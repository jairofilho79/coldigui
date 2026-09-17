import 'dart:ui' show Size;

import '../entities/device_snapshot.dart';

/// Coleta o que é do SO/navegador. O que é do Flutter (tela, idioma,
/// conectividade) vem por parâmetro — assim o port não precisa de BuildContext
/// e é trivial de falsear em teste.
abstract class DeviceSnapshotPort {
  Future<DeviceSnapshot> collect({
    required Size screen,
    required double pixelRatio,
    required String locale,
    required bool online,
  });
}
