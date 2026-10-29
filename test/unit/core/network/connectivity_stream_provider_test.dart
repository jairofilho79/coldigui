import 'dart:async';

import 'package:coldigui/core/network/connectivity_results.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'emite true quando há algum resultado além de none, false quando só none',
    () async {
      final controller = StreamController<List<ConnectivityResult>>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          connectivityStreamProvider.overrideWith(
            (ref) => controller.stream.map(connectivityHasUsableConnection),
          ),
        ],
      );
      addTearDown(container.dispose);

      final values = <bool>[];
      container.listen<AsyncValue<bool>>(connectivityStreamProvider, (_, next) {
        if (next.hasValue) values.add(next.value!);
      }, fireImmediately: true);

      controller.add([ConnectivityResult.none]);
      await pumpEventQueue();
      controller.add([ConnectivityResult.wifi]);
      await pumpEventQueue();
      // Emissão repetida de `true` é deduplicada pelo próprio Riverpod
      // (AsyncData(true) == AsyncData(true)) — não gera novo evento.
      controller.add([ConnectivityResult.mobile, ConnectivityResult.none]);
      await pumpEventQueue();
      controller.add([ConnectivityResult.none]);
      await pumpEventQueue();

      expect(values, [false, true, false]);
    },
  );
}
