/// `409` do Worker: a linha remota é mais nova que a `updatedAt` enviada.
///
/// Mora aqui, junto de [RemoteAudioFlag], porque carrega uma: o caso de uso de
/// sync (domínio) precisa dela sem enxergar a camada `data` — mesmo desenho de
/// `PlaylistConflictException`.
class AudioFlagConflictException implements Exception {
  const AudioFlagConflictException(this.remote);

  /// Linha atual do servidor, que veio no corpo do 409.
  final RemoteAudioFlag remote;

  @override
  String toString() =>
      'AudioFlagConflictException(${remote.id} v${remote.version} '
      '@ ${remote.updatedAt.toIso8601String()})';
}

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
    this.deletedAt,
  });

  final String id;
  final String audioId;
  final int positionMs;
  final String label;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  /// Tombstone do servidor (`?includeDeleted=1`); `null` nas linhas vivas.
  ///
  /// Também `null` quando o Worker ainda não devolve o campo — a exclusão
  /// remota nunca é deduzida por ausência da linha (spec A.2).
  final DateTime? deletedAt;

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
      deletedAt: _optionalDate(json, 'deletedAt'),
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

  /// Data opcional: ausente ou `null` → `null`; presente e ilegível →
  /// [FormatException] (o registro inteiro é descartado por quem chama).
  ///
  /// Tratar `'ontem'` como "sem tombstone" apagaria a diferença entre uma linha
  /// viva e uma que o servidor disse ter apagado.
  static DateTime? _optionalDate(Map<String, dynamic> json, String field) {
    if (!json.containsKey(field)) return null;
    final value = json[field];
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      throw FormatException(
        'RemoteAudioFlag: campo "$field" não é uma data ISO-8601 (veio $value)',
      );
    }
    return parsed;
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
