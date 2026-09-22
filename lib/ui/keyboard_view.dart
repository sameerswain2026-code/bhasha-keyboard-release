/// Main keyboard view: toolbar (with dynamic status/suggestions), key
/// rows, and panels.
///
/// Height budget (must sum to the native IME window's fixed
/// `KEYBOARD_HEIGHT_DP = 292` - see BhashaImeService.kt - so the overall
/// container bounds never change regardless of what's showing):
///   Toolbar (idle):      46
///   Key rows (idle):    246
///   ---------------------------------
///   Total (idle):       292
///
/// When any panel is open, the outer toolbar is hidden (every panel
/// already renders its own back-button/header row, so keeping the outer
/// toolbar visible too just wasted space and made GIF/Emoji/Sticker
/// results feel cramped) and the panel expands to use the FULL 292
/// budget instead of only the 246 key-rows portion - this is the fix for
/// spec item 5's "expand the viewable area upward" requirement.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/keyboard_controller.dart';
import '../data/languages.dart';
import '../data/layouts.dart';
import '../engine/voice_engine.dart';
import 'kb_theme.dart';
import 'key_widget.dart';
import 'mic_indicator.dart';
import 'panels/clipboard_panel.dart';
import 'panels/emoji_panel.dart';
import 'panels/gif_panel.dart';
import 'panels/language_panel.dart';
import 'panels/menu_panel.dart';
import 'panels/resize_panel.dart';
import 'panels/settings_panel.dart';
import 'panels/sticker_panel.dart';
import 'panels/text_editing_panel.dart';
import 'panels/theme_panel.dart';
import 'panels/translate_config_panel.dart';

const double _kToolbarHeight = 46;
const double _kBodyHeight = 246;
const double _kFullBodyHeight = _kToolbarHeight + _kBodyHeight; // 292

class KeyboardView extends StatelessWidget {
  const KeyboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    final panelOpen = kb.panel != ActivePanel.none;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!panelOpen) _Toolbar(kb: kb),
        if (panelOpen)
          SizedBox(height: _kFullBodyHeight, child: _panelFor(kb.panel))
        else
          SizedBox(
            height: _kBodyHeight,
            child: _OneHandedFrame(
              kb: kb,
              child: _KeyRows(kb: kb),
            ),
          ),
      ],
    );

    if (kb.floatingEnabled) {
      return _FloatingWrapper(kb: kb, t: t, child: content);
    }

    return Container(color: t.background, child: content);
  }

  Widget _panelFor(ActivePanel p) {
    switch (p) {
      case ActivePanel.menu:
        return const MenuPanel();
      case ActivePanel.emoji:
        return const EmojiPanel();
      case ActivePanel.gif:
        return const GifPanel();
      case ActivePanel.sticker:
        return const StickerPanel();
      case ActivePanel.textEditing:
        return const TextEditingPanel();
      case ActivePanel.resize:
        return const ResizePanel();
      case ActivePanel.translateConfig:
        return const TranslateConfigPanel();
      case ActivePanel.clipboard:
        return const ClipboardPanel();
      case ActivePanel.language:
        return const LanguagePanel();
      case ActivePanel.settings:
        return const SettingsPanel();
      case ActivePanel.theme:
        return const ThemePanel();
      case ActivePanel.none:
        return const SizedBox.shrink();
    }
  }
}

// ===========================================================================
// Floating Keyboard (spec item 11 / Tools & Mode Functionality)
// ===========================================================================

