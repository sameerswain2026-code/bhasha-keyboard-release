import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/keyboard_controller.dart';
import '../ime/setup_helper.dart';
import 'document_context_screen.dart';
import 'personalization_screen.dart';
import 'setup_flow_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), actions: [IconButton(onPressed: () => ImeSetupHelper.openImeSettings(), icon: const Icon(Icons.open_in_new))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Text('Your workspace', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Make Bhasha feel like your own keyboard.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          _SettingsTile(icon: Icons.auto_awesome_rounded, color: scheme.primary, title: 'Document context', subtitle: kb.voiceContext.isEmpty ? 'Add a PDF or text reference' : 'Context-aware writing is active', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentContextScreen()))),
          _SettingsTile(icon: Icons.tune_rounded, color: const Color(0xFF7C3AED), title: 'Personalization', subtitle: 'Snippets and pronunciation dictionary', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalizationScreen()))),
          _SettingsTile(icon: Icons.verified_user_outlined, color: const Color(0xFF0F766E), title: 'Keyboard setup', subtitle: 'Enable, select, and grant microphone access', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SetupFlowScreen(onContinue: () => Navigator.pop(context))))),
          const SizedBox(height: 18),
          Card(
            child: Column(children: [
              SwitchListTile.adaptive(value: kb.contextAwareEnabled, onChanged: kb.setContextAware, title: const Text('Context-aware suggestions', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Use your saved context for correction and writing assistance.'), secondary: const Icon(Icons.psychology_outlined)),
              const Divider(height: 1),
              SwitchListTile.adaptive(value: kb.hapticsEnabled, onChanged: kb.setHaptics, title: const Text('Key haptics', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('A short tactile tick on every key press.'), secondary: const Icon(Icons.vibration_outlined)),
            ]),
          ),
          const SizedBox(height: 20),
          Center(child: Text('SAMEER  •  Bhasha Keyboard', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: .7))),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final Color color; final String title; final String subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded)),
  );
}
