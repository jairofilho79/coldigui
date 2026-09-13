import 'dart:convert';
import '../../../support/fakes/fake_playlists_notifier.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/chord_reader_url_builder.dart';
import 'package:coldigui/core/utils/gesture_reader_url_builder.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/pending_delete.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_list_tile.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editor da lista ativa que registra as ativações e as espelha em
/// [activePlaylistIdProvider], como o editor real (D6).
///
/// O id ativo inicial (o que o primeiro «Desfazer» restaura) vem das prefs —
/// ver [prefsWithActive].
class _RecordingActiveEditor extends ActivePlaylistEditor {
  final activated = <String>[];

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<String?> activate(String playlistId) async {
    activated.add(playlistId);
    final previous = ref.read(activePlaylistIdProvider);
    ref.read(activePlaylistIdProvider.notifier).set(playlistId);
    return previous;
  }
}

/// Registra as remoções por posição pedidas ao notifier (lista não ativa).
class _RemovalRecordingPlaylistsNotifier extends FakePlaylistsNotifier {
  _RemovalRecordingPlaylistsNotifier(super.initial);

  final removed = <(String, int)>[];

  @override
  Future<void> removeEntryAt({
    required String playlistId,
    required int index,
  }) async {
    removed.add((playlistId, index));
  }
}

/// Editor que registra as remoções por chave (lista ativa).
class _RemovalRecordingActiveEditor extends _RecordingActiveEditor {
  final removedKeys = <String>[];

  @override
  Future<void> removeByKey(String key) async {
    removedKeys.add(key);
  }
}

/// Modo degradado (Isar fechado): ativar lança.
class _StorelessActiveEditor extends _RecordingActiveEditor {
  @override
  Future<String?> activate(String playlistId) async {
    throw const StorageUnavailableException('playlists.update');
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

/// Registra os pedidos de `deleteWithUndo`/`undo`/`commit` (C11) sem tocar
/// no repositório de verdade — devolve um [PendingDelete] real (com `grace`
/// infinito para não disparar sozinho durante o teste).
class _DeleteRecordingPlaylistsNotifier extends FakePlaylistsNotifier {
  _DeleteRecordingPlaylistsNotifier(super.initial);

  final deleteRequests = <String>[];
  final undoRequests = <String>[];
  final commitRequests = <String>[];
  PendingDelete? lastPending;

  @override
  PendingDelete deleteWithUndo(
    String playlistId, {
    Duration grace = const Duration(seconds: 5),
  }) {
    deleteRequests.add(playlistId);
    final pending = PendingDelete(
      grace: grace,
      onUndo: () async => undoRequests.add(playlistId),
      onCommit: () async => commitRequests.add(playlistId),
    );
    lastPending = pending;
    return pending;
  }
}

/// Registra os pedidos de `duplicate` (C11).
class _DuplicateRecordingPlaylistsNotifier extends FakePlaylistsNotifier {
  _DuplicateRecordingPlaylistsNotifier(super.initial);

  final duplicated = <(String, String)>[];

  @override
  Future<String> duplicate(
    String playlistId, {
    required String copyName,
  }) async {
    duplicated.add((playlistId, copyName));
    return 'copy-of-$playlistId';
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

/// Resolve que encontra o índice apontando para um arquivo apagado do disco.
class _DeletedPdfResolveForReader implements ResolvePdfForReader {
  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    throw PdfExternallyDeletedException(pdfId: pdfId);
  }
}

class _LouvorFindingPlaylistsNotifier extends FakePlaylistsNotifier {
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

class _FakeChordCacheNotifier extends ColdigomChordMaterialsCacheNotifier {
  _FakeChordCacheNotifier(this.initial);

  final Map<String, ChordMaterial> initial;

  @override
  Map<String, ChordMaterial> build() => initial;
}

class _FakeGestureCacheNotifier extends ColdigomGestureMaterialsCacheNotifier {
  _FakeGestureCacheNotifier(this.initial);

  final Map<String, GestureMaterial> initial;

  @override
  Map<String, GestureMaterial> build() => initial;
}

/// Registra o material que chegou ao ponto único de abertura.
///
/// Tudo que não é PDF passa a ser aberto pelo `openMaterialProvider`, então o
/// teste verifica o material que ele recebe; no caso da cifra o fake ainda
/// navega para `/cifra`.
class _OpenMaterialSpy {
  CatalogMaterial? opened;

  OpenMaterial build() {
    return OpenMaterial(
      openChord: ({required ref, required context, required chord}) async {
        opened = ChordMaterialRef(chord);
        await context.push(
          buildChordReaderLocation(
            chordId: chord.chordId,
            titulo: chord.nome,
            subtitulo: chord.numero,
          ),
        );
      },
      openGesture: ({required ref, required context, required gesture}) async {
        opened = GestureMaterialRef(gesture);
        await context.push(
          buildGestureReaderLocation(
            gestureId: gesture.gestureId,
            titulo: gesture.nome,
            subtitulo: gesture.numero,
          ),
        );
      },
      openAudio:
          ({
            required ref,
            required context,
            required track,
            List<AudioTrack>? queue,
          }) async {
            opened = AudioMaterial(track);
          },
    );
  }
}

class _FakeAudioCacheNotifier extends ColdigomAudioTracksCacheNotifier {
  _FakeAudioCacheNotifier(this.initial);

  final Map<String, AudioTrack> initial;

  @override
  Map<String, AudioTrack> build() => initial;
}

/// Editor do teste de toque no chip de áudio (fix round 1, Task 4): além de
/// registrar `activate` (herdado de [_RecordingActiveEditor]), registra o
/// `addToActive` que `playAudioInSession`/`openAudioInPlayer` disparam ao
/// tocar (D4) — sem tocar em Isar/storage de verdade, mesmo padrão do
/// `_StubActiveEditor` de `play_audio_in_session_storage_test.dart`.
class _AudioActivatingEditor extends _RecordingActiveEditor {
  final addedToActive = <String>[];

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    addedToActive.add(materialId);
    return AddToActiveOutcome.added;
  }
}

/// Sessão de áudio de mentira: registra a fila e o índice inicial que
/// `playQueue` recebeu — mesmo padrão de
/// `play_entry_points_active_queue_test.dart`.
class _RecordingAudioSession extends AudioPlayerSessionNotifier {
  List<AudioTrack>? queue;
  int? startIndex;

  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    queue = tracks;
    this.startIndex = startIndex;
  }
}

String _pdfId(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Prefs com [activeId] já ativo antes de o tile aparecer.
  Future<void> prefsWithActive(String activeId) async {
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: activeId,
    });
    prefs = await SharedPreferences.getInstance();
  }

