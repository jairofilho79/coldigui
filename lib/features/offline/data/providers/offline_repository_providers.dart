import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../domain/ports/pdf_storage_port.dart';
import '../../domain/repositories/offline_pdf_repository.dart';
import '../datasources/offline_pdf_local_datasource.dart';
import '../datasources/pdf_storage_impl.dart';
import '../repositories/offline_pdf_repository_impl.dart';

/// DI — [PdfStoragePort] (nativo: wrapper de [PdfLocalStore]; web: OPFS).
final pdfStoragePortProvider = Provider<PdfStoragePort>((ref) {
  return createPdfStoragePort();
});

/// Revisão do índice offline — sobe a cada escrita que muda disponibilidade.
///
/// É o que invalida `offlineAvailabilityMapProvider` (A5): o mapa observa
/// este contador e relê o índice **uma** vez por mudança, em vez de uma query
/// por card. Mora ao lado da DI porque é ela quem injeta o `bump` no
/// datasource — o datasource, em `data/`, não segura `Ref`.
class OfflineIndexRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Registra uma escrita no índice.
  void bump() => state = state + 1;
}

/// Contador de escritas no índice offline — ver [OfflineIndexRevisionNotifier].
final offlineIndexRevisionProvider =
    NotifierProvider<OfflineIndexRevisionNotifier, int>(
      OfflineIndexRevisionNotifier.new,
    );

/// DI — CRUD Isar [OfflinePdfIndex] via [isarProvider].
final offlinePdfLocalDatasourceProvider = Provider<OfflinePdfLocalDatasource>((
  ref,
) {
  final isar = ref.watch(optionalIsarProvider);
  if (isar == null) return const OfflinePdfLocalDatasource.unavailable();
  return OfflinePdfLocalDatasource(
    isar,
    onIndexChanged: () =>
        ref.read(offlineIndexRevisionProvider.notifier).bump(),
  );
});

/// DI — [OfflinePdfRepositoryImpl].
final offlinePdfRepositoryProvider = Provider<OfflinePdfRepository>((ref) {
  return OfflinePdfRepositoryImpl(
    store: ref.watch(pdfStoragePortProvider),
    local: ref.watch(offlinePdfLocalDatasourceProvider),
  );
});
