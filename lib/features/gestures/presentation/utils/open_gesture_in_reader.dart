import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/gesture_reader_url_builder.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/gesture_material.dart';

/// Resultado de decodificar um id de material como documento de gestos.
///
/// [isGesture] falso = siga pelo caminho de PDF; verdadeiro com [location]
/// nula = é gesto, mas o cache está frio (não há para onde navegar).
class GestureRoute {
  const GestureRoute({required this.isGesture, this.location});

  final bool isGesture;
  final String? location;
}

/// Classifica [materialId] como gesto e resolve a rota `/gestos` pelo cache.
GestureRoute gestureRouteFor(
  String materialId,
  Map<String, GestureMaterial> gestureCache,
) {
  if (materialIdKindOf(materialId) != MaterialKind.gesture) {
    return const GestureRoute(isGesture: false);
  }
  final gesture = gestureCache[materialId];
  if (gesture == null) return const GestureRoute(isGesture: true);
  return GestureRoute(
    isGesture: true,
    location: buildGestureReaderLocation(
      gestureId: gesture.gestureId,
      titulo: gesture.nome,
      subtitulo: gesture.numero,
    ),
  );
}

/// Abre [gesture] em `/gestos`, entrando na lista ativa como o PDF faz.
///
/// Espelha `openChordInReader`: o documento é buscado pelo
/// `gestureDocumentProvider` na própria tela.
Future<void> openGestureInReader({
  required WidgetRef ref,
  required BuildContext context,
  required GestureMaterial gesture,
}) async {
  ref.read(coldigomCacheWriterProvider).mergeGestures([gesture]);

  await ref
      .read(playlistsProvider.notifier)
      .addLouvorToActivePlaylist(gesture.gestureId);

  if (!context.mounted) return;

  unawaited(
    context.push(
      buildGestureReaderLocation(
        gestureId: gesture.gestureId,
        titulo: gesture.nome,
        subtitulo: gesture.numero,
      ),
    ),
  );
}
