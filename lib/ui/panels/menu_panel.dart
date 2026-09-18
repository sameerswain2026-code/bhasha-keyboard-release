/// Gboard-style expanded Menu: a grid of quick-access tools opened from
/// the toolbar's Menu icon. Per spec this grid contains Theme, GIF,
/// Sticker, Emoji, Text Editing, Resize, Floating Keyboard and
/// One-Handed Mode - the mic language/mode selector deliberately lives
/// beside the mic instead (see [MicIndicator]), never here.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../kb_theme.dart';

/// Menu tile kind: opens a [panel], or is a direct toggle/cycle action
/// with no panel of its own (Floating Keyboard, One-Handed Mode). The
/// latter matches Gboard: both of these are inline compact controls,
/// never full settings screens (spec item 11).
enum _TileAction { floating, oneHanded }

class _MenuItem {
  final IconData icon;
  final String label;
  final ActivePanel? panel;
  final _TileAction? action;
  const _MenuItem(this.icon, this.label, {this.panel, this.action});
}

const List<_MenuItem> _items = [
  _MenuItem(Icons.palette_outlined, 'Theme', panel: ActivePanel.theme),
  _MenuItem(Icons.gif_box_outlined, 'GIF', panel: ActivePanel.gif),
  _MenuItem(
    Icons.emoji_emotions_outlined,
    'Sticker',
    panel: ActivePanel.sticker,
  ),
  _MenuItem(Icons.mood, 'Emoji', panel: ActivePanel.emoji),
  _MenuItem(Icons.text_fields, 'Text Editing', panel: ActivePanel.textEditing),
  _MenuItem(
    Icons.photo_size_select_large_outlined,
    'Resize',
    panel: ActivePanel.resize,
  ),
  _MenuItem(
    Icons.picture_in_picture_alt_outlined,
    'Floating Keyboard',
    action: _TileAction.floating,
  ),
  _MenuItem(Icons.swap_horiz, 'One-Handed Mode', action: _TileAction.oneHanded),
];

class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});

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
                IconButton(
                  tooltip: 'Back to keyboard',
                  icon: Icon(Icons.arrow_back, size: 20, color: t.icon),
                  onPressed: kb.closePanel,
                ),
                Icon(Icons.apps, size: 16, color: t.icon),
                const SizedBox(width: 8),
                Text(
                  'Tools',
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
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.92,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                final isToggle = item.action != null;
                final active = switch (item.action) {
                  _TileAction.floating => kb.floatingEnabled,
                  _TileAction.oneHanded =>
                    kb.oneHandedSide != OneHandedSide.off,
                  null => kb.panel == item.panel,
                };
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    switch (item.action) {
                      case _TileAction.floating:
                        kb.setFloatingEnabled(!kb.floatingEnabled);
                      case _TileAction.oneHanded:
                        kb.cycleOneHandedSide();
                        kb.closePanel();
                      case null:
                        kb.togglePanel(item.panel!);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: active
                          ? t.accent.withValues(alpha: 0.16)
                          : t.keyBg,
                      borderRadius: BorderRadius.circular(12),
                      border: active ? Border.all(color: t.accent) : null,
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 24,
                              color: active ? t.accent : t.icon,
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                item.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: active ? t.accent : t.keyTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isToggle && active)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle,
                              size: 13,
                              color: t.accent,
                            ),
                          ),
                      ],
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
