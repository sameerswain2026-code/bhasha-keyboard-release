/// IME bridge: mirrors the KeyboardController's editor text into the
/// host app's text field via the Android InputConnection.
///
/// The keyboard logic (transliteration, suggestions, voice, composing)
/// all operates on the controller's internal editor exactly like the
/// demo app. This bridge observes that editor and forwards *diffs*
/// (delete N, insert S) to the native IME service, so committed text in
/// WhatsApp/Telegram/any app always matches what the engine produced.
library;

import 'package:flutter/services.dart';

import '../core/keyboard_controller.dart';

class ImeBridge {
  ImeBridge(this.kb) {
    _lastSynced = kb.editor.text;
    kb.editor.addListener(_onEditorChanged);
    _channel.setMethodCallHandler(_onNativeCall);
    kb.hostSelectionDeleter = _deleteHostSelection;
    kb.hostSelectedTextReader = getHostSelectedText;
    kb.hostSelectionReplacer = replaceHostSelectedText;
    kb.hostTextSpeaker = speakText;
    kb.hostMediaSharer = shareMedia;
  }

  static const MethodChannel _channel = MethodChannel('bhasha/ime');

  final KeyboardController kb;
  String _lastSynced = '';
  int _lastSelectionStart = 0;
  int _lastSelectionEnd = 0;
  bool _muted = false;
  Future<void> _editQueue = Future<void>.value();

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'startInput':
        final args = (call.arguments as Map?) ?? {};
        final action = args['action'] as String? ?? 'newline';
        // Android keeps one IME FlutterEngine alive across apps. Clear any
        // open settings/panel/symbol page and stop voice before the new host
        // field is shown, so WhatsApp -> Telegram never resumes in Settings.
        kb.resetTransientStateForNewInput();
        kb.setEditorAction(
          EditorAction.values.firstWhere(
            (a) => a.name == action,
            orElse: () => EditorAction.newline,
          ),
        );
        // A freshly-focused field may already contain text (an existing
        // draft, a quoted reply, text left over from before this IME
        // attached) - resync from the host's ACTUAL text instead of
        // blindly clearing, otherwise the shadow mirror starts out of
        // sync with a non-empty field and backspace no-ops until the
        // user types at least one new character first.
        await _resyncEditorFromHost();
      case 'finishInput':
        kb.resetTransientStateForNewInput();
        _resetEditor();
      case 'externalTextChanged':
        // The host's text changed by a means we did NOT initiate -
        // native "Paste"/"Cut" from the Android text-selection menu,
        // autocorrect, or any other out-of-band edit (see
        // BhashaImeService.onUpdateSelection). Resync the shadow
        // mirror to the host's real text so subsequent backspace/typing
        // diffs correctly instead of silently no-op'ing against stale
        // state - this is the fix for the reported "paste karke delete
        // nahi hota" bug.
        final args = call.arguments;
        if (args is Map) {
          final before = (args['before'] as String?) ?? '';
          final after = (args['after'] as String?) ?? '';
          _applySyncedText(before, after);
        } else {
          await _resyncEditorFromHost();
        }
      case 'externalClipboardChanged':
        // Text was copied in ANY app (not just via our own Copy
        // button) - surface it the same way Gboard highlights a fresh
        // system-clipboard entry, so the user sees visual confirmation
        // that "yes, this was copied" right in the keyboard toolbar.
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          kb.addToClipboardHistory(text);
        }
    }
  }

  /// Applies host-reported surrounding text directly (avoids a second
  /// async round-trip back to the native side when the native callback
  /// already included before/after text). Routes through
  /// [KeyboardController.syncFromHost] so any in-flight composing word
  /// is correctly dropped too, not just the raw editor text.
  void _applySyncedText(String before, String after) {
    _muted = true;
    kb.syncFromHost(before, after);
    _lastSynced = kb.editor.text;
    _lastSelectionStart = before.length;
    _lastSelectionEnd = before.length;
    _muted = false;
  }

  void _resetEditor() {
    _muted = true;
    kb.editor.clear();
    _lastSynced = '';
    _lastSelectionStart = 0;
    _lastSelectionEnd = 0;
    _muted = false;
  }

  /// Re-syncs the shadow [kb.editor] mirror to the host app's ACTUAL
  /// current text (queried directly via InputConnection), instead of
  /// blindly clearing it to empty. Blindly clearing was the root cause
  /// of a delete-button bug: after deleting a host-side selection that
  /// did not cover the whole field (e.g. 20 chars, select+delete 19),
  /// the shadow mirror falsely believed the field was completely empty,
  /// so the next backspace's `if (full.isEmpty) return;` guard silently
  /// no-op'd instead of deleting the 1 remaining character.
  Future<void> _resyncEditorFromHost() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getSurroundingText',
      );
      final before = (result?['before'] as String?) ?? '';
      final after = (result?['after'] as String?) ?? '';
      _applySyncedText(before, after);
    } catch (_) {
      // Fall back to the old (imperfect but safe) behaviour if the
      // native side doesn't support the new method yet.
      _resetEditor();
    }
  }

  void _onEditorChanged() {
    if (_muted) return;
    final now = kb.editor.text;
    final selection = kb.editor.selection;
    final selectionStart = selection.isValid ? selection.start : now.length;
    final selectionEnd = selection.isValid ? selection.end : now.length;
    final selectionChanged =
        selectionStart != _lastSelectionStart ||
        selectionEnd != _lastSelectionEnd;

    // Cursor navigation in the keyboard changes only the shadow editor's
    // selection. Forward that selection to the real host field before the
    // next text diff is applied; otherwise the host cursor remains at the
    // old location and a mid-text edit can replay/duplicate the whole tail.
    if (now == _lastSynced) {
      if (!selectionChanged) return;
      _lastSelectionStart = selectionStart;
      _lastSelectionEnd = selectionEnd;
      _editQueue = _editQueue.then((_) async {
        try {
          await _channel.invokeMethod('setSelection', {
            'start': selectionStart,
            'end': selectionEnd,
          });
        } catch (_) {}
      });
      return;
    }

    // Compute the smallest changed range using both a common prefix and a
    // common suffix. The previous implementation deleted everything after
    // the prefix from the host caret and inserted the new tail. That only
    // worked at the end of the buffer; in the middle it could delete the
    // wrong side of the caret and then replay the unchanged tail, causing
    // cursor jumps and duplication.
    var prefix = 0;
    final minLen = now.length < _lastSynced.length
        ? now.length
        : _lastSynced.length;
    while (prefix < minLen &&
        now.codeUnitAt(prefix) == _lastSynced.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < now.length - prefix &&
        suffix < _lastSynced.length - prefix &&
        now.codeUnitAt(now.length - 1 - suffix) ==
            _lastSynced.codeUnitAt(_lastSynced.length - 1 - suffix)) {
      suffix++;
    }

    // Avoid splitting a surrogate pair at either boundary.
    if (prefix > 0 && prefix < now.length) {
      final cu = now.codeUnitAt(prefix - 1);
      if (cu >= 0xD800 && cu <= 0xDBFF) prefix--;
    }
    if (suffix > 0 && suffix < now.length) {
      final cu = now.codeUnitAt(now.length - suffix);
      if (cu >= 0xDC00 && cu <= 0xDFFF) suffix--;
    }

    final oldEnd = _lastSynced.length - suffix;
    final insertEnd = now.length - suffix;
    final insertText = now.substring(prefix, insertEnd);

    _lastSynced = now;
    _lastSelectionStart = selectionStart;
    _lastSelectionEnd = selectionEnd;
    // Serialize every host edit. Sending multiple platform-channel edits
    // concurrently lets selection callbacks race the next edit and was the
    // main cause of cursor jumps after paste/transliteration.
    _editQueue = _editQueue.then((_) async {
      try {
        await _channel.invokeMethod('replaceRange', {
          'start': prefix,
          'end': oldEnd,
          'text': insertText,
        });
      } catch (_) {
        // The host may have closed the field; the next startInput will
        // perform a fresh authoritative resync.
      }
    });
  }

  /// Forward a non-newline enter action to the host editor.
  Future<void> performAction(String action) async {
    try {
      await _channel.invokeMethod('performAction', {'action': action});
    } catch (_) {}
  }

  /// Asks the native side to delete the host app's ACTUAL selection
  /// (e.g. text highlighted with the native selection handles in
  /// WhatsApp/Telegram). The shadow [kb.editor] mirror has no knowledge
  /// of selections made directly in the host app, so backspace on a
  /// selection there would otherwise only delete a single character
  /// from the (unrelated) shadow cursor position. Returns true if a
  /// non-empty selection existed and was deleted; the native side also
  /// resets the diff baseline so subsequent typing diffs correctly.
  Future<String?> getHostSelectedText() async {
    try {
      final text = await _channel.invokeMethod<String>('getSelectedText');
      if (text != null && text.trim().isNotEmpty) return text;
      final clipboard = await _channel.invokeMethod<String>('getClipboardText');
      return clipboard?.trim().isEmpty == true ? null : clipboard;
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceHostSelectedText(String text) async {
    try {
      await _channel.invokeMethod('replaceSelectedText', {'text': text});
    } catch (_) {}
  }

  Future<void> speakText(String text, String locale) async {
    try {
      await _channel.invokeMethod('speakText', {
        'text': text,
        'locale': locale,
      });
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
  }

  Future<void> shareMedia(String source, String mimeType, String title) async {
    try {
      await _channel.invokeMethod('shareMedia', {
        'source': source,
        'mimeType': mimeType,
        'title': title,
      });
    } catch (_) {}
  }

  Future<bool> _deleteHostSelection() async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteHostSelection');
      if (result == true) {
        // Host text changed outside of our diff tracking - resync the
        // shadow mirror to the host's ACTUAL remaining text (not just
        // blindly cleared) so a subsequent backspace on any leftover
        // characters works correctly.
        await _resyncEditorFromHost();
      }
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    kb.editor.removeListener(_onEditorChanged);
  }
}
