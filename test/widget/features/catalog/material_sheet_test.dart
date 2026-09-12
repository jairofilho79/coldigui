import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/chords/presentation/providers/available_chords_provider.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fixtures

Louvor _pdf({
  required String categoria,
  required String pdfId,
  String classificacao = 'Básico',
  LouvorDataSource source = LouvorDataSource.plpcg,
}) {
  return Louvor.fromManifest(
    nome: 'Comigo habita',
    numero: '692',
    categoria: categoria,
    classificacao: classificacao,
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g1',
    source: source,
  );
}

ChordMaterial _chord(String categoria, String r2Key) {
  return ChordMaterial(
    chordId: 'chord-$categoria',
    r2Key: r2Key,
    nome: 'Comigo habita',
    numero: '692',
    groupId: 'g1',
    categoria: categoria,
    classificacao: 'Básico',
  );
}

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

const _youtube = YoutubeMaterial(
  id: 'yt1',
  url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'g1',
  categoria: 'Gestos CIAs',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

// ------------------------------------------------------------------- fakes

/// Registra o material que o sheet mandou abrir pelo `openMaterialProvider`.
class _OpenMaterialSpy extends OpenMaterial {
  _OpenMaterialSpy();

  CatalogMaterial? opened;
  List<AudioTrack>? openedQueue;

  @override
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    CatalogMaterial material, {
    List<AudioTrack>? audioQueue,
  }) async {
    opened = material;
    openedQueue = audioQueue;
  }
}

class _RecordingPlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];
}

/// Registra cada `addToActive` do sheet — o `+` passa pelo editor (B.3).
class _RecordingActiveEditor extends ActivePlaylistEditor {
  _RecordingActiveEditor({this.outcome = AddToActiveOutcome.added});

  /// O que o editor responde — o sheet só traduz o resultado em snackbar.
  final AddToActiveOutcome outcome;
  final List<({String id, MaterialKind? kind, bool allowDuplicate})> added = [];

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    added.add((id: materialId, kind: kind, allowDuplicate: allowDuplicate));
    return outcome;
  }
}

/// Cache de metadados Coldigom pré-carregado (o card só lê, nunca busca).
class _SeededPraiseMetaCache extends ColdigomPraiseMetaCacheNotifier {
  _SeededPraiseMetaCache(this.seed);

  final Map<String, ColdigomPraiseMetadata> seed;

