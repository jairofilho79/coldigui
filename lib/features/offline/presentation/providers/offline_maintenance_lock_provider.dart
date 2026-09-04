import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quem pode segurar o lock de manutenção offline (spec C.1 / B14).
enum OfflineMaintenanceOwner { bulk, missing, clear, reconcile }

/// Lock cooperativo de manutenção offline (spec C.1 / B14).
///
/// Bulk download, download de faltantes, limpar cache e reconcile mexem no
/// mesmo par índice+disco: rodar em paralelo faz um enxergar arquivos que o
/// outro ainda não indexou (e apagá-los como órfãos). Só um dono por vez.
final offlineMaintenanceLockProvider =
    NotifierProvider<OfflineMaintenanceLock, OfflineMaintenanceOwner?>(
      OfflineMaintenanceLock.new,
    );

/// Estado do lock: `null` = livre; caso contrário o dono atual.
class OfflineMaintenanceLock extends Notifier<OfflineMaintenanceOwner?> {
  @override
  OfflineMaintenanceOwner? build() => null;

  /// `true` quando [owner] passa a segurar (ou já segurava) o lock.
  ///
  /// `false` — sem alterar o estado — quando outro dono está com ele.
  bool tryAcquire(OfflineMaintenanceOwner owner) {
    final current = state;
    if (current != null && current != owner) {
      debugPrint(
        '[offline] manutenção ocupada por ${current.name}: '
        '${owner.name} não adquiriu o lock',
      );
      return false;
    }
    state = owner;
    return true;
  }

  /// Libera o lock; no-op se [owner] não é o dono atual.
  void release(OfflineMaintenanceOwner owner) {
    if (state != owner) return;
    state = null;
  }
}
