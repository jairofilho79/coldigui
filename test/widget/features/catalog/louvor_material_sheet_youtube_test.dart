import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_material_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seção YouTube com ícone vermelho, sem + e callback no toque', (
    tester,
  ) async {
    YoutubeMaterial? selected;

    final louvor = Louvor.fromManifest(
      nome: 'Leão',
      numero: '010',
      categoria: 'Partitura',
      classificacao: 'Fox',
      pdf: 'a.pdf',
      pdfId: 'pdf1',
      groupId: 'praise-1',
      source: LouvorDataSource.coldigom,
    );
    const yt = YoutubeMaterial(
      id: 'yt1',
      url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
      nome: 'Leão',
      numero: '010',
      groupId: 'praise-1',
      categoria: 'Gestos CIAs',
      classificacao: 'Fox',
    );
    final group = LouvorGroup.fromLouvores(
      [louvor],
      youtubeMaterials: [yt],
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
                    showLouvorMaterialSheet(
                      context: context,
                      group: group,
                      onMaterialSelected: (_) {},
                      onYoutubeSelected: (item) => selected = item,
                      onMaterialAdd: (_) async {},
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

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Gestos CIAs'), findsOneWidget);

    final youtubeIcon = tester.widget<Icon>(
      find.byIcon(LouvorMaterialIcons.youtube),
    );
    expect(youtubeIcon.color, AppColors.youtube);

    // PDF tem botão +; tile YouTube não.
    expect(find.byType(CarouselLouvorAddButton), findsOneWidget);
    final youtubeTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Gestos CIAs'),
    );
    expect(youtubeTile.trailing, isNull);

    await tester.tap(find.text('Gestos CIAs'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.id, 'yt1');
  });
}
