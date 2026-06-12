import '../../../catalog/domain/entities/louvor.dart';

/// UC-03 — Ordenar louvores (Fase 1.4).
///
/// Ordenação in-memory por [UrlSyncParams.ordenar]: `numero` (padrão) ou `nome`.
class SortLouvores {
  const SortLouvores();

  /// [sortBy] espelha query param `ordenar=` da biblioteca.
  List<Louvor> call(List<Louvor> louvores, {required String sortBy}) {
    final sorted = List<Louvor>.from(louvores);

    if (sortBy == 'nome') {
      sorted.sort((a, b) {
        final byName = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        if (byName != 0) return byName;
        return a.pdfId.compareTo(b.pdfId);
      });
      return sorted;
    }

    sorted.sort((a, b) {
      final byNumber = _compareNumero(a.numero, b.numero);
      if (byNumber != 0) return byNumber;
      return a.pdfId.compareTo(b.pdfId);
    });
    return sorted;
  }

  int _compareNumero(String a, String b) {
    final aNum = int.tryParse(a.trim());
    final bNum = int.tryParse(b.trim());

    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }
    if (aNum != null) return -1;
    if (bNum != null) return 1;

    return a.trim().compareTo(b.trim());
  }
}
