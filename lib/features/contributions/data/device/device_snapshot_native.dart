import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/device_snapshot.dart';
import '../../domain/ports/device_snapshot_port.dart';

/// Um bug report não pode morrer porque um plugin de metadados falhou (canal
/// de plataforma indisponível, build restrito de OEM, etc.) — por isso as
/// duas fontes ([loadPackageInfo] e o device_info_plus) são injetáveis (para
/// testar a degradação sem depender de plugin nativo) e cada uma é isolada
/// em seu próprio try/catch: uma falha vira valor desconhecido, nunca exceção.
class NativeDeviceSnapshotPort implements DeviceSnapshotPort {
  NativeDeviceSnapshotPort({
    Future<PackageInfo> Function()? loadPackageInfo,
    DeviceInfoPlugin? deviceInfo,
  }) : _loadPackageInfo = loadPackageInfo ?? PackageInfo.fromPlatform,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final Future<PackageInfo> Function() _loadPackageInfo;
  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  }) async {
    var appVersion = 'desconhecida';
    var buildNumber = '0';
    try {
      final pkg = await _loadPackageInfo();
      appVersion = pkg.version;
      buildNumber = pkg.buildNumber;
    } catch (e) {
      debugPrint('[contributions] package_info falhou: $e');
    }

    String? manufacturer;
    String? model;
    String? osVersion;
    try {
      if (Platform.isAndroid) {
        final a = await _deviceInfo.androidInfo;
        manufacturer = a.manufacturer;
        model = a.model;
        osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
      } else if (Platform.isIOS) {
        final i = await _deviceInfo.iosInfo;
        manufacturer = 'Apple';
        model = i.utsname.machine;
        osVersion = '${i.systemName} ${i.systemVersion}';
      }
    } catch (e) {
      debugPrint('[contributions] device_info falhou: $e');
    }

    return DeviceSnapshot(
      appVersion: appVersion,
      buildNumber: buildNumber,
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
