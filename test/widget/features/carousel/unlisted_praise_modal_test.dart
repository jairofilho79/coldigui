import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_list_panel.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';

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
    'unlisted_id': _louvor(
      'unlisted_id',
      '099',
      'Louvor Fora da Lista',
      'ColAdultos',
    ),
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSubject({
    required FakeActiveEditor editor,
    Future<void> Function(CarouselItem item)? onOpen,
    Future<void> Function(CarouselItem item)? onRemoved,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coldigomLouvoresOverride(manifest.values.toList()),
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

  group('ActiveListPanel - Desacoplamento e marcação zebrada', () {
    testWidgets(
      'quando louvor aberto nao esta na lista ativa, exibe secao de material em exibicao e divider',
      (tester) async {
        final editor = FakeActiveEditor([
          const PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
          const PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
        ]);

        await tester.pumpWidget(buildSubject(editor: editor));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ActiveListPanel)),
        );
        container.read(readerRouteParamsProvider.notifier).update({
          UrlSyncParams.pdfId: 'unlisted_id',
          UrlSyncParams.titulo: 'Louvor Fora da Lista',
          UrlSyncParams.subtitulo: '099',
        });
        await tester.pumpAndSettle();

        expect(
          find.text('Material em exibição (não está na lista)'),
          findsOneWidget,
        );
        expect(find.byType(Divider), findsOneWidget);
        expect(find.text('#099 — Louvor Fora da Lista'), findsOneWidget);

        final addButtons = find.byType(CarouselLouvorAddButton);
        expect(addButtons, findsOneWidget);

        expect(find.byType(ZebradaHighlight), findsNothing);

        await tester.tap(addButtons);
        await tester.pumpAndSettle();

        expect(editor.added, hasLength(1));
        expect(editor.added.first.id, 'unlisted_id');
      },
    );

    testWidgets(
      'quando louvor aberto esta na lista ativa, nao exibe secao unlisted e destaca com ZebradaHighlight exclusivamente o item atual',
      (tester) async {
        final editor = FakeActiveEditor([
          const PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
          const PlaylistEntry(id: 'b', kind: MaterialKind.pdf),
          const PlaylistEntry(id: 'c', kind: MaterialKind.pdf),
        ]);

        await tester.pumpWidget(buildSubject(editor: editor));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ActiveListPanel)),
        );
        container.read(readerRouteParamsProvider.notifier).update({
          UrlSyncParams.pdfId: 'b',
          UrlSyncParams.titulo: 'Louvor B',
          UrlSyncParams.subtitulo: '002',
        });
        await tester.pumpAndSettle();

        expect(
          find.text('Material em exibição (não está na lista)'),
          findsNothing,
        );
        expect(find.byType(Divider), findsNothing);

        expect(find.byType(ZebradaHighlight), findsOneWidget);
        expect(find.text('Atual'), findsOneWidget);

        final itemBHighlight = find.descendant(
          of: find.byKey(const ValueKey('activeListPanelItem-b')),
          matching: find.byType(ZebradaHighlight),
        );
        expect(itemBHighlight, findsOneWidget);

        final itemAHighlight = find.descendant(
          of: find.byKey(const ValueKey('activeListPanelItem-a')),
          matching: find.byType(ZebradaHighlight),
        );
        expect(itemAHighlight, findsNothing);

        final itemCHighlight = find.descendant(
          of: find.byKey(const ValueKey('activeListPanelItem-c')),
          matching: find.byType(ZebradaHighlight),
        );
        expect(itemCHighlight, findsNothing);
      },
    );

    testWidgets(
      'quando lista esta vazia e ha louvor aberto, exibe secao unlisted e mensagem de lista vazia com instrucao',
      (tester) async {
        final editor = FakeActiveEditor([]);

        await tester.pumpWidget(buildSubject(editor: editor));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ActiveListPanel)),
        );
        container.read(readerRouteParamsProvider.notifier).update({
          UrlSyncParams.pdfId: 'unlisted_id',
          UrlSyncParams.titulo: 'Louvor Fora da Lista',
          UrlSyncParams.subtitulo: '099',
        });
        await tester.pumpAndSettle();

        expect(
          find.text('Material em exibição (não está na lista)'),
          findsOneWidget,
        );
        expect(find.text('Nenhum louvor na lista atual'), findsOneWidget);
        expect(
          find.text('Toque no + acima para adicionar este louvor à lista'),
          findsOneWidget,
        );
        expect(find.byType(CarouselLouvorAddButton), findsOneWidget);
      },
    );
  });
}
