import 'package:coldigui/core/theme/app_theme.dart';
import 'package:coldigui/core/theme/brand_fade_page_transitions_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transição de página é a da marca em todas as plataformas (P7)', () {
    final builders = AppTheme.light.pageTransitionsTheme.builders;
    for (final platform in TargetPlatform.values) {
      expect(
        builders[platform],
        isA<BrandFadePageTransitionsBuilder>(),
        reason: 'plataforma $platform sem a transição da marca',
      );
    }
  });
}
