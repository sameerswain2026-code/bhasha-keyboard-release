/// Shared widgets for panel-embedded text input (search bars, translate
/// source text).
///
/// Background: the Flutter app running here IS the Android system
/// keyboard. Tapping a normal [TextField] inside a panel cannot summon
/// a second on-screen keyboard - Android will not stack an IME on top
/// of the IME that is currently active. So instead of a real TextField,
/// panels show a tappable "field" that opens a compact QWERTY
/// mini-keyboard docked inside the panel itself; key taps are captured
/// through [KeyboardController.panelInputText] rather than sent to the
/// host app's text field.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/layouts.dart';
import '../kb_theme.dart';

/// A tappable field that looks like a search bar. Tapping it opens the
/// on-panel mini-keyboard (see [PanelMiniKeyboard]) instead of trying
/// (and failing) to summon the system keyboard.
class PanelTextField extends StatelessWidget {
  final String hintText;
  final IconData leadingIcon;

  const PanelTextField({
    super.key,
    this.hintText = 'Search',
    this.leadingIcon = Icons.search,
  });

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);
    final text = kb.panelInputText;
    final active = kb.panelKeyboardActive;

    return SizedBox(
      height: 34,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => kb.openPanelKeyboard(initialText: text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.keyBg,
            borderRadius: BorderRadius.circular(18),
            border: active ? Border.all(color: t.accent, width: 1.3) : null,
          ),
          child: Row(
            children: [
              Icon(leadingIcon, size: 18, color: t.icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isEmpty ? hintText : text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: text.isEmpty ? t.keyTextSecondary : t.keyText,
                  ),
                ),
              ),
              if (text.isNotEmpty)
                InkWell(
                  onTap: kb.panelKeyboardClear,
                  child: Icon(Icons.clear, size: 16, color: t.icon),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact QWERTY mini-keyboard rendered inside a panel while
/// [KeyboardController.panelKeyboardActive] is true.
///
/// Gboard never hides the search results while the user types - the
/// mini-keyboard docks to the bottom of the panel and live results stay
/// visible in the space above it. To make that layout fit the fixed
/// 292dp panel budget, [compact] shrinks key height/padding so this
/// keyboard occupies a smaller fixed strip (see `_kCompactHeight`)
/// instead of the panel's full body height.
class PanelMiniKeyboard extends StatefulWidget {
  /// Called when the user taps the checkmark ("done") button.
  final VoidCallback? onDone;

  /// When true, renders at a reduced height so it can be docked below a
  /// still-visible, still-live-filtering results grid (Gboard's actual
  /// GIF/sticker/emoji search behaviour) rather than replacing it.
  final bool compact;

  const PanelMiniKeyboard({super.key, this.onDone, this.compact = false});

  /// Fixed height to reserve for the compact variant (used by callers
  /// laying out the results-area-above-keyboard split).
  static const double compactHeight = 140;

  @override
  State<PanelMiniKeyboard> createState() => _PanelMiniKeyboardState();
}

/// Shift/layer state for the embedded mini-keyboard.
///
/// This mirrors [KeyboardController]'s own `ShiftState`/`KeyboardLayer`
/// state machine and the exact same rows (`kQwerty`/`kNumeric`/
/// `kSymbols` from layouts.dart - the "existing keyboard engine") so
/// typing behavior here is identical to the main keyboard. It is kept
/// local to this widget rather than stored on [KeyboardController]
/// because the panel mini-keyboard is a separate, simultaneous typing
/// surface (e.g. a GIF search box) - toggling Shift/Caps/Numeric here
/// must never also flip the main keyboard's own Shift/layer state (and
/// vice versa), which is what sharing the controller's fields would do.
class _PanelMiniKeyboardState extends State<PanelMiniKeyboard> {
  ShiftState _shift = ShiftState.off;
  KeyboardLayer _layer = KeyboardLayer.alpha;
  DateTime? _lastShiftTap;

  /// Same 350ms double-tap-for-caps-lock window as
  /// [KeyboardController.tapShift].
  void _tapShift() {
    final now = DateTime.now();
    final isDouble =
        _lastShiftTap != null &&
        now.difference(_lastShiftTap!) < const Duration(milliseconds: 350);
    _lastShiftTap = now;
    setState(() {
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
    });
  }

  void _setLayer(KeyboardLayer l) {
    setState(() => _layer = l);
  }

  /// Applies the same uppercase-and-consume-single-shift transform as
  /// [KeyboardController.insertText] before forwarding the character to
  /// [KeyboardController.panelKeyboardInsert].
  void _insertLetter(KeyboardController kb, String raw) {
    var text = raw;
    if (_shift != ShiftState.off) {
      text = text.toUpperCase();
      if (_shift == ShiftState.single) {
        setState(() => _shift = ShiftState.off);
      }
    }
    kb.panelKeyboardInsert(text);
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.read<KeyboardController>();
    final t = KbTheme.of(context);

    final double keyH = widget.compact ? 28 : 38;
    final double pad = widget.compact ? 1.5 : 2;
    final double fontSize = widget.compact ? 14 : 16;
    final double iconSize = widget.compact ? 15 : 18;

    switch (_layer) {
      case KeyboardLayer.alpha:
        return _buildAlpha(kb, t, keyH, pad, fontSize, iconSize);
      case KeyboardLayer.numeric:
        return _buildGrid(
          kb,
          t,
          keyH,
          pad,
          fontSize,
          iconSize,
          kNumeric,
          isNumeric: true,
        );
      case KeyboardLayer.symbols:
        return _buildGrid(
          kb,
          t,
          keyH,
          pad,
          fontSize,
          iconSize,
          kSymbols,
          isNumeric: false,
        );
    }
  }

  Widget _buildAlpha(
    KeyboardController kb,
    KbTheme t,
    double keyH,
    double pad,
    double fontSize,
    double iconSize,
  ) {
    final shiftActive = _shift != ShiftState.off;
    String display(String c) => shiftActive ? c.toUpperCase() : c;

    Widget key(String label, {int flex = 1}) => Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: PanelMiniKey(
          height: keyH,
          color: t.keyBg,
          pressedColor: t.keyBgPressed,
          onTap: () => _insertLetter(kb, label),
          child: Text(
            display(label),
            style: TextStyle(fontSize: fontSize, color: t.keyText),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [for (final c in kQwerty.rows[0]) key(c)]),
        Row(
          children: [
            const Spacer(flex: 1),
            for (final c in kQwerty.rows[1]) key(c, flex: 2),
            const Spacer(flex: 1),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: PanelMiniKey(
                  height: keyH,
                  color: shiftActive ? t.accent : t.keyBgSpecial,
                  pressedColor: t.keyBgPressed,
                  onTap: _tapShift,
                  child: Icon(
                    _shift == ShiftState.capsLock
                        ? Icons.keyboard_capslock
                        : Icons.arrow_upward,
                    size: iconSize,
                    color: shiftActive ? t.accentText : t.icon,
                  ),
                ),
              ),
            ),
            for (final c in kQwerty.rows[2]) key(c, flex: 2),
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: PanelMiniKey(
                  height: keyH,
                  color: t.keyBgSpecial,
                  pressedColor: t.keyBgPressed,
                  onTap: kb.panelKeyboardBackspace,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: iconSize,
                    color: t.icon,
                  ),
                ),
              ),
            ),
          ],
        ),
        _buildBottomRow(kb, t, keyH, pad, iconSize, isAlpha: true),
      ],
    );
  }

  Widget _buildGrid(
    KeyboardController kb,
    KbTheme t,
    double keyH,
    double pad,
    double fontSize,
    double iconSize,
    LayoutRows layout, {
    required bool isNumeric,
  }) {
    Widget key(String label, {int flex = 1}) => Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: PanelMiniKey(
          height: keyH,
          color: t.keyBg,
          pressedColor: t.keyBgPressed,
          onTap: () => kb.panelKeyboardInsert(label),
          child: Text(
            label,
            style: TextStyle(fontSize: fontSize, color: t.keyText),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [for (final c in layout.rows[0]) key(c)]),
        Row(
          children: [
            const Spacer(flex: 1),
            for (final c in layout.rows[1]) key(c, flex: 2),
            const Spacer(flex: 1),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: PanelMiniKey(
                  height: keyH,
                  color: t.keyBgSpecial,
                  pressedColor: t.keyBgPressed,
                  onTap: () => _setLayer(
                    isNumeric ? KeyboardLayer.symbols : KeyboardLayer.numeric,
                  ),
                  child: Text(
                    isNumeric ? '=\\<' : '?123',
                    style: TextStyle(fontSize: 12, color: t.keyText),
                  ),
                ),
              ),
            ),
            for (final c in layout.rows[2]) key(c, flex: 2),
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: PanelMiniKey(
                  height: keyH,
                  color: t.keyBgSpecial,
                  pressedColor: t.keyBgPressed,
                  onTap: kb.panelKeyboardBackspace,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: iconSize,
                    color: t.icon,
                  ),
                ),
              ),
            ),
          ],
        ),
        _buildBottomRow(kb, t, keyH, pad, iconSize, isAlpha: false),
      ],
    );
  }

  Widget _buildBottomRow(
    KeyboardController kb,
    KbTheme t,
    double keyH,
    double pad,
    double iconSize, {
    required bool isAlpha,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: PanelMiniKey(
              height: keyH,
              color: t.keyBgSpecial,
              pressedColor: t.keyBgPressed,
              onTap: () => _setLayer(
                isAlpha ? KeyboardLayer.numeric : KeyboardLayer.alpha,
              ),
              child: Text(
                isAlpha ? '?123' : 'ABC',
                style: TextStyle(fontSize: 12, color: t.keyText),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: PanelMiniKey(
              height: keyH,
              color: t.keyBg,
              pressedColor: t.keyBgPressed,
              onTap: () => kb.panelKeyboardInsert(' '),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: PanelMiniKey(
              height: keyH,
              color: t.accent,
              pressedColor: t.accent.withValues(alpha: 0.7),
              onTap: () {
                kb.closePanelKeyboard();
                widget.onDone?.call();
              },
              child: Icon(Icons.check, size: iconSize + 2, color: t.accentText),
            ),
          ),
        ),
      ],
    );
  }
}

