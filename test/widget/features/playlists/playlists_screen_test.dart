import 'dart:async';

import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/pages/playlists_screen.dart';
import 'package:coldigui/features/playlists/domain/usecases/sync_playlists.dart';
import 'package:coldigui/features/playlists/presentation/widgets/import_playlist_dialog.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_sync_error_banner.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoggedOutAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  _FakePlaylistsNotifier(this.initial, {this.deleteAllUnsavedThrows});

  final List<PlaylistViewItem> initial;
  final Object? deleteAllUnsavedThrows;
  ImportPlaylistDialogResult? lastImport;
  var reloadCalls = 0;

  @override
  List<PlaylistViewItem> build() => initial;

  @override
  Future<void> reload() async {
    reloadCalls++;
  }

  @override
  Future<void> deleteAllUnsaved() async {
    final error = deleteAllUnsavedThrows;
    if (error != null) throw error;
  }

  @override
  Future<String?> importSharedFromUrl({
    required String shareName,
    String sharePdfs = '',
    String shareAudios = '',
    String shareItems = '',
  }) async {
    lastImport = ImportPlaylistDialogResult(
      sharePdfs: sharePdfs,
      shareAudios: shareAudios,
      shareItems: shareItems,
      shareName: shareName,
    );
    return 'imported-id';
  }
}

/// Estado de sync fixo, sem `ref.listen` de auth nem rede.
///
/// [gate], quando informado, segura o `sync()` até o teste completá-lo — é
/// assim que se descarta a tela no meio de um retry.
class _FakeSyncNotifier extends PlaylistSyncNotifier {
  _FakeSyncNotifier([
    this.initial = const PlaylistSyncState(),
    this.result = const PlaylistSyncResult(),
    this.gate,
  ]);

  final PlaylistSyncState initial;
  final PlaylistSyncResult result;
  final Completer<void>? gate;
  var syncCalls = 0;

  @override
  PlaylistSyncState build() => initial;

  @override
  Future<PlaylistSyncResult> sync() async {
    syncCalls++;
    await gate?.future;
    // Como o notifier real: a tela recarrega quando a rodada moveu linhas.
    if (result.movedRows && ref.mounted) {
      await ref.read(playlistsProvider.notifier).reload();
    }
    return result;
  }
}

/// Sync que o teste move de estado depois da montagem — é como se observa o
/// `ref.listen` da tela, que só dispara em transição.
class _MutableSyncNotifier extends PlaylistSyncNotifier {
  @override
  PlaylistSyncState build() => const PlaylistSyncState();

  void emit(PlaylistSyncState next) => state = next;

