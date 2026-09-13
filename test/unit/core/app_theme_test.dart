import 'package:coldigui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transição de página é fade em todas as plataformas (P7)', () {
    final builders = AppTheme.light.pageTransitionsTheme.builders;
    for (final platform in TargetPlatform.values) {
      expect(
        builders[platform],
        isA<FadeForwardsPageTransitionsBuilder>(),
        reason: 'plataforma $platform sem fade',
      );
    }
  });
}
