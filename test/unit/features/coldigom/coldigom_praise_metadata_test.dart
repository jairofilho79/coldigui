import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(
      const ColdigomPraiseMetadata(
        name: 'x',
        biblicalSummary: 'Sl 23:1 — O Senhor é meu pastor',
      ).hasAnyField,
      isTrue,
    );
  });
}
