import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasAnyField ignora category: a seção da Coletânea vem nas tags', () {
    expect(
      const ColdigomPraiseMetadata(name: 'x', category: 'Clamor').hasAnyField,
      isFalse,
    );
    expect(
      const ColdigomPraiseMetadata(
        name: 'x',
        category: 'Clamor',
        tagNames: ['Coletânea · Clamor'],
      ).hasAnyField,
      isTrue,
    );
  });

  test('hasAnyField: tom, autor, ritmo ou tags bastam', () {
    expect(const ColdigomPraiseMetadata(name: 'x').hasAnyField, isFalse);
    expect(
      const ColdigomPraiseMetadata(name: 'x', tonality: 'Dm').hasAnyField,
      isTrue,
    );
    expect(
      const ColdigomPraiseMetadata(name: 'x', author: 'A').hasAnyField,
      isTrue,
    );
    expect(
      const ColdigomPraiseMetadata(name: 'x', rhythm: 'Fox').hasAnyField,
      isTrue,
    );
    expect(
      const ColdigomPraiseMetadata(name: 'x', tagNames: ['PES']).hasAnyField,
      isTrue,
    );
  });
}