/// Simulates Gboard's floating keyboard: a draggable, dockable card that
/// visually detaches from the bottom-anchored layout. A REAL OS-level
/// floating IME window (overlaying the host app outside this view's own
/// bounds) is a native Android WindowManager feature this Flutter host
/// cannot reach - BhashaImeService hosts a single fixed-size FrameLayout
/// with no overlay window, and Flutter has no visibility into anything
/// drawn above/behind its own view. Within what this host DOES control,
/// this gives Floating Keyboard genuine, working detach + drag + dock
/// behavior: the keyboard becomes a smaller rounded card with a drag
/// handle that can be moved anywhere within the available surface, and
/// a Dock button that snaps it back to the default bottom position.
class _FloatingWrapper extends StatelessWidget {
  final KeyboardController kb;
  final KbTheme t;
  final Widget child;
  const _FloatingWrapper({
    required this.kb,
    required this.t,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final docked = kb.floatingOffset == Offset.zero;
    return Container(
      color: t.background.withValues(alpha: 0.35),
      child: Center(
        child: Transform.translate(
          offset: kb.floatingOffset,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: t.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) =>
                      kb.setFloatingOffset(kb.floatingOffset + d.delta),
                  child: Container(
                    height: 22,
                    color: t.stripBg,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: t.keyTextSecondary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        if (!docked) ...[
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: kb.dockFloating,
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: t.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// One-Handed Mode (inline Gboard-style compact control)
// ===========================================================================

/// Constrains and side-anchors the key rows when One-Handed Mode is
/// active, matching Gboard's own inline design: the keys shrink to hug
/// the chosen edge (width driven by [KeyboardController.oneHandedWidthFraction],
/// live-draggable - see reference screenshot's corner drag handles),
/// with a slim inline switch/expand control strip filling the gap on
/// the other side - never a separate full-screen settings page. A no-op
/// wrapper when off.
class _OneHandedFrame extends StatelessWidget {
  final KeyboardController kb;
  final Widget child;
  const _OneHandedFrame({required this.kb, required this.child});

  @override
  Widget build(BuildContext context) {
    final side = kb.oneHandedSide;
    if (side == OneHandedSide.off) return child;
    final t = KbTheme.of(context);

    final controls = Container(
      color: t.panelBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Switch side',
            icon: Icon(
              side == OneHandedSide.left
                  ? Icons.chevron_right
                  : Icons.chevron_left,
              size: 22,
              color: t.accent,
            ),
            onPressed: () => kb.setOneHandedSide(
              side == OneHandedSide.left
                  ? OneHandedSide.right
                  : OneHandedSide.left,
            ),
          ),
          IconButton(
            tooltip: 'Resize',
            icon: Icon(
              Icons.open_with,
              size: 20,
              color: kb.oneHandedAdjusting ? t.accent : t.icon,
            ),
            onPressed: kb.enterOneHandedAdjust,
          ),
          IconButton(
            tooltip: 'Exit one-handed mode',
            icon: Icon(Icons.fullscreen, size: 22, color: t.icon),
            onPressed: () => kb.setOneHandedSide(OneHandedSide.off),
          ),
        ],
      ),
    );

    final widthFraction = (kb.oneHandedWidthFraction * 100).round();
    final gapFraction = 100 - widthFraction;
    final keys = Expanded(flex: widthFraction, child: child);
    final side22 = Expanded(flex: gapFraction, child: controls);

    final row = Row(
      children: side == OneHandedSide.left ? [keys, side22] : [side22, keys],
    );

    if (!kb.oneHandedAdjusting) return row;
    return _OneHandedResizeOverlay(kb: kb, side: side, child: row);
  }
}

/// Gboard-style resize overlay (see reference screenshot): drag handles
/// on the corner of the one-handed keyboard's outer edge let the user
/// live-resize the keys area, with explicit "Reset" / "Done" buttons -
/// entered via the control strip's resize icon, exited via "Done".
class _OneHandedResizeOverlay extends StatelessWidget {
  final KeyboardController kb;
  final OneHandedSide side;
  final Widget child;
  const _OneHandedResizeOverlay({
    required this.kb,
    required this.side,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        void onDrag(double dx) {
          // Left-anchored: dragging the RIGHT edge right grows the keys
          // area. Right-anchored: dragging the LEFT edge left grows it
          // (mirrored, since keys hug the opposite edge).
          final delta =
              (side == OneHandedSide.left ? dx : -dx) / constraints.maxWidth;
          kb.setOneHandedWidthFraction(kb.oneHandedWidthFraction + delta);
        }

        final handle = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onDrag(d.delta.dx),
          child: Container(
            width: 26,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.drag_indicator, size: 16, color: t.accentText),
          ),
        );

        final edgeFraction = kb.oneHandedWidthFraction;
        final handleLeft = side == OneHandedSide.left
            ? constraints.maxWidth * edgeFraction - 13
            : constraints.maxWidth * (1 - edgeFraction) - 13;

        return Stack(
          children: [
            // Dim the keys slightly so the overlay controls read clearly
            // on top, matching the reference screenshot's translucent
            // resize mode.
            Positioned.fill(
              child: IgnorePointer(child: Opacity(opacity: 0.55, child: child)),
            ),
            Positioned(
              left: handleLeft,
              top: 0,
              bottom: 0,
              child: Center(child: handle),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _pillButton(t, 'Reset', kb.resetOneHandedWidth),
                  _pillButton(t, 'Done', kb.exitOneHandedAdjust, filled: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pillButton(
    KbTheme t,
    String label,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? t.accent : t.keyBg,
          borderRadius: BorderRadius.circular(18),
          border: filled ? null : Border.all(color: t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: filled ? t.accentText : t.keyText,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Toolbar (merged with dynamic status/suggestions - spec item 2)
// ===========================================================================

/// Main toolbar: Menu, Clipboard, Translate, Settings icons evenly
/// distributed across the full width, plus the mic-mode indicator and
/// mic button. There is no longer a separate "language sub-bar" row
/// beneath it (the old fallback "English · abc" indicator has been
/// removed entirely per spec) - when voice typing or general typing
/// produces a status/suggestions to show, that content dynamically
/// takes over the tool-icon area instead (Menu remains reachable via a
/// single persistent icon), and the reclaimed vertical space that the
/// old sub-bar used to occupy has been redistributed into taller keys
/// (see key_widget.dart).
class _Toolbar extends StatelessWidget {
  final KeyboardController kb;
  const _Toolbar({required this.kb});

  @override
  Widget build(BuildContext context) {
    final voiceActive = kb.voice.isActive;
    final voice = kb.voice;
    final hasDynamicContent =
        voice.state == VoiceState.initializing ||
        voice.state == VoiceState.listening ||
        voice.state == VoiceState.stopping ||
        voice.state == VoiceState.error ||
        kb.aiCapturing ||
        kb.aiThinking ||
        kb.justCopiedText != null ||
        kb.suggestionList.isNotEmpty;

    Widget iconSlot(
      IconData icon,
      ActivePanel panel,
      String tooltip, {
      VoidCallback? onTap,
    }) {
      final selected = kb.panel == panel;
      return Expanded(
        child: Center(
          child: _ToolbarButton(
            icon: icon,
            tooltip: tooltip,
            selected: selected,
            onTap: onTap ?? () => kb.togglePanel(panel),
          ),
        ),
      );
    }

    return Container(
      height: _kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (hasDynamicContent) ...[
            Expanded(
              flex: 1,
              child: Center(
                child: _ToolbarButton(
                  icon: Icons.apps,
                  tooltip: 'Menu',
                  selected: kb.panel == ActivePanel.menu,
                  onTap: () => kb.togglePanel(ActivePanel.menu),
                ),
              ),
            ),
            Expanded(flex: 3, child: _DynamicStatusOrSuggestions(kb: kb)),
          ] else ...[
            iconSlot(Icons.apps, ActivePanel.menu, 'Menu'),
            iconSlot(Icons.content_paste, ActivePanel.clipboard, 'Clipboard'),
            iconSlot(
              Icons.translate,
              ActivePanel.translateConfig,
              'Translate',
              onTap: kb.openTranslateConfig,
            ),
            iconSlot(Icons.settings_outlined, ActivePanel.settings, 'Settings'),
          ],
          Expanded(
            flex: 1,
            child: Center(child: MicIndicator(kb: kb)),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _ToolbarButton(
                icon: voiceActive ? Icons.mic : Icons.mic_none,
                tooltip: voiceActive ? 'Stop voice typing' : 'Voice typing',
                selected: voiceActive,
                highlight: voiceActive,
                onTap: () => kb.toggleVoice(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 36,
          decoration: BoxDecoration(
            color: highlight
                ? Colors.redAccent.withValues(alpha: 0.9)
                : selected
                ? t.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 21,
            color: highlight
                ? Colors.white
                : selected
                ? t.accent
                : t.icon,
          ),
        ),
      ),
    );
  }
}

/// The dynamic content that takes over the toolbar's icon area while
/// voice typing is active or word suggestions are available (spec item
/// 2's "Dynamic Status & Word Suggestions").
class _DynamicStatusOrSuggestions extends StatelessWidget {
  final KeyboardController kb;
  const _DynamicStatusOrSuggestions({required this.kb});

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);
    final voice = kb.voice;

    Widget child;
    if (kb.aiThinking) {
      // AI Router request in flight (Gemini/Tavily) - subtle "Thinking…"
      // indicator, shown until the response is inserted and AI mode
      // auto-exits (see KeyboardController._insertAiAssistantResult).
      child = Row(
        key: const ValueKey('ai-thinking'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Thinking…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: t.suggestionText,
              ),
            ),
          ),
        ],
      );
    } else if (kb.aiCapturing) {
      // Wake word detected - buffering the full command until the mic
      // stops or the inactivity timeout elapses (see AiCommandCapture).
      // Takes priority over the generic voice-status row below since
      // the mic session stays active (VoiceState.listening) throughout
      // capture.
      child = Row(
        key: const ValueKey('ai-listening'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PulsingDot(color: t.accent),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Listening…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: t.suggestionText,
              ),
            ),
          ),
        ],
      );
    } else if (voice.state == VoiceState.initializing ||
        voice.state == VoiceState.listening ||
        voice.state == VoiceState.stopping) {
      child = Row(
        key: const ValueKey('voice-status'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (voice.state == VoiceState.listening)
            _PulsingDot(color: Colors.redAccent)
          else
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              voice.partialText.isNotEmpty
                  ? voice.partialText
                  : voice.statusMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: voice.partialText.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: t.suggestionText,
              ),
            ),
          ),
        ],
      );
    } else if (voice.state == VoiceState.error) {
      child = InkWell(
        key: const ValueKey('voice-error'),
        onTap: kb.toggleVoice,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, size: 15, color: Colors.orange),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                voice.statusMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.suggestionText),
              ),
            ),
          ],
        ),
      );
    } else if (kb.justCopiedText != null) {
      // Gboard-style "Copied" confirmation: flashes right where the
      // word suggestions normally sit the instant text is copied
      // (whether via this keyboard's own Copy action or copied natively
      // in any other app - see ImeBridge's system-clipboard listener),
      // previewing what was copied and offering an immediate one-tap
      // paste. Auto-dismisses itself after a few seconds.
      final preview = kb.justCopiedText!.replaceAll('\n', ' ').trim();
      child = InkWell(
        key: const ValueKey('just-copied'),
        onTap: () async {
          kb.dismissJustCopiedBanner();
          kb.pasteFromHistory(preview);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.copy_all, size: 15, color: t.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Copied: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.accent,
                        ),
                      ),
                      TextSpan(
                        text: preview,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: t.suggestionText,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: kb.dismissJustCopiedBanner,
                child: Icon(Icons.close, size: 14, color: t.keyTextSecondary),
              ),
            ],
          ),
        ),
      );
    } else {
      final list = kb.suggestionList;
      child = Row(
        key: const ValueKey('suggestions'),
        children: [
          for (int i = 0; i < list.length; i++) ...[
            if (i > 0) Container(width: 1, height: 18, color: t.border),
            Expanded(
              child: InkWell(
                onTap: () => kb.applySuggestion(list[i]),
                child: Center(
                  child: Text(
                    list[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                      color: t.suggestionText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: child,
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ===========================================================================
// Key rows
// ===========================================================================

class _KeyRows extends StatelessWidget {
  final KeyboardController kb;
  const _KeyRows({required this.kb});

  @override
  Widget build(BuildContext context) {
    switch (kb.layer) {
      case KeyboardLayer.alpha:
        return _AlphaLayer(kb: kb);
      case KeyboardLayer.numeric:
        return _GridLayer(kb: kb, layout: kNumeric, isNumeric: true);
      case KeyboardLayer.symbols:
        return _GridLayer(kb: kb, layout: kSymbols, isNumeric: false);
    }
  }
}

class _AlphaLayer extends StatelessWidget {
  final KeyboardController kb;
  const _AlphaLayer({required this.kb});

  Future<void> _key(String c) async {
    await kb.keyPressedDuringVoice();
    kb.insertText(c);
  }

  @override
  Widget build(BuildContext context) {
    final layoutLanguage = kb.keyboardLanguage;
    final nativePages =
        kb.keyboardScriptMode == ScriptMode.native && !layoutLanguage.isLatin
        ? nativeLayoutPagesFor(layoutLanguage)
        : const <LayoutRows>[];
    final layout = nativePages.isNotEmpty
        ? nativePages[kb.nativePage % nativePages.length]
        : layoutFor(layoutLanguage, kb.keyboardScriptMode);
    final isLatin = layout == kQwerty;
    final shiftActive = kb.shift != ShiftState.off;

    String display(String c) => (isLatin && shiftActive) ? c.toUpperCase() : c;

    final fontSize = isLatin ? 21.0 : 19.0;

    final scale = kb.sizeScale;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final c in layout.rows[0])
                KeyWidget(
                  label: display(c),
                  fontSize: fontSize,
                  heightScale: scale,
                  onTap: () => _key(c),
                ),
            ],
          ),
          Row(
            children: [
              const Spacer(flex: 1),
              for (final c in layout.rows[1])
                KeyWidget(
                  label: display(c),
                  fontSize: fontSize,
                  flex: 2,
                  heightScale: scale,
                  onTap: () => _key(c),
                ),
              const Spacer(flex: 1),
            ],
          ),
          Row(
            children: [
              KeyWidget(
                icon: kb.shift == ShiftState.capsLock
                    ? Icons.keyboard_capslock
                    : Icons.arrow_upward,
                special: true,
                active: kb.shift != ShiftState.off,
                flex: 3,
                heightScale: scale,
                onTap: () async {
                  await kb.keyPressedDuringVoice();
                  kb.tapShift();
                },
              ),
              for (final c in layout.rows[2])
                KeyWidget(
                  label: display(c),
                  fontSize: fontSize,
                  flex: 2,
                  heightScale: scale,
                  onTap: () => _key(c),
                ),
              KeyWidget(
                icon: Icons.backspace_outlined,
                special: true,
                flex: 3,
                heightScale: scale,
                onTap: () async {
                  await kb.keyPressedDuringVoice();
                  kb.deleteBackward();
                },
                onLongPressStart: () async {
                  await kb.keyPressedDuringVoice();
                  kb.startContinuousDelete();
                },
                onLongPressEnd: kb.stopContinuousDelete,
                onHorizontalDragStart: () async {
                  await kb.keyPressedDuringVoice();
                  kb.startSwipeDelete();
                },
                onHorizontalDragUpdate: kb.updateSwipeDelete,
                onHorizontalDragEnd: kb.endSwipeDelete,
              ),
            ],
          ),
          _BottomRow(kb: kb),
        ],
      ),
    );
  }
}

class _GridLayer extends StatelessWidget {
  final KeyboardController kb;
  final LayoutRows layout;
  final bool isNumeric;
  const _GridLayer({
    required this.kb,
    required this.layout,
    required this.isNumeric,
  });

  @override
  Widget build(BuildContext context) {
    final scale = kb.sizeScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final c in layout.rows[0])
                KeyWidget(
                  label: c,
                  heightScale: scale,
                  onTap: () async {
                    await kb.keyPressedDuringVoice();
                    kb.insertText(c);
                  },
                ),
            ],
          ),
          Row(
            children: [
              const Spacer(flex: 1),
              for (final c in layout.rows[1])
                KeyWidget(
                  label: c,
                  flex: 2,
                  heightScale: scale,
                  onTap: () async {
                    await kb.keyPressedDuringVoice();
                    kb.insertText(c);
                  },
                ),
              const Spacer(flex: 1),
            ],
          ),
          Row(
            children: [
              KeyWidget(
                label: isNumeric ? '=\\<' : '?123',
                special: true,
                fontSize: 14,
                flex: 3,
                heightScale: scale,
                onTap: () => kb.setLayer(
                  isNumeric ? KeyboardLayer.symbols : KeyboardLayer.numeric,
                ),
              ),
              for (final c in layout.rows[2])
                KeyWidget(
                  label: c,
                  flex: 2,
                  heightScale: scale,
                  onTap: () async {
                    await kb.keyPressedDuringVoice();
                    kb.insertText(c);
                  },
                ),
              KeyWidget(
                icon: Icons.backspace_outlined,
                special: true,
                flex: 3,
                heightScale: scale,
                onTap: () async {
                  await kb.keyPressedDuringVoice();
                  kb.deleteBackward();
                },
                onLongPressStart: () async {
                  await kb.keyPressedDuringVoice();
                  kb.startContinuousDelete();
                },
                onLongPressEnd: kb.stopContinuousDelete,
                onHorizontalDragStart: () async {
                  await kb.keyPressedDuringVoice();
                  kb.startSwipeDelete();
                },
                onHorizontalDragUpdate: kb.updateSwipeDelete,
                onHorizontalDragEnd: kb.endSwipeDelete,
              ),
            ],
          ),
          _BottomRow(kb: kb),
        ],
      ),
    );
  }
}

