import 'package:isar_plus/isar_plus.dart';

part 'gesture_document_cache.g.dart';

/// Cache persistente do documento `.gestures` de um material coldigom.
///
/// Cópia fiel de `ChordContentCache`: JSON de 2–8 KB, guardar o corpo inteiro
/// é o que faz o louvor abrir offline e impede que uma queda de rede vire
/// "este louvor não tem gestos". [content] vazio é o marcador negativo (404).
@Collection()
class GestureDocumentCache {
  int id = 0;

  /// Chave Coldigom do arquivo, ex.: `assets/praises/p1/m1.gestures`.
  @Index(unique: true)
  late String r2Key;

  /// JSON cru, exatamente como veio do Worker; vazio = não existe.
  late String content;

  /// Quando o corpo foi buscado — base para revalidação em background.
  late DateTime fetchedAt;
}
