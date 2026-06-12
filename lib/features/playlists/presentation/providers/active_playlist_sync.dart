import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/data/providers/carousel_providers.dart';
import '../../data/providers/playlist_providers.dart';
import 'active_playlist_provider.dart';

/// Sincroniza [pdfIds] da playlist ativa com o carousel Isar.
Future<void> syncActivePlaylistFromCarousel(Ref ref) async {
  final activeId = ref.read(activePlaylistIdProvider);
  if (activeId == null) return;

  final pdfIds = await ref.read(carouselRepositoryProvider).getOrderedPdfIds();
  await ref.read(updatePlaylistProvider)(
    playlistId: activeId,
    pdfIds: pdfIds,
  );
}
