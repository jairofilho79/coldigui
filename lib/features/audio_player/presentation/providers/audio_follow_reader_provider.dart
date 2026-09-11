import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../carousel/presentation/providers/carousel_focused_index_provider.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
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

/// Inverte o toggle a partir de um `onPressed`, sem descartar o `Future`.
///
/// O estado em memória já mudou de forma síncrona; o que pode falhar é a
/// gravação em SharedPreferences, e isso precisa aparecer no console em vez de
/// virar uma exceção não observada.
void toggleAudioFollowReader(WidgetRef ref) {
  unawaited(
    ref
        .read(audioFollowReaderProvider.notifier)
        .toggle()
        .catchError(
          (Object error) =>
              debugPrint('[audio] falha ao salvar "seguir o áudio": $error'),
        ),
  );
}

/// Decide se a troca de faixa deve trocar o material aberto no leitor.
///
/// Regra pura de [listenAudioFollowReader]. Nunca navega:
/// - fora de `/leitor` e `/cifra`;
/// - enquanto [sessionRestoredWithoutPlayback] — a fila veio de `restoreQueue`
///   no boot ([hydratePlaylistSession]) e o usuário ainda não deu play, então
///   um reload ou deep link no leitor não pode ser sequestrado por ela. É um
///   sinal explícito da sessão: "sem faixa anterior" servia de proxy e engolia
///   a primeira faixa de uma sessão nova (A6);
/// - quando o louvor **aberto** já é o da faixa ([currentMaterialGroupId]): a
///   entrada é louvor + material escolhido (PRODUCT §4), então uma cifra aberta
///   não vira a partitura do mesmo louvor.
bool shouldFollowAudioInReader({
  required bool enabled,
  required bool isReaderRoute,
  required bool sessionRestoredWithoutPlayback,
  required String? previousGroupId,
  required String? nextGroupId,
  required String? currentMaterialGroupId,
  required String? targetMaterialPdfId,
}) {
  if (!enabled || !isReaderRoute) return false;
  if (nextGroupId == null || nextGroupId.isEmpty) return false;
  if (sessionRestoredWithoutPlayback) return false;
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
      ? ref.watch(carouselItemsProvider)
      : ref.read(carouselItemsProvider);
  final lookup = listen
      ? ref.watch(catalogMaterialLookupProvider)
      : ref.read(catalogMaterialLookupProvider);
  final manifest = listen
      ? ref.watch(louvoresManifestProvider)
      : ref.read(louvoresManifestProvider);

  return findMaterialForGroup(
    groupId: groupId,
    carouselPdfIds: [for (final item in carouselItems) item.materialId],
    byPdfId: lookup.coldigomLouvoresByPdfId,
    chordsById: lookup.chordsById,
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

  final lookup = listen
      ? ref.watch(catalogMaterialLookupProvider)
      : ref.read(catalogMaterialLookupProvider);
  final manifest = listen
      ? ref.watch(louvoresManifestProvider)
      : ref.read(louvoresManifestProvider);

  return groupIdForMaterialId(
    materialId: materialId,
    byPdfId: lookup.coldigomLouvoresByPdfId,
    chordsById: lookup.chordsById,
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

  // O foco é por ocorrência: o id vira chave pela **primeira** ocorrência dele
  // na face, que é a mesma escolha de [resolveMaterialForGroup]. Fora da face
  // (louvor que não está na lista) `focusKey` é no-op e o foco fica onde está.
  final items = ref.read(carouselItemsProvider);
  final index = items.indexWhere((item) => item.materialId == targetPdfId);
  if (index < 0) return;
  ref.read(carouselFocusedIndexProvider.notifier).focusKey(items[index].key);
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
        sessionRestoredWithoutPlayback: ref
            .read(audioPlayerSessionProvider)
            .restoredWithoutPlayback,
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
