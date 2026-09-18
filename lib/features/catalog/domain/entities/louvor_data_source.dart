/// Espaço de ids de um louvor/material — **não** de onde os bytes vêm.
///
/// Desde a migração do catálogo (set/2026) tudo é servido pelo coldigom; o
/// valor só diz como o id foi cunhado.
enum LouvorDataSource {
  /// Id legado do manifest PLPCG: Base64 de `<classificacao>/<arquivo>.pdf`.
  /// Tem `shortId`; abre pela URL absoluta do campo `pdf`.
  plpcg,

  /// Id nativo Coldigom: Base64 de `assets/praises/<praise>/<material>.<ext>`.
  coldigom,
}
