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
import 'ui/app_settings_screen.dart';

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
      if (_managementDestination == 'settings') return const AppSettingsScreen();
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2140) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF087FE8), Color(0xFF6927D8)]), borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('भ', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SAMEER', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w900, color: t.keyTextSecondary)),
                        const SizedBox(height: 3),
                        Text('Your keyboard workspace', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: t.keyText)),
                      ])),
                      Text(kb.language.englishName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.accent)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _HomeAction(icon: Icons.settings_outlined, label: 'Settings & context', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen())), color: const Color(0xFF7C3AED)),
                  ),
                  Container(
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.accent,
                                  ),
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
                        SizedBox(
                          height: 92,
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
                ],
              ),
            ),
            const KeyboardView(),
          ],
        ),
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({required this.icon, required this.label, required this.onTap, required this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );
}
