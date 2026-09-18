/// Resize tool (Menu -> Resize): adjusts key height via
/// [KeyboardController.sizeScale]. A real OS-level IME window resize is
/// outside what this Flutter host can control - the slider instead
/// scales key height live, which is directly visible and testable in
/// every host (web preview, widget tests, and the real Android IME).
/// `onChanged` updates the scale on every drag tick with zero haptic
/// overhead (see [KeyboardController.setSizeScale]) so dragging feels
/// perfectly smooth/real-time; a single haptic pulse fires only on
/// `onChangeEnd` (release) for tactile confirmation.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class ResizePanel extends StatelessWidget {
  const ResizePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    return Container(
      color: t.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
            child: Row(
              children: [
                const PanelBackButton(),
                Icon(
                  Icons.photo_size_select_large_outlined,
                  size: 16,
                  color: t.icon,
                ),
                const SizedBox(width: 8),
                Text(
                  'Resize keyboard',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.keyText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_outlined, size: 40, color: t.accent),
                  const SizedBox(height: 12),
                  Text(
                    'Key height: ${(kb.sizeScale * 100).round()}%',
                    style: TextStyle(fontSize: 13, color: t.keyText),
                  ),
                  Slider(
                    value: kb.sizeScale,
                    min: 0.82,
                    max: 1.18,
                    divisions: 18,
                    activeColor: t.accent,
                    label: '${(kb.sizeScale * 100).round()}%',
                    onChanged: kb.setSizeScale,
                    onChangeEnd: (_) => kb.hapticTick(),
                  ),
                  TextButton(
                    onPressed: () {
                      kb.setSizeScale(1.0);
                      kb.hapticTick();
                    },
                    child: Text(
                      'Reset',
                      style: TextStyle(fontSize: 12, color: t.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
