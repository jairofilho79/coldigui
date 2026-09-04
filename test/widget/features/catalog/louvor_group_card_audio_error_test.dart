import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<bool> addAudioToActivePlaylist(String audioId) async => true;
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

/// Sessão de áudio que sempre falha ao tocar — `playQueue` é o único `await`
/// de `openAudioInPlayer`, então o erro chega ao `catch` do card.
class _FailingAudioSession extends AudioPlayerSessionNotifier {
  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    throw StateError('detalhe_interno_feio');
  }
}

void main() {
  const track = AudioTrack(
    audioId: 'a1',
    r2Key: 'assets/praises/001.mp3',
    nome: 'Aleluia',
    numero: '001',
    groupId: '001:aleluia',
    categoria: 'Áudio',
    classificacao: 'Coro',
    source: LouvorDataSource.coldigom,
  );

  LouvorGroup audioOnlyGroup() => LouvorGroup(
    groupId: '001:aleluia',
    numero: '001',
    nome: 'Aleluia',
    sections: const [],
    audioTracks: const [track],
  );

  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'falha ao abrir áudio mostra mensagem traduzida, não o toString',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
            carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
            audioPlayerSessionProvider.overrideWith(_FailingAudioSession.new),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      Scaffold(body: LouvorGroupCard(group: audioOnlyGroup())),
                ),
                GoRoute(
                  path: '/audio',
                  builder: (_, _) => const Scaffold(body: Text('player')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Aleluia'));
      await tester.pumpAndSettle();

      expect(find.text(pt.errorGeneric), findsOneWidget);
      expect(find.textContaining('detalhe_interno_feio'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);
    },
  );
}
