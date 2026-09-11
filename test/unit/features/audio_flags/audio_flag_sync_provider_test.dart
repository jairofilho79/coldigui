import 'dart:async';

import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_flags/data/providers/audio_flag_providers.dart';
import 'package:coldigui/features/audio_flags/domain/entities/remote_audio_flag.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/domain/repositories/audio_flag_repository.dart';
import 'package:coldigui/features/audio_flags/domain/usecases/sync_audio_flags.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flag_sync_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _subKey = 'audio_flag_sync.last_synced_sub';

class _LoggedInAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'token');
}

/// Repositório mínimo: registra `adoptForSub`/`purgeSyncedOwnedBy` **na ordem**
/// em que foram chamados e pode falhar na adoção.
class _CountingRepository implements AudioFlagRepository {
  _CountingRepository({this.adoptThrows});

  final Object? adoptThrows;

  /// Diário ordenado (`'purge:<sub>'` / `'adopt:<sub>'`).
  ///
  /// A ordem é o contrato, não só a contagem: purgar **depois** de adotar
  /// apagaria as linhas que a conta nova acabou de adotar, e adotar antes de
  /// purgar faria as linhas `synced` da conta anterior virarem `pendingPush`
  /// do dono novo — subindo a biblioteca de A para a nuvem de B (spec A.5).
  final calls = <String>[];

  var adoptCalls = 0;
  final purgedSubs = <String>[];

  @override
  Future<void> adoptForSub(String sub) async {
    adoptCalls++;
    calls.add('adopt:$sub');
    final error = adoptThrows;
    if (error != null) throw error;
  }

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) async {
    purgedSubs.add(previousSub);
    calls.add('purge:$previousSub');
    return 0;
  }

  @override
  Future<String> create({
    required String audioId,
    required int positionMs,
    String label = '',
    String? flagId,
    DateTime? createdAt,
  }) async => flagId ?? 'gen';

  @override
  Future<void> delete(String flagId) async {}

  @override
  Future<List<SavedAudioFlag>> getByAudioId(String audioId) async => const [];

  @override
  Future<SavedAudioFlag?> getById(String flagId) async => null;

  @override
  Future<List<SavedAudioFlag>> getPendingPush({String? sub}) async => const [];

  @override
  Future<List<SavedAudioFlag>> getTombstones() async => const [];

  @override
  Future<void> hardDelete(String flagId) async {}

  @override
  Future<void> upsert(SavedAudioFlag flag) async {}
}

/// [SyncAudioFlags] roteirizado: falha nas primeiras [throwsUntilCall]
/// chamadas e depois devolve [result].
class _ScriptedSync extends SyncAudioFlags {
  _ScriptedSync({this.result, this.throws, this.throwsUntilCall})
    : super(
        _CountingRepository(),
        (_) async => const <RemoteAudioFlag>[],
        ({required idToken, required flag}) async => flag,
        ({required idToken, required flagId}) async {},
      );

  final AudioFlagSyncResult? result;
  final Object? throws;

  /// Número da última chamada que ainda falha (`1` = só a primeira).
  final int? throwsUntilCall;
  var calls = 0;
  final subs = <String?>[];

