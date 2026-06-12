/// Linha da tabela do folheto (UC-08).
class LeafletEntry {
  const LeafletEntry({
    required this.index,
    required this.numero,
    required this.nome,
  });

  /// Posição na lista (1-based).
  final int index;

  /// Número do louvor (coluna NÚMERO).
  final String numero;

  /// Nome do hino (coluna NOME DO HINO).
  final String nome;
}
