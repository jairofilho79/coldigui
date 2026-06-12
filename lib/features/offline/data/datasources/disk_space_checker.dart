import 'package:disk_space_plus/disk_space_plus.dart';

/// Consulta espaço livre no volume de armazenamento (UC-09).
class DiskSpaceChecker {
  DiskSpaceChecker({DiskSpacePlus? diskSpacePlus})
      : _diskSpacePlus = diskSpacePlus ?? DiskSpacePlus();

  final DiskSpacePlus _diskSpacePlus;

  /// Retorna bytes livres ou `null` se indisponível (ex.: simulador).
  Future<int?> getFreeBytes() async {
    final freeMb = await _diskSpacePlus.getFreeDiskSpace;
    if (freeMb == null) return null;
    return (freeMb * 1024 * 1024).round();
  }
}
