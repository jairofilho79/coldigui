import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/leaflet/presentation/utils/leaflet_capture.dart';
import 'package:coldigui/features/leaflet/presentation/providers/leaflet_actions_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  _FakePlaylistsNotifier({this.resolvedPlaylist});

  final ResolvedActivePlaylist? resolvedPlaylist;

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<ResolvedActivePlaylist?> resolveActivePlaylistFromCarousel() async =>
      resolvedPlaylist;
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
    GetTemporaryDirectoryFn? getTemporaryDirectory,
    Future<bool> Function(BuildContext context)? showWhatsAppStepDialog,
  }) async {
    lastOption = option;
    return true;
  }
}

class _FakeReaderCarouselActions extends ReaderCarouselActionsNotifier {
  String? lastPdfId;
  final navigatedPdfIds = <String>[];

  @override
  void build() {}

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    lastPdfId = targetPdfId;
    navigatedPdfIds.add(targetPdfId);
    return '${RoutePaths.reader}?pdfId=$targetPdfId&file=asset:fixtures/sample.pdf';
  }
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;
  var cleared = false;
  List<String>? lastReorder;
  final removed = <String>[];

  @override
  List<CarouselItem> build() => initial;

  @override
  Future<void> remove(String pdfId) async {
    removed.add(pdfId);
    state = state.where((item) => item.pdfId != pdfId).toList(growable: false);
  }

  @override
  Future<void> clear() async {
    cleared = true;
    state = const [];
  }

  @override
  Future<void> reorder(List<String> pdfIds) async {
    lastReorder = pdfIds;
    final byId = {for (final item in state) item.pdfId: item};
    state = pdfIds.map((pdfId) => byId[pdfId]!).toList(growable: false);
  }
}

CarouselItem _item({
  required String pdfId,
  required int sortOrder,
  required String numero,
  required String nome,
}) {
  return CarouselItem(
    pdfId: pdfId,
    sortOrder: sortOrder,
    numero: numero,
    nome: nome,
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
  );
}

