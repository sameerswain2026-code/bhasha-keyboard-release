/// Compact keyboard-side view of the pronunciation dictionary.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class DictionaryPanel extends StatelessWidget {
  const DictionaryPanel({super.key});

  Future<void> _openApp() async {
    try {
      await const MethodChannel('bhasha/ime').invokeMethod('openManagementApp');
    } catch (_) {}
  }

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
                Icon(Icons.record_voice_over_outlined, size: 17, color: t.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dictionary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.keyText,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openApp,
                  tooltip: 'Manage in app',
                  icon: Icon(Icons.open_in_new, color: t.accent),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Text(
              'Correct words that voice recognition often hears incorrectly. Manage comfortably in the app.',
              style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
            ),
          ),
          Expanded(
            child: kb.dictionaryEntries.isEmpty
                ? Center(
                    child: Text(
                      'No corrections yet.\nOpen the app to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.keyTextSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: kb.dictionaryEntries.length,
                    itemBuilder: (_, index) {
                      final item = kb.dictionaryEntries[index];
                      return Card(
                        color: t.keyBg,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            '${item.heard}  →  ${item.preferred}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.keyText),
                          ),
                          subtitle: Text(
                            'Voice correction',
                            style: TextStyle(color: t.keyTextSecondary),
                          ),
                          trailing: IconButton(
                            onPressed: () =>
                                kb.deleteDictionaryEntry(item.heard),
                            icon: Icon(
                              Icons.delete_outline,
                              color: t.keyTextSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openApp,
                icon: const Icon(Icons.tune),
                label: const Text('Manage in app'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
