import 'package:isar_plus/isar_plus.dart';

part 'playlist.g.dart';

/// Playlist do usuário (UC-06/07).
///
/// [playlistId] é UUID estável; [pdfIds] preserva ordem da seleção.
/// [salva] default `true` migra registros existentes como salvas.
@Collection()
class Playlist {
  int id = 0;

  @Index(unique: true)
  late String playlistId;

  late String nome;
  late List<String> pdfIds;
  late DateTime createdAt;

  /// `false` = lista não salva (rascunho automático ao abrir louvor).
  bool salva = true;

  DateTime? savedAt;
  DateTime? favoritedAt;
  bool favorita = false;
}
