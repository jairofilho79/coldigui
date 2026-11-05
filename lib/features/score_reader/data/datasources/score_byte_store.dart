import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'score_byte_store_native.dart'
    if (dart.library.js_interop) 'score_byte_store_web.dart';

/// Persistência das partituras abertas e do SoundFont completo, por chave.
///
/// Mesma forma do store de figuras dos gestos (filesystem no nativo, Cache
/// API na web), em store próprio: é o que permite reabrir uma partitura e
/// tocá-la com o SoundFont completo sem rede.
///
/// Best-effort: nenhuma operação lança — o que não gravou é baixado de novo.
abstract interface class ScoreByteStorePort {
  Future<Uint8List?> read(String key);

  /// Há cópia local de [key]? Não lê os bytes.
  Future<bool> contains(String key);

  /// Nomes ([scoreByteStoreFileName]) de tudo que está gravado.
  Future<Set<String>> fileNames();

  Future<void> write(String key, Uint8List bytes);
  Future<void> delete(String key);
}

/// Subdiretório (nativo) / prefixo lógico (web) do store.
const kScoreByteStoreSubdir = 'plpcg_scores';

/// Nome estável, de tamanho fixo e seguro para o filesystem.
String scoreByteStoreFileName(String key) =>
    sha256.convert(utf8.encode(key.trim())).toString();

/// Factory por plataforma (import condicional).
ScoreByteStorePort createScoreByteStore() => createScoreByteStoreImpl();
