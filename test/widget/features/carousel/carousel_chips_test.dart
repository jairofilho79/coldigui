import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_position_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }) async {
    lastOption = option;
    return true;
  }
}

class _FakeReaderCarouselActions extends ReaderCarouselActionsNotifier {
  String? lastPdfId;
  final navigatedPdfIds = <String>[];

  /// Chaves por ocorrência recebidas — é por elas que as setas do leitor
  /// navegam, e só elas distinguem duas entradas do mesmo louvor.
  final navigatedKeys = <String>[];

  @override
  void build() {}

  /// Registra a chave e deixa a implementação real focar/resolver o item.
  @override
  Future<String?> navigateToKey({required String key}) {
    navigatedKeys.add(key);
    return super.navigateToKey(key: key);
  }

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    lastPdfId = targetPdfId;
    navigatedPdfIds.add(targetPdfId);
    return '${RoutePaths.reader}?pdfId=$targetPdfId&file=asset:fixtures/sample.pdf';
  }
}

class _FakeColdigomLouvoresCache extends ColdigomLouvoresCacheNotifier {
  _FakeColdigomLouvoresCache(this.initial);

  final Map<String, Louvor> initial;

  @override
  Map<String, Louvor> build() => initial;
}

class _FakeColdigomChordMaterialsCache
    extends ColdigomChordMaterialsCacheNotifier {
  _FakeColdigomChordMaterialsCache(this.initial);

  final Map<String, ChordMaterial> initial;

  @override
  Map<String, ChordMaterial> build() => initial;
}

/// Sessão de áudio dirigida pelo teste (emula `restoreQueue` / troca de faixa).
class _ControllableAudioSession extends AudioPlayerSessionNotifier {
  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  void emitQueue(List<AudioTrack> tracks) {
    state = AudioPlayerSessionState(queue: tracks);
  }

  /// Fila reidratada no boot (`restoreQueue`) — nada foi tocado ainda.
  void emitRestoredQueue(List<AudioTrack> tracks) {
    state = AudioPlayerSessionState(
      queue: tracks,
      restoredWithoutPlayback: true,
    );
  }
}

class _FakeColdigomAudioTracksCache extends ColdigomAudioTracksCacheNotifier {
  _FakeColdigomAudioTracksCache(this.initial);

  final Map<String, AudioTrack> initial;

  @override
  Map<String, AudioTrack> build() => initial;
}

/// Metadados do manifest para o id — é daí que o chip tira número e nome.
Louvor _manifestLouvor({
  required String pdfId,
  required String numero,
  required String nome,
}) {
  return Louvor.fromManifest(
    nome: nome,
    numero: numero,
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g-$pdfId',
  );
}

