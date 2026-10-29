import 'dart:ui' show Size;

import 'package:coldigui/features/contributions/domain/entities/device_snapshot.dart';
import 'package:coldigui/features/contributions/domain/ports/device_snapshot_port.dart';

class FakeDeviceSnapshotPort implements DeviceSnapshotPort {
  FakeDeviceSnapshotPort([
    this.snapshot = const DeviceSnapshot(
      appVersion: '0.0.0',
      buildNumber: '1',
      platform: 'test',
      locale: 'pt',
      screenW: 400,
      screenH: 800,
      pixelRatio: 2,
      online: true,
      pwaStandalone: false,
      model: 'Fake',
      osVersion: 'Test 1',
    ),
  ]);

  final DeviceSnapshot snapshot;

  @override
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  }) async => snapshot;
}
