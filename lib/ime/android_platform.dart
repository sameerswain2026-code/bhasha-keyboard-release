/// True only when actually running on an Android device/emulator.
/// Used to gate the one-time setup flow so `flutter test` (host VM) and
/// web preview never show it, only real Android launches do.
library;

export 'android_platform_stub.dart'
    if (dart.library.io) 'android_platform_io.dart';
