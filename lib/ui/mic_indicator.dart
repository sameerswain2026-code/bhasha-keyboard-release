/// Dynamic mic-side indicator, per spec:
/// - Transcribe -> Language Selector icon (opens the 23-language x
///   Native/Roman Transcribe selector; default Odia + Roman).
/// - Translate -> Translate Page icon (opens the Translate Configuration
///   Page, pre-seeded with the currently SAVED config so edits are
///   drafts until Save/Apply again).
/// - Auto Mix -> "Auto Mix" button; tapping shows exactly 2 options
///   (Roman / Native) with a checkmark on the active one - implemented
///   as a small popup menu rather than a full panel, since the spec
///   only calls for a 2-item choice, not a screen.
///
/// This indicator lives immediately beside the mic in the toolbar, NOT
/// inside the Menu grid (the Menu never contains mic mode/language
/// controls per spec).
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
    final t = KbTheme.of(context);
    switch (kb.micMode) {
      case MicMode.transcribe:
        return _IndicatorButton(
          icon: Icons.language,
          tooltip:
              '${kb.transcribeLanguage.englishName} · ${kb.transcribeStyle == ScriptMode.roman ? 'Roman' : 'Native'}',
          selected: kb.panel == ActivePanel.transcribeLang,
          onTap: () => kb.togglePanel(ActivePanel.transcribeLang),
        );
      case MicMode.translate:
        return _IndicatorButton(
          icon: Icons.g_translate,
          tooltip:
              '${kb.translateSource.englishName} -> ${kb.translateTarget.englishName}',
          selected: kb.panel == ActivePanel.translateConfig,
          onTap: kb.openTranslateConfig,
        );
      case MicMode.autoMix:
        return _AutoMixButton(kb: kb, t: t);
    }
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
    final t = KbTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 34,
          decoration: BoxDecoration(
            color: selected
                ? t.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: selected ? t.accent : t.icon),
        ),
      ),
    );
  }
}

class _AutoMixButton extends StatelessWidget {
  final KeyboardController kb;
  final KbTheme t;
  const _AutoMixButton({required this.kb, required this.t});

  Future<void> _showChoices(BuildContext context, Offset globalPos) async {
    final selected = await showMenu<ScriptMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy - 90,
        globalPos.dx,
        0,
      ),
      items: [
        PopupMenuItem(
          value: ScriptMode.roman,
          child: Row(
            children: [
              if (kb.autoMixStyle == ScriptMode.roman)
                Icon(Icons.check, size: 16, color: t.accent)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              const Text('Roman (abc)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ScriptMode.native,
          child: Row(
            children: [
              if (kb.autoMixStyle == ScriptMode.native)
                Icon(Icons.check, size: 16, color: t.accent)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              const Text('Native script'),
            ],
          ),
        ),
      ],
    );
    if (selected != null) kb.setAutoMixStyle(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTapDown: (details) => _showChoices(context, details.globalPosition),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shuffle, size: 16, color: t.accent),
                const SizedBox(width: 4),
                Text(
                  'Auto Mix',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
