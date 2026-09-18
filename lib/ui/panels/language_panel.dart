/// Language picker: clean aligned scrollable list of all 22 languages,
/// with search and separate script-mode selection.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/languages.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class LanguagePanel extends StatelessWidget {
  const LanguagePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);
    final langs = LanguageRegistry.search(kb.panelInputText);

    return Container(
      color: t.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
            child: Row(
              children: [
                const PanelBackButton(),
                const SizedBox(width: 4),
                Expanded(child: PanelTextField(hintText: 'Search languages')),
              ],
            ),
          ),
          if (kb.panelKeyboardActive)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: const PanelMiniKeyboard(),
              ),
            )
          else ...[
            // Script mode toggle (only relevant choices shown)
            if (kb.language.supportsNative && kb.language.supportsRoman)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      'Input mode:',
                      style: TextStyle(fontSize: 12, color: t.keyTextSecondary),
                    ),
                    const SizedBox(width: 8),
                    _modeChip(kb, t, ScriptMode.roman, 'Roman (abc)'),
                    const SizedBox(width: 6),
                    _modeChip(kb, t, ScriptMode.native, 'Native script'),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: langs.length,
                itemBuilder: (context, i) {
                  final lang = langs[i];
                  final selected = kb.language.id == lang.id;
                  return InkWell(
                    onTap: () {
                      kb.setLanguage(lang);
                      // Compact workflow: return to typing immediately.
                      kb.closePanel();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.accent.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              lang.nativeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? t.accent : t.keyText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang.englishName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: t.keyTextSecondary,
                              ),
                            ),
                          ),
                          if (lang.voiceAvailable)
                            Icon(
                              Icons.mic_none,
                              size: 15,
                              color: t.keyTextSecondary,
                            ),
                          const SizedBox(width: 6),
                          if (selected)
                            Icon(Icons.check_circle, size: 18, color: t.accent),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(
    KeyboardController kb,
    KbTheme t,
    ScriptMode mode,
    String label,
  ) {
    final selected = kb.scriptMode == mode;
    return InkWell(
      onTap: () => kb.setScriptMode(mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.keyBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? t.accent : t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? t.accentText : t.keyText,
          ),
        ),
      ),
    );
  }
}
