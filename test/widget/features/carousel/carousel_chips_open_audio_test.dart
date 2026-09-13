// test/widget/features/carousel/carousel_chips_open_audio_test.dart
//
// «Abrir» numa entrada de áudio focada na barra tem que tocar a faixa (fila
// híbrida) em vez de tentar abrir o leitor de PDF (spec 2026-09-12, §3.2).
//
// Harness: mesmo padrão do teste de PDF em `carousel_chips_test.dart`
// ("toque no chip abre leitor com pdf focado") — `Scaffold(body:
// CarouselChips())` com rotas irmãs simples, mais leve que o shell inteiro e
// já provado para exercitar `context.push` a partir da barra. `_FakeAudioSession`
// e as fixtures `track`/`audioEntry` vêm de
// `test/widget/features/app_shell/shell_scaffold_test.dart`.
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_active_editor.dart';

/// Sessão de mentira: grava a fila e o índice recebidos por [playQueue] —
/// é isso que prova que «Abrir» tocou a faixa (e não só tentou navegar).
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  _FakeAudioSession(this._state);

  final AudioPlayerSessionState _state;

  List<AudioTrack>? playedQueue;
  int? playedStartIndex;

  @override
  AudioPlayerSessionState build() => _state;

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    playedQueue = tracks;
    playedStartIndex = startIndex;
  }
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
  const audioEntry = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('«Abrir» numa entrada de áudio toca a faixa e abre /audio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = _FakeAudioSession(const AudioPlayerSessionState());
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
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
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor([audioEntry]),
          ),
          audioPlayerSessionProvider.overrideWith(() => session),
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

    // Cache de faixas: sem isso `catalogMaterialLookupProvider` não resolve
    // `item.materialId` ('aud-1') numa `AudioTrack` e `_openAudio` cairia no
    // caminho de erro (snackbar) em vez de tocar.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CarouselChips)),
    );
    container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
      track,
    ]);
    await tester.pump();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(session.playedQueue, isNotNull);
    expect(
      session.playedQueue![session.playedStartIndex ?? 0].audioId,
      track.audioId,
    );
    // Rota /audio empurrada (spec §3.2: abrir áudio navega + toca) — a rota
    // de mentira devolve o `audioId` da query, que é `track.audioId`.
    expect(find.text(track.audioId), findsOneWidget);
  });
}