/// Generic tap-feedback wrapper: a subtle scale-down plus a soft dark
/// overlay while pressed, giving GIF/Emoji/Sticker grid tiles (and any
/// other tappable panel content) the same kind of tactile feedback the
/// main keyboard's own keys already have (see [KeyWidget] in
/// key_widget.dart). Purely visual - [onTap] fires exactly as before,
/// so this never changes what tapping something does, only how it
/// looks while it's being tapped.
class PanelPressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final Color overlayColor;
  final double pressedScale;

  const PanelPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = BorderRadius.zero,
    this.overlayColor = const Color(0x33000000),
    this.pressedScale = 0.94,
  });

  @override
  State<PanelPressable> createState() => _PanelPressableState();
}

class _PanelPressableState extends State<PanelPressable> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  color: _pressed ? widget.overlayColor : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single mini-keyboard key with the same tactile "swap to a darker
/// fill + slight scale-down" press feedback as the main keyboard's
/// [KeyWidget] - previously these keys used a bare [InkWell] with no
/// visible feedback at all while typing.
class PanelMiniKey extends StatefulWidget {
  final Widget child;
  final Color color;
  final Color pressedColor;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const PanelMiniKey({
    super.key,
    required this.child,
    required this.color,
    required this.pressedColor,
    required this.height,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  State<PanelMiniKey> createState() => PanelMiniKeyState();
}

class PanelMiniKeyState extends State<PanelMiniKey> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          height: widget.height,
          decoration: BoxDecoration(
            color: _pressed ? widget.pressedColor : widget.color,
            borderRadius: widget.borderRadius,
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Standard "back to main keyboard" button used by every panel header.
/// Distinct back-arrow affordance (rather than the ambiguous
/// "keyboard_hide" glyph) so it's unmistakably a navigation action, not
/// a "dismiss the whole keyboard" action.
class PanelBackButton extends StatelessWidget {
  const PanelBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.read<KeyboardController>();
    final t = KbTheme.of(context);
    return IconButton(
      tooltip: 'Back to keyboard',
      icon: Icon(Icons.arrow_back, size: 20, color: t.icon),
      onPressed: kb.closePanel,
    );
  }
}
