import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../domain/ports/audio_storage_port.dart';
import '../../domain/repositories/offline_audio_repository.dart';
import '../datasources/audio_storage_impl.dart';
import '../datasources/offline_audio_local_datasource.dart';
import '../repositories/offline_audio_repository_impl.dart';

/// DI — [AudioStoragePort] (nativo: documents; web: Cache API).
final audioStoragePortProvider = Provider<AudioStoragePort>((ref) {
  return createAudioStoragePort();
});

/// Revisão do índice de áudio — sobe a cada escrita; é o que re-deriva o
/// `materialAvailabilityMapProvider` e as stats Coldigom (mesmo papel de
/// `offlineIndexRevisionProvider` para os PDFs).
class OfflineAudioIndexRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final offlineAudioIndexRevisionProvider =
    NotifierProvider<OfflineAudioIndexRevisionNotifier, int>(
      OfflineAudioIndexRevisionNotifier.new,
    );

/// DI — CRUD Isar [OfflineAudioIndex]; degradado sem Isar.
final offlineAudioLocalDatasourceProvider =
    Provider<OfflineAudioLocalDatasource>((ref) {
      final isar = ref.watch(optionalIsarProvider);
      if (isar == null) return const OfflineAudioLocalDatasource.unavailable();
      return OfflineAudioLocalDatasource(
        isar,
        onIndexChanged: () =>
            ref.read(offlineAudioIndexRevisionProvider.notifier).bump(),
      );
    });

/// DI — [OfflineAudioRepositoryImpl].
final offlineAudioRepositoryProvider = Provider<OfflineAudioRepository>((ref) {
  return OfflineAudioRepositoryImpl(
    store: ref.watch(audioStoragePortProvider),
    local: ref.watch(offlineAudioLocalDatasourceProvider),
  );
});