  @override
  Future<AudioFlagSyncResult> call({
    required String? idToken,
    required String? sub,
  }) async {
    calls++;
    subs.add(sub);
    final error = throws;
    final limit = throwsUntilCall;
    if (error != null && (limit == null || calls <= limit)) throw error;
    return result ?? const AudioFlagSyncResult();
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // `getInstance` é singleton: sem o reload, o cache do teste anterior
    // sobrevive a `setMockInitialValues`.
    await prefs.reload();
    AudioFlagSyncNotifier.reconnectDebounce = const Duration(milliseconds: 5);
  });

  tearDown(() {
    AudioFlagSyncNotifier.reconnectDebounce = const Duration(seconds: 2);
  });

  /// Deixa o sync pós-login disparado pelo `build()` terminar.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  ProviderContainer buildContainer({
    required AudioFlagRepository repository,
    required SyncAudioFlags sync,
    Stream<bool>? connectivity,
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_LoggedInAuth.new),
        audioFlagRepositoryProvider.overrideWithValue(repository),
        syncAudioFlagsProvider.overrideWithValue(sync),
        if (connectivity != null)
          connectivityStreamProvider.overrideWith((ref) => connectivity),
      ],
    );
  }

  test('primeiro login adota as flags e persiste o sub', () async {
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();

    expect(repo.adoptCalls, 1);
    expect(repo.purgedSubs, isEmpty, reason: 'não havia conta anterior');
    expect(prefs.getString(_subKey), 'sub-1');
  });

  test('reinício com o mesmo sub não repete adoptForSub', () async {
    final first = _CountingRepository();
    final container = buildContainer(repository: first, sync: _ScriptedSync());
    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();
    expect(first.adoptCalls, 1);
    container.dispose();

    final second = _CountingRepository();
    final secondSync = _ScriptedSync();
    final restarted = buildContainer(repository: second, sync: secondSync);
    addTearDown(restarted.dispose);
    await restarted.read(authStateProvider.future);
    restarted.read(audioFlagSyncProvider);
    await settle();

    expect(second.adoptCalls, 0, reason: 'sem transição de conta');
    expect(secondSync.calls, 1, reason: 'boot ainda faz sync simples');
  });

  test('troca de conta purga a anterior antes de adotar', () async {
    await prefs.setString(_subKey, 'outro-sub');
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();

    // A ordem é o contrato: adotar antes de purgar faria as linhas `synced` da
    // conta anterior virarem `pendingPush` do dono novo e subirem para a nuvem
    // dele. Só contar as chamadas deixaria a inversão passar.
    expect(repo.calls, ['purge:outro-sub', 'adopt:sub-1']);
    expect(prefs.getString(_subKey), 'sub-1');
  });

  test('primeiro login não purga nada antes de adotar', () async {
    final repo = _CountingRepository();
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();

    expect(repo.calls, ['adopt:sub-1'], reason: 'não havia conta anterior');
  });

  test('adoptForSub indisponível vira lastErrorCause e não persiste', () async {
    final repo = _CountingRepository(
      adoptThrows: StorageUnavailableException('sem storage'),
    );
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();

    expect(
      container.read(audioFlagSyncProvider).lastErrorCause,
      isA<StorageUnavailableException>(),
    );
    expect(prefs.getString(_subKey), isNull);
  });

  test('erro do resultado (pull) vira lastErrorCause e hasProblem', () async {
    final failure = StateError('pull caiu');
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: AudioFlagSyncResult(pullError: failure)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await container.read(audioFlagSyncProvider.notifier).sync();

    final state = container.read(audioFlagSyncProvider);
    expect(state.lastErrorCause, same(failure));
    expect(state.hasProblem, isTrue);
  });

  test('conflitos do resultado chegam ao estado', () async {
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: _ScriptedSync(result: const AudioFlagSyncResult(conflicts: 2)),
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    await container.read(audioFlagSyncProvider.notifier).sync();

    final state = container.read(audioFlagSyncProvider);
    expect(state.conflicts, 2);
    expect(state.hasProblem, isTrue);
  });

  test('sync bem-sucedida limpa o erro anterior', () async {
    final sync = _ScriptedSync(
      throws: StateError('rede caiu'),
      throwsUntilCall: 2,
    );
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: sync,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();

    final notifier = container.read(audioFlagSyncProvider.notifier);
    await notifier.sync();
    expect(container.read(audioFlagSyncProvider).lastErrorCause, isNotNull);

    await notifier.sync();
    expect(container.read(audioFlagSyncProvider).lastErrorCause, isNull);
  });

  test('a sync recebe o sub da conta logada', () async {
    final sync = _ScriptedSync();
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: sync,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    await container.read(audioFlagSyncProvider.notifier).sync();

    expect(sync.subs, everyElement('sub-1'));
    expect(sync.subs, isNotEmpty);
  });

  test('retryAndReload refaz a adoção quando o sub não foi persistido', () async {
    final repo = _CountingRepository(adoptThrows: StateError('storage fora'));
    final container = buildContainer(repository: repo, sync: _ScriptedSync());
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(audioFlagSyncProvider);
    await settle();
    expect(repo.adoptCalls, 1);
    expect(prefs.getString(_subKey), isNull);

    // Segunda tentativa: a adoção volta a ser chamada (sub ainda não persistido).
    await container.read(audioFlagSyncProvider.notifier).retryAndReload();

    expect(repo.adoptCalls, 2);
  });

  test(
    'retryAndReload só sincroniza quando o sub já está persistido',
    () async {
      await prefs.setString(_subKey, 'sub-1');
      final repo = _CountingRepository();
      final sync = _ScriptedSync();
      final container = buildContainer(repository: repo, sync: sync);
      addTearDown(container.dispose);

      await container.read(authStateProvider.future);
      container.read(audioFlagSyncProvider);
      await settle();
      final before = sync.calls;

      await container.read(audioFlagSyncProvider.notifier).retryAndReload();

      expect(repo.adoptCalls, 0);
      expect(sync.calls, before + 1);
    },
  );

  test('volta da conectividade dispara sync depois do debounce', () async {
    await prefs.setString(_subKey, 'sub-1');
    final sync = _ScriptedSync();
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    final container = buildContainer(
      repository: _CountingRepository(),
      sync: sync,
      connectivity: connectivity.stream,
    );
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    // `listen`, e não `read`: no Riverpod 3 um provider sem ouvinte ativo tem
    // as próprias assinaturas pausadas — o `ref.listen` da conectividade só
    // recebe eventos enquanto alguém observa o notifier (na tela, o player).
    container.listen(audioFlagSyncProvider, (_, _) {});
    await settle();
    final before = sync.calls;

    connectivity.add(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sync.calls, before, reason: 'ficar offline não sincroniza');

    connectivity.add(true);
    expect(sync.calls, before, reason: 'o debounce ainda não venceu');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(sync.calls, before + 1);
  });
}
