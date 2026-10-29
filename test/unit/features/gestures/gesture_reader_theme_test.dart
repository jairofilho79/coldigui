import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claro é creme com texto escuro; escuro é carvão com texto claro', () {
    final light = GestureReaderMode.light.palette;
    final dark = GestureReaderMode.dark.palette;
    expect(light.paper, AppColors.card);
    expect(light.lyric, AppColors.textDark);
    expect(light.toolbarIcon, AppColors.title);
    expect(dark.paper, AppColors.pdfArea);
    expect(dark.lyric, AppColors.textLight);
    expect(dark.toolbarIcon, AppColors.goldLight);
  });

  test('a figura fica em quadro branco nos dois temas', () {
    expect(GestureReaderMode.light.palette.figureBg.toARGB32(), 0xFFFFFFFF);
    expect(GestureReaderMode.dark.palette.figureBg.toARGB32(), 0xFFFFFFFF);
  });

  test('toggle alterna; serialização ida e volta; inválido é null', () {
    expect(GestureReaderMode.light.toggle(), GestureReaderMode.dark);
    expect(GestureReaderMode.dark.toggle(), GestureReaderMode.light);
    for (final mode in GestureReaderMode.values) {
      expect(GestureReaderMode.fromStorageString(mode.toStorageString()), mode);
    }
    expect(GestureReaderMode.fromStorageString('sepia'), isNull);
    expect(GestureReaderMode.fromStorageString(null), isNull);
  });
}
