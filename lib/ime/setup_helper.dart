/// Helper for the keyboard setup flow on Android:
/// enable in settings -> select as current IME -> grant microphone.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ImeSetupHelper {
  static const MethodChannel _system = MethodChannel('bhasha/system');

  /// Whether the setup flow applies (Android only).
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isImeEnabled() async {
    try {
      return await _system.invokeMethod<bool>('isImeEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isImeSelected() async {
    try {
      return await _system.invokeMethod<bool>('isImeSelected') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasMicPermission() async {
    try {
      return await _system.invokeMethod<bool>('hasMicPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openImeSettings() async {
    try {
      await _system.invokeMethod('openImeSettings');
    } catch (_) {}
  }

  static Future<void> showImePicker() async {
    try {
      await _system.invokeMethod('showImePicker');
    } catch (_) {}
  }

  static Future<void> requestMicPermission() async {
    try {
      await _system.invokeMethod('requestMicPermission');
    } catch (_) {}
  }
}
