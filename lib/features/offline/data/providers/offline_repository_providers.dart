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

/// DI — CRUD Isar [OfflinePdfIndex] via [isarProvider].
final offlinePdfLocalDatasourceProvider = Provider<OfflinePdfLocalDatasource>((
  ref,
) {
  final isar = ref.watch(optionalIsarProvider);
  if (isar == null) return const OfflinePdfLocalDatasource.unavailable();
  return OfflinePdfLocalDatasource(isar);
});

/// DI — [OfflinePdfRepositoryImpl].
final offlinePdfRepositoryProvider = Provider<OfflinePdfRepository>((ref) {
  return OfflinePdfRepositoryImpl(
    store: ref.watch(pdfStoragePortProvider),
    local: ref.watch(offlinePdfLocalDatasourceProvider),
  );
});
