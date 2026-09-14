import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/material_kind_prefs/data/datasources/material_kind_prefs_local_datasource.dart';
import 'package:coldigui/features/material_kind_prefs/data/providers/material_kind_prefs_providers.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', sessionToken: 'tok');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Sync que só conta chamadas — o provider de prefs pede sync após salvar.
class _CountingSync extends MaterialKindPrefsSyncNotifier {
  int calls = 0;

  @override
  MaterialKindPrefsSyncState build() => const MaterialKindPrefsSyncState();

  @override
  Future<MaterialKindPrefsSyncResult> sync() async {
    calls++;
    return MaterialKindPrefsSyncResult.skippedAuth;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> make({
    required AuthNotifier Function() auth,
    Map<String, Object> initial = const {},
    _CountingSync? sync,
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(auth),
        if (sync != null)
          materialKindPrefsSyncProvider.overrideWith(() => sync),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('deslogado → empty e rank vazio, sem ler SharedPreferences', () async {
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith(_LoggedOut.new)],
    );
    addTearDown(container.dispose);
    final prefs = await container.read(materialKindPrefsProvider.future);
    expect(prefs.kindIds, isEmpty);
    expect(container.read(favoriteMaterialKindRankProvider), isEmpty);
  });

  test('logado lê a chave do sub', () async {
    final container = await make(
      auth: _LoggedIn.new,
      initial: {
        MaterialKindPrefsLocalDatasource.keyFor('sub-1'): '{"kindIds":["a","b"],"updatedAt":"2026-09-01T00:00:00.000Z","pendingPush":false}',
        MaterialKindPrefsLocalDatasource.keyFor('sub-2'): '{"kindIds":["z"],"updatedAt":"2026-09-01T00:00:00.000Z","pendingPush":false}',
      },
    );
    final prefs = await container.read(materialKindPrefsProvider.future);
    expect(prefs.kindIds, ['a', 'b']);
    container.listen(favoriteMaterialKindRankProvider, (_, _) {});
    await container.pump();
    expect(container.read(favoriteMaterialKindRankProvider), {'a': 0, 'b': 1});
  });

  test('save grava pendingPush, atualiza o estado e dispara sync', () async {
    final sync = _CountingSync();
    final container = await make(auth: _LoggedIn.new, sync: sync);
    await container.read(materialKindPrefsProvider.future);
    final before = DateTime.now().toUtc();

    await container.read(materialKindPrefsProvider.notifier).save(['x', 'y']);

    final state = container.read(materialKindPrefsProvider).requireValue;
    expect(state.kindIds, ['x', 'y']);
    expect(state.pendingPush, isTrue);
    expect(state.updatedAt.isBefore(before), isFalse);
    final stored = container
        .read(materialKindPrefsLocalDatasourceProvider)
        .read('sub-1');
    expect(stored!.kindIds, ['x', 'y']);
    expect(sync.calls, 1);
  });

  test('save rejeita mais de 5 e duplicata sem tocar o estado', () async {
    final container = await make(auth: _LoggedIn.new, sync: _CountingSync());
    await container.read(materialKindPrefsProvider.future);
    await expectLater(
      container.read(materialKindPrefsProvider.notifier).save([
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
      ]),
      throwsArgumentError,
    );
    expect(
      container.read(materialKindPrefsProvider).requireValue.kindIds,
      isEmpty,
    );
  });

  test('save deslogado é ignorado', () async {
    final sync = _CountingSync();
    final container = await make(auth: _LoggedOut.new, sync: sync);
    await container.read(materialKindPrefsProvider.future);
    await container.read(materialKindPrefsProvider.notifier).save(['x']);
    expect(
      container.read(materialKindPrefsProvider).requireValue.kindIds,
      isEmpty,
    );
    expect(sync.calls, 0);
  });

  test('save preserva o preferredTypeByKind já gravado', () async {
    final container = await make(auth: _LoggedIn.new, sync: _CountingSync());
    await container.read(materialKindPrefsProvider.future);
    await container
        .read(materialKindPrefsProvider.notifier)
        .setPreferredType('x', 'chord');

    await container.read(materialKindPrefsProvider.notifier).save(['x', 'y']);

    expect(
      container
          .read(materialKindPrefsProvider)
          .requireValue
          .preferredTypeByKind,
      {'x': 'chord'},
    );
  });

  test('setPreferredType grava o material type preferido, atualiza o estado e dispara sync', () async {
    final sync = _CountingSync();
    final container = await make(auth: _LoggedIn.new, sync: sync);
    await container.read(materialKindPrefsProvider.future);
    await container.read(materialKindPrefsProvider.notifier).save(['x']);

    await container
        .read(materialKindPrefsProvider.notifier)
        .setPreferredType('x', 'chord');

    final state = container.read(materialKindPrefsProvider).requireValue;
    expect(state.preferredTypeByKind, {'x': 'chord'});
    expect(state.kindIds, ['x']);
    final stored = container
        .read(materialKindPrefsLocalDatasourceProvider)
        .read('sub-1');
    expect(stored!.preferredTypeByKind, {'x': 'chord'});
    expect(sync.calls, 2); // save() + setPreferredType()
  });

  test('setPreferredType deslogado é ignorado', () async {
    final sync = _CountingSync();
    final container = await make(auth: _LoggedOut.new, sync: sync);
    await container.read(materialKindPrefsProvider.future);
    await container
        .read(materialKindPrefsProvider.notifier)
        .setPreferredType('x', 'chord');
    expect(
      container
          .read(materialKindPrefsProvider)
          .requireValue
          .preferredTypeByKind,
      isEmpty,
    );
    expect(sync.calls, 0);
  });
}
