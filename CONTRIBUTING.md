# Contributing

## Development workflow

Create a feature branch from `main`, make the smallest focused change, and add or update tests for behavior that changes. Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test` before opening a pull request.

Pull requests should explain the user-visible behavior, Android versions tested, and any permission or provider changes. Do not commit API keys, keystores, generated APK/AAB files, `local.properties`, or private user data.

## Review expectations

Changes to the IME service, text editing bridge, permissions, clipboard, microphone, or network providers require extra review because they affect user privacy or text integrity. Keep provider integrations disabled by default when credentials are absent.
