import 'dart:io';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/pages/gesture_reader_screen.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_document_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/newer_schema_banner.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/gesture_test_png.dart';

const _r2Key = 'assets/praises/p1/m1.gestures';

String _read(String name) => File('test/fixtures/gestures/$name').readAsStringSync();

/// O prefetch da tela não pode ir à rede no teste.
class _NoopFigureRepository implements GestureFigureRepository {
  @override
  Future<Uint8List?> get(String r2Key) async => null;

  @override
  Future<void> prefetch(Iterable<String> r2Keys) async {}
}

/// Conta quantas vezes o prefetch rodou — pin do reset em troca de louvor.
class _CountingFigureRepository implements GestureFigureRepository {
  var prefetchCalls = 0;

  @override
  Future<Uint8List?> get(String r2Key) async => null;

  @override
  Future<void> prefetch(Iterable<String> r2Keys) async {
    prefetchCalls++;
  }
}

/// [document] `null` = 404; `Future.error` = falha de rede.
Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required Future<GestureDocument?> Function() document,
  Map<String, String>? queryParams,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final dict = parseGestureDictionary(_read('dictionary.json'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gestureDocumentProvider.overrideWith((ref, key) => document()),
        gestureDictionaryProvider.overrideWith((ref) async => dict),
        gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng()),
        gestureFigureRepositoryProvider.overrideWithValue(_NoopFigureRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: GestureReaderScreen(
          queryParams: queryParams ?? {'pdfId': encodePdfId(_r2Key), 'titulo': 'Quero viver'},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return prefs;
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GestureReaderScreen)));

Future<void> _sendWithControl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('renderiza o documento e publica os params da rota', (tester) async {
    await _pump(tester, document: () async => parseGestureDocument(_read('182_quero_viver.json')));

    expect(find.byType(GestureDocumentView), findsOneWidget);
    expect(find.text('182 - QUERO VIVER PRA SEMPRE COM JESUS'), findsOneWidget);
    expect(find.byType(GestureCardTile), findsWidgets);
    expect(_containerOf(tester).read(readerRouteParamsProvider)['pdfId'], encodePdfId(_r2Key));
  });

  testWidgets('404 mostra "ainda não tem gestos"', (tester) async {
    await _pump(tester, document: () async => null);
    expect(find.text('Este louvor ainda não tem gestos'), findsOneWidget);
    expect(find.byType(GestureDocumentView), findsNothing);
  });

  testWidgets('falha de rede mostra indisponível com retry que reinvalida', (tester) async {
    var calls = 0;
    await _pump(tester, document: () {
      calls++;
      return calls == 1
          ? Future.error(const GestureFetchFailedException(_r2Key, 'rede'))
          : Future.value(parseGestureDocument(_read('182_quero_viver.json')));
    });
    expect(find.text('Gestos indisponíveis · tentar de novo'), findsOneWidget);

    await tester.tap(find.byKey(gestureReaderRetryKey));
    await tester.pump();
    await tester.pump();
    expect(find.byType(GestureDocumentView), findsOneWidget);
  });

  testWidgets('schema v2 mostra o banner acima do papel', (tester) async {
    await _pump(tester, document: () async => parseGestureDocument(_read('schema_v2.json')));
    expect(find.byType(NewerSchemaBanner), findsOneWidget);
    expect(find.byType(GestureDocumentView), findsOneWidget);
  });

  testWidgets('A+/A- mudam a fonte e persistem; Ctrl+↑/↓ também', (tester) async {
    final prefs = await _pump(tester, document: () async => parseGestureDocument(_read('182_quero_viver.json')));
    final container = _containerOf(tester);
    expect(container.read(gestureReaderFontSizeProvider), 18);

    await tester.tap(find.byTooltip('Aumentar letra dos gestos'));
    await tester.pump();
    expect(container.read(gestureReaderFontSizeProvider), 20);
    expect(prefs.getDouble(StorageKeys.gestureReaderFontSize), 20);
    expect(tester.getSize(find.byType(GestureFigure).first).width, closeTo(96 * 20 / 18, 0.1));

    await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);
    await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);
    expect(container.read(gestureReaderFontSizeProvider), 16);

    await tester.tap(find.byTooltip('Diminuir letra dos gestos'));
    await tester.pump();
    expect(container.read(gestureReaderFontSizeProvider), 14);
    // `find.byTooltip` casa com o `RawTooltip` interno, não com o `IconButton`
    // que o envolve — busca pelo predicado para pegar o widget certo.
    final decreaseButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Diminuir letra dos gestos',
    );
    expect(tester.widget<IconButton>(decreaseButton).onPressed, isNull);
  });

  testWidgets(
    'troca de louvor via replace republica os params e refaz o prefetch',
    (tester) async {
      // Espelha o `context.replace()` do carousel: mesma key de página, só o
      // widget muda — o go_router não recria o State, chama `didUpdateWidget`.
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final dict = parseGestureDictionary(_read('dictionary.json'));
      final figureRepo = _CountingFigureRepository();

      final overrides = [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gestureDocumentProvider.overrideWith(
          (ref, key) async => parseGestureDocument(_read('182_quero_viver.json')),
        ),
        gestureDictionaryProvider.overrideWith((ref) async => dict),
        gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng()),
        gestureFigureRepositoryProvider.overrideWithValue(figureRepo),
      ];

      const firstKey = 'assets/praises/p1/m1.gestures';
      const secondKey = 'assets/praises/p1/m2.gestures';

      Widget buildApp(Map<String, String> queryParams) {
        return ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: GestureReaderScreen(queryParams: queryParams),
          ),
        );
      }

      await tester.pumpWidget(
        buildApp({'pdfId': encodePdfId(firstKey), 'titulo': 'Quero viver'}),
      );
      await tester.pump();
      await tester.pump();

      expect(
        _containerOf(tester).read(readerRouteParamsProvider)['pdfId'],
        encodePdfId(firstKey),
      );
      expect(figureRepo.prefetchCalls, 1);

      // Mesma árvore de overrides/ProviderScope — só o `queryParams` do
      // GestureReaderScreen muda, exatamente como o `replace` do carousel.
      await tester.pumpWidget(
        buildApp({'pdfId': encodePdfId(secondKey), 'titulo': 'Outro louvor'}),
      );
      await tester.pump();
      await tester.pump();

      expect(
        _containerOf(tester).read(readerRouteParamsProvider)['pdfId'],
        encodePdfId(secondKey),
      );
      expect(figureRepo.prefetchCalls, 2);
    },
  );

  testWidgets('pdfId inválido não quebra: mostra "ainda não tem gestos"', (tester) async {
    await _pump(tester, document: () async => null, queryParams: {'pdfId': '###'});
    expect(find.text('Este louvor ainda não tem gestos'), findsOneWidget);
  });
}
