import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/presentation/shell_scaffold.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/stage_wakelock.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/mini_player_bar.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sessão de mentira: só o que o shell precisa (`currentTrack`, fila).
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  _FakeAudioSession(this._state);

  final AudioPlayerSessionState _state;

  @override
  AudioPlayerSessionState build() => _state;
}

/// Lista ativa dirigida pelo teste — a face de áudio/PDF sai daqui.
class _FakeActiveEditor extends ActivePlaylistEditor {
  _FakeActiveEditor(this.initial);

  final List<PlaylistEntry> initial;

  @override
  List<PlaylistEntry>? build() => initial;
}

/// Sem sync real: nem auth, nem conectividade.
class _FixedPlaylistSync extends PlaylistSyncNotifier {
  @override
  PlaylistSyncState build() => const PlaylistSyncState();
}

/// Deslogado, sem tocar no SDK do Google.
class _FixedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

/// Fullscreen sempre ligado — não chama `SystemChrome`.
class _FixedFullscreenNotifier extends ReaderFullscreenNotifier {
  @override
  bool build() => true;
}

/// Registra em vez de falar com o plugin de wakelock.
class _NoopWakelock implements StageWakelockController {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

void main() {
  const track = AudioTrack(
    audioId: 'aud-1',
    r2Key: 'assets/praises/p1/a.mp3',
    nome: 'Louvor',
    numero: '12',
    groupId: 'p1',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );
  const pdfEntry = PlaylistEntry(id: 'pdf-1', kind: MaterialKind.pdf);
  const audioEntry = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);

  late Isar isar;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('shell_scaffold_test_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: dir.path);
  });

  tearDownAll(() {
    isar.close();
  });

  GoRouter buildRouter({String initialLocation = RoutePaths.home}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ShellScaffold(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  builder: (_, _) => const Scaffold(body: Text('Home')),
                  routes: [
                    GoRoute(
                      path: 'leitor',
                      builder: (_, _) => const Scaffold(body: Text('Leitor')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    required List<Override> overrides,
    String initialLocation = RoutePaths.home,
  }) async {
    final router = buildRouter(initialLocation: initialLocation);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          isarInitializerProvider.overrideWith((ref) async => isar),
          playlistSyncProvider.overrideWith(_FixedPlaylistSync.new),
          authStateProvider.overrideWith(_FixedAuthNotifier.new),
          stageWakelockProvider.overrideWithValue(_NoopWakelock()),
          ...overrides,
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
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('com faixa e face PDF, o mini-player aparece no shell', (
    tester,
  ) async {
    await pumpShell(
      tester,
      overrides: [
        activePlaylistEditorProvider.overrideWith(
          () => _FakeActiveEditor([pdfEntry]),
        ),
        audioPlayerSessionProvider.overrideWith(
          () =>
              _FakeAudioSession(const AudioPlayerSessionState(queue: [track])),
        ),
      ],
    );

    expect(find.byType(MiniPlayerBar), findsOneWidget);
    final bar = tester.widget<MiniPlayerBar>(find.byType(MiniPlayerBar));
    expect(bar.overlay, isFalse);
  });

  testWidgets(
    'com a face de áudio visível, o mini-player some (ela já mostra os controles)',
    (tester) async {
      await pumpShell(
        tester,
        overrides: [
          activePlaylistEditorProvider.overrideWith(
            () => _FakeActiveEditor([audioEntry]),
          ),
          playlistMediaFaceProvider.overrideWith(
            () => _FixedFace(PlaylistMediaFace.audio),
          ),
          audioPlayerSessionProvider.overrideWith(
            () => _FakeAudioSession(
              const AudioPlayerSessionState(queue: [track]),
            ),
          ),
        ],
      );

      expect(find.byType(MiniPlayerBar), findsNothing);
    },
  );

  testWidgets(
    'em fullscreen, o mini-player aparece como overlay sobre o navigationShell',
    (tester) async {
      await pumpShell(
        tester,
        initialLocation: '${RoutePaths.home}leitor',
        overrides: [
          readerFullscreenProvider.overrideWith(_FixedFullscreenNotifier.new),
          activePlaylistEditorProvider.overrideWith(
            () => _FakeActiveEditor([pdfEntry]),
          ),
          audioPlayerSessionProvider.overrideWith(
            () => _FakeAudioSession(
              const AudioPlayerSessionState(queue: [track]),
            ),
          ),
        ],
      );

      expect(find.byType(MiniPlayerBar), findsOneWidget);
      final bar = tester.widget<MiniPlayerBar>(find.byType(MiniPlayerBar));
      expect(bar.overlay, isTrue);
      expect(find.byType(Stack), findsWidgets);
    },
  );
}

/// Face fixa — sem depender de SharedPreferences.
class _FixedFace extends PlaylistMediaFaceNotifier {
  _FixedFace(this._face);

  final PlaylistMediaFace _face;

  @override
  PlaylistMediaFace build() => _face;
}
