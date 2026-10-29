import 'autoscroll_speed_config.dart';

/// Registro de um ajuste de velocidade de autoscroll feito por um usuário
/// em um louvor específico, associado ao tamanho da fonte em vigor.
class AutoscrollAdjustment {
  const AutoscrollAdjustment({
    required this.praiseId,
    required this.materialKind,
    required this.speed,
    required this.fontSize,
    required this.timestamp,
  });

  /// Identificador único do louvor (ex.: `groupId` ou `praiseId`).
  final String praiseId;

  /// Tipo de leitor / material: `'chord'`, `'gesture'`, `'lyrics'`.
  final String materialKind;

  /// Velocidade discreta escolhida (entre [AutoscrollSpeedConfig.min] e [AutoscrollSpeedConfig.max]).
  final int speed;

  /// Tamanho da fonte ativo no momento do ajuste (dp/px).
  final double fontSize;

  /// Momento em que o ajuste foi registrado.
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'praiseId': praiseId,
    'materialKind': materialKind,
    'speed': speed,
    'fontSize': fontSize,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AutoscrollAdjustment.fromJson(Map<String, dynamic> json) =>
      AutoscrollAdjustment(
        praiseId: json['praiseId'] as String? ?? '',
        materialKind: json['materialKind'] as String? ?? '',
        speed: (json['speed'] as num?)?.toInt() ?? AutoscrollSpeedConfig.initial,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AutoscrollAdjustment &&
          other.praiseId == praiseId &&
          other.materialKind == materialKind &&
          other.speed == speed &&
          other.fontSize == fontSize &&
          other.timestamp == timestamp);

  @override
  int get hashCode => Object.hash(
        praiseId,
        materialKind,
        speed,
        fontSize,
        timestamp,
      );
}
