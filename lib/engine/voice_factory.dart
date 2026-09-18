/// Platform-conditional voice engine factory.
///
/// - Android: SarvamSpeechProvider (real-time streaming STT, 5-key failover)
/// - Web/preview: SimulatedSpeechProvider (full lifecycle, no network)
library;

export 'voice_factory_stub.dart' if (dart.library.io) 'voice_factory_io.dart';
