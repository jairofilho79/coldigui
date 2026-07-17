import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/dio_provider.dart';
import '../../domain/repositories/audio_flag_repository.dart';
import '../../domain/usecases/sync_audio_flags.dart';
import '../datasources/audio_flag_local_datasource.dart';
import '../datasources/audio_flag_remote_datasource.dart';
import '../repositories/audio_flag_repository_impl.dart';

final audioFlagLocalDatasourceProvider = Provider<AudioFlagLocalDatasource>((
  ref,
) {
  final isar = ref.watch(optionalIsarProvider);
  if (isar == null) return const AudioFlagLocalDatasource.unavailable();
  return AudioFlagLocalDatasource(isar);
});

final audioFlagRepositoryProvider = Provider<AudioFlagRepository>((ref) {
  return AudioFlagRepositoryImpl(ref.watch(audioFlagLocalDatasourceProvider));
});

final audioFlagRemoteDatasourceProvider = Provider<AudioFlagRemoteDatasource>((
  ref,
) {
  return AudioFlagRemoteDatasource(ref.watch(dioProvider));
});

final syncAudioFlagsProvider = Provider<SyncAudioFlags>((ref) {
  final remote = ref.watch(audioFlagRemoteDatasourceProvider);
  return SyncAudioFlags(
    ref.watch(audioFlagRepositoryProvider),
    remote.fetchAll,
    ({required idToken, required flag}) =>
        remote.upsert(idToken: idToken, flag: flag),
    ({required idToken, required flagId}) =>
        remote.softDelete(idToken: idToken, flagId: flagId),
  );
});
