import 'dart:convert';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_list_tile.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  _FakePlaylistsNotifier(this.initial);

  final List<PlaylistViewItem> initial;
  String? lastLoadedPlaylistId;

  @override
  List<PlaylistViewItem> build() => initial;

  @override
  Future<bool> loadIntoCarousel(String playlistId) async {
    lastLoadedPlaylistId = playlistId;
    return true;
  }
}

class _FakePlaylistShareActionsNotifier extends PlaylistShareActionsNotifier {
  PlaylistShareOption? lastOption;

  @override
  void build() {}

  @override
  Future<bool> share(
    BuildContext context,
    shareContext,
    PlaylistShareOption option, {
    required Rect? sharePositionOrigin,
    ShareFn? share,
    ShareXFilesFn? shareXFiles,
    CaptureWidgetToPngFn? capture,
    Future<bool> Function(BuildContext context)? showWhatsAppStepDialog,
  }) async {
    lastOption = option;
    return true;
  }
}

class _FakeResolvePdfForReader implements ResolvePdfForReader {
  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    return LocalPdfSource(
      pdfId: pdfId,
      absolutePath: '/tmp/$pdfId.pdf',
      fromCache: true,
    );
  }
}

class _LouvorFindingPlaylistsNotifier extends _FakePlaylistsNotifier {
  _LouvorFindingPlaylistsNotifier(super.initial);

  @override
  Louvor? findLouvorByPdfId(String pdfId) {
    return Louvor.fromManifest(
      nome: 'Louvor $pdfId',
      numero: '002',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$pdfId.pdf',
      pdfId: pdfId,
    );
  }
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;

  @override
  List<CarouselItem> build() => initial;
}

String _pdfId(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

void main() {
  final pdfIdA = _pdfId('ColAdultos/001.pdf');
  final pdfIdB = _pdfId('ColAdultos/002.pdf');

  final item = PlaylistViewItem(
    playlist: SavedPlaylist(
      playlistId: 'p1',
      nome: 'Ensaio domingo',
      pdfIds: [pdfIdA, pdfIdB],
      createdAt: DateTime(2026, 6, 8),
    ),
    pdfLabels: ['001 — A', '002 — B'],
  );

  Widget buildSubject({
    required PlaylistsNotifier playlistsNotifier,
    PlaylistShareActionsNotifier? shareActionsNotifier,
    List<CarouselItem> carouselItems = const [],
  }) {
    final shareNotifier =
        shareActionsNotifier ?? _FakePlaylistShareActionsNotifier();
    return ProviderScope(
      overrides: [
        playlistsProvider.overrideWith(() => playlistsNotifier),
        playlistShareActionsProvider.overrideWith(() => shareNotifier),
        carouselLouvoresProvider.overrideWith(
          () => _FakeCarouselNotifier(carouselItems),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: PlaylistListTile(item: item, tab: PlaylistTab.saved),
        ),
      ),
    );
  }

  testWidgets('menu exibe Carregar no carousel e Abrir no leitor', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(playlistsNotifier: _FakePlaylistsNotifier([item])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Carregar no carousel'), findsOneWidget);
    expect(find.text('Abrir no leitor'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
  });

  testWidgets('Carregar no carousel dispara loadIntoCarousel', (tester) async {
    final notifier = _FakePlaylistsNotifier([item]);
    await tester.pumpWidget(buildSubject(playlistsNotifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar no carousel'));
    await tester.pumpAndSettle();

    expect(notifier.lastLoadedPlaylistId, 'p1');
    expect(find.text('Lista carregada no carousel'), findsOneWidget);
  });

  testWidgets('confirma substituição quando carousel não vazio', (
    tester,
  ) async {
    final notifier = _FakePlaylistsNotifier([item]);
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: notifier,
        carouselItems: const [
          CarouselItem(
            pdfId: 'x',
            sortOrder: 0,
            numero: '001',
            nome: 'X',
            categoria: 'Partitura',
            classificacao: 'ColAdultos',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar no carousel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Substituir seleção?'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(notifier.lastLoadedPlaylistId, 'p1');
  });

  testWidgets('toque no chip abre leitor com pdf selecionado', (tester) async {
    final notifier = _LouvorFindingPlaylistsNotifier([item]);
    final router = GoRouter(
      initialLocation: RoutePaths.playlists,
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, _) => Scaffold(
            body: PlaylistListTile(item: item, tab: PlaylistTab.saved),
          ),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, state) =>
              Scaffold(body: Text(state.uri.queryParameters['pdfId'] ?? '')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistsProvider.overrideWith(() => notifier),
          carouselLouvoresProvider.overrideWith(
            () => _FakeCarouselNotifier([]),
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _FakeResolvePdfForReader(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ensaio domingo'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('002'));
    await tester.pumpAndSettle();

    expect(notifier.lastLoadedPlaylistId, 'p1');
    expect(find.text(pdfIdB), findsOneWidget);
  });

  testWidgets('Compartilhar abre sheet e dispara share', (tester) async {
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: _FakePlaylistsNotifier([item]),
        shareActionsNotifier: shareNotifier,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartilhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só o link'));
    await tester.pumpAndSettle();

    expect(shareNotifier.lastOption, PlaylistShareOption.link);
  });

  testWidgets('menu exibe Publicar em lista privada', (tester) async {
    await tester.pumpWidget(
      buildSubject(playlistsNotifier: _FakePlaylistsNotifier([item])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Publicar'), findsOneWidget);
  });

  testWidgets('lista publicada mostra badge e esconde Publicar', (
    tester,
  ) async {
    final published = PlaylistViewItem(
      playlist: SavedPlaylist(
        playlistId: 'p1',
        nome: 'Ensaio domingo',
        pdfIds: [pdfIdA, pdfIdB],
        createdAt: DateTime(2026, 6, 8),
        isPublished: true,
        publicationReach: PlaylistReach.usual,
        publicationCategory: PlaylistCategory.evangelizacao,
        publishedAt: DateTime(2026, 6, 9),
      ),
      pdfLabels: ['001 — A', '002 — B'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistsProvider.overrideWith(
            () => _FakePlaylistsNotifier([published]),
          ),
          playlistShareActionsProvider.overrideWith(
            _FakePlaylistShareActionsNotifier.new,
          ),
          carouselLouvoresProvider.overrideWith(
            () => _FakeCarouselNotifier([]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: PlaylistListTile(item: published, tab: PlaylistTab.saved),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pública'), findsOneWidget);
    expect(find.text('Evangelização'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Publicar'), findsNothing);
  });
}
