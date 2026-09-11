import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_follow_reader_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

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
