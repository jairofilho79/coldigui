import 'louvor_data_source.dart';

/// Material YouTube Coldigom — abre URL externa (app / navegador).
class YoutubeMaterial {
  const YoutubeMaterial({
    required this.id,
    required this.url,
    required this.nome,
    required this.numero,
    required this.groupId,
    required this.categoria,
    required this.classificacao,
    this.author = '',
    this.source = LouvorDataSource.coldigom,
  });

  final String id;

  /// URL HTTPS do vídeo (youtube.com / youtu.be).
  final String url;

  final String nome;
  final String numero;
  final String groupId;

  /// Label do kind (ex.: "Áudio", "Gestos CIAs").
  final String categoria;

  final String classificacao;
  final String author;
  final LouvorDataSource source;
}
