import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_audio_face_bar.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];
}

/// Lista ativa fixa — a face de partituras da barra sai daqui (B.2).
class _FakeActiveEditor extends ActivePlaylistEditor {
  _FakeActiveEditor(this.initial);

  final List<PlaylistEntry> initial;

  @override
  List<PlaylistEntry>? build() => initial;
}

class _QueuedAudioSession extends AudioPlayerSessionNotifier {
  _QueuedAudioSession(this.track, {this.errorMessage, this.emptyQueue = false});

  final AudioTrack track;
  final String? errorMessage;
  final bool emptyQueue;
  int retryCalls = 0;

  @override
  AudioPlayerSessionState build() {
    return AudioPlayerSessionState(
      queue: emptyQueue ? const [] : [track],
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> retryCurrent() async {
    retryCalls++;
    state = state.copyWith(clearError: true);
  }
}

/// Registra `playQueue` em vez de tocar — as setas de louvor (D5) não podem
/// encostar num `AudioPlayer` real.
class _RecordingAudioSession extends AudioPlayerSessionNotifier {
  _RecordingAudioSession(this._state);

  final AudioPlayerSessionState _state;
  final playedQueues = <List<AudioTrack>>[];

  @override
  AudioPlayerSessionState build() => _state;

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    playedQueues.add(tracks);
  }
}

/// Quantos pixels a barra estourou (0 quando não houve `RenderFlex` overflow).
double _overflowPixels(Object? exception) {
  if (exception == null) return 0;
  final match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch(exception.toString());
  if (match == null) throw exception;
  return double.parse(match.group(1)!);
}

class _FakeColdigomLouvoresCache extends ColdigomLouvoresCacheNotifier {
  _FakeColdigomLouvoresCache(this.initial);

  final Map<String, Louvor> initial;

  @override
  Map<String, Louvor> build() => initial;
}

class _FakeColdigomAudioTracksCache extends ColdigomAudioTracksCacheNotifier {
  _FakeColdigomAudioTracksCache(this.initial);

  final Map<String, AudioTrack> initial;

