import '../../domain/ports/device_snapshot_port.dart';

/// Par do import condicional — nunca chega a rodar (nativo e web têm impl).
DeviceSnapshotPort createDeviceSnapshotPort() => throw UnsupportedError(
  'DeviceSnapshotPort sem implementação nesta plataforma',
);
