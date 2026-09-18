/// Android setup flow: guides the user through the three steps required
/// to use Bhasha Keyboard system-wide -
///   1. Enable the keyboard in Settings > Languages & input
///   2. Select it as the active input method
///   3. Grant microphone permission for real-time voice typing
///
/// Each step's live status is polled from the platform side (via
/// ImeSetupHelper) so the screen reflects what the user actually did in
/// Settings, rather than assuming success after a tap. The screen is only
/// shown on Android; web preview goes straight to the demo editor.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../ime/setup_helper.dart';
import 'kb_theme.dart';

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
    // User returns from Settings/permission dialog -> re-check live status.
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
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
    final t = KbTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121316)
          : const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A73E8), Color(0xFF7C4DFF)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'भ',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Set up Bhasha Keyboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: t.keyText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Three quick steps to use Bhasha Keyboard in WhatsApp, '
                    'Telegram and every other app.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: t.keyTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StepCard(
                    stepNumber: 1,
                    icon: Icons.keyboard_alt_outlined,
                    title: 'Enable the keyboard',
                    subtitle: _enabled
                        ? 'Enabled in system settings'
                        : 'Turn on Bhasha Keyboard in Languages & input',
                    done: _enabled,
                    buttonLabel: _enabled ? 'Enabled' : 'Open settings',
                    onTap: _enabled
                        ? null
                        : () async {
                            await ImeSetupHelper.openImeSettings();
                            _refreshStatus();
                          },
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    stepNumber: 2,
                    icon: Icons.swap_horiz,
                    title: 'Select as active keyboard',
                    subtitle: _selected
                        ? 'Bhasha Keyboard is the active input method'
                        : 'Choose Bhasha Keyboard from the keyboard picker',
                    done: _selected,
                    buttonLabel: _selected ? 'Selected' : 'Choose keyboard',
                    enabled: _enabled,
                    onTap: _selected
                        ? null
                        : () async {
                            await ImeSetupHelper.showImePicker();
                            _refreshStatus();
                          },
                  ),
                  const SizedBox(height: 12),
                  _StepCard(
                    stepNumber: 3,
                    icon: Icons.mic_none,
                    title: 'Allow microphone access',
                    subtitle: _micGranted
                        ? 'Voice typing is ready'
                        : 'Needed only for real-time voice typing',
                    done: _micGranted,
                    buttonLabel: _micGranted ? 'Granted' : 'Grant permission',
                    onTap: _micGranted
                        ? null
                        : () async {
                            await ImeSetupHelper.requestMicPermission();
                            _refreshStatus();
                          },
                  ),
                  const SizedBox(height: 20),
                  if (_checked && !_allDone)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: t.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You can finish this later from Settings inside '
                              'the keyboard toolbar. Typing works in this demo '
                              'app right away.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: t.keyTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: t.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: widget.onContinue,
                      child: Text(
                        _allDone ? 'Continue' : 'Skip for now',
                        style: TextStyle(
                          color: t.keyText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_allDone) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: widget.onContinue,
                        child: const Text(
                          'Try it now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final String buttonLabel;
  final VoidCallback? onTap;
  final bool enabled;

  const _StepCard({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.buttonLabel,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = KbTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2024) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? Colors.green.withValues(alpha: 0.4) : t.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? Colors.green.withValues(alpha: 0.14)
                  : t.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check_circle : icon,
              color: done ? Colors.green : t.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $stepNumber · $title',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.keyText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: t.keyTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: done
                    ? Colors.green.withValues(alpha: 0.14)
                    : (enabled ? t.accent : t.keyBgSpecial),
                foregroundColor: done ? Colors.green : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: (enabled && !done) ? onTap : null,
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