  @override
  Map<String, AudioTrack> build() => initial;
}

void main() {
  const track = AudioTrack(
    audioId: 'aud-1',
    r2Key: 'assets/praises/p1/a.mp3',
    nome: 'Shekinah',
    numero: '047',
    groupId: 'p1',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );

  const pdfEntry = PlaylistEntry(id: 'pdf-1', kind: MaterialKind.pdf);

  final groupPdfId = encodePdfId('assets/praises/p1/partitura.pdf');
  final groupLouvor = Louvor.fromManifest(
    nome: 'Shekinah',
    numero: '047',
    categoria: 'Partitura',
    classificacao: 'Coro',
    pdf: 'partitura.pdf',
    pdfId: groupPdfId,
    groupId: 'p1',
    source: LouvorDataSource.coldigom,
  );
  final groupPdfEntry = PlaylistEntry(id: groupPdfId, kind: MaterialKind.pdf);

  Widget buildSubject({
    required SharedPreferences prefs,
    required List<PlaylistEntry> entries,
    Map<String, Louvor> coldigomCache = const {},
    Map<String, AudioTrack> audioCache = const {},
    AudioPlayerSessionNotifier? session,
    double? width,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        activePlaylistEditorProvider.overrideWith(
          () => _FakeActiveEditor(entries),
        ),
        coldigomLouvoresCacheProvider.overrideWith(
          () => _FakeColdigomLouvoresCache(coldigomCache),
        ),
        coldigomAudioTracksCacheProvider.overrideWith(
          () => _FakeColdigomAudioTracksCache(audioCache),
        ),
        audioPlayerSessionProvider.overrideWith(
          () => session ?? _QueuedAudioSession(track),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: SizedBox(width: width, child: const CarouselAudioFaceBar()),
        ),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sem X; com abrir player e olho quando há PDF na seleção', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildSubject(prefs: prefs, entries: const [pdfEntry]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.open_in_full), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('exibe partitura e seguir quando o louvor tocando tem material', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildSubject(
        prefs: prefs,
        entries: [groupPdfEntry],
        coldigomCache: {groupPdfId: groupLouvor},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byTooltip('Partitura/cifra deste louvor'), findsOneWidget);
    expect(find.byTooltip('Seguir o áudio'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('toggle de seguir o áudio inverte o ícone', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildSubject(
        prefs: prefs,
        entries: [groupPdfEntry],
        coldigomCache: {groupPdfId: groupLouvor},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Seguir o áudio'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.link_off), findsOneWidget);
    expect(prefs.getBool(kAudioFollowReaderPrefsKey), isFalse);
  });

  testWidgets('erro do player mostra a mensagem e "Tentar novamente"', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final session = _QueuedAudioSession(track, errorMessage: '(1) decode');
    await tester.pumpWidget(
      buildSubject(prefs: prefs, entries: const [pdfEntry], session: session),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível reproduzir este áudio.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(session.retryCalls, 1);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('erro sem faixa não oferece retry (seria no-op)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildSubject(
        prefs: prefs,
        entries: const [pdfEntry],
        session: _QueuedAudioSession(
          track,
          errorMessage: '(1) decode',
          emptyQueue: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Não foi possível reproduzir este áudio.'), findsNothing);
  });

  testWidgets('sem erro não aparece "Tentar novamente"', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildSubject(prefs: prefs, entries: const [pdfEntry]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Não foi possível reproduzir este áudio.'), findsNothing);
  });

  testWidgets('linha de erro não aumenta a barra nem o estouro em 360 px', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildSubject(prefs: prefs, entries: const [pdfEntry], width: 360),
    );
    await tester.pumpAndSettle();
    final baselineHeight = tester
        .getSize(find.byType(CarouselAudioFaceBar))
        .height;
    // A fileira de ícones já estoura em 360 px desde a onda 1 (revisão da face
    // de áudio); o que este teste protege é o erro **não piorar** isso.
    final baselineOverflow = _overflowPixels(tester.takeException());

    // Árvore nova: o `RenderFlex` só relata o estouro uma vez por instância.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      buildSubject(
        prefs: prefs,
        entries: const [pdfEntry],
        session: _QueuedAudioSession(track, errorMessage: '(1) decode'),
        width: 360,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(CarouselAudioFaceBar)).height,
      lessThanOrEqualTo(baselineHeight),
    );
    expect(_overflowPixels(tester.takeException()), baselineOverflow);
  });

  group('sem sessão, a faixa vem da lista ativa', () {
    const segunda = AudioTrack(
      audioId: 'aud-2',
      r2Key: 'assets/praises/p2/a.mp3',
      nome: 'Vem, Espírito',
      numero: '101',
      groupId: 'p2',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );

    testWidgets('mostra a primeira entrada de áudio resolvível no cache', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          // A primeira entrada de áudio ainda não foi aquecida no cache: ela é
          // pulada em vez de apagar a barra.
          entries: const [
            PlaylistEntry(id: 'aud-frio', kind: MaterialKind.audio),
            PlaylistEntry(id: 'aud-2', kind: MaterialKind.audio),
          ],
          audioCache: const {'aud-2': segunda},
          session: _QueuedAudioSession(track, emptyQueue: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vem, Espírito'), findsOneWidget);
      expect(find.text('Esta lista não tem áudios.'), findsNothing);
    });

    testWidgets('sem entrada de áudio resolvível a barra fica vazia', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          entries: const [
            PlaylistEntry(id: 'aud-frio', kind: MaterialKind.audio),
          ],
          session: _QueuedAudioSession(track, emptyQueue: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vem, Espírito'), findsNothing);
      expect(find.text('Esta lista não tem áudios.'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsNothing);
    });
  });

  testWidgets('sem faixa, o layers cai na ocorrência focada (id e chave)', (
    tester,
  ) async {
    // O mesmo PDF duas vezes na face: só a chave distingue as ocorrências, e o
    // botão de troca tem que receber a da entrada focada — `pdf-1#1`.
    SharedPreferences.setMockInitialValues({
      'carousel_focused_pdf_id': 'pdf-1#1',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildSubject(
        prefs: prefs,
        entries: const [pdfEntry, pdfEntry],
        session: _QueuedAudioSession(track, emptyQueue: true),
      ),
    );
    await tester.pumpAndSettle();

    final swap = tester.widget<CarouselSwapMaterialButton>(
      find.byType(CarouselSwapMaterialButton),
    );
    expect(swap.materialId, 'pdf-1');
    expect(swap.entryKey, 'pdf-1#1');
    expect(swap.audioId, isNull);
  });

  testWidgets('oculta partitura quando o louvor tocando não tem material', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildSubject(prefs: prefs, entries: const [pdfEntry]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(
      find.byTooltip('Seguir o áudio'),
      findsOneWidget,
      reason: 'o toggle é preferência global, não depende do material da faixa',
    );
  });

  group('setas de louvor (D5)', () {
    // Posição atual = a faixa TOCANDO (sessão), nunca o foco da face PDF
    // (spec A.1 emendada — fix round 1): a face de áudio não chama
    // `carouselFocusedIndexProvider.focusKey`.
    const trackA = AudioTrack(
      audioId: 'aud-a',
      r2Key: 'assets/praises/a/a.mp3',
      nome: 'Louvor A',
      numero: '001',
      groupId: 'ga',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );
    const trackB = AudioTrack(
      audioId: 'aud-b',
      r2Key: 'assets/praises/b/a.mp3',
      nome: 'Louvor B',
      numero: '002',
      groupId: 'gb',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );
    const trackC = AudioTrack(
      audioId: 'aud-c',
      r2Key: 'assets/praises/c/a.mp3',
      nome: 'Louvor C',
      numero: '003',
      groupId: 'gc',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );
    const entryA = PlaylistEntry(id: 'aud-a', kind: MaterialKind.audio);
    const entryB = PlaylistEntry(id: 'aud-b', kind: MaterialKind.audio);
    const entryC = PlaylistEntry(id: 'aud-c', kind: MaterialKind.audio);
    final audioCache = {
      trackA.audioId: trackA,
      trackB.audioId: trackB,
      trackC.audioId: trackC,
    };

    testWidgets(
      'tocando a segunda: anterior toca a primeira, próximo toca a terceira',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final session = _RecordingAudioSession(
          const AudioPlayerSessionState(queue: [trackB]),
        );

        await tester.pumpWidget(
          buildSubject(
            prefs: prefs,
            entries: const [entryA, entryB, entryC],
            audioCache: audioCache,
            session: session,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Louvor anterior'));
        await tester.pumpAndSettle();
        expect(session.playedQueues, hasLength(1));
        expect(
          session.playedQueues.single.any((t) => t.audioId == trackA.audioId),
          isTrue,
        );

        await tester.tap(find.byTooltip('Próximo louvor'));
        await tester.pumpAndSettle();
        expect(session.playedQueues, hasLength(2));
        expect(
          session.playedQueues.last.any((t) => t.audioId == trackC.audioId),
          isTrue,
        );
      },
    );

    testWidgets('tocando a última: próximo desabilitado, anterior habilitado', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          entries: const [entryA, entryB, entryC],
          audioCache: audioCache,
          session: _RecordingAudioSession(
            const AudioPlayerSessionState(queue: [trackC]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final previous = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(previous.onPressed, isNotNull);
      expect(next.onPressed, isNull);
    });

    testWidgets('nada tocando: próximo toca a segunda entrada (índice 0)', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final session = _RecordingAudioSession(
        const AudioPlayerSessionState(queue: [], currentIndex: 0),
      );

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          entries: const [entryA, entryB, entryC],
          audioCache: audioCache,
          session: session,
        ),
      );
      await tester.pumpAndSettle();

      final previous = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(previous.onPressed, isNull);

      await tester.tap(find.byTooltip('Próximo louvor'));
      await tester.pumpAndSettle();

      expect(session.playedQueues, hasLength(1));
      expect(
        session.playedQueues.single.any((t) => t.audioId == trackB.audioId),
        isTrue,
      );
    });

    testWidgets(
      'faixa tocando fora da lista: cai no índice 0 (próximo habilitado)',
      (tester) async {
        // A sessão toca um áudio que não é nenhuma das três entradas da face
        // — o foco da face PDF (que nunca existiu para chaves de áudio) não
        // entra na conta: a posição cai no início da própria face de áudio.
        const trackD = AudioTrack(
          audioId: 'aud-d',
          r2Key: 'assets/praises/d/a.mp3',
          nome: 'Louvor D',
          numero: '004',
          groupId: 'gd',
          categoria: 'Áudio',
          classificacao: 'Coro',
        );
        final prefs = await SharedPreferences.getInstance();
        final session = _RecordingAudioSession(
          const AudioPlayerSessionState(queue: [trackD]),
        );

        await tester.pumpWidget(
          buildSubject(
            prefs: prefs,
            entries: const [entryA, entryB, entryC],
            audioCache: audioCache,
            session: session,
          ),
        );
        await tester.pumpAndSettle();

        final previous = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_left),
        );
        expect(previous.onPressed, isNull);

        await tester.tap(find.byTooltip('Próximo louvor'));
        await tester.pumpAndSettle();

        expect(session.playedQueues, hasLength(1));
        expect(
          session.playedQueues.single.any((t) => t.audioId == trackB.audioId),
          isTrue,
        );
      },
    );
  });
}
