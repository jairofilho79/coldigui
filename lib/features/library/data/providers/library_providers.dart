import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/browse_library.dart';
import '../../domain/usecases/paginate_louvores.dart';
import '../../domain/usecases/sort_louvores.dart';

/// Use case UC-03 — navegar biblioteca filtrada (sem busca obrigatória).
final browseLibraryProvider = Provider<BrowseLibrary>((ref) {
  return const BrowseLibrary();
});

/// Use case UC-03 — ordenar louvores por número ou nome.
final sortLouvoresProvider = Provider<SortLouvores>((ref) {
  return const SortLouvores();
});

/// Use case UC-03 — paginar louvores (10/25/50/100).
final paginateLouvoresProvider = Provider<PaginateLouvores>((ref) {
  return const PaginateLouvores();
});
