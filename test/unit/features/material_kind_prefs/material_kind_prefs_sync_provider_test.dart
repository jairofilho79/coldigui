import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/material_kind_prefs/data/providers/material_kind_prefs_providers.dart';
import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/domain/usecases/sync_material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'tok');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, List<String>)> make({
    required AuthNotifier Function() auth,
    MaterialKindPrefs? remote,
    StreamController<bool>? connectivity,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(auth),
        if (connectivity != null)
          connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
        syncMaterialKindPrefsProvider.overrideWith((ref) {
          return SyncMaterialKindPrefs(
            ref.watch(materialKindPrefsRepositoryProvider),
            (_) async {
              calls.add('fetch');
              return remote;
            },
            ({required idToken, required prefs}) async {
              calls.add('put');
              return prefs.copyWith(pendingPush: false);
            },
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    return (container, calls);
  }

  test(
    'login dispara uma sync e o pull recarrega materialKindPrefsProvider',
    () async {
      final remote = MaterialKindPrefs.validated(
        kindIds: const ['remoto'],
        updatedAt: DateTime.utc(2026, 9, 10),
      );
      final (container, calls) = await make(
        auth: _LoggedIn.new,
        remote: remote,
      );
      container.listen(materialKindPrefsSyncProvider, (_, _) {});
      await container.read(authStateProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(calls, ['fetch']);
      final prefs = await container.read(materialKindPrefsProvider.future);
      expect(prefs.kindIds, ['remoto']);
    },
  );

  test('deslogado não toca a rede', () async {
    final (container, calls) = await make(auth: _LoggedOut.new);
    container.listen(materialKindPrefsSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    expect(
      (await container.read(materialKindPrefsSyncProvider.notifier).sync())
          .outcome,
      MaterialKindPrefsSyncOutcome.skipped,
    );
  });

  test('voltar a ficar online dispara sync com debounce', () async {
    MaterialKindPrefsSyncNotifier.reconnectDebounce = const Duration(
      milliseconds: 10,
    );
    addTearDown(
      () => MaterialKindPrefsSyncNotifier.reconnectDebounce = const Duration(
        seconds: 2,
      ),
    );
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    final (container, calls) = await make(
      auth: _LoggedIn.new,
      connectivity: connectivity,
    );
    container.listen(materialKindPrefsSyncProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    calls.clear();

    connectivity.add(false);
    await Future<void>.delayed(Duration.zero);
    connectivity.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(calls, ['fetch']);
  });
}
