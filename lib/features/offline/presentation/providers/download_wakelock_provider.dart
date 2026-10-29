import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantém a tela ligada durante um download prolongado (backlog #12).
abstract interface class BulkDownloadWakelock {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusBulkDownloadWakelock implements BulkDownloadWakelock {
  const WakelockPlusBulkDownloadWakelock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final bulkDownloadWakelockProvider = Provider<BulkDownloadWakelock>(
  (ref) => const WakelockPlusBulkDownloadWakelock(),
);
