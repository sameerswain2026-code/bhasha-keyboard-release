/// Local snippets and personal dictionary panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class SnippetsPanel extends StatelessWidget {
  const SnippetsPanel({super.key});

  Future<void> _openApp() async {
    try {
      await const MethodChannel('bhasha/ime').invokeMethod('openManagementApp');
    } catch (_) {}
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
                  onPressed: _openApp,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open full editor in app'),
              ),
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
                          title: Text(
                            item.alias,
                            style: TextStyle(color: theme.keyText),
                          ),
                          subtitle: Text(
                            item.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.keyTextSecondary),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            onPressed: () => kb.deleteSnippet(item.alias),
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.keyTextSecondary,
                            ),
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
