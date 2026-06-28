import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../domain/repositories/offline_pdf_repository.dart';
import '../datasources/offline_pdf_local_datasource.dart';
import '../datasources/pdf_local_store.dart';
import '../repositories/offline_pdf_repository_impl.dart';

/// DI — [PdfLocalStore] em `ApplicationDocumentsDirectory/plpcg_pdfs/`.
final pdfLocalStoreProvider = Provider<PdfLocalStore>((ref) {
  return PdfLocalStore();
});

/// DI — CRUD Isar [OfflinePdfIndex] via [isarProvider].
final offlinePdfLocalDatasourceProvider =
    Provider<OfflinePdfLocalDatasource>((ref) {
  return OfflinePdfLocalDatasource(ref.watch(isarProvider));
});

/// DI — [OfflinePdfRepositoryImpl].
final offlinePdfRepositoryProvider = Provider<OfflinePdfRepository>((ref) {
  return OfflinePdfRepositoryImpl(
    store: ref.watch(pdfLocalStoreProvider),
    local: ref.watch(offlinePdfLocalDatasourceProvider),
  );
});
