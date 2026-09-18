/// Clipboard history panel with copy current text and paste actions.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class ClipboardPanel extends StatelessWidget {
  const ClipboardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    return Container(
      color: t.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
            child: Row(
              children: [
                const PanelBackButton(),
                Icon(Icons.content_paste, size: 16, color: t.icon),
                const SizedBox(width: 8),
                Text(
                  'Clipboard',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.keyText,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => kb.copySelectionOrAll(),
                  icon: Icon(Icons.copy, size: 14, color: t.accent),
                  label: Text(
                    'Copy text',
                    style: TextStyle(fontSize: 12, color: t.accent),
                  ),
                ),
                if (kb.clipboardHistory.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear history',
                    icon: Icon(Icons.delete_outline, size: 17, color: t.icon),
                    onPressed: kb.clearClipboardHistory,
                  ),
              ],
            ),
          ),
          Expanded(
            child: kb.clipboardHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.content_paste_off,
                          size: 30,
                          color: t.keyTextSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clipboard history is empty.\nCopy text to see it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.keyTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: kb.clipboardHistory.length,
                    itemBuilder: (context, i) {
                      final item = kb.clipboardHistory[i];
                      // The most recently copied/cut entry is highlighted
                      // as an active chip (spec item 4) so it's obvious
                      // which text was just copied and ready to paste
                      // with a single tap.
                      final isActive = item == kb.activeClipboardEntry;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        color: isActive
                            ? t.accent.withValues(alpha: 0.12)
                            : t.keyBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isActive ? t.accent : t.border,
                            width: isActive ? 1.4 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => kb.pasteFromHistory(item),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                if (isActive) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.accent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: t.accentText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    item,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: t.keyText,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.input,
                                  size: 15,
                                  color: isActive
                                      ? t.accent
                                      : t.keyTextSecondary,
                                ),
                              ],
                            ),
                          ),
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
