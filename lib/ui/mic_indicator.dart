/// Dynamic mic-side indicator.
/// Auto detects the spoken language; the user chooses only Native or Roman.
library;

import 'package:flutter/material.dart';

import '../core/keyboard_controller.dart';
import '../data/languages.dart';
import '../engine/voice_engine.dart';
import 'kb_theme.dart';

class MicIndicator extends StatelessWidget {
  final KeyboardController kb;
  const MicIndicator({super.key, required this.kb});

  @override
  Widget build(BuildContext context) {
    final theme = KbTheme.of(context);
    if (kb.micMode == MicMode.translate) {
      return _IndicatorButton(
        icon: Icons.g_translate,
        tooltip: '${kb.translateSource.englishName} -> ${kb.translateTarget.englishName}',
        selected: kb.panel == ActivePanel.translateConfig,
        onTap: kb.openTranslateConfig,
      );
    }
    return _AutoButton(kb: kb, theme: theme);
  }
}

class _IndicatorButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _IndicatorButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = KbTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? theme.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 19, color: selected ? theme.accent : theme.icon),
        ),
      ),
    );
  }
}

class _AutoButton extends StatelessWidget {
  final KeyboardController kb;
  final KbTheme theme;
  const _AutoButton({required this.kb, required this.theme});

  Future<void> _showChoices(BuildContext context, Offset position) async {
    final selected = await showMenu<ScriptMode>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy - 90, position.dx, 0),
      items: [
        _choice(ScriptMode.roman, 'Roman (abc)'),
        _choice(ScriptMode.native, 'Native script'),
      ],
    );
    if (selected != null) kb.setAutoMixStyle(selected);
  }

  PopupMenuItem<ScriptMode> _choice(ScriptMode mode, String label) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          if (kb.autoMixStyle == mode)
            Icon(Icons.check, size: 16, color: theme.accent)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTapDown: (details) => _showChoices(context, details.globalPosition),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: theme.accent),
            const SizedBox(width: 4),
            Text(
              'Auto',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.accent),
            ),
          ],
        ),
      ),
    );
  }
}
