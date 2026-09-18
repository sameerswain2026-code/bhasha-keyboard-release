/// Offline emoji picker matching Gboard's actual layout (see reference
/// screenshot): header (back + search) at top, category tabs directly
/// below the header, then the emoji grid filling the rest - plus a
/// Gboard-style "Emoji Kitchen" combo strip shown above the grid on the
/// Recents tab. Search filters the grid live, in place; opening the
/// on-panel mini-keyboard docks a small compact keyboard under the grid
/// instead of replacing it, so results stay visible and keep updating
/// while typing (Gboard never hides matches behind its own keyboard).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/emoji_data.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class EmojiPanel extends StatefulWidget {
  const EmojiPanel({super.key});

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  int _categoryIndex = 0; // 0 = recents, 1..n = categories

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    final query = kb.panelInputText;
    final searching = query.trim().isNotEmpty;
    List<String> emojis;
    if (searching) {
      emojis = EmojiSearch.search(query).map((e) => e.char).toList();
    } else if (_categoryIndex == 0) {
      emojis = kb.recentEmojis;
    } else {
      emojis = kEmojiCategories[_categoryIndex - 1].emojis
          .map((e) => e.char)
          .toList();
    }

    return Container(
      color: t.panelBg,
      child: Column(
        children: [
          // Header: back + search field (Gboard's top row).
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 2),
            child: Row(
              children: [
                const PanelBackButton(),
                const SizedBox(width: 4),
                Expanded(child: PanelTextField(hintText: 'Search emoji')),
              ],
            ),
          ),
          // Category tabs directly under the header (Gboard's actual
          // tab position - top, not bottom). Hidden while searching.
          if (!searching)
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  _tab(t, 0, const Icon(Icons.history, size: 19)),
                  for (int i = 0; i < kEmojiCategories.length; i++)
                    _tab(
                      t,
                      i + 1,
                      Text(
                        kEmojiCategories[i].icon,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                ],
              ),
            ),
          // Emoji Kitchen combo strip (spec: reference screenshot shows
          // this directly above the grid) - only on the Recents tab,
          // hidden while searching so it never competes for space with
          // actual search results.
          if (!searching && _categoryIndex == 0)
            _EmojiKitchenStrip(kb: kb, t: t),
          // Body: emoji grid, ALWAYS visible and live-filtered, even
          // while the on-panel mini-keyboard is docked below it - this
          // is the fix for "keyboard pops up and obscures the content".
          Expanded(
            child: emojis.isEmpty
                ? Center(
                    child: Text(
                      searching ? 'No emoji found' : 'No recent emojis yet',
                      style: TextStyle(fontSize: 13, color: t.keyTextSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                    itemCount: emojis.length,
                    itemBuilder: (context, i) {
                      return PanelPressable(
                        onTap: () => kb.insertContent(emojis[i]),
                        borderRadius: BorderRadius.circular(6),
                        overlayColor: t.accent.withValues(alpha: 0.18),
                        pressedScale: 0.8,
                        child: Center(
                          child: Text(
                            emojis[i],
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Compact docked mini-keyboard while typing a search. Fixed,
          // small height so the results grid above keeps its space.
          if (kb.panelKeyboardActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.border, width: 1)),
              ),
              child: const PanelMiniKeyboard(compact: true),
            ),
        ],
      ),
    );
  }

  Widget _tab(KbTheme t, int index, Widget child) {
    final selected = _categoryIndex == index;
    return PanelPressable(
      onTap: () => setState(() => _categoryIndex = index),
      overlayColor: t.accent.withValues(alpha: 0.16),
      pressedScale: 0.88,
      child: Container(
        width: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: selected
              ? Border(bottom: BorderSide(color: t.accent, width: 2))
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// Horizontal strip of curated two-emoji "Emoji Kitchen" combos (see
/// [kEmojiKitchenCombos]). Each tile shows both source emoji stacked
/// (mimicking the fused-sticker look without a network image) and, on
/// tap, inserts the combo sequence directly.
class _EmojiKitchenStrip extends StatelessWidget {
  final KeyboardController kb;
  final KbTheme t;
  const _EmojiKitchenStrip({required this.kb, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 13, color: t.accent),
              const SizedBox(width: 4),
              Text(
                'Emoji Kitchen',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.keyTextSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: kEmojiKitchenCombos.length,
            itemBuilder: (context, i) {
              final combo = kEmojiKitchenCombos[i];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PanelMiniKey(
                  height: 56,
                  color: t.keyBg,
                  pressedColor: t.keyBgPressed,
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => kb.insertContent(combo.combined),
                  child: Text(
                    combo.combined,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, color: t.border),
      ],
    );
  }
}