  @override
  Map<String, ColdigomPraiseMetadata> build() => seed;
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required LouvorGroup group,
  _OpenMaterialSpy? opener,
  PlaylistsNotifier Function()? playlists,
  ActivePlaylistEditor Function()? editor,
  List<ActiveEntry> activeEntries = const [],
  bool canAddToPlaylist = true,
  IsarStatus isarStatus = IsarStatus.available,
  List<Override> overrides = const [],
}) async {
  // O sheet é uma ListView e o modal ocupa 75% da altura: na janela padrão
  // (800x600) os materiais do fim da lista não chegam a ser construídos, e
  // `find.text` não rola.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isarStatusProvider.overrideWithValue(isarStatus),
        activeEntriesProvider.overrideWithValue(activeEntries),
        if (editor != null) activePlaylistEditorProvider.overrideWith(editor),
        if (playlists != null) playlistsProvider.overrideWith(playlists),
        if (opener != null) openMaterialProvider.overrideWithValue(opener),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Locale fixo: o default do flutter_test é inglês e os asserts abaixo
        // esperam as strings em português.
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => showMaterialSheet(
                  context,
                  ref,
                  group,
                  canAddToPlaylist: canAddToPlaylist,
                ),
                child: const Text('abrir'),
              ),
            );
          },
        ),
      ),
    ),
  );
  // Quem monta o grupo (busca/browse, detalhe do praise) já fundiu as cifras
  // no cache pelo escritor — o sheet só lê (C.3). O teste repete o contrato.
  capturedRef
      .read(coldigomCacheWriterProvider)
      .mergeChords(group.chordMaterials);
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  final song = parseChordPro('{title: X}\n\nA [Bb]noite vem,\n');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PDF por seção', () {
    testWidgets('duas seções mostram rótulo, entradas e abrem pelo opener', (
      tester,
    ) async {
      final opener = _OpenMaterialSpy();
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1', classificacao: 'Básico'),
        _pdf(categoria: 'Cifra', pdfId: 'pdf2', classificacao: 'Fox'),
      ]).first;

      await _pumpSheet(tester, group: group, opener: opener);

      // Duas seções → os rótulos de classificação aparecem.
      expect(find.text('Básico'), findsOneWidget);
      expect(find.text('Fox'), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
      expect(find.text('Cifra'), findsOneWidget);

      await tester.tap(find.text('Cifra'));
      await tester.pumpAndSettle();

      expect(opener.opened, isA<PdfMaterial>());
      expect(opener.opened!.id, 'pdf2');
    });

    testWidgets('seção única e nada mais não mostra rótulo nenhum', (
      tester,
    ) async {
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
        _pdf(categoria: 'Cifra', pdfId: 'pdf2'),
      ]).first;

      await _pumpSheet(tester, group: group);

      expect(find.text('Básico'), findsNothing);
      expect(find.text('Partitura'), findsOneWidget);
      expect(find.text('Cifra'), findsOneWidget);
    });

    // Dois tipos → abas «Partituras» | «Cifras»; a seção única de PDF não
    // ganha rótulo (a aba já diz o que é).
    testWidgets('uma seção de PDF com cifras vira duas abas', (tester) async {
      final group = LouvorGroup(
        groupId: 'g1',
        numero: '692',
        nome: 'Comigo habita',
        sections: LouvorGroup.fromLouvores([
          _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
        ]).first.sections,
        chordMaterials: [_chord('Cifra I', 'k1')],
      );

      await _pumpSheet(
        tester,
        group: group,
        overrides: [chordSongProvider.overrideWith((ref, r2Key) async => song)],
      );

      expect(find.text('Básico'), findsNothing);
      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Cifras'), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
      expect(find.text('Cifra I'), findsNothing);

      await tester.tap(find.text('Cifras'));
      await tester.pumpAndSettle();

      expect(find.text('Cifra I'), findsOneWidget);
      expect(find.text('Partitura'), findsNothing);
    });

    testWidgets('seção sem classificação usa «Partituras» como rótulo', (
      tester,
    ) async {
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1', classificacao: ''),
        _pdf(categoria: 'Cifra', pdfId: 'pdf2', classificacao: 'Fox'),
      ]).first;

      await _pumpSheet(tester, group: group);

      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Fox'), findsOneWidget);
    });

    // Praise Coldigom de seção única sem cifra/áudio/YouTube: um bloco só.
    testWidgets('praise de bloco único não mostra rótulo', (tester) async {
      final group = LouvorGroup.fromLouvores([
        _pdf(
          categoria: 'Partitura',
          pdfId: 'pdf1',
          source: LouvorDataSource.coldigom,
        ),
      ]).first;

      await _pumpSheet(tester, group: group);

      expect(find.text('Básico'), findsNothing);
      expect(find.text('Partituras'), findsNothing);
      expect(find.text('Cifras'), findsNothing);
      expect(find.text('Áudio'), findsNothing);
      expect(find.text('YouTube'), findsNothing);
      expect(find.text('Partitura'), findsOneWidget);
    });
  });

  group('YouTube', () {
    testWidgets('ícone vermelho, sem + e abertura pelo opener', (tester) async {
      final opener = _OpenMaterialSpy();
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        youtubeMaterials: const [_youtube],
      ).first;

      await _pumpSheet(
        tester,
        group: group,
        opener: opener,
        playlists: _RecordingPlaylistsNotifier.new,
      );

      expect(find.text('YouTube'), findsOneWidget);
      // PDF tem botão +; a aba de YouTube nem tile com + tem.
      expect(find.byType(CarouselLouvorAddButton), findsOneWidget);
      expect(find.text('Gestos CIAs'), findsNothing);

      await tester.tap(find.text('YouTube'));
      await tester.pumpAndSettle();

      expect(find.text('Gestos CIAs'), findsOneWidget);
      expect(find.byType(CarouselLouvorAddButton), findsNothing);

      final youtubeIcon = tester.widget<Icon>(
        find.byIcon(LouvorMaterialIcons.youtube),
      );
      expect(youtubeIcon.color, AppColors.youtube);

      final youtubeTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Gestos CIAs'),
      );
      expect(youtubeTile.trailing, isNull);

      await tester.tap(find.text('Gestos CIAs'));
      await tester.pumpAndSettle();

      expect(opener.opened, isA<YoutubeMaterialRef>());
      expect(opener.opened!.id, 'yt1');
    });
  });

  group('cabeçalho Coldigom', () {
    testWidgets('meta, número separado do nome e abas por tipo', (
      tester,
    ) async {
      final group = LouvorGroup.fromLouvores(
        [
          _pdf(
            categoria: 'Partitura',
            pdfId: 'pdf1',
            source: LouvorDataSource.coldigom,
          ),
          _pdf(
            categoria: 'Cifra I',
            pdfId: 'pdf2',
            source: LouvorDataSource.coldigom,
          ),
        ],
        audioTracks: const [_track],
        youtubeMaterials: const [_youtube],
        coldigomMetaByGroupId: const {
          'g1': ColdigomPraiseMetadata(
            name: 'Comigo habita',
            tonality: 'Dm',
            author: 'CIAS',
            rhythm: 'Básico',
            category: 'Clamor',
            tagNames: ['PES'],
          ),
        },
      ).first;

      await _pumpSheet(tester, group: group);

      expect(find.text('692'), findsOneWidget);
      expect(find.text('Comigo habita'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(find.text('Dm'), findsOneWidget);
      expect(find.text('Autor'), findsOneWidget);
      expect(find.text('CIAS'), findsOneWidget);
      expect(find.text('Ritmo'), findsOneWidget);
      // Só no bloco de meta: a seção única de PDF não ganha rótulo, a aba
      // «Partituras» já diz o que é.
      expect(find.text('Básico'), findsOneWidget);
      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Clamor'), findsOneWidget);
      expect(find.text('PES'), findsOneWidget);
      expect(find.text('TAGS'), findsOneWidget);

      // Título concatenado antigo do sheet PLPCG não existe.
      expect(find.text('692 — Comigo habita'), findsNothing);

      // Abas: PDF aberta, as outras só com o rótulo.
      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Áudio'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
      expect(find.text('Cifra I'), findsOneWidget);
      expect(find.text('Playback'), findsNothing);
      expect(find.text('Gestos CIAs'), findsNothing);

      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();

      expect(find.text('Partitura'), findsNothing);
      expect(find.text('Playback'), findsOneWidget);
      // Autor no bloco de meta e no subtítulo da faixa.
      expect(find.text('CIAS'), findsNWidgets(2));

      await tester.tap(find.text('YouTube'));
      await tester.pumpAndSettle();

      expect(find.text('Playback'), findsNothing);
      expect(find.text('Gestos CIAs'), findsOneWidget);
    });

    testWidgets('sem coldigomMeta não desenha o bloco de metadados', (
      tester,
    ) async {
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
        _pdf(categoria: 'Cifra', pdfId: 'pdf2'),
      ]).first;

      await _pumpSheet(tester, group: group);

      expect(find.text('Tom'), findsNothing);
      expect(find.text('TAGS'), findsNothing);
    });
  });

  group('cifras', () {
    LouvorGroup groupWithChords(List<ChordMaterial> chords) {
      return LouvorGroup(
        groupId: 'g1',
        numero: '692',
        nome: 'Comigo habita',
        sections: const [],
        chordMaterials: chords,
      );
    }

    testWidgets('lista só as cifras disponíveis', (tester) async {
      await _pumpSheet(
        tester,
        group: groupWithChords([
          _chord('Cifra I', 'k1'),
          _chord('Cifra II', 'k2'),
        ]),
        overrides: [
          chordSongProvider.overrideWith(
            (ref, r2Key) async => r2Key == 'k1' ? song : null,
          ),
        ],
      );

      // Tipo único: sem abas nem rótulo.
      expect(find.text('Cifras'), findsNothing);
      expect(find.text('Cifra I'), findsOneWidget);
      expect(find.text('Cifra II'), findsNothing);
    });

    testWidgets('esconde a seção quando nenhuma cifra está disponível', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        group: groupWithChords([_chord('Cifra I', 'k1')]),
        overrides: [
          chordSongProvider.overrideWith(
            (ref, r2Key) async => null as ChordProSong?,
          ),
        ],
      );

      expect(find.text('Cifras'), findsNothing);
    });

    testWidgets('esconde a seção quando o grupo não tem cifra', (tester) async {
      await _pumpSheet(tester, group: groupWithChords(const []));

      expect(find.text('Cifras'), findsNothing);
    });

    // B3: o `kind` da cifra é confiável; a `categoria` é texto livre do Worker.
    // Uma cifra rotulada "Gestos CIAs" continua com ícone de cifra.
    testWidgets('ícone vem do kind, não da categoria livre', (tester) async {
      await _pumpSheet(
        tester,
        group: groupWithChords([_chord('Gestos CIAs', 'k1')]),
        overrides: [chordSongProvider.overrideWith((ref, r2Key) async => song)],
      );

      expect(
        find.byIcon(LouvorMaterialIcons.forKind(MaterialKind.chord)),
        findsOneWidget,
      );
      expect(
        find.byIcon(LouvorMaterialIcons.forKind(MaterialKind.gesture)),
        findsNothing,
      );
    });

    testWidgets('toque na cifra abre pelo opener', (tester) async {
      final opener = _OpenMaterialSpy();
      await _pumpSheet(
        tester,
        group: groupWithChords([_chord('Cifra', 'k1')]),
        opener: opener,
        overrides: [chordSongProvider.overrideWith((ref, r2Key) async => song)],
      );

      await tester.tap(find.text('Cifra'));
      await tester.pumpAndSettle();

      expect(opener.opened, isA<ChordMaterialRef>());
      expect(opener.opened!.categoria, 'Cifra');
    });

    // Defensivo (A4): em produção `availableChordsProvider` engole falha de
    // rede e nunca emite `AsyncError` — ver
    // `available_chords_provider_test.dart`, "falha de rede nunca vira
    // AsyncError". O override abaixo força o estado que só um erro inesperado
    // (bug de parsing, provider trocado) produziria; o teste existe para que a
    // linha de retry continue correta se isso acontecer.
    testWidgets(
      'defensivo: AsyncError mostra "indisponível · tentar de novo" e o toque '
      'retenta',
      (tester) async {
        var failing = true;
        var calls = 0;
        await _pumpSheet(
          tester,
          group: groupWithChords([_chord('Cifra I', 'k1')]),
          overrides: [
            availableChordsProvider.overrideWith((ref, groupId) async {
              calls++;
              if (failing) throw Exception('sem rede');
              return [_chord('Cifra I', 'k1')];
            }),
          ],
        );

        // Erro não some com a lista: a linha de retry ocupa o lugar da cifra.
        expect(
          find.text('Cifra indisponível · tentar de novo'),
          findsOneWidget,
        );
        expect(find.text('Cifra I'), findsNothing);

        final callsBeforeRetry = calls;
        failing = false;
        await tester.tap(find.text('Cifra indisponível · tentar de novo'));
        await tester.pumpAndSettle();

        expect(calls, greaterThan(callsBeforeRetry));
        expect(find.text('Cifra indisponível · tentar de novo'), findsNothing);
        expect(find.text('Cifra I'), findsOneWidget);
      },
    );
  });

  group('áudio', () {
    testWidgets('mostra autor no subtítulo e abre pelo opener', (tester) async {
      final opener = _OpenMaterialSpy();
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        audioTracks: const [_track],
      ).first;

      await _pumpSheet(tester, group: group, opener: opener);

      expect(find.text('Áudio'), findsOneWidget);
      expect(find.text('Playback'), findsNothing);

      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();

      expect(find.text('Playback'), findsOneWidget);
      expect(find.text('CIAS'), findsOneWidget);

      await tester.tap(find.text('Playback'));
      await tester.pumpAndSettle();

      expect(opener.opened, isA<AudioMaterial>());
      expect(opener.opened!.id, 'audio1');
    });

    testWidgets('toque leva a fila inteira do grupo, não só a faixa', (
      tester,
    ) async {
      const segunda = AudioTrack(
        audioId: 'audio2',
        r2Key: 'audio-key-2',
        nome: 'Comigo habita',
        numero: '692',
        groupId: 'g1',
        categoria: 'Instrumental',
        classificacao: 'Básico',
        source: LouvorDataSource.coldigom,
      );
      const terceira = AudioTrack(
        audioId: 'audio3',
        r2Key: 'audio-key-3',
        nome: 'Comigo habita',
        numero: '692',
        groupId: 'g1',
        categoria: 'Coral',
        classificacao: 'Básico',
        source: LouvorDataSource.coldigom,
      );
      final opener = _OpenMaterialSpy();
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        audioTracks: const [_track, segunda, terceira],
      ).first;

      await _pumpSheet(tester, group: group, opener: opener);

      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instrumental'));
      await tester.pumpAndSettle();

      expect(opener.opened!.id, 'audio2');
      expect(opener.openedQueue?.map((t) => t.audioId).toList(), [
        'audio1',
        'audio2',
        'audio3',
      ]);
    });

    testWidgets('grupo sem áudio não mostra o cabeçalho Áudio', (tester) async {
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
        _pdf(categoria: 'Cifra', pdfId: 'pdf2'),
      ]).first;

      await _pumpSheet(tester, group: group);

      expect(find.text('Áudio'), findsNothing);
    });
  });

  group('ações de trailing', () {
    testWidgets('+ do PDF e do áudio entram pelo editor com o kind certo', (
      tester,
    ) async {
      final editor = _RecordingActiveEditor();
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        audioTracks: const [_track],
      ).first;

      await _pumpSheet(tester, group: group, editor: () => editor);

      expect(find.byType(CarouselLouvorAddButton), findsOneWidget);

      await tester.tap(find.byType(CarouselLouvorAddButton));
      await tester.pumpAndSettle();
      expect(editor.added, [
        (id: 'pdf1', kind: MaterialKind.pdf, allowDuplicate: false),
      ]);

      // O + não fecha o sheet.
      expect(find.text('Partitura'), findsOneWidget);

      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CarouselLouvorAddButton));
      await tester.pumpAndSettle();
      expect(editor.added.last, (
        id: 'audio1',
        kind: MaterialKind.audio,
        allowDuplicate: false,
      ));
      expect(find.text('Playback'), findsOneWidget);
    });

    testWidgets('material já na lista mostra «Adicionar de novo» e repete', (
      tester,
    ) async {
      final editor = _RecordingActiveEditor();
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
      ]).first;

      await _pumpSheet(
        tester,
        group: group,
        editor: () => editor,
        activeEntries: const [
          ActiveEntry(
            index: 0,
            entry: PlaylistEntry(id: 'pdf1', kind: MaterialKind.pdf),
            key: 'pdf1',
          ),
        ],
      );

      expect(find.byType(CarouselLouvorAddButton), findsNothing);
      expect(find.text('Adicionar de novo'), findsOneWidget);

      await tester.tap(find.text('Adicionar de novo'));
      await tester.pumpAndSettle();

      expect(editor.added, [
        (id: 'pdf1', kind: MaterialKind.pdf, allowDuplicate: true),
      ]);
    });

    // A8: enquanto o Isar ainda **abre** (web fria), o `+` não pré-julga o
    // storage no toque — quem decide é o editor, que espera a abertura.
    testWidgets('com o Isar abrindo, o + entra pelo editor sem pré-julgar', (
      tester,
    ) async {
      final editor = _RecordingActiveEditor();
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
      ]).first;

      await _pumpSheet(
        tester,
        group: group,
        editor: () => editor,
        isarStatus: IsarStatus.opening,
      );

      await tester.tap(find.byType(CarouselLouvorAddButton));
      await tester.pumpAndSettle();

      expect(editor.added, hasLength(1));
      expect(find.text('Adicionado à seleção'), findsOneWidget);
      expect(
        find.text(
          'Armazenamento local indisponível. Listas não podem ser salvas.',
        ),
        findsNothing,
      );
    });

    testWidgets('storageUnavailable do editor vira a snackbar de storage', (
      tester,
    ) async {
      final editor = _RecordingActiveEditor(
        outcome: AddToActiveOutcome.storageUnavailable,
      );
      final group = LouvorGroup.fromLouvores([
        _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
      ]).first;

      await _pumpSheet(
        tester,
        group: group,
        editor: () => editor,
        isarStatus: IsarStatus.opening,
      );

      await tester.tap(find.byType(CarouselLouvorAddButton));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Armazenamento local indisponível. Listas não podem ser salvas.',
        ),
        findsOneWidget,
      );
      expect(find.text('Adicionado à seleção'), findsNothing);
    });

    testWidgets('canAddToPlaylist falso esconde todos os +', (tester) async {
      final group = LouvorGroup.fromLouvores(
        [_pdf(categoria: 'Partitura', pdfId: 'pdf1')],
        audioTracks: const [_track],
      ).first;

      await _pumpSheet(
        tester,
        group: group,
        canAddToPlaylist: false,
        playlists: _RecordingPlaylistsNotifier.new,
      );

      expect(find.byType(CarouselLouvorAddButton), findsNothing);
      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();
      expect(find.byType(CarouselLouvorAddButton), findsNothing);
    });
  });

  group('LouvorGroupCard abre o mesmo sheet nos dois acervos', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required LouvorGroup group,
      Map<String, ColdigomPraiseMetadata> praiseMeta = const {},
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isarAvailableProvider.overrideWithValue(true),
            activeEntriesProvider.overrideWithValue(const []),
            playlistsProvider.overrideWith(_RecordingPlaylistsNotifier.new),
            coldigomPraiseMetaCacheProvider.overrideWith(
              () => _SeededPraiseMetaCache(praiseMeta),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Scaffold(body: LouvorGroupCard(group: group)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Comigo habita').first);
      await tester.pumpAndSettle();
    }

    testWidgets('grupo PLPCG abre o MaterialSheet', (tester) async {
      await pumpCard(
        tester,
        group: LouvorGroup.fromLouvores([
          _pdf(categoria: 'Partitura', pdfId: 'pdf1'),
          _pdf(categoria: 'Cifra', pdfId: 'pdf2'),
        ]).first,
      );

      expect(find.byType(MaterialSheet), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
      expect(find.text('Tom'), findsNothing);
    });

    testWidgets('grupo Coldigom abre o mesmo sheet, com o cabeçalho de meta', (
      tester,
    ) async {
      await pumpCard(
        tester,
        group: LouvorGroup.fromLouvores([
          _pdf(
            categoria: 'Partitura',
            pdfId: 'pdf1',
            source: LouvorDataSource.coldigom,
          ),
          _pdf(
            categoria: 'Cifra I',
            pdfId: 'pdf2',
            source: LouvorDataSource.coldigom,
          ),
        ]).first,
        // Grupo sem coldigomMeta: groupWithColdigomMeta anexa o do cache.
        praiseMeta: const {
          'g1': ColdigomPraiseMetadata(name: 'Comigo habita', tonality: 'Dm'),
        },
      );

      expect(find.byType(MaterialSheet), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(find.text('Dm'), findsOneWidget);
    });
  });
}
