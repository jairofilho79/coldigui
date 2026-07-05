import 'package:isar_plus/isar_plus.dart';

import 'isar_app_schemas.dart';

/// Abre Isar na web (IndexedDB). Requer [Isar.initialize] explícito.
///
/// [directory] é ignorado — storage web não usa path de filesystem.
Future<Isar> openAppIsar({
  String name = kAppIsarName,
  String? directory,
}) async {
  await Isar.initialize();
  return Isar.open(
    schemas: kAppIsarSchemas,
    directory: directory ?? '',
    name: name,
  );
}
