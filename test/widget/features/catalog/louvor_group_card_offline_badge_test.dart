import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/catalog/presentation/widgets/offline_availability_badge.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_availability_map_provider.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mapa dirigido pelo teste — a badge do card lê **só** daqui (A5).
class _MapNotifier extends Notifier<Map<String, PdfOfflineAvailability>> {
  _MapNotifier(this.initial);

  final Map<String, PdfOfflineAvailability> initial;

  @override
  Map<String, PdfOfflineAvailability> build() => initial;

  void set(Map<String, PdfOfflineAvailability> next) => state = next;
}

final _mapProvider =
    NotifierProvider<_MapNotifier, Map<String, PdfOfflineAvailability>>(
      () => _MapNotifier(const {}),
    );

void main() {
  final pdfId = encodePdfId('ColAdultos/001.pdf');

  Louvor louvorFixture() => Louvor(
    nome: 'Aleluia',
    numero: '001',
    categoria: 'ColAdultos',
    classificacao: 'Partitura',
    pdf: 'ColAdultos/001.pdf',
    pdfId: pdfId,
    groupId: '001:aleluia',
    searchTitleNorm: 'aleluia',
    searchContentTokens: const [],
    searchCompactContent: '',
  );

  LouvorGroup pdfOnlyGroup() => LouvorGroup(
    groupId: '001:aleluia',
    numero: '001',
    nome: 'Aleluia',
    sections: [
      LouvorMaterialSection(
        classificacao: 'Partitura',
        displayLabel: 'Partitura',
        materials: [
          LouvorMaterialEntry(
            categoria: 'ColAdultos',
            pdfId: pdfId,
            louvor: louvorFixture(),
          ),
        ],
      ),
    ],
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_MapNotifier> pumpCard(
    WidgetTester tester,
    Map<String, PdfOfflineAvailability> initial,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = _MapNotifier(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          _mapProvider.overrideWith(() => notifier),
          offlineAvailabilityMapProvider.overrideWith(
            (ref) => ref.watch(_mapProvider),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(body: LouvorGroupCard(group: pdfOnlyGroup())),
        ),
      ),
    );
    await tester.pump();
    return notifier;
  }

  PdfOfflineAvailability badgeOf(WidgetTester tester) {
    return tester
        .widget<OfflineAvailabilityBadge>(find.byType(OfflineAvailabilityBadge))
        .availability;
  }

  testWidgets('card lê a disponibilidade do mapa único, sem query por card', (
    tester,
  ) async {
    await pumpCard(tester, {pdfId: PdfOfflineAvailability.persistentOffline});

    expect(badgeOf(tester), PdfOfflineAvailability.persistentOffline);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });

  testWidgets('id fora do mapa é «não disponível»: sem badge', (tester) async {
    await pumpCard(tester, const {});

    expect(find.byType(OfflineAvailabilityBadge), findsNothing);
    expect(find.byIcon(Icons.cloud_done), findsNothing);
  });

  testWidgets('mudança no mapa atualiza a badge do card', (tester) async {
    final notifier = await pumpCard(tester, const {});
    expect(find.byIcon(Icons.cloud_done), findsNothing);

    notifier.set({pdfId: PdfOfflineAvailability.cachedLru});
    await tester.pump();

    expect(badgeOf(tester), PdfOfflineAvailability.cachedLru);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
  });
}
