import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/datasources/autoscroll_telemetry_datasource.dart';

/// Provider do datasource de telemetria e recomendação de autoscroll.
final autoscrollTelemetryDatasourceProvider =
    Provider<AutoscrollTelemetryDatasource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AutoscrollTelemetryDatasource(prefs);
});
