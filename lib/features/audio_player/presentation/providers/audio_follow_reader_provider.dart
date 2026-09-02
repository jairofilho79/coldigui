import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_louvores_provider.dart';
import '../../../carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../domain/utils/find_material_for_group.dart';
import 'audio_player_session_provider.dart';

/// Chave SharedPreferences do toggle "Seguir o áudio".
const kAudioFollowReaderPrefsKey = 'audio_follow_reader';

/// "Seguir o áudio": trocar o material aberto no leitor quando a faixa muda.
///
/// Ligado por padrão (D1 — quem ouve normalmente quer ver a mesma partitura) e
/// persistido em SharedPreferences.
class AudioFollowReaderNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .watch(sharedPreferencesProvider)
            .getBool(kAudioFollowReaderPrefsKey) ??
        true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kAudioFollowReaderPrefsKey, enabled);
  }

  Future<void> toggle() => setEnabled(!state);
}

/// Toggle global de "Seguir o áudio" (face de áudio e player).
final audioFollowReaderProvider =
    NotifierProvider<AudioFollowReaderNotifier, bool>(
      AudioFollowReaderNotifier.new,
    );

/// Decide se a troca de faixa deve trocar o material aberto no leitor.
///
/// Regra pura de [listenAudioFollowReader]. Nunca navega:
/// - fora de `/leitor` e `/cifra`;
/// - sem faixa anterior ([previousGroupId] `null`) — é a restauração da sessão
///   no boot ([hydratePlaylistSession] chama `restoreQueue` sem tocar nada), e
///   um reload ou deep link no leitor não pode ser sequestrado por ela;
/// - quando o louvor **aberto** já é o da faixa ([currentMaterialGroupId]): a
///   entrada é louvor + material escolhido (PRODUCT §4), então uma cifra aberta
///   não vira a partitura do mesmo louvor.
bool shouldFollowAudioInReader({
  required bool enabled,
  required bool isReaderRoute,
  required String? previousGroupId,
  required String? nextGroupId,
  required String? currentMaterialGroupId,
  required String? targetMaterialPdfId,
}) {
  if (!enabled || !isReaderRoute) return false;
  if (nextGroupId == null || nextGroupId.isEmpty) return false;
  if (previousGroupId == null) return false;
  if (nextGroupId == previousGroupId) return false;
  if (targetMaterialPdfId == null || targetMaterialPdfId.isEmpty) return false;
  if (nextGroupId == currentMaterialGroupId) return false;
  return true;
}

/// `pdfId` (PDF ou cifra) do louvor [groupId] — lista ativa primeiro.
///
/// [listen] `false` dentro de callbacks (`ref.listen`, `onPressed`), onde
/// `ref.watch` é proibido.
String? resolveMaterialForGroup(
  WidgetRef ref,
  String? groupId, {
  bool listen = true,
}) {
  if (groupId == null || groupId.isEmpty) return null;

  final carouselItems = listen
      ? ref.watch(carouselLouvoresProvider)
      : ref.read(carouselLouvoresProvider);
  final coldigomCache = listen
      ? ref.watch(coldigomLouvoresCacheProvider)
      : ref.read(coldigomLouvoresCacheProvider);
  final chordCache = listen
      ? ref.watch(coldigomChordMaterialsCacheProvider)
      : ref.read(coldigomChordMaterialsCacheProvider);
  final manifest = listen
      ? ref.watch(louvoresManifestProvider)
      : ref.read(louvoresManifestProvider);

  return findMaterialForGroup(
    groupId: groupId,
    carouselPdfIds: [for (final item in carouselItems) item.pdfId],
    byPdfId: coldigomCache,
    chordsById: chordCache,
    catalog: manifest.value?.louvores ?? const [],
  );
}

