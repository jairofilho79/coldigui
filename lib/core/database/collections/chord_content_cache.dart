import 'package:isar_plus/isar_plus.dart';

part 'chord_content_cache.g.dart';

/// Cache persistente do conteúdo `.chord` de um material coldigom.
///
/// Os arquivos têm ~611 B, então guardar o corpo inteiro custa pouco e paga
/// caro: com ele a cifra continua abrindo offline, e uma queda de rede deixa
/// de virar "este louvor não tem cifra".
@Collection()
class ChordContentCache {
  int id = 0;

  /// Chave Coldigom do arquivo, ex.: `assets/praises/p1/m1.chord`.
  @Index(unique: true)
  late String r2Key;

  /// Corpo ChordPro cru, exatamente como veio do Worker.
  late String content;

  /// Quando o corpo foi buscado — base para revalidação em background.
  late DateTime fetchedAt;
}
