import 'dart:async';

import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/providers/offline_core_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _relPath = 'assets/ColAdultos/001.pdf';
final _pdfId = encodePdfId(_relPath);
final _louvor = Louvor.fromManifest(
  nome: 'Aleluia',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: _pdfId,
);
const _source = LocalPdfSource(
  pdfId: 'pdf-1',
  absolutePath: '/tmp/aleluia.pdf',
  fromCache: true,
);

class _StubOfflinePdfRepository implements OfflinePdfRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubFetchAndStorePdf extends FetchAndStorePdf {
  _StubFetchAndStorePdf()
    : super(
        PdfBytesDatasource(Dio()),
        _StubOfflinePdfRepository(),
        favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
      );
}

/// Resolver controlável — devolve o que [_handler] disser, sem tocar rede/Isar.
class _ControllableResolvePdfForReader extends ResolvePdfForReader {
  _ControllableResolvePdfForReader(this._handler)
    : super(_StubOfflinePdfRepository(), _StubFetchAndStorePdf());

  final Future<LocalPdfSource> Function() _handler;
  int callCount = 0;

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) {
    callCount++;
    return _handler();
  }
}

/// Playlist ativa que sempre falha ao adicionar (ex.: Isar indisponível).
class _ThrowingPlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) {
    throw StateError('Isar indisponível');
  }
}

/// Playlist ativa que registra a chamada e completa de imediato.
class _RecordingPlaylistsNotifier extends PlaylistsNotifier {
  String? lastAddedPdfId;

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async {
    lastAddedPdfId = pdfId;
    return true;
  }
}

/// Playlist ativa cujo `add` fica preso até [gate] completar — usada para
/// provar que a resolução do PDF não espera a playlist (execução paralela).
class _GatedPlaylistsNotifier extends PlaylistsNotifier {
  final gate = Completer<bool>();

  @override
  List<PlaylistViewItem> build() => const [];

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) => gate.future;
}

GoRouter _buildRouter({
  required void Function(BuildContext, WidgetRef) onBuild,
}) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            onBuild(context, ref);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
      GoRoute(
        path: RoutePaths.reader,
        builder: (_, _) => const Scaffold(body: Text('Leitor aberto')),
      ),
    ],
  );
}

Widget _harness(GoRouter router, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
    ),
  );
}

