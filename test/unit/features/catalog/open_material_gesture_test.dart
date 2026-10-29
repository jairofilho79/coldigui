import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _gesture = GestureMaterial(gestureId: 'g1', r2Key: 'k.gestures', nome: 'N', numero: '1', groupId: 'g', categoria: 'Gestos', classificacao: 'x');

void main() {
  testWidgets('GestureMaterialRef vai para openGesture', (tester) async {
    GestureMaterial? opened;
    final open = OpenMaterial(
      openGesture: ({required ref, required context, required gesture}) async => opened = gesture,
    );
    late WidgetRef capturedRef;
    late BuildContext capturedContext;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            capturedRef = ref;
            capturedContext = context;
            return const SizedBox();
          }),
        ),
      ),
    );
    await open.open(capturedContext, capturedRef, const GestureMaterialRef(_gesture));
    expect(opened, same(_gesture));
  });
}
