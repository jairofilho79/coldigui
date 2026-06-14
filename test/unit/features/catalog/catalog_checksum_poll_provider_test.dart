import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_providers.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:coldigui/features/catalog/domain/repositories/manifest_checksum_reader.dart';
import 'package:coldigui/features/catalog/domain/usecases/poll_manifest_checksum.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_checksum_poll_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<List<Louvor>> loadManifest() async => [];

  @override
  Future<List<Louvor>> forceRefreshManifest() async => [];

  @override
  Future<void> cacheManifest(List<Louvor> louvores) async {}

  @override
  Future<String?> fetchManifestChecksum() async => 'same';

  @override
  Future<bool> isCatalogStale() async => false;
}

class _FakeChecksumStore implements ManifestChecksumReader {
  @override
  Future<String?> getLastKnownChecksum() async => 'same';

  @override
  Future<void> saveChecksum(String checksum) async {}
}

class _CountingPoll extends PollManifestChecksum {
  _CountingPoll() : super(_FakeCatalogRepository(), _FakeChecksumStore());

  int callCount = 0;

  @override
  Future<bool> call() async {
    callCount++;
    return false;
  }
}

void main() {
  late SharedPreferences prefs;
  late _CountingPoll poll;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    poll = _CountingPoll();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pollManifestChecksumProvider.overrideWith((ref) => poll),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('primeiro poll após cold start executa', () async {
    final container = createContainer();

    await container.read(catalogChecksumPollProvider.notifier).requestPoll();

    expect(poll.callCount, 1);
    expect(container.read(catalogChecksumPollProvider).lastPollAt, isNotNull);
    expect(prefs.getInt(StorageKeys.lastChecksumPollAt), isNotNull);
  });

  test('poll recente (< 30 min) é ignorado', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.lastChecksumPollAt: DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
    poll = _CountingPoll();

    final container = createContainer();

    await container.read(catalogChecksumPollProvider.notifier).requestPoll();

    expect(poll.callCount, 0);
    expect(container.read(catalogChecksumPollProvider).lastPollAt, isNull);
  });

  test('poll após 30 min executa novamente', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.lastChecksumPollAt: DateTime.now()
          .subtract(const Duration(minutes: 31))
          .millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
    poll = _CountingPoll();

    final container = createContainer();

    await container.read(catalogChecksumPollProvider.notifier).requestPoll();

    expect(poll.callCount, 1);
    expect(container.read(catalogChecksumPollProvider).lastPollAt, isNotNull);
  });
}
