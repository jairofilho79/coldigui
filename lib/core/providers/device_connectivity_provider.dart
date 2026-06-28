import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/device_connectivity.dart';

final deviceConnectivityProvider = Provider<DeviceConnectivity>((ref) {
  return ConnectivityDeviceConnectivity();
});
