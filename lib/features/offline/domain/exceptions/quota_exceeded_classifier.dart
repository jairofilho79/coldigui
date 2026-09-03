/// Classifica um erro de `cache.put` (web) como estouro de quota do navegador.
///
/// Extraída para um arquivo Dart puro (Task 3/B4 fix round 1) para que possa
/// ser testada diretamente por um teste de unidade na VM — `pdf_storage_web.dart`
/// importa `package:web`/`dart:js_interop` e não pode ser importado por um
/// teste rodando na VM.
bool isQuotaExceededError({required String name, required String message}) {
  return name == 'QuotaExceededError' ||
      message.toLowerCase().contains('quota');
}
