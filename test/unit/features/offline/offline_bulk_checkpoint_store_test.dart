import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_checkpoint_store.dart';
import 'package:coldigui/features/offline/domain/entities/offline_bulk_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('round-trip checkpoint JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineBulkCheckpointStore(prefs);

    final checkpoint = OfflineBulkCheckpoint(
      categories: const ['Partitura', 'Cifra'],
      categoryIndex: 1,
      partIndex: 2,
      extractedPdfCount: 5,
      startedAt: DateTime.utc(2026, 6, 8, 12),
    );

    await store.save(checkpoint);
    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.categories, checkpoint.categories);
    expect(loaded.categoryIndex, 1);
    expect(loaded.partIndex, 2);
    expect(loaded.extractedPdfCount, 5);
    expect(loaded.startedAt, checkpoint.startedAt);
    expect(
      prefs.getString(StorageKeys.offlineBulkCheckpoint),
      isNotNull,
    );
  });

  test('clear remove checkpoint', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineBulkCheckpointStore(prefs);

    await store.save(
      OfflineBulkCheckpoint(
        categories: const ['Partitura'],
        categoryIndex: 0,
        partIndex: 0,
        extractedPdfCount: 0,
        startedAt: DateTime.now(),
      ),
    );

    await store.clear();
    expect(await store.load(), isNull);
  });
}
