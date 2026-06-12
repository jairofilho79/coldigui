import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LouvorClassification displayLabel', () {
    test('converte Col* em Coletânea *', () {
      expect(
        LouvorClassification.displayLabel('ColCIAs'),
        'Coletânea CIAs',
      );
      expect(
        LouvorClassification.displayLabel('ColAdultos'),
        'Coletânea Adultos',
      );
    });

    test('ignora arranjo especial entre parênteses', () {
      expect(
        LouvorClassification.displayLabel('ColAdultos (Especial)'),
        'Coletânea Adultos',
      );
    });

    test('retorna base quando não segue padrão Col', () {
      expect(
        LouvorClassification.displayLabel('Outra'),
        'Outra',
      );
    });

    test('não reexpande rótulo já amigável (Coletânea …)', () {
      expect(
        LouvorClassification.displayLabel('Coletânea Adultos'),
        'Coletânea Adultos',
      );
      expect(
        LouvorClassification.displayLabel('Coletânea CIAs'),
        'Coletânea CIAs',
      );
    });
  });

  group('LouvorClassification special arrangement', () {
    test('specialArrangement extrai texto entre parênteses', () {
      expect(
        LouvorClassification.specialArrangement('ColAdultos (Especial)'),
        'Especial',
      );
    });

    test('specialArrangement sem parênteses retorna Padrão', () {
      expect(
        LouvorClassification.specialArrangement('ColAdultos'),
        LouvorClassification.specialArrangementPadrao,
      );
    });

    test('parseSpecialArrangementsFromUrl vazio retorna conjunto vazio', () {
      expect(
        LouvorClassification.parseSpecialArrangementsFromUrl(null),
        isEmpty,
      );
    });

    test('parseSpecialArrangementsFromUrl parseia CSV', () {
      expect(
        LouvorClassification.parseSpecialArrangementsFromUrl('Padrão,Especial'),
        {'Padrão', 'Especial'},
      );
    });

    test('serializeSpecialArrangementsForUrl omite quando vazio', () {
      expect(
        LouvorClassification.serializeSpecialArrangementsForUrl({}),
        isNull,
      );
    });

    test('serializeSpecialArrangementsForUrl junta CSV', () {
      expect(
        LouvorClassification.serializeSpecialArrangementsForUrl({'Especial'}),
        'Especial',
      );
    });
  });
}
