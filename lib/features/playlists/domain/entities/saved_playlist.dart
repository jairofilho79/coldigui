/// Playlist do usuário (UC-06, Fase 4.2+).
///
/// Espelha o modelo persistido sem expor Isar.
class SavedPlaylist {
  const SavedPlaylist({
    required this.playlistId,
    required this.nome,
    required this.pdfIds,
    required this.createdAt,
    this.salva = true,
    this.savedAt,
    this.favoritedAt,
    this.favorita = false,
  });

  /// Identificador estável (UUID-like, compatível com PWA).
  final String playlistId;

  /// Nome exibido na lista — default `lista dd/MM/yyyy HH:mm:ss` na criação.
  final String nome;

  /// IDs dos PDFs na ordem da seleção original.
  final List<String> pdfIds;

  final DateTime createdAt;

  /// `false` quando criada automaticamente ao abrir louvor no leitor.
  final bool salva;

  /// Preenchido ao salvar; ordena aba Salvas.
  final DateTime? savedAt;

  /// Preenchido ao favoritar; ordena aba Favoritas.
  final DateTime? favoritedAt;

  final bool favorita;

  SavedPlaylist copyWith({
    String? playlistId,
    String? nome,
    List<String>? pdfIds,
    DateTime? createdAt,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
  }) {
    return SavedPlaylist(
      playlistId: playlistId ?? this.playlistId,
      nome: nome ?? this.nome,
      pdfIds: pdfIds ?? this.pdfIds,
      createdAt: createdAt ?? this.createdAt,
      salva: salva ?? this.salva,
      savedAt: savedAt ?? this.savedAt,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      favorita: favorita ?? this.favorita,
    );
  }
}
