import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/device_snapshot.dart';
import '../../domain/ports/device_snapshot_port.dart';

class NativeDeviceSnapshotPort implements DeviceSnapshotPort {
  @override
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final info = DeviceInfoPlugin();
    String? manufacturer;
    String? model;
    String? osVersion;
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      manufacturer = a.manufacturer;
      model = a.model;
      osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      manufacturer = 'Apple';
      model = i.utsname.machine;
      osVersion = '${i.systemName} ${i.systemVersion}';
    }
    return DeviceSnapshot(
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      platform: Platform.operatingSystem,
      locale: locale,
      screenW: screen.width.round(),
      screenH: screen.height.round(),
      pixelRatio: pixelRatio,
      online: online,
      pwaStandalone: false,
      manufacturer: manufacturer,
      model: model,
      osVersion: osVersion,
    );
  }
}

DeviceSnapshotPort createDeviceSnapshotPort() => NativeDeviceSnapshotPort();
