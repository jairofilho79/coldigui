import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/presentation/widgets/leaflet_content.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../helpers/praise_share_fixtures.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlist);

  final SavedPlaylist? _playlist;

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      _playlist?.playlistId == playlistId ? _playlist : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _pdf = PlaylistEntry(
  id: praiseMaterialId('p-a', 'partitura.pdf'),
  kind: MaterialKind.pdf,
);
final _audio = PlaylistEntry(
  id: praiseMaterialId('p-b', 'audio.mp3'),
  kind: MaterialKind.audio,
);
final _chord = PlaylistEntry(
  id: praiseMaterialId('p-c', 'cifra.chord'),
  kind: MaterialKind.chord,
);
final _shortIds = {_pdf.id: '1a2', _audio.id: '0c3', _chord.id: 'fff'};
const _url = 'https://v2.plpcg.com/?p=1a2-0c3-fff&n=Ensaio';

SavedPlaylist _ensaio(List<PlaylistEntry> entries) => SavedPlaylist(
  playlistId: 'p1',
  nome: 'Ensaio',
  entries: entries,
  createdAt: DateTime(2026, 9, 23),
);

PlaylistShareContext _shareContext(List<PlaylistEntry> entries) =>
    PlaylistShareContext(playlistId: 'p1', nome: 'Ensaio', entries: entries);

/// Monta o scope com a lista [playlist] no repositório e o catálogo
/// [shortIds] (padrão: [_shortIds]); devolve o contexto pronto e o sync
/// falso, que conta os `sync()` pedidos quando falta `shortId` (§4.2).
Future<(BuildContext, FakeColdigomCatalogSyncNotifier)> _pump(
  WidgetTester tester, {
  required SavedPlaylist? playlist,
  Map<String, String>? shortIds,
}) async {
  final repository = _FakePlaylistRepository(playlist);
  final catalog = shortIds ?? _shortIds;
  final sync = FakeColdigomCatalogSyncNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(repository),
        generatePlaylistShareUrlProvider.overrideWithValue(
          GeneratePlaylistShareUrl(
            repository,
            praiseShortIdOf: (id) => catalog[id],
          ),
        ),
        coldigomCatalogSyncProvider.overrideWith(() => sync),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  return (tester.element(find.byType(Scaffold)), sync);
}

/// `capture` que lê o [LeafletDocument] montado no overlay.
CaptureWidgetToPngFn _captureInto(
  WidgetTester tester,
  void Function(LeafletDocument) onDocument,
) {
  return (boundaryKey) async {
    // O overlay foi inserido, mas só constrói no próximo frame.
    await tester.pump();
    final content = tester.widget<LeafletContent>(find.byType(LeafletContent));
    onDocument(content.document);
    return const [1, 2, 3];
  };
}

