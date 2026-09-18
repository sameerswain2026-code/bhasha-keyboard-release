/// Sticker picker (Menu -> Sticker). Gboard-style illustrated mascot
/// character stickers (bundled PNG assets, see `sticker_data.dart`) -
/// distinct from the plain unicode Emoji panel. Layout matches Gboard's
/// actual sticker page (see reference screenshot): header (back +
/// search) at top, Recent/category pack tabs directly below the
/// header, then the sticker grid filling the rest. Search filters the
/// grid live, in place; opening the on-panel mini-keyboard docks a
/// small compact keyboard under the grid instead of replacing it, so
/// results stay visible while typing.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/sticker_data.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class StickerPanel extends StatefulWidget {
  const StickerPanel({super.key});

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel> {
  int _categoryIndex = 0; // 0 = recents, 1..n = categories

  Future<void> _send(KeyboardController kb, StickerEntry sticker) async {
    await kb.insertMedia(
      source: sticker.asset,
      mimeType: 'image/png',
      title: sticker.label,
      fallbackText: '[Sticker: ${sticker.label}]',
    );
    kb.addRecentSticker(sticker.id);
    kb.closePanel();
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    final query = kb.panelInputText;
    final searching = query.trim().isNotEmpty;
    List<StickerEntry> results;
    if (searching) {
      results = StickerSearch.search(query);
    } else if (_categoryIndex == 0) {
      results = kb.recentStickers
          .map((id) => kStickersById[id])
          .whereType<StickerEntry>()
          .toList();
    } else {
      results = kStickerCategories[_categoryIndex - 1].stickers;
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
                Expanded(child: PanelTextField(hintText: 'Search stickers')),
              ],
            ),
          ),
          // Recent + category pack tabs directly under the header
          // (Gboard's actual tab position - top, not bottom). Hidden
          // while searching.
          if (!searching)
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  _tab(t, 0, const Icon(Icons.history, size: 19)),
                  for (int i = 0; i < kStickerCategories.length; i++)
                    _tab(
                      t,
                      i + 1,
                      Text(
                        kStickerCategories[i].icon,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                ],
              ),
            ),
          // Sticker grid: ALWAYS visible and live-filtered, even while
          // the on-panel mini-keyboard is docked below it - this is the
          // fix for "keyboard pops up and obscures the content".
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      searching
                          ? 'No stickers found'
                          : 'No recent stickers yet',
                      style: TextStyle(fontSize: 13, color: t.keyTextSecondary),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.92,
                        ),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final sticker = results[i];
                      return PanelPressable(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _send(kb, sticker),
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.keyBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            sticker.asset,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: t.keyTextSecondary,
                                size: 22,
                              ),
                            ),
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
    return Expanded(
      child: PanelPressable(
        onTap: () => setState(() => _categoryIndex = index),
        overlayColor: t.accent.withValues(alpha: 0.16),
        pressedScale: 0.88,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: selected
                ? Border(bottom: BorderSide(color: t.accent, width: 2))
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
