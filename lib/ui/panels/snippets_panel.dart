/// Local snippets and personal dictionary panel.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class SnippetsPanel extends StatelessWidget {
  const SnippetsPanel({super.key});

  Future<void> _add(BuildContext context, KeyboardController kb) async {
    final alias = TextEditingController();
    final value = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add snippet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: alias,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Shortcut or voice phrase',
                hintText: 'email id one',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: value,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Text to insert',
                hintText: 'name@example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [alias.text, value.text]),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    alias.dispose();
    value.dispose();
    if (result != null && result.length == 2) {
      kb.saveSnippet(result[0], result[1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final theme = KbTheme.of(context);
    return Container(
      color: theme.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
            child: Row(
              children: [
                const PanelBackButton(),
                Icon(Icons.auto_awesome, size: 17, color: theme.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Snippets & Dictionary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.keyText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add snippet',
                  onPressed: () => _add(context, kb),
                  icon: Icon(Icons.add, color: theme.accent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Text(
              'Say or type the shortcut to insert your saved text. Stored only on this device.',
              style: TextStyle(fontSize: 11, color: theme.keyTextSecondary),
            ),
          ),
          Expanded(
            child: kb.localSnippets.isEmpty
                ? Center(
                    child: Text(
                      'No snippets yet\nTap + to add an email, phone number, or biodata.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.keyTextSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: kb.localSnippets.length,
                    itemBuilder: (_, index) {
                      final item = kb.localSnippets[index];
                      return Card(
                        color: theme.keyBg,
                        child: ListTile(
                          dense: true,
                          title: Text(item.alias, style: TextStyle(color: theme.keyText)),
                          subtitle: Text(
                            item.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.keyTextSecondary),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            onPressed: () => kb.deleteSnippet(item.alias),
                            icon: Icon(Icons.delete_outline, color: theme.keyTextSecondary),
                          ),
                          onTap: () {
                            kb.insertContent(item.value);
                            kb.closePanel();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
