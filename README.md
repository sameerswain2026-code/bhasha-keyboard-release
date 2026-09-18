# Bhasha Keyboard

Bhasha Keyboard is a Flutter-based Android Input Method Editor (IME) for multilingual typing across Indian languages. It provides native-script layouts, transliteration, suggestions, voice input, emoji, stickers, GIFs, clipboard tools, text editing, themes, and optional AI-assisted features.

> **Status:** Public repository and active development. The Android IME path is the primary product surface; the launcher app includes an onboarding flow for enabling and selecting the keyboard.

## Features

| Area | Included capability |
| --- | --- |
| Languages | 22 Indian-language packs with native layouts and transliteration |
| Input | System-wide IME, cursor-aware editing, selection replacement, editor actions |
| Productivity | Suggestions, clipboard panel, emoji, stickers, GIF panel, resize and theme controls |
| Accessibility | Voice typing, text-to-speech for selected text, dark theme |
| Integrations | Optional Gemini, Sarvam and Tavily integrations configured at build time |

## Requirements

- Flutter SDK 3.35.x or newer compatible with Dart 3.9.x.
- Java 17 and Android SDK with the Flutter-recommended compile/target SDK.
- Android device or emulator running Android 6.0 (API 23) or newer.

## Local development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

To test the actual system keyboard, install the debug build on an Android device, open **Settings → System → Keyboard → On-screen keyboard**, enable **Bhasha Keyboard**, then select it from the input method picker.

## Optional provider configuration

Provider credentials are never committed. They are passed as Dart compile-time defines, for example:

```bash
flutter build apk --release \
  --dart-define="GEMINI_API_KEYS=key1,key2" \
  --dart-define="SARVAM_API_KEYS=key1,key2" \
  --dart-define="TAVILY_API_KEYS=key1,key2"
```

For a public consumer release, use a backend proxy rather than shipping provider secrets in an APK. An empty configuration intentionally disables the corresponding provider instead of failing the application startup.

## Release signing

Release signing is intentionally strict and does not fall back to the debug keystore. Copy `android/key.properties.example` to `android/key.properties`, point `storeFile` to a local keystore, and keep both the file and keystore out of source control. CI uses the encrypted `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES`, and `ANDROID_KEYSTORE_PASSWORD` repository secrets.

## CI/CD

GitHub Actions runs formatting checks, static analysis, unit/widget tests, and an Android debug APK build on every pull request and push. Version tags matching `v*` trigger a signed Android App Bundle build and publish the artifact to a GitHub Release. Configure signing and optional provider secrets in **Repository Settings → Secrets and variables → Actions** before creating a release tag.

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [docs/releasing.md](docs/releasing.md) for the contributor and release procedures.

## Project structure

```text
lib/                 Flutter application, IME UI, engines and data
android/             Android host activity, InputMethodService and resources
assets/              App icon and sticker assets
test/                Unit, widget and integration-oriented tests
.github/workflows/   CI validation and signed release automation
docs/                Operational and release documentation
```

## License

This project is distributed under the MIT License. See [LICENSE](LICENSE).
