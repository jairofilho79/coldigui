import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/ports/share_link_shortener.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

class _LoggedInAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', sessionToken: 'token');
}

/// Encurtador que só conta chamadas — usado para provar que o share
/// (qualquer opção, gate Coldigom incluso) nunca bate no `/l/`, mesmo
/// autenticado: `_generateUrl` sempre pede `short: false` (débito: remover
/// o port junto com o gate Coldigom).
class _CountingShortener implements ShareLinkShortener {
  var callCount = 0;

  @override
  Future<String> shorten(String query) async {
    callCount++;
    return 'https://plpcg.com/l/abc1234';
  }
}

class _FakePlaylistRepository implements PlaylistRepository {
  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    return SavedPlaylist.fromLegacyLists(
      playlistId: playlistId,
      nome: 'Ensaio',
      pdfIds: const ['pdf-a'],
      createdAt: DateTime(2026, 6, 8),
    );
  }

  @override
  Future<String> create({
    required String nome,
    List<PlaylistEntry>? entries,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
    String? ownerSub,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String playlistId) => throw UnimplementedError();

  @override
  Future<void> deleteAllUnsaved() => throw UnimplementedError();

  @override
  Future<void> hardDelete(String playlistId) => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getAll() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getByTab(tab) => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones({String? sub}) =>
      throw UnimplementedError();

  @override
  Future<void> adoptForSub(String sub) => throw UnimplementedError();

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) =>
      throw UnimplementedError();

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) => throw UnimplementedError();

  @override
  Future<void> upsert(SavedPlaylist playlist) => throw UnimplementedError();

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<PlaylistEntry>? entries,
    List<String>? pdfIds,
    List<String>? audioIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => throw UnimplementedError();
}

class _EmptyEntriesPlaylistRepository extends _FakePlaylistRepository {
  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    return SavedPlaylist.fromLegacyLists(
      playlistId: playlistId,
      nome: 'Ensaio',
      createdAt: DateTime(2026, 6, 8),
    );
  }
}

/// `PlaylistEntry.classified` classifica pela extensão do id decodificado —
/// `pdf-a` não é um path Base64 válido, então viraria `MaterialKind.unknown`
/// (nunca `pdf`). O construtor canônico de [SavedPlaylist] deixa explícito
/// o `kind: MaterialKind.pdf`, como o vetor de contrato em
/// `generate_playlist_share_url_test.dart`.
class _PdfKindPlaylistRepository extends _FakePlaylistRepository {
  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    return SavedPlaylist(
      playlistId: playlistId,
      nome: 'Ensaio',
      entries: const [PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf)],
      createdAt: DateTime(2026, 6, 8),
    );
  }
}

