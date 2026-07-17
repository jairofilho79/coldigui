/// Payload Worker `/api/audio-flags`.
class RemoteAudioFlag {
  const RemoteAudioFlag({
    required this.id,
    required this.audioId,
    required this.positionMs,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.label = '',
  });

  final String id;
  final String audioId;
  final int positionMs;
  final String label;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  factory RemoteAudioFlag.fromJson(Map<String, dynamic> json) {
    return RemoteAudioFlag(
      id: json['id'] as String,
      audioId: json['audioId'] as String,
      positionMs: (json['positionMs'] as num).toInt(),
      label: json['label'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'audioId': audioId,
    'positionMs': positionMs,
    'label': label,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'version': version,
  };
}
