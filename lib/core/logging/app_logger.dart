import 'package:flutter/foundation.dart';

/// Logger simples por feature, com prefixo `[feature]` em toda mensagem.
///
/// `debug`/`info`/`warn` só imprimem em modo debug ([kDebugMode]); `error`
/// sempre imprime, mesmo em release, porque indica uma falha real que
/// precisa aparecer em qualquer log disponível (spec C.9 / E9).
class AppLogger {
  AppLogger._(this._feature);

  final String _feature;

  static AppLogger of(String feature) => AppLogger._(feature);

  void debug(String msg) {
    if (kDebugMode) debugPrint('[$_feature] $msg');
  }

  void info(String msg) {
    if (kDebugMode) debugPrint('[$_feature] $msg');
  }

  void warn(String msg, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint(error == null ? '[$_feature] $msg' : '[$_feature] $msg: $error');
  }

  void error(String msg, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$_feature] $msg: $error');
    if (stackTrace != null && kDebugMode) debugPrint('$stackTrace');
  }
}
