/// Text Editing tools (Menu -> Text Editing): select all, cut, copy,
/// paste, jump to start/end - a compact Gboard-style action sheet
/// rather than a full clipboard browser (that remains the dedicated
/// Clipboard toolbar icon/panel).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/languages.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class TextEditingPanel extends StatelessWidget {
  const TextEditingPanel({super.key});

  Future<void> _chooseTranslationLanguage(
    BuildContext context,
    KeyboardController kb,
    KbTheme theme,
  ) async {
    final selected = await kb.snapshotHostSelection();
    if (selected == null || selected.trim().isEmpty || !context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.panelBg,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 360,
          child: ListView.builder(
            itemCount: LanguageRegistry.all.length,
            itemBuilder: (_, index) {
              final pack = LanguageRegistry.all[index];
              return ListTile(
                leading: Text(pack.nativeName),
                title: Text(pack.englishName),
                subtitle: Text(pack.locale),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await kb.translateSelectedTextTo(pack, speak: true);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    Widget action(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: t.keyBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: t.icon),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: t.keyTextSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: t.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
            child: Row(
              children: [
                const PanelBackButton(),
                Icon(Icons.text_fields, size: 16, color: t.icon),
                const SizedBox(width: 8),
                Text(
                  'Text Editing',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  action(Icons.select_all, 'Select all', kb.selectAll),
                  action(Icons.content_cut, 'Cut', kb.cutSelectionOrAll),
                  action(Icons.content_copy, 'Copy', kb.copySelectionOrAll),
                  action(
                    Icons.content_paste,
                    'Paste',
                    kb.pasteFromSystemClipboard,
                  ),
                  action(Icons.first_page, 'Go to start', kb.moveCursorToStart),
                  action(Icons.chevron_left, 'Cursor left', kb.moveCursorLeft),
                  action(
                    Icons.chevron_right,
                    'Cursor right',
                    kb.moveCursorRight,
                  ),
                  action(Icons.last_page, 'Go to end', kb.moveCursorToEnd),
                  action(
                    Icons.translate,
                    'Translate selection',
                    () => _chooseTranslationLanguage(context, kb, t),
                  ),
                  action(
                    Icons.volume_up_outlined,
                    'Read selection',
                    kb.readSelectedTextAloud,
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
