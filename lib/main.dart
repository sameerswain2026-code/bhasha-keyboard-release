/// Bhasha Keyboard - premium multilingual keyboard for 22 Indian languages.
/// Web preview hosts the keyboard inside a demo messaging-style editor;
/// on Android the same KeyboardView binds to the IME service.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/keyboard_controller.dart';
import 'engine/voice_factory.dart';
import 'ime/android_platform.dart';
import 'ime/ime_bridge.dart';
import 'ui/kb_theme.dart';
import 'ui/keyboard_view.dart';
import 'ui/setup_flow_screen.dart';
import 'ui/personalization_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BhashaKeyboardApp());
}

/// Entrypoint for the Android IME service (BhashaImeService).
/// Runs only the keyboard surface; text is forwarded to the host app's
/// text field through the InputConnection bridge.
@pragma('vm:entry-point')
void imeMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BhashaImeApp());
}

class BhashaKeyboardApp extends StatelessWidget {
  const BhashaKeyboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KeyboardController(voiceEngine: createVoiceEngine()),
      child: Consumer<KeyboardController>(
        builder: (context, kb, _) {
          return MaterialApp(
            title: 'Bhasha Keyboard',
            debugShowCheckedModeBanner: false,
            themeMode: kb.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorSchemeSeed: kb.themeSeedColor,
              scaffoldBackgroundColor: const Color(0xFFF7F8FA),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: kb.themeSeedColor,
              scaffoldBackgroundColor: const Color(0xFF121316),
            ),
            home: const _AppHome(),
          );
        },
      ),
    );
  }
}

/// Decides whether to show the one-time Android setup flow (enable IME,
/// select IME, grant mic) before the demo editor. Only ever gates real
/// Android launches - web preview and `flutter test` (host VM) go
/// straight to the demo editor.
class _AppHome extends StatefulWidget {
  const _AppHome();

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  static const _prefKey = 'setup_flow_seen';
  bool? _showSetup;
  String? _managementDestination;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    if (!isRunningOnAndroidDevice) {
      setState(() => _showSetup = false);
      return;
    }
    try {
      _managementDestination = await const MethodChannel(
        'bhasha/system',
      ).invokeMethod<String>('getManagementDestination');
      final prefs = await SharedPreferences.getInstance();
      setState(() => _showSetup = !(prefs.getBool(_prefKey) ?? false));
    } catch (_) {
      setState(() => _showSetup = false);
    }
  }

  Future<void> _completeSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
    if (mounted) setState(() => _showSetup = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSetup == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_showSetup == true) {
      return SetupFlowScreen(onContinue: _completeSetup);
    }
    if (_managementDestination != null) {
      return PersonalizationScreen(
        initialTab: _managementDestination == 'dictionary' ? 1 : 0,
      );
    }
    return const DemoEditorScreen();
  }
}

/// Root widget for the system IME: keyboard surface only, wired to the
/// host app's text field via ImeBridge (commitText/deleteSurroundingText).
class BhashaImeApp extends StatefulWidget {
  const BhashaImeApp({super.key});

  @override
  State<BhashaImeApp> createState() => _BhashaImeAppState();
}

class _BhashaImeAppState extends State<BhashaImeApp> {
  late final KeyboardController _kb;
  late final ImeBridge _bridge;

  @override
  void initState() {
    super.initState();
    _kb = KeyboardController(voiceEngine: createVoiceEngine());
    _bridge = ImeBridge(_kb);
    _kb.onEditorActionTriggered = _bridge.performAction;
  }

  @override
  void dispose() {
    _bridge.dispose();
    _kb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<KeyboardController>.value(
      value: _kb,
      child: Consumer<KeyboardController>(
        builder: (context, kb, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: kb.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorSchemeSeed: kb.themeSeedColor,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: kb.themeSeedColor,
            ),
            home: const Scaffold(
              backgroundColor: Colors.transparent,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: KeyboardView(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Branded demo host screen. It mirrors the Play Store banner: blue-purple
/// identity, Indian-language chips, a chat-style preview, and the live IME
/// docked below so the first launch feels like a product showcase.
class DemoEditorScreen extends StatelessWidget {
  const DemoEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10142A)
          : const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087FE8), Color(0xFF6927D8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x331A73E8),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'भ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Bhasha Keyboard',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          kb.language.englishName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'One keyboard.\nMany Indias.',
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Type India, your way.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFE5EDFF),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const [
                      'हिन्दी',
                      'தமிழ்',
                      'తెలుగు',
                      'বাংলা',
                      'मराठी',
                      '+ 16 more',
                    ].map((label) => _LanguageChip(label)).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  _FeaturePill(
                    Icons.language,
                    '22 Languages',
                    onTap: () => kb.togglePanel(ActivePanel.language),
                  ),
                  _FeaturePill(Icons.mic_none, 'Voice', onTap: kb.toggleVoice),
                  _FeaturePill(
                    Icons.translate,
                    'Translate',
                    onTap: kb.openTranslateConfig,
                  ),
                  _FeaturePill(
                    Icons.emoji_emotions_outlined,
                    'Emoji',
                    onTap: () => kb.togglePanel(ActivePanel.emoji),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PersonalizationScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.accent.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: t.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Personalize your keyboard',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: t.keyText,
                          ),
                        ),
                      ),
                      Text(
                        'Snippets • Dictionary',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.keyTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: t.accent),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2140) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: t.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Try the keyboard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.keyText,
                          ),
                        ),
                        const Spacer(),
                        if (kb.editor.text.isNotEmpty)
                          InkWell(
                            onTap: kb.editor.clear,
                            child: Text(
                              'Clear',
                              style: TextStyle(fontSize: 11, color: t.accent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.09),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Namaste! How are you? 😊',
                          style: TextStyle(fontSize: 14, color: t.keyText),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: kb.editor,
                        maxLines: null,
                        expands: true,
                        readOnly: true,
                        showCursor: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.4,
                          color: t.keyText,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type in Hindi, Odia, Tamil…',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: t.keyTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const KeyboardView(),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  const _LanguageChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  );
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FeaturePill(this.icon, this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: const Color(0x332B63D9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Column(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF163B8F)),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF263A68),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
