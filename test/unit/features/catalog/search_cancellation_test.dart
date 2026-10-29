import 'package:coldigui/features/catalog/domain/ports/search_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchCancellation', () {
    test(
      'nasce não cancelada e whenCancelled só resolve após cancel',
      () async {
        final cancellation = SearchCancellation();

        expect(cancellation.isCancelled, isFalse);

        var resolved = false;
        unawaitedThen(cancellation.whenCancelled, () => resolved = true);
        await Future<void>.delayed(Duration.zero);
        expect(resolved, isFalse);

        cancellation.cancel();
        await cancellation.whenCancelled;

        expect(cancellation.isCancelled, isTrue);
        expect(resolved, isTrue);
      },
    );

    test('cancel é idempotente', () async {
      final cancellation = SearchCancellation()..cancel();

      expect(() => cancellation.cancel(), returnsNormally);
      expect(cancellation.isCancelled, isTrue);
      await expectLater(cancellation.whenCancelled, completes);
    });

    test('whenCancelled já cancelada resolve sem travar', () async {
      final cancellation = SearchCancellation()..cancel();

      await expectLater(cancellation.whenCancelled, completes);
    });
  });

  test('SearchCancelledException é uma Exception distinguível', () {
    const error = SearchCancelledException();

    expect(error, isA<Exception>());
    expect(error.toString(), contains('cancel'));
  });
}

/// `future.then` sem `unawaited` explícito (evita import de `dart:async` só
/// para isso no teste).
void unawaitedThen(Future<void> future, void Function() onDone) {
  future.then((_) => onDone());
}
