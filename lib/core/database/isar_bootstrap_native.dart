import 'package:isar_plus/isar_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'isar_app_schemas.dart';

/// Abre Isar no filesystem nativo (iOS/Android/desktop VM).
///
/// [directory] opcional — útil em testes; produção usa documents dir.
Future<Isar> openAppIsar({
  String name = kAppIsarName,
  String? directory,
}) async {
  final dirPath =
      directory ?? (await getApplicationDocumentsDirectory()).path;
  return Isar.open(
    schemas: kAppIsarSchemas,
    directory: dirPath,
    name: name,
  );
}