void main() {
  testWidgets(
    'playlist ativa falhando (Isar indisponível) não impede abrir o leitor',
    (tester) async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };

      try {
        late BuildContext capturedContext;
        late WidgetRef capturedRef;

        final router = _buildRouter(
          onBuild: (context, ref) {
            capturedContext = context;
            capturedRef = ref;
          },
        );

        await tester.pumpWidget(
          _harness(router, [
            playlistsProvider.overrideWith(_ThrowingPlaylistsNotifier.new),
            ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
              (Louvor _) async {},
            ),
            resolvePdfForReaderProvider.overrideWithValue(
              _ControllableResolvePdfForReader(() async => _source),
            ),
          ]),
        );
        await tester.pump();

        await openLouvorInReader(
          ref: capturedRef,
          context: capturedContext,
          louvor: _louvor,
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, RoutePaths.reader);
        expect(find.text('Leitor aberto'), findsOneWidget);
        expect(
          logs.any((l) => l.contains('[catalog]') && l.contains('playlist')),
          isTrue,
        );
      } finally {
        debugPrint = originalDebugPrint;
      }
    },
  );

  testWidgets(
    'warmup Coldigom que nunca completa não atrasa a abertura do leitor',
    (tester) async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };

      try {
        final warmupNeverCompletes = Completer<void>();
        late BuildContext capturedContext;
        late WidgetRef capturedRef;

        final router = _buildRouter(
          onBuild: (context, ref) {
            capturedContext = context;
            capturedRef = ref;
          },
        );

        await tester.pumpWidget(
          _harness(router, [
            playlistsProvider.overrideWith(_RecordingPlaylistsNotifier.new),
            ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
              (Louvor _) => warmupNeverCompletes.future,
            ),
            resolvePdfForReaderProvider.overrideWithValue(
              _ControllableResolvePdfForReader(() async => _source),
            ),
          ]),
        );
        await tester.pump();

        unawaited(
          openLouvorInReader(
            ref: capturedRef,
            context: capturedContext,
            louvor: _louvor,
          ),
        );

        // Só flusha microtasks/futures síncronos — nada de tempo real de 10s
        // (nem os 5s do timeout) precisa se passar para a navegação ocorrer.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(
          router.state.uri.path,
          RoutePaths.reader,
          reason: 'não deve esperar um warmup que nunca completa',
        );

        // Simula os "10s" do enunciado — o warmup deve estourar o timeout de
        // 5s internamente, em silêncio, sem afetar o que já navegou.
        await tester.pump(const Duration(seconds: 10));
        expect(logs.any((l) => l.contains('[coldigom] warmup falhou')), isTrue);
      } finally {
        debugPrint = originalDebugPrint;
      }
    },
  );

  testWidgets('warmup Coldigom que lança não impede abrir o leitor', (
    tester,
  ) async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };

    try {
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      final router = _buildRouter(
        onBuild: (context, ref) {
          capturedContext = context;
          capturedRef = ref;
        },
      );

      await tester.pumpWidget(
        _harness(router, [
          playlistsProvider.overrideWith(_RecordingPlaylistsNotifier.new),
          ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
            (Louvor _) async => throw StateError('coldigom indisponível'),
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _ControllableResolvePdfForReader(() async => _source),
          ),
        ]),
      );
      await tester.pump();

      await openLouvorInReader(
        ref: capturedRef,
        context: capturedContext,
        louvor: _louvor,
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, RoutePaths.reader);
      expect(logs.any((l) => l.contains('[coldigom] warmup falhou')), isTrue);
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  testWidgets(
    'resolve do PDF dispara mesmo com addLouvorToActivePlaylist ainda pendente '
    '(execução em paralelo, não sequencial)',
    (tester) async {
      final gatedPlaylists = _GatedPlaylistsNotifier();
      final resolve = _ControllableResolvePdfForReader(() async => _source);
      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      final router = _buildRouter(
        onBuild: (context, ref) {
          capturedContext = context;
          capturedRef = ref;
        },
      );

      await tester.pumpWidget(
        _harness(router, [
          playlistsProvider.overrideWith(() => gatedPlaylists),
          ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
            (Louvor _) async {},
          ),
          resolvePdfForReaderProvider.overrideWithValue(resolve),
        ]),
      );
      await tester.pump();

      unawaited(
        openLouvorInReader(
          ref: capturedRef,
          context: capturedContext,
          louvor: _louvor,
        ),
      );

      // addLouvorToActivePlaylist está preso em `gatedPlaylists.gate` — se o
      // resolve do PDF só disparasse depois dela terminar (sequencial, como
      // antes), `resolve.callCount` continuaria 0 aqui.
      await tester.pump();
      await tester.pump();

      expect(
        resolve.callCount,
        1,
        reason: 'resolveLouvorPdf deve disparar mesmo com a playlist pendente',
      );
      expect(
        router.state.uri.path,
        RoutePaths.home,
        reason: 'ainda aguardando addLouvorToActivePlaylist (Future.wait)',
      );

      gatedPlaylists.gate.complete(true);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, RoutePaths.reader);
    },
  );

  group('louvorPdfErrorMessage', () {
    const generic = 'Não foi possível concluir a ação';

    test('caminho inválido cai na mensagem genérica', () {
      expect(
        louvorPdfErrorMessage(
          const InvalidPdfPathException('path ruim'),
          generic,
        ),
        generic,
      );
    });

    test('PDF indisponível offline mostra a mensagem própria', () {
      expect(
        louvorPdfErrorMessage(
          const PdfOfflineUnavailableException(
            pdfId: 'pdf-1',
            message: 'não baixado',
          ),
          generic,
        ),
        'não baixado',
      );
    });

    test('PDF removido do dispositivo mostra a mensagem própria', () {
      expect(
        louvorPdfErrorMessage(
          const PdfExternallyDeletedException(
            pdfId: 'pdf-1',
            message: 'apagado do disco',
          ),
          generic,
        ),
        'apagado do disco',
      );
    });

    test('falha de download mostra a mensagem própria', () {
      expect(
        louvorPdfErrorMessage(
          const PdfFetchFailedException('rede caiu'),
          generic,
        ),
        'rede caiu',
      );
    });

    test('erro desconhecido cai na mensagem genérica', () {
      expect(louvorPdfErrorMessage(StateError('boom'), generic), generic);
    });
  });
}
