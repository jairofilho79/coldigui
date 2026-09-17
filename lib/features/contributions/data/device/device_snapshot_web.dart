import 'dart:ui' show Size;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:web/web.dart' as web;

import '../../domain/entities/device_snapshot.dart';
import '../../domain/ports/device_snapshot_port.dart';

class WebDeviceSnapshotPort implements DeviceSnapshotPort {
  @override
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    return DeviceSnapshot(
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      platform: 'web',
      locale: locale,
      screenW: screen.width.round(),
      screenH: screen.height.round(),
      pixelRatio: pixelRatio,
      online: online,
      pwaStandalone: web.window
          .matchMedia('(display-mode: standalone)')
          .matches,
      userAgent: web.window.navigator.userAgent,
    );
  }
}

DeviceSnapshotPort createDeviceSnapshotPort() => WebDeviceSnapshotPort();
