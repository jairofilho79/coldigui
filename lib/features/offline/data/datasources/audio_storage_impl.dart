import '../../domain/ports/audio_storage_port.dart';
import 'audio_storage_native.dart'
    if (dart.library.js_interop) 'audio_storage_web.dart';

/// Factory por plataforma (conditional import) — como `pdf_storage_impl.dart`.
AudioStoragePort createAudioStoragePort() => createAudioStoragePortImpl();
