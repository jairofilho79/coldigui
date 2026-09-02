import 'package:flutter_test/flutter_test.dart';

/// Espelha [PdfStorageWeb.isQuotaExceededError] — `DOMException` não é
/// instanciável na VM (fora de contexto web/JS interop), então a lógica pura
/// de classificação é testada aqui como cópia fiel da implementação real em
/// `pdf_storage_web.dart`.
bool isQuotaExceededError({required String name, required String message}) {
  return name == 'QuotaExceededError' ||
      message.toLowerCase().contains('quota');
}

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
