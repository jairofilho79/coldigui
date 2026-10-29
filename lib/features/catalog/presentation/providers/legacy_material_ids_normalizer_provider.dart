import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/network/connectivity_stream_provider.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../coldigom/data/constants/coldigom_api_config.dart';
import '../../../coldigom/data/providers/coldigom_remote_providers.dart';
import '../../../offline/data/legacy/offline_index_legacy_id_store.dart';
import '../../../offline/data/providers/offline_repository_providers.dart';
import '../../../offline/presentation/providers/offline_maintenance_lock_provider.dart';
import '../../../pdf_reader/data/providers/pdf_reader_viewer_providers.dart';
import '../../../playlists/data/legacy/playlist_legacy_id_store.dart';
import '../../../playlists/data/providers/playlist_providers.dart';
import '../../../playlists/presentation/providers/playlist_session_prefs.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../data/legacy_ids/prefs_legacy_id_stores.dart';
import '../../domain/legacy_ids/legacy_id_store.dart';
import '../../domain/usecases/normalize_legacy_material_ids.dart';
import 'recently_opened_provider.dart';

/// Crosswalk legado → coldigom (C9).
///
/// Sem `COLDIGOM_API_BASE_URL` (CI, testes sem dart-define) falha na hora: a
/// rodada fica pendente em vez de tentar rede com a base vazia.
final legacyPdfIdResolverProvider = Provider<LegacyPdfIdResolver>((ref) {
  if (ColdigomApiConfig.isBaseUrlMissing) {
    return (_) async => throw StateError('COLDIGOM_API_BASE_URL ausente');
  }
  return ref.watch(coldigomRemoteDatasourceProvider).resolveLegacyPdfIds;
});

/// Normalização única dos ids legados guardados (spec 2026-09-23 §6.2).
///
/// Gatilhos: `hydratePlaylistSession`, cada pull de playlists com linhas
/// novas (`PlaylistSyncNotifier`), a volta da rede (offline → online) e, depois
/// de uma rodada [LegacyIdNormalizationOutcome.deferred], o lock de manutenção
/// offline a soltar. Estado = desfecho da última rodada.
final legacyMaterialIdsNormalizerProvider =
    NotifierProvider<
      LegacyMaterialIdsNormalizer,
      LegacyIdNormalizationOutcome?
    >(LegacyMaterialIdsNormalizer.new);

