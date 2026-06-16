import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/offline/data/datasources/disk_space_checker.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localPdfPath = '/tmp/plpcg_pdfs/ColAdultos/001.pdf';
const _groupId = '001:aleluia';

String _pdfIdForPath(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

Louvor _louvor({
  required String nome,
  required String categoria,
  required String pdf,
  required String relPath,
}) {
  return Louvor.fromManifest(
    nome: nome,
    numero: '001',
    categoria: categoria,
    classificacao: 'ColAdultos',
    pdf: pdf,
    pdfId: _pdfIdForPath(relPath),
    groupId: _groupId,
  );
}

Louvor _singleLouvor({required String nome}) {
  return _louvor(
    nome: nome,
    categoria: 'Partitura',
    pdf: '001.pdf',
    relPath: 'assets/ColAdultos/001.pdf',
  );
}

LouvorGroup _multiMaterialGroup() {
  return LouvorGroup.fromLouvores([
    _louvor(
      nome: 'Aleluia',
      categoria: 'Partitura',
      pdf: '001.pdf',
      relPath: 'assets/ColAdultos/001.pdf',
    ),
    _louvor(
      nome: 'Aleluia',
      categoria: 'Cifra',
      pdf: '001-cifra.pdf',
      relPath: 'assets/ColAdultos/001-cifra.pdf',
    ),
  ]).first;
}

class _StubDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBytesDatasource extends PdfBytesDatasource {
  _FakeBytesDatasource(this._bytes) : super(_StubDio());

  final Uint8List _bytes;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
  }) async =>
      _bytes;
}

class _FakeResolvePdfForReader extends ResolvePdfForReader {
  _FakeResolvePdfForReader()
      : super(_UnusedRepository(), _UnusedFetchAndStorePdf());

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    return const LocalPdfSource(
      pdfId: 'fake',
      absolutePath: _localPdfPath,
      fromCache: true,
    );
  }
}

class _UnusedRepository implements OfflinePdfRepository {
  @override
  Future<Map<String, int>> countByCategory() => throw UnimplementedError();

  @override
  Future<OfflinePdfEntry?> findIndexEntry(String pdfId) =>
      throw UnimplementedError();

  @override
  Future<List<OfflinePdfEntry>> listAll() => throw UnimplementedError();

  @override
  Future<OfflinePdfEntry?> lookup(String pdfId) => throw UnimplementedError();

  @override
  Future<(OfflinePdfEntry? entry, bool hasIndexEntry)> lookupWithIndexState(
    String pdfId,
  ) =>
      throw UnimplementedError();

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) =>
      throw UnimplementedError();

  @override
  Future<void> remove(String pdfId) => throw UnimplementedError();

  @override
  Future<String?> findPdfIdByAbsolutePath(String absolutePath) async => null;

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> indexExtractedBatch(List<ExtractedPdfItem> items) =>
      throw UnimplementedError();

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) =>
      throw UnimplementedError();

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) =>
      throw UnimplementedError();

  @override
  Future<void> clearAll() => throw UnimplementedError();

  @override
  Future<int> totalCachedBytes() async => 0;

  @override
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  }) async =>
      0;

  @override
  Future<void> flushPendingTouchLastAccessed() async {}
}

class _UnusedFetchAndStorePdf extends FetchAndStorePdf {
  _UnusedFetchAndStorePdf()
      : super(
          _FakeBytesDatasource(Uint8List(0)),
          _UnusedRepository(),
          diskSpaceChecker: _UnusedDiskSpaceChecker(),
          favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
        );
}

class _UnusedDiskSpaceChecker extends DiskSpaceChecker {
  @override
  Future<int?> getFreeBytes() async => 999999999;
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<String> ensurePlaylistForLouvor(String pdfId) async => 'fake-playlist';

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async => true;
}

class _RecordingPlaylistsNotifier extends PlaylistsNotifier {
  String? lastAddedPdfId;

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<String> ensurePlaylistForLouvor(String pdfId) async => 'fake-playlist';

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async {
    lastAddedPdfId = pdfId;
    return true;
  }
}

List<Override> _commonOverrides() {
  return [
    resolvePdfForReaderProvider.overrideWithValue(_FakeResolvePdfForReader()),
    carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
    playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
  ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LouvorCard tap abre o leitor interno em /leitor',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, __) => Scaffold(
            body: LouvorCard(louvor: _singleLouvor(nome: 'Aleluia')),
          ),
        ),
        GoRoute(
          path: RoutePaths.reader,
          builder: (_, __) => const Scaffold(body: Text('Leitor aberto')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ..._commonOverrides(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
        ),
      ),
    );

    await tester.tap(find.textContaining('Aleluia'));
    await tester.pumpAndSettle();

    expect(find.text('Leitor aberto'), findsOneWidget);
    expect(router.state.uri.path, RoutePaths.reader);
    expect(router.state.uri.queryParameters['file'], _localPdfPath);
    expect(router.state.uri.queryParameters['titulo'], 'Aleluia');
  });

  testWidgets('LouvorCard com 1 material não exibe menu compartilhar no card',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ..._commonOverrides(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: LouvorCard(louvor: _singleLouvor(nome: 'Aleluia')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('LouvorGroupCard com vários materiais não exibe + no card',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ..._commonOverrides(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: LouvorGroupCard(group: _multiMaterialGroup()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('LouvorGroupCard com vários materiais adiciona pelo sheet',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final playlists = _RecordingPlaylistsNotifier();
    final cifraPdfId = _pdfIdForPath('assets/ColAdultos/001-cifra.pdf');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ..._commonOverrides(),
          playlistsProvider.overrideWith(() => playlists),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: LouvorGroupCard(group: _multiMaterialGroup()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Aleluia'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.add), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();

    expect(playlists.lastAddedPdfId, cifraPdfId);
    expect(find.text('Adicionado à seleção'), findsOneWidget);
  });
}
