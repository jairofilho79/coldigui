import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/carousel/presentation/utils/related_praises_swapper.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_swap_material_button.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  group('resolveRelatedPraisesForGroup', () {
    final groupColetanea = catalogGroup(
      praiseId: 'col_003',
      number: '003',
      name: 'Clamo a ti',
      tags: const ['Coletânea · Clamor'],
      groupId: 'g_003',
    );
    final groupPes = catalogGroup(
      praiseId: 'pes_003',
      number: '003',
      name: 'Clamo a ti',
      tags: const ['GLTM', 'PES'],
      groupId: 'g_003',
    );
    final groupSolo = catalogGroup(
      praiseId: 'solo_010',
      number: '010',
      name: 'Louvor Único',
      groupId: 'g_unique',
    );
    final groupNoGroup = catalogGroup(
      praiseId: 'no_group',
      number: '011',
      name: 'Sem grupo',
    );

    final index = catalogIndexOf([
      groupColetanea,
      groupPes,
      groupSolo,
      groupNoGroup,
    ]);

    test('retorna lista de praises relacionados quando o grupo tem >= 2 membros', () {
      final related = resolveRelatedPraisesForGroup(groupColetanea, index);
      expect(related.length, 2);
      expect(related.map((g) => g.groupId), containsAll(['col_003', 'pes_003']));
    });

    test('retorna vazio quando o grupo tem apenas 1 membro no índice', () {
      final related = resolveRelatedPraisesForGroup(groupSolo, index);
      expect(related, isEmpty);
    });

    test('retorna vazio quando o praise não possui groupId', () {
      final related = resolveRelatedPraisesForGroup(groupNoGroup, index);
      expect(related, isEmpty);
    });
  });

  group('resolveMatchingMaterialForPraise', () {
    final targetLouvor = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '003',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'mat.pdf',
      pdfId: 'target_pdf_id',
      groupId: 'pes_003',
    );

    const targetChord = ChordMaterial(
      chordId: 'target_chord_id',
      r2Key: 'k_chord',
      nome: 'Clamo a ti',
      numero: '003',
      groupId: 'pes_003',
      categoria: 'Cifra',
      classificacao: 'ColAdultos',
    );

    final groupWithPdfAndChord = LouvorGroup(
      groupId: 'pes_003',
      numero: '003',
      nome: 'Clamo a ti',
      sections: [
        LouvorMaterialSection(
          classificacao: 'ColAdultos',
          displayLabel: 'Coletânea',
          materials: [
            LouvorMaterialEntry(
              categoria: 'Partitura',
              pdfId: 'target_pdf_id',
              louvor: targetLouvor,
            ),
          ],
        ),
      ],
      chordMaterials: const [targetChord],
    );

    final groupOnlyChord = LouvorGroup(
      groupId: 'pes_003_chord',
      numero: '003',
      nome: 'Clamo a ti',
      sections: const [],
      chordMaterials: const [targetChord],
    );

    test('mantém MaterialKind.chord quando disponível no alvo', () {
      final match = resolveMatchingMaterialForPraise(
        targetGroup: groupWithPdfAndChord,
        preferredKind: MaterialKind.chord,
      );
      expect(match, isA<ChordMaterialRef>());
      expect(match?.id, 'target_chord_id');
    });

    test('mantém MaterialKind.pdf quando disponível no alvo', () {
      final match = resolveMatchingMaterialForPraise(
        targetGroup: groupWithPdfAndChord,
        preferredKind: MaterialKind.pdf,
      );
      expect(match, isA<PdfMaterial>());
      expect(match?.id, 'target_pdf_id');
    });

    test('fallback para PDF quando preferredKind (ex: audio) não existe no alvo', () {
      final match = resolveMatchingMaterialForPraise(
        targetGroup: groupWithPdfAndChord,
        preferredKind: MaterialKind.audio,
      );
      expect(match, isA<PdfMaterial>());
      expect(match?.id, 'target_pdf_id');
    });

    test('fallback para Cifra quando alvo não possui PDF', () {
      final match = resolveMatchingMaterialForPraise(
        targetGroup: groupOnlyChord,
        preferredKind: MaterialKind.pdf,
      );
      expect(match, isA<ChordMaterialRef>());
      expect(match?.id, 'target_chord_id');
    });
  });

  group('resolveCarouselSwapMaterialGroup com praises relacionados', () {
    testWidgets(
      'exibe botão de troca mesmo com 1 material se houver versões relacionadas',
      (tester) async {
        final groupCol = catalogGroup(
          praiseId: 'col_single',
          number: '005',
          name: 'Louvor 5',
          groupId: 'grp_5',
          pdfKinds: const {'k1': 'Partitura'},
        );
        final groupPes = catalogGroup(
          praiseId: 'pes_single',
          number: '005',
          name: 'Louvor 5',
          groupId: 'grp_5',
          pdfKinds: const {'k1': 'Partitura'},
        );

        final index = catalogIndexOf([groupCol, groupPes]);
        final pdfId = groupCol.flatPdfMaterials.first.pdfId;
        final source = ColdigomCatalogSource(
          louvores: {
            pdfId: groupCol.flatPdfMaterials.first.louvor,
          },
          index: index,
        );

        LouvorGroup? resolved;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              coldigomCatalogSourceProvider.overrideWithValue(source),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                resolved = resolveCarouselSwapMaterialGroup(
                  ref,
                  materialId: pdfId,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(resolved, isNotNull);
        expect(resolved?.groupId, 'col_single');
      },
    );
  });
}

