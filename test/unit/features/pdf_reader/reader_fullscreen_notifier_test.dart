import 'dart:async';

import 'package:coldigui/features/pdf_reader/presentation/platform/reader_fullscreen_platform.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Porta fake (spec A.3 C8) — sobreescreve [readerFullscreenPlatformProvider].
class _FakeReaderFullscreenPlatform implements ReaderFullscreenPlatform {
  final _controller = StreamController<bool>.broadcast();

  var enterCallCount = 0;
  var exitCallCount = 0;

  /// Quando não-nulo, [enter] lança este erro (simula `requestFullscreen`
  /// sem gesto do usuário na web).
  Object? enterError;

  @override
  Future<void> enter() async {
    enterCallCount++;
    final error = enterError;
    if (error != null) throw error;
  }

  @override
  Future<void> exit() async {
    exitCallCount++;
  }

  @override
  Stream<bool> get changes => _controller.stream;

  /// Simula o navegador reportando `fullscreenchange` (ex.: Esc do browser).
  void emitChange(bool value) => _controller.add(value);

  void dispose() => _controller.close();
}

void main() {
  late _FakeReaderFullscreenPlatform platform;
  late ProviderContainer container;

  setUp(() {
    platform = _FakeReaderFullscreenPlatform();
    container = ProviderContainer(
      overrides: [readerFullscreenPlatformProvider.overrideWithValue(platform)],
    );
    addTearDown(container.dispose);
    addTearDown(platform.dispose);
  });

  test('estado inicial é false', () {
    expect(container.read(readerFullscreenProvider), isFalse);
  });

  test('toggle() chama enter() da porta e liga o estado', () async {
    await container.read(readerFullscreenProvider.notifier).toggle();

    expect(platform.enterCallCount, 1);
    expect(container.read(readerFullscreenProvider), isTrue);
  });

  test('toggle() de novo chama exit() da porta e desliga o estado', () async {
    final notifier = container.read(readerFullscreenProvider.notifier);
    await notifier.toggle();
    await notifier.toggle();

    expect(platform.exitCallCount, 1);
    expect(container.read(readerFullscreenProvider), isFalse);
  });

  test('changes emitindo false desliga o estado sem chamar exit() de novo '
      '(navegador saiu sozinho — Esc do browser)', () async {
    await container.read(readerFullscreenProvider.notifier).toggle();
    expect(container.read(readerFullscreenProvider), isTrue);

    platform.emitChange(false);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(readerFullscreenProvider), isFalse);
    expect(platform.exitCallCount, 0);
  });

  test(
    'changes emitindo true não altera nada (já entramos via toggle)',
    () async {
      await container.read(readerFullscreenProvider.notifier).toggle();

      platform.emitChange(true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(readerFullscreenProvider), isTrue);
      expect(platform.exitCallCount, 0);
    },
  );

  test(
    'enter() lançando mantém o estado true (modo imersivo do app) e registra',
    () async {
      platform.enterError = Exception('sem gesto do usuário');
      final captured = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) captured.add(message);
      };

      try {
        await container.read(readerFullscreenProvider.notifier).toggle();
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(container.read(readerFullscreenProvider), isTrue);
      expect(captured.any((line) => line.contains('pdf_reader')), isTrue);
    },
  );
}
