import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_page_keyboard_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atalho de leitura: a política é pura, então cada caso é só (tecla, mods,
/// extremidades) -> ação.
PdfKeyAction act(
  LogicalKeyboardKey key, {
  bool first = false,
  bool last = false,
  bool ctrl = false,
  bool meta = false,
  bool shift = false,
}) {
  return PdfPageKeyboardPolicy.actionForKey(
    key: key,
    isFirstPage: first,
    isLastPage: last,
    isControlPressed: ctrl,
    isMetaPressed: meta,
    isShiftPressed: shift,
  );
}

void main() {
  group('PdfPageKeyboardPolicy.actionForKey — próxima página', () {
    test('arrowRight no meio avança página', () {
      expect(act(LogicalKeyboardKey.arrowRight), PdfKeyAction.nextPage);
    });

    test('arrowDown avança página', () {
      expect(act(LogicalKeyboardKey.arrowDown), PdfKeyAction.nextPage);
    });

    test('pageDown avança página', () {
      expect(act(LogicalKeyboardKey.pageDown), PdfKeyAction.nextPage);
    });

    test('espaço avança página', () {
      expect(act(LogicalKeyboardKey.space), PdfKeyAction.nextPage);
    });
  });

  group('PdfPageKeyboardPolicy.actionForKey — página anterior', () {
    test('arrowLeft no meio volta página', () {
      expect(act(LogicalKeyboardKey.arrowLeft), PdfKeyAction.previousPage);
    });

    test('arrowUp volta página', () {
      expect(act(LogicalKeyboardKey.arrowUp), PdfKeyAction.previousPage);
    });

    test('pageUp volta página', () {
      expect(act(LogicalKeyboardKey.pageUp), PdfKeyAction.previousPage);
    });

    test('shift+espaço volta página', () {
      expect(
        act(LogicalKeyboardKey.space, shift: true),
        PdfKeyAction.previousPage,
      );
    });
  });

  group('PdfPageKeyboardPolicy.actionForKey — extremos do documento', () {
    test('home vai para a primeira página', () {
      expect(act(LogicalKeyboardKey.home), PdfKeyAction.firstPage);
    });

    test('end vai para a última página', () {
      expect(act(LogicalKeyboardKey.end), PdfKeyAction.lastPage);
    });
  });

  group('PdfPageKeyboardPolicy.actionForKey — pedaleira', () {
    test('última página + arrowRight avança para o próximo louvor', () {
      expect(
        act(LogicalKeyboardKey.arrowRight, last: true),
        PdfKeyAction.nextLouvor,
      );
    });

    test('última página + pageDown avança para o próximo louvor', () {
      expect(
        act(LogicalKeyboardKey.pageDown, last: true),
        PdfKeyAction.nextLouvor,
      );
    });

    test('primeira página + arrowLeft volta para o louvor anterior', () {
      expect(
        act(LogicalKeyboardKey.arrowLeft, first: true),
        PdfKeyAction.previousLouvor,
      );
    });

    test('primeira página + pageUp volta para o louvor anterior', () {
      expect(
        act(LogicalKeyboardKey.pageUp, first: true),
        PdfKeyAction.previousLouvor,
      );
    });

    test('última página + espaço continua sendo troca de página', () {
      expect(act(LogicalKeyboardKey.space, last: true), PdfKeyAction.nextPage);
    });
  });

  group('PdfPageKeyboardPolicy.actionForKey — louvor do carousel', () {
    test('ctrl+arrowRight vai para o próximo louvor', () {
      expect(
        act(LogicalKeyboardKey.arrowRight, ctrl: true),
        PdfKeyAction.nextLouvor,
      );
    });

    test('cmd+arrowRight vai para o próximo louvor', () {
      expect(
        act(LogicalKeyboardKey.arrowRight, meta: true),
        PdfKeyAction.nextLouvor,
      );
    });

    test('ctrl+arrowLeft volta para o louvor anterior', () {
      expect(
        act(LogicalKeyboardKey.arrowLeft, ctrl: true),
        PdfKeyAction.previousLouvor,
      );
    });

    test('N vai para o próximo louvor', () {
      expect(act(LogicalKeyboardKey.keyN), PdfKeyAction.nextLouvor);
    });

    test('P volta para o louvor anterior', () {
      expect(act(LogicalKeyboardKey.keyP), PdfKeyAction.previousLouvor);
    });

    test('ctrl+N é do navegador, não do leitor', () {
      expect(act(LogicalKeyboardKey.keyN, ctrl: true), PdfKeyAction.none);
    });

    test('ctrl+P é impressão, não do leitor', () {
      expect(act(LogicalKeyboardKey.keyP, ctrl: true), PdfKeyAction.none);
    });
  });

  group('PdfPageKeyboardPolicy.actionForKey — teclas não tratadas', () {
    test('ctrl+espaço fica para o play/pause global', () {
      expect(act(LogicalKeyboardKey.space, ctrl: true), PdfKeyAction.none);
    });

    test('cmd+espaço fica para o play/pause global', () {
      expect(act(LogicalKeyboardKey.space, meta: true), PdfKeyAction.none);
    });

    test('ctrl+arrowUp fica para o tamanho da fonte do leitor de cifras', () {
      expect(act(LogicalKeyboardKey.arrowUp, ctrl: true), PdfKeyAction.none);
    });

    test('ctrl+arrowDown não troca página', () {
      expect(act(LogicalKeyboardKey.arrowDown, ctrl: true), PdfKeyAction.none);
    });

    test('F fica para o atalho global de tela cheia', () {
      expect(act(LogicalKeyboardKey.keyF), PdfKeyAction.none);
    });

    test('escape fica para o atalho global de sair da tela cheia', () {
      expect(act(LogicalKeyboardKey.escape), PdfKeyAction.none);
    });
  });
}
