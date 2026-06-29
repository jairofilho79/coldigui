import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/routing/app_router.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/data/providers/app_shell_providers.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/deep_link_listener.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:coldigui/features/playlists/domain/usecases/load_playlist_into_carousel.dart';
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
  }) async =>
      _result;
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
    final isar = Isar.open(schemas: [CarouselEntrySchema, PlaylistSchema],
      directory: dir.path,
    );
    final carouselRepository =
        CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    final playlistRepository =
        PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    importUseCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      LoadPlaylistIntoCarousel(playlistRepository, carouselRepository),
    );
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
          builder: (_, __) => const Scaffold(body: Text('Home Screen')),
        ),
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, __) => const Scaffold(body: Text('Listas Screen')),
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

    final state =
        tester.state<DeepLinkListenerState>(find.byType(DeepLinkListener));
    await state.handleUriForTest(
      Uri.parse('/?sharepdfs=a&sharename=Teste'),
    );
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
          builder: (_, __) => const Scaffold(body: Text('Home Screen')),
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
              SyncDeepLinkResult.invalid,
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

    final state =
        tester.state<DeepLinkListenerState>(find.byType(DeepLinkListener));
    await state.handleUriForTest(
      Uri.parse('/?sharepdfs=x&sharename=Teste'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Link inválido'),
      findsOneWidget,
    );
  });
}
