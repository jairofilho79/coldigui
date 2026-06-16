import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sharePositionOriginFromContextOrFallback', () {
    testWidgets('usa fallback não vazio quando contexto não tem RenderBox',
        (tester) async {
      late Rect origin;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              origin = sharePositionOriginFromContextOrFallback(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(origin.width, greaterThan(0));
      expect(origin.height, greaterThan(0));
    });

    testWidgets('usa retângulo do widget quando layout está pronto',
        (tester) async {
      late Rect origin;
      const buttonKey = Key('share-anchor');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return SizedBox(
                    key: buttonKey,
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        origin = sharePositionOriginFromContextOrFallback(
                          context,
                        );
                      },
                      child: const Text('Share'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byKey(buttonKey));
      final expected = box.localToGlobal(Offset.zero) & box.size;

      expect(origin, expected);
      expect(origin.width, greaterThan(0));
      expect(origin.height, greaterThan(0));
    });
  });
}
