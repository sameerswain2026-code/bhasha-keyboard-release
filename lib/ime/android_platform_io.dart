/// Native (VM/Android/desktop) check: true only on an actual Android
/// device/emulator. Deliberately uses dart:io Platform (not
/// defaultTargetPlatform) so `flutter test` - which runs on the host VM
/// and would otherwise report TargetPlatform.android - correctly resolves
/// to false and the setup flow never blocks widget tests.
library;

import 'dart:io';

bool get isRunningOnAndroidDevice => Platform.isAndroid;
