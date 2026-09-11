import 'dart:io';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/widgets/brace_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_document_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/instruction_card_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/link_connector_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/newer_schema_banner.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

String _read(String name) => File('test/fixtures/gestures/$name').readAsStringSync();

Future<GlobalKey<GestureDocumentViewState>> _pump(
  WidgetTester tester,
  String fixture, {
  GestureDictionary? dictionary,
  ValueChanged<int>? onCardTap,
  double fontSize = 18,
}) async {
  final key = GlobalKey<GestureDocumentViewState>();
  final dict = dictionary ?? parseGestureDictionary(_read('dictionary.json'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Column(
            children: [
              if (parseGestureDocument(_read(fixture)).isNewerSchema) const NewerSchemaBanner(),
              Expanded(
                child: GestureDocumentView(
                  key: key,
                  document: parseGestureDocument(_read(fixture)),
                  dictionary: dict,
                  fontSize: fontSize,
                  onCardTap: onCardTap,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return key;
}

void main() {
  testWidgets('182: título em caixa alta, CORO tracejado sobre 5 cartões, 14 cartões, 2 instruções', (tester) async {
    await _pump(tester, '182_quero_viver.json');

    expect(find.text('182 - QUERO VIVER PRA SEMPRE COM JESUS'), findsOneWidget);
    expect(find.byType(GestureCardTile, skipOffstage: false), findsNWidgets(14));
    expect(find.byType(InstructionCardView, skipOffstage: false), findsNWidgets(2));
    expect(find.text('Voltar ao coro', skipOffstage: false), findsOneWidget);

    final brace = find.byKey(gestureBraceKey);
    expect(brace, findsOneWidget);
    expect((tester.widget<CustomPaint>(brace).painter as BracePainter).dashed, isTrue);
    final braceRect = tester.getRect(brace);
    expect(braceRect.top, tester.getRect(find.byKey(gestureCardKey(0))).top);
    expect(braceRect.bottom, tester.getRect(find.byKey(gestureCardKey(4))).bottom);
  });

  testWidgets('181: chave 2x cobre os 4 últimos cartões', (tester) async {
    await _pump(tester, '181_jerusalem.json');
    final brace = find.byKey(gestureBraceKey);
    expect((tester.widget<CustomPaint>(brace).painter as BracePainter).label, '2x');
    expect(tester.getRect(brace).top, tester.getRect(find.byKey(gestureCardKey(5))).top);
    expect(tester.getRect(brace).bottom, tester.getRect(find.byKey(gestureCardKey(8))).bottom);
  });

  testWidgets('sintético: FINAL, conector dentro da chave, id inexistente vira placeholder, texto desconhecido não quebra', (tester) async {
    await _pump(tester, 'sintetico_final_link.json');
    expect(find.text('FINAL', skipOffstage: false), findsOneWidget);
    expect(find.byKey(gestureLinkConnectorKey, skipOffstage: false), findsOneWidget);
    expect(find.byKey(gesturePlaceholderKey('000000000000'), skipOffstage: false), findsOneWidget);
    expect(find.textContaining('hologram', skipOffstage: false), findsOneWidget);
    expect(find.text('Instrumentos'), findsOneWidget);
  });

  testWidgets('alias: documento com id deprecated mostra a figura da entrada ativa', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gestureFigureProvider.overrideWith((ref, k) async {
            asked.add(k);
            return gestureTestPng();
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: GestureDocumentView(
              document: parseGestureDocument(
                '{"items":[{"type":"gesture","gestureId":"a1b2c3d4e5f6","lyrics":[{"trigger":"a","text":"b"}]}]}',
              ),
              dictionary: parseGestureDictionary(_read('dictionary.json')),
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(asked, ['assets/cia/gestures/c687580e7682.png']);
  });

  testWidgets('dicionário vazio: todos os cartões viram placeholder, nada quebra', (tester) async {
    await _pump(tester, '182_quero_viver.json', dictionary: GestureDictionary.empty);
    expect(find.byType(GestureCardTile, skipOffstage: false), findsNWidgets(14));
    expect(find.byKey(gesturePlaceholderKey('c687580e7682'), skipOffstage: false), findsWidgets);
  });

  testWidgets('schema v2 mostra o banner e renderiza', (tester) async {
    await _pump(tester, 'schema_v2.json');
    expect(find.byType(NewerSchemaBanner), findsOneWidget);
    expect(find.text('Documento em formato mais novo; atualize o app.'), findsOneWidget);
    expect(find.byType(GestureCardTile), findsOneWidget);
  });

  testWidgets('toque no cartão chama onCardTap com o índice do flatten', (tester) async {
    int? tapped;
    await _pump(tester, '182_quero_viver.json', onCardTap: (i) => tapped = i);
    await tester.tap(find.byKey(gestureCardKey(3)));
    expect(tapped, 3);
  });

  testWidgets('scrollToCard rola até o cartão', (tester) async {
    final key = await _pump(tester, '182_quero_viver.json', fontSize: 28);
    expect(find.byKey(gestureCardKey(13)), findsNothing);
    await key.currentState!.scrollToCard(13);
    await tester.pumpAndSettle();
    expect(find.byKey(gestureCardKey(13)), findsOneWidget);
  });

  testWidgets('largura máxima 720 centralizada', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, '182_quero_viver.json');
    final page = tester.getRect(find.byKey(gestureDocumentPageKey));
    expect(page.width, 720);
    expect(page.left, closeTo((1200 - 720) / 2, 1));
  });
}
