/// Responsive in-keyboard manual translation workspace.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../data/languages.dart';
import '../../engine/translation_engine.dart';
import '../kb_theme.dart';
import 'panel_mini_keyboard.dart';

class ManualTranslatePanel extends StatefulWidget {
  const ManualTranslatePanel({super.key});

  @override
  State<ManualTranslatePanel> createState() => _ManualTranslatePanelState();
}

class _ManualTranslatePanelState extends State<ManualTranslatePanel> {
  LanguagePack? _target;
  String _sourceId = 'auto';
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
    final detected = input.trim().isEmpty
        ? null
        : TranslationLanguageDetector.detect(input);
    final selectedSource = _sourceId == 'auto'
        ? null
        : LanguageRegistry.byId(_sourceId);

    return Container(
      color: theme.panelBg,
      child: Column(
        children: [
          _header(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste or type text. Source language is detected automatically.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.keyTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _inputCard(kb, theme, input),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => kb.pasteIntoPanelFromClipboard(),
                          icon: const Icon(Icons.content_paste, size: 17),
                          label: const Text('Paste'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: input.isEmpty
                              ? null
                              : kb.panelKeyboardClear,
                          icon: const Icon(Icons.clear, size: 17),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _languageRow(
                    theme,
                    label: 'From',
                    value: _sourceId,
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'auto',
                        child: Text('Auto detect'),
                      ),
                      ...LanguageRegistry.all.map(
                        (pack) => DropdownMenuItem<String>(
                          value: pack.id,
                          child: Text(pack.nativeName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sourceId = value);
                    },
                    suffix: _sourceId == 'auto' && detected != null
                        ? 'Detected: ${detected.nativeName}'
                        : null,
                  ),
                  const SizedBox(height: 6),
                  _languageRow(
                    theme,
                    label: 'To',
                    value: _target!.id,
                    items: LanguageRegistry.all
                        .map(
                          (pack) => DropdownMenuItem<String>(
                            value: pack.id,
                            child: Text(pack.nativeName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _target = LanguageRegistry.byId(value));
                      }
                    },
                  ),
                  const SizedBox(height: 7),
                  FilledButton.icon(
                    onPressed: input.trim().isEmpty || _busy
                        ? null
                        : () async {
                            setState(() {
                              _busy = true;
                              _result = '';
                            });
                            final result = await kb.translateManualText(
                              input,
                              _target!,
                              source: selectedSource,
                            );
                            if (mounted) {
                              setState(() {
                                _result = result;
                                _busy = false;
                              });
                            }
                          },
                    icon: _busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt, size: 18),
                    label: Text(_busy ? 'Translating…' : 'Translate'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                  if (_result.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _resultCard(theme),
                  ],
                ],
              ),
            ),
          ),
          if (kb.panelKeyboardActive)
            SizedBox(
              height: PanelMiniKeyboard.compactHeight,
              child: PanelMiniKeyboard(
                compact: true,
                onDone: kb.closePanelKeyboard,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                'Tap the input box to open the keyboard here',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: theme.keyTextSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(KbTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 4),
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
                fontWeight: FontWeight.w800,
                color: theme.keyText,
              ),
            ),
          ),
          Icon(Icons.auto_awesome, size: 16, color: theme.accent),
          const SizedBox(width: 4),
          Text(
            'Auto source',
            style: TextStyle(fontSize: 10, color: theme.accent),
          ),
        ],
      ),
    );
  }

  Widget _inputCard(KeyboardController kb, KbTheme theme, String input) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => kb.openPanelKeyboard(initialText: input),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58, maxHeight: 82),
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
        decoration: BoxDecoration(
          color: theme.keyBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kb.panelKeyboardActive ? theme.accent : theme.border,
            width: kb.panelKeyboardActive ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.edit_note, size: 19, color: theme.icon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                input.isEmpty ? 'Tap here to type or paste text' : input,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  color: input.isEmpty ? theme.keyTextSecondary : theme.keyText,
                ),
              ),
            ),
            if (kb.panelKeyboardActive)
              Icon(Icons.keyboard, size: 17, color: theme.accent),
          ],
        ),
      ),
    );
  }

  Widget _languageRow(
    KbTheme theme, {
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 8, 2),
      decoration: BoxDecoration(
        color: theme.keyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.keyTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: items,
              onChanged: onChanged,
              style: TextStyle(fontSize: 12, color: theme.keyText),
            ),
          ),
          if (suffix != null)
            Flexible(
              child: Text(
                suffix,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: theme.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultCard(KbTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 15, color: theme.accent),
              const SizedBox(width: 5),
              Text(
                'Translation result',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: theme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _result,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.25, color: theme.keyText),
          ),
        ],
      ),
    );
  }
}
