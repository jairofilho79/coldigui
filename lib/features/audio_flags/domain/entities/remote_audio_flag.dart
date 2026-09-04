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

  /// Lê um marcador do wire.
  ///
  /// Um campo obrigatório ausente ou com tipo inesperado vira [FormatException]
  /// **nomeando o campo** — em vez do `TypeError` cru que um `as` solta —, para
  /// quem chama poder descartar só o registro ruim (mesmo contrato de
  /// `RemotePlaylist.fromJson`, spec A.7).
  factory RemoteAudioFlag.fromJson(Map<String, dynamic> json) {
    return RemoteAudioFlag(
      id: _requiredString(json, 'id'),
      audioId: _requiredString(json, 'audioId'),
      positionMs: _requiredInt(json, 'positionMs'),
      label: json['label'] as String? ?? '',
      createdAt: _requiredDate(json, 'createdAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      version: json['version'] is int ? json['version'] as int : 1,
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

  static String _requiredString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String || value.isEmpty) {
      throw FormatException(
        'RemoteAudioFlag: campo "$field" obrigatório ausente ou inválido '
        '(veio $value)',
      );
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num) {
      throw FormatException(
        'RemoteAudioFlag: campo "$field" deve ser numérico (veio $value)',
      );
    }
    return value.toInt();
  }

  static DateTime _requiredDate(Map<String, dynamic> json, String field) {
    final value = json[field];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      throw FormatException(
        'RemoteAudioFlag: campo "$field" não é uma data ISO-8601 (veio $value)',
      );
    }
    return parsed;
  }
}
