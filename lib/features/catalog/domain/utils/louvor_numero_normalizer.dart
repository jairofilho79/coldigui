/// Normalização de [Louvor.numero] — pad-left com zeros em valores numéricos.
///
/// Espelha `normalize_numero()` em `scripts/assign_louvor_group_ids.py`.
/// Garante ordenação lexicográfica estável em [LouvorGroupId] e listas
/// (`0001` … `0794` em vez de `1`, `10`, `100`…).
///
/// Ex.: `"3"` / `"003"` → `"003"`; `""` permanece vazio; `"PES-609"` inalterado.
abstract final class LouvorNumeroNormalizer {
  /// Largura do pad-left para números puros (acervo atual ≤ 794).
  static const int catalogPadWidth = 3;

  /// Pad-left quando [numero] é só dígitos; demais valores só trim.
  static String normalize(String numero) {
    final trimmed = numero.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return int.parse(trimmed).toString().padLeft(catalogPadWidth, '0');
    }
    return trimmed;
  }
}
