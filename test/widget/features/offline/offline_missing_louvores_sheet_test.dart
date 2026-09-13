import '../../../support/fakes/fake_playlists_notifier.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_state.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_missing_louvores_provider.dart';
import 'package:coldigui/features/offline/presentation/widgets/offline_missing_louvores_sheet.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolve que encontra o índice apontando para um arquivo apagado.
class _DeletedPdfDownloadNotifier extends LouvorPdfDownloadNotifier {
  @override
  Map<String, LouvorPdfDownloadState> build() => const {};

  @override
  Future<LocalPdfSource> resolveLouvorPdf({
    required String pdfId,
    required String remotePath,
  }) async {
    throw PdfExternallyDeletedException(pdfId: pdfId);
  }
}

void main() {
  const material = 'Partitura';
  final pdfId = encodePdfId('ColAdultos/001.pdf');

  Louvor louvorFixture() => Louvor(
    nome: 'Aleluia',
    numero: '001',
    categoria: 'ColAdultos',
    classificacao: 'Partitura',
    pdf: 'ColAdultos/001.pdf',
    pdfId: pdfId,
    groupId: '001:aleluia',
    searchTitleNorm: 'aleluia',
    searchContentTokens: const [],
    searchCompactContent: '',
  );

  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  testWidgets(
    'PDF removido do dispositivo mostra o texto do l10n, não o genérico',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
            louvorPdfDownloadProvider.overrideWith(
              _DeletedPdfDownloadNotifier.new,
            ),
            offlineMissingLouvoresProvider(
              material,
            ).overrideWith((ref) async => [louvorFixture()]),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            // O sheet dá `pop` na própria rota antes de abrir o louvor, então
            // precisa ser uma rota de verdade sobre uma página base — senão o
            // `pop` derruba o `home` e não sobra ScaffoldMessenger para a
            // snackbar.
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Center(
                  child: ElevatedButton(
                    onPressed: () => showOfflineMissingLouvoresSheet(
                      context: context,
                      ref: ref,
                      material: material,
                    ),
                    child: const Text('abrir sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('abrir sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Aleluia'));
      await tester.pumpAndSettle();

      expect(find.text(pt.pdfExternallyDeleted), findsOneWidget);
      expect(find.text(pt.errorGeneric), findsNothing);
      expect(find.text(pt.pdfActionError), findsNothing);
    },
  );
}
