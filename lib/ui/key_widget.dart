/// Individual key widget with press feedback and long-press support.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kb_theme.dart';

class KeyWidget extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onHorizontalDragStart;
  final ValueChanged<double>? onHorizontalDragUpdate;
  final VoidCallback? onHorizontalDragEnd;
  final bool special;
  final bool active;
  final int flex;
  final double fontSize;

  /// Key-height multiplier driven by the Menu's Resize feature
  /// (KeyboardController.sizeScale, clamped 0.82-1.18). Only height
  /// scales - width stays flex-driven so rows never overflow.
  final double heightScale;

  const KeyWidget({
    super.key,
    this.label,
    this.icon,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.special = false,
    this.active = false,
    this.flex = 1,
    this.fontSize = 21,
    this.heightScale = 1.0,
  });

  @override
  State<KeyWidget> createState() => _KeyWidgetState();
}

class _KeyWidgetState extends State<KeyWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);
    final bg = _pressed
        ? t.keyBgPressed
        : widget.active
        ? t.accent
        : widget.special
        ? t.keyBgSpecial
        : t.keyBg;
    final fg = widget.active ? t.accentText : t.keyText;

    return Expanded(
      flex: widget.flex,
      child: Padding(
        // Tighter gutters make each key body and hit target larger without
        // changing the fixed keyboard width.
        padding: const EdgeInsets.all(1.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            // Give fast typing immediate tactile confirmation, before the
            // text insertion callback returns.
            HapticFeedback.lightImpact();
            setState(() => _pressed = true);
          },
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () {
            setState(() => _pressed = false);
            widget.onLongPressEnd?.call();
          },
          onTap: widget.onTap,
          onHorizontalDragStart: widget.onHorizontalDragStart == null
              ? null
              : (_) => widget.onHorizontalDragStart!.call(),
          onHorizontalDragUpdate: widget.onHorizontalDragUpdate == null
              ? null
              : (details) => widget.onHorizontalDragUpdate!(details.delta.dx),
          onHorizontalDragEnd: widget.onHorizontalDragEnd == null
              ? null
              : (_) => widget.onHorizontalDragEnd!.call(),
          onLongPressStart: widget.onLongPressStart == null
              ? null
              : (_) {
                  widget.onLongPressStart!.call();
                },
          onLongPressEnd: widget.onLongPressEnd == null
              ? null
              : (_) {
                  setState(() => _pressed = false);
                  widget.onLongPressEnd!.call();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            // Base height raised from 46 -> 55: the standalone language
            // sub-bar row beneath the toolbar was removed (spec item 2),
            // and that reclaimed vertical space is redistributed into
            // the keys themselves rather than left empty, while the
            // overall keyboard container height budget stays identical
            // (see `_kBodyHeight`/`_kFullBodyHeight` in keyboard_view.dart).
            //
            // Budget check (4 key rows, each wrapped in EdgeInsets.all(1.5)
            // padding, inside an outer Padding.fromLTRB(2,2,2,4)):
            //   4 * (55 + 3) + 6 = 238, which fits within the 246dp
            //   `_kBodyHeight` budget with a few dp of margin to spare.
            //   (56 was tried first and overflowed by ~4dp - see history.)
            height: 55 * widget.heightScale,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: widget.icon != null
                ? Icon(
                    widget.icon,
                    size: 22,
                    color: widget.active ? t.accentText : t.icon,
                  )
                : Text(
                    widget.label ?? '',
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
