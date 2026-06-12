import 'package:coldigui/features/leaflet/presentation/utils/leaflet_header_date.dart';
import 'package:coldigui/l10n/app_localizations_pt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatLeafletHeaderDate formata dia da semana e data PT', () {
    final l10n = AppLocalizationsPt();
    final line = formatLeafletHeaderDate(l10n, DateTime(2026, 6, 11));

    expect(line, 'QUINTA-FEIRA 11/06/2026');
  });
}