void main() {
  final shareContext = PlaylistShareContext(
    playlistId: 'p1',
    nome: 'Ensaio',
    entries: [PlaylistEntry.classified('pdf-a')],
  );

  testWidgets('link only chama Share.share com URL', (tester) async {
    String? sharedText;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistRepositoryProvider.overrideWithValue(
            _PdfKindPlaylistRepository(),
          ),
          generatePlaylistShareUrlProvider.overrideWith(
            (ref) => GeneratePlaylistShareUrl(
              _PdfKindPlaylistRepository(),
              shareOrigin: 'https://plpcg.com',
              shortIdOf: (id) =>
                  ref.read(louvoresByPdfIdProvider)[id]?.shortId,
            ),
          ),
          louvoresManifestOverride(
            LouvoresManifest.fromLouvores([
              Louvor.fromManifest(
                nome: 'Louvor A',
                numero: '001',
                categoria: 'Partitura',
                classificacao: 'ColAdultos',
                pdf: 'a.pdf',
                pdfId: 'pdf-a',
                shortId: '0000',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final container = ProviderScope.containerOf(context);
    await container.read(louvoresManifestProvider.future);
    final notifier = container.read(playlistShareActionsProvider.notifier);

    final ok = await notifier.share(
      context,
      shareContext,
      PlaylistShareOption.link,
      sharePositionOrigin: null,
      share: (text, {subject, sharePositionOrigin}) async {
        sharedText = text;
      },
    );

    expect(ok, isTrue);
    expect(sharedText, 'https://plpcg.com/?s=0000&n=Ensaio');
  });

  testWidgets(
    'leaflet com lista só de áudio gera folheto (não mostra playlistEmptyCarousel)',
    (tester) async {
      final audioOnlyContext = PlaylistShareContext(
        playlistId: 'p1',
        nome: 'Ensaio',
        entries: [PlaylistEntry.audio('audio-1')],
      );
      var shared = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistRepositoryProvider.overrideWithValue(
              _FakePlaylistRepository(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(playlistShareActionsProvider.notifier);

      final ok = await notifier.share(
        context,
        audioOnlyContext,
        PlaylistShareOption.leaflet,
        sharePositionOrigin: null,
        shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
          shared = true;
        },
        capture: (boundaryKey) async => const [1, 2, 3],
      );

      expect(ok, isTrue);
      expect(shared, isTrue);
      expect(
        find.text(AppLocalizations.of(context)!.playlistEmptyCarousel),
        findsNothing,
      );
    },
  );

  testWidgets(
    'leaflet-only não chama o encurtador, autenticado ou não '
    '(/l/ não tem mais chamador no share)',
    (tester) async {
      final shortener = _CountingShortener();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistRepositoryProvider.overrideWithValue(
              _FakePlaylistRepository(),
            ),
            generatePlaylistShareUrlProvider.overrideWithValue(
              GeneratePlaylistShareUrl(
                _FakePlaylistRepository(),
                shareOrigin: 'https://plpcg.com',
                shortener: shortener,
              ),
            ),
            authStateProvider.overrideWith(_LoggedInAuth.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(playlistShareActionsProvider.notifier);

      final ok = await notifier.share(
        context,
        shareContext,
        PlaylistShareOption.leaflet,
        sharePositionOrigin: null,
        shareXFiles: (files, {subject, text, sharePositionOrigin}) async {},
        capture: (boundaryKey) async => const [1, 2, 3],
      );

      expect(ok, isTrue);
      expect(shortener.callCount, 0);
    },
  );

  testWidgets(
    'playlist sem entradas: EmptyPlaylistShareException retorna false e '
    'mostra exatamente um snackbar (o provider é o único dono do feedback)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistRepositoryProvider.overrideWithValue(
              _EmptyEntriesPlaylistRepository(),
            ),
            generatePlaylistShareUrlProvider.overrideWithValue(
              GeneratePlaylistShareUrl(
                _EmptyEntriesPlaylistRepository(),
                shareOrigin: 'https://plpcg.com',
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(playlistShareActionsProvider.notifier);

      final ok = await notifier.share(
        context,
        shareContext,
        PlaylistShareOption.link,
        sharePositionOrigin: null,
      );
      await tester.pump();

      expect(ok, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  // Duas `testWidgets` (em vez de uma única rodando `run()` duas vezes com o
  // mesmo `tester`): reusar o mesmo `ProviderScope`/`pumpWidget` entre as
  // duas chamadas manteve o container antigo vivo entre elas (Flutter
  // atualiza o `State` do `ProviderScope` em vez de recriá-lo), então o
  // segundo `run` viu de fato o manifest do primeiro. Cada `testWidgets`
  // aqui recebe seu próprio binding, garantindo isolamento real.
  testWidgets('linkWithLeaflet com link curto passa shareUrl ao folheto', (
    tester,
  ) async {
    final result = await _shareLinkWithLeaflet(
      tester,
      shareContext: shareContext,
      comShortId: true,
    );
    expect(result.capturedUrl, 'https://plpcg.com/?s=0000&n=Ensaio');
    expect(result.text, contains('https://plpcg.com/?s=0000&n=Ensaio'));
  });

  testWidgets(
    'linkWithLeaflet com lista fora do PLPCG abre dialog e, em Cancelar, '
    'não compartilha',
    (tester) async {
      final context = await _pumpOutOfPlpcgScope(tester);
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(playlistShareActionsProvider.notifier);
      List<XFile>? sharedFiles;

      final future = notifier.share(
        context,
        shareContext,
        PlaylistShareOption.linkWithLeaflet,
        sharePositionOrigin: null,
        shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
          sharedFiles = files;
        },
        capture: (boundaryKey) async => const [1, 2, 3],
      );
      await tester.pumpAndSettle();

      expect(find.text('Lista com materiais do Coldigom'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
      expect(sharedFiles, isNull);
    },
  );

  testWidgets(
    'linkWithLeaflet com lista fora do PLPCG e «Só o folheto» compartilha '
    'imagem sem texto e sem QR',
    (tester) async {
      final context = await _pumpOutOfPlpcgScope(tester);
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(playlistShareActionsProvider.notifier);
      String? sharedText;
      String? sharedSubject;
      LeafletDocument? capturedDoc;

      final future = notifier.share(
        context,
        shareContext,
        PlaylistShareOption.linkWithLeaflet,
        sharePositionOrigin: null,
        shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
          sharedText = text;
          sharedSubject = subject;
        },
        capture: (boundaryKey) async {
          // O overlay foi inserido, mas só constrói no próximo frame.
          await tester.pump();
          final content = tester.widget<LeafletContent>(
            find.byType(LeafletContent),
          );
          capturedDoc = content.document;
          return const [1, 2, 3];
        },
      );
      await tester.pumpAndSettle();

      // `tester.tap`/`pumpAndSettle` conflitaria com o `tester.pump()` que
      // `capture` chama dentro da própria continuação do toque
      // (TestAsyncUtils guarda os dois como não aninhados): aciona
      // `onPressed` direto e deixa `future` (que resolve via os `pump`s de
      // `capture`) dirigir o resto.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Só o folheto'),
      );
      button.onPressed!();

      expect(await future, isTrue);
      expect(sharedText, isNull);
      expect(sharedSubject, 'Folheto PLPCG');
      expect(capturedDoc?.shareUrl, isNull);
    },
  );

  testWidgets(
    'link com lista fora do PLPCG abre dialog só com «Entendi» e não '
    'compartilha',
    (tester) async {
      final context = await _pumpOutOfPlpcgScope(tester);
      final container = ProviderScope.containerOf(context);
      final notifier = container.read(playlistShareActionsProvider.notifier);
      String? sharedText;

      final future = notifier.share(
        context,
        shareContext,
        PlaylistShareOption.link,
        sharePositionOrigin: null,
        share: (text, {subject, sharePositionOrigin}) async {
          sharedText = text;
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Entendi'), findsOneWidget);
      expect(find.text('Só o folheto'), findsNothing);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
      expect(sharedText, isNull);
    },
  );
}

/// Monta o `ProviderScope` com uma lista fora do acervo PLPCG (PDF sem
/// `shortId` — gate Coldigom) e devolve o [BuildContext] já pronto, com o
/// manifest carregado.
Future<BuildContext> _pumpOutOfPlpcgScope(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(
          _PdfKindPlaylistRepository(),
        ),
        generatePlaylistShareUrlProvider.overrideWith(
          (ref) => GeneratePlaylistShareUrl(
            _PdfKindPlaylistRepository(),
            shareOrigin: 'https://plpcg.com',
            shortIdOf: (id) => ref.read(louvoresByPdfIdProvider)[id]?.shortId,
          ),
        ),
        louvoresManifestOverride(
          LouvoresManifest.fromLouvores([
            Louvor.fromManifest(
              nome: 'Louvor A',
              numero: '001',
              categoria: 'Partitura',
              classificacao: 'ColAdultos',
              pdf: 'a.pdf',
              pdfId: 'pdf-a',
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  final context = tester.element(find.byType(Scaffold));
  final container = ProviderScope.containerOf(context);
  await container.read(louvoresManifestProvider.future);
  return context;
}

/// Roda `share(linkWithLeaflet)` de ponta a ponta e devolve o `shareUrl`
/// que chegou ao [LeafletDocument] capturado e o texto compartilhado — prova
/// a regra D10 (QR/link no folheto só com link curto) no fluxo real.
Future<({String? capturedUrl, String? text})> _shareLinkWithLeaflet(
  WidgetTester tester, {
  required PlaylistShareContext shareContext,
  required bool comShortId,
}) async {
  String? capturedText;
  LeafletDocument? doc;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(
          _PdfKindPlaylistRepository(),
        ),
        generatePlaylistShareUrlProvider.overrideWith(
          (ref) => GeneratePlaylistShareUrl(
            _PdfKindPlaylistRepository(),
            shareOrigin: 'https://plpcg.com',
            shortIdOf: (id) => ref.read(louvoresByPdfIdProvider)[id]?.shortId,
          ),
        ),
        louvoresManifestOverride(
          LouvoresManifest.fromLouvores([
            Louvor.fromManifest(
              nome: 'Louvor A',
              numero: '001',
              categoria: 'Partitura',
              classificacao: 'ColAdultos',
              pdf: 'a.pdf',
              pdfId: 'pdf-a',
              shortId: comShortId ? '0000' : null,
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  final context = tester.element(find.byType(Scaffold));
  final container = ProviderScope.containerOf(context);
  await container.read(louvoresManifestProvider.future);
  final notifier = container.read(playlistShareActionsProvider.notifier);
  await notifier.share(
    context,
    shareContext,
    PlaylistShareOption.linkWithLeaflet,
    sharePositionOrigin: null,
    shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
      capturedText = text;
    },
    capture: (boundaryKey) async {
      // O overlay foi inserido, mas só constrói no próximo frame.
      await tester.pump();
      final content = tester.widget<LeafletContent>(
        find.byType(LeafletContent),
      );
      doc = content.document;
      return const [1, 2, 3];
    },
  );
  return (capturedUrl: doc?.shareUrl, text: capturedText);
}
