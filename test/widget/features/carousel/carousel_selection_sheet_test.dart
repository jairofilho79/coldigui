import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_selection_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;
  final removed = <String>[];
  List<String>? lastReorder;

  @override
  List<CarouselItem> build() => initial;

  @override
  Future<void> remove(String pdfId) async {
    removed.add(pdfId);
    state = state.where((item) => item.pdfId != pdfId).toList(growable: false);
  }

  @override
  Future<void> reorder(List<String> pdfIds) async {
    lastReorder = pdfIds;
    final byId = {for (final item in state) item.pdfId: item};
    state = pdfIds.map((pdfId) => byId[pdfId]!).toList(growable: false);
  }
}

class _OpenSheetButton extends ConsumerWidget {
  const _OpenSheetButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => showCarouselSelectionSheet(context),
      child: const Text('open'),
    );
  }
}

const _items = [
  CarouselItem(
    pdfId: 'a',
    sortOrder: 0,
    numero: '001',
    nome: 'Louvor A',
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
  ),
  CarouselItem(
    pdfId: 'b',
    sortOrder: 1,
    numero: '002',
    nome: 'Louvor B',
    categoria: 'Cifra nível I',
    classificacao: 'ColCIAs',
  ),
];

void main() {
  testWidgets('remove dispara notifier.remove', (tester) async {
    final notifier = _FakeCarouselNotifier(_items);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [carouselLouvoresProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: _OpenSheetButton()),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(notifier.removed, ['a']);
  });

  testWidgets('reorder dispara notifier.reorder', (tester) async {
    final notifier = _FakeCarouselNotifier(_items);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [carouselLouvoresProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: _OpenSheetButton()),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dragHandle = find.descendant(
      of: find.ancestor(
        of: find.textContaining('Louvor A'),
        matching: find.byType(ReorderableDragStartListener),
      ),
      matching: find.byIcon(Icons.drag_indicator),
    );
    await tester.drag(dragHandle, const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(notifier.lastReorder, isNotNull);
  });

  testWidgets('onItemTap dispara ao tocar no chip', (tester) async {
    CarouselItem? tapped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider.overrideWith(
            () => _FakeCarouselNotifier(_items),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showCarouselSelectionSheet(
                  context,
                  onItemTap: (item) async => tapped = item,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Louvor B'));
    await tester.pumpAndSettle();

    expect(tapped?.pdfId, 'b');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('exibe chips temáticos com metadados', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carouselLouvoresProvider.overrideWith(
            () => _FakeCarouselNotifier(_items),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: _OpenSheetButton()),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CarouselLouvorChip), findsNWidgets(2));
    expect(find.textContaining('Coletânea Adultos'), findsOneWidget);
    expect(find.textContaining('Coletânea CIAs'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
  });
}
