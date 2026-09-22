/// Premium first-run setup and feature education for Bhasha Keyboard.
library;

import 'package:flutter/material.dart';

import '../ime/setup_helper.dart';

class SetupFlowScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const SetupFlowScreen({super.key, required this.onContinue});

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen>
    with WidgetsBindingObserver {
  bool _enabled = false;
  bool _selected = false;
  bool _micGranted = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final enabled = await ImeSetupHelper.isImeEnabled();
    final selected = await ImeSetupHelper.isImeSelected();
    final mic = await ImeSetupHelper.hasMicPermission();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _selected = selected;
      _micGranted = mic;
      _checked = true;
    });
  }

  bool get _allDone => _enabled && _selected && _micGranted;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? Colors.white70 : const Color(0xFF667085);
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF0B1022), Color(0xFF17152D)]
                : const [Color(0xFFF6F8FF), Color(0xFFEFF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  children: [
                    _Hero(primary: primary, text: text, muted: muted),
                    const SizedBox(height: 18),
                    Text(
                      'Built for the way India speaks',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'One keyboard for 22 Indian languages, Auto voice typing, manual translation, and your own shortcuts.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Feature(
                            icon: Icons.language,
                            title: '22 languages',
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Feature(
                            icon: Icons.auto_awesome,
                            title: 'Auto voice',
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Feature(
                            icon: Icons.translate,
                            title: 'Translate',
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Get started in three steps',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StepCard(
                      step: 1,
                      icon: Icons.keyboard_alt_outlined,
                      title: 'Enable Bhasha',
                      subtitle: _enabled
                          ? 'Keyboard enabled'
                          : 'Turn it on in Languages & input',
                      done: _enabled,
                      button: _enabled ? 'Done' : 'Open settings',
                      onTap: _enabled
                          ? null
                          : () async {
                              await ImeSetupHelper.openImeSettings();
                              _refreshStatus();
                            },
                    ),
                    const SizedBox(height: 9),
                    _StepCard(
                      step: 2,
                      icon: Icons.touch_app_outlined,
                      title: 'Choose it to type',
                      subtitle: _selected
                          ? 'Bhasha is active'
                          : 'Select Bhasha from the keyboard picker',
                      done: _selected,
                      enabled: _enabled,
                      button: _selected ? 'Done' : 'Choose',
                      onTap: _selected
                          ? null
                          : () async {
                              await ImeSetupHelper.showImePicker();
                              _refreshStatus();
                            },
                    ),
                    const SizedBox(height: 9),
                    _StepCard(
                      step: 3,
                      icon: Icons.mic_none_rounded,
                      title: 'Unlock your voice',
                      subtitle: _micGranted
                          ? 'Voice typing is ready'
                          : 'Optional: needed for Auto voice typing',
                      done: _micGranted,
                      button: _micGranted ? 'Ready' : 'Allow mic',
                      onTap: _micGranted
                          ? null
                          : () async {
                              await ImeSetupHelper.requestMicPermission();
                              _refreshStatus();
                            },
                    ),
                    const SizedBox(height: 14),
                    if (_checked && !_allDone)
                      Text(
                        'You can skip now and finish setup later from the keyboard Settings.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onContinue,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(_allDone ? 'Start typing' : 'Explore Bhasha'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.primary, required this.text, required this.muted});
  final Color primary;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .94, end: 1),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutBack,
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, const Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Center(
                  child: Text(
                    'भ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'BHASHA KEYBOARD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Type India,\nyour way.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 1.02,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Speak naturally. Translate instantly. Keep your words yours.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .85),
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.color,
  });
  final IconData icon;
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.button,
    required this.onTap,
    this.enabled = true,
  });
  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final String button;
  final VoidCallback? onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done
              ? Colors.green.withValues(alpha: .5)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: done
                  ? Colors.green.withValues(alpha: .12)
                  : scheme.primary.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check : icon,
              color: done ? Colors.green : scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '0$step  ·  $title',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: enabled && !done ? onTap : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Text(
              button,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
