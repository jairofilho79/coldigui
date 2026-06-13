import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:coldigui/features/pdf_reader/data/datasources/connectivity_network_connection_checker.dart';
import 'package:coldigui/features/pdf_reader/data/policies/wifi_only_prefetch_network_policy.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this._results);

  final List<ConnectivityResult> _results;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _results;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ConnectivityNetworkConnectionChecker', () {
    test('WiFi é conexão não medida', () async {
      final checker = ConnectivityNetworkConnectionChecker(
        _FakeConnectivity([ConnectivityResult.wifi]),
      );
      expect(await checker.isUnmeteredConnection(), isTrue);
    });

    test('Ethernet é conexão não medida', () async {
      final checker = ConnectivityNetworkConnectionChecker(
        _FakeConnectivity([ConnectivityResult.ethernet]),
      );
      expect(await checker.isUnmeteredConnection(), isTrue);
    });

    test('dados móveis não são conexão não medida', () async {
      final checker = ConnectivityNetworkConnectionChecker(
        _FakeConnectivity([ConnectivityResult.mobile]),
      );
      expect(await checker.isUnmeteredConnection(), isFalse);
    });
  });

  group('WifiOnlyPrefetchNetworkPolicy', () {
    test('permite prefetch em WiFi', () async {
      final policy = WifiOnlyPrefetchNetworkPolicy(
        ConnectivityNetworkConnectionChecker(
          _FakeConnectivity([ConnectivityResult.wifi]),
        ),
      );
      expect(await policy.allowsAdjacentPdfPrefetch(), isTrue);
    });

    test('bloqueia prefetch em dados móveis', () async {
      final policy = WifiOnlyPrefetchNetworkPolicy(
        ConnectivityNetworkConnectionChecker(
          _FakeConnectivity([ConnectivityResult.mobile]),
        ),
      );
      expect(await policy.allowsAdjacentPdfPrefetch(), isFalse);
    });
  });
}
