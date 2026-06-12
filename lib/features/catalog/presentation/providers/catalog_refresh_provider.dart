import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_providers.dart';
import 'louvores_manifest_provider.dart';

/// Status do refresh manual UC-12 (Fase 1.5).
enum CatalogRefreshStatus { idle, loading, error }

/// Estado do banner "Atualizar lista" na biblioteca.
class CatalogRefreshState {
  const CatalogRefreshState._({
    required this.status,
    this.errorMessage,
  });

  const CatalogRefreshState.idle() : this._(status: CatalogRefreshStatus.idle);

  const CatalogRefreshState.loading()
      : this._(status: CatalogRefreshStatus.loading);

  const CatalogRefreshState.error(String message)
      : this._(status: CatalogRefreshStatus.error, errorMessage: message);

  final CatalogRefreshStatus status;
  final String? errorMessage;

  bool get isLoading => status == CatalogRefreshStatus.loading;
  bool get isIdle => status == CatalogRefreshStatus.idle;
  bool get hasError => status == CatalogRefreshStatus.error;
}

/// Orquestra refresh manual: use case → invalidate [louvoresManifestProvider].
class CatalogRefreshNotifier extends Notifier<CatalogRefreshState> {
  @override
  CatalogRefreshState build() => const CatalogRefreshState.idle();

  /// Dispara fetch remoto obrigatório e invalida o manifest.
  Future<void> refresh() async {
    state = const CatalogRefreshState.loading();
    try {
      await ref.read(forceRefreshCatalogProvider)();
      ref.invalidate(louvoresManifestProvider);
      state = const CatalogRefreshState.idle();
    } on Object catch (error) {
      state = CatalogRefreshState.error('$error');
    }
  }
}

/// Estado do banner de refresh manual na biblioteca (UC-12 Fase 1.5).
final catalogRefreshProvider =
    NotifierProvider<CatalogRefreshNotifier, CatalogRefreshState>(
  CatalogRefreshNotifier.new,
);
