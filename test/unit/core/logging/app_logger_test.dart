import 'package:coldigui/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> captured;
  late DebugPrintCallback original;

  setUp(() {
    captured = <String>[];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      captured.add(message ?? '');
    };
  });

  tearDown(() {
    debugPrint = original;
  });

  test('debug formata mensagem com prefixo [feature]', () {
    AppLogger.of('catalog').debug('abrindo cache');

    expect(captured, contains('[catalog] abrindo cache'));
  });

  test('info formata mensagem com prefixo [feature]', () {
    AppLogger.of('audio').info('faixa carregada');

    expect(captured, contains('[audio] faixa carregada'));
  });

  test('warn inclui o erro opcional na mensagem', () {
    AppLogger.of('playlists').warn('estado inconsistente', 'motivo x');

    expect(captured.single, '[playlists] estado inconsistente: motivo x');
  });

  test('warn sem erro opcional so imprime a mensagem', () {
    AppLogger.of('playlists').warn('estado inconsistente');

    expect(captured.single, '[playlists] estado inconsistente');
  });

  test('error formata mensagem, erro e prefixo [feature]', () {
    AppLogger.of('isar').error('falha ao abrir', Exception('boom'));

    expect(captured.first, startsWith('[isar] falha ao abrir'));
    expect(captured.first, contains('boom'));
  });
}
