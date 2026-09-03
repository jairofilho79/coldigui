import 'package:coldigui/features/offline/presentation/pages/offline_settings_screen.dart';
import 'package:coldigui/l10n/app_localizations_pt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsPt();

  test(
    'failedCount == 0 mostra a mensagem de sucesso simples mesmo em '
    'completedWithWarnings só por unmatchedZipEntries (Task 3/B4 fix round 1)',
    () {
      final message = offlineBulkCompletionMessage(l10n, 0);

      expect(message, l10n.offlineDownloadCompleted);
      expect(message, isNot(contains('0')));
    },
  );

  test('failedCount > 0 mostra a mensagem com contagem de falhas', () {
    final message = offlineBulkCompletionMessage(l10n, 2);

    expect(message, l10n.offlineDownloadCompletedWithFailures(2));
    expect(message, contains('2'));
  });
}
