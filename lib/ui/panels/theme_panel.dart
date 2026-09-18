/// Theme selection panel: Light, Dark, System.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class ThemePanel extends StatelessWidget {
  const ThemePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    return Container(
      color: t.panelBg,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PanelBackButton(),
              Icon(Icons.palette_outlined, size: 17, color: t.icon),
              const SizedBox(width: 8),
              Text(
                'Keyboard theme',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.keyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _themeCard(
                context,
                kb,
                ThemeMode.light,
                'Light',
                Icons.light_mode_outlined,
                KbTheme.light,
              ),
              const SizedBox(width: 10),
              _themeCard(
                context,
                kb,
                ThemeMode.dark,
                'Dark',
                Icons.dark_mode_outlined,
                KbTheme.dark,
              ),
              const SizedBox(width: 10),
              _themeCard(
                context,
                kb,
                ThemeMode.system,
                'System',
                Icons.brightness_auto_outlined,
                null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeCard(
    BuildContext context,
    KeyboardController kb,
    ThemeMode mode,
    String label,
    IconData icon,
    KbTheme? preview,
  ) {
    final t = KbTheme.of(context);
    final selected = kb.themeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => kb.setThemeMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: preview?.background ?? t.keyBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: preview?.keyText ?? t.icon),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: preview?.keyText ?? t.keyText,
                ),
              ),
              const SizedBox(height: 4),
              if (selected) Icon(Icons.check_circle, size: 17, color: t.accent),
            ],
          ),
        ),
      ),
    );
  }
}
