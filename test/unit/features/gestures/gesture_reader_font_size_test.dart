import 'package:coldigui/features/gestures/domain/entities/gesture_reader_font_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('faixa 14–28, passo 2, inicial 18', () {
    expect(GestureReaderFontSize.min, 14);
    expect(GestureReaderFontSize.max, 28);
    expect(GestureReaderFontSize.step, 2);
    expect(GestureReaderFontSize.initial, 18);
  });

  test('increase/decrease andam de 2 e param nos limites', () {
    expect(GestureReaderFontSize.increase(18), 20);
    expect(GestureReaderFontSize.decrease(18), 16);
    expect(GestureReaderFontSize.increase(28), 28);
    expect(GestureReaderFontSize.decrease(14), 14);
    expect(GestureReaderFontSize.canIncrease(28), isFalse);
    expect(GestureReaderFontSize.canDecrease(14), isFalse);
  });

  test('clamp grampeia fora da faixa', () {
    expect(GestureReaderFontSize.clamp(5), 14);
    expect(GestureReaderFontSize.clamp(99), 28);
  });
}
