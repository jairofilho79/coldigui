import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../coldigom/data/providers/coldigom_dio_provider.dart';
import '../../domain/entities/chordpro_song.dart';
import '../datasources/chord_content_datasource.dart';

/// Datasource de conteúdo de cifra.
final chordContentDatasourceProvider = Provider<ChordContentDatasource>((ref) {
  return ChordContentDatasource(
    ref.watch(coldigomDioProvider),
    apiBase: AppConfig.apiBaseUrl,
  );
});

/// Música de um `r2Key`, ou `null` se indisponível.
///
/// Cache compartilhado entre o sheet (que usa o resultado para decidir se lista
/// a cifra) e o leitor (que usa para renderizar). `keepAlive` porque os
/// arquivos são minúsculos e reabrir a mesma cifra é comum.
final chordSongProvider = FutureProvider.family<ChordProSong?, String>((
  ref,
  r2Key,
) {
  ref.keepAlive();
  return ref.watch(chordContentDatasourceProvider).fetchSong(r2Key);
});
