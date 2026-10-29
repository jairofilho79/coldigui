import 'package:coldigui/features/offline/domain/exceptions/quota_exceeded_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testa [isQuotaExceededError] diretamente — a função foi extraída para um
/// arquivo Dart puro (`quota_exceeded_classifier.dart`) exatamente para que
/// `pdf_storage_web.dart` (que importa `package:web`/`dart:js_interop` e não
/// pode ser importado por um teste rodando na VM) não precise ser tocado por
/// este teste, sem recorrer a uma cópia duplicada da lógica.
void main() {
  test('name == QuotaExceededError é classificado como quota', () {
    expect(
      isQuotaExceededError(name: 'QuotaExceededError', message: ''),
      isTrue,
    );
  });

  test(
    'mensagem contendo "quota" (case-insensitive) é quota mesmo com outro name',
    () {
      expect(
        isQuotaExceededError(
          name: 'UnknownError',
          message: 'The Storage QUOTA has been exceeded',
        ),
        isTrue,
      );
    },
  );

  test('erro sem relação a quota retorna false', () {
    expect(
      isQuotaExceededError(
        name: 'InvalidStateError',
        message: 'cache is closed',
      ),
      isFalse,
    );
  });
}
