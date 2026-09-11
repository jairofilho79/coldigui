import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

/// Resolve qualquer id para uma rota de leitor — o teste só quer o efeito de
/// foco de [openMaterialForGroupInReader], não a abertura real do PDF.
class _StubReaderCarouselActions extends ReaderCarouselActionsNotifier {
  @override
  void build() {}

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async =>
      '${RoutePaths.reader}?pdfId=$targetPdfId';
}

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('seguir o áudio vem ligado por padrão', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await _container();

    expect(container.read(audioFollowReaderProvider), isTrue);
  });

  test('lê o valor persistido em SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({kAudioFollowReaderPrefsKey: false});
    final container = await _container();

    expect(container.read(audioFollowReaderProvider), isFalse);
  });

  test('toggle inverte o estado e persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(audioFollowReaderProvider.notifier).toggle();

    expect(container.read(audioFollowReaderProvider), isFalse);
    expect(prefs.getBool(kAudioFollowReaderPrefsKey), isFalse);

    await container.read(audioFollowReaderProvider.notifier).toggle();

    expect(container.read(audioFollowReaderProvider), isTrue);
    expect(prefs.getBool(kAudioFollowReaderPrefsKey), isTrue);
  });

  test('estado sobrevive a um novo ProviderContainer', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);
    await first.read(audioFollowReaderProvider.notifier).setEnabled(false);

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);

    expect(second.read(audioFollowReaderProvider), isFalse);
  });

  group('resolveMaterialForGroup — face de partituras + lookup', () {
    final chordId = encodePdfId('assets/praises/p2/m1.chord');
    final pdfId = encodePdfId('assets/praises/p2/m1.pdf');

    CarouselItem item(String materialId, int index) => CarouselItem(
      materialId: materialId,
      kind: MaterialKind.pdf,
      index: index,
      key: materialId,
      numero: '2',
      nome: 'Louvor',
      categoria: 'Partitura',
      classificacao: 'Cancao',
    );

    Future<WidgetRef> pump(
      WidgetTester tester,
      List<CarouselItem> items,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            carouselItemsProvider.overrideWithValue(items),
            louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('a cifra que está na lista ativa vence a partitura', (
      tester,
    ) async {
      final ref = await pump(tester, [item(chordId, 0)]);
      ref.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords([
        ChordMaterial(
          chordId: chordId,
          r2Key: 'assets/praises/p2/m1.chord',
          nome: 'Comigo habita',
          numero: '692',
          groupId: 'p2',
          categoria: 'Cifra I',
          classificacao: 'Cancao',
        ),
      ]);
      ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
        Louvor.fromManifest(
          nome: 'Comigo habita',
          numero: '692',
          categoria: 'Partitura',
          classificacao: 'Cancao',
          pdf: 'm1.pdf',
          pdfId: pdfId,
          groupId: 'p2',
        ),
      ]);
      await tester.pump();

      expect(
        resolveMaterialForGroup(ref, 'p2', listen: false),
        chordId,
        reason: 'a escolha do usuário na lista ativa vence',
      );
    });

    testWidgets('sem material na lista ativa cai no cache Coldigom', (
      tester,
    ) async {
      final ref = await pump(tester, const []);
      ref.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
        Louvor.fromManifest(
          nome: 'Comigo habita',
          numero: '692',
          categoria: 'Partitura',
          classificacao: 'Cancao',
          pdf: 'm1.pdf',
          pdfId: pdfId,
          groupId: 'p2',
        ),
      ]);
      await tester.pump();

      expect(resolveMaterialForGroup(ref, 'p2', listen: false), pdfId);
    });
  });

  // O foco é por ocorrência: `openMaterialForGroupInReader` não pode arrastar o
  // usuário da segunda ocorrência de um louvor para a primeira.
  group('openMaterialForGroupInReader — foco por ocorrência', () {
    final pdfId = encodePdfId('assets/praises/p3/m1.pdf');
    final louvor = Louvor.fromManifest(
      nome: 'Comigo habita',
      numero: '693',
      categoria: 'Partitura',
      classificacao: 'Cancao',
      pdf: 'm1.pdf',
      pdfId: pdfId,
      groupId: 'p3',
    );

    CarouselItem occurrence(int index, String key) => CarouselItem(
      materialId: pdfId,
      kind: MaterialKind.pdf,
      index: index,
      key: key,
      numero: '693',
      nome: 'Comigo habita',
      categoria: 'Partitura',
      classificacao: 'Cancao',
    );

    /// Devolve o `ref` da página, já com o material aberto.
    Future<WidgetRef> pumpAndOpen(
      WidgetTester tester, {
      String? focusedKey,
    }) async {
      late WidgetRef captured;
      SharedPreferences.setMockInitialValues({
        kCarouselFocusedPdfIdPrefsKey: ?focusedKey,
      });
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  captured = ref;
                  // O manifest é assíncrono: alguém tem que observá-lo para
                  // ele sair de `loading` antes do toque.
                  ref.watch(louvoresManifestProvider);
                  return ElevatedButton(
                    onPressed: () => openMaterialForGroupInReader(
                      ref: ref,
                      context: context,
                      groupId: 'p3',
                    ),
                    child: const Text('abrir'),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, _) => const Scaffold(body: Text('leitor')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            carouselItemsProvider.overrideWithValue([
              occurrence(0, pdfId),
              occurrence(1, '$pdfId#1'),
            ]),
            louvoresManifestOverride(LouvoresManifest.fromLouvores([louvor])),
            readerCarouselActionsProvider.overrideWith(
              _StubReaderCarouselActions.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      // Sanidade: o material foi mesmo aberto — sem isto o teste de foco
      // passaria à toa, com o fluxo saindo antes de focar.
      expect(find.text('leitor'), findsOneWidget);
      return captured;
    }

    testWidgets('a ocorrência focada do mesmo material continua focada', (
      tester,
    ) async {
      final ref = await pumpAndOpen(tester, focusedKey: '$pdfId#1');

      expect(ref.read(focusedCarouselItemProvider)?.key, '$pdfId#1');
    });

    testWidgets('sem foco nenhum, a ocorrência efetiva é a primeira', (
      tester,
    ) async {
      final ref = await pumpAndOpen(tester);

      // Chave nula resolve para o índice 0 — já é uma ocorrência deste
      // material, então nada é gravado e o foco efetivo é a primeira.
      expect(ref.read(carouselFocusedKeyProvider), isNull);
      expect(ref.read(focusedCarouselItemProvider)?.key, pdfId);
    });
  });

  group('shouldFollowAudioInReader', () {
    test('segue quando a faixa muda numa rota de leitura', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isTrue,
      );
    });

    test('não segue com o toggle desligado', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: false,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega fora das rotas de leitura', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: false,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: null,
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega na restauração da sessão (fila restaurada sem play)', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: true,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: null,
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('primeira faixa da sessão segue (A6)', () {
      // Louvor p1 aberto no leitor, usuário dá play no áudio de p2: não há
      // faixa anterior, mas a fila não veio de restauração.
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: null,
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isTrue,
      );
    });

    test('troca de faixa depois de uma restauração ainda parada não segue', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: true,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });

    test('não navega quando o grupo não mudou', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p1',
          currentMaterialGroupId: 'p9',
          targetMaterialPdfId: 'pdf-p1',
        ),
        isFalse,
      );
    });

    test('não navega sem material para o grupo', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: null,
        ),
        isFalse,
      );
    });

    test('não troca a cifra aberta pela partitura do mesmo louvor', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: 'p2',
          // Cifra do louvor p2 aberta; o alvo é a partitura do mesmo p2.
          currentMaterialGroupId: 'p2',
          targetMaterialPdfId: 'pdf-p2-partitura',
        ),
        isFalse,
      );
    });

    test('não navega com faixa sem grupo', () {
      expect(
        shouldFollowAudioInReader(
          sessionRestoredWithoutPlayback: false,
          enabled: true,
          isReaderRoute: true,
          previousGroupId: 'p1',
          nextGroupId: '',
          currentMaterialGroupId: 'p1',
          targetMaterialPdfId: 'pdf-p2',
        ),
        isFalse,
      );
    });
  });
}
