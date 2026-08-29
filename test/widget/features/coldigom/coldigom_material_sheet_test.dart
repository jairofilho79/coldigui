import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/presentation/widgets/coldigom_material_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'sheet Coldigom: meta, abas condicionais, lista PDF plana sem ritmo',
    (tester) async {
      final partitura = Louvor.fromManifest(
        nome: 'A minha vida entrego',
        numero: '449',
        categoria: 'Partitura',
        classificacao: 'Básico',
        pdf: 'a.pdf',
        pdfId: 'pdf1',
        groupId: 'praise-1',
        source: LouvorDataSource.coldigom,
      );
      final cifra = Louvor.fromManifest(
        nome: 'A minha vida entrego',
        numero: '449',
        categoria: 'Cifra I',
        classificacao: 'Básico',
        pdf: 'b.pdf',
        pdfId: 'pdf2',
        groupId: 'praise-1',
        source: LouvorDataSource.coldigom,
      );
      const yt = YoutubeMaterial(
        id: 'yt1',
        url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
        nome: 'A minha vida entrego',
        numero: '449',
        groupId: 'praise-1',
        categoria: 'Gestos CIAs',
        classificacao: 'Básico',
      );
      final group = LouvorGroup.fromLouvores(
        [partitura, cifra],
        youtubeMaterials: [yt],
        coldigomMetaByGroupId: const {
          'praise-1': ColdigomPraiseMetadata(
            name: 'A minha vida entrego',
            tonality: 'Dm',
            author: 'CIAS',
            rhythm: 'Básico',
            category: 'Clamor',
            tagNames: ['PES'],
          ),
        },
      ).first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showColdigomMaterialSheet(
                        context: context,
                        group: group,
                        onMaterialSelected: (_) {},
                        onYoutubeSelected: (_) {},
                      );
                    },
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('449'), findsOneWidget);
      expect(find.text('A minha vida entrego'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(find.text('Dm'), findsOneWidget);
      expect(find.text('Autor'), findsOneWidget);
      expect(find.text('CIAS'), findsOneWidget);
      expect(find.text('Ritmo'), findsOneWidget);
      expect(find.text('Básico'), findsOneWidget);
      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Clamor'), findsOneWidget);
      expect(find.text('PES'), findsOneWidget);
      expect(find.text('TAGS'), findsOneWidget);

      // Título concatenado antigo e seção de ritmo não existem.
      expect(find.text('449 — A minha vida entrego'), findsNothing);

      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Áudio'), findsNothing);

      expect(find.text('Partitura'), findsOneWidget);
      expect(find.text('Cifra I'), findsOneWidget);

      await tester.tap(find.text('YouTube'));
      await tester.pumpAndSettle();
      expect(find.text('Gestos CIAs'), findsOneWidget);
    },
  );

  test('adapter toMetadata e DetailDto parseiam tag_names', () {
    final detail = PraiseDetailDto.fromJson({
      'id': 'p1',
      'name': 'Hino',
      'number': '001',
      'rhythm': 'Fox',
      'tonality': 'G',
      'category': 'Clamor',
      'author': 'Autor',
      'tag_names': 'PES,Coletânea',
      'materials': const [],
    });

    expect(detail.tagNames, ['PES', 'Coletânea']);

    final meta = ColdigomLouvorAdapter.toMetadata(detail);
    expect(meta.tonality, 'G');
    expect(meta.rhythm, 'Fox');
    expect(meta.tagNames, ['PES', 'Coletânea']);
    expect(meta.hasAnyField, isTrue);
  });

  test('fromLouvores anexa coldigomMeta e flatPdfMaterials ordena', () {
    final a = Louvor.fromManifest(
      nome: 'Hino',
      numero: '1',
      categoria: 'Cifra',
      classificacao: 'Básico',
      pdf: 'a.pdf',
      pdfId: 'a',
      groupId: 'g1',
      source: LouvorDataSource.coldigom,
    );
    final b = Louvor.fromManifest(
      nome: 'Hino',
      numero: '1',
      categoria: 'Partitura',
      classificacao: 'Básico',
      pdf: 'b.pdf',
      pdfId: 'b',
      groupId: 'g1',
      source: LouvorDataSource.coldigom,
    );

    final group = LouvorGroup.fromLouvores(
      [a, b],
      coldigomMetaByGroupId: const {
        'g1': ColdigomPraiseMetadata(name: 'Hino', rhythm: 'Básico'),
      },
    ).first;

    expect(group.coldigomMeta?.rhythm, 'Básico');
    expect(group.isColdigom, isTrue);
    expect(group.flatPdfMaterials.map((e) => e.categoria), [
      'Partitura',
      'Cifra',
    ]);
  });
}
