import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_audio_face_bar.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;

  @override
  List<CarouselItem> build() => initial;
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

  const pdfItem = CarouselItem(
    pdfId: 'pdf-1',
    sortOrder: 0,
    numero: '047',
    nome: 'Shekinah',
    categoria: 'Partitura',
    classificacao: 'Coro',
  );

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
  final groupPdfItem = CarouselItem(
    pdfId: groupPdfId,
    sortOrder: 0,
    numero: '047',
    nome: 'Shekinah',
    categoria: 'Partitura',
    classificacao: 'Coro',
    source: LouvorDataSource.coldigom,
  );

  Widget buildSubject({
    required SharedPreferences prefs,
    required List<CarouselItem> items,
    Map<String, Louvor> coldigomCache = const {},
    _QueuedAudioSession? session,
    double? width,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
        carouselLouvoresProvider.overrideWith(
          () => _FakeCarouselNotifier(items),
        ),
        coldigomLouvoresCacheProvider.overrideWith(
          () => _FakeColdigomLouvoresCache(coldigomCache),
        ),
        audioPlayerSessionProvider.overrideWith(
          () => session ?? _QueuedAudioSession(track),
        ),
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
    await tester.pumpWidget(buildSubject(prefs: prefs, items: const [pdfItem]));
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
        items: [groupPdfItem],
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
        items: [groupPdfItem],
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
      buildSubject(prefs: prefs, items: const [pdfItem], session: session),
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
        items: const [pdfItem],
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
    await tester.pumpWidget(buildSubject(prefs: prefs, items: const [pdfItem]));
    await tester.pumpAndSettle();

    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Não foi possível reproduzir este áudio.'), findsNothing);
  });

  testWidgets('linha de erro não aumenta a barra nem o estouro em 360 px', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      buildSubject(prefs: prefs, items: const [pdfItem], width: 360),
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
        items: const [pdfItem],
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

  testWidgets('oculta partitura quando o louvor tocando não tem material', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(buildSubject(prefs: prefs, items: const [pdfItem]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(
      find.byTooltip('Seguir o áudio'),
      findsOneWidget,
      reason: 'o toggle é preferência global, não depende do material da faixa',
    );
  });
}
