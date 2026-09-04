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

    expect(lock.tryAcquire(OfflineMaintenanceOwner.bulk), isTrue);
    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.bulk,
    );

    expect(lock.tryAcquire(OfflineMaintenanceOwner.reconcile), isFalse);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.missing), isFalse);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.clear), isFalse);
    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.bulk,
    );
  });

  test('mesmo dono readquire sem perder o lock', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    expect(lock.tryAcquire(OfflineMaintenanceOwner.bulk), isTrue);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.bulk), isTrue);
    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.bulk,
    );
  });

  test('release por dono errado é no-op', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    lock.tryAcquire(OfflineMaintenanceOwner.bulk);
    lock.release(OfflineMaintenanceOwner.reconcile);

    expect(
      container.read(offlineMaintenanceLockProvider),
      OfflineMaintenanceOwner.bulk,
    );
  });

  test('release pelo dono libera para o próximo', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    lock.tryAcquire(OfflineMaintenanceOwner.bulk);
    lock.release(OfflineMaintenanceOwner.bulk);

    expect(container.read(offlineMaintenanceLockProvider), isNull);
    expect(lock.tryAcquire(OfflineMaintenanceOwner.reconcile), isTrue);
  });

  test('release com lock livre é no-op', () {
    final container = createContainer();
    final lock = container.read(offlineMaintenanceLockProvider.notifier);

    lock.release(OfflineMaintenanceOwner.clear);

    expect(container.read(offlineMaintenanceLockProvider), isNull);
  });
}
