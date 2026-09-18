/// Microphone audio source abstraction (platform-neutral).
library;

/// Source of microphone PCM16 audio chunks (16kHz mono).
/// On Android this is fed by the native AudioRecord via platform channel.
abstract class MicAudioSource {
  /// Whether microphone permission is currently granted.
  Future<bool> hasPermission();

  /// Start capture; returns a stream of raw PCM16LE chunks.
  Future<Stream<List<int>>> start();

  Future<void> stop();
}
