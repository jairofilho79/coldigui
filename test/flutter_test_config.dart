import 'dart:async';

import 'helpers/isar_plus_test_init.dart';

/// Inicialização global — binário isar_plus antes de qualquer teste.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await ensureIsarPlusTestCore();
  await testMain();
}
