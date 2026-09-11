import 'dart:convert';

import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/chord_reader_url_builder.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
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

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  _FakePlaylistsNotifier(this.initial);

  final List<PlaylistViewItem> initial;

  @override
  List<PlaylistViewItem> build() => initial;
}

/// Editor da lista ativa que só registra as ativações (D6).
///
/// [previousId] é o que `activate` devolve — o id que o «Desfazer» restaura.
class _RecordingActiveEditor extends ActivePlaylistEditor {
  _RecordingActiveEditor({this.previousId});

  final String? previousId;
  final activated = <String>[];

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<String?> activate(String playlistId) async {
    activated.add(playlistId);
    return previousId;
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

class _FakeChordCacheNotifier extends ColdigomChordMaterialsCacheNotifier {
  _FakeChordCacheNotifier(this.initial);

  final Map<String, ChordMaterial> initial;

  @override
  Map<String, ChordMaterial> build() => initial;
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
      buildSubject(playlistsNotifier: _FakePlaylistsNotifier([item])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Tornar lista ativa'), findsOneWidget);
    expect(find.text('Abrir no leitor'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
    expect(find.text('Carregar no carousel'), findsNothing);
  });

  // D6: trocar a lista ativa não substitui nada — a anterior continua salva.
  // Nada de modal; a saída é o snackbar com «Desfazer».
  testWidgets('«Tornar lista ativa» ativa sem diálogo e o snackbar desfaz', (
    tester,
  ) async {
    final editor = _RecordingActiveEditor(previousId: 'p0');
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: _FakePlaylistsNotifier([item]),
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

  testWidgets('sem lista ativa anterior o snackbar não oferece desfazer', (
    tester,
  ) async {
    final editor = _RecordingActiveEditor();
    await tester.pumpWidget(
      buildSubject(
        playlistsNotifier: _FakePlaylistsNotifier([item]),
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
        playlistsNotifier: _FakePlaylistsNotifier([item]),
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
            () => _FakePlaylistsNotifier([published]),
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
}
