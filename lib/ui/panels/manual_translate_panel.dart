/// In-keyboard manual translation workspace: type/paste text, choose a
/// destination language, and see the translated result without leaving the IME.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/languages.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class ManualTranslatePanel extends StatefulWidget {
  const ManualTranslatePanel({super.key});

  @override
  State<ManualTranslatePanel> createState() => _ManualTranslatePanelState();
}

class _ManualTranslatePanelState extends State<ManualTranslatePanel> {
  LanguagePack? _target;
  String _result = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final theme = KbTheme.of(context);
    _target ??= kb.language.id == 'en'
        ? LanguageRegistry.byId('hi')
        : LanguageRegistry.byId('en');
    final input = kb.panelInputText;
    return Container(
      color: theme.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
            child: Row(
              children: [
                const PanelBackButton(),
                Icon(Icons.translate, size: 17, color: theme.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manual Translate',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.keyText,
                    ),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 5),
            child: Text(
              'Paste or type text here. It stays visible while the keyboard is open.',
              style: TextStyle(fontSize: 11, color: theme.keyTextSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PanelTextField(
              hintText: 'Type or paste text to translate',
              leadingIcon: Icons.edit_note,
            ),
          ),
          if (_result.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                _result,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: theme.keyText),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 5),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<LanguagePack>(
                    initialValue: _target,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Translate to',
                      border: OutlineInputBorder(),
                    ),
                    items: LanguageRegistry.all
                        .map(
                          (pack) => DropdownMenuItem(
                            value: pack,
                            child: Text(
                              pack.nativeName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _target = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: input.trim().isEmpty || _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final result = await kb.translateManualText(
                            input,
                            _target!,
                          );
                          if (mounted)
                            setState(() {
                              _result = result;
                              _busy = false;
                            });
                        },
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Translate'),
                ),
              ],
            ),
          ),
          if (kb.panelKeyboardActive)
            const Expanded(child: PanelMiniKeyboard(compact: true))
          else
            const Spacer(),
        ],
      ),
    );
  }
}
