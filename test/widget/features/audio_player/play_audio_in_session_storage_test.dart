// test/widget/features/audio_player/play_audio_in_session_storage_test.dart
//
// A1/A8: tocar nunca depende do storage — o áudio vem da rede. A entrada na
// lista ativa passa pelo editor, que devolve `storageUnavailable` quando o
// Isar de fato não veio; enquanto ele só está **abrindo** (web fria) ninguém
// pré-julga no toque. Quem tem `BuildContext` (`openAudioInPlayer`) mostra a
// snackbar de storage a partir do resultado.
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _track = AudioTrack(
  audioId: 'audio1',
  r2Key: 'audio-key',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Playback',
  classificacao: 'Básico',
  author: 'CIAS',
  source: LouvorDataSource.coldigom,
);

class _FakeSession extends AudioPlayerSessionNotifier {
  final List<List<AudioTrack>> played = [];

  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    played.add(tracks);
  }
}

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];
}

/// Editor com resultado fixo — registra o que o player mandou adicionar.
class _StubActiveEditor extends ActivePlaylistEditor {
  _StubActiveEditor(this.outcome);

  final AddToActiveOutcome outcome;
  final List<({String id, MaterialKind? kind})> added = [];

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    added.add((id: materialId, kind: kind));
    return outcome;
  }
}

void main() {
  late SharedPreferences prefs;
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> overrides({
    required _FakeSession session,
    required _StubActiveEditor editor,
  }) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // Web fria: o app já está na tela e o Isar ainda não resolveu.
    isarStatusProvider.overrideWithValue(IsarStatus.opening),
    audioPlayerSessionProvider.overrideWith(() => session),
    activePlaylistEditorProvider.overrideWith(() => editor),
    playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
  ];

  group('playAudioInSession', () {
    Future<AddToActiveOutcome> pumpAndPlay(
      WidgetTester tester, {
      required _FakeSession session,
      required _StubActiveEditor editor,
    }) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(session: session, editor: editor),
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final outcome = await playAudioInSession(ref: capturedRef, track: _track);
      await tester.pump();
      return outcome;
    }

    testWidgets('sem storage toca mesmo assim e devolve storageUnavailable', (
      tester,
    ) async {
      final session = _FakeSession();
      final editor = _StubActiveEditor(AddToActiveOutcome.storageUnavailable);

      final outcome = await pumpAndPlay(
        tester,
        session: session,
        editor: editor,
      );

      expect(session.played, hasLength(1));
      expect(session.played.single.single.audioId, 'audio1');
      expect(outcome, AddToActiveOutcome.storageUnavailable);
    });

    testWidgets('com o Isar abrindo, entra pelo editor com kind de áudio', (
      tester,
    ) async {
      final session = _FakeSession();
      final editor = _StubActiveEditor(AddToActiveOutcome.added);

      final outcome = await pumpAndPlay(
        tester,
        session: session,
        editor: editor,
      );

      expect(session.played, hasLength(1));
      expect(editor.added, [(id: 'audio1', kind: MaterialKind.audio)]);
      expect(outcome, AddToActiveOutcome.added);
    });
  });

  group('openAudioInPlayer', () {
    Future<void> pumpAndOpen(
      WidgetTester tester, {
      required _FakeSession session,
      required _StubActiveEditor editor,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(session: session, editor: editor),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => Scaffold(
                    body: Consumer(
                      builder: (context, ref, _) => ElevatedButton(
                        onPressed: () => openAudioInPlayer(
                          ref: ref,
                          context: context,
                          track: _track,
                        ),
                        child: const Text('tocar'),
                      ),
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
      await tester.tap(find.text('tocar'));
      await tester.pumpAndSettle();
    }

    testWidgets('com o Isar abrindo, toca, navega e não mostra snackbar', (
      tester,
    ) async {
      final session = _FakeSession();
      final editor = _StubActiveEditor(AddToActiveOutcome.added);

      await pumpAndOpen(tester, session: session, editor: editor);

      expect(session.played, hasLength(1));
      expect(find.text('player'), findsOneWidget);
      expect(find.text(pt.playlistStorageUnavailable), findsNothing);
    });

    testWidgets('storageUnavailable do editor mostra a snackbar de storage', (
      tester,
    ) async {
      final session = _FakeSession();
      final editor = _StubActiveEditor(AddToActiveOutcome.storageUnavailable);

      await pumpAndOpen(tester, session: session, editor: editor);

      // Tocar continua valendo (o áudio vem da rede); só a lista não gravou.
      expect(session.played, hasLength(1));
      expect(find.text('player'), findsOneWidget);
      expect(find.text(pt.playlistStorageUnavailable), findsOneWidget);
    });
  });
}
