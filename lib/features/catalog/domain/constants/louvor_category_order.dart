/// Ordem de exibição de materiais na sublista (LOUVOR_GROUPING.md).
abstract final class LouvorCategoryOrder {
  static const List<String> displayOrder = [
    'Partitura',
    'Cifra nível I',
    'Cifra nível II',
    'Cifra',
    'Gestos em Gravura',
  ];

  /// Compara categorias para ordenação estável na sublista.
  static int compare(String a, String b) {
    final ia = displayOrder.indexOf(a);
    final ib = displayOrder.indexOf(b);
    final ra = ia == -1 ? displayOrder.length : ia;
    final rb = ib == -1 ? displayOrder.length : ib;
    if (ra != rb) return ra.compareTo(rb);
    return a.compareTo(b);
  }
}
