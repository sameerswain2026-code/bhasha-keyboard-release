/// Settings panel: feedback toggles, editor action selection, about.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/keyboard_controller.dart';
import '../../engine/voice_engine.dart';
import '../../ime/setup_helper.dart';
import '../kb_theme.dart';
import '../setup_flow_screen.dart';
import 'panel_mini_keyboard.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  String _micModeDescription(MicMode mode) {
    switch (mode) {
      case MicMode.transcribe:
        return 'Speech follows the Native/Roman script setting';
      case MicMode.translate:
        return 'Speech is translated; output follows Native/Roman setting';
      case MicMode.autoMix:
        return 'Speech is always romanized, regardless of language';
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);

    // Editing the Assistant Name uses the same on-panel mini-keyboard
    // pattern as every other panel text field (this app IS the system
    // keyboard, so a second field can't summon its own IME - see
    // panel_mini_keyboard.dart). Fixed to match the GIF/Emoji/Language
    // panels' own layout: a visible PanelTextField stays on screen
    // showing the live value being typed, with only a small *compact*
    // keyboard docked below it - never a full-size keyboard that
    // consumes the whole panel and hides the field being edited.
    if (kb.panelKeyboardActive) {
      return Container(
        color: t.panelBg,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
              child: Row(
                children: [
                  const PanelBackButton(),
                  Icon(Icons.record_voice_over, size: 16, color: t.icon),
                  const SizedBox(width: 8),
                  Text(
                    'Assistant name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.keyText,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: PanelTextField(
                hintText: 'Wake word',
                leadingIcon: Icons.record_voice_over,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: PanelMiniKeyboard(
                compact: true,
                onDone: () {
                  kb.setAssistantName(kb.panelInputText);
                  kb.panelKeyboardClear();
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: t.panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                const PanelBackButton(),
                Icon(Icons.settings_outlined, size: 17, color: t.icon),
                const SizedBox(width: 8),
                Text(
                  'Settings',
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (ImeSetupHelper.isSupported) ...[
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.checklist_rtl,
                      size: 18,
                      color: t.accent,
                    ),
                    title: Text(
                      'Guided setup',
                      style: TextStyle(fontSize: 13, color: t.keyText),
                    ),
                    subtitle: Text(
                      'Walk through enable, select and mic steps',
                      style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: t.icon,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SetupFlowScreen(
                            onContinue: () => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 18,
                      color: t.accent,
                    ),
                    title: Text(
                      'Enable Bhasha Keyboard system-wide',
                      style: TextStyle(fontSize: 13, color: t.keyText),
                    ),
                    subtitle: Text(
                      'Use in WhatsApp, Telegram and all apps',
                      style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                    ),
                    trailing: Icon(Icons.open_in_new, size: 15, color: t.icon),
                    onTap: ImeSetupHelper.openImeSettings,
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.swap_horiz, size: 18, color: t.accent),
                    title: Text(
                      'Switch to Bhasha Keyboard',
                      style: TextStyle(fontSize: 13, color: t.keyText),
                    ),
                    subtitle: Text(
                      'Open the system keyboard picker',
                      style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                    ),
                    onTap: ImeSetupHelper.showImePicker,
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.mic_none, size: 18, color: t.accent),
                    title: Text(
                      'Microphone permission',
                      style: TextStyle(fontSize: 13, color: t.keyText),
                    ),
                    subtitle: Text(
                      'Needed for real-time voice typing',
                      style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                    ),
                    onTap: ImeSetupHelper.requestMicPermission,
                  ),
                  const Divider(height: 12),
                ],
                ListTile(
                  dense: true,
                  leading: Icon(Icons.mic_outlined, size: 18, color: t.accent),
                  title: Text(
                    'Mic mode',
                    style: TextStyle(fontSize: 13, color: t.keyText),
                  ),
                  subtitle: Text(
                    _micModeDescription(kb.micMode),
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                  trailing: DropdownButton<MicMode>(
                    value: kb.micMode,
                    isDense: true,
                    dropdownColor: t.panelBg,
                    style: TextStyle(fontSize: 12, color: t.keyText),
                    items: const [
                      DropdownMenuItem(
                        value: MicMode.transcribe,
                        child: Text('Transcribe'),
                      ),
                      DropdownMenuItem(
                        value: MicMode.translate,
                        child: Text('Translate'),
                      ),
                      DropdownMenuItem(
                        value: MicMode.autoMix,
                        child: Text('Auto-mix'),
                      ),
                    ],
                    onChanged: (m) {
                      if (m != null) kb.setMicMode(m);
                    },
                  ),
                ),
                const Divider(height: 12),
                // ---- AI Web Assistant (optional, opt-in feature) ----
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: t.accent,
                  ),
                  title: Text(
                    'AI Web Assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.keyText,
                    ),
                  ),
                  subtitle: Text(
                    'Say "${kb.assistantName}" during voice typing to '
                    'search the web instead of typing the command',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: Text(
                    'Enable AI Web Assistant',
                    style: TextStyle(fontSize: 13, color: t.keyText),
                  ),
                  subtitle: Text(
                    kb.aiAssistantEnabled
                        ? 'On - listening for the wake word during voice typing'
                        : 'Off - keyboard behaves exactly as usual',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                  value: kb.aiAssistantEnabled,
                  activeThumbColor: t.accent,
                  onChanged: kb.setAiAssistantEnabled,
                ),
                ListTile(
                  dense: true,
                  enabled: kb.aiAssistantEnabled,
                  title: Text(
                    'Assistant name (wake word)',
                    style: TextStyle(
                      fontSize: 13,
                      color: kb.aiAssistantEnabled
                          ? t.keyText
                          : t.keyTextSecondary,
                    ),
                  ),
                  subtitle: Text(
                    'Currently: "${kb.assistantName}"',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                  trailing: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: kb.aiAssistantEnabled ? t.accent : t.icon,
                  ),
                  onTap: kb.aiAssistantEnabled
                      ? () =>
                            kb.openPanelKeyboard(initialText: kb.assistantName)
                      : null,
                ),
                ListTile(
                  dense: true,
                  enabled: kb.aiAssistantEnabled,
                  title: Text(
                    'Continuous command listening',
                    style: TextStyle(
                      fontSize: 13,
                      color: kb.aiAssistantEnabled
                          ? t.keyText
                          : t.keyTextSecondary,
                    ),
                  ),
                  subtitle: Text(
                    'Keeps listening while you speak and stops after real silence or manual stop',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                ),
                const Divider(height: 12),
                SwitchListTile(
                  dense: true,
                  title: Text(
                    'Haptic feedback',
                    style: TextStyle(fontSize: 13, color: t.keyText),
                  ),
                  subtitle: Text(
                    'Vibrate on key press',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                  value: kb.hapticsEnabled,
                  activeThumbColor: t.accent,
                  onChanged: kb.setHaptics,
                ),
                SwitchListTile(
                  dense: true,
                  title: Text(
                    'Sound on key press',
                    style: TextStyle(fontSize: 13, color: t.keyText),
                  ),
                  subtitle: Text(
                    'Click sound feedback',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                  value: kb.soundEnabled,
                  activeThumbColor: t.accent,
                  onChanged: kb.setSound,
                ),
                ListTile(
                  dense: true,
                  title: Text(
                    'Enter key action (demo)',
                    style: TextStyle(fontSize: 13, color: t.keyText),
                  ),
                  subtitle: Text(
                    'Simulates target editor action: ${kb.editorAction.name}',
                    style: TextStyle(fontSize: 11, color: t.keyTextSecondary),
                  ),
                  trailing: DropdownButton<EditorAction>(
                    value: kb.editorAction,
                    isDense: true,
                    dropdownColor: t.panelBg,
                    style: TextStyle(fontSize: 12, color: t.keyText),
                    items: [
                      for (final a in EditorAction.values)
                        DropdownMenuItem(value: a, child: Text(a.name)),
                    ],
                    onChanged: (a) {
                      if (a != null) kb.setEditorAction(a);
                    },
                  ),
                ),
                const Divider(height: 12),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Bhasha Keyboard v1.0\n'
                    '22 Indian languages · Native & Roman input · Real-time voice typing (Sarvam AI)\n'
                    'Offline-first: typing, emoji and suggestions work without internet.\n'
                    'Microphone is used only for voice typing.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: t.keyTextSecondary,
                    ),
                  ),
                ),
                const Divider(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: t.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Developer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.keyText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sameer Swain\n'
                        'B.Tech CSE, 7th Semester Student\n'
                        'Sanjay Memorial Institute Of Technology\n'
                        'Chandhipadar, Berhampur, Ganjam, Odisha',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: t.keyTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
