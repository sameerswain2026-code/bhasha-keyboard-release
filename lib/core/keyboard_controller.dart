/// Central keyboard state - single coherent state model.
/// All subsystems (layout, language, panels, voice, suggestions,
/// clipboard, themes) coordinate through this controller. Features
/// never keep conflicting copies of shared state.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/languages.dart';
import '../engine/ai_assistant_engine.dart';
import '../engine/ai_command_capture.dart';
import '../engine/suggestion_engine.dart';
import '../engine/transliterator.dart';
import '../engine/translation_engine.dart';
import '../engine/voice_engine.dart';
import '../engine/voice_factory.dart';
import '../engine/writing_assistant.dart';

/// Keyboard layout page.
enum KeyboardLayer { alpha, numeric, symbols }

/// Shift state machine: off -> single (temporary) -> capsLock.
enum ShiftState { off, single, capsLock }

/// Which panel is open above/instead of keys.
enum ActivePanel {
  none,
  menu, // Gboard-style expanded menu grid
  emoji,
  gif,
  sticker,
  textEditing,
  resize,
  translateConfig, // Translate Configuration Page (source/target/style + Save)
  transcribeLang, // Mic-side language selector for Transcribe mode
  clipboard,
  language, // Keyboard TYPING language (independent of mic), via long-press
  settings,
  theme,
}

/// One-handed mode side.
enum OneHandedSide { off, left, right }

/// Editor action for Enter key.
enum EditorAction { newline, send, search, done, next }

/// Synthetic pack representing Sarvam's automatic multi-language
/// detection code ("unknown"), used only for Auto Mix mode's mixed
/// Odia+Hindi+English (etc.) speech recognition. Never exposed in the
/// language picker UI and intentionally excluded from [kLanguagePacks]
/// (the test suite asserts that list is exactly the 23 real,
/// user-selectable languages).
const LanguagePack _autoMixLanguagePack = LanguagePack(
  id: '_automix',
  englishName: 'Auto Mix (multilingual)',
  nativeName: 'Auto Mix',
  locale: 'unknown',
  family: ScriptFamily.latin,
  sarvamCodeOverride: 'unknown',
);

class KeyboardController extends ChangeNotifier {
  KeyboardController({
    VoiceEngine? voiceEngine,
    AiAssistantEngine? aiEngine,
    AiCommandCapture? aiCapture,
  }) : voice = voiceEngine ?? createVoiceEngine(),
       _ai = aiEngine ?? AiAssistantEngine(),
       _aiCapture = aiCapture ?? AiCommandCapture() {
    voice.onFinalText = _onVoiceFinal;
    voice.onPartialText = (_) => notifyListeners();
    voice.onSessionEnd = _onVoiceSessionEnd;
    voice.addListener(notifyListeners);
    _aiCapture.onCaptureStart = () {
      _aiThinking = false;
      notifyListeners();
    };
    _aiCapture.onCaptureEnd = () {
      // Restore the mic's normal silence window - see the field doc on
      // [VoiceEngine.silenceTimeout] for why this is temporarily
      // widened only while a command is being buffered.
      voice.silenceTimeout = VoiceEngine.defaultSilenceTimeout;
    };
    _aiCapture.onFinalize = (fullUtterance) {
      _aiThinking = true;
      notifyListeners();
      _ai.process(fullUtterance, _insertAiAssistantResult);
    };
    _loadPrefs();
  }

  // ---- Sub-engines ----
  final VoiceEngine voice;
  final SuggestionEngine suggestions = SuggestionEngine();
  final WritingAssistant writingAssistant = const WritingAssistant();

  int _nativePage = 0;
  int get nativePage => _nativePage;
  int get nativePageCount => _language.isLatin
      ? 1
      : nativeLayoutPagesFor(_language).length;
  void nextNativePage() {
    if (_language.isLatin) return;
    _nativePage = (_nativePage + 1) % nativePageCount;
    notifyListeners();
  }

  // =====================================================================
  // AI Web Assistant (optional, opt-in - default OFF)
  // =====================================================================
  //
  // Lightweight middleware inserted after transcription (see
  // [_onVoiceFinal]). When [_aiAssistantEnabled] is false (the default),
  // this feature performs ZERO extra work: no wake-word scan, no Tavily
  // call, no behavior change whatsoever versus the keyboard's original
  // voice pipeline. It only ever activates for a finalized utterance in
  // Transcribe mode or Auto Mix mode when the configured wake word is
  // present; Translate mode's existing pivot-translation flow is left
  // completely untouched (kept flexible for future support, per spec).
  final AiAssistantEngine _ai;

  // Buffers a wake-word-triggered command across multiple finalized
  // speech chunks until the mic stops or the configured inactivity
  // timeout elapses - see [ai_command_capture.dart] for the full
  // rationale. Wired entirely through callbacks in the constructor
  // above; [_onVoiceFinal] only ever decides whether a chunk should
  // start/feed a capture (via [AiAssistantEngine.matchesWakeWord]) or
  // be treated as normal speech - it never talks to [_ai] directly for
  // the capturing path, [_aiCapture.onFinalize] does that exactly once
  // per completed command.
  final AiCommandCapture _aiCapture;

  /// True the instant a command's inactivity/mic-stop finalize fires
  /// and the AI Router request is in flight; cleared the moment
  /// [_insertAiAssistantResult] delivers the answer. Drives the
  /// subtle "Thinking…" indicator - purely additive UI state, changing
  /// it never affects the assistant's actual request/response flow.
  bool _aiThinking = false;
  bool get aiThinking => _aiThinking;

  /// True while a wake-word-triggered command is actively being
  /// buffered (i.e. [_aiCapture] is capturing) - drives the subtle
  /// "Listening…" (for the AI command specifically, distinct from the
  /// mic's own general "Listening…" status) indicator.
  bool get aiCapturing => _aiCapture.isCapturing;

  bool _aiAssistantEnabled = false;
  bool get aiAssistantEnabled => _aiAssistantEnabled;

  static const String _defaultAssistantName = 'Bhasha';
  String _assistantName = _defaultAssistantName;
  String get assistantName => _assistantName;

  AiListeningTimeout _aiListeningTimeout = AiListeningTimeout.balanced;
  AiListeningTimeout get aiListeningTimeout => _aiListeningTimeout;

  /// Enables/disables the AI Web Assistant. Off by default; toggling
  /// this is the ONLY way the wake-word/Tavily path can ever run.
  void setAiAssistantEnabled(bool v) {
    _feedback();
    _aiAssistantEnabled = v;
    _ai.enabled = v;
    if (!v) {
      // Disabling mid-capture must never leave a stray buffered
      // command or widened mic-silence window behind.
      _aiCapture.cancel();
      _aiThinking = false;
    }
    _persist('aiAssistantEnabled', v);
    notifyListeners();
  }

  /// Sets the AI command inactivity-listening timeout (Settings -> AI
  /// Web Assistant -> "Command Listening Timeout"). Applies instantly:
  /// the very next time a command starts being captured uses the new
  /// duration. An already in-progress capture keeps running with
  /// whatever duration was active when its timer last armed (see
  /// [AiCommandCapture.timeout]'s own doc) - so changing this setting
  /// mid-command can never abruptly cut it short or unexpectedly
  /// extend it, only future commands are affected.
  void setAiListeningTimeout(AiListeningTimeout t) {
    _feedback();
    _aiListeningTimeout = t;
    _aiCapture.timeout = t.duration;
    _persist('aiListeningTimeout', t.name);
    notifyListeners();
  }

