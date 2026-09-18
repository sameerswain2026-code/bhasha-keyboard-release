/// Translate Configuration Page (Method 2: opened from the toolbar's
/// Translate icon). Lets the user pick Source / Target / Output style
/// from all 23 languages, but - per spec - none of it takes effect
/// until the explicit Save/Apply button is pressed. Editing here only
/// touches [KeyboardController]'s draft fields; [applyTranslateConfig]
/// is the sole path that commits the draft, switches the live mic mode
/// to Translate, and swaps the mic-side indicator to the Translate Page
/// icon. Until Apply is pressed, the mic keeps behaving exactly as it
/// did before this page was opened (Transcribe by default).
///
/// Layout: a single compact ROW - "Speak in" | swap arrow | "Translate
/// to" side-by-side, with the Output style chips and Save button
/// directly below - so everything fits within the fixed keyboard-panel
/// height with no vertical scrolling (spec item 3).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/languages.dart';
import '../kb_theme.dart';

class TranslateConfigPanel extends StatelessWidget {
  const TranslateConfigPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    Widget langColumn(
      String label,
      LanguagePack current,
      void Function(LanguagePack) onChanged,
    ) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
            ),
            const SizedBox(height: 4),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: t.keyBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: current.id,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: t.panelBg,
                  style: TextStyle(fontSize: 12.5, color: t.keyText),
                  items: [
                    for (final p in kLanguagePacks)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.englishName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) onChanged(LanguageRegistry.byId(id));
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget styleChip(ScriptMode mode, String label) {
      final selected = kb.draftStyle == mode;
      return Expanded(
        child: InkWell(
          onTap: () => kb.setDraftStyle(mode),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? t.accent : t.keyBg,
              borderRadius: BorderRadius.circular(12),
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
        ),
      );
    }

    return Container(
      color: t.panelBg,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to keyboard',
                icon: Icon(Icons.arrow_back, size: 20, color: t.icon),
                onPressed: kb.closePanel,
              ),
              Icon(Icons.translate, size: 16, color: t.icon),
              const SizedBox(width: 8),
              Text(
                'Translate mode setup',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.keyText,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Compact horizontal row: Speak in <-> Translate to.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              langColumn('Speak in', kb.draftSource, kb.setDraftSource),
              Padding(
                padding: const EdgeInsets.only(bottom: 9, left: 6, right: 6),
                child: Icon(Icons.arrow_forward, size: 18, color: t.icon),
              ),
              langColumn('Translate to', kb.draftTarget, kb.setDraftTarget),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Output style',
            style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              styleChip(ScriptMode.roman, 'Roman (abc)'),
              const SizedBox(width: 8),
              styleChip(ScriptMode.native, 'Native script'),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 38,
            child: FilledButton.icon(
              onPressed: kb.applyTranslateConfig,
              icon: const Icon(Icons.check, size: 16),
              label: const Text(
                'Save & activate Translate mode',
                style: TextStyle(fontSize: 12.5),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.accentText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
