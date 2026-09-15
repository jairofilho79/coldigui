import '../../../support/fakes/fake_playlists_notifier.dart';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fixtures

Louvor _pdf({required String categoria, required String pdfId}) {
  return Louvor.fromManifest(
    nome: 'Comigo habita',
    numero: '692',
    categoria: categoria,
    classificacao: 'Básico',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g1',
    source: LouvorDataSource.coldigom,
  );
}

const _chord = ChordMaterial(
  chordId: 'chord1',
  r2Key: 'k1',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Cifra I',
  classificacao: 'Básico',
);

const _gesture = GestureMaterial(
  gestureId: 'gesture1',
  r2Key: 'k2',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Gestos I',
  classificacao: 'Básico',
);

const _trackA = AudioTrack(
  audioId: 'audio1',
  r2Key: 'audio-key-1',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Playback',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

const _trackB = AudioTrack(
  audioId: 'audio2',
  r2Key: 'audio-key-2',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Instrumental',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

/// Ids "de verdade" (Base64 de um path com extensão de áudio) — só com isso
/// `materialIdKindOf` classifica a entrada focada como
/// [MaterialKind.audio] e o sheet troca por chave em vez de só tocar por
/// cima. `_trackA`/`_trackB` acima usam ids soltos porque os testes que já
/// existiam nunca passavam por `materialIdKindOf`.
final _voiceAudioId1 = encodePdfId('assets/praises/g1/voz1.mp3');
final _voiceAudioId2 = encodePdfId('assets/praises/g1/voz2.mp3');

final _voiceTrackA = AudioTrack(
  audioId: _voiceAudioId1,
  r2Key: 'assets/praises/g1/voz1.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Playback',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

final _voiceTrackB = AudioTrack(
  audioId: _voiceAudioId2,
  r2Key: 'assets/praises/g1/voz2.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Instrumental',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

// ------------------------------------------------------------------- fakes

/// Editor da lista ativa com uma entrada só — a partitura `pdf1` por padrão
/// (ou [initialEntries], para o cenário de troca de voz de áudio).
class _RecordingActiveEditor extends ActivePlaylistEditor {
  _RecordingActiveEditor({
    this.initialEntries = const [
      PlaylistEntry(id: 'pdf1', kind: MaterialKind.pdf),
    ],
  });

  final List<PlaylistEntry> initialEntries;

  /// `(chave da ocorrência, entrada nova)` de cada [replaceByKey].
  final List<(String, PlaylistEntry)> replaced = [];

  /// Ids de cada [addToActive] — o sheet de troca não deve anexar nada.
  final List<String> added = [];

  @override
  List<PlaylistEntry>? build() => initialEntries;

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    added.add(materialId);
    return AddToActiveOutcome.added;
  }

  @override
  Future<bool> replaceByKey(String key, PlaylistEntry replacement) async {
    replaced.add((key, replacement));
    return true;
  }
}

class _FakeReaderCarouselActions extends ReaderCarouselActionsNotifier {
  final navigated = <String>[];

  @override
  void build() {}

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    navigated.add(targetPdfId);
    return '${RoutePaths.reader}?pdfId=$targetPdfId';
  }
}

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

// -------------------------------------------------------------------- pump

class _Harness {
  _Harness({
    required this.router,
    required this.carousel,
    required this.readerActions,
    required this.audio,
  });

  final GoRouter router;
  final _RecordingActiveEditor carousel;
  final _FakeReaderCarouselActions readerActions;
  final _RecordingAudioSession audio;

  String get location => router.state.uri.toString();
}

Future<_Harness> _pumpSwapSheet(
  WidgetTester tester, {
  required LouvorGroup group,
  String currentMaterialId = 'pdf1',
  String? currentEntryKey = 'pdf1',
  List<PlaylistEntry> initialActiveEntries = const [
    PlaylistEntry(id: 'pdf1', kind: MaterialKind.pdf),
  ],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final carousel = _RecordingActiveEditor(initialEntries: initialActiveEntries);
  final readerActions = _FakeReaderCarouselActions();
  final audio = _RecordingAudioSession();
  final prefs = await SharedPreferences.getInstance();

  // A rota inicial é o leitor: é de lá que o botão de troca de material é
  // acionado, e é lá que o usuário precisa continuar depois de escolher áudio.
  late WidgetRef capturedRef;
  final router = GoRouter(
    initialLocation: RoutePaths.reader,
    routes: [
      GoRoute(
        path: RoutePaths.reader,
        builder: (context, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Column(
                children: [
                  const Text('leitor'),
                  ElevatedButton(
                    onPressed: () => showCarouselSwapMaterialSheet(
                      context: context,
                      ref: ref,
                      group: group,
                      currentMaterialId: currentMaterialId,
                      currentEntryKey: currentEntryKey,
                    ),
                    child: const Text('trocar'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.chords,
        builder: (_, _) => const Scaffold(body: Text('cifra')),
      ),
      GoRoute(
        path: RoutePaths.gestos,
        builder: (_, _) => const Scaffold(body: Text('gestos')),
      ),
      GoRoute(
        path: RoutePaths.audio,
        builder: (_, _) => const Scaffold(body: Text('player')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        activePlaylistEditorProvider.overrideWith(() => carousel),
        louvoresByPdfIdProvider.overrideWithValue({
          'pdf1': _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
        }),
        readerCarouselActionsProvider.overrideWith(() => readerActions),
        playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        audioPlayerSessionProvider.overrideWith(() => audio),
        chordSongProvider.overrideWith(
          (ref, r2Key) async => parseChordPro('{title: X}\n\nA [Bb]noite,\n'),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // O grupo do leitor sai do cache Coldigom, que o data já encheu com as
  // cifras pelo escritor — o sheet só lê (C.3). O teste repete o contrato.
  capturedRef
      .read(coldigomCacheWriterProvider)
      .mergeChords(group.chordMaterials);
  await tester.tap(find.text('trocar'));
  await tester.pumpAndSettle();

  return _Harness(
    router: router,
    carousel: carousel,
    readerActions: readerActions,
    audio: audio,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sheet de troca não mostra os + (o louvor já está na lista)', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
        _pdf(categoria: 'Gestos CIAs', pdfId: 'pdf2'),
      ],
      audioTracks: const [_trackA],
    ).first;

    await _pumpSwapSheet(tester, group: group);

    expect(find.byType(MaterialSheet), findsOneWidget);
    expect(find.byType(CarouselLouvorAddButton), findsNothing);
  });

  testWidgets('outro PDF troca a entrada do carousel e não empilha rota', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores([
      _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
      _pdf(categoria: 'Gestos CIAs', pdfId: 'pdf2'),
    ]).first;

    final harness = await _pumpSwapSheet(tester, group: group);

    await tester.tap(find.text('Gestos CIAs'));
    await tester.pumpAndSettle();

    expect(harness.carousel.replaced, [
      ('pdf1', const PlaylistEntry(id: 'pdf2', kind: MaterialKind.pdf)),
    ]);
    expect(harness.readerActions.navigated, ['pdf2']);
    // `context.replace` no leitor: continua uma rota `/leitor` só, com o novo
    // pdfId — nada de empilhar um segundo leitor.
    expect(harness.location, '${RoutePaths.reader}?pdfId=pdf2');
    expect(find.text('leitor'), findsOneWidget);
  });

  // Cifra e gestos são **o mesmo louvor** com outro material: trocam a
  // entrada no lugar (como o PDF) e substituem a rota do leitor — nunca
  // entram como louvor novo no fim da lista (era o que `addToActive` fazia).
  testWidgets('cifra troca a entrada e substitui a rota, sem anexar', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
      chordMaterials: const [_chord],
    ).first;

    final harness = await _pumpSwapSheet(tester, group: group);

    await tester.tap(find.text('Cifras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cifra I'));
    await tester.pumpAndSettle();

    expect(harness.carousel.replaced, [
      ('pdf1', const PlaylistEntry(id: 'chord1', kind: MaterialKind.chord)),
    ]);
    expect(harness.carousel.added, isEmpty);
    // A rota vem de `navigateToPdfId` (que desvia cifra para `/cifra` em
    // produção) e substitui o leitor em vez de empilhar.
    expect(harness.readerActions.navigated, ['chord1']);
    expect(harness.location, '${RoutePaths.reader}?pdfId=chord1');
  });

  testWidgets('gesto troca a entrada e substitui a rota, sem anexar', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
      gestureMaterials: const [_gesture],
    ).first;

    final harness = await _pumpSwapSheet(tester, group: group);

    await tester.tap(find.text('Gestos'));
    await tester.pumpAndSettle();
    expect(find.text('Gestos I'), findsOneWidget);

    await tester.tap(find.text('Gestos I'));
    await tester.pumpAndSettle();

    expect(harness.carousel.replaced, [
      ('pdf1', const PlaylistEntry(id: 'gesture1', kind: MaterialKind.gesture)),
    ]);
    expect(harness.carousel.added, isEmpty);
    expect(harness.readerActions.navigated, ['gesture1']);
    expect(harness.location, '${RoutePaths.reader}?pdfId=gesture1');
  });

  testWidgets('áudio toca com a fila do grupo e fica no leitor', (
    tester,
  ) async {
    final group = LouvorGroup.fromLouvores(
      [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
      audioTracks: const [_trackA, _trackB],
    ).first;

    final harness = await _pumpSwapSheet(tester, group: group);

    await tester.tap(find.text('Áudio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instrumental'));
    await tester.pumpAndSettle();

    expect(harness.audio.queue?.map((t) => t.audioId).toList(), [
      'audio1',
      'audio2',
    ]);
    expect(harness.audio.startIndex, 1);
    // Ouvir enquanto lê: a rota continua no leitor, sem push de `/audio`.
    expect(harness.location, RoutePaths.reader);
    expect(find.text('leitor'), findsOneWidget);
    expect(find.text('player'), findsNothing);
  });

  testWidgets(
    'entrada focada já é áudio: escolher outra voz troca a entrada por chave '
    '(spec §3.2)',
    (tester) async {
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        audioTracks: [_voiceTrackA, _voiceTrackB],
      ).first;

      // A lista ativa já tem a voz 1 (não `pdf1`) — o `|◀ ▶|` de dentro do
      // grupo agora troca a entrada, não só toca por cima dela.
      final harness = await _pumpSwapSheet(
        tester,
        group: group,
        currentMaterialId: _voiceAudioId1,
        currentEntryKey: _voiceAudioId1,
        initialActiveEntries: [
          PlaylistEntry(id: _voiceAudioId1, kind: MaterialKind.audio),
        ],
      );

      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instrumental'));
      await tester.pumpAndSettle();

      expect(harness.carousel.replaced, [
        (
          _voiceAudioId1,
          PlaylistEntry(id: _voiceAudioId2, kind: MaterialKind.audio),
        ),
      ]);
      expect(harness.audio.queue?.map((t) => t.audioId).toList(), [
        _voiceAudioId1,
        _voiceAudioId2,
      ]);
      expect(harness.audio.startIndex, 1);
    },
  );

  testWidgets(
    'entrada focada é áudio: escolher a MESMA voz não chama replaceByKey',
    (tester) async {
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        audioTracks: [_voiceTrackA, _voiceTrackB],
      ).first;

      final harness = await _pumpSwapSheet(
        tester,
        group: group,
        currentMaterialId: _voiceAudioId1,
        currentEntryKey: _voiceAudioId1,
        initialActiveEntries: [
          PlaylistEntry(id: _voiceAudioId1, kind: MaterialKind.audio),
        ],
      );

      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playback'));
      await tester.pumpAndSettle();

      expect(harness.carousel.replaced, isEmpty);
      expect(harness.audio.queue?.map((t) => t.audioId).toList(), [
        _voiceAudioId1,
        _voiceAudioId2,
      ]);
      expect(harness.audio.startIndex, 0);
    },
  );
}