void main() {
  testWidgets('Só o link partilha a URL por praise (PDF, áudio e cifra)', (
    tester,
  ) async {
    final (context, sync) = await _pump(
      tester,
      playlist: _ensaio([_pdf, _audio, _chord]),
    );
    final notifier = ProviderScope.containerOf(context)
        .read(playlistShareActionsProvider.notifier);
    String? sharedText;

    final ok = await notifier.share(
      context,
      _shareContext([_pdf, _audio, _chord]),
      PlaylistShareOption.link,
      sharePositionOrigin: null,
      share: (text, {subject, sharePositionOrigin}) async {
        sharedText = text;
      },
    );

    expect(ok, isTrue);
    expect(sharedText, _url);
    expect(sync.syncCalls, 0);
  });

  testWidgets('Folheto de lista com áudio e cifra leva link e QR', (
    tester,
  ) async {
    final (context, _) = await _pump(
      tester,
      playlist: _ensaio([_pdf, _audio, _chord]),
    );
    final notifier = ProviderScope.containerOf(context)
        .read(playlistShareActionsProvider.notifier);
    LeafletDocument? doc;
    String? capturedText;

    final ok = await notifier.share(
      context,
      _shareContext([_pdf, _audio, _chord]),
      PlaylistShareOption.linkWithLeaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
        capturedText = text;
      },
      capture: _captureInto(tester, (d) => doc = d),
    );

    expect(ok, isTrue);
    expect(doc?.shareUrl, _url);
    expect(capturedText, contains(_url));
  });

  testWidgets('«Gerar folheto» sai com o QR do link', (tester) async {
    final (context, _) = await _pump(
      tester,
      playlist: _ensaio([_pdf, _audio]),
      shortIds: {_pdf.id: '1a2', _audio.id: '0c3'},
    );
    final notifier = ProviderScope.containerOf(context)
        .read(playlistShareActionsProvider.notifier);
    LeafletDocument? doc;
    String? capturedSubject;
    String? capturedText;

    final ok = await notifier.share(
      context,
      _shareContext([_pdf, _audio]),
      PlaylistShareOption.leaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
        capturedSubject = subject;
        capturedText = text;
      },
      capture: _captureInto(tester, (d) => doc = d),
    );

    expect(ok, isTrue);
    expect(doc?.shareUrl, 'https://v2.plpcg.com/?p=1a2-0c3&n=Ensaio');
    expect(capturedSubject, 'Folheto PLPCG');
    expect(capturedText, isNull);
  });

  testWidgets('«Gerar folheto» de lista fora do repositório sai sem QR', (
    tester,
  ) async {
    final (context, sync) = await _pump(tester, playlist: null);
    final notifier = ProviderScope.containerOf(context)
        .read(playlistShareActionsProvider.notifier);
    LeafletDocument? doc;

    final ok = await notifier.share(
      context,
      _shareContext([_pdf]),
      PlaylistShareOption.leaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {},
      capture: _captureInto(tester, (d) => doc = d),
    );

    expect(ok, isTrue);
    expect(doc, isNotNull);
    expect(doc?.shareUrl, isNull);
    expect(sync.syncCalls, 0);
  });

  testWidgets(
    'leaflet com lista só de áudio gera folheto (não mostra playlistEmptyCarousel)',
    (tester) async {
      final (context, _) = await _pump(tester, playlist: _ensaio([_audio]));
      final notifier = ProviderScope.containerOf(context)
          .read(playlistShareActionsProvider.notifier);
      var shared = false;

      final ok = await notifier.share(
        context,
        _shareContext([_audio]),
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
    'praise sem shortId: Só o link falha com um snackbar e pede sync',
    (tester) async {
      final (context, sync) = await _pump(
        tester,
        playlist: _ensaio([_pdf, _audio]),
        shortIds: {_pdf.id: '1a2'},
      );
      final notifier = ProviderScope.containerOf(context)
          .read(playlistShareActionsProvider.notifier);
      String? sharedText;

      final ok = await notifier.share(
        context,
        _shareContext([_pdf, _audio]),
        PlaylistShareOption.link,
        sharePositionOrigin: null,
        share: (text, {subject, sharePositionOrigin}) async {
          sharedText = text;
        },
      );
      await tester.pump();

      expect(ok, isFalse);
      expect(sharedText, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(sync.syncCalls, 1);
    },
  );

  testWidgets('praise sem shortId: Folheto não captura nem partilha', (
    tester,
  ) async {
    final (context, sync) = await _pump(
      tester,
      playlist: _ensaio([_pdf, _audio]),
      shortIds: {_pdf.id: '1a2'},
    );
    final notifier = ProviderScope.containerOf(context)
        .read(playlistShareActionsProvider.notifier);
    var captured = false;
    var shared = false;

    final ok = await notifier.share(
      context,
      _shareContext([_pdf, _audio]),
      PlaylistShareOption.linkWithLeaflet,
      sharePositionOrigin: null,
      shareXFiles: (files, {subject, text, sharePositionOrigin}) async {
        shared = true;
      },
      capture: (boundaryKey) async {
        captured = true;
        return const [1, 2, 3];
      },
    );
    await tester.pump();

    expect(ok, isFalse);
    expect(captured, isFalse);
    expect(shared, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(sync.syncCalls, 1);
  });

  testWidgets(
    'playlist sem entradas: EmptyPlaylistShareException mostra exatamente '
    'um snackbar (o provider é o único dono do feedback)',
    (tester) async {
      final (context, _) = await _pump(tester, playlist: _ensaio(const []));
      final notifier = ProviderScope.containerOf(context)
          .read(playlistShareActionsProvider.notifier);

      final ok = await notifier.share(
        context,
        _shareContext([_pdf]),
        PlaylistShareOption.link,
        sharePositionOrigin: null,
      );
      await tester.pump();

      expect(ok, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
}
