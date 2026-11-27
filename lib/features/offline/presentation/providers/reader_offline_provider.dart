import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../chords/data/providers/chord_providers.dart';
import '../../../coldigom/data/providers/coldigom_catalog_data_providers.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../gestures/data/providers/gesture_providers.dart';
import '../../data/providers/offline_audio_providers.dart';
import '../../data/providers/offline_coldigom_providers.dart';
import '../../data/providers/offline_repository_providers.dart';
import '../../data/providers/reader_offline_exclusions_provider.dart';
import '../../domain/entities/offline_reader_material.dart';
import 'offline_coldigom_stats_provider.dart';
import 'offline_maintenance_lock_provider.dart';

final readerOfflineAvailableProvider = FutureProvider.autoDispose
    .family<bool, OfflineReaderMaterial>(retry: (_, _) => null, (ref, item) {
      if (!ref.watch(isarAvailableProvider)) return false;
      switch (item.kind) {
        case MaterialKind.lyrics:
          ref.watch(coldigomCatalogRowProvider(item.key));
          final excluded = ref.watch(
            readerOfflineExclusionsProvider.select(
              (keys) =>
                  keys.contains(readerOfflineExclusion(item.kind, item.key)),
            ),
          );
          return !excluded &&
              _hasLyrics(
                ref
                    .watch(coldigomCatalogLocalDatasourceProvider)
                    .findByPraiseIdSync(item.key)
                    ?.lyrics,
              );
        case MaterialKind.pdf:
          ref.watch(offlineIndexRevisionProvider);
        case MaterialKind.audio:
          ref.watch(offlineAudioIndexRevisionProvider);
        case MaterialKind.chord:
          ref.watch(chordGestureCacheRevisionProvider);
          ref.watch(
            chordSongProvider(item.key).select((value) => value.isLoading),
          );
        case MaterialKind.gesture:
          ref.watch(chordGestureCacheRevisionProvider);
          ref.watch(
            gestureDocumentProvider(item.key)
                .select((value) => value.isLoading),
          );
        default:
          throw ArgumentError.value(
            item.kind,
            'kind',
            'Not an offline reader material',
          );
      }
      return ref
          .watch(downloadColdigomMaterialsProvider)
          .isMaterialAvailable(item);
    });

bool _hasLyrics(String? lyrics) => lyrics?.trim().isNotEmpty ?? false;

final readerOfflineEditProvider =
    NotifierProvider<ReaderOfflineEdit, OfflineReaderMaterial?>(
      ReaderOfflineEdit.new,
    );

class ReaderOfflineEdit extends Notifier<OfflineReaderMaterial?> {
  @override
  OfflineReaderMaterial? build() => null;

  Future<void> setAvailable(OfflineReaderMaterial item, bool available) async {
    if (!ref.read(isarAvailableProvider)) {
      throw const StorageUnavailableException('offline.reader');
    }
    final lock = ref.read(offlineMaintenanceLockProvider.notifier);
    if (state != null || !lock.tryAcquire(OfflineMaintenanceOwner.reader)) {
      throw StateError('Offline storage is busy');
    }
    state = item;
    try {
      final exclusionKey = readerOfflineExclusion(item.kind, item.key);
      if (item.kind == MaterialKind.lyrics) {
        final exclusions = ref.read(readerOfflineExclusionsProvider.notifier);
        if (available) {
          final row = ref
              .read(coldigomCatalogLocalDatasourceProvider)
              .findByPraiseIdSync(item.key);
          if (!_hasLyrics(row?.lyrics)) {
            throw StateError(
              'Lyrics not stored in the local catalog: ${item.key}',
            );
          }
          await exclusions.include([exclusionKey]);
        } else {
          await exclusions.exclude(exclusionKey);
        }
        return;
      }

      final downloads = ref.read(downloadColdigomMaterialsProvider);
      final automaticallyCached =
          item.kind == MaterialKind.chord || item.kind == MaterialKind.gesture;
      if (available) {
        await downloads.downloadMaterial(item);
        if (automaticallyCached) {
          await ref.read(readerOfflineExclusionsProvider.notifier).include([
            exclusionKey,
          ]);
        }
      } else {
        if (automaticallyCached) {
          await ref
              .read(readerOfflineExclusionsProvider.notifier)
              .exclude(exclusionKey);
        }
        await downloads.removeMaterial(item);
      }
      if (item.kind == MaterialKind.chord) {
        ref.invalidate(chordSongProvider(item.key));
      } else if (item.kind == MaterialKind.gesture) {
        ref.invalidate(gestureDocumentProvider(item.key));
      }
    } finally {
      ref.invalidate(readerOfflineAvailableProvider(item));
      if (item.kind == MaterialKind.chord ||
          item.kind == MaterialKind.gesture) {
        ref.read(chordGestureCacheRevisionProvider.notifier).bump();
      }
      state = null;
      lock.release(OfflineMaintenanceOwner.reader);
    }
  }
}
