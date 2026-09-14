import 'dart:math';

import 'package:coldigui/features/live/domain/live_reconnect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backoff 1, 2, 4, 8, 16, 30, 30 s (sem jitter)', () {
    final policy = LiveReconnectPolicy(random: _ZeroRandom());
    expect([0, 1, 2, 3, 4, 5, 9].map(policy.delayFor).map((d) => d.inSeconds), [
      1,
      2,
      4,
      8,
      16,
      30,
      30,
    ]);
  });

  test('jitter fica abaixo de 1 s', () {
    final policy = LiveReconnectPolicy(random: Random(7));
    for (var i = 0; i < 20; i++) {
      final d = policy.delayFor(2);
      expect(d, greaterThanOrEqualTo(const Duration(seconds: 4)));
      expect(d, lessThan(const Duration(seconds: 5)));
    }
  });
}

class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}
