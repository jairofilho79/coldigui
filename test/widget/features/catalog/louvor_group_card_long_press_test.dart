// test/widget/features/catalog/louvor_group_card_long_press_test.dart
//
// Pressionar e segurar o card multi-material abre direto o material
// favorito do grupo (mesma resolução do "+" — `preferredMaterialForGroup`),
// sem passar pelo `MaterialSheet`. Sem favorito adicionável (ex.: grupo só
// com YouTube), o long-press cai no mesmo caminho do tap de hoje.
import '../../../support/fakes/fake_active_editor.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _pdf(String categoria, String pdfId, {String? kind}) =>
    Louvor.fromManifest(
      nome: 'Grande Deus',
      numero: '001',
      categoria: categoria,
      classificacao: 'Coletânea',
      pdf: '$pdfId.pdf',
      pdfId: pdfId,
      groupId: 'g1',
      source: LouvorDataSource.plpcg,
      materialKindId: kind,
    );

/// Grupo com dois PDFs (Letra é a seção principal, Partitura a segunda) —
/// multi-material, então o tap de hoje abriria o `MaterialSheet`.
LouvorGroup _multiPdfGroup() => LouvorGroup(
  groupId: 'g1',
  numero: '001',
  nome: 'Grande Deus',
  sections: [
    LouvorMaterialSection(
      classificacao: 'Coletânea',
      displayLabel: 'Coletânea',
      materials: [
        LouvorMaterialEntry(
          categoria: 'Letra',
          pdfId: 'p-letra',
          louvor: _pdf('Letra', 'p-letra', kind: 'k-letra'),
        ),
        LouvorMaterialEntry(
          categoria: 'Partitura',
          pdfId: 'p-partitura',
          louvor: _pdf('Partitura', 'p-partitura', kind: 'k-partitura'),
        ),
      ],
    ),
  ],
);

/// Grupo com um único material — YouTube — sem PDF/áudio adicionável, então
/// `preferredMaterialForGroup` devolve `null` (nada para abrir direto).
LouvorGroup _youtubeOnlyGroup() => LouvorGroup(
  groupId: 'g2',
  numero: '002',
  nome: 'Ao Deus a quem sirvo',
  sections: const [],
  youtubeMaterials: const [
    YoutubeMaterial(
      id: 'yt1',
      url: 'https://youtu.be/1Pks43ceAac',
      nome: 'Ao Deus a quem sirvo',
      numero: '002',
      groupId: 'g2',
      categoria: 'YouTube',
      classificacao: 'Coletânea',
    ),
  ],
);

/// Registra qual material o opener recebeu, sem abrir nada de verdade.
class _OpenerSpy {
  final calls = <String>[];

  OpenMaterial build() => OpenMaterial(
    openPdf: ({required ref, required context, required louvor}) async {
      calls.add('pdf:${louvor.pdfId}');
    },
    openAudio: ({required ref, required context, required track, queue}) async {
      calls.add('audio:${track.audioId}');
    },
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required LouvorGroup group,
  required Map<String, int> rank,
  required OpenMaterial opener,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activePlaylistEditorProvider.overrideWith(FakeActiveEditor.new),
        playlistsProvider.overrideWith(FakePlaylistsNotifier.new),
        favoriteMaterialKindRankProvider.overrideWithValue(rank),
        openMaterialProvider.overrideWithValue(opener),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: LouvorGroupCard(group: group)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'long press com favorito disponível abre o material favorito direto, '
    'sem mostrar o bottom sheet',
    (tester) async {
      final spy = _OpenerSpy();
      await _pumpCard(
        tester,
        group: _multiPdfGroup(),
        rank: const {'k-partitura': 0},
        opener: spy.build(),
      );

      await tester.longPress(find.byType(CarouselLouvorChip));
      await tester.pumpAndSettle();

      expect(spy.calls, ['pdf:p-partitura']);
      expect(find.byType(MaterialSheet), findsNothing);
    },
  );

  // Guarda de paridade (não é RED→GREEN): o fallback chama o mesmo
  // `_handleTap()` do tap normal, então esta asserção já vale hoje (o tap
  // "vence" a arena de gestos quando não há `onLongPress` registrado) e
  // continua valendo depois — é o comportamento que o fallback deve
  // preservar, não uma prova do código novo (esse é o teste acima).
  testWidgets(
    'long press sem favorito adicionável (grupo só com YouTube) cai no '
    'mesmo comportamento do tap — abre o bottom sheet',
    (tester) async {
      final spy = _OpenerSpy();
      await _pumpCard(
        tester,
        group: _youtubeOnlyGroup(),
        rank: const {},
        opener: spy.build(),
      );

      await tester.longPress(find.byType(CarouselLouvorChip));
      await tester.pumpAndSettle();

      expect(spy.calls, isEmpty);
      expect(find.byType(MaterialSheet), findsOneWidget);
    },
  );
}
