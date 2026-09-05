import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/routing/app_router.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/data/providers/app_shell_providers.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/deep_link_listener.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_plus/isar_plus.dart';

class _StubSyncDeepLinkState extends SyncDeepLinkState {
  _StubSyncDeepLinkState(this._result, ImportSharedPlaylistFromUrl import)
    : super(import);

  final SyncDeepLinkResult _result;

  @override
  Future<SyncDeepLinkResult> call({
    Uri? uri,
    Map<String, String>? queryParams,
  }) async => _result;
}

class _ThrowingSyncDeepLinkState extends SyncDeepLinkState {
  _ThrowingSyncDeepLinkState(this._error, ImportSharedPlaylistFromUrl import)
    : super(import);

  final Object _error;

  @override
  Future<SyncDeepLinkResult> call({
    Uri? uri,
    Map<String, String>? queryParams,
  }) async {
    throw _error;
  }
}

class _CountingSyncDeepLinkState extends SyncDeepLinkState {
  _CountingSyncDeepLinkState(super.import);

  var callCount = 0;

  @override
  Future<SyncDeepLinkResult> call({
    Uri? uri,
    Map<String, String>? queryParams,
  }) async {
    callCount++;
    return SyncDeepLinkResult.success('playlist-$callCount');
  }
}

/// Sempre lança, contando as chamadas — o dedupe tem que valer aqui também.
class _ThrowingCountingSyncDeepLinkState extends SyncDeepLinkState {
  _ThrowingCountingSyncDeepLinkState(super.import);

  var callCount = 0;

  @override
  Future<SyncDeepLinkResult> call({
    Uri? uri,
    Map<String, String>? queryParams,
  }) async {
    callCount++;
    throw const StorageUnavailableException('playlists.insert');
  }
}

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  var refreshCalled = false;

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<void> refreshAfterImport() async {
    refreshCalled = true;
  }
}

