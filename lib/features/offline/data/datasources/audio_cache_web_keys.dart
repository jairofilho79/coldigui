import 'dart:js_interop';

import 'package:web/web.dart';

/// Origem lógica do bucket de áudio na Cache API (web) — a mesma usada por
/// [AudioStorageWeb] para escrever/ler e por `WebAudioSourceResolver` para
/// ir direto do cache a um blob (`resolveFromCache`), sem materializar
/// bytes em Dart no meio do caminho.
const audioCacheOfflineOrigin = 'https://plpcg-offline.local';

/// `storageKey` (`plpcg_audio/<relPath>`) → `Request` da mesma origem
/// lógica usada nas escritas — chave compartilhada entre quem grava
/// ([AudioStorageWeb]) e quem só lê para tocar (o resolver de áudio web).
Request audioCacheRequestForKey(String storageKey) => Request(
  Uri(
    scheme: 'https',
    host: Uri.parse(audioCacheOfflineOrigin).host,
    pathSegments: storageKey.split('/'),
  ).toString().toJS,
);