  @override
  Future<PlaylistSyncResult> sync() async => const PlaylistSyncResult();
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildSubject(List<PlaylistViewItem> items) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_LoggedOutAuth.new),
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
      playlist: SavedPlaylist.fromLegacyLists(
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(_LoggedOutAuth.new),
          playlistsProvider.overrideWith(() => notifier),
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
      'shareitems=p:x,a:aud-1,p:y&sharename=Teste&sharepdfs=x,y'
      '&shareaudios=aud-1',
    );
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    // O `shareitems` colado tem que atravessar diálogo → tela → notifier: é ele
    // que carrega a ordem intercalada que `sharepdfs`/`shareaudios` perdem.
    expect(notifier.lastImport?.shareItems, 'p:x,a:aud-1,p:y');
    expect(notifier.lastImport?.sharePdfs, 'x,y');
    expect(notifier.lastImport?.shareAudios, 'aud-1');
    expect(notifier.lastImport?.shareName, 'Teste');
    expect(
      PlaylistShareParams(
        sharePdfs: notifier.lastImport!.sharePdfs,
        shareAudios: notifier.lastImport!.shareAudios,
        shareItems: notifier.lastImport!.shareItems,
        shareName: notifier.lastImport!.shareName,
      ).entries,
      const [
        PlaylistEntry(id: 'x', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
        PlaylistEntry(id: 'y', kind: MaterialKind.pdf),
      ],
    );
    expect(find.text('Lista importada'), findsOneWidget);
  });

  // D6: importar cria uma lista nova e a torna ativa — a anterior continua
  // salva, então não há "substituição" a confirmar (paridade com o deep link).
  testWidgets('importar por URL não pede confirmação', (tester) async {
    final notifier = _FakePlaylistsNotifier(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(_LoggedOutAuth.new),
          playlistsProvider.overrideWith(() => notifier),
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

    expect(find.text('Substituir seleção?'), findsNothing);
    expect(find.text('Confirmar'), findsNothing);
    expect(notifier.lastImport?.shareName, 'Teste');
    expect(find.text('Lista importada'), findsOneWidget);
  });

  testWidgets('importar URL legada (sem shareitems) segue funcionando', (
    tester,
  ) async {
    final notifier = _FakePlaylistsNotifier(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(_LoggedOutAuth.new),
          playlistsProvider.overrideWith(() => notifier),
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
    expect(notifier.lastImport?.shareItems, '');
    expect(notifier.lastImport?.shareName, 'Teste');
    expect(find.text('Lista importada'), findsOneWidget);
  });

  Widget buildWithSync(
    PlaylistSyncNotifier syncNotifier, {
    PlaylistsNotifier? playlists,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_LoggedOutAuth.new),
        playlistsProvider.overrideWith(
          () => playlists ?? _FakePlaylistsNotifier(const []),
        ),
        playlistSyncProvider.overrideWith(() => syncNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const PlaylistsScreen(),
      ),
    );
  }

  testWidgets('sync sem problema não mostra banner', (tester) async {
    await tester.pumpWidget(buildWithSync(_FakeSyncNotifier()));
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistSyncErrorBanner), findsOneWidget);
    expect(find.text('Não foi possível sincronizar suas listas'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('erro de sync vira banner traduzido com Tentar novamente', (
    tester,
  ) async {
    final syncNotifier = _FakeSyncNotifier(
      const PlaylistSyncState(
        lastErrorCause: StorageUnavailableException('sem storage'),
      ),
    );
    await tester.pumpWidget(buildWithSync(syncNotifier));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível sincronizar suas listas'),
      findsOneWidget,
    );
    // Mensagem do `userMessageFor`, não o `toString()` da exceção.
    expect(
      find.text(
        'Armazenamento local indisponível. Recarregue a página ou libere espaço.',
      ),
      findsOneWidget,
    );

    // A tela já sincroniza sozinha ao montar (lifecycle): o que importa é o
    // toque somar mais uma.
    final before = syncNotifier.syncCalls;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(syncNotifier.syncCalls, before + 1);
  });

  testWidgets('conflitos aparecem no banner', (tester) async {
    await tester.pumpWidget(
      buildWithSync(_FakeSyncNotifier(const PlaylistSyncState(conflicts: 1))),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 lista em conflito'), findsOneWidget);
  });

  testWidgets('erro e conflito convivem no mesmo banner', (tester) async {
    await tester.pumpWidget(
      buildWithSync(
        _FakeSyncNotifier(
          const PlaylistSyncState(
            lastErrorCause: StorageUnavailableException('sem storage'),
            conflicts: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível sincronizar suas listas'),
      findsOneWidget,
    );
    expect(find.text('2 listas em conflito'), findsOneWidget);
  });

  testWidgets('cópia guardada no 409 aparece no banner (A.3)', (tester) async {
    await tester.pumpWidget(
      buildWithSync(
        _FakeSyncNotifier(
          const PlaylistSyncState(conflictCopies: ['Culto (cópia local)']),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Edições locais de «Culto» guardadas em «Culto (cópia local)»'),
      findsOneWidget,
    );
  });

  testWidgets('remoção em outro aparelho vira snackbar (A.2)', (tester) async {
    final syncNotifier = _MutableSyncNotifier();
    await tester.pumpWidget(buildWithSync(syncNotifier));
    await tester.pumpAndSettle();

    syncNotifier.emit(
      const PlaylistSyncState(
        lastResult: PlaylistSyncResult(deletedRemotely: 2),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('2 listas removidas em outro aparelho'), findsOneWidget);
  });

  testWidgets('sync sem remoção remota não mostra snackbar', (tester) async {
    final syncNotifier = _MutableSyncNotifier();
    await tester.pumpWidget(buildWithSync(syncNotifier));
    await tester.pumpAndSettle();

    syncNotifier.emit(
      const PlaylistSyncState(lastResult: PlaylistSyncResult(pulled: 3)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('retry que move linhas recarrega a lista visível', (
    tester,
  ) async {
    final playlists = _FakePlaylistsNotifier(const []);
    final syncNotifier = _FakeSyncNotifier(
      const PlaylistSyncState(
        lastErrorCause: StorageUnavailableException('sem storage'),
      ),
      const PlaylistSyncResult(pulled: 1),
    );
    await tester.pumpWidget(buildWithSync(syncNotifier, playlists: playlists));
    await tester.pumpAndSettle();

    final before = playlists.reloadCalls;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(playlists.reloadCalls, before + 1);
  });

  testWidgets('sair da tela no meio do retry não explode', (tester) async {
    final gate = Completer<void>();
    final playlists = _FakePlaylistsNotifier(const []);
    final syncNotifier = _FakeSyncNotifier(
      const PlaylistSyncState(
        lastErrorCause: StorageUnavailableException('sem storage'),
      ),
      const PlaylistSyncResult(pulled: 1),
      gate,
    );
    await tester.pumpWidget(buildWithSync(syncNotifier, playlists: playlists));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    // Some com a tela (e com o ProviderScope) antes de a sync responder.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('retry sem novidade não recarrega a lista', (tester) async {
    final playlists = _FakePlaylistsNotifier(const []);
    final syncNotifier = _FakeSyncNotifier(
      const PlaylistSyncState(
        lastErrorCause: StorageUnavailableException('sem storage'),
      ),
    );
    await tester.pumpWidget(buildWithSync(syncNotifier, playlists: playlists));
    await tester.pumpAndSettle();

    final before = playlists.reloadCalls;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(playlists.reloadCalls, before);
  });

  testWidgets('storage indisponível ao limpar rascunhos vira snackbar', (
    tester,
  ) async {
    final playlists = _FakePlaylistsNotifier(
      const [],
      deleteAllUnsavedThrows: StorageUnavailableException('sem storage'),
    );
    await tester.pumpWidget(
      buildWithSync(_FakeSyncNotifier(), playlists: playlists),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Armazenamento local indisponível. Recarregue a página ou libere espaço.',
      ),
      findsOneWidget,
    );
  });
}