/// `groupId` do louvor a que [materialId] (PDF ou cifra) pertence.
///
/// Contraparte de [resolveMaterialForGroup] — usado para saber de que louvor é
/// o material já aberto no leitor.
String? resolveGroupIdForMaterial(
  WidgetRef ref,
  String? materialId, {
  bool listen = true,
}) {
  if (materialId == null || materialId.isEmpty) return null;

  final coldigomCache = listen
      ? ref.watch(coldigomLouvoresCacheProvider)
      : ref.read(coldigomLouvoresCacheProvider);
  final chordCache = listen
      ? ref.watch(coldigomChordMaterialsCacheProvider)
      : ref.read(coldigomChordMaterialsCacheProvider);
  final manifest = listen
      ? ref.watch(louvoresManifestProvider)
      : ref.read(louvoresManifestProvider);

  return groupIdForMaterialId(
    materialId: materialId,
    byPdfId: coldigomCache,
    chordsById: chordCache,
    catalog: manifest.value?.louvores ?? const [],
  );
}

/// Abre no leitor o material do louvor [groupId] (botão "partitura/cifra").
///
/// `replace` na rota de leitura (troca o material sem empilhar) e `push` fora
/// dela — mesma convenção de [openCarouselPdfInReader] no carousel.
Future<void> openMaterialForGroupInReader({
  required WidgetRef ref,
  required BuildContext context,
  required String groupId,
}) async {
  final targetPdfId = resolveMaterialForGroup(ref, groupId, listen: false);
  if (targetPdfId == null) return;

  final onReader = isReaderRoute(context);
  await openCarouselPdfInReader(
    ref: ref,
    context: context,
    pdfId: targetPdfId,
    navigate: (location) async {
      if (onReader) {
        context.replace(location);
      } else {
        context.push(location);
      }
    },
  );
  if (!context.mounted) return;
  ref.read(carouselFocusedIndexProvider.notifier).focusPdfId(targetPdfId);
}

/// `true` em `/leitor` ou `/cifra`; `false` sem GoRouter (testes de widget).
bool isReaderRoute(BuildContext context) {
  final path = currentRoutePath(context);
  return path == RoutePaths.reader || path == RoutePaths.chords;
}

/// Path da rota atual, ou `null` quando não há GoRouter no contexto.
String? currentRoutePath(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  return GoRouterState.of(context).uri.path;
}

/// Material aberto no leitor (`pdfId` da URL — cifras usam a mesma chave).
String? currentReaderMaterialPdfId(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return null;
  final pdfId = GoRouterState.of(
    context,
  ).uri.queryParameters[UrlSyncParams.pdfId];
  return pdfId == null || pdfId.isEmpty ? null : pdfId;
}

/// Liga a sessão de áudio ao leitor: ao trocar de louvor na fila, troca o
/// material aberto em `/leitor` ou `/cifra` (D1).
///
/// Chamar no `build` de um widget montado em todas as rotas do shell
/// ([CarouselChips]). Fora das rotas de leitura nada acontece.
void listenAudioFollowReader(WidgetRef ref, BuildContext context) {
  ref.listen(
    audioPlayerSessionProvider.select(
      (session) => session.currentTrack?.groupId,
    ),
    (previousGroupId, nextGroupId) {
      final targetPdfId = resolveMaterialForGroup(
        ref,
        nextGroupId,
        listen: false,
      );
      if (!shouldFollowAudioInReader(
        enabled: ref.read(audioFollowReaderProvider),
        isReaderRoute: isReaderRoute(context),
        previousGroupId: previousGroupId,
        nextGroupId: nextGroupId,
        currentMaterialGroupId: resolveGroupIdForMaterial(
          ref,
          currentReaderMaterialPdfId(context),
          listen: false,
        ),
        targetMaterialPdfId: targetPdfId,
      )) {
        return;
      }

      unawaited(
        openMaterialForGroupInReader(
          ref: ref,
          context: context,
          groupId: nextGroupId!,
        ),
      );
    },
  );
}