class LegacyMaterialIdsNormalizer
    extends Notifier<LegacyIdNormalizationOutcome?> {
  /// Espera antes de normalizar quando a rede volta.
  ///
  /// Mutável e estática só para o teste encolher — mesma razão de
  /// `PlaylistSyncNotifier.reconnectDebounce`: a volta vem em rajada e a
  /// primeira pergunta ao crosswalk ainda falharia (a rodada ficaria pendente
  /// até o próximo gatilho).
  static Duration reconnectDebounce = const Duration(seconds: 2);

  /// Rodada em curso, ou `null`.
  Future<LegacyIdNormalizationOutcome>? _inFlight;

  /// Rodada a mais pedida durante a em curso — no máximo uma à espera.
  Completer<LegacyIdNormalizationOutcome>? _followUp;
  Timer? _reconnectTimer;

  /// A última rodada adiou o índice offline: corre outra quando o lock de
  /// manutenção soltar.
  var _retryWhenLockFree = false;

  @override
  LegacyIdNormalizationOutcome? build() {
    ref.onDispose(() {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    });

    // Uma rodada pendente (crosswalk fora do ar) tenta de novo quando a rede
    // volta. Só a transição offline → online: o boot já pede pelo hydrate.
    ref.listen(connectivityStreamProvider, (prev, next) {
      final wasOffline = prev?.asData?.value == false;
      final online = next.asData?.value ?? false;
      if (!wasOffline || !online) return;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(reconnectDebounce, () {
        if (!ref.mounted) return;
        unawaited(run());
      });
    });

    // O reconcile ou um download seguravam o lock: sem isto o índice ficava
    // com as chaves legadas até o próximo boot. Só uma rodada por soltura.
    ref.listen(offlineMaintenanceLockProvider, (_, owner) {
      if (owner != null || !_retryWhenLockFree) return;
      _retryWhenLockFree = false;
      unawaited(run());
    });

    return null;
  }

  /// Pede uma rodada. Nunca lança; nunca há duas rodadas em paralelo.
  ///
  /// Com uma rodada em curso, o pedido não se junta a ela: a rodada já
  /// recolheu os ids e só reescreve os que perguntou ao crosswalk, e um id
  /// legado gravado entretanto (o pull do boot, com o hydrate à espera do
  /// crosswalk) ficaria para o próximo gatilho. Em vez disso marca **uma**
  /// rodada a mais, que começa quando a atual acaba; os pedidos seguintes
  /// partilham-na. Sem legados restantes ela não vai à rede nem escreve.
  Future<LegacyIdNormalizationOutcome> run() {
    if (_inFlight == null) return _startRound();
    return (_followUp ??= Completer<LegacyIdNormalizationOutcome>()).future;
  }

  Future<LegacyIdNormalizationOutcome> _startRound() {
    final round = _run();
    _inFlight = round;
    // `_run` nunca lança.
    unawaited(
      round.then((_) {
        _inFlight = null;
        final followUp = _followUp;
        if (followUp == null) return;
        _followUp = null;
        followUp.complete(
          ref.mounted
              ? _startRound()
              : const LegacyIdNormalizationOutcome(pending: true),
        );
      }),
    );
    return round;
  }

  Future<LegacyIdNormalizationOutcome> _run() async {
    try {
      final outcome = await NormalizeLegacyMaterialIds(
        stores: _stores(),
        resolve: ref.read(legacyPdfIdResolverProvider),
      )();
      if (!ref.mounted) return outcome;
      state = outcome;
      if (outcome.deferred) _scheduleAfterLock();
      if (outcome.rewritten > 0) {
        // As prefs mudaram por baixo dos notifiers que as leram no build, e o
        // `PlaylistsNotifier` não observa o banco (mesma razão do reload pós-
        // sync em `PlaylistSyncNotifier._run`).
        ref.invalidate(recentlyOpenedProvider);
        ref.invalidate(carouselFocusedKeyProvider);
        await ref.read(playlistsProvider.notifier).reload();
      }
      return outcome;
    } on Object catch (e) {
      debugPrint('[legacy-ids] normalização abortada: $e');
      return const LegacyIdNormalizationOutcome(pending: true);
    }
  }

  /// Pede a rodada seguinte para quando o lock de manutenção soltar — ou
  /// já, se soltou enquanto esta rodada acabava (o ouvinte não viu a volta).
  void _scheduleAfterLock() {
    if (ref.read(offlineMaintenanceLockProvider) == null) {
      unawaited(run());
    } else {
      _retryWhenLockFree = true;
    }
  }

  /// Sem Isar não há playlists nem índice para migrar — só as prefs (§6.2).
  List<LegacyIdStore> _stores() {
    final prefs = ref.read(sharedPreferencesProvider);
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    return [
      if (ref.read(isarAvailableProvider)) ...[
        PlaylistLegacyIdStore(
          ref.read(playlistRepositoryProvider),
          currentSub: _currentSub,
        ),
        OfflineIndexLegacyIdStore(
          ref.read(offlinePdfRepositoryProvider),
          tryLock: () => lock.tryAcquire(OfflineMaintenanceOwner.normalize),
          unlock: () => lock.release(OfflineMaintenanceOwner.normalize),
        ),
      ],
      RecentlyOpenedLegacyIdStore(prefs),
      PdfLastPagesLegacyIdStore(ref.read(readerPreferencesDatasourceProvider)),
      FocusedEntryLegacyIdStore(prefs, key: kCarouselFocusedPdfIdPrefsKey),
    ];
  }

  /// `sub` da sessão **na hora** da reescrita — o login pode mudar enquanto o
  /// crosswalk responde. Sem sessão (ou notifier descartado) = `null`, que a
  /// store trata como lista de outra conta.
  String? _currentSub() {
    if (!ref.mounted) return null;
    return ref.read(authStateProvider).asData?.value?.googleSub;
  }
}
