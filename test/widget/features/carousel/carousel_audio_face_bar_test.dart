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
  _QueuedAudioSession(this.track);

  final AudioTrack track;

  @override
  AudioPlayerSessionState build() {
    return AudioPlayerSessionState(queue: [track]);
  }
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
          () => _QueuedAudioSession(track),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: CarouselAudioFaceBar()),
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

  testWidgets('oculta partitura quando o louvor tocando não tem material', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(buildSubject(prefs: prefs, items: const [pdfItem]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_book), findsNothing);
    expect(find.byTooltip('Seguir o áudio'), findsNothing);
  });
}
