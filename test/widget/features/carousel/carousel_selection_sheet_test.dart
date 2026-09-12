import '../../../support/fakes/fake_active_editor.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_selection_sheet.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _OpenSheetButton extends ConsumerWidget {
  const _OpenSheetButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => showCarouselSelectionSheet(context),
      child: const Text('open'),
    );
  }
}

void main() {
  late SharedPreferences prefs;

  final manifest = {
    'a': _louvor('a', '001', 'Louvor A', 'ColAdultos'),
    'b': _louvor('b', '002', 'Louvor B', 'ColCIAs'),
  };

  const entries = [
    PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
    PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSubject({
    required FakeActiveEditor editor,
    Widget body = const _OpenSheetButton(),
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
        home: Scaffold(body: body),
      ),
    );
  }

  testWidgets('remover dispara removeByKey com a chave da ocorrência', (
    tester,
  ) async {
    final editor = FakeActiveEditor(entries);

    await tester.pumpWidget(buildSubject(editor: editor));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(editor.removedKeys, ['a']);
  });

  testWidgets('o mesmo louvor repetido remove só a ocorrência tocada', (
    tester,
  ) async {
    final editor = FakeActiveEditor(const [
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
    ]);

    await tester.pumpWidget(buildSubject(editor: editor));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CarouselLouvorChip), findsNWidgets(3));

    // A segunda ocorrência tem a chave `a#1`; a primeira continua `a`.
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.close),
          )
          .at(1),
    );
    await tester.pumpAndSettle();

    expect(editor.removedKeys, ['a#1']);
    expect(find.byType(CarouselLouvorChip), findsNWidgets(2));
  });

  testWidgets('reorder dispara reorderFace na face de partituras por chaves', (
    tester,
  ) async {
    final editor = FakeActiveEditor(entries);

    await tester.pumpWidget(buildSubject(editor: editor));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dragHandle = find.descendant(
      of: find.ancestor(
        of: find.textContaining('Louvor A'),
        matching: find.byType(ReorderableDragStartListener),
      ),
      matching: find.byIcon(Icons.drag_indicator),
    );
    await tester.drag(dragHandle, const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(editor.lastReorder, ['b', 'a']);
  });

  testWidgets('toque no chip foca a chave e dispara onItemTap', (tester) async {
    final editor = FakeActiveEditor(entries);
    CarouselItem? tapped;

    await tester.pumpWidget(
      buildSubject(
        editor: editor,
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCarouselSelectionSheet(
              context,
              onItemTap: (item) async => tapped = item,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Louvor B'));
    await tester.pumpAndSettle();

    expect(tapped?.materialId, 'b');
    expect(tapped?.key, 'b');
    expect(find.byType(AlertDialog), findsNothing);
    expect(prefs.getString('carousel_focused_pdf_id'), 'b');
  });

  testWidgets('exibe chips temáticos com metadados', (tester) async {
    await tester.pumpWidget(buildSubject(editor: FakeActiveEditor(entries)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CarouselLouvorChip), findsNWidgets(2));
    expect(find.textContaining('Coletânea Adultos'), findsOneWidget);
    expect(find.textContaining('Coletânea CIAs'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
  });

  testWidgets('a chave da ocorrência é a ValueKey do item reordenável', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(editor: FakeActiveEditor(entries)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final keys = tester
        .widgetList<ReorderableDragStartListener>(
          find.byType(ReorderableDragStartListener),
        )
        .map((w) => w.key)
        .toList();
    expect(keys, [const ValueKey('a'), const ValueKey('b')]);
  });
}