class _BottomRow extends StatelessWidget {
  final KeyboardController kb;
  const _BottomRow({required this.kb});

  IconData _enterIcon() {
    switch (kb.editorAction) {
      case EditorAction.send:
        return Icons.send;
      case EditorAction.search:
        return Icons.search;
      case EditorAction.done:
        return Icons.check;
      case EditorAction.next:
        return Icons.arrow_forward;
      case EditorAction.newline:
        return Icons.keyboard_return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAlpha = kb.layer == KeyboardLayer.alpha;
    final layoutLanguage = kb.keyboardLanguage;
    final canToggleScript =
        layoutLanguage.supportsNative && layoutLanguage.supportsRoman;
    final scale = kb.sizeScale;

    return Row(
      children: [
        KeyWidget(
          label: isAlpha ? '?123' : 'ABC',
          special: true,
          fontSize: 14,
          flex: 3,
          heightScale: scale,
          onTap: () async {
            await kb.keyPressedDuringVoice();
            kb.setLayer(isAlpha ? KeyboardLayer.numeric : KeyboardLayer.alpha);
          },
        ),
        // Script-toggle / globe key: tap switches Native<->Roman when the
        // typing language supports both (else types a comma); long-press
        // ALWAYS opens the general typing-language selector - Gboard's
        // own convention for a globe key, and this app's only remaining
        // entry point to the typing language now that mic-mode language
        // selection lives entirely beside the mic instead (see
        // MicIndicator), never in the toolbar/Menu.
        KeyWidget(
          label: canToggleScript
              ? (kb.keyboardScriptMode == ScriptMode.roman ? 'क' : 'a')
              : ',',
          special: canToggleScript,
          fontSize: canToggleScript ? 16 : 21,
          flex: 2,
          heightScale: scale,
          onTap: () async {
            if (canToggleScript) {
              final next = kb.keyboardScriptMode == ScriptMode.roman
                  ? ScriptMode.native
                  : ScriptMode.roman;
              if (kb.micMode == MicMode.translate) {
                kb.setTranslateOutputStyle(next);
              } else {
                kb.setScriptMode(next);
              }
            } else {
              await kb.keyPressedDuringVoice();
              kb.insertText(',');
            }
          },
          onLongPressStart: () => kb.togglePanel(ActivePanel.language),
        ),
        if (kb.keyboardScriptMode == ScriptMode.native &&
            !layoutLanguage.isLatin)
          KeyWidget(
            label: '${kb.nativePage + 1}/${kb.nativePageCount}',
            special: true,
            fontSize: 11,
            flex: 2,
            heightScale: scale,
            onTap: kb.nextNativePage,
          ),
        // Dedicated Emoji key (spec item 9): opens the emoji picker
        // immediately, directly from the main layout - independent of
        // (and functionally identical to) the Menu's Emoji option.
        KeyWidget(
          icon: Icons.emoji_emotions_outlined,
          special: true,
          flex: 2,
          heightScale: scale,
          onTap: () async {
            await kb.keyPressedDuringVoice();
            kb.togglePanel(ActivePanel.emoji);
          },
        ),
        KeyWidget(
          // Make the language-switch affordance discoverable. Holding this
          // key opens the language selector, matching the requested Gboard
          // interaction while keeping a normal tap as Space.
          label: 'English',
          fontSize: 13,
          flex: 8,
          heightScale: scale,
          onTap: () async {
            await kb.keyPressedDuringVoice();
            kb.insertText(' ');
          },
          onLongPressStart: () => kb.togglePanel(ActivePanel.language),
        ),
        KeyWidget(
          label: '.',
          flex: 2,
          heightScale: scale,
          onTap: () async {
            await kb.keyPressedDuringVoice();
            kb.insertText('.');
          },
        ),
        KeyWidget(
          icon: _enterIcon(),
          special: true,
          flex: 3,
          heightScale: scale,
          onTap: () async {
            await kb.keyPressedDuringVoice();
            kb.pressEnter();
          },
        ),
      ],
    );
  }
}
