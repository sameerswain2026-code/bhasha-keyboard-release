/// Full-screen management for personal snippets and pronunciation dictionary.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/keyboard_controller.dart';
import '../engine/snippet_store.dart';
import 'personalization_flow_widgets.dart';

class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  Future<List<String>?> _form(
    BuildContext context, {
    required String title,
    required String leftLabel,
    required String leftHint,
    required String rightLabel,
    required String rightHint,
    String? initialLeft,
    String? initialRight,
  }) async {
    final left = TextEditingController(text: initialLeft);
    final right = TextEditingController(text: initialRight);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: left,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: leftLabel,
                  hintText: leftHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: right,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: rightLabel,
                  hintText: rightHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, [left.text, right.text]),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    left.dispose();
    right.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personalize Bhasha'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Snippets'),
              Tab(text: 'Dictionary'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Your language, your shortcuts, your spelling.\nEverything stays on this device.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: const [
                      FlowStep(Icons.mic_none, 'Speak'),
                      FlowArrow(),
                      FlowStep(Icons.tune, 'Teach'),
                      FlowArrow(),
                      FlowStep(Icons.check_circle_outline, 'Type right'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SnippetList(
                    items: kb.localSnippets,
                    onAdd: () async {
                      final result = await _form(
                        context,
                        title: 'Create snippet',
                        leftLabel: 'Shortcut or voice phrase',
                        leftHint: 'email id one',
                        rightLabel: 'Text to insert',
                        rightHint: 'name@example.com',
                      );
                      if (result != null && result.length == 2)
                        kb.saveSnippet(result[0], result[1]);
                    },
                    onDelete: kb.deleteSnippet,
                    onTap: (item) => kb.insertContent(item.value),
                  ),
                  _DictionaryList(
                    items: kb.dictionaryEntries,
                    onAdd: () async {
                      final result = await _form(
                        context,
                        title: 'Add pronunciation correction',
                        leftLabel: 'What speech recognition hears',
                        leftHint: 'sameer',
                        rightLabel: 'Preferred spelling',
                        rightHint: 'समीर',
                      );
                      if (result != null && result.length == 2)
                        kb.saveDictionaryEntry(result[0], result[1]);
                    },
                    onDelete: kb.deleteDictionaryEntry,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnippetList extends StatelessWidget {
  const _SnippetList({
    required this.items,
    required this.onAdd,
    required this.onDelete,
    required this.onTap,
  });
  final List<LocalSnippet> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;
  final ValueChanged<LocalSnippet> onTap;

  @override
  Widget build(BuildContext context) => _ManagementList(
    title: 'Say a short phrase, get the full text',
    description:
        'Use snippets for emails, phone numbers, addresses, biodata, or any repeated message.',
    empty: 'No snippets yet. Add “email id one” or “biodata”.',
    count: items.length,
    onAdd: onAdd,
    children: items
        .map(
          (item) => _EntryCard(
            leading: Icons.short_text,
            title: item.alias,
            subtitle: item.value,
            onTap: () => onTap(item),
            onDelete: () => onDelete(item.alias),
          ),
        )
        .toList(),
  );
}

class _DictionaryList extends StatelessWidget {
  const _DictionaryList({
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });
  final List<DictionaryEntry> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => _ManagementList(
    title: 'Teach Bhasha your pronunciation',
    description:
        'Use dictionary corrections when accent or speech recognition repeatedly writes a word incorrectly.',
    empty: 'No corrections yet. Add “sameer” → “समीर”.',
    count: items.length,
    onAdd: onAdd,
    children: items
        .map(
          (item) => _EntryCard(
            leading: Icons.record_voice_over_outlined,
            title: '${item.heard}  →  ${item.preferred}',
            subtitle: 'Applied automatically to voice results',
            onDelete: () => onDelete(item.heard),
          ),
        )
        .toList(),
  );
}

class _ManagementList extends StatelessWidget {
  const _ManagementList({
    required this.title,
    required this.description,
    required this.empty,
    required this.count,
    required this.onAdd,
    required this.children,
  });
  final String title;
  final String description;
  final String empty;
  final int count;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add new'),
      ),
      const SizedBox(height: 12),
      if (children.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(empty, textAlign: TextAlign.center),
          ),
        )
      else
        ...children,
      const SizedBox(height: 8),
      Text(
        '$count saved locally',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    required this.onDelete,
  });
  final IconData leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(leading, color: Theme.of(context).colorScheme.primary),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    ),
  );
}
