import 'dart:io';

import '../../../support/fakes/fake_playlists_notifier.dart';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/routing/app_router.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/data/providers/app_shell_providers.dart';
import 'package:coldigui/features/app_shell/domain/usecases/sync_deep_link_state.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/deep_link_listener.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/usecases/import_shared_playlist_from_url.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_plus/isar_plus.dart';

/// Conta chamadas — a sala ao vivo não deve disparar nenhum import (D6).
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

void main() {
  late ImportSharedPlaylistFromUrl importUseCase;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('deep_link_live_widget_');
    final isar = Isar.open(schemas: [PlaylistSchema], directory: dir.path);
    final playlistRepository = PlaylistRepositoryImpl(
      PlaylistLocalDatasource(isar),
    );
    importUseCase = ImportSharedPlaylistFromUrl(
      playlistRepository,
      loadPraiseEntryResolver: () async =>
          (_) => null,
    );
  });

  GoRouter buildRouter() => GoRouter(
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
      GoRoute(
        path: RoutePaths.liveRoom,
        builder: (_, state) =>
            Scaffold(body: Text('Sala ${state.pathParameters['code']}')),
      ),
    ],
  );

  Future<DeepLinkListenerState> pumpListener(
    WidgetTester tester, {
    required GoRouter router,
    required SyncDeepLinkState syncState,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          deepLinkHandlingEnabledProvider.overrideWithValue(true),
          syncDeepLinkStateProvider.overrideWithValue(syncState),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
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
    return tester.state<DeepLinkListenerState>(find.byType(DeepLinkListener));
  }

  testWidgets('?live=<code> navega para /ao-vivo/<code> sem importar', (
    tester,
  ) async {
    final router = buildRouter();
    final counting = _CountingSyncDeepLinkState(importUseCase);
    final state = await pumpListener(
      tester,
      router: router,
      syncState: counting,
    );

    await state.handleUriForTest(Uri.parse('https://plpcg.com/?live=k7x2m9q'));
    await tester.pumpAndSettle();

    expect(find.text('Sala k7x2m9q'), findsOneWidget);
    expect(counting.callCount, 0);
  });

  testWidgets('/ao-vivo/<code> navega para /ao-vivo/<code> sem importar', (
    tester,
  ) async {
    final router = buildRouter();
    final counting = _CountingSyncDeepLinkState(importUseCase);
    final state = await pumpListener(
      tester,
      router: router,
      syncState: counting,
    );

    await state.handleUriForTest(
      Uri.parse('https://plpcg.com/ao-vivo/k7x2m9q'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sala k7x2m9q'), findsOneWidget);
    expect(counting.callCount, 0);
  });

  testWidgets(
    'URL de share (?p=&n=) continua no fluxo de import, não navega para /ao-vivo',
    (tester) async {
      final router = buildRouter();
      final counting = _CountingSyncDeepLinkState(importUseCase);
      final state = await pumpListener(
        tester,
        router: router,
        syncState: counting,
      );

      await state.handleUriForTest(
        Uri.parse('https://v2.plpcg.com/?p=0a1&n=x'),
      );
      await tester.pumpAndSettle();

      expect(counting.callCount, 1);
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.textContaining('Sala '), findsNothing);
    },
  );
}
