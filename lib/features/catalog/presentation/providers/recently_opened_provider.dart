import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';

final _log = AppLogger.of('catalog');

/// Teto de ids guardados — chips «Abertos recentemente» na Home (B.1/C4).
const kRecentlyOpenedMaxSize = 8;

/// Ids de material abertos recentemente na Home, mais recente primeiro
/// (B.1/C4).
///
/// Grava a partir de dois sinais, ambos ouvidos aqui dentro do `build`:
/// - `readerRouteParamsProvider` — `UrlSyncParams.pdfId` ao entrar em
///   `/leitor` ou `/cifra` (os dois espelham o id nesse mesmo campo: o
///   comentário de `ChordReaderScreen` explica que cifra e PDF dividem o
///   mesmo espaço de ids);
/// - `audioPlayerSessionProvider` — `currentTrack.audioId` ao trocar de
///   faixa.
///
/// **Riverpod 3.3:** um `ref.listen` dentro do `build` de um `Notifier` só
/// dispara enquanto o próprio notifier tiver pelo menos um observador vivo —
/// é por isso que [HomeScreen] precisa **observar** este provider (basta um
/// `ref.watch`) em vez de só lê-lo sob demanda; sem isso os dois `ref.listen`
/// abaixo nunca disparariam fora da Home.
///
/// Sem Isar: persistido em SharedPreferences (`StorageKeys.recentlyOpened`,
/// JSON) — a Home não depende do banco local para mostrar isto.
class RecentlyOpenedNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.listen(readerRouteParamsProvider, (previous, next) {
      final id = next[UrlSyncParams.pdfId];
      if (id != null && id.isNotEmpty) record(id);
    });
    ref.listen(
      audioPlayerSessionProvider.select(
        (session) => session.currentTrack?.audioId,
      ),
      (previous, next) {
        if (next != null && next.isNotEmpty) record(next);
      },
    );
    return _load();
  }

  List<String> _load() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(StorageKeys.recentlyOpened);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList(growable: false);
    } on Object catch (e) {
      _log.warn('recentlyOpened: JSON inválido em SharedPreferences', e);
      return const [];
    }
  }

  /// Registra [materialId] como o mais recente — dedupe, teto de
  /// [kRecentlyOpenedMaxSize], persiste.
  void record(String materialId) {
    final deduped = [materialId, ...state.where((id) => id != materialId)];
    state = deduped.length > kRecentlyOpenedMaxSize
        ? deduped.sublist(0, kRecentlyOpenedMaxSize)
        : deduped;
    unawaited(_persist());
  }

  /// Esvazia a lista.
  void clear() {
    state = const [];
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.recentlyOpened, jsonEncode(state));
  }
}

/// Chips «Abertos recentemente» da Home (B.1/C4).
final recentlyOpenedProvider =
    NotifierProvider<RecentlyOpenedNotifier, List<String>>(
      RecentlyOpenedNotifier.new,
    );
