/// Faixa de áudio Coldigom — independente de [Louvor] (PDF).
class AudioTrack {
  const AudioTrack({
    required this.audioId,
    required this.r2Key,
    required this.nome,
    required this.numero,
    required this.groupId,
    required this.categoria,
    required this.classificacao,
    this.author = '',
    this.duration,
    this.materialKindId,
  });

  /// Identificador estável (mesmo codec Base64 do path relativo).
  final String audioId;

  /// Path R2 (`assets/praises/...`).
  final String r2Key;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do material (ex.: "Áudio", "Playback").
  final String categoria;

  /// Classificação / ritmo.
  final String classificacao;

  final String author;

  /// Duração descoberta pelo player, se já conhecida.
  final Duration? duration;

  /// Id do `material_kind` Coldigom; `null` quando o dump não traz o kind.
  final String? materialKindId;

  AudioTrack copyWith({Duration? duration}) {
    return AudioTrack(
      audioId: audioId,
      r2Key: r2Key,
      nome: nome,
      numero: numero,
      groupId: groupId,
      categoria: categoria,
      classificacao: classificacao,
      author: author,
      duration: duration ?? this.duration,
      materialKindId: materialKindId,
    );
  }
}
