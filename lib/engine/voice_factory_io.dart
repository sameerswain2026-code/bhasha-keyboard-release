/// Native (Android) voice factory: real-time Sarvam AI streaming
/// recognition fed by the platform microphone.
library;

import 'dart:io';

import 'android_mic_source.dart';
import 'android_speech_provider.dart';
import 'sarvam_speech_provider.dart';
import 'voice_engine.dart';

VoiceEngine createVoiceEngine() {
  if (Platform.isAndroid) {
    final mic = AndroidMicSource();
    return VoiceEngine(
      provider: ResilientSpeechProvider(
        primary: SarvamSpeechProvider(micSource: mic),
        fallback: AndroidSpeechProvider(),
      ),
    );
  }
  return VoiceEngine(); // other desktop targets: simulated
}
