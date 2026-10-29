import 'package:coldigui/features/autoscroll/data/datasources/autoscroll_telemetry_datasource.dart';
import 'package:coldigui/features/autoscroll/domain/entities/autoscroll_adjustment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AutoscrollTelemetryDatasource', () {
    late SharedPreferences prefs;
    late AutoscrollTelemetryDatasource datasource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      datasource = AutoscrollTelemetryDatasource(prefs);
    });

    test('começa com logs vazios e sem recomendação', () {
      expect(datasource.getLogs(), isEmpty);
      expect(
        datasource.getRecommendedSpeed(
          praiseId: '123',
          currentFontSize: 16.0,
        ),
        isNull,
      );
    });

    test('registra ajuste, persiste log e calcula recomendação futura', () async {
      final adjustment = AutoscrollAdjustment(
        praiseId: 'louvor_42',
        materialKind: 'chord',
        speed: 8,
        fontSize: 16.0,
        timestamp: DateTime(2026, 10, 10, 12, 0),
      );

      await datasource.recordAdjustment(adjustment);

      final logs = datasource.getLogs();
      expect(logs.length, 1);
      expect(logs.first.praiseId, 'louvor_42');
      expect(logs.first.speed, 8);
      expect(logs.first.fontSize, 16.0);

      // Com a mesma fonte, a recomendação é 8
      expect(
        datasource.getRecommendedSpeed(
          praiseId: 'louvor_42',
          currentFontSize: 16.0,
        ),
        8,
      );

      // Se a fonte aumenta para 24 (+50%), a recomendação sobe para 12 (+50%)
      expect(
        datasource.getRecommendedSpeed(
          praiseId: 'louvor_42',
          currentFontSize: 24.0,
        ),
        12,
      );

      // Se a fonte diminui para 12 (-25%), a recomendação desce para 6 (-25%)
      expect(
        datasource.getRecommendedSpeed(
          praiseId: 'louvor_42',
          currentFontSize: 12.0,
        ),
        6,
      );
    });

    test('ignora ajustes com praiseId vazio', () async {
      await datasource.recordAdjustment(
        AutoscrollAdjustment(
          praiseId: '',
          materialKind: 'lyrics',
          speed: 8,
          fontSize: 16.0,
          timestamp: DateTime.now(),
        ),
      );

      expect(datasource.getLogs(), isEmpty);
    });

    test('clearLogs remove registros e recomendações', () async {
      await datasource.recordAdjustment(
        AutoscrollAdjustment(
          praiseId: 'praise_1',
          materialKind: 'gesture',
          speed: 10,
          fontSize: 20.0,
          timestamp: DateTime.now(),
        ),
      );

      expect(datasource.getLogs().length, 1);
      await datasource.clearLogs();
      expect(datasource.getLogs(), isEmpty);
      expect(
        datasource.getRecommendedSpeed(
          praiseId: 'praise_1',
          currentFontSize: 20.0,
        ),
        isNull,
      );
    });

    test('exportLogsJson retorna string json dos registros', () async {
      await datasource.recordAdjustment(
        AutoscrollAdjustment(
          praiseId: 'praise_1',
          materialKind: 'chord',
          speed: 9,
          fontSize: 18.0,
          timestamp: DateTime(2026, 1, 1),
        ),
      );

      final exported = datasource.exportLogsJson();
      expect(exported, contains('"praiseId":"praise_1"'));
      expect(exported, contains('"speed":9'));
    });
  });
}
