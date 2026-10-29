import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/autoscroll_adjustment.dart';
import '../../domain/usecases/calculate_recommended_speed.dart';

/// Datasource responsável por:
/// 1. Registrar histórico de ajustes de autoscroll por louvor e emitir logs diagnósticos.
/// 2. Manter mapa de perfis por louvor e calcular velocidade recomendada
///    ponderada pelo corpo de letra atual.
class AutoscrollTelemetryDatasource {
  AutoscrollTelemetryDatasource(this._prefs);

  final SharedPreferences _prefs;
  final AppLogger _log = AppLogger.of('autoscroll');

  static const int _maxStoredLogs = 500;

  /// Registra o ajuste do usuário, persistindo no histórico e atualizando
  /// a recomendação base para o louvor.
  Future<void> recordAdjustment(AutoscrollAdjustment adjustment) async {
    if (adjustment.praiseId.isEmpty) return;

    _log.info(
      'Ajuste autoscroll: louvor=${adjustment.praiseId} '
      '(${adjustment.materialKind}) -> vel=${adjustment.speed}, '
      'fonte=${adjustment.fontSize}',
    );

    // 1. Atualiza lista cronológica de logs (com limite de tamanho).
    final currentLogs = getLogs();
    currentLogs.add(adjustment);
    if (currentLogs.length > _maxStoredLogs) {
      currentLogs.removeRange(0, currentLogs.length - _maxStoredLogs);
    }
    final encodedLogs = jsonEncode(
      currentLogs.map((e) => e.toJson()).toList(growable: false),
    );
    await _prefs.setString(StorageKeys.autoscrollAdjustmentsLog, encodedLogs);

    // 2. Atualiza perfil de recomendação rápida por louvor.
    final recs = _getRecommendationsRaw();
    recs[adjustment.praiseId] = {
      'speed': adjustment.speed,
      'fontSize': adjustment.fontSize,
      'materialKind': adjustment.materialKind,
      'updatedAt': adjustment.timestamp.toIso8601String(),
    };
    await _prefs.setString(
      StorageKeys.praiseAutoscrollRecommendations,
      jsonEncode(recs),
    );
  }

  /// Retorna a velocidade recomendada para o louvor [praiseId] dado o
  /// [currentFontSize] em vigor. Retorna `null` se não houver ajuste prévio.
  int? getRecommendedSpeed({
    required String praiseId,
    required double currentFontSize,
    String? materialKind,
  }) {
    if (praiseId.isEmpty) return null;
    final recs = _getRecommendationsRaw();
    final profile = recs[praiseId];
    if (profile == null || profile is! Map) return null;

    final baseSpeed = (profile['speed'] as num?)?.toInt();
    final baseFontSize = (profile['fontSize'] as num?)?.toDouble();
    if (baseSpeed == null || baseFontSize == null) return null;

    final recommended = calculateRecommendedSpeed(
      baseSpeed: baseSpeed,
      baseFontSize: baseFontSize,
      currentFontSize: currentFontSize,
    );

    _log.debug(
      'Recomendação calculada para $praiseId: base=($baseSpeed @ ${baseFontSize}px), '
      'atual=${currentFontSize}px -> vel=$recommended',
    );
    return recommended;
  }

  /// Retorna lista de todos os ajustes registrados.
  List<AutoscrollAdjustment> getLogs() {
    final raw = _prefs.getString(StorageKeys.autoscrollAdjustmentsLog);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AutoscrollAdjustment.fromJson)
          .toList();
    } catch (e) {
      _log.warn('Falha ao decodificar logs de autoscroll: $e');
      return [];
    }
  }

  /// Exporta todos os logs como JSON formatado.
  String exportLogsJson() {
    final logs = getLogs();
    return jsonEncode(logs.map((e) => e.toJson()).toList());
  }

  /// Limpa logs e perfis de recomendação.
  Future<void> clearLogs() async {
    await _prefs.remove(StorageKeys.autoscrollAdjustmentsLog);
    await _prefs.remove(StorageKeys.praiseAutoscrollRecommendations);
    _log.info('Logs e recomendações de autoscroll apagados');
  }

  Map<String, dynamic> _getRecommendationsRaw() {
    final raw = _prefs.getString(StorageKeys.praiseAutoscrollRecommendations);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
