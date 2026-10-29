import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LouvorClassification', () {
    test('baseClassification remove parênteses', () {
      expect(
        LouvorClassification.baseClassification('ColAdultos (Especial)'),
        'ColAdultos',
      );
    });
  });
}
