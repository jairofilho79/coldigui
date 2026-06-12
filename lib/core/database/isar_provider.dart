import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

/// Provider de instância Isar (ADR-001).
///
/// Schemas: [LouvorCache], [CarouselEntry], [Playlist], [OfflinePdfIndex].
/// Sobrescrever em `main()` após `Isar.open`.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError(
    'Override isarProvider in main with Isar instance',
  );
});
