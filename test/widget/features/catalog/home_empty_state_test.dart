import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_empty_state.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor(
  String pdfId, {
  String numero = '001',
  String nome = 'Aleluia',
}) => Louvor.fromManifest(
  nome: nome,
  numero: numero,
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '$pdfId.pdf',
  pdfId: pdfId,
  groupId: 'g-$pdfId',
);

const _chord = ChordMaterial(
  chordId: 'chord-1',
  r2Key: 'assets/praises/p2/cifra.chord',
  nome: 'Grande é o Senhor',
  numero: '002',
  groupId: 'g-chord-1',
  categoria: 'Cifra',
  classificacao: 'ColAdultos',
);

const _track = AudioTrack(
  audioId: 'audio-1',
  r2Key: 'assets/praises/p3/audio.mp3',
  nome: 'Vim Adorar',
  numero: '003',
  groupId: 'g-audio-1',
  categoria: 'Áudio',
  classificacao: 'ColAdultos',
);

HomeSearchState _state({
  String query = '',
  AsyncValue<CatalogSearchPage>? remote,
}) {
  return HomeSearchState(
    query: query,
    page: 1,
    localGroups: const [],
    remote: remote ?? const AsyncData(CatalogSearchPage.empty),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required HomeSearchState state,
  required SharedPreferences prefs,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: HomeEmptyState(state: state)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedRecentlyOpened extends RecentlyOpenedNotifier {
  _FixedRecentlyOpened(this._ids);
  final List<String> _ids;

  @override
  List<String> build() => _ids;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('sem consulta', () {
    testWidgets('sem lista ativa nem recentes mostra só o hint', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        tester,
        state: _state(),
        prefs: prefs,
        overrides: [
          activePlaylistProvider.overrideWithValue(null),
          recentlyOpenedProvider.overrideWith(
            () => _FixedRecentlyOpened(const []),
          ),
        ],
      );

      expect(find.text('Busque por título ou número'), findsOneWidget);
    });

    testWidgets('lista ativa com entradas mostra "Lista ativa: …"', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final playlist = SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto de domingo',
        entries: [
          PlaylistEntry.classified('pdf-1'),
          PlaylistEntry.classified('pdf-2'),
        ],
        createdAt: DateTime.utc(2026, 9, 1),
      );

      await _pump(
        tester,
        state: _state(),
        prefs: prefs,
        overrides: [
          activePlaylistProvider.overrideWithValue(playlist),
          recentlyOpenedProvider.overrideWith(
            () => _FixedRecentlyOpened(const []),
          ),
        ],
      );

      expect(
        find.text('Lista ativa: Culto de domingo · 2 louvores'),
        findsOneWidget,
      );
      expect(find.text('Abrir no leitor'), findsOneWidget);
    });

    testWidgets('lista ativa sem entradas não mostra o cartão', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final playlist = SavedPlaylist(
        playlistId: 'p1',
        nome: 'Rascunho',
        entries: const [],
        createdAt: DateTime.utc(2026, 9, 1),
      );

      await _pump(
        tester,
        state: _state(),
        prefs: prefs,
        overrides: [
          activePlaylistProvider.overrideWithValue(playlist),
          recentlyOpenedProvider.overrideWith(
            () => _FixedRecentlyOpened(const []),
          ),
        ],
      );

      expect(find.textContaining('Lista ativa:'), findsNothing);
    });

    testWidgets(
      'chips de recentes abrem PDF/cifra/áudio pelo opener existente',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final openedIds = <String>[];

        await _pump(
          tester,
          state: _state(),
          prefs: prefs,
          overrides: [
            activePlaylistProvider.overrideWithValue(null),
            recentlyOpenedProvider.overrideWith(
              () => _FixedRecentlyOpened(const [
                'pdf-1',
                'chord-1',
                'audio-1',
                'id-sem-lookup',
              ]),
            ),
            catalogMaterialLookupProvider.overrideWithValue(
              CatalogMaterialLookup(
                plpcgLouvoresByPdfId: {'pdf-1': _louvor('pdf-1')},
                chordsById: const {'chord-1': _chord},
                audioTracksById: const {'audio-1': _track},
              ),
            ),
            openMaterialProvider.overrideWithValue(
              OpenMaterial(
                openPdf:
                    ({
                      required WidgetRef ref,
                      required BuildContext context,
                      required Louvor louvor,
                    }) async {
                      openedIds.add(louvor.pdfId);
                    },
                openChord:
                    ({
                      required WidgetRef ref,
                      required BuildContext context,
                      required ChordMaterial chord,
                    }) async {
                      openedIds.add(chord.chordId);
                    },
                openAudio:
                    ({
                      required WidgetRef ref,
                      required BuildContext context,
                      required AudioTrack track,
                      List<AudioTrack>? queue,
                    }) async {
                      openedIds.add(track.audioId);
                    },
              ),
            ),
          ],
        );

        // Id sem hit no lookup não vira chip (B.1: "ids sem lookup são
        // pulados").
        expect(find.byType(ActionChip), findsNWidgets(3));

        await tester.tap(find.text('001 Aleluia'));
        await tester.pumpAndSettle();
        expect(openedIds, ['pdf-1']);

        await tester.tap(find.text('002 Grande é o Senhor'));
        await tester.pumpAndSettle();
        expect(openedIds, ['pdf-1', 'chord-1']);

        await tester.tap(find.text('003 Vim Adorar'));
        await tester.pumpAndSettle();
        expect(openedIds, ['pdf-1', 'chord-1', 'audio-1']);
      },
    );
  });

  group('consulta sem resultado', () {
    testWidgets('mostra "Nenhum louvor para «query»" e as dicas', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        tester,
        state: _state(query: 'zzz'),
        prefs: prefs,
        overrides: [
          catalogFiltersProvider.overrideWith(_DefaultFiltersNotifier.new),
        ],
      );

      expect(find.text('Nenhum louvor para «zzz»'), findsOneWidget);
      expect(
        find.text('Tente outro termo, ou confira o número e a grafia.'),
        findsOneWidget,
      );
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('filtro fora do padrão mostra "Limpar filtros" e chama reset', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(catalogFiltersProvider.notifier)
          .toggleArranjo('ColAdultos');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Scaffold(
              body: HomeEmptyState(state: _state(query: 'zzz')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Limpar filtros'), findsOneWidget);
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      final filters = container.read(catalogFiltersProvider);
      expect(filters.materiaisUrlValue, isNull);
      expect(filters.arranjoUrlValue, isNull);
    });

    testWidgets('remoto falho e offline mostra o aviso Coldigom', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        tester,
        state: _state(
          query: 'zzz',
          remote: AsyncError(Exception('boom'), StackTrace.empty),
        ),
        prefs: prefs,
        overrides: [
          catalogFiltersProvider.overrideWith(_DefaultFiltersNotifier.new),
          connectivityStreamProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );

      expect(
        find.text(
          'Sem conexão — o acervo Coldigom pode estar incompleto nesta busca.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('remoto falho mas online não mostra o aviso Coldigom', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        tester,
        state: _state(
          query: 'zzz',
          remote: AsyncError(Exception('boom'), StackTrace.empty),
        ),
        prefs: prefs,
        overrides: [
          catalogFiltersProvider.overrideWith(_DefaultFiltersNotifier.new),
          connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );

      expect(
        find.text(
          'Sem conexão — o acervo Coldigom pode estar incompleto nesta busca.',
        ),
        findsNothing,
      );
    });
  });
}

class _DefaultFiltersNotifier extends CatalogFiltersNotifier {
  @override
  CatalogFilterState build() => CatalogFilterState.defaults();
}
