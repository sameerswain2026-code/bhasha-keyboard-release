/// Native (Android) voice factory: real-time Sarvam AI streaming
/// recognition fed by the platform microphone.
library;

import 'dart:io';

import 'android_mic_source.dart';
import 'sarvam_speech_provider.dart';
import 'voice_engine.dart';

VoiceEngine createVoiceEngine() {
  if (Platform.isAndroid) {
    return VoiceEngine(
      provider: SarvamSpeechProvider(micSource: AndroidMicSource()),
    );
  }
  return VoiceEngine(); // other desktop targets: simulated
}
