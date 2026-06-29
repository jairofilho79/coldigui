import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/pdf_reader_prefetch_providers.dart';
import 'pdf_reader_document_provider.dart';
import 'reader_carousel_position_provider.dart';

/// Parâmetros para prefetch de PDFs adjacentes no carousel in-reader.
@immutable
class ReaderAdjacentPdfPrefetchParams {
  const ReaderAdjacentPdfPrefetchParams({
    required this.filePath,
    required this.pdfId,
  });

  final String filePath;
  final String pdfId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReaderAdjacentPdfPrefetchParams &&
            filePath == other.filePath &&
            pdfId == other.pdfId;
  }

  @override
  int get hashCode => Object.hash(filePath, pdfId);
}

/// Side-effect provider — prefetch dos vizinhos após sessão PDF carregar (#8).
///
/// Fire-and-forget, prioridade baixa: só dispara quando
/// [pdfReaderSessionProvider] entrega dados. Respeita [prefetchNetworkPolicyProvider]
/// (sem prefetch em dados móveis por padrão).
final readerAdjacentPdfPrefetchProvider = Provider.autoDispose
    .family<void, ReaderAdjacentPdfPrefetchParams>((ref, params) {
      var prefetchGeneration = 0;

      Future<void> schedulePrefetch() async {
        final generation = ++prefetchGeneration;

        final session = ref.read(pdfReaderSessionProvider(params.filePath));
        if (!session.hasValue) return;

        final position = ref.read(readerCarouselPositionProvider(params.pdfId));
        if (position == null) return;

        final catalog = ref.read(prefetchLouvorCatalogProvider);
        final prefetch = ref.read(prefetchAdjacentCarouselPdfsProvider);

        await Future<void>.delayed(Duration.zero);
        if (generation != prefetchGeneration) return;

        await prefetch.call(
          catalog: catalog,
          previousPdfId: position.previousPdfId,
          nextPdfId: position.nextPdfId,
        );
      }

      ref.listen(pdfReaderSessionProvider(params.filePath), (previous, next) {
        next.whenData((_) {
          schedulePrefetch();
        });
      });

      ref.listen(readerCarouselPositionProvider(params.pdfId), (
        previous,
        next,
      ) {
        if (next == null) return;
        if (previous?.previousPdfId == next.previousPdfId &&
            previous?.nextPdfId == next.nextPdfId) {
          return;
        }
        final session = ref.read(pdfReaderSessionProvider(params.filePath));
        if (session.hasValue) {
          schedulePrefetch();
        }
      });

      ref.watch(pdfReaderSessionProvider(params.filePath));
    });
