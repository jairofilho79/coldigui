import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

/// Reproduz a cadeia de campo do `navigateToPdfId` real para PDFs: o warmup
/// Coldigom escreve no cache (o lookup e a lista re-emitem, a barra
/// reconstrói) **antes** de o arquivo resolver, e a resolução leva mais de
/// um frame — só então a rota é trocada.
class _SlowReaderActions extends ReaderCarouselActionsNotifier {
  final resolutions = <Completer<void>>[];

  @override
  void build() {}

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
      _louvor('z', '999', 'Fora da lista'),
    ]);
    final resolution = Completer<void>();
    resolutions.add(resolution);
    await resolution.future;
    return '${RoutePaths.reader}?pdfId=$targetPdfId&file=asset:fixtures/sample.pdf';
  }
}

Louvor _louvor(String pdfId, String numero, String nome) {
  return Louvor.fromManifest(
    nome: nome,
    numero: numero,
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g-$pdfId',
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final manifest = {
    'a': _louvor('a', '001', 'Louvor A'),
    'b': _louvor('b', '002', 'Louvor B'),
    'c': _louvor('c', '003', 'Louvor C'),
    'd': _louvor('d', '004', 'Louvor D'),
  };

  testWidgets('a lista re-emitir durante a resolução do PDF não devolve o foco ao '
      'louvor da rota antiga', (tester) async {
    final actions = _SlowReaderActions();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresByPdfIdProvider.overrideWithValue(manifest),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor([
              for (final id in const ['a', 'b', 'c', 'd'])
                PlaylistEntry(id: id, kind: MaterialKind.pdf),
            ]),
          ),
          playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
          readerCarouselActionsProvider.overrideWith(() => actions),
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

    // Abrir «b» pela rota (deep link) foca «b» na barra.
    router.go(
      '${RoutePaths.reader}?pdfId=b&file=asset:fixtures/sample.pdf&titulo=Louvor%20B',
    );
    await tester.pumpAndSettle();
    expect(prefs.getString('carousel_focused_pdf_id'), 'b');

    // 1ª seta: b → c. O foco vai para «c» na hora; a rota ainda é «b».
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      prefs.getString('carousel_focused_pdf_id'),
      'c',
      reason: 'a barra reconstruiu com a rota velha e devolveu o foco',
    );

    actions.resolutions.single.complete();
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['pdfId'], 'c');
    expect(prefs.getString('carousel_focused_pdf_id'), 'c');

    // 2ª seta: c → d. A rota anterior («c») já foi sincronizada, então a
    // reconstrução no meio da resolução também não pode voltar para «c».
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(prefs.getString('carousel_focused_pdf_id'), 'd');

    actions.resolutions.last.complete();
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['pdfId'], 'd');
    expect(prefs.getString('carousel_focused_pdf_id'), 'd');
  });
}
