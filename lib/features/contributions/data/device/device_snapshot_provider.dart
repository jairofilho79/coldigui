import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ports/device_snapshot_port.dart';
import 'device_snapshot_stub.dart'
    if (dart.library.io) 'device_snapshot_native.dart'
    if (dart.library.js_interop) 'device_snapshot_web.dart';

final deviceSnapshotPortProvider = Provider<DeviceSnapshotPort>(
  (ref) => createDeviceSnapshotPort(),
);
