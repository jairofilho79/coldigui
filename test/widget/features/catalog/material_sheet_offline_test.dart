import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/offline/presentation/providers/material_availability_map_provider.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

final _pdfDownloaded = encodePdfId('assets/praises/p1/a.pdf');
final _pdfMissing = encodePdfId('assets/praises/p1/b.pdf');
final _audioId = encodePdfId('assets/praises/p1/c.mp3');

Louvor _pdf(String id, String categoria) => Louvor.fromManifest(
  nome: 'Comigo habita',
  numero: '692',
  categoria: categoria,
  classificacao: 'Básico',
  pdf: '$id.pdf',
  pdfId: id,
  groupId: 'p1',
  source: LouvorDataSource.coldigom,
);

final _track = AudioTrack(
  audioId: _audioId,
  r2Key: 'assets/praises/p1/c.mp3',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Playback',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

const _youtube = YoutubeMaterial(
  id: 'yt1',
  url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
  nome: 'Comigo habita',
  numero: '692',
  groupId: 'p1',
  categoria: 'Vídeo',
  classificacao: 'Básico',
  source: LouvorDataSource.coldigom,
);

const _lyrics = LyricsMaterial(
  praiseId: 'p1',
  nome: 'Comigo habita',
  numero: '692',
);

/// Registra cada `addToActive` do sheet — o `+` continua a chamar o editor
/// mesmo com a linha desabilitada (O14: só o `onTap` do corpo é bloqueado).
class _RecordingActiveEditor extends ActivePlaylistEditor {
  final added = <({String id, MaterialKind? kind, bool allowDuplicate})>[];

  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async {
    added.add((id: materialId, kind: kind, allowDuplicate: allowDuplicate));
    return AddToActiveOutcome.added;
  }
}

class _OpenSpy extends OpenMaterial {
  final opened = <CatalogMaterial>[];
  @override
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    CatalogMaterial material, {
    List<AudioTrack>? audioQueue,
  }) async {
    opened.add(material);
  }
}

LouvorGroup _group() => LouvorGroup.fromLouvores(
  [_pdf(_pdfDownloaded, 'Grade'), _pdf(_pdfMissing, 'Partitura')],
  audioTracks: [_track],
  youtubeMaterials: const [_youtube],
  lyricsByGroupId: const {'p1': _lyrics},
).single;

Future<_OpenSpy> _pumpSheet(
  WidgetTester tester, {
  required bool online,
  ActivePlaylistEditor Function()? editor,
  Size viewSize = const Size(800, 1600),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final spy = _OpenSpy();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        isarStatusProvider.overrideWithValue(IsarStatus.available),
        activeEntriesProvider.overrideWithValue(const []),
        openMaterialProvider.overrideWithValue(spy),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
        materialAvailabilityMapProvider.overrideWithValue({
          _pdfDownloaded: PdfOfflineAvailability.persistentOffline,
        }),
        if (editor != null) activePlaylistEditorProvider.overrideWith(editor),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMaterialSheet(context, ref, _group()),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return spy;
}

ListTile _tile(WidgetTester tester, String title) =>
    tester.widget<ListTile>(find.widgetWithText(ListTile, title));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'offline: baixado ativo, não baixado desabilitado com subtítulo, + continua ativo',
    (tester) async {
      final editor = _RecordingActiveEditor();
      final spy = await _pumpSheet(tester, online: false, editor: () => editor);

      expect(
        find.text('Sem ligação · só o que está no aparelho abre'),
        findsOneWidget,
      );
      expect(_tile(tester, 'Grade').enabled, isTrue);
      expect(_tile(tester, 'Partitura').enabled, isFalse);
      expect(find.text('Não baixado · sem ligação'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Partitura'),
          matching: find.byType(MaterialAddTrailing),
        ),
        findsOneWidget,
      );

      // O14: o `+` continua a funcionar num tile desabilitado — só o toque
      // no corpo da linha (abrir o material) é bloqueado.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Partitura'),
          matching: find.byType(CarouselLouvorAddButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(editor.added, [
        (id: _pdfMissing, kind: MaterialKind.pdf, allowDuplicate: false),
      ]);

      await tester.tap(find.widgetWithText(ListTile, 'Partitura'));
      await tester.pumpAndSettle();
      expect(spy.opened, isEmpty);
    },
  );

  testWidgets(
    'offline: áudio não baixado desabilitado; YouTube «Precisa de ligação»; letra ativa',
    (tester) async {
      await _pumpSheet(tester, online: false);

      await _openTab(tester, 'Áudio');
      expect(_tile(tester, 'Playback').enabled, isFalse);

      await _openTab(tester, 'YouTube');
      expect(_tile(tester, 'Vídeo').enabled, isFalse);
      expect(find.text('Precisa de ligação'), findsOneWidget);

      await _openTab(tester, 'Letra');
      expect(_tile(tester, 'Letra').enabled, isTrue);
    },
  );

  testWidgets('online: tudo ativo e sem banner', (tester) async {
    await _pumpSheet(tester, online: true);

    expect(
      find.text('Sem ligação · só o que está no aparelho abre'),
      findsNothing,
    );
    expect(_tile(tester, 'Partitura').enabled, isTrue);
    expect(find.text('Não baixado · sem ligação'), findsNothing);
  });

  testWidgets('offline a 400 px: banner + tile desabilitado sem overflow', (
    tester,
  ) async {
    await _pumpSheet(tester, online: false, viewSize: const Size(400, 1600));

    expect(
      find.text('Sem ligação · só o que está no aparelho abre'),
      findsOneWidget,
    );
    expect(_tile(tester, 'Partitura').enabled, isFalse);
    expect(find.text('Não baixado · sem ligação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
