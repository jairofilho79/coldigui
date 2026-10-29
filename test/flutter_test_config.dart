import 'dart:async';

import 'package:flutter/foundation.dart';

import 'helpers/isar_plus_test_init.dart';

/// Inicialização global — binário isar_plus antes de testes VM (não na web).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (!kIsWeb) {
    await ensureIsarPlusTestCore();
  }
  await testMain();
}
