// test/widget/features/carousel/material_kinds_row_test.dart
//
// C5: `MaterialKindsRow` mostra um ícone por tipo de material presente no
// grupo, na ordem PDF · cifra · gestos · áudio · YouTube, com contagem quando
// há mais de um material do mesmo tipo.
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/material_kinds_row.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _pdf({String categoria = 'Partitura', String pdfId = 'pdf1'}) {
  return Louvor(
    nome: 'Aleluia',
    numero: '001',
    categoria: categoria,
    classificacao: 'Básico',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: 'g1',
    searchTitleNorm: 'aleluia',
    searchContentTokens: const [],
    searchCompactContent: '',
  );
}

AudioTrack _audio(String id) {
  return AudioTrack(
    audioId: id,
    r2Key: 'assets/praises/g1/$id.mp3',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'Áudio',
    classificacao: 'Básico',
  );
}

ChordMaterial _chord(String id) {
  return ChordMaterial(
    chordId: id,
    r2Key: 'assets/praises/g1/$id.chord',
    nome: 'Aleluia',
    numero: '001',
    groupId: 'g1',
    categoria: 'Cifra',
    classificacao: 'Básico',
  );
}

LouvorGroup _groupWith({
  List<Louvor> pdfs = const [],
  List<CatalogMaterial> extras = const [],
}) {
  return LouvorGroup(
    groupId: 'g1',
    numero: '001',
    nome: 'Aleluia',
    sections: pdfs.isEmpty
        ? const []
        : [
            LouvorMaterialSection(
              classificacao: 'Básico',
              displayLabel: 'Básico',
              materials: [
                for (final louvor in pdfs)
                  LouvorMaterialEntry(
                    categoria: louvor.categoria,
                    pdfId: louvor.pdfId,
                    louvor: louvor,
                  ),
              ],
            ),
          ],
    extras: extras,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('PDF + cifra + áudio: 3 ícones, na ordem', (tester) async {
    final group = _groupWith(
      pdfs: [_pdf()],
      extras: [ChordMaterialRef(_chord('c1')), AudioMaterial(_audio('a1'))],
    );

    await _pump(tester, MaterialKindsRow(group: group));

    final icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .map((icon) => icon.icon)
        .toList();
    expect(icons, [
      LouvorMaterialIcons.forKind(MaterialKind.pdf),
      LouvorMaterialIcons.forKind(MaterialKind.chord),
      LouvorMaterialIcons.forKind(MaterialKind.audio),
    ]);
  });

  testWidgets('toque no ícone de áudio chama onTap(MaterialKind.audio)', (
    tester,
  ) async {
    MaterialKind? tapped;
    final group = _groupWith(
      pdfs: [_pdf()],
      extras: [ChordMaterialRef(_chord('c1')), AudioMaterial(_audio('a1'))],
    );

    await _pump(
      tester,
      MaterialKindsRow(group: group, onTap: (kind) => tapped = kind),
    );

    await tester.tap(
      find.byIcon(LouvorMaterialIcons.forKind(MaterialKind.audio)),
    );
    await tester.pumpAndSettle();

    expect(tapped, MaterialKind.audio);
  });

  testWidgets('mais de um material do mesmo tipo mostra a contagem', (
    tester,
  ) async {
    final group = _groupWith(
      pdfs: [
        _pdf(pdfId: 'pdf1'),
        _pdf(pdfId: 'pdf2', categoria: 'Partitura'),
      ],
    );

    await _pump(tester, MaterialKindsRow(group: group));

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('um único material do tipo não mostra contagem', (tester) async {
    final group = _groupWith(pdfs: [_pdf()]);

    await _pump(tester, MaterialKindsRow(group: group));

    expect(find.text('1'), findsNothing);
  });

  testWidgets('grupo sem materiais não renderiza nada', (tester) async {
    await _pump(tester, MaterialKindsRow(group: _groupWith()));

    expect(find.byType(Icon), findsNothing);
  });
}
