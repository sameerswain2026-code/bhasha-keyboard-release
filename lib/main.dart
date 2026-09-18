/// Bhasha Keyboard - premium multilingual keyboard for 22 Indian languages.
/// Web preview hosts the keyboard inside a demo messaging-style editor;
/// on Android the same KeyboardView binds to the IME service.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/keyboard_controller.dart';
import 'engine/voice_factory.dart';
import 'ime/android_platform.dart';
import 'ime/ime_bridge.dart';
import 'ui/kb_theme.dart';
import 'ui/keyboard_view.dart';
import 'ui/setup_flow_screen.dart';

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
              colorSchemeSeed: const Color(0xFF1A73E8),
              scaffoldBackgroundColor: const Color(0xFFF7F8FA),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: const Color(0xFF8AB4F8),
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
              colorSchemeSeed: const Color(0xFF1A73E8),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: const Color(0xFF8AB4F8),
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

/// Demo host screen: a messaging-style editor with the keyboard docked
/// at the bottom - mirrors how the IME appears inside Android apps.
class DemoEditorScreen extends StatelessWidget {
  const DemoEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final t = KbTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A73E8), Color(0xFF7C4DFF)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Center(
                      child: Text(
                        'भ',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bhasha Keyboard',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.keyText,
                        ),
                      ),
                      Text(
                        '22 Indian languages · Voice · Emoji · GIF',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: t.keyTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      kb.language.englishName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Demo editor area
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2024) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 16,
                          color: t.keyTextSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Demo editor — type with the keyboard below',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.keyTextSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (kb.editor.text.isNotEmpty)
                          InkWell(
                            onTap: () {
                              kb.editor.clear();
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(fontSize: 11, color: t.accent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                          height: 1.45,
                          color: t.keyText,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              'नमस्ते! Try typing "namaste" in Hindi Roman mode…',
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
            // The keyboard itself
            const KeyboardView(),
          ],
        ),
      ),
    );
  }
}
