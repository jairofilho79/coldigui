import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/theme/app_theme.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_query.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_state.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/recently_opened_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_empty_state.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool offline = false,
}) {
  return HomeSearchState(
    query: query,
    localGroups: const [],
    remote: remote ?? const AsyncData(CatalogSearchPage.empty),
    offline: offline,
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

/// Igual a [_pump], mas com [AppTheme.light] e sem `backgroundColor` no
/// `Scaffold` — reproduz o fundo vinho real da Home ([AppColors.background],
/// `scaffoldBackgroundColor` do tema) para os testes de contraste do fix
/// «texto branco onde o fundo é vinho» (onda 4.1, feedback do product owner).
Future<void> _pumpOnWine(
  WidgetTester tester, {
  required HomeSearchState state,
  required SharedPreferences prefs,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: HomeEmptyState(state: state)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Color? _buttonForegroundColor(WidgetTester tester, Finder finder) {
  final style = switch (tester.widget(finder)) {
    TextButton(:final style) => style,
    OutlinedButton(:final style) => style,
    _ => null,
  };
  return style?.foregroundColor?.resolve(const <WidgetState>{});
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

    testWidgets('lista ativa não vira cartão — a barra já a mostra', (
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

      expect(find.textContaining('Lista ativa:'), findsNothing);
      expect(find.text('Abrir no leitor'), findsNothing);
      expect(find.text('Busque por título ou número'), findsOneWidget);
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
                coldigomLouvoresByPdfId: {'pdf-1': _louvor('pdf-1')},
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

        // Id sem hit no lookup não vira card (B.1: "ids sem lookup são
        // pulados").
        expect(find.byType(CarouselLouvorChip), findsNWidgets(3));

        await tester.tap(find.text('#001 — Aleluia'));
        await tester.pumpAndSettle();
        expect(openedIds, ['pdf-1']);

        await tester.tap(find.text('#002 — Grande é o Senhor'));
        await tester.pumpAndSettle();
        expect(openedIds, ['pdf-1', 'chord-1']);

        await tester.tap(find.text('#003 — Vim Adorar'));
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

    testWidgets('filtro ativo mostra "Limpar filtros" e limpa', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      container.read(catalogFiltersProvider.notifier).toggleTag('PES');

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

      expect(container.read(catalogFiltersProvider).isEmpty, isTrue);
    });

    testWidgets(
      'remoto falho e offline mostra o aviso de catálogo incompleto',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await _pump(
          tester,
          state: _state(
            query: 'zzz',
            remote: AsyncError(Exception('boom'), StackTrace.empty),
            offline: true,
          ),
          prefs: prefs,
          overrides: [
            catalogFiltersProvider.overrideWith(_DefaultFiltersNotifier.new),
            coldigomSearchIndexProvider.overrideWithValue(
              ColdigomSearchIndex.empty,
            ),
          ],
        );

        expect(
          find.text(
            'Sem conexão — o catálogo pode estar incompleto nesta busca.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'remoto falho, offline mas com catálogo local não mostra o aviso',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await _pump(
          tester,
          state: _state(
            query: 'zzz',
            remote: AsyncError(Exception('boom'), StackTrace.empty),
            offline: true,
          ),
          prefs: prefs,
          overrides: [
            catalogFiltersProvider.overrideWith(_DefaultFiltersNotifier.new),
            coldigomSearchIndexProvider.overrideWithValue(
              ColdigomSearchIndex.build([
                ColdigomIndexedPraise.build(
                  praiseId: 'p',
                  numero: '',
                  nome: 'x',
                  searchTokens: 'x',
                  group: LouvorGroup(
                    groupId: 'p',
                    numero: '',
                    nome: 'x',
                    sections: const [],
                  ),
                ),
              ]),
            ),
          ],
        );

        expect(
          find.text(
            'Sem conexão — o catálogo pode estar incompleto nesta busca.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'remoto falho mas online não mostra o aviso de catálogo incompleto',
      (tester) async {
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
          ],
        );

        expect(
          find.text(
            'Sem conexão — o catálogo pode estar incompleto nesta busca.',
          ),
          findsNothing,
        );
      },
    );
  });

  group(
    'contraste sobre o fundo vinho (onda 4.1, feedback do product owner)',
    () {
      testWidgets('sem consulta: rótulo de recentes e hint em branco', (
        tester,
      ) async {
        final prefs = await SharedPreferences.getInstance();
        final playlist = SavedPlaylist(
          playlistId: 'p1',
          nome: 'Culto de domingo',
          entries: [PlaylistEntry.classified('pdf-1')],
          createdAt: DateTime.utc(2026, 9, 1),
        );

        await _pumpOnWine(
          tester,
          state: _state(),
          prefs: prefs,
          overrides: [
            activePlaylistProvider.overrideWithValue(playlist),
            recentlyOpenedProvider.overrideWith(
              () => _FixedRecentlyOpened(const ['pdf-1']),
            ),
            catalogMaterialLookupProvider.overrideWithValue(
              CatalogMaterialLookup(
                coldigomLouvoresByPdfId: {'pdf-1': _louvor('pdf-1')},
              ),
            ),
          ],
        );

        // O rótulo vive dentro do card creme próprio da seção (C6) — vinho,
        // como qualquer texto sobre `AppColors.card`, independente do fundo
        // do `Scaffold` por trás.
        expect(_textColor(tester, 'Abertos recentemente'), AppColors.title);
        expect(
          _textColor(tester, 'Busque por título ou número'),
          AppColors.textLight.withValues(alpha: 0.7),
        );
        // O card do material usa `CarouselLouvorChip` — título em branco
        // sobre o fundo vermelho/preto do chip (por `LouvorDataSource`).
        expect(_textColor(tester, '#001 — Aleluia'), AppColors.textLight);
      });

      testWidgets(
        'consulta sem resultado: título, dicas, botão e aviso de catálogo incompleto em branco',
        (tester) async {
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              // Sem isto, `_NoResultsContent` tentaria hidratar o índice
              // Coldigom via Isar de verdade (não há aqui) e o teste travaria
              // num timer pendente — mesmo cuidado do caso "mostra o aviso".
              coldigomSearchIndexProvider.overrideWithValue(
                ColdigomSearchIndex.empty,
              ),
            ],
          );
          addTearDown(container.dispose);
          container.read(catalogFiltersProvider.notifier).toggleTag('PES');

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('pt'),
                home: Scaffold(
                  body: HomeEmptyState(
                    state: _state(
                      query: 'zzz',
                      remote: AsyncError(Exception('boom'), StackTrace.empty),
                      offline: true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            _textColor(tester, 'Nenhum louvor para «zzz»'),
            AppColors.textLight,
          );
          expect(
            _textColor(
              tester,
              'Tente outro termo, ou confira o número e a grafia.',
            ),
            AppColors.textLight.withValues(alpha: 0.7),
          );
          expect(
            _buttonForegroundColor(
              tester,
              find.widgetWithText(OutlinedButton, 'Limpar filtros'),
            ),
            AppColors.textLight,
          );
          expect(
            _textColor(
              tester,
              'Sem conexão — o catálogo pode estar incompleto nesta busca.',
            ),
            AppColors.textLight.withValues(alpha: 0.75),
          );
        },
      );
    },
  );
}

class _DefaultFiltersNotifier extends CatalogFiltersNotifier {
  @override
  CatalogFilterState build() => CatalogFilterState.empty;
}
