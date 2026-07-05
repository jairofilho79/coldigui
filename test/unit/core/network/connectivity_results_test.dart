import 'package:coldigui/core/network/connectivity_results.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connectivityHasUsableConnection', () {
    test('WiFi indica conexão utilizável', () {
      expect(
        connectivityHasUsableConnection([ConnectivityResult.wifi]),
        isTrue,
      );
    });

    test('none indica sem conexão', () {
      expect(
        connectivityHasUsableConnection([ConnectivityResult.none]),
        isFalse,
      );
    });
  });

  group('connectivityIsUnmetered', () {
    test('WiFi é não medido', () {
      expect(connectivityIsUnmetered([ConnectivityResult.wifi]), isTrue);
    });

    test('Ethernet é não medido', () {
      expect(connectivityIsUnmetered([ConnectivityResult.ethernet]), isTrue);
    });

    test('dados móveis não são não medidos', () {
      expect(connectivityIsUnmetered([ConnectivityResult.mobile]), isFalse);
    });

    test('other sem conexão não é não medido', () {
      expect(connectivityIsUnmetered([ConnectivityResult.other]), isFalse);
    });
  });
}
