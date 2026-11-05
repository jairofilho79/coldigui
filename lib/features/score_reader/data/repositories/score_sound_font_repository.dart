import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:soundfont_kit/soundfont_kit.dart';

import '../../../../core/utils/coldigom_asset_url.dart';
import '../datasources/fallback_sound_font.dart';
import '../datasources/score_byte_store.dart';

/// Chave R2 do SoundFont General MIDI completo (FluidR3Mono_GM, MIT — o
/// padrão do MuseScore 3; ~23 MB). Sobrescrevível em build com
/// `--dart-define=SCORE_SOUNDFONT_KEY=...`.
const kScoreSoundFontKey = String.fromEnvironment(
  'SCORE_SOUNDFONT_KEY',
  defaultValue: 'assets/shared/soundfonts/FluidR3Mono_GM.sf3',
);

/// SoundFonts do leitor de partituras.
///
/// O som mínimo ([fallback]) é gerado em memória e está sempre disponível:
/// a partitura toca na hora, mesmo sem rede. O completo (um timbre por
/// instrumento) é baixado sob demanda e fica no store para uso offline.
class ScoreSoundFontRepository {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado.
  ScoreSoundFontRepository(
    this._store,
    this._dio, {
    required String apiBase,
    this.key = kScoreSoundFontKey,
  })
    // ignore: prefer_initializing_formals
    : _apiBase = apiBase;

  final ScoreByteStorePort _store;
  final Dio _dio;
  final String _apiBase;
  final String key;

  Uint8List? _fallback;

  Uint8List get fallback => _fallback ??= buildFallbackSoundFont();

  Future<Uint8List?> readCached() async {
    final bytes = await _store.read(key);
    if (bytes == null) return null;
    try {
      _validateHeader(bytes);
      return bytes;
    } on FormatException catch (error) {
      debugPrint('[partitura] SoundFont em cache inválido: $error');
      await _store.delete(key);
      return null;
    }
  }

  /// Baixa o SoundFont completo e grava no store. Lança em falha de rede —
  /// quem chama decide se avisa ou segue com o som mínimo.
  Future<Uint8List> download({
    void Function(double progress)? onProgress,
  }) async {
    final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: _apiBase);
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        // O arquivo tem dezenas de MB; o timeout padrão (30 s) é para JSON.
        receiveTimeout: const Duration(minutes: 10),
      ),
      onReceiveProgress: onProgress == null
          ? null
          : (received, total) {
              if (total > 0) onProgress((received / total).clamp(0, 1));
            },
    );
    if (response.statusCode != 200) {
      throw StateError('SoundFont HTTP ${response.statusCode} em $url');
    }
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('SoundFont vazio em $url');
    }
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    _validateHeader(bytes);
    final soundFont = await SoundFontFile.fromBytes(bytes);
    if (soundFont.presets.isEmpty || soundFont.samples.isEmpty) {
      throw const FormatException('SoundFont sem instrumentos ou amostras');
    }
    await _store.write(key, bytes);
    return bytes;
  }

  static void _validateHeader(Uint8List bytes) {
    if (bytes.length < 12 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'sfbk' ||
        ByteData.sublistView(bytes).getUint32(4, Endian.little) + 8 >
            bytes.length) {
      throw const FormatException('SoundFont SF2/SF3 inválido ou truncado');
    }
  }
}
