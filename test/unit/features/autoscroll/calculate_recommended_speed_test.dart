import 'package:coldigui/features/autoscroll/domain/entities/autoscroll_speed_config.dart';
import 'package:coldigui/features/autoscroll/domain/usecases/calculate_recommended_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateRecommendedSpeed', () {
    test('mantém velocidade quando o tamanho da fonte não muda', () {
      final speed = calculateRecommendedSpeed(
        baseSpeed: 8,
        baseFontSize: 16.0,
        currentFontSize: 16.0,
      );
      expect(speed, 8);
    });

    test('aumenta a velocidade proporcionalmente quando a fonte cresce', () {
      // Se a fonte dobra de 16 para 32, a altura do documento dobra:
      // a velocidade recomendada deve dobrar de 6 para 12.
      final speed = calculateRecommendedSpeed(
        baseSpeed: 6,
        baseFontSize: 16.0,
        currentFontSize: 32.0,
      );
      expect(speed, 12);
    });

    test('diminui a velocidade proporcionalmente quando a fonte diminui', () {
      // Se a fonte cai pela metade de 20 para 10, a velocidade cai de 8 para 4.
      final speed = calculateRecommendedSpeed(
        baseSpeed: 8,
        baseFontSize: 20.0,
        currentFontSize: 10.0,
      );
      expect(speed, 4);
    });

    test('satura no teto máximo de 15', () {
      final speed = calculateRecommendedSpeed(
        baseSpeed: 12,
        baseFontSize: 10.0,
        currentFontSize: 20.0,
      );
      expect(speed, AutoscrollSpeedConfig.max); // 15
    });

    test('satura no piso mínimo de 1', () {
      final speed = calculateRecommendedSpeed(
        baseSpeed: 2,
        baseFontSize: 30.0,
        currentFontSize: 10.0,
      );
      expect(speed, AutoscrollSpeedConfig.min); // 1
    });

    test('retorna baseSpeed grampeada se fontes forem inválidas ou zero', () {
      expect(
        calculateRecommendedSpeed(
          baseSpeed: 8,
          baseFontSize: 0,
          currentFontSize: 16,
        ),
        8,
      );
      expect(
        calculateRecommendedSpeed(
          baseSpeed: 8,
          baseFontSize: 16,
          currentFontSize: 0,
        ),
        8,
      );
    });
  });
}
