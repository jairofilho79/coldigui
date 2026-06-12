import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/pages/playlists_screen.dart';
import 'package:coldigui/features/playlists/presentation/widgets/import_playlist_dialog.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  _FakePlaylistsNotifier(this.initial);

  final List<PlaylistViewItem> initial;
  ImportPlaylistDialogResult? lastImport;

  @override
  List<PlaylistViewItem> build() => initial;

  @override
  Future<String?> importSharedFromUrl({
    required String sharePdfs,
    required String shareName,
  }) async {
    lastImport = ImportPlaylistDialogResult(
      sharePdfs: sharePdfs,
      shareName: shareName,
    );
    return 'imported-id';
  }
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;

  @override
  List<CarouselItem> build() => initial;
}

void main() {
  Widget buildSubject(List<PlaylistViewItem> items) {
    return ProviderScope(
      overrides: [
        playlistsProvider.overrideWith(() => _FakePlaylistsNotifier(items)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const PlaylistsScreen(),
      ),
    );
  }

  testWidgets('exibe estado vazio', (tester) async {
    await tester.pumpWidget(buildSubject(const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhuma lista não salva'), findsOneWidget);
  });

  testWidgets('renderiza playlist salva', (tester) async {
    final item = PlaylistViewItem(
      playlist: SavedPlaylist(
        playlistId: 'p1',
        nome: 'Ensaio domingo',
        pdfIds: ['a', 'b'],
        createdAt: DateTime(2026, 6, 8),
      ),
      pdfLabels: ['001 — A', '002 — B'],
    );

    await tester.pumpWidget(buildSubject([item]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvas'));
    await tester.pumpAndSettle();

    expect(find.text('Ensaio domingo'), findsOneWidget);
    expect(find.text('2 louvores'), findsOneWidget);
  });

  testWidgets('exibe FAB importar lista', (tester) async {
    await tester.pumpWidget(buildSubject(const []));
    await tester.pumpAndSettle();

    expect(find.text('Importar lista'), findsOneWidget);
  });

  testWidgets('importar via FAB dispara importSharedFromUrl', (tester) async {
    final notifier = _FakePlaylistsNotifier(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistsProvider.overrideWith(() => notifier),
          carouselLouvoresProvider.overrideWith(
            () => _FakeCarouselNotifier(const []),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const PlaylistsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar lista'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'sharepdfs=x&sharename=Teste',
    );
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(notifier.lastImport?.sharePdfs, 'x');
    expect(notifier.lastImport?.shareName, 'Teste');
    expect(find.text('Lista importada'), findsOneWidget);
  });
}