void main() {
  final items = [
    _item(pdfId: 'a', sortOrder: 0, numero: '001', nome: 'Louvor A'),
    _item(pdfId: 'b', sortOrder: 1, numero: '002', nome: 'Louvor B'),
    _item(pdfId: 'c', sortOrder: 2, numero: '003', nome: 'Louvor C'),
  ];

  Widget buildSubject(
    List<CarouselItem> carouselItems, {
    CarouselLouvoresNotifier? notifier,
  }) {
    final carouselNotifier = notifier ?? _FakeCarouselNotifier(carouselItems);
    return ProviderScope(
      overrides: [
        carouselLouvoresProvider.overrideWith(() => carouselNotifier),
        playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: CarouselChips()),
      ),
    );
  }

  testWidgets('oculta barra quando seleção vazia', (tester) async {
    await tester.pumpWidget(buildSubject(const []));
    await tester.pumpAndSettle();

    expect(find.byType(CarouselLouvorChip), findsNothing);
    expect(find.byIcon(Icons.clear_all), findsNothing);
  });

  testWidgets('renderiza apenas um chip visível', (tester) async {
    await tester.pumpWidget(buildSubject(items));
    await tester.pumpAndSettle();

    expect(find.textContaining('Louvor A'), findsOneWidget);
    expect(find.textContaining('Louvor B'), findsNothing);
    expect(find.textContaining('Louvor C'), findsNothing);
  });

  testWidgets('setas navegam índice focado e somem nas extremidades',
      (tester) async {
    await tester.pumpWidget(buildSubject(items));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.textContaining('Louvor B'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.textContaining('Louvor C'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('chip da barra não possui botão de remover', (tester) async {
    await tester.pumpWidget(buildSubject(items));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('modal permite remover item', (tester) async {
    final notifier = _FakeCarouselNotifier(items);
    await tester.pumpWidget(buildSubject(items, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(find.text('Seleção temporária'), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Louvor A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Louvor B')),
      findsOneWidget,
    );

    await tester.tap(find
        .descendant(
          of: dialog,
          matching: find.byIcon(Icons.close),
        )
        .first);
    await tester.pumpAndSettle();

    expect(notifier.removed, ['a']);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Louvor A')),
      findsNothing,
    );
  });

  testWidgets('exibe botão salvar quando há chips', (tester) async {
    await tester.pumpWidget(buildSubject(items));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
  });

  testWidgets('exibe botão compartilhar quando há chips', (tester) async {
    await tester.pumpWidget(buildSubject(items));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
  });

  testWidgets('em smartphone usa menu overflow em vez de ícones individuais',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(items));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.clear_all), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.view_list), findsOneWidget);
  });

  testWidgets('menu overflow em smartphone abre sheet de compartilhar',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playlistsNotifier = _FakePlaylistsNotifier(
      resolvedPlaylist: const ResolvedActivePlaylist(
        playlistId: 'p1',
        nome: 'Ensaio',
      ),
    );
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    final carouselNotifier = _FakeCarouselNotifier(items);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider.overrideWith(() => carouselNotifier),
          playlistsProvider.overrideWith(() => playlistsNotifier),
          playlistShareActionsProvider.overrideWith(() => shareNotifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: CarouselChips()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartilhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só o link'));
    await tester.pumpAndSettle();

    expect(shareNotifier.lastOption, PlaylistShareOption.link);
  });

  testWidgets(
      'compartilhar lista com carousel preenchido sem playlist ativa em memória',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playlistsNotifier = _FakePlaylistsNotifier(
      resolvedPlaylist: const ResolvedActivePlaylist(
        playlistId: 'p1',
        nome: 'Ensaio',
      ),
    );
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    final carouselNotifier = _FakeCarouselNotifier(items);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider.overrideWith(() => carouselNotifier),
          playlistsProvider.overrideWith(() => playlistsNotifier),
          playlistShareActionsProvider.overrideWith(() => shareNotifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: CarouselChips()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartilhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só o link'));
    await tester.pumpAndSettle();

    expect(find.text('Esta lista não tem louvores.'), findsNothing);
  });

  testWidgets('tap compartilhar dispara opção folheto no sheet',
      (tester) async {
    final playlistsNotifier = _FakePlaylistsNotifier(
      resolvedPlaylist: const ResolvedActivePlaylist(
        playlistId: 'p1',
        nome: 'Ensaio',
      ),
    );
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    final carouselNotifier = _FakeCarouselNotifier(items);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider.overrideWith(() => carouselNotifier),
          playlistsProvider.overrideWith(() => playlistsNotifier),
          playlistShareActionsProvider.overrideWith(() => shareNotifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: CarouselChips()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só o folheto'));
    await tester.pumpAndSettle();

    expect(shareNotifier.lastOption, PlaylistShareOption.leaflet);
  });

  testWidgets('limpar seleção após confirmação', (tester) async {
    final notifier = _FakeCarouselNotifier(items);
    await tester.pumpWidget(buildSubject(items, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.clear_all));
    await tester.pumpAndSettle();

    expect(find.text('Limpar seleção?'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(notifier.cleared, isTrue);
    expect(find.byType(CarouselLouvorChip), findsNothing);
  });

  testWidgets('toque no chip abre leitor com pdf focado', (tester) async {
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, state) => Scaffold(
            body: Text(state.uri.queryParameters['pdfId'] ?? ''),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider
              .overrideWith(() => _FakeCarouselNotifier(items)),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
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

    await tester.tap(find.textContaining('Louvor A'));
    await tester.pumpAndSettle();

    expect(readerActions.lastPdfId, 'a');
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('toque no chip do modal abre leitor', (tester) async {
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, state) => Scaffold(
            body: Text(state.uri.queryParameters['pdfId'] ?? ''),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider
              .overrideWith(() => _FakeCarouselNotifier(items)),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
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

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Louvor B'));
    await tester.pumpAndSettle();

    expect(readerActions.lastPdfId, 'b');
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('segundo toque no chip do modal no leitor troca o PDF',
      (tester) async {
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider
              .overrideWith(() => _FakeCarouselNotifier(items)),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
          readerCarouselPositionProvider('b').overrideWith(
            (ref) => const CarouselReaderPosition(
              currentIndex: 2,
              total: 3,
              previousPdfId: 'a',
              nextPdfId: 'c',
            ),
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

    router.go(
      '${RoutePaths.reader}?pdfId=b&file=asset:fixtures/sample.pdf&titulo=Louvor%20B',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor C'));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedPdfIds, ['c']);
    expect(router.state.uri.queryParameters['pdfId'], 'c');

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor A'));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedPdfIds, ['c', 'a']);
    expect(router.state.uri.queryParameters['pdfId'], 'a');
  });

  testWidgets('segundo toque no chip do modal no shell abre outro PDF',
      (tester) async {
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, state) => Scaffold(
            body: Text(state.uri.queryParameters['pdfId'] ?? ''),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider
              .overrideWith(() => _FakeCarouselNotifier(items)),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
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

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor B'));
    await tester.pumpAndSettle();

    expect(find.text('b'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor C'));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedPdfIds, ['b', 'c']);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('item único não exibe setas', (tester) async {
    await tester.pumpWidget(buildSubject([items.first]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.textContaining('Louvor A'), findsOneWidget);
  });

  testWidgets('modo leitor exibe setas com posição no carousel',
      (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, __) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider
              .overrideWith(() => _FakeCarouselNotifier(items)),
          readerCarouselPositionProvider('b').overrideWith(
            (ref) => const CarouselReaderPosition(
              currentIndex: 2,
              total: 3,
              previousPdfId: 'a',
              nextPdfId: 'c',
            ),
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

    router.go(
      '${RoutePaths.reader}?pdfId=b&file=asset:fixtures/sample.pdf&titulo=Louvor%20B',
    );
    await tester.pumpAndSettle();

    expect(find.byType(CarouselLouvorChip), findsOneWidget);
    expect(find.textContaining('#002'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.view_list), findsOneWidget);
  });
}
