import 'package:isar_plus/isar_plus.dart';

import 'isar_app_schemas.dart';

/// Abre Isar na web (SQLite/WASM + OPFS ou IndexedDB). Requer [Isar.initialize] explícito.
///
/// [directory] é ignorado — storage web usa VFS persistente (`isar_data`).
Future<Isar> openAppIsar({
  String name = kAppIsarName,
  String? directory,
}) async {
  // Assets em web/ (mesma origem) — OPFS exige COEP require-corp; unpkg quebra ou falha no backend.
  await Isar.initialize('isar_plus.wasm');
  return Isar.open(
    schemas: kAppIsarSchemas,
    directory: directory ?? 'isar_data',
    name: name,
    engine: IsarEngine.sqlite,
  );
}