  final pdfIdA = _pdfId('ColAdultos/001.pdf');
  final pdfIdB = _pdfId('ColAdultos/002.pdf');

  final item = PlaylistViewItem(
    playlist: SavedPlaylist.fromLegacyLists(
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
    _RecordingActiveEditor? editor,
  }) {
    final shareNotifier =
        shareActionsNotifier ?? _FakePlaylistShareActionsNotifier();
    final activeEditor = editor ?? _RecordingActiveEditor();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistsProvider.overrideWith(() => playlistsNotifier),
        playlistShareActionsProvider.overrideWith(() => shareNotifier),
        activePlaylistEditorProvider.overrideWith(() => activeEditor),
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

  testWidgets('menu exibe Tornar lista ativa e Abrir no leitor', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(playlistsNotifier: FakePlaylistsNotifier([item])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Tornar lista ativa'), findsOneWidget);
    expect(find.text('Abrir no leitor'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Duplicar'), findsOneWidget);
    expect(find.text('Gerar folheto'), findsOneWidget);
    expect(find.text('Carregar no carousel'), findsNothing);
  });

  // D6: trocar a lista ativa não substitui nada — a anterior continua salva.
  // Nada de modal; a saída é o snackbar com «Desfazer».
  testWidgets('«Tornar lista ativa» ativa sem diálogo e o snackbar desfaz', (
    tester,
  ) async {
    await prefsWithActive('p0');
    final editor = _RecordingActiveEditor();
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: FakePlaylistsNotifier([item]),
        editor: editor,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();

    expect(find.text('Substituir seleção?'), findsNothing);
    expect(find.text('Confirmar'), findsNothing);
    expect(editor.activated, ['p1']);
    expect(find.text('Lista «Ensaio domingo» ativa'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(editor.activated, ['p1', 'p0']);
  });

  // Crítico (revisão r1): o snackbar vive 5 s no messenger da raiz e o tile
  // pode sair da árvore nesse meio-tempo (troca de aba). O callback não pode
  // tocar em `ref` — tem que usar o que foi capturado antes de mostrar.
  testWidgets('«Desfazer» funciona depois que o tile saiu da árvore', (
    tester,
  ) async {
    await prefsWithActive('p0');
    final editor = _RecordingActiveEditor();
    final showTile = ValueNotifier(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => FakePlaylistsNotifier([item])),
          playlistShareActionsProvider.overrideWith(
            _FakePlaylistShareActionsNotifier.new,
          ),
          activePlaylistEditorProvider.overrideWith(() => editor),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showTile,
              builder: (_, show, _) => show
                  ? PlaylistListTile(item: item, tab: PlaylistTab.saved)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();
    expect(editor.activated, ['p1']);

    showTile.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistListTile), findsNothing);
    expect(find.text('Desfazer'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(editor.activated, ['p1', 'p0']);
  });

  // Importante (revisão r1): snackbars enfileiram; o «Desfazer» de B não
  // pode derrubar a ativação de C que veio depois.
  testWidgets('«Desfazer» antigo não derruba uma ativação mais nova', (
    tester,
  ) async {
    await prefsWithActive('p0');
    final editor = _RecordingActiveEditor();
    final itemC = PlaylistViewItem(
      playlist: SavedPlaylist.fromLegacyLists(
        playlistId: 'p2',
        nome: 'Ensaio quarta',
        pdfIds: [pdfIdA],
        createdAt: DateTime(2026, 6, 9),
      ),
      pdfLabels: const ['001 — A'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(
            () => FakePlaylistsNotifier([item, itemC]),
          ),
          playlistShareActionsProvider.overrideWith(
            _FakePlaylistShareActionsNotifier.new,
          ),
          activePlaylistEditorProvider.overrideWith(() => editor),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: Column(
              children: [
                PlaylistListTile(item: item, tab: PlaylistTab.saved),
                PlaylistListTile(item: itemC, tab: PlaylistTab.saved),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ativa B (p1) e guarda o callback do «Desfazer» dela.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();
    final undoOfB = tester
        .widget<SnackBarAction>(find.byType(SnackBarAction))
        .onPressed;

    // Ativa C (p2).
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();
    expect(editor.activated, ['p1', 'p2']);

    // Só o snackbar de C está visível — o de B foi limpo, não enfileirado.
    expect(find.text('Lista «Ensaio domingo» ativa'), findsNothing);
    expect(find.text('Lista «Ensaio quarta» ativa'), findsOneWidget);

    // O «Desfazer» de B, disparado tarde, não derruba C.
    undoOfB();
    await tester.pumpAndSettle();
    expect(editor.activated, ['p1', 'p2']);

    // O desfazer visível (o de C) volta para B.
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(editor.activated, ['p1', 'p2', 'p1']);
  });

  // Menor (revisão r1): lista já ativa não tem para onde "voltar".
  testWidgets('lista já ativa não oferece desfazer', (tester) async {
    await prefsWithActive('p1');
    final editor = _RecordingActiveEditor();
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: FakePlaylistsNotifier([item]),
        editor: editor,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();

    expect(editor.activated, ['p1']);
    expect(find.text('Lista «Ensaio domingo» ativa'), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);
  });

  testWidgets('sem lista ativa anterior o snackbar não oferece desfazer', (
    tester,
  ) async {
    final editor = _RecordingActiveEditor();
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: FakePlaylistsNotifier([item]),
        editor: editor,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();

    expect(editor.activated, ['p1']);
    expect(find.text('Lista «Ensaio domingo» ativa'), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);
  });

  // B5: ação da lista sem storage vira aviso, não erro solto no callback.
  testWidgets('ação sem armazenamento mostra o aviso de storage', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: FakePlaylistsNotifier([item]),
        editor: _StorelessActiveEditor(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar lista ativa'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Armazenamento local indisponível. Recarregue a página ou libere espaço.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('toque no chip abre leitor com pdf selecionado', (tester) async {
    final notifier = _LouvorFindingPlaylistsNotifier([item]);
    final editor = _RecordingActiveEditor();
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => notifier),
          activePlaylistEditorProvider.overrideWith(() => editor),
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

    expect(editor.activated, ['p1']);
    expect(find.text(pdfIdB), findsOneWidget);
  });

  // Fix round 1 (revisão Task 4, Importante 1): o caminho de áudio (chip e
  // menu «Abrir no reprodutor» chamam o mesmo `openAudioTrack`) não tinha o
  // teste ponta a ponta simétrico ao do PDF acima — ativa a lista e toca a
  // fila híbrida (D4) de verdade, sem dublê de `PlaylistTileActions`.
  testWidgets('toque no chip de áudio ativa a lista e toca a fila (D4)', (
    tester,
  ) async {
    final audioId = _pdfId('ColAdultos/003.mp3');
    final track = AudioTrack(
      audioId: audioId,
      r2Key: 'ColAdultos/003.mp3',
      nome: 'Toque no áudio',
      numero: '003',
      groupId: '003',
      categoria: 'Áudio',
      classificacao: 'ColAdultos',
    );
    final audioItem = PlaylistViewItem(
      playlist: SavedPlaylist.fromLegacyLists(
        playlistId: 'p3',
        nome: 'Ensaio com áudio',
        pdfIds: [pdfIdA],
        audioIds: [audioId],
        createdAt: DateTime(2026, 6, 10),
      ),
      pdfLabels: const ['001 — A'],
    );
    final editor = _AudioActivatingEditor();
    final session = _RecordingAudioSession();
    final router = GoRouter(
      initialLocation: RoutePaths.playlists,
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, _) => Scaffold(
            body: PlaylistListTile(item: audioItem, tab: PlaylistTab.saved),
          ),
        ),
        GoRoute(
          path: RoutePaths.audio,
          builder: (_, state) =>
              Scaffold(body: Text(state.uri.queryParameters['audioId'] ?? '')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(
            () => FakePlaylistsNotifier([audioItem]),
          ),
          activePlaylistEditorProvider.overrideWith(() => editor),
          audioPlayerSessionProvider.overrideWith(() => session),
          coldigomAudioTracksCacheProvider.overrideWith(
            () => _FakeAudioCacheNotifier({audioId: track}),
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

    await tester.tap(find.text('Ensaio com áudio'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('003'));
    await tester.pumpAndSettle();

    // (a) a lista do chip virou a ativa (D6) — mesma asserção usada no
    // caminho de PDF e no de «Tornar lista ativa».
    expect(editor.activated, ['p3']);
    // (b) a sessão recebeu a fila híbrida (D4) com a faixa tocada no início.
    expect(session.queue?.map((t) => t.audioId).toList(), [audioId]);
    expect(session.startIndex, 0);
  });

  testWidgets(
    'PDF removido do dispositivo mostra o texto do l10n, não o erro genérico',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final pt = await AppLocalizations.delegate.load(const Locale('pt'));
      final notifier = _LouvorFindingPlaylistsNotifier([item]);
      final editor = _RecordingActiveEditor();
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
            sharedPreferencesProvider.overrideWithValue(prefs),
            playlistsProvider.overrideWith(() => notifier),
            activePlaylistEditorProvider.overrideWith(() => editor),
            resolvePdfForReaderProvider.overrideWithValue(
              _DeletedPdfResolveForReader(),
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

      // Antes da correção do round 1 este caminho caía na snackbar genérica
      // da playlist, escondendo que o arquivo sumiu do aparelho.
      expect(find.text(pt.pdfExternallyDeleted), findsOneWidget);
      expect(find.text(pt.pdfActionError), findsNothing);
    },
  );

  testWidgets('Abrir no leitor com cifra na primeira posicao vai para /cifra', (
    tester,
  ) async {
    // A cifra entra na lista com o mesmo espaco de ids do PDF, entao so o
    // materialIdKindOf separa as duas. Sem o desvio, o notifier abaixo (que
    // acha Louvor para qualquer id) mandaria a cifra para /leitor.
    final chordId = _pdfId('assets/praises/p1/m1.chord');
    final chordItem = PlaylistViewItem(
      playlist: SavedPlaylist.fromLegacyLists(
        playlistId: 'p1',
        nome: 'Ensaio com cifra',
        pdfIds: [chordId, pdfIdB],
        createdAt: DateTime(2026, 6, 8),
      ),
      pdfLabels: ['Cifra — A', '002 — B'],
    );
    final chord = ChordMaterial(
      chordId: chordId,
      r2Key: 'assets/praises/p1/m1.chord',
      nome: 'Comigo habita',
      numero: '001',
      groupId: 'p1',
      categoria: 'Cifra',
      classificacao: 'ColAdultos',
    );

    final notifier = _LouvorFindingPlaylistsNotifier([chordItem]);

    final editor = _RecordingActiveEditor();
    final openSpy = _OpenMaterialSpy();
    final router = GoRouter(
      initialLocation: RoutePaths.playlists,
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (_, _) => Scaffold(
            body: PlaylistListTile(item: chordItem, tab: PlaylistTab.saved),
          ),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, state) => Scaffold(
            body: Text('leitor:${state.uri.queryParameters['pdfId']}'),
          ),
        ),
        GoRoute(
          path: RoutePaths.chords,
          builder: (_, state) => Scaffold(
            body: Text('cifra:${state.uri.queryParameters['pdfId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => notifier),
          activePlaylistEditorProvider.overrideWith(() => editor),
          coldigomChordMaterialsCacheProvider.overrideWith(
            () => _FakeChordCacheNotifier({chordId: chord}),
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _FakeResolvePdfForReader(),
          ),
          openMaterialProvider.overrideWithValue(openSpy.build()),
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

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir no leitor'));
    await tester.pumpAndSettle();

    expect(editor.activated, ['p1']);
    expect(openSpy.opened, isA<ChordMaterialRef>());
    expect(openSpy.opened!.id, chordId);
    expect(find.text('cifra:$chordId'), findsOneWidget);
    expect(find.textContaining('Não foi possível'), findsNothing);
  });

  testWidgets(
    'Abrir no leitor com gesto na primeira posicao vai para /gestos',
    (tester) async {
      // Mesmo caminho da cifra acima: o gesto entra na lista com o mesmo espaco
      // de ids do PDF, entao so o materialIdKindOf separa os dois.
      final gestureId = _pdfId('assets/praises/p1/m1.gestures');
      final gestureItem = PlaylistViewItem(
        playlist: SavedPlaylist.fromLegacyLists(
          playlistId: 'p1',
          nome: 'Ensaio com gesto',
          pdfIds: [gestureId, pdfIdB],
          createdAt: DateTime(2026, 6, 8),
        ),
        pdfLabels: ['Gestos — A', '002 — B'],
      );
      final gesture = GestureMaterial(
        gestureId: gestureId,
        r2Key: 'assets/praises/p1/m1.gestures',
        nome: 'Comigo habita',
        numero: '001',
        groupId: 'p1',
        categoria: 'Gestos',
        classificacao: 'ColAdultos',
      );

      final notifier = _LouvorFindingPlaylistsNotifier([gestureItem]);

      final editor = _RecordingActiveEditor();
      final openSpy = _OpenMaterialSpy();
      final router = GoRouter(
        initialLocation: RoutePaths.playlists,
        routes: [
          GoRoute(
            path: RoutePaths.playlists,
            builder: (_, _) => Scaffold(
              body: PlaylistListTile(item: gestureItem, tab: PlaylistTab.saved),
            ),
          ),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, state) => Scaffold(
              body: Text('leitor:${state.uri.queryParameters['pdfId']}'),
            ),
          ),
          GoRoute(
            path: RoutePaths.gestos,
            builder: (_, state) => Scaffold(
              body: Text('gesto:${state.uri.queryParameters['pdfId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playlistsProvider.overrideWith(() => notifier),
            activePlaylistEditorProvider.overrideWith(() => editor),
            coldigomGestureMaterialsCacheProvider.overrideWith(
              () => _FakeGestureCacheNotifier({gestureId: gesture}),
            ),
            resolvePdfForReaderProvider.overrideWithValue(
              _FakeResolvePdfForReader(),
            ),
            openMaterialProvider.overrideWithValue(openSpy.build()),
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

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir no leitor'));
      await tester.pumpAndSettle();

      expect(editor.activated, ['p1']);
      expect(openSpy.opened, isA<GestureMaterialRef>());
      expect(openSpy.opened!.id, gestureId);
      expect(find.text('gesto:$gestureId'), findsOneWidget);
      expect(find.textContaining('Não foi possível'), findsNothing);
    },
  );

  testWidgets('Abrir no leitor com id de áudio na face de partituras toca', (
    tester,
  ) async {
    // O desvio não é mais só de cifra: `kind != pdf` manda qualquer material
    // resolvível para o opener. Um id de áudio só chega aqui quando o `kind`
    // gravado na entrada discorda da extensão do id (a face de partituras é
    // projetada por `PlaylistEntry.kind`, o desvio decide por
    // `materialIdKindOf`); sem este caminho ele cairia no findLouvorByPdfId e
    // viraria erro genérico.
    final audioId = _pdfId('assets/praises/p1/m1.mp3');
    expect(materialIdKindOf(audioId), MaterialKind.audio);

    final audioItem = PlaylistViewItem(
      playlist: SavedPlaylist(
        playlistId: 'p1',
        nome: 'Ensaio com áudio',
        entries: [
          PlaylistEntry(id: audioId, kind: MaterialKind.pdf),
          PlaylistEntry(id: pdfIdB, kind: MaterialKind.pdf),
        ],
        createdAt: DateTime(2026, 6, 8),
      ),
      pdfLabels: ['Áudio — A', '002 — B'],
    );
    expect(audioItem.playlist.pdfIds.first, audioId);

    final track = AudioTrack(
      audioId: audioId,
      r2Key: 'assets/praises/p1/m1.mp3',
      nome: 'Comigo habita',
      numero: '001',
      groupId: 'p1',
      categoria: 'Áudio',
      classificacao: 'ColAdultos',
    );

    final notifier = _LouvorFindingPlaylistsNotifier([audioItem]);

    final editor = _RecordingActiveEditor();
    final openSpy = _OpenMaterialSpy();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(() => notifier),
          activePlaylistEditorProvider.overrideWith(() => editor),
          coldigomAudioTracksCacheProvider.overrideWith(
            () => _FakeAudioCacheNotifier({audioId: track}),
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _FakeResolvePdfForReader(),
          ),
          openMaterialProvider.overrideWithValue(openSpy.build()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlaylistListTile(item: audioItem, tab: PlaylistTab.saved),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir no leitor'));
    await tester.pumpAndSettle();

    expect(editor.activated, ['p1']);
    expect(openSpy.opened, isA<AudioMaterial>());
    expect(openSpy.opened!.id, audioId);
    expect(find.textContaining('Não foi possível'), findsNothing);
  });

  // B.1: a lista pode repetir um louvor. O «×» de um chip remove **aquela**
  // ocorrência — pela posição —, nunca todas as do mesmo id.
  group('«×» do chip remove uma ocorrência (#4)', () {
    final repeated = PlaylistViewItem(
      playlist: SavedPlaylist.fromLegacyLists(
        playlistId: 'p1',
        nome: 'Com repetição',
        pdfIds: [pdfIdA, pdfIdB, pdfIdA],
        createdAt: DateTime(2026, 6, 8),
      ),
      pdfLabels: const ['001 — A', '002 — B', '001 — A'],
    );

    Future<void> pumpRepeated(
      WidgetTester tester, {
      required PlaylistsNotifier notifier,
      required _RecordingActiveEditor editor,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playlistsProvider.overrideWith(() => notifier),
            playlistShareActionsProvider.overrideWith(
              _FakePlaylistShareActionsNotifier.new,
            ),
            activePlaylistEditorProvider.overrideWith(() => editor),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Scaffold(
              body: PlaylistListTile(item: repeated, tab: PlaylistTab.saved),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Com repetição'));
      await tester.pumpAndSettle();
    }

    testWidgets('lista ativa: remove pela chave da ocorrência', (tester) async {
      await prefsWithActive('p1');
      final editor = _RemovalRecordingActiveEditor();
      await pumpRepeated(
        tester,
        notifier: FakePlaylistsNotifier([repeated]),
        editor: editor,
      );

      // Terceiro chip = segunda ocorrência de A.
      await tester.tap(find.byIcon(Icons.close).at(2));
      await tester.pumpAndSettle();

      expect(editor.removedKeys, ['$pdfIdA#1']);
    });

    testWidgets('lista não ativa: remove pela posição na ordem única', (
      tester,
    ) async {
      await prefsWithActive('outra');
      final notifier = _RemovalRecordingPlaylistsNotifier([repeated]);
      final editor = _RemovalRecordingActiveEditor();
      await pumpRepeated(tester, notifier: notifier, editor: editor);

      await tester.tap(find.byIcon(Icons.close).at(2));
      await tester.pumpAndSettle();

      expect(notifier.removed, [('p1', 2)]);
      expect(editor.removedKeys, isEmpty);
    });
  });

  testWidgets('Compartilhar abre sheet e dispara share', (tester) async {
    final shareNotifier = _FakePlaylistShareActionsNotifier();
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: FakePlaylistsNotifier([item]),
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
      buildSubject(playlistsNotifier: FakePlaylistsNotifier([item])),
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
      playlist: SavedPlaylist.fromLegacyLists(
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          playlistsProvider.overrideWith(
            () => FakePlaylistsNotifier([published]),
          ),
          playlistShareActionsProvider.overrideWith(
            _FakePlaylistShareActionsNotifier.new,
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

  // C11: o desfazer substitui a confirmação — nenhum diálogo aparece.
  group('«Apagar»', () {
    testWidgets('sem diálogo, mostra snackbar «Lista removida · Desfazer»', (
      tester,
    ) async {
      final notifier = _DeleteRecordingPlaylistsNotifier([item]);
      await tester.pumpWidget(buildSubject(playlistsNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir lista?'), findsNothing);
      expect(notifier.deleteRequests, ['p1']);
      expect(find.text('Lista removida'), findsOneWidget);
      expect(find.text('Desfazer'), findsOneWidget);
      expect(notifier.undoRequests, isEmpty);

      // Sem isso, o `Timer` de 5 s do `PendingDelete` real ficaria pendente
      // depois da árvore de widgets ser descartada (o teste não desfaz nem
      // espera a graça).
      await notifier.lastPending!.commit();
    });

    testWidgets('«Desfazer» chama o undo do PendingDelete', (tester) async {
      final notifier = _DeleteRecordingPlaylistsNotifier([item]);
      await tester.pumpWidget(buildSubject(playlistsNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(notifier.undoRequests, ['p1']);
      expect(notifier.commitRequests, isEmpty);
    });
  });

  testWidgets('«Duplicar» chama duplicate com o nome de cópia', (tester) async {
    final notifier = _DuplicateRecordingPlaylistsNotifier([item]);
    await tester.pumpWidget(buildSubject(playlistsNotifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicar'));
    await tester.pumpAndSettle();

    expect(notifier.duplicated, [('p1', 'Ensaio domingo (cópia)')]);
  });

  // C16 (fix round 1 — Important 2): mesmo caminho de «Compartilhar», fixado
  // em PlaylistShareOption.leaflet — nunca ativa a lista do tile.
  testWidgets(
    '«Gerar folheto» chama share(..., leaflet) sem trocar a lista ativa',
    (tester) async {
      await prefsWithActive('p0');
      final editor = _RecordingActiveEditor();
      final shareNotifier = _FakePlaylistShareActionsNotifier();
      await tester.pumpWidget(
        buildSubject(
          playlistsNotifier: FakePlaylistsNotifier([item]),
          editor: editor,
          shareActionsNotifier: shareNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gerar folheto'));
      await tester.pumpAndSettle();

      expect(shareNotifier.lastOption, PlaylistShareOption.leaflet);
      expect(find.byType(BottomSheet), findsNothing);

      // Nunca ativa: nem o editor registrou uma ativação, nem o id ativo
      // (o que o «Desfazer» de _activate leria de volta) mudou de p0.
      expect(editor.activated, isEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlaylistListTile)),
      );
      expect(container.read(activePlaylistIdProvider), 'p0');
    },
  );
}
