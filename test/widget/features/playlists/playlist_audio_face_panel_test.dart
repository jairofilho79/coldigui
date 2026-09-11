import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_audio_face_panel.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _trackA = AudioTrack(
  audioId: 'aud-a',
  r2Key: 'assets/praises/a.mp3',
  nome: 'Primeira',
  numero: '001',
  groupId: 'g1',
  categoria: 'Áudio',
  classificacao: 'Coro',
  source: LouvorDataSource.coldigom,
);

const _trackB = AudioTrack(
  audioId: 'aud-b',
  r2Key: 'assets/praises/b.mp3',
  nome: 'Segunda',
  numero: '002',
  groupId: 'g2',
  categoria: 'Áudio',
  classificacao: 'Coro',
  source: LouvorDataSource.coldigom,
);

CarouselItem _audioItem(AudioTrack track, int index) => CarouselItem(
  materialId: track.audioId,
  kind: MaterialKind.audio,
  index: index,
  key: track.audioId,
  numero: track.numero,
  nome: track.nome,
  categoria: track.categoria,
  classificacao: track.classificacao,
);

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];
}

/// Registra as remoções por posição pedidas ao notifier.
class _RemovalRecordingPlaylistsNotifier extends _FakePlaylistsNotifier {
  final removed = <(String, int)>[];

  @override
  Future<void> removeEntryAt({
    required String playlistId,
    required int index,
  }) async {
    removed.add((playlistId, index));
  }
}

class _FakeAudioCache extends ColdigomAudioTracksCacheNotifier {
  _FakeAudioCache(this.initial);

  final Map<String, AudioTrack> initial;

  @override
  Map<String, AudioTrack> build() => initial;
}

/// Sessão com a fila já carregada e a posição em [index].
class _SessionAt extends AudioPlayerSessionNotifier {
  _SessionAt(this.tracks, this.index);

  final List<AudioTrack> tracks;
  final int index;
  List<AudioTrack>? played;
  int? playedIndex;

  @override
  AudioPlayerSessionState build() =>
      AudioPlayerSessionState(queue: tracks, currentIndex: index);

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    played = tracks;
    playedIndex = startIndex;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final playlist = SavedPlaylist.fromLegacyLists(
    playlistId: 'p1',
    nome: 'Ensaio',
    audioIds: const ['aud-a', 'aud-b'],
    createdAt: DateTime(2026, 9, 4),
  );

  Future<void> pump(
    WidgetTester tester, {
    required AudioPlayerSessionNotifier session,
    SavedPlaylist? list,
    List<CarouselItem>? activeFace,
    PlaylistsNotifier Function()? playlists,
  }) async {
    final shown = list ?? playlist;
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isarAvailableProvider.overrideWithValue(false),
          playlistsProvider.overrideWith(
            playlists ?? _FakePlaylistsNotifier.new,
          ),
          audioPlayerSessionProvider.overrideWith(() => session),
          coldigomAudioTracksCacheProvider.overrideWith(
            () => _FakeAudioCache(const {'aud-a': _trackA, 'aud-b': _trackB}),
          ),
          catalogMaterialLookupProvider.overrideWithValue(
            const CatalogMaterialLookup(
              audioTracksById: {'aud-a': _trackA, 'aud-b': _trackB},
            ),
          ),
          audioFaceItemsProvider.overrideWithValue(
            activeFace ?? [_audioItem(_trackA, 0), _audioItem(_trackB, 1)],
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: SingleChildScrollView(
                    child: PlaylistAudioFacePanel(playlist: shown),
                  ),
                ),
              ),
              GoRoute(
                path: RoutePaths.audio,
                builder: (_, _) => const Scaffold(body: Text('player')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hasPrevious false na primeira faixa', (tester) async {
    await pump(tester, session: _SessionAt(const [_trackA, _trackB], 0));

    final controls = tester.widget<AudioTransportControls>(
      find.byType(AudioTransportControls),
    );
    expect(controls.hasPrevious, isFalse);
    expect(controls.hasNext, isTrue);
  });

  testWidgets('hasPrevious true na segunda faixa, hasNext false no fim', (
    tester,
  ) async {
    await pump(tester, session: _SessionAt(const [_trackA, _trackB], 1));

    final controls = tester.widget<AudioTransportControls>(
      find.byType(AudioTransportControls),
    );
    expect(controls.hasPrevious, isTrue);
    expect(controls.hasNext, isFalse);
  });

  testWidgets('sem sessão nesta lista os controles começam do início', (
    tester,
  ) async {
    await pump(tester, session: _SessionAt(const [], 0));

    final controls = tester.widget<AudioTransportControls>(
      find.byType(AudioTransportControls),
    );
    expect(controls.hasPrevious, isFalse);
    expect(controls.hasNext, isTrue);
  });

  // A lista mostrada tem só a segunda faixa; a lista **ativa** tem as duas.
  // Tocar daqui emenda na reunião em vez de parar na faixa do painel.
  testWidgets('tocar usa a fila da lista ativa (D4)', (tester) async {
    final session = _SessionAt(const [], 0);
    await pump(
      tester,
      session: session,
      list: SavedPlaylist.fromLegacyLists(
        playlistId: 'p2',
        nome: 'Só a segunda',
        audioIds: const ['aud-b'],
        createdAt: DateTime(2026, 9, 4),
      ),
    );

    await tester.tap(find.text('Segunda'));
    await tester.pump();

    expect(session.played?.map((t) => t.audioId).toList(), ['aud-a', 'aud-b']);
  });

  // A lista mostrada é a ativa e repete um áudio: tocar a segunda ocorrência
  // tem que começar nela (índice 2), não na primeira.
  testWidgets('ocorrência repetida toca pelo índice, não pelo id', (
    tester,
  ) async {
    final session = _SessionAt(const [], 0);
    await pump(
      tester,
      session: session,
      list: SavedPlaylist.fromLegacyLists(
        playlistId: 'p3',
        nome: 'Com repetição',
        audioIds: const ['aud-a', 'aud-b', 'aud-a'],
        createdAt: DateTime(2026, 9, 4),
      ),
      activeFace: [
        _audioItem(_trackA, 0),
        _audioItem(_trackB, 1),
        _audioItem(_trackA, 2),
      ],
    );

    await tester.tap(find.text('Primeira').last);
    await tester.pump();

    expect(session.played?.map((t) => t.audioId).toList(), [
      'aud-a',
      'aud-b',
      'aud-a',
    ]);
    expect(session.playedIndex, 2);
  });

  // B.1: o «×» de uma linha remove **aquela** ocorrência, pela posição na
  // ordem única (as partituras contam na posição), nunca todas as do id.
  testWidgets('«×» remove a ocorrência pela posição na ordem única (#4)', (
    tester,
  ) async {
    final notifier = _RemovalRecordingPlaylistsNotifier();
    await pump(
      tester,
      session: _SessionAt(const [], 0),
      list: SavedPlaylist.fromLegacyLists(
        playlistId: 'p3',
        nome: 'Com repetição',
        items: const ['pdf-x', 'aud-a', 'aud-b', 'aud-a'],
        audioIds: const ['aud-a', 'aud-b'],
        createdAt: DateTime(2026, 9, 4),
      ),
      playlists: () => notifier,
    );

    // Terceira linha de áudio = segunda ocorrência de aud-a = entries[3].
    await tester.tap(find.byIcon(Icons.close).at(2));
    await tester.pump();

    expect(notifier.removed, [('p3', 3)]);
  });
}
