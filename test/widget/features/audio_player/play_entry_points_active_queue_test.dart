import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

/// D4 — a fila do player é a reunião: os pontos de play preferem os
/// áudios da lista ativa quando a faixa tocada já está nela.
///
/// Antes da Tarefa 14 nenhum desses pontos respeitava a lista; card, sheet
/// de troca e o opener único mandavam a fila do grupo, e o playback parava no
/// fim do arranjo em vez de emendar no próximo louvor da reunião. (O carousel
/// no leitor também tinha um ponto de play próprio — removido depois por
/// risco de misclick.)

const _trackDaLista = AudioTrack(
  audioId: 'aud-lista',
  r2Key: 'assets/praises/p9/a.mp3',
  nome: 'Outro da reunião',
  numero: '009',
  groupId: 'p9',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

const _trackAlvo = AudioTrack(
  audioId: 'aud-alvo',
  r2Key: 'assets/praises/p1/a.mp3',
  nome: 'Aleluia',
  numero: '001',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

const _trackForaDaLista = AudioTrack(
  audioId: 'aud-fora',
  r2Key: 'assets/praises/p1/b.mp3',
  nome: 'Aleluia (playback)',
  numero: '001',
  groupId: 'p1',
  categoria: 'Playback',
  classificacao: 'Coro',
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

/// A face de áudio da lista ativa com a faixa alvo **na segunda** posição.
List<Override> _activeQueueOverrides() => [
  audioCarouselItemsProvider.overrideWithValue([
    _audioItem(_trackDaLista, 0),
    _audioItem(_trackAlvo, 1),
  ]),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Card com um único material de áudio: o toque toca direto, sem sheet.
  Future<_RecordingAudioSession> pumpGroupCard(
    WidgetTester tester, {
    required AudioTrack track,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final audio = _RecordingAudioSession();
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '001',
      nome: 'Aleluia',
      sections: const [],
      audioTracks: [track],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isarAvailableProvider.overrideWithValue(true),
          activePlaylistEditorProvider.overrideWith(FakeActiveEditor.new),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
          audioPlayerSessionProvider.overrideWith(() => audio),
          catalogMaterialLookupProvider.overrideWithValue(
            const CatalogMaterialLookup(
              audioTracksById: {
                'aud-lista': _trackDaLista,
                'aud-alvo': _trackAlvo,
              },
            ),
          ),
          ..._activeQueueOverrides(),
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
                    Scaffold(body: LouvorGroupCard(group: group)),
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
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Aleluia').first);
    await tester.pumpAndSettle();
    return audio;
  }

  testWidgets('LouvorGroupCard: a fila é a lista ativa, não só o grupo', (
    tester,
  ) async {
    final audio = await pumpGroupCard(tester, track: _trackAlvo);

    expect(audio.queue?.map((t) => t.audioId).toList(), [
      'aud-lista',
      'aud-alvo',
    ]);
    expect(audio.startIndex, 1);
  });

  testWidgets('LouvorGroupCard: faixa fora da lista toca a fila do grupo', (
    tester,
  ) async {
    final audio = await pumpGroupCard(tester, track: _trackForaDaLista);

    expect(audio.queue?.map((t) => t.audioId).toList(), ['aud-fora']);
    expect(audio.startIndex, 0);
  });

  testWidgets('sheet de troca de material: a fila é a lista ativa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final audio = _RecordingAudioSession();
    final louvor = Louvor.fromManifest(
      nome: 'Aleluia',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'pdf1.pdf',
      pdfId: 'pdf1',
      groupId: 'p1',
    );
    final group = LouvorGroup(
      groupId: 'p1',
      numero: '001',
      nome: 'Aleluia',
      sections: [
        LouvorMaterialSection(
          classificacao: 'Partitura',
          displayLabel: 'Partitura',
          materials: [
            LouvorMaterialEntry(
              categoria: 'Partitura',
              pdfId: 'pdf1',
              louvor: louvor,
            ),
          ],
        ),
      ],
      audioTracks: const [_trackAlvo],
    );

    final router = GoRouter(
      initialLocation: RoutePaths.reader,
      routes: [
        GoRoute(
          path: RoutePaths.reader,
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showCarouselSwapMaterialSheet(
                  context: context,
                  ref: ref,
                  group: group,
                  currentMaterialId: 'pdf1',
                  currentEntryKey: 'pdf1',
                ),
                child: const Text('trocar'),
              ),
            ),
          ),
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
          isarAvailableProvider.overrideWithValue(true),
          activePlaylistEditorProvider.overrideWith(FakeActiveEditor.new),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
          audioPlayerSessionProvider.overrideWith(() => audio),
          coldigomLouvoresOverride([louvor]),
          catalogMaterialLookupProvider.overrideWithValue(
            const CatalogMaterialLookup(
              audioTracksById: {
                'aud-lista': _trackDaLista,
                'aud-alvo': _trackAlvo,
              },
            ),
          ),
          ..._activeQueueOverrides(),
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

    await tester.tap(find.text('trocar'));
    await tester.pumpAndSettle();
    // A aba «Áudio» primeiro; a faixa tem a mesma categoria «Áudio».
    await tester.tap(find.text('Áudio').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áudio').last);
    await tester.pumpAndSettle();

    expect(audio.queue?.map((t) => t.audioId).toList(), [
      'aud-lista',
      'aud-alvo',
    ]);
    expect(audio.startIndex, 1);
  });

  testWidgets('openMaterialProvider: sem fila explícita usa a lista ativa', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<AudioTrack>? received;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          catalogMaterialLookupProvider.overrideWithValue(
            const CatalogMaterialLookup(
              audioTracksById: {
                'aud-lista': _trackDaLista,
                'aud-alvo': _trackAlvo,
              },
            ),
          ),
          openMaterialProvider.overrideWithValue(
            OpenMaterial(
              openAudio:
                  ({
                    required ref,
                    required context,
                    required track,
                    List<AudioTrack>? queue,
                  }) async {
                    received = queue;
                  },
            ),
          ),
          ..._activeQueueOverrides(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ref
                    .read(openMaterialProvider)
                    .open(context, ref, const AudioMaterial(_trackAlvo)),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(received?.map((t) => t.audioId).toList(), ['aud-lista', 'aud-alvo']);
  });
}
