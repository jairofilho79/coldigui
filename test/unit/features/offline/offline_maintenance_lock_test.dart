import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('lock começa livre', () {
    final container = createContainer();
    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });

  test('primeiro dono adquire; segundo dono é recusado', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    expect(lock.tryAcquire(OfflineMaintenanceOwner.coldigom), isTrue);
    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.coldigom,
    );

    expect(lock.tryAcquire(OfflineMaintenanceOwner.reconcile), isFalse);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.normalize), isFalse);
    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.coldigom,
    );
  });

  test('mesmo dono readquire sem perder o lock', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    expect(lock.tryAcquire(OfflineMaintenanceOwner.coldigom), isTrue);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.coldigom), isTrue);
    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.coldigom,
    );
  });

  test('release por dono errado é no-op', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    lock.tryAcquire(OfflineMaintenanceOwner.coldigom);
    lock.release(OfflineMaintenanceOwner.reconcile);

    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.coldigom,
    );
  });

  test('release pelo dono libera para o próximo', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    lock.tryAcquire(OfflineMaintenanceOwner.coldigom);
    lock.release(OfflineMaintenanceOwner.coldigom);

    expect(container.read(offlineMaintenanceLockProvider), isNull);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.reconcile), isTrue);
  });

  test('release com lock livre é no-op', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    lock.release(OfflineMaintenanceOwner.normalize);

    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });
}
