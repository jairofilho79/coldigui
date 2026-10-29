// test/widget/features/carousel/carousel_chips_swap_material_test.dart
//
// Crítico #1: «Material» tem que aparecer para uma entrada de áudio focada na
// barra do shell. `_buildNavigatorBar` mandava o id da faixa focada como
// `materialId:` (nunca `audioId:`) para `CarouselSwapMaterialButton`, e
// `findSwapMaterialGroup` não reconhece um `audioId` nesse parâmetro — o
// grupo nunca resolvia e o botão «Material» ficava sempre oculto para áudio.
//
// Harness: mesmo padrão de `carousel_chips_open_audio_test.dart`
// (`Scaffold(body: CarouselChips())` com `FakeActiveEditor`).
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
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

/// Sessão de mentira: só grava a fila/índice de [playQueue] — o suficiente
/// para provar que a troca de voz tocou a faixa nova.
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  List<AudioTrack>? playedQueue;
  int? playedStartIndex;

  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    playedQueue = tracks;
    playedStartIndex = startIndex;
  }
}

const _pdfEntry = PlaylistEntry(id: 'pdf1', kind: MaterialKind.pdf);

// Id "de verdade" (Base64 de um path com extensão de áudio) — só assim
// `materialIdKindOf` classifica a entrada focada como [MaterialKind.audio] e
// o sheet troca a ocorrência por chave em vez de só tocar por cima dela (ver
// o mesmo comentário em `carousel_chips_open_audio_test.dart`).
final _audioId1 = encodePdfId('assets/praises/g1/voz1.mp3');
final _audioId2 = encodePdfId('assets/praises/g1/voz2.mp3');

final _audioEntry = PlaylistEntry(id: _audioId1, kind: MaterialKind.audio);

final _trackVoz1 = AudioTrack(
  audioId: _audioId1,
  r2Key: 'assets/praises/g1/voz1.mp3',
  nome: 'Louvor g1',
  numero: '010',
  groupId: 'g1',
  categoria: 'Voz 1',
  classificacao: 'Básico',
);

final _trackVoz2 = AudioTrack(
  audioId: _audioId2,
  r2Key: 'assets/praises/g1/voz2.mp3',
  nome: 'Louvor g1',
  numero: '010',
  groupId: 'g1',
  categoria: 'Voz 2',
  classificacao: 'Básico',
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    '«Material» aparece para uma entrada de áudio focada e troca a voz por '
    'chave',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final editor = FakeActiveEditor([_pdfEntry, _audioEntry]);
      final session = _FakeAudioSession();

      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: CarouselChips()),
          ),
          GoRoute(
            path: RoutePaths.audio,
            builder: (_, state) => Scaffold(
              body: Text(state.uri.queryParameters['audioId'] ?? ''),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(() => editor),
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

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      // Duas vozes do mesmo grupo Coldigom — sem a segunda, o grupo resolvido
      // teria `totalMaterials == 1` e «Material» continuaria oculto.
      container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
        _trackVoz1,
        _trackVoz2,
      ]);
      await tester.pump();

      // Sem «Material» ainda: o foco está no PDF (primeiro item), não no
      // áudio.
      expect(find.byIcon(Icons.change_circle_outlined), findsNothing);

      container
          .read(carouselFocusedIndexProvider.notifier)
          .focusKey(_audioEntry.id);
      await tester.pump();

      // Crítico #1: com o áudio focado, «Material» aparece — o
      // `audioId`/`materialId` agora vão para os parâmetros certos de
      // `findSwapMaterialGroup`.
      expect(find.byIcon(Icons.change_circle_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.change_circle_outlined));
      await tester.pumpAndSettle();

      // Só um tipo no grupo (áudio) — o sheet lista as vozes direto, sem aba.
      // Escopado ao sheet: a chip da barra por trás também mostra «Voz 1»
      // como categoria do item focado.
      final sheetVoz1 = find.descendant(
        of: find.byType(MaterialSheet),
        matching: find.text('Voz 1'),
      );
      final sheetVoz2 = find.descendant(
        of: find.byType(MaterialSheet),
        matching: find.text('Voz 2'),
      );
      expect(sheetVoz1, findsOneWidget);
      expect(sheetVoz2, findsOneWidget);

      await tester.tap(sheetVoz2);
      await tester.pumpAndSettle();

      // Escolher outra voz troca a ocorrência da lista ativa por chave (spec
      // §3.2) — a chave da entrada de áudio focada, não a de uma partitura.
      expect(editor.replaced, [
        (
          key: _audioEntry.id,
          replacement: PlaylistEntry(id: _audioId2, kind: MaterialKind.audio),
        ),
      ]);
      expect(session.playedQueue?.map((t) => t.audioId).toList(), [
        _audioId1,
        _audioId2,
      ]);
      expect(session.playedStartIndex, 1);
    },
  );
}
