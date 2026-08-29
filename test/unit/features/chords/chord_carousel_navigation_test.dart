import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/presentation/utils/build_carousel_metadata_map.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const r2Key = 'assets/praises/p1/m1.chord';

  test('metadata map inclui cifras com categoria e nome', () {
    final chordId = encodePdfId(r2Key);
    final map = buildCarouselMetadataMap(
      chordCache: {
        chordId: ChordMaterial(
          chordId: chordId,
          r2Key: r2Key,
          nome: 'Comigo habita',
          numero: '692',
          groupId: 'p1',
          categoria: 'Cifra I',
          classificacao: 'Cancao',
        ),
      },
    );

    expect(map[chordId]?.nome, 'Comigo habita');
    expect(map[chordId]?.numero, '692');
    expect(map[chordId]?.categoria, 'Cifra I');
  });

  test('id de cifra e distinguivel de id de PDF no mesmo espaco', () {
    expect(materialIdKindOf(encodePdfId(r2Key)), MaterialIdKind.chord);
    expect(
      materialIdKindOf(encodePdfId('assets/praises/p1/m1.pdf')),
      MaterialIdKind.pdf,
    );
  });
}
