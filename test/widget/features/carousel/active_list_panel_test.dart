import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_list_panel.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editor da lista ativa dirigido pelo teste — registra chave por chave
/// (mesmo dublê de `carousel_selection_sheet_test.dart`).
class _FakeActiveEditor extends ActivePlaylistEditor {
  _FakeActiveEditor(this.initial);

  final List<PlaylistEntry> initial;
  final removedKeys = <String>[];
  List<String>? lastReorder;
  PlaylistMediaFace? lastReorderFace;

  @override
  List<PlaylistEntry>? build() => initial;

  List<ActiveEntry> get _entries => activeEntriesOf(state ?? const []);

  @override
  Future<void> removeByKey(String key) async {
    removedKeys.add(key);
    state = [
      for (final active in _entries)
        if (active.key != key) active.entry,
    ];
  }

  @override
  Future<void> reorderFace(
    PlaylistMediaFace face,
    List<String> orderedKeys,
  ) async {
    lastReorderFace = face;
    lastReorder = orderedKeys;
    final byKey = {for (final active in _entries) active.key: active.entry};
    state = [for (final key in orderedKeys) ?byKey[key]];
  }
}

Louvor _louvor(String pdfId, String numero, String nome, String classificacao) {
  return Louvor.fromManifest(
    nome: nome,
    numero: numero,
    categoria: 'Partitura',
    classificacao: classificacao,
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g-$pdfId',
  );
}

void main() {
  late SharedPreferences prefs;

  final manifest = {
    'a': _louvor('a', '001', 'Louvor A', 'ColAdultos'),
    'b': _louvor('b', '002', 'Louvor B', 'ColCIAs'),
    'c': _louvor('c', '003', 'Louvor C', 'ColAdultos'),
  };

  const entries = [
    PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
    PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
    PlaylistEntry(id: 'c', kind: MaterialKind.pdf),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSubject({
    required _FakeActiveEditor editor,
    Future<void> Function(CarouselItem item)? onOpen,
    Future<void> Function(CarouselItem item)? onRemoved,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        louvoresByPdfIdProvider.overrideWithValue(manifest),
        activePlaylistEditorProvider.overrideWith(() => editor),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: ActiveListPanel(onOpen: onOpen, onRemoved: onRemoved),
        ),
      ),
    );
  }

  testWidgets('exibe a face de partituras com metadados', (tester) async {
    await tester.pumpWidget(buildSubject(editor: _FakeActiveEditor(entries)));
    await tester.pumpAndSettle();

    expect(find.byType(CarouselLouvorChip), findsNWidgets(3));
    expect(find.textContaining('Coletânea Adultos'), findsNWidgets(2));
    expect(find.textContaining('Coletânea CIAs'), findsOneWidget);
  });

  testWidgets('a segunda entrada focada ganha destaque visual', (tester) async {
    // A pref de foco guarda a chave; a chave da primeira ocorrência é o
    // próprio id.
    await prefs.setString('carousel_focused_pdf_id', 'b');

    await tester.pumpWidget(buildSubject(editor: _FakeActiveEditor(entries)));
    await tester.pumpAndSettle();

    final a = tester.widget<Container>(
      find.byKey(const ValueKey('activeListPanelItem-a')),
    );
    final b = tester.widget<Container>(
      find.byKey(const ValueKey('activeListPanelItem-b')),
    );
    final c = tester.widget<Container>(
      find.byKey(const ValueKey('activeListPanelItem-c')),
    );

    expect(a.decoration, isNull, reason: 'não focada');
    expect(b.decoration, isNotNull, reason: 'focada');
    expect(c.decoration, isNull, reason: 'não focada');
  });

  testWidgets('reorder dispara reorderFace na face de partituras por chaves', (
    tester,
  ) async {
    final editor = _FakeActiveEditor(entries);
    await tester.pumpWidget(buildSubject(editor: editor));
    await tester.pumpAndSettle();

    final dragHandle = find.descendant(
      of: find.ancestor(
        of: find.textContaining('Louvor A'),
        matching: find.byType(ReorderableDragStartListener),
      ),
      matching: find.byIcon(Icons.drag_indicator),
    );
    await tester.drag(dragHandle, const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(editor.lastReorderFace, PlaylistMediaFace.pdf);
    expect(editor.lastReorder, ['b', 'c', 'a']);
  });

  testWidgets('× dispara removeByKey com a chave da ocorrência', (
    tester,
  ) async {
    final editor = _FakeActiveEditor(entries);
    CarouselItem? removed;

    await tester.pumpWidget(
      buildSubject(editor: editor, onRemoved: (item) async => removed = item),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.ancestor(
              of: find.textContaining('Louvor B'),
              matching: find.byType(CarouselLouvorChip),
            ),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(editor.removedKeys, ['b']);
    expect(removed?.materialId, 'b');
    expect(find.byType(CarouselLouvorChip), findsNWidgets(2));
  });

  testWidgets('toque foca a chave e dispara onOpen', (tester) async {
    final editor = _FakeActiveEditor(entries);
    CarouselItem? tapped;

    await tester.pumpWidget(
      buildSubject(editor: editor, onOpen: (item) async => tapped = item),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Louvor C'));
    await tester.pumpAndSettle();

    expect(tapped?.materialId, 'c');
    expect(tapped?.key, 'c');
    expect(prefs.getString('carousel_focused_pdf_id'), 'c');
  });

  testWidgets('sem onOpen o toque não faz nada', (tester) async {
    await tester.pumpWidget(buildSubject(editor: _FakeActiveEditor(entries)));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Louvor A'));
    await tester.pumpAndSettle();

    expect(prefs.getString('carousel_focused_pdf_id'), isNull);
  });
}