void main() {
  late ImportSharedPlaylistFromUrl importUseCase;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('deep_link_widget_');
    final isar = Isar.open(schemas: [PlaylistSchema], directory: dir.path);
    final playlistRepository = PlaylistRepositoryImpl(
      PlaylistLocalDatasource(isar),
    );
    importUseCase = ImportSharedPlaylistFromUrl(playlistRepository);
  });

  testWidgets('deep link success navega para home e exibe snackbar', (
    tester,
  ) async {
    final fakePlaylists = _FakePlaylistsNotifier();
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.playlists,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, _) => const Scaffold(body: Text('Listas Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          syncDeepLinkStateProvider.overrideWithValue(
            _StubSyncDeepLinkState(
              SyncDeepLinkResult.success('playlist-id'),
              importUseCase,
            ),
          ),
          playlistsProvider.overrideWith(() => fakePlaylists),
        ],
        child: DeepLinkListener(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Listas Screen'), findsOneWidget);

    final state = tester.state<DeepLinkListenerState>(
      find.byType(DeepLinkListener),
    );
    await state.handleUriForTest(Uri.parse('/?sharepdfs=a&sharename=Teste'));
    await tester.pumpAndSettle();

    expect(find.text('Home Screen'), findsOneWidget);
    expect(find.text('Lista importada'), findsOneWidget);
    expect(fakePlaylists.refreshCalled, isTrue);
  });

  testWidgets('deep link inválido exibe snackbar de erro', (tester) async {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          syncDeepLinkStateProvider.overrideWithValue(
            _StubSyncDeepLinkState(SyncDeepLinkResult.invalid, importUseCase),
          ),
          playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        ],
        child: DeepLinkListener(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<DeepLinkListenerState>(
      find.byType(DeepLinkListener),
    );
    await state.handleUriForTest(Uri.parse('/?sharepdfs=x&sharename=Teste'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Link inválido'), findsOneWidget);
  });

  testWidgets('deep link só com sharename avisa em vez de sumir (D.6)', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          // Sem stub: a URL passa pelo parser e pelo use case de verdade — é
          // exatamente ali que o caso era engolido.
          syncDeepLinkStateProvider.overrideWithValue(
            SyncDeepLinkState(importUseCase),
          ),
          playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        ],
        child: DeepLinkListener(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<DeepLinkListenerState>(
      find.byType(DeepLinkListener),
    );
    await state.handleUriForTest(Uri.parse('/?sharename=Ensaio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Link inválido'), findsOneWidget);
  });

  testWidgets(
    'sincronização lançando PlaylistNotFoundException exibe snackbar sem propagar exceção',
    (tester) async {
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: Text('Home Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(router),
            deepLinkHandlingEnabledProvider.overrideWithValue(true),
            syncDeepLinkStateProvider.overrideWithValue(
              _ThrowingSyncDeepLinkState(
                const PlaylistNotFoundException(),
                importUseCase,
              ),
            ),
            playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
          ],
          child: DeepLinkListener(
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('pt'),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<DeepLinkListenerState>(
        find.byType(DeepLinkListener),
      );
      await state.handleUriForTest(Uri.parse('/?sharepdfs=a&sharename=Teste'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Não foi possível importar a lista compartilhada.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'sincronização lançando StorageUnavailableException exibe snackbar de armazenamento indisponível',
    (tester) async {
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: Text('Home Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWithValue(router),
            deepLinkHandlingEnabledProvider.overrideWithValue(true),
            syncDeepLinkStateProvider.overrideWithValue(
              _ThrowingSyncDeepLinkState(
                const StorageUnavailableException('playlists.insert'),
                importUseCase,
              ),
            ),
            playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
          ],
          child: DeepLinkListener(
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('pt'),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<DeepLinkListenerState>(
        find.byType(DeepLinkListener),
      );
      await state.handleUriForTest(Uri.parse('/?sharepdfs=a&sharename=Teste'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Armazenamento local indisponível. Recarregue a página ou libere espaço.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('mesma query dentro de 3s é ignorada; após 3s é reprocessada', (
    tester,
  ) async {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );
    var currentTime = DateTime(2026, 1, 1);
    final countingUseCase = _CountingSyncDeepLinkState(importUseCase);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          syncDeepLinkStateProvider.overrideWithValue(countingUseCase),
          playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        ],
        child: DeepLinkListener(
          now: () => currentTime,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<DeepLinkListenerState>(
      find.byType(DeepLinkListener),
    );
    final uri = Uri.parse('/?sharepdfs=a&sharename=Teste');

    await state.handleUriForTest(uri);
    await tester.pumpAndSettle();
    expect(countingUseCase.callCount, 1);

    currentTime = currentTime.add(const Duration(seconds: 1));
    await state.handleUriForTest(uri);
    await tester.pumpAndSettle();
    expect(countingUseCase.callCount, 1);

    currentTime = currentTime.add(const Duration(seconds: 3));
    await state.handleUriForTest(uri);
    await tester.pumpAndSettle();
    expect(countingUseCase.callCount, 2);
  });

  // B4: exceção também marca o link como processado. Sem isso, o mesmo link
  // que estourou reentrava a cada evento do stream, repetindo a snackbar de
  // erro sem nenhuma chance de dar certo.
  testWidgets('link que lançou também entra no dedupe de 3s', (tester) async {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );
    var currentTime = DateTime(2026, 1, 1);
    final throwingUseCase = _ThrowingCountingSyncDeepLinkState(importUseCase);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          syncDeepLinkStateProvider.overrideWithValue(throwingUseCase),
          playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        ],
        child: DeepLinkListener(
          now: () => currentTime,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<DeepLinkListenerState>(
      find.byType(DeepLinkListener),
    );
    final uri = Uri.parse('/?sharepdfs=a&sharename=Teste');

    await state.handleUriForTest(uri);
    await tester.pumpAndSettle();
    expect(throwingUseCase.callCount, 1);
    expect(tester.takeException(), isNull);

    currentTime = currentTime.add(const Duration(seconds: 1));
    await state.handleUriForTest(uri);
    await tester.pumpAndSettle();
    expect(throwingUseCase.callCount, 1, reason: 'dentro da janela de dedupe');

    currentTime = currentTime.add(const Duration(seconds: 3));
    await state.handleUriForTest(uri);
    await tester.pumpAndSettle();
    expect(throwingUseCase.callCount, 2, reason: 'passada a janela, retenta');
  });
}