List<PlaylistEntry> _entriesOf(Iterable<String> ids) => [
  for (final id in ids) PlaylistEntry(id: id, kind: MaterialKind.pdf),
];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final manifest = {
    'a': _manifestLouvor(pdfId: 'a', numero: '001', nome: 'Louvor A'),
    'b': _manifestLouvor(pdfId: 'b', numero: '002', nome: 'Louvor B'),
    'c': _manifestLouvor(pdfId: 'c', numero: '003', nome: 'Louvor C'),
  };
  final entries = _entriesOf(const ['a', 'b', 'c']);

  /// Lista ativa em memória — é dela que o compartilhar tira id e nome (D3).
  final activePlaylist = SavedPlaylist(
    playlistId: 'p1',
    nome: 'Ensaio',
    createdAt: DateTime(2026, 1, 1),
    entries: entries,
    salva: false,
  );

  Widget buildSubject(
    List<PlaylistEntry> activeEntries, {
    FakeActiveEditor? notifier,
  }) {
    final editor = notifier ?? FakeActiveEditor(activeEntries);
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        louvoresByPdfIdProvider.overrideWithValue(manifest),
        activePlaylistEditorProvider.overrideWith(() => editor),
        playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
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
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('renderiza apenas um chip visível', (tester) async {
    await tester.pumpWidget(buildSubject(entries));
    await tester.pumpAndSettle();

    expect(find.textContaining('Louvor A'), findsOneWidget);
    expect(find.textContaining('Louvor B'), findsNothing);
    expect(find.textContaining('Louvor C'), findsNothing);
  });

  testWidgets(
    'setas navegam índice focado; ficam apagadas (não escondidas) nos '
    'extremos',
    (tester) async {
      await tester.pumpWidget(buildSubject(entries));
      await tester.pumpAndSettle();

      // As zonas de seta do chip são sempre desenhadas (Task 5,
      // `ChipNavZone`) — nos extremos ficam desabilitadas/apagadas, não
      // somem do layout.
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
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
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // No último item a seta direita está desabilitada: tocar não navega.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.textContaining('Louvor C'), findsOneWidget);
    },
  );

  testWidgets('chip da barra não possui botão de remover', (tester) async {
    await tester.pumpWidget(buildSubject(entries));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('modal permite remover item', (tester) async {
    final notifier = FakeActiveEditor(entries);
    await tester.pumpWidget(buildSubject(entries, notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music));
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

    await tester.tap(
      find.descendant(of: dialog, matching: find.byIcon(Icons.close)).first,
    );
    await tester.pumpAndSettle();

    expect(notifier.removedKeys, ['a']);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Louvor A')),
      findsNothing,
    );
  });

  testWidgets('exibe só compartilhar à direita, sem menu de três pontos', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(entries));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.byIcon(Icons.adaptive.share), findsOneWidget);
    // Barra larga (800 px de teste ≥ 600) mostra legenda, não tooltip (D3).
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsNothing);
    expect(find.text('Salvar como lista'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
  });

  testWidgets('em smartphone compartilhar não esconde limpar nem lista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(entries));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.adaptive.share), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // Zonas de seta sempre presentes (Task 5) — a esquerda fica apagada.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.byIcon(Icons.view_list), findsNothing);
  });

  testWidgets('botão compartilhar em smartphone abre sheet de compartilhar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playlistsNotifier = FakePlaylistsNotifier();
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    final editor = FakeActiveEditor(entries);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(() => editor),
          playlistsProvider.overrideWith(() => playlistsNotifier),
          activePlaylistProvider.overrideWithValue(activePlaylist),
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

    await tester.tap(find.byIcon(Icons.adaptive.share));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só o link'));
    await tester.pumpAndSettle();

    expect(shareNotifier.lastOption, PlaylistShareOption.link);
  });

  testWidgets(
    'compartilhar com a lista ativa preenchida não avisa lista vazia',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final playlistsNotifier = FakePlaylistsNotifier();
      final shareNotifier = _FakePlaylistShareActionsNotifier();
      final editor = FakeActiveEditor(entries);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            louvoresByPdfIdProvider.overrideWithValue(manifest),
            activePlaylistEditorProvider.overrideWith(() => editor),
            playlistsProvider.overrideWith(() => playlistsNotifier),
            activePlaylistProvider.overrideWithValue(activePlaylist),
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

      await tester.tap(find.byIcon(Icons.adaptive.share));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Só o link'));
      await tester.pumpAndSettle();

      expect(find.text('Esta lista não tem louvores.'), findsNothing);
    },
  );

  testWidgets('compartilhar folheto pelo sheet da barra', (
    tester,
  ) async {
    final playlistsNotifier = FakePlaylistsNotifier();
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    final editor = FakeActiveEditor(entries);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(() => editor),
          playlistsProvider.overrideWith(() => playlistsNotifier),
          activePlaylistProvider.overrideWithValue(activePlaylist),
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

    await tester.tap(find.byIcon(Icons.adaptive.share));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folheto'));
    await tester.pumpAndSettle();

    expect(shareNotifier.lastOption, PlaylistShareOption.linkWithLeaflet);
  });

  testWidgets('limpar seleção com Nova Lista', (tester) async {
    final notifier = FakeActiveEditor(entries);
    final playlists = FakePlaylistsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(() => notifier),
          playlistsProvider.overrideWith(() => playlists),
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

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Limpar seleção?'), findsOneWidget);
    expect(find.text('Nova Lista'), findsOneWidget);
    expect(find.text('Apagar lista'), findsNothing);
    await tester.tap(find.text('Nova Lista'));
    await tester.pumpAndSettle();

    expect(playlists.startedNewEmpty, isTrue);
    expect(playlists.deletedActiveUnsaved, isFalse);
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
          builder: (_, _) => const Scaffold(body: CarouselChips()),
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor(entries),
          ),
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
          builder: (_, _) => const Scaffold(body: CarouselChips()),
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor(entries),
          ),
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

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Louvor B'));
    await tester.pumpAndSettle();

    expect(readerActions.lastPdfId, 'b');
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('segundo toque no chip do modal no leitor troca o PDF', (
    tester,
  ) async {
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor(entries),
          ),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
          readerCarouselPositionProvider('b').overrideWith(
            (ref) => const CarouselReaderPosition(
              currentIndex: 2,
              total: 3,
              currentKey: 'b',
              previousKey: 'a',
              nextKey: 'c',
              previousMaterialId: 'a',
              nextMaterialId: 'c',
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

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor C'));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedPdfIds, ['c']);
    expect(router.state.uri.queryParameters['pdfId'], 'c');

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor A'));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedPdfIds, ['c', 'a']);
    expect(router.state.uri.queryParameters['pdfId'], 'a');
  });

  testWidgets('segundo toque no chip do modal no shell abre outro PDF', (
    tester,
  ) async {
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor(entries),
          ),
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

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor B'));
    await tester.pumpAndSettle();

    expect(find.text('b'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Louvor C'));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedPdfIds, ['b', 'c']);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('o mesmo louvor repetido é duas entradas navegáveis', (
    tester,
  ) async {
    final repeated = _entriesOf(const ['a', 'a', 'b']);
    await tester.pumpWidget(buildSubject(repeated));
    await tester.pumpAndSettle();

    // Três ocorrências, duas do mesmo id: a seta anda por ocorrência.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.textContaining('Louvor A'), findsOneWidget);
    // O foco persistido é a chave da **segunda** ocorrência, não o id.
    expect(prefs.getString('carousel_focused_pdf_id'), 'a#1');

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.textContaining('Louvor B'), findsOneWidget);
    expect(prefs.getString('carousel_focused_pdf_id'), 'b');
  });

  testWidgets('item único mostra setas apagadas (sem para onde navegar)', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject([entries.first]));
    await tester.pumpAndSettle();

    // As zonas de seta são sempre desenhadas (Task 5, `ChipNavZone`); com um
    // só item ficam desabilitadas/apagadas, não escondidas.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.textContaining('Louvor A'), findsOneWidget);
  });

  testWidgets('modo leitor exibe setas com posição no carousel', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor(entries),
          ),
          readerCarouselPositionProvider('b').overrideWith(
            (ref) => const CarouselReaderPosition(
              currentIndex: 2,
              total: 3,
              currentKey: 'b',
              previousKey: 'a',
              nextKey: 'c',
              previousMaterialId: 'a',
              nextMaterialId: 'c',
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
    expect(find.byIcon(Icons.queue_music), findsOneWidget);
    expect(find.byIcon(Icons.view_list), findsNothing);
    // D10: sem áudio no louvor aberto, o slot "abrir" não aparece.
    expect(find.byIcon(Icons.file_open_outlined), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('seta do leitor navega pela chave da ocorrência vizinha', (
    tester,
  ) async {
    // Louvor A repetido: o vizinho à direita de B é a **segunda** ocorrência
    // dele (`a#1`). Navegar por id não saberia distinguir as duas.
    final repeated = _entriesOf(const ['a', 'b', 'a']);
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor(repeated),
          ),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
          readerCarouselPositionProvider('b').overrideWith(
            (ref) => const CarouselReaderPosition(
              currentIndex: 2,
              total: 3,
              currentKey: 'b',
              previousKey: 'a',
              nextKey: 'a#1',
              previousMaterialId: 'a',
              nextMaterialId: 'a',
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

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(readerActions.navigatedKeys, ['a#1']);
    expect(readerActions.navigatedPdfIds, ['a']);
    // O foco é efeito de `navigateToKey`: a ocorrência focada é a segunda.
    expect(prefs.getString('carousel_focused_pdf_id'), 'a#1');
  });

  testWidgets('remover uma ocorrência não tira o leitor do louvor repetido', (
    tester,
  ) async {
    final repeated = FakeActiveEditor(_entriesOf(const ['a', 'b', 'a']));
    final readerActions = _FakeReaderCarouselActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(() => repeated),
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

    router.go(
      '${RoutePaths.reader}?pdfId=a&file=asset:fixtures/sample.pdf&titulo=Louvor%20A',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();

    // Remove a **segunda** ocorrência de A (a terceira linha do modal).
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.close),
          )
          .at(2),
    );
    await tester.pumpAndSettle();

    expect(repeated.removedKeys, ['a#1']);
    // A outra ocorrência de A continua na face: o leitor fica onde está.
    expect(readerActions.navigatedKeys, isEmpty);
    expect(readerActions.navigatedPdfIds, isEmpty);
    expect(router.state.uri.queryParameters['pdfId'], 'a');
  });

  testWidgets(
    'modo leitor não oferece mais tocar áudio (botão removido — risco de '
    'misclique)',
    (tester) async {
      final pdfId = encodePdfId('assets/praises/p1/partitura.pdf');
      final louvor = Louvor.fromManifest(
        nome: 'Louvor D',
        numero: '004',
        categoria: 'Partitura',
        classificacao: 'Coro',
        pdf: 'partitura.pdf',
        pdfId: pdfId,
        groupId: 'p1',
        source: LouvorDataSource.coldigom,
      );
      const track = AudioTrack(
        audioId: 'aud-p1',
        r2Key: 'assets/praises/p1/a.mp3',
        nome: 'Louvor D',
        numero: '004',
        groupId: 'p1',
        categoria: 'Áudio',
        classificacao: 'Coro',
      );

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: CarouselChips()),
          ),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, _) => const Scaffold(body: CarouselChips()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(
              () => FakeActiveEditor(_entriesOf([pdfId])),
            ),
            playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
            coldigomLouvoresCacheProvider.overrideWith(
              () => _FakeColdigomLouvoresCache({pdfId: louvor}),
            ),
            coldigomAudioTracksCacheProvider.overrideWith(
              () => _FakeColdigomAudioTracksCache({track.audioId: track}),
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

      router.go('${RoutePaths.reader}?pdfId=$pdfId&titulo=Louvor%20D');
      await tester.pumpAndSettle();

      // Mesmo com áudio disponível para o louvor aberto, o slot "abrir" da
      // barra 2 não mostra mais o play — o botão foi removido por aumentar a
      // probabilidade de misclique sem ser útil para a maioria das pessoas.
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.byIcon(Icons.file_open_outlined), findsNothing);
    },
  );

  group('seguir o áudio (listener do shell)', () {
    final chordP1Id = encodePdfId('assets/praises/p1/cifra.chord');
    final pdfP1Id = encodePdfId('assets/praises/p1/partitura.pdf');
    final pdfP2Id = encodePdfId('assets/praises/p2/partitura.pdf');

    Louvor coldigomPdf(String pdfId, String groupId) => Louvor.fromManifest(
      nome: 'Louvor $groupId',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'partitura.pdf',
      pdfId: pdfId,
      groupId: groupId,
      source: LouvorDataSource.coldigom,
    );

    final chordP1 = ChordMaterial(
      chordId: chordP1Id,
      r2Key: 'assets/praises/p1/cifra.chord',
      nome: 'Louvor p1',
      numero: '001',
      groupId: 'p1',
      categoria: 'Cifra',
      classificacao: 'Coro',
    );

    AudioTrack trackFor(String groupId) => AudioTrack(
      audioId: 'aud-$groupId',
      r2Key: 'assets/praises/$groupId/a.mp3',
      nome: 'Louvor $groupId',
      numero: '001',
      groupId: groupId,
      categoria: 'Áudio',
      classificacao: 'Coro',
    );

    // A partitura vem antes da cifra: é ela que `findMaterialForGroup` devolve
    // para o grupo p1, enquanto o leitor exibe a cifra do mesmo louvor.
    final activeEntries = _entriesOf([pdfP1Id, chordP1Id, pdfP2Id]);

    Future<_ControllableAudioSession> pumpReader(
      WidgetTester tester,
      _FakeReaderCarouselActions readerActions,
    ) async {
      final session = _ControllableAudioSession();
      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: CarouselChips()),
          ),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, state) => Scaffold(
              body: Column(
                children: [
                  Text('aberto:${state.uri.queryParameters['pdfId'] ?? ''}'),
                  const Expanded(child: CarouselChips()),
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(
              () => FakeActiveEditor(activeEntries),
            ),
            playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
            readerCarouselActionsProvider.overrideWith(() => readerActions),
            audioPlayerSessionProvider.overrideWith(() => session),
            coldigomLouvoresCacheProvider.overrideWith(
              () => _FakeColdigomLouvoresCache({
                pdfP1Id: coldigomPdf(pdfP1Id, 'p1'),
                pdfP2Id: coldigomPdf(pdfP2Id, 'p2'),
              }),
            ),
            coldigomChordMaterialsCacheProvider.overrideWith(
              () => _FakeColdigomChordMaterialsCache({chordP1Id: chordP1}),
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

      router.go('${RoutePaths.reader}?pdfId=$chordP1Id&titulo=Cifra%20p1');
      await tester.pumpAndSettle();
      return session;
    }

    testWidgets('restauração da sessão não sequestra o leitor', (tester) async {
      final readerActions = _FakeReaderCarouselActions();
      final session = await pumpReader(tester, readerActions);

      // `restoreQueue` no boot: fila com faixa de outro louvor, sem tocar.
      session.emitRestoredQueue([trackFor('p2')]);
      await tester.pumpAndSettle();

      expect(readerActions.navigatedPdfIds, isEmpty);
      expect(find.text('aberto:$chordP1Id'), findsOneWidget);
    });

    testWidgets('não troca o material escolhido do mesmo louvor', (
      tester,
    ) async {
      final readerActions = _FakeReaderCarouselActions();
      final session = await pumpReader(tester, readerActions);

      session.emitQueue([trackFor('p9')]);
      await tester.pumpAndSettle();

      // Troca real de louvor, mas para o louvor da cifra já aberta.
      session.emitQueue([trackFor('p1')]);
      await tester.pumpAndSettle();

      expect(readerActions.navigatedPdfIds, isEmpty);
      expect(find.text('aberto:$chordP1Id'), findsOneWidget);
    });

    testWidgets('primeira faixa da sessão segue (A6)', (tester) async {
      final readerActions = _FakeReaderCarouselActions();
      final session = await pumpReader(tester, readerActions);

      // Cifra de p1 aberta e o usuário dá play no áudio de p2: é a primeira
      // faixa da sessão, mas não veio de restauração.
      session.emitQueue([trackFor('p2')]);
      await tester.pumpAndSettle();

      expect(readerActions.navigatedPdfIds, [pdfP2Id]);
    });

    testWidgets('segue o áudio quando o louvor muda de verdade', (
      tester,
    ) async {
      final readerActions = _FakeReaderCarouselActions();
      final session = await pumpReader(tester, readerActions);

      session.emitQueue([trackFor('p9')]);
      await tester.pumpAndSettle();

      session.emitQueue([trackFor('p2')]);
      await tester.pumpAndSettle();

      expect(readerActions.navigatedPdfIds, [pdfP2Id]);
    });
  });

  group('rebuild só com o que usa (A7)', () {
    testWidgets(
      'observar só queue.isNotEmpty não reconstrói quando só a posição muda',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlayerSessionProvider.overrideWith(
              _ControllableAudioSession.new,
            ),
          ],
        );
        addTearDown(container.dispose);
        var buildCount = 0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  buildCount++;
                  ref.watch(
                    audioPlayerSessionProvider.select(
                      (s) => s.queue.isNotEmpty,
                    ),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        final afterMount = buildCount;

        // Só a posição muda: a posição mora num provider separado (A7) e não
        // pode disparar rebuild de quem só observa `queue.isNotEmpty`.
        container
            .read(audioPlayerPositionProvider.notifier)
            .update(position: const Duration(milliseconds: 200));
        await tester.pump();
        container
            .read(audioPlayerPositionProvider.notifier)
            .update(position: const Duration(milliseconds: 400));
        await tester.pump();

        expect(
          buildCount,
          afterMount,
          reason:
              'a posição mudou 2x e não pode ter reconstruído quem só '
              'observa queue.isNotEmpty',
        );

        // Sanidade: uma troca real na seleção que o widget observa continua
        // reconstruindo.
        final session =
            container.read(audioPlayerSessionProvider.notifier)
                as _ControllableAudioSession;
        session.emitQueue([
          AudioTrack(
            audioId: 'aud-a',
            r2Key: 'assets/praises/p1/a.mp3',
            nome: 'A',
            numero: '001',
            groupId: 'p1',
            categoria: 'Áudio',
            classificacao: 'Coro',
          ),
        ]);
        await tester.pump();

        expect(buildCount, afterMount + 1);
      },
    );
  });
}
