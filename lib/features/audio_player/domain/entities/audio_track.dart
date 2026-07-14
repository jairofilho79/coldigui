import '../../../catalog/domain/entities/louvor_data_source.dart';

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
    this.source = LouvorDataSource.coldigom,
    this.duration,
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
  final LouvorDataSource source;

  /// Duração descoberta pelo player, se já conhecida.
  final Duration? duration;

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
      source: source,
      duration: duration ?? this.duration,
    );
  }
}