  /// Sets the custom wake word / assistant name (defaults to "Bhasha").
  /// Blank input is ignored so the assistant can never be left with an
  /// empty, unmatchable wake word.
  void setAssistantName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _feedback();
    _assistantName = trimmed;
    _ai.assistantName = trimmed;
    _persist('assistantName', trimmed);
    notifyListeners();
  }

  // ---- Editor state (source of truth for the demo editor) ----
  final TextEditingController editor = TextEditingController();

  /// Composing region: the word currently being typed (for suggestions
  /// and transliteration). Committed text is never mutated by async work.
  String _composing = '';
  String get composing => _composing;

  // ---- Layout / shift ----
  KeyboardLayer _layer = KeyboardLayer.alpha;
  KeyboardLayer get layer => _layer;

  ShiftState _shift = ShiftState.off;
  ShiftState get shift => _shift;

  // ---- Language / script ----
  LanguagePack _language = LanguageRegistry.byId('en');
  LanguagePack get language => _language;

  ScriptMode _scriptMode = ScriptMode.roman;
  ScriptMode get scriptMode => _scriptMode;

  // ---- Panels ----
  ActivePanel _panel = ActivePanel.none;
  ActivePanel get panel => _panel;

  // ---- Editor action ----
  EditorAction _editorAction = EditorAction.newline;
  EditorAction get editorAction => _editorAction;

  // ---- Theme ----
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // ---- Feedback settings ----
  bool _hapticsEnabled = true;
  bool get hapticsEnabled => _hapticsEnabled;
  bool _soundEnabled = false;
  bool get soundEnabled => _soundEnabled;

  // ---- Suggestions ----
  List<String> _suggestionList = [];
  List<String> get suggestionList => _suggestionList;

  // ---- Clipboard history ----
  final List<String> _clipboardHistory = [];
  List<String> get clipboardHistory => List.unmodifiable(_clipboardHistory);

  // ---- Recently used emojis ----
  final List<String> _recentEmojis = [];
  List<String> get recentEmojis => List.unmodifiable(_recentEmojis);

  // ---- Recently used stickers ----
  final List<String> _recentStickers = [];
  List<String> get recentStickers => List.unmodifiable(_recentStickers);

  // ---- Long-press delete ----
  Timer? _deleteTimer;
  int _deleteGeneration = 0;
  int _deleteTickCount = 0;

  /// Optional hook (wired by [ImeBridge] on real Android IME sessions
  /// only): attempts to delete the HOST app's actual text selection
  /// (e.g. text selected with the native selection handles in WhatsApp)
  /// via InputConnection.getSelectedText/commitText. Returns true if a
  /// host-side selection existed and was deleted - in that case the
  /// shadow [editor] mirror is not touched (the bridge resets it so
  /// future diffs recompute cleanly against the host's new state).
  /// Left null in the demo app / widget tests, where deletion always
  /// falls back to the shadow-editor-based [_performDelete].
  Future<bool> Function()? hostSelectionDeleter;
  Future<String?> Function()? hostSelectedTextReader;
  Future<void> Function(String text)? hostSelectionReplacer;
  Future<void> Function(String text, String locale)? hostTextSpeaker;
  Future<void> Function(String source, String mimeType, String title)?
  hostMediaSharer;

  // ---- Mic mode (Transcribe / Translate / Auto-mix) ----
  // Exactly 3 modes. Default on first open is Transcribe (Odia, Roman).
  MicMode _micMode = MicMode.transcribe;

  /// Effective mic mode: identical to the stored mode except it safely
  /// falls back to Transcribe if Translate was never successfully
  /// activated via Save/Apply (guards a stale/corrupted persisted state
  /// claiming Translate is live without a saved configuration behind
  /// it - "the mic must continue functioning as Transcribe Mode if
  /// Translate Mode has not yet been successfully activated").
  MicMode get micMode =>
      (_micMode == MicMode.translate && !_translateEverActivated)
      ? MicMode.transcribe
      : _micMode;

  final TranslationEngine _translationEngine = TranslationEngine();

  // ---- Transcribe mode config (Method: mic-side Language Selector) ----
  // Independent of the general typing [_language] - the mic's Transcribe
  // recognition language defaults to Odia regardless of what script the
  // user is currently typing in.
  LanguagePack _transcribeLanguage = LanguageRegistry.byId('or');
  LanguagePack get transcribeLanguage => _transcribeLanguage;
  ScriptMode _transcribeStyle = ScriptMode.roman;
  ScriptMode get transcribeStyle => _transcribeStyle;

  /// Sets the Transcribe mode language + output style (Native/Roman).
  /// Chosen from the mic-side Language Selector, not the toolbar.
  void setTranscribeConfig(LanguagePack lang, ScriptMode style) {
    _transcribeLanguage = lang;
    if (style == ScriptMode.native && !lang.supportsNative) {
      style = ScriptMode.roman;
    } else if (style == ScriptMode.roman && !lang.supportsRoman) {
      style = ScriptMode.native;
    }
    _transcribeStyle = style;
    _persist('transcribeLang', lang.id);
    _persist('transcribeStyle', style.name);
    // Language-code changes require a fresh recognizer session.
    if (voice.isActive && micMode == MicMode.transcribe) {
      voice.stopSession(reason: 'transcribe-config-changed');
    }
    notifyListeners();
  }

  // ---- Translate mode config (saved/active) ----
  // Default: Source=Odia, Target=English, Output=Roman.
  LanguagePack _translateSource = LanguageRegistry.byId('or');
  LanguagePack get translateSource => _translateSource;
  LanguagePack _translateTarget = LanguageRegistry.byId('en');
  LanguagePack get translateTarget => _translateTarget;
  ScriptMode _translateOutputStyle = ScriptMode.roman;
  ScriptMode get translateOutputStyle => _translateOutputStyle;

  /// True once Translate mode's configuration has been successfully
  /// saved/applied at least once (the explicit Save/Apply button on the
  /// Translate Configuration Page, or a direct Method-1 selection which
  /// commits the current default/saved config immediately).
  bool _translateEverActivated = false;
  bool get translateEverActivated => _translateEverActivated;

  /// Draft fields for the Translate Configuration Page (Method 2, opened
  /// from the toolbar Translate icon). Edited freely by the user but
  /// never affect live mic behavior until [applyTranslateConfig] (the
  /// explicit Save/Apply button) is called - this is the core of the
  /// required gating logic.
  LanguagePack _draftSource = LanguageRegistry.byId('or');
  LanguagePack get draftSource => _draftSource;
  LanguagePack _draftTarget = LanguageRegistry.byId('en');
  LanguagePack get draftTarget => _draftTarget;
  ScriptMode _draftStyle = ScriptMode.roman;
  ScriptMode get draftStyle => _draftStyle;

  /// Opens the Translate Configuration Page, seeding drafts from the
  /// last SAVED config (never from a previously abandoned edit).
  void openTranslateConfig() {
    _draftSource = _translateSource;
    _draftTarget = _translateTarget;
    _draftStyle = _translateOutputStyle;
    togglePanel(ActivePanel.translateConfig);
  }

  void setDraftSource(LanguagePack p) {
    _draftSource = p;
    notifyListeners();
  }

  void setDraftTarget(LanguagePack p) {
    _draftTarget = p;
    notifyListeners();
  }

  void setDraftStyle(ScriptMode m) {
    _draftStyle = m;
    notifyListeners();
  }

  /// Save/Apply: only now does the draft become the live, active
  /// Translate configuration - mic mode switches to Translate and the
  /// mic-side indicator swaps to the Translate Page icon. Until this is
  /// called, editing the draft has zero effect on mic behavior.
  void applyTranslateConfig() {
    _feedback();
    _translateSource = _draftSource;
    _translateTarget = _draftTarget;
    _translateOutputStyle = _draftStyle;
    _translateEverActivated = true;
    _persist('translateSource', _translateSource.id);
    _persist('translateTarget', _translateTarget.id);
    _persist('translateStyle', _translateOutputStyle.name);
    _persist('translateEverActivated', true);
    setMicMode(MicMode.translate);
    closePanel();
  }

  // ---- Auto Mix mode config ----
  // Default: Auto Mix + Roman.
  ScriptMode _autoMixStyle = ScriptMode.roman;
  ScriptMode get autoMixStyle => _autoMixStyle;

  void setAutoMixStyle(ScriptMode mode) {
    _feedback();
    _autoMixStyle = mode;
    _persist('autoMixStyle', mode.name);
    if (voice.isActive && micMode == MicMode.autoMix) {
      voice.setScriptMode(mode);
    }
    notifyListeners();
  }

  // ---- Menu extras: Resize / One-handed mode ----
  // "Resize" is expressed as a key-height scale factor rather than a
  // native window-size change (the demo/web-preview host and widget
  // tests have no OS-level IME window to resize).
  double _sizeScale = 1.0;
  double get sizeScale => _sizeScale;

  /// Updates the key-height scale live (called on every Slider onChanged
  /// tick during a drag). Deliberately does NOT trigger haptic/sound
  /// feedback here - doing so on every tick during a fast drag caused the
  /// slider to feel laggy/throttled (each tick blocked briefly on a
  /// platform-channel haptics call). Use [hapticTick] once, on release.
  void setSizeScale(double scale) {
    _sizeScale = scale.clamp(0.82, 1.18);
    _persist('sizeScale', _sizeScale.toString());
    notifyListeners();
  }

  /// Single haptic pulse for the Resize slider's onChangeEnd (or the
  /// Reset button) - tactile confirmation without per-tick overhead.
  void hapticTick() => _feedback();

  OneHandedSide _oneHandedSide = OneHandedSide.off;
  OneHandedSide get oneHandedSide => _oneHandedSide;
  void setOneHandedSide(OneHandedSide side) {
    _feedback();
    _oneHandedSide = side;
    if (side == OneHandedSide.off) _oneHandedAdjusting = false;
    _persist('oneHandedSide', side.name);
    notifyListeners();
  }

  /// Cycles Off -> Left -> Right -> Off. The Menu's "One-Handed Mode"
  /// tile is a direct toggle (like Floating Keyboard), not a settings
  /// screen - matching Gboard's own compact design, where the actual
  /// side-switch/expand controls live inline beside the shrunk keys
  /// themselves (see [KeyboardView]'s one-handed frame), not in a menu.
  void cycleOneHandedSide() {
    _feedback();
    _oneHandedSide = switch (_oneHandedSide) {
      OneHandedSide.off => OneHandedSide.left,
      OneHandedSide.left => OneHandedSide.right,
      OneHandedSide.right => OneHandedSide.off,
    };
    if (_oneHandedSide == OneHandedSide.off) _oneHandedAdjusting = false;
    _persist('oneHandedSide', _oneHandedSide.name);
    notifyListeners();
  }

  /// Fraction of the available width the keys occupy in One-Handed Mode
  /// (the rest is the side control/handle strip). Matches Gboard's own
  /// drag-to-resize one-handed keyboard: dragging the handle in
  /// [_OneHandedFrame] calls [setOneHandedWidthFraction] live, and a
  /// "Reset" button restores [_oneHandedWidthDefault].
  static const double _oneHandedWidthDefault = 0.78;
  double _oneHandedWidthFraction = _oneHandedWidthDefault;
  double get oneHandedWidthFraction => _oneHandedWidthFraction;

  void setOneHandedWidthFraction(double v) {
    _oneHandedWidthFraction = v.clamp(0.55, 0.88);
    _persist('oneHandedWidth', _oneHandedWidthFraction.toString());
    notifyListeners();
  }

  void resetOneHandedWidth() {
    _feedback();
    _oneHandedWidthFraction = _oneHandedWidthDefault;
    _persist('oneHandedWidth', _oneHandedWidthFraction.toString());
    notifyListeners();
  }

  /// Whether the Gboard-style drag-handle resize overlay (corner
  /// handles + Reset/Done) is showing over the one-handed keyboard.
  /// Entered explicitly via the control strip's resize icon; exiting
  /// ("Done") just hides the handles, one-handed mode itself stays on.
  bool _oneHandedAdjusting = false;
  bool get oneHandedAdjusting => _oneHandedAdjusting;

  void enterOneHandedAdjust() {
    _feedback();
    _oneHandedAdjusting = true;
    notifyListeners();
  }

  void exitOneHandedAdjust() {
    _feedback();
    _oneHandedAdjusting = false;
    notifyListeners();
  }

  /// "Floating Keyboard" toggle. Floating an actual OS-level IME window
  /// is a native Android window-management feature this Flutter host
  /// cannot control from Dart; the toggle is kept as user-facing state
  /// (persisted, surfaced in the Menu) so the feature has a real,
  /// working switch today and a native implementation can hook into it
  /// later without any UI changes.
  bool _floatingEnabled = false;
  bool get floatingEnabled => _floatingEnabled;
  void setFloatingEnabled(bool v) {
    _feedback();
    _floatingEnabled = v;
    if (!v) _floatingOffset = Offset.zero;
    _persist('floatingEnabled', v);
    notifyListeners();
  }

  /// Drag offset of the floating keyboard "card" (see [KeyboardView]'s
  /// floating wrapper). Real OS-level window floating/dragging is a
  /// native Android feature this Flutter host cannot reach into (no
  /// WindowManager overlay exists in the IME service) - this offset
  /// drives a genuine drag-anywhere-within-the-view simulation instead,
  /// so Floating Keyboard has real, working detach/drag/dock behavior
  /// at the layer this app can control.
  Offset _floatingOffset = Offset.zero;
  Offset get floatingOffset => _floatingOffset;
  void setFloatingOffset(Offset o) {
    _floatingOffset = o;
    notifyListeners();
  }

  /// "Dock" the floating card back to its default position.
  void dockFloating() {
    _feedback();
    _floatingOffset = Offset.zero;
    notifyListeners();
  }

  // ---- Panel-embedded text capture (search bars, translate input) ----
  // Panels (emoji/GIF/language search, translate source text) contain a
  // text field, but this app IS the system keyboard - tapping that field
  // cannot summon a second on-screen keyboard from Android. Instead,
  // tapping the field opens a compact mini-keyboard docked inside the
  // panel itself; keys typed there are captured here rather than sent to
  // the host app's main text editor. Only one panel is visible at a
  // time, so a single shared slot of state is sufficient.
  bool _panelKeyboardActive = false;
  bool get panelKeyboardActive => _panelKeyboardActive;
  String _panelInputText = '';
  String get panelInputText => _panelInputText;

  /// Pre-fills the panel input text without opening the mini-keyboard
  /// (e.g. seeding the translate field with the current selection).
  void setPanelInputText(String text) {
    _panelInputText = text;
    notifyListeners();
  }

  /// Opens the on-panel mini-keyboard for the given field, seeding it
  /// with [initialText] (kept when re-opening the same field).
  void openPanelKeyboard({String initialText = ''}) {
    _feedback();
    _panelInputText = initialText;
    _panelKeyboardActive = true;
    notifyListeners();
  }

  /// Hides the mini-keyboard but preserves the typed text so panels can
  /// keep filtering/showing it (e.g. after tapping a checkmark "done").
  void closePanelKeyboard() {
    if (!_panelKeyboardActive) return;
    _panelKeyboardActive = false;
    notifyListeners();
  }

  void panelKeyboardInsert(String ch) {
    _feedback();
    _panelInputText += ch;
    notifyListeners();
  }

  void panelKeyboardBackspace() {
    _feedback();
    if (_panelInputText.isEmpty) return;
    _panelInputText = _panelInputText.substring(0, _panelInputText.length - 1);
    notifyListeners();
  }

  void panelKeyboardClear() {
    if (_panelInputText.isEmpty && !_panelKeyboardActive) return;
    _panelInputText = '';
    _panelKeyboardActive = false;
    notifyListeners();
  }

  // ---- Persistence ----
  SharedPreferences? _prefs;
  bool _prefsLoaded = false;

  /// Writes requested before [_prefs] finishes initializing (a real
  /// race: `SharedPreferences.getInstance()` is async and can be slow
  /// on a freshly-spawned IME FlutterEngine, while a user can pick a
  /// language the instant the keyboard appears) are queued here and
  /// flushed once prefs are ready, instead of being silently dropped.
  /// Without this queue, a language chosen quickly after the keyboard
  /// opens would appear to work in the session but never actually be
  /// saved, making the "persistent selection" complaint intermittent
  /// and hard to reproduce.
  final Map<String, Object> _pendingPersist = {};

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langId = prefs.getString('language');
      if (langId != null) _language = LanguageRegistry.byId(langId);
      final mode = prefs.getString('scriptMode');
      if (mode == 'native' && _language.supportsNative) {
        _scriptMode = ScriptMode.native;
      }
      final theme = prefs.getString('themeMode');
      if (theme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == theme,
          orElse: () => ThemeMode.system,
        );
      }
      _hapticsEnabled = prefs.getBool('haptics') ?? true;
      _soundEnabled = prefs.getBool('sound') ?? false;
      final micModeName = prefs.getString('micMode');
      if (micModeName != null) {
        _micMode = MicMode.values.firstWhere(
          (m) => m.name == micModeName,
          orElse: () => MicMode.transcribe,
        );
      }
      // Transcribe mode config.
      final transcribeLangId = prefs.getString('transcribeLang');
      if (transcribeLangId != null) {
        _transcribeLanguage = LanguageRegistry.byId(transcribeLangId);
      }
      final transcribeStyleName = prefs.getString('transcribeStyle');
      if (transcribeStyleName != null) {
        _transcribeStyle = transcribeStyleName == 'native'
            ? ScriptMode.native
            : ScriptMode.roman;
      }
      // Translate mode config (saved/active).
      final translateSourceId = prefs.getString('translateSource');
      if (translateSourceId != null) {
        _translateSource = LanguageRegistry.byId(translateSourceId);
      }
      final translateTargetId = prefs.getString('translateTarget');
      if (translateTargetId != null) {
        _translateTarget = LanguageRegistry.byId(translateTargetId);
      }
      final translateStyleName = prefs.getString('translateStyle');
      if (translateStyleName != null) {
        _translateOutputStyle = translateStyleName == 'native'
            ? ScriptMode.native
            : ScriptMode.roman;
      }
      _translateEverActivated =
          prefs.getBool('translateEverActivated') ?? false;
      // AI Web Assistant (optional feature - off by default).
      _aiAssistantEnabled = prefs.getBool('aiAssistantEnabled') ?? false;
      _ai.enabled = _aiAssistantEnabled;
      final assistantNameStr = prefs.getString('assistantName');
      if (assistantNameStr != null && assistantNameStr.trim().isNotEmpty) {
        _assistantName = assistantNameStr;
        _ai.assistantName = assistantNameStr;
      }
      _aiListeningTimeout = AiListeningTimeout.fromName(
        prefs.getString('aiListeningTimeout'),
      );
      _aiCapture.timeout = _aiListeningTimeout.duration;
      // Auto Mix mode config.
      final autoMixStyleName = prefs.getString('autoMixStyle');
      if (autoMixStyleName != null) {
        _autoMixStyle = autoMixStyleName == 'native'
            ? ScriptMode.native
            : ScriptMode.roman;
      }
      // Resize (key-height scale).
      final sizeScaleStr = prefs.getString('sizeScale');
      if (sizeScaleStr != null) {
        final parsed = double.tryParse(sizeScaleStr);
        if (parsed != null) _sizeScale = parsed.clamp(0.82, 1.18);
      }
      final oneHandedName = prefs.getString('oneHandedSide');
      if (oneHandedName != null) {
        _oneHandedSide = OneHandedSide.values.firstWhere(
          (s) => s.name == oneHandedName,
          orElse: () => OneHandedSide.off,
        );
      }
      final oneHandedWidthStr = prefs.getString('oneHandedWidth');
      if (oneHandedWidthStr != null) {
        final parsed = double.tryParse(oneHandedWidthStr);
        if (parsed != null) _oneHandedWidthFraction = parsed.clamp(0.55, 0.88);
      }
      _floatingEnabled = prefs.getBool('floatingEnabled') ?? false;
      _recentEmojis.addAll(prefs.getStringList('recentEmojis') ?? []);
      _recentStickers.addAll(prefs.getStringList('recentStickers') ?? []);
      _clipboardHistory.addAll(prefs.getStringList('clipboard') ?? []);
      for (final pack in kLanguagePacks) {
        final learned = prefs.getStringList('learned_${pack.id}');
        if (learned != null) suggestions.restoreLearned(pack.id, learned);
      }
      _prefs = prefs;
      _prefsLoaded = true;
      // Flush any writes that arrived before prefs finished loading -
      // these reflect the user's most recent explicit choice (made via
      // a setter that already updated in-memory state synchronously),
      // so they must win over whatever was just loaded from disk above,
      // which may be stale relative to that choice.
      if (_pendingPersist.isNotEmpty) {
        final pending = Map<String, Object>.from(_pendingPersist);
        _pendingPersist.clear();
        for (final entry in pending.entries) {
          _writePref(prefs, entry.key, entry.value);
          final v = entry.value;
          switch (entry.key) {
            case 'language':
              if (v is String) _language = LanguageRegistry.byId(v);
            case 'scriptMode':
              if (v is String) {
                _scriptMode = v == 'native'
                    ? ScriptMode.native
                    : ScriptMode.roman;
              }
            case 'themeMode':
              if (v is String) {
                _themeMode = ThemeMode.values.firstWhere(
                  (m) => m.name == v,
                  orElse: () => ThemeMode.system,
                );
              }
            case 'micMode':
              if (v is String) {
                _micMode = MicMode.values.firstWhere(
                  (m) => m.name == v,
                  orElse: () => MicMode.transcribe,
                );
              }
            case 'haptics':
              if (v is bool) _hapticsEnabled = v;
            case 'sound':
              if (v is bool) _soundEnabled = v;
            case 'transcribeLang':
              if (v is String) _transcribeLanguage = LanguageRegistry.byId(v);
            case 'transcribeStyle':
              if (v is String) {
                _transcribeStyle = v == 'native'
                    ? ScriptMode.native
                    : ScriptMode.roman;
              }
            case 'translateSource':
              if (v is String) _translateSource = LanguageRegistry.byId(v);
            case 'translateTarget':
              if (v is String) _translateTarget = LanguageRegistry.byId(v);
            case 'translateStyle':
              if (v is String) {
                _translateOutputStyle = v == 'native'
                    ? ScriptMode.native
                    : ScriptMode.roman;
              }
            case 'translateEverActivated':
              if (v is bool) _translateEverActivated = v;
            case 'aiAssistantEnabled':
              if (v is bool) {
                _aiAssistantEnabled = v;
                _ai.enabled = v;
              }
            case 'assistantName':
              if (v is String && v.trim().isNotEmpty) {
                _assistantName = v;
                _ai.assistantName = v;
              }
            case 'aiListeningTimeout':
              if (v is String) {
                _aiListeningTimeout = AiListeningTimeout.fromName(v);
                _aiCapture.timeout = _aiListeningTimeout.duration;
              }
            case 'autoMixStyle':
              if (v is String) {
                _autoMixStyle = v == 'native'
                    ? ScriptMode.native
                    : ScriptMode.roman;
              }
            case 'sizeScale':
              if (v is String) {
                final parsed = double.tryParse(v);
                if (parsed != null) _sizeScale = parsed.clamp(0.82, 1.18);
              }
            case 'oneHandedSide':
              if (v is String) {
                _oneHandedSide = OneHandedSide.values.firstWhere(
                  (s) => s.name == v,
                  orElse: () => OneHandedSide.off,
                );
              }
            case 'oneHandedWidth':
              if (v is String) {
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  _oneHandedWidthFraction = parsed.clamp(0.55, 0.88);
                }
              }
            case 'floatingEnabled':
              if (v is bool) _floatingEnabled = v;
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Persistence failure must never break typing.
    }
  }

  void _writePref(SharedPreferences p, String key, Object value) {
    try {
      if (value is String) p.setString(key, value);
      if (value is bool) p.setBool(key, value);
      if (value is List<String>) p.setStringList(key, value);
    } catch (_) {}
  }

  void _persist(String key, Object value) {
    if (!_prefsLoaded) {
      // Queue instead of dropping - see [_pendingPersist].
      _pendingPersist[key] = value;
      return;
    }
    final p = _prefs;
    if (p == null) return;
    _writePref(p, key, value);
  }

  // =====================================================================
  // Core typing (P0)
  // =====================================================================

  /// Insert a character at the cursor. Handles shift and composing.
  void insertText(String raw) {
    _feedback();
    if (_justCopiedText != null) dismissJustCopiedBanner();
    var text = raw;
    if (_shift != ShiftState.off && text.length == 1) {
      text = text.toUpperCase();
      if (_shift == ShiftState.single) {
        _shift = ShiftState.off;
      }
    }

    final isLetter =
        RegExp(r'[a-zA-Z]').hasMatch(text) ||
        (text.runes.length == 1 && text.runes.first > 0x0900);

    // Word separators commit the composing word first.
    if (!isLetter) {
      _commitComposing();
      _insertRaw(text);
      _updateSuggestions();
      notifyListeners();
      return;
    }

    // Letters extend the composing region.
    _composing += text;
    _insertRaw(text);
    _updateSuggestions();
    notifyListeners();
  }

  /// Insert emoji or arbitrary content (commits composing first).
  void insertContent(String content) {
    _feedback();
    _commitComposing();
    _insertRaw(content);
    if (content.runes.isNotEmpty && content.runes.first > 0x1F000) {
      _addRecentEmoji(content);
    }
    notifyListeners();
  }

  /// Insert rich content into the host app when running as the Android IME.
  /// Preview/demo editors use the labelled fallback instead.
  Future<void> insertMedia({
    required String source,
    required String mimeType,
    required String title,
    String? fallbackText,
  }) async {
    _feedback();
    _commitComposing();
    final sharer = hostMediaSharer;
    if (sharer != null) {
      await sharer(source, mimeType, title);
    } else if (fallbackText != null) {
      _insertRaw(fallbackText);
      notifyListeners();
    }
  }

  void _insertRaw(String text) {
    final sel = editor.selection;
    final full = editor.text;
    if (!sel.isValid) {
      editor.text = full + text;
      editor.selection = TextSelection.collapsed(offset: editor.text.length);
      return;
    }
    final start = sel.start.clamp(0, full.length);
    final end = sel.end.clamp(0, full.length);
    final next = full.replaceRange(start, end, text);
    editor.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  /// Commit the current composing region. If Roman mode on an Indic
  /// language, replace the composing text with its transliteration.
  void _commitComposing({String? replaceWith}) {
    if (_composing.isEmpty) return;
    final replacement =
        replaceWith ??
        ((!_language.isLatin && _scriptMode == ScriptMode.roman)
            ? Transliterator.transliterate(_composing, _language)
            : _composing);

    if (replacement != _composing) {
      _replaceComposingInEditor(replacement);
    }
    suggestions.learn(_language.id, replacement);
    _persist(
      'learned_${_language.id}',
      suggestions.learnedWords(_language.id).take(200).toList(),
    );
    // Gboard-style next-word learning: remember what word tends to
    // follow the previously committed word.
    if (_lastCommittedWord.isNotEmpty) {
      suggestions.learnBigram(_language.id, _lastCommittedWord, replacement);
    }
    _lastCommittedWord = replacement;
    _composing = '';
    _suggestionList = [];
  }

  /// Last word committed (for next-word prediction learning/lookup).
  String _lastCommittedWord = '';

  void _replaceComposingInEditor(String replacement) {
    final sel = editor.selection;
    final full = editor.text;
    final cursor = sel.isValid ? sel.start : full.length;
    final compLen = _composing.length;
    final start = (cursor - compLen).clamp(0, full.length);
    // Verify the text before the cursor actually is the composing word.
    if (cursor <= full.length &&
        start >= 0 &&
        full.substring(start, cursor) == _composing) {
      final next = full.replaceRange(start, cursor, replacement);
      editor.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + replacement.length),
      );
    }
  }

  /// Pick a suggestion: replaces the composing word.
  void applySuggestion(String suggestion) {
    _feedback();
    if (_composing.isNotEmpty) {
      _commitComposing(replaceWith: suggestion);
      _insertRaw(' ');
    } else {
      // Picking a next-word prediction: insert directly and chain the
      // bigram (predicted word becomes the new "previous word").
      _insertRaw('$suggestion ');
      suggestions.learn(_language.id, suggestion);
      if (_lastCommittedWord.isNotEmpty) {
        suggestions.learnBigram(_language.id, _lastCommittedWord, suggestion);
      }
      _lastCommittedWord = suggestion;
    }
    _updateSuggestions();
    notifyListeners();
  }

  /// Re-syncs the shadow [editor] mirror to text reported directly by
  /// the host app (via [ImeBridge]'s InputConnection queries), used
  /// whenever the host's real text changed by a means this controller
  /// did not itself initiate - native "Paste"/"Cut" from Android's own
  /// text-selection menu, autocorrect, or a field that already held
  /// text when the keyboard attached. Without this resync the shadow
  /// mirror silently drifts out of sync with the host's actual text,
  /// which is what caused backspace/typing diffs computed against the
  /// stale mirror to appear to do nothing.
  ///
  /// Any in-flight composing word is dropped: it was being tracked
  /// against the OLD shadow text, which may no longer correspond to
  /// anything real at the new cursor position after an external edit.
  void syncFromHost(String before, String after) {
    _composing = '';
    editor.value = TextEditingValue(
      text: before + after,
      selection: TextSelection.collapsed(offset: before.length),
    );
    _updateSuggestions();
    notifyListeners();
  }

  // =====================================================================
  // Delete (P0) - tap, long-press repeat, and Gboard-style swipe delete
  // =====================================================================

  int? _swipeDeleteCursor;
  int? _swipeDeleteStart;
  double _swipeDeleteDistance = 0;

  /// Starts Gboard's short press-and-swipe-left delete gesture. The text is
  /// only changed when the finger is released, so dragging previews a
  /// selection instead of repeatedly mutating the host editor.
  void startSwipeDelete() {
    stopContinuousDelete();
    final sel = editor.selection;
    if (!sel.isValid) return;
    final cursor = sel.isCollapsed ? sel.start : sel.end;
    _swipeDeleteCursor = cursor.clamp(0, editor.text.length);
    _swipeDeleteStart = _swipeDeleteCursor;
    _swipeDeleteDistance = 0;
  }

  /// Extends the pending deletion one word at a time as the finger moves
  /// left, matching Gboard's swipe-left-to-highlight behavior. A small
  /// movement still selects the previous grapheme/word rather than doing
  /// nothing, which makes the gesture reliable on narrow delete keys.
  void updateSwipeDelete(double deltaX) {
    if (_swipeDeleteCursor == null || deltaX >= 0) return;
    _swipeDeleteDistance += -deltaX;
    final full = editor.text;
    final cursor = _swipeDeleteCursor!.clamp(0, full.length);
    if (cursor <= 0) return;

    var target = cursor;
    final steps = (_swipeDeleteDistance / 24).floor().clamp(1, 1000);
    for (var n = 0; n < steps && target > 0; n++) {
      bool isBoundary(String ch) => ch == ' ' || ch == '\n' || ch == '\t';
      while (target > 0 && isBoundary(full[target - 1])) {
        target--;
      }
      while (target > 0 && !isBoundary(full[target - 1])) {
        target--;
      }
    }
    editor.selection = TextSelection(baseOffset: target, extentOffset: cursor);
    notifyListeners();
  }

  /// Commits the currently previewed swipe selection. If no horizontal
  /// movement occurred, the ordinary tap/long-press path remains in charge.
  void endSwipeDelete() {
    if (_swipeDeleteCursor != null &&
        _swipeDeleteStart != null &&
        _swipeDeleteDistance > 0 &&
        editor.selection.isValid &&
        !editor.selection.isCollapsed) {
      _performDelete();
      notifyListeners();
    }
    _swipeDeleteCursor = null;
    _swipeDeleteStart = null;
    _swipeDeleteDistance = 0;
  }

  /// Delete one step backward. On a real Android IME session this first
  /// asks the host app (via [hostSelectionDeleter]) whether there is an
  /// actual text selection in the target app (e.g. text selected with
  /// the native handles in WhatsApp) and deletes that range directly
  /// through InputConnection - the shadow [editor] has no knowledge of
  /// selections made natively in the host app, so without this hook a
  /// held selection could not be removed with backspace.
  Future<void> deleteBackward() async {
    _feedback();
    final hostDeleter = hostSelectionDeleter;
    if (hostDeleter != null) {
      final handled = await hostDeleter();
      if (handled) {
        _composing = '';
        _updateSuggestions();
        notifyListeners();
        return;
      }
    }
    _performDelete();
    notifyListeners();
  }

  /// Deletes one step backward in the shadow [editor]: the current
  /// selection if one is active (covers both a user-made selection and
  /// a just-pasted block that's still selected), otherwise exactly one
  /// grapheme cluster before the cursor. Uses the `characters` package
  /// (grapheme-cluster aware) rather than a manual UTF-16 surrogate-pair
  /// check, so combining marks, flags and multi-code-unit emoji (ZWJ
  /// sequences) are removed as a single unit and backspace never gets
  /// "stuck" leaving an orphaned half-character behind.
  void _performDelete() {
    final sel = editor.selection;
    final full = editor.text;
    if (full.isEmpty) {
      _composing = '';
      _updateSuggestions();
      return;
    }
    if (sel.isValid && !sel.isCollapsed) {
      final start = sel.start.clamp(0, full.length);
      final end = sel.end.clamp(0, full.length);
      final next = full.replaceRange(start, end, '');
      editor.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start),
      );
      _composing = '';
      _updateSuggestions();
      return;
    }
    final cursor = sel.isValid ? sel.start.clamp(0, full.length) : full.length;
    if (cursor <= 0) return;
    final before = full.substring(0, cursor);
    final after = full.substring(cursor);
    final beforeChars = before.characters;
    if (beforeChars.isEmpty) return;
    final delLen = beforeChars.last.length;
    final next = before.substring(0, before.length - delLen) + after;
    editor.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor - delLen),
    );
    if (_composing.isNotEmpty) {
      final compChars = _composing.characters;
      _composing = compChars.isEmpty ? '' : compChars.skipLast(1).toString();
    }
    _updateSuggestions();
  }

  /// Word-acceleration delete used once a held backspace has been
  /// running for a while (Gboard-style: hold long enough and whole
  /// words disappear per tick instead of single characters). Deletes
  /// any selection first (falls back to [_performDelete]'s selection
  /// path), otherwise removes trailing whitespace immediately before
  /// the cursor plus the whole word before that.
  void _performDeleteWord() {
    final sel = editor.selection;
    final full = editor.text;
    if (full.isEmpty) {
      _composing = '';
      _updateSuggestions();
      return;
    }
    if (sel.isValid && !sel.isCollapsed) {
      _performDelete();
      return;
    }
    final cursor = sel.isValid ? sel.start.clamp(0, full.length) : full.length;
    if (cursor <= 0) return;
    bool isBoundary(String ch) => ch == ' ' || ch == '\n' || ch == '\t';
    int i = cursor;
    while (i > 0 && isBoundary(full[i - 1])) {
      i--;
    }
    while (i > 0 && !isBoundary(full[i - 1])) {
      i--;
    }
    final next = full.replaceRange(i, cursor, '');
    editor.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: i),
    );
    _composing = '';
    _updateSuggestions();
  }

  /// Starts a long-press-and-hold backspace. First tick may need to
  /// remove a host-app selection (see [deleteBackward]); subsequent
  /// repeats always operate on the shadow editor directly (a host-side
  /// selection cannot persist across the first delete). Ticks are
  /// generation-guarded so a stale timer can never fire after
  /// [stopContinuousDelete] has already run (defensive race safety
  /// around the async [hostSelectionDeleter] hop in [deleteBackward]).
  void startContinuousDelete() {
    stopContinuousDelete();
    final myGeneration = ++_deleteGeneration;
    _deleteTickCount = 0;
    deleteBackward();
    _deleteTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (myGeneration != _deleteGeneration) {
        timer.cancel();
        return;
      }
      if (editor.text.isEmpty) {
        stopContinuousDelete();
        return;
      }
      _deleteTickCount++;
      // Gboard-style acceleration: once the hold has run long enough
      // (~1.1s), switch from single-character to whole-word deletion so
      // clearing a long pasted block or several words never feels stuck.
      if (_deleteTickCount > 12) {
        _performDeleteWord();
      } else {
        _performDelete();
      }
      notifyListeners();
    });
  }

  void stopContinuousDelete() {
    _deleteGeneration++;
    _deleteTimer?.cancel();
    _deleteTimer = null;
    _deleteTickCount = 0;
  }

  // =====================================================================
  // Shift / Caps Lock (P0)
  // =====================================================================

  DateTime? _lastShiftTap;

  void tapShift() {
    _feedback();
    final now = DateTime.now();
    final isDouble =
        _lastShiftTap != null &&
        now.difference(_lastShiftTap!) < const Duration(milliseconds: 350);
    _lastShiftTap = now;

    if (isDouble && _shift != ShiftState.capsLock) {
      _shift = ShiftState.capsLock;
    } else {
      switch (_shift) {
        case ShiftState.off:
          _shift = ShiftState.single;
        case ShiftState.single:
          _shift = ShiftState.off;
        case ShiftState.capsLock:
          _shift = ShiftState.off;
      }
    }
    notifyListeners();
  }

  // =====================================================================
  // Layers (P0): alpha <-> numeric <-> symbols
  // =====================================================================

  void setLayer(KeyboardLayer l) {
    _feedback();
    _layer = l;
    notifyListeners();
  }

  // =====================================================================
  // Enter (P0)
  // =====================================================================

  void setEditorAction(EditorAction a) {
    _editorAction = a;
    notifyListeners();
  }

  /// Fired when Enter triggers a host-editor action (send/search/...).
  /// The IME bridge forwards this to InputConnection.performEditorAction.
  void Function(String action)? onEditorActionTriggered;

  /// Returns a human description of what Enter did (for status/testing).
  String pressEnter() {
    // The IME action key is also a real keyboard interaction. Stop an active
    // voice session here as a defensive guard, even if a host widget invokes
    // pressEnter directly instead of going through the key-row callback.
    if (voice.isActive) voice.cancelForKeyPress();
    _feedback();
    _commitComposing();
    switch (_editorAction) {
      case EditorAction.newline:
        _insertRaw('\n');
        notifyListeners();
        return 'newline';
      case EditorAction.send:
      case EditorAction.search:
      case EditorAction.done:
      case EditorAction.next:
        onEditorActionTriggered?.call(_editorAction.name);
        notifyListeners();
        return _editorAction.name;
    }
  }

  // =====================================================================
  // Language / script (P0)
  // =====================================================================

  void setLanguage(LanguagePack pack) {
    // Commit pending text before switching language.
    _commitComposing();
    _lastCommittedWord = '';
    _language = pack;
    _nativePage = 0;
    if (!pack.supportsNative) {
      _scriptMode = ScriptMode.roman;
    } else if (!pack.supportsRoman) {
      _scriptMode = ScriptMode.native;
    }
    voice.setScriptMode(_scriptMode);
    voice.setTranslateTarget(_translateTarget);
    _persist('language', pack.id);
    _persist('scriptMode', _scriptMode.name);
    _updateSuggestions();
    notifyListeners();
  }

  void setScriptMode(ScriptMode mode) {
    if (mode == ScriptMode.native && !_language.supportsNative) return;
    if (mode == ScriptMode.roman && !_language.supportsRoman) return;
    _commitComposing();
    _scriptMode = mode;
    voice.setScriptMode(mode);
    _persist('scriptMode', mode.name);
    _updateSuggestions();
    notifyListeners();
  }

  // =====================================================================
  // Panels
  // =====================================================================

  void togglePanel(ActivePanel p) {
    _feedback();
    _panel = _panel == p ? ActivePanel.none : p;
    _panelKeyboardActive = false;
    _panelInputText = '';
    notifyListeners();
  }

  /// Returns to the main key rows. If a sub-view of the current panel
  /// (e.g. the on-panel mini-keyboard) is open, this first backs out of
  /// that sub-view; a second call fully closes the panel. This gives
  /// every panel a working "back" step even though a single button is
  /// shared for both hide-mini-keyboard and close-panel.
  void closePanel() {
    if (_panelKeyboardActive) {
      _panelKeyboardActive = false;
      notifyListeners();
      return;
    }
    if (_panel == ActivePanel.none) return;
    _panel = ActivePanel.none;
    _panelInputText = '';
    notifyListeners();
  }

  /// Android keeps the IME engine alive while the user switches apps. Reset
  /// transient keyboard state for the newly focused field so Settings, emoji,
  /// symbol pages, and active voice never leak into another app.
  void resetTransientStateForNewInput() {
    if (voice.isActive) voice.cancelForKeyPress();
    _aiCapture.cancel();
    _aiThinking = false;
    _panel = ActivePanel.none;
    _panelKeyboardActive = false;
    _panelInputText = '';
    _layer = KeyboardLayer.alpha;
    _shift = ShiftState.off;
    notifyListeners();
  }

  // =====================================================================
  // Theme & feedback settings
  // =====================================================================

  void setThemeMode(ThemeMode m) {
    _themeMode = m;
    _persist('themeMode', m.name);
    notifyListeners();
  }

  void setHaptics(bool v) {
    _hapticsEnabled = v;
    _persist('haptics', v);
    notifyListeners();
  }

  void setSound(bool v) {
    _soundEnabled = v;
    _persist('sound', v);
    notifyListeners();
  }

  void _feedback() {
    if (_hapticsEnabled) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
    if (_soundEnabled) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  // =====================================================================
  // Voice integration
  // =====================================================================

  /// The language the mic should recognize speech in, per the currently
  /// EFFECTIVE mode ([micMode], not the raw stored [_micMode]):
  /// - Transcribe: the dedicated Transcribe-mode language (default
  ///   Odia), independent of the general typing language.
  /// - Translate: the saved Source language.
  /// - Auto Mix: a synthetic multilingual pack (Sarvam auto-detects).
  LanguagePack get _voiceRecognitionLanguage {
    switch (micMode) {
      case MicMode.transcribe:
        return _transcribeLanguage;
      case MicMode.translate:
        return _translateSource;
      case MicMode.autoMix:
        return _autoMixLanguagePack;
    }
  }

  /// The output script for the current mode, forwarded to the provider.
  ScriptMode get _voiceOutputStyle {
    switch (micMode) {
      case MicMode.transcribe:
        return _transcribeStyle;
      case MicMode.translate:
        return _translateOutputStyle;
      case MicMode.autoMix:
        return _autoMixStyle;
    }
  }

  Future<void> toggleVoice() async {
    if (voice.isActive) {
      await voice.stopSession();
    } else {
      _commitComposing();
      closePanel();
      voice.setScriptMode(_voiceOutputStyle);
      voice.setMicMode(micMode);
      voice.setTranslateTarget(_translateTarget);
      await voice.startSession(_voiceRecognitionLanguage);
    }
    notifyListeners();
  }

  /// Changes the mic mode (Transcribe / Translate / Auto-mix). Applied
  /// on the next voice session; if a session is currently active it is
  /// re-armed immediately so the change takes effect without requiring
  /// the user to manually stop voice typing first.
  ///
  /// Switching directly to Translate here (Method 1: mic settings) uses
  /// whatever config is currently saved (defaults apply the first time)
  /// and counts as a successful activation, matching Method 2's
  /// Save/Apply gate - both paths only ever expose a fully-configured
  /// Translate mode to the mic.
  void setMicMode(MicMode mode) {
    _micMode = mode;
    if (mode == MicMode.translate) _translateEverActivated = true;
    _persist('micMode', mode.name);
    _persist('translateEverActivated', _translateEverActivated);
    if (voice.isActive) {
      voice.stopSession(reason: 'mic-mode-changed');
    }
    notifyListeners();
  }

  void _onVoiceFinal(String rawText) {
    // Committed text is never erased: append finalized speech.
    if (rawText.trim().isEmpty) return;
    final text = rawText.trim();

    // AI Web Assistant middleware (optional, opt-in - see the field docs
    // on [_ai]/[_aiCapture] above). Only ever consulted for
    // Transcribe/Auto Mix, per spec Translate mode's existing behavior
    // is left completely untouched. When the assistant is disabled,
    // this entire block is skipped - zero wake-word scan, zero Tavily/
    // Gemini call, zero behavior change versus the original pipeline.
    if (micMode != MicMode.translate && _aiAssistantEnabled) {
      if (_aiCapture.isCapturing) {
        // A command is already being buffered: this finalized chunk is
        // a continuation of the same spoken command (not new,
        // independent speech) - append it to the buffer and keep
        // waiting for mic-stop/inactivity rather than reacting to this
        // chunk in isolation. Never insert it into the editor.
        _aiCapture.feed(text);
        return;
      }
      if (_ai.matchesWakeWord(text)) {
        // Widen the mic's own silence auto-stop so it never ends the
        // session before the user's configured AI inactivity timeout
        // gets a chance to elapse - restored to the stock default by
        // [_aiCapture]'s onCaptureEnd hook the instant the command
        // finishes (finalized or cancelled). Only ever widens, never
        // shortens, the mic's existing default behavior.
        if (voice.silenceTimeout < _aiCapture.timeout) {
          voice.silenceTimeout = _aiCapture.timeout;
        }
        _aiCapture.start(text);
        return;
      }
    }

    // Transcribe/Auto-mix: provider already returns the correct script -
    // append synchronously (no async hop) so callers/tests observing the
    // editor immediately after this call see the appended text.
    if (micMode != MicMode.translate) {
      _appendVoiceText(text);
      return;
    }
    // Translate mode needs an async pivot-translation step.
    _resolveVoiceText(text).then(_appendVoiceText);
  }

  /// Mic session ended, for any reason (manual stop, silence auto-stop,
  /// error, mode change). If an AI command is still being buffered,
  /// this is the "mic stops" finalize trigger from the spec: finalize
  /// it right away instead of waiting out the rest of the inactivity
  /// timeout unnecessarily. No-op (besides the pre-existing UI refresh)
  /// when nothing is being captured - byte-for-byte the same as the
  /// previous `() => notifyListeners()` session-end callback.
  void _onVoiceSessionEnd() {
    if (_aiCapture.isCapturing) _aiCapture.finalizeNow();
    notifyListeners();
  }

  /// Inserts the AI Web Assistant's formatted result (Gemini's direct
  /// answer, Gemini's summarization of a Tavily result, the plain
  /// title+summary+url fallback, or a friendly error message) into the
  /// active input field, exactly like any other finalized voice text.
  /// Also clears the "Thinking…" indicator and, since [_aiCapture] has
  /// already returned to idle before this fires (see
  /// [AiCommandCapture._complete]), the assistant has now fully exited
  /// AI mode - the very next finalized voice chunk is treated as
  /// ordinary speech again with no extra state to reset.
  void _insertAiAssistantResult(String formattedText) {
    _aiThinking = false;
    _appendVoiceText(formattedText);
  }

  void _appendVoiceText(String text) {
    if (text.trim().isEmpty) return;
    final needsSpace =
        editor.text.isNotEmpty &&
        !editor.text.endsWith(' ') &&
        !editor.text.endsWith('\n');
    _insertRaw('${needsSpace ? ' ' : ''}${text.trim()} ');
    notifyListeners();
  }

  /// Post-processes a finalized voice utterance for Translate mode, using
  /// the saved (not draft) [_translateSource]/[_translateTarget]/
  /// [_translateOutputStyle] - never the general typing [_language].
  ///
  /// Sarvam's server-side `translate` mode (see [SarvamSpeechProvider])
  /// only ever translates speech -> English; there is no server-side
  /// arbitrary-target step. So this always pivots through English:
  ///  1. Obtain English text: either directly from the provider (when
  ///     [_serverSideTranslateSupported] is true), or via the offline
  ///     [_translationEngine] pivoting [_translateSource] -> English
  ///     (fallback path used by e.g. the simulated web-preview provider,
  ///     which always emits source-language text).
  ///  2. If the target IS English, that's the final answer.
  ///  3. Otherwise pivot English -> [_translateTarget] via the offline
  ///     dictionary, which returns native-script target text.
  ///  4. Apply [_translateOutputStyle]: Roman is only meaningful when the
  ///     target is itself Latin-script (English) - [Transliterator] only
  ///     supports Roman -> Native, never the reverse, so there is no way
  ///     to romanize a non-Latin target's native-script result. This is
  ///     a known, documented limitation: native script is returned as
  ///     the best-effort fallback rather than silently dropping the
  ///     translation.
  Future<String> _resolveVoiceText(String text) async {
    if (_micMode != MicMode.translate) return text;
    try {
      String english = text;
      if (!_serverSideTranslateSupported) {
        english = _translateSource.id == 'en'
            ? text
            : await _translationEngine.translate(
                    text,
                    _translateSource,
                    LanguageRegistry.byId('en'),
                  ) ??
                  text;
      }
      if (_translateTarget.id == 'en') {
        return english;
      }
      // Pivot English -> target (native-script result; see limitation
      // above regarding Roman output for non-Latin targets).
      return await _translationEngine.translate(
            english,
            LanguageRegistry.byId('en'),
            _translateTarget,
          ) ??
          english;
    } catch (_) {
      return text;
    }
  }

  /// True when the active [SpeechProvider] performs the speech -> English
  /// translation itself (Sarvam's `translate` mode on saaras:v3). The
  /// simulated web-preview provider has no such server-side mode, so its
  /// output is always source-language text and needs the offline pivot
  /// fallback above.
  bool get _serverSideTranslateSupported => voice.hasNativeTranslateMode;

  /// Cancels voice before a keyboard edit is applied. Key taps must not wait
  /// for the provider's network flush window: that made every key appear
  /// unresponsive while listening. The key-interaction path discards the
  /// partial voice result and stops the provider asynchronously.
  Future<void> keyPressedDuringVoice() async {
    if (voice.isActive) {
      voice.cancelForKeyPress();
    }
  }

  // =====================================================================
  // Text editing (Menu -> Text Editing: select all / cut / copy / paste)
  // =====================================================================

  String? _pendingHostSelection;

  Future<String?> snapshotHostSelection() async {
    _pendingHostSelection = await hostSelectedTextReader?.call();
    return _pendingHostSelection;
  }

  Future<void> _applyWritingTransform(String Function(String) transform) async {
    final reader = hostSelectedTextReader;
    final replacer = hostSelectionReplacer;
    if (reader == null || replacer == null) return;
    final text = _pendingHostSelection ?? await reader();
    _pendingHostSelection = null;
    if (text == null || text.trim().isEmpty) return;
    await replacer(transform(text));
  }

  Future<void> fixGrammar() =>
      _applyWritingTransform(writingAssistant.fixGrammar);

  Future<void> rewriteText({WritingTone tone = WritingTone.clear}) =>
      _applyWritingTransform((text) => writingAssistant.rewrite(text, tone: tone));

  Future<void> suggestReply() =>
      _applyWritingTransform(writingAssistant.suggestReply);

  Future<void> readSelectedTextAloud() async {
    final text = await hostSelectedTextReader?.call();
    if (text != null && text.trim().isNotEmpty) {
      await hostTextSpeaker?.call(text, _language.locale);
    }
  }

  /// Best-effort offline translation for selected host text into the current
  /// keyboard language.
  Future<void> translateSelectedText() =>
      translateSelectedTextTo(_language, speak: false);

  /// Translates selected host text into [target], replaces the selection and,
  /// when requested, reads the translated result aloud in that language.
  Future<void> translateSelectedTextTo(
    LanguagePack target, {
    bool speak = true,
  }) async {
    final reader = hostSelectedTextReader;
    final replacer = hostSelectionReplacer;
    if (reader == null || replacer == null) return;
    final text = _pendingHostSelection ?? await reader();
    _pendingHostSelection = null;
    if (text == null || text.trim().isEmpty) return;
    // Detect the source script automatically; the user only chooses the
    // destination language. This avoids the old trial-through-every-language
    // behavior, which was slow and often selected the wrong source.
    final source = TranslationLanguageDetector.detect(text);
    final english = source.id == 'en'
        ? text
        : await _translationEngine.translate(
              text,
              source,
              LanguageRegistry.byId('en'),
            ) ??
            text;
    final translated = target.id == 'en'
        ? english
        : await _translationEngine.translate(
                english,
                LanguageRegistry.byId('en'),
                target,
              ) ??
              english;
    await replacer(translated);
    if (speak) await hostTextSpeaker?.call(translated, target.locale);
  }

  void selectAll() {
    _feedback();
    _commitComposing();
    editor.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editor.text.length,
    );
    notifyListeners();
  }

  void moveCursorToStart() {
    _feedback();
    // Moving away from the current composing word starts a new editing
    // context. Keeping the old word here makes the next separator/voice
    // commit try to resolve text against the wrong cursor anchor.
    _composing = '';
    editor.selection = const TextSelection.collapsed(offset: 0);
    notifyListeners();
  }

  void moveCursorToEnd() {
    _feedback();
    // A cursor jump invalidates the composing-word anchor.
    _composing = '';
    editor.selection = TextSelection.collapsed(offset: editor.text.length);
    notifyListeners();
  }

  /// Moves the cursor one grapheme cluster left/right (Gboard's cursor
  /// navigation arrows in the Text Editing tools sheet). Collapses an
  /// active selection to its near edge on the first press, matching
  /// standard text-field arrow-key behavior, rather than jumping past
  /// the whole selection.
  void moveCursorLeft() {
    _feedback();
    final sel = editor.selection;
    final full = editor.text;
    if (sel.isValid && !sel.isCollapsed) {
      _composing = '';
      editor.selection = TextSelection.collapsed(offset: sel.start);
      notifyListeners();
      return;
    }
    final cursor = sel.isValid ? sel.start.clamp(0, full.length) : full.length;
    if (cursor <= 0) return;
    final before = full.substring(0, cursor).characters;
    final step = before.isEmpty ? 1 : before.last.length;
    _composing = '';
    editor.selection = TextSelection.collapsed(offset: cursor - step);
    notifyListeners();
  }

  void moveCursorRight() {
    _feedback();
    final sel = editor.selection;
    final full = editor.text;
    if (sel.isValid && !sel.isCollapsed) {
      _composing = '';
      editor.selection = TextSelection.collapsed(offset: sel.end);
      notifyListeners();
      return;
    }
    final cursor = sel.isValid ? sel.start.clamp(0, full.length) : full.length;
    if (cursor >= full.length) return;
    final after = full.substring(cursor).characters;
    final step = after.isEmpty ? 1 : after.first.length;
    _composing = '';
    editor.selection = TextSelection.collapsed(offset: cursor + step);
    notifyListeners();
  }

  /// Cuts the current selection (or the whole text if nothing is
  /// selected) to the system clipboard + clipboard history, removing it
  /// from the editor.
  Future<void> cutSelectionOrAll() async {
    final sel = editor.selection;
    final hasSelection = sel.isValid && !sel.isCollapsed;
    final text = hasSelection
        ? editor.text.substring(sel.start, sel.end)
        : editor.text;
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
    addToClipboardHistory(text);
    if (hasSelection) {
      final next = editor.text.replaceRange(sel.start, sel.end, '');
      editor.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
    } else {
      editor.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    _composing = '';
    _updateSuggestions();
    notifyListeners();
  }

  /// Pastes the system clipboard's current contents (falls back to the
  /// most recent clipboard-history entry when the system clipboard is
  /// unavailable, e.g. widget tests without a real platform clipboard).
  Future<void> pasteFromSystemClipboard() async {
    String? text;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text;
    } catch (_) {}
    text ??= _clipboardHistory.isNotEmpty ? _clipboardHistory.first : null;
    if (text == null || text.isEmpty) return;
    insertContent(text);
  }

  // =====================================================================
  // Clipboard
  // =====================================================================

  Future<void> copySelectionOrAll() async {
    final sel = editor.selection;
    final text = (sel.isValid && !sel.isCollapsed)
        ? editor.text.substring(sel.start, sel.end)
        : editor.text;
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
    addToClipboardHistory(text);
    notifyListeners();
  }

  /// The most recently copied/cut text (drives the Clipboard panel's
  /// "active chip" highlight so the newest entry is visually obvious and
  /// immediately tappable, per spec item 4). Cleared once the user pastes
  /// something else in from history, so the highlight always tracks the
  /// single truly-latest clipboard action rather than staying stuck on
  /// an old entry forever.
  String? _activeClipboardEntry;
  String? get activeClipboardEntry => _activeClipboardEntry;

  /// Transient "Copied" banner shown directly in the toolbar the moment
  /// ANYTHING is copied - whether via this keyboard's own Copy button,
  /// or (thanks to [ImeBridge] watching the system ClipboardManager) by
  /// long-pressing text and tapping "Copy" in WhatsApp, Chrome, or any
  /// other app. This mirrors Gboard's own behavior: the instant you copy
  /// something anywhere, Gboard's suggestion strip flashes a preview
  /// chip of what was just copied, confirming the copy worked and
  /// offering a one-tap paste - addressing "jab main koi chij copy
  /// karta hun to usme dikhana chahiye tha ki yeh chij copy ho gayi,
  /// jaise Gboard dikhata hai". Auto-dismisses after a few seconds, or
  /// immediately when the user taps it (pastes) / starts typing.
  String? _justCopiedText;
  String? get justCopiedText => _justCopiedText;
  Timer? _justCopiedTimer;

  void _showJustCopiedBanner(String text) {
    _justCopiedText = text;
    _justCopiedTimer?.cancel();
    _justCopiedTimer = Timer(const Duration(seconds: 3), () {
      _justCopiedText = null;
      notifyListeners();
    });
  }

  /// Dismisses the "Copied" banner early (tapped to paste, or the user
  /// resumed typing/opened a panel).
  void dismissJustCopiedBanner() {
    if (_justCopiedText == null) return;
    _justCopiedTimer?.cancel();
    _justCopiedText = null;
    notifyListeners();
  }

  void addToClipboardHistory(String text) {
    if (text.trim().isEmpty) return;
    _clipboardHistory.remove(text);
    _clipboardHistory.insert(0, text);
    _activeClipboardEntry = text;
    _showJustCopiedBanner(text);
    while (_clipboardHistory.length > 20) {
      _clipboardHistory.removeLast();
    }
    _persist('clipboard', _clipboardHistory);
    notifyListeners();
  }

  void pasteFromHistory(String text) {
    insertContent(text);
    closePanel();
  }

  void clearClipboardHistory() {
    _clipboardHistory.clear();
    _activeClipboardEntry = null;
    _persist('clipboard', _clipboardHistory);
    notifyListeners();
  }

  // =====================================================================
  // Emoji recents
  // =====================================================================

  void _addRecentEmoji(String emoji) {
    _recentEmojis.remove(emoji);
    _recentEmojis.insert(0, emoji);
    while (_recentEmojis.length > 24) {
      _recentEmojis.removeLast();
    }
    _persist('recentEmojis', _recentEmojis);
  }

  // =====================================================================
  // Sticker recents
  // =====================================================================

  /// Records [id] (a sticker's stable identifier, see StickerPanel's
  /// `_StickerEntry.id`) as most-recently-used, capped at 24 - mirrors
  /// [_addRecentEmoji]'s dedup/cap/persist behavior so the Sticker
  /// panel's "Recent" tab works exactly like the Emoji panel's.
  void addRecentSticker(String id) {
    _recentStickers.remove(id);
    _recentStickers.insert(0, id);
    while (_recentStickers.length > 24) {
      _recentStickers.removeLast();
    }
    _persist('recentStickers', _recentStickers);
    notifyListeners();
  }

  // =====================================================================
  // Suggestions
  // =====================================================================

  void _updateSuggestions() {
    if (_composing.isEmpty && _lastCommittedWord.isNotEmpty) {
      // Nothing composing yet: show Gboard-style next-word predictions
      // based on the previously committed word.
      final predicted = suggestions.nextWordSuggestions(
        _language.id,
        _lastCommittedWord,
        limit: 3,
      );
      if (predicted.isNotEmpty) {
        _suggestionList = predicted;
        return;
      }
    }
    _suggestionList = suggestions.suggest(
      _composing,
      _language,
      _scriptMode,
      limit: 3,
    );
  }

  /// Replace all editor text (used by translation insert/replace).
  void replaceSelectionWith(String text) {
    final sel = editor.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final next = editor.text.replaceRange(sel.start, sel.end, text);
      editor.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start + text.length),
      );
    } else {
      insertContent(text);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _deleteTimer?.cancel();
    _justCopiedTimer?.cancel();
    voice.removeListener(notifyListeners);
    voice.dispose();
    _aiCapture.dispose();
    _ai.dispose();
    super.dispose();
  }
}
