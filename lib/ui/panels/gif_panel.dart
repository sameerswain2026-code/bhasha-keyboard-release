/// Inline GIF panel matching Gboard's actual layout (see reference
/// screenshot): header (back + search) at top, category tabs directly
/// below the header, then the results grid filling the rest. Search
/// filters the grid live, in-place - opening the on-panel mini-keyboard
/// no longer swaps away the results; it docks a compact keyboard under
/// a results area that stays visible and keeps live-updating as you
/// type (Gboard never lets its own mini text field cover up matches).
/// Insertion uses explicit fallback (labelled share text), never
/// blindly pasting a raw URL as if it were typed text.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../engine/gif_provider.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class GifPanel extends StatefulWidget {
  const GifPanel({super.key});

  @override
  State<GifPanel> createState() => _GifPanelState();
}

class _GifPanelState extends State<GifPanel> {
  final GifEngine _engine = GifEngine();
  GifCategory _category = GifCategory.trending;

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  void _selectCategory(GifCategory category) {
    if (category == _category) return;
    setState(() => _category = category);
  }

  Future<void> _insertGif(BuildContext context, GifItem gif) async {
    final kb = context.read<KeyboardController>();
    await kb.insertMedia(
      source: gif.shareUrl,
      mimeType: 'image/gif',
      title: gif.title,
      fallbackText: '[GIF: ${gif.title}]',
    );
    kb.closePanel();
  }

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);
    final kb = context.watch<KeyboardController>();
    final query = kb.panelInputText;
    final searching = query.trim().isNotEmpty;

    // Synchronous, un-debounced filtering: results narrow on every
    // keystroke, same as Gboard's own GIF search.
    final List<GifItem> results = searching
        ? _engine.search(query)
        : _engine.byCategory(_category);

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
                Expanded(child: PanelTextField(hintText: 'Search GIFs')),
              ],
            ),
          ),
          // Category tabs directly under the header (Gboard's actual
          // tab position - top, not bottom). Hidden while searching,
          // same as Gboard collapsing its tab row during search.
          if (!searching)
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  for (final category in GifCategory.values)
                    Expanded(child: _tab(t, category)),
                ],
              ),
            ),
          // Results grid: ALWAYS visible and live-filtered, even while
          // the on-panel mini-keyboard is docked below it - this is the
          // fix for "keyboard pops up and obscures the content".
          Expanded(
            child: _GifResultsGrid(
              results: results,
              searching: searching,
              onTap: (g) => _insertGif(context, g),
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

  Widget _tab(KbTheme t, GifCategory category) {
    final selected = _category == category;
    return PanelPressable(
      onTap: () => _selectCategory(category),
      overlayColor: t.accent.withValues(alpha: 0.16),
      pressedScale: 0.88,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: selected
              ? Border(bottom: BorderSide(color: t.accent, width: 2))
              : null,
        ),
        child: Icon(
          kGifCategoryIcons[category],
          size: 19,
          color: selected ? t.accent : t.icon,
        ),
      ),
    );
  }
}

class _GifResultsGrid extends StatelessWidget {
  final List<GifItem> results;
  final bool searching;
  final void Function(GifItem) onTap;
  const _GifResultsGrid({
    required this.results,
    required this.searching,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);
    if (results.isEmpty) {
      return Center(
        child: Text(
          searching ? 'No GIFs found' : 'No GIFs in this category',
          style: TextStyle(fontSize: 13, color: t.keyTextSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.4,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final gif = results[i];
        return PanelPressable(
          onTap: () => onTap(gif),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: t.keyBgSpecial,
            child: Image.network(
              gif.previewUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gif_box_outlined, color: t.icon, size: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        gif.title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: t.keyTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              loadingBuilder: (c, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.accent,
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
