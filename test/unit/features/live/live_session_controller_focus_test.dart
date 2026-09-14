import 'dart:convert';

import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_navigation_providers.dart';
import 'package:coldigui/features/live/presentation/providers/live_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_live_transport.dart';
import '../../../support/test_overrides.dart';

const code = 'k7x2m9q';
const _entries = [
  {'id': 'a', 'kind': 'pdf'},
  {'id': 'b', 'kind': 'pdf'},
  {'id': 'c', 'kind': 'pdf'},
];

String roomFrame(String focus) => jsonEncode({
  't': 'room',
  'room': code,
  'status': 'live',
  'ownerName': 'F',
  'role': 'consumer',
  'version': 1,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'n',
    'entries': _entries,
    'focusKey': focus,
  },
  'leaderPresent': true,
  'viewers': 1,
});
String snapshotFrame(int version, String focus) => jsonEncode({
  't': 'snapshot',
  'room': code,
  'version': version,
  'snapshot': {
    'playlistId': 'p1',
    'name': 'n',
    'entries': _entries,
    'focusKey': focus,
  },
  'viewers': 1,
});

void main() {
  late ProviderContainer container;
  late FakeLiveTransport transport;
  late List<String> navigated;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    transport = FakeLiveTransport();
    navigated = [];
    container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        liveTransportProvider.overrideWithValue(transport),
        liveWsUriProvider.overrideWithValue((c) => Uri.parse('wss://test/$c')),
        liveFocusResolverProvider.overrideWithValue((key) async {
          container.read(carouselFocusedIndexProvider.notifier).focusKey(key);
          return '/leitor?key=$key';
        }),
        liveNavigatorProvider.overrideWithValue(navigated.add),
      ],
    );
    addTearDown(container.dispose);
    await container.read(liveSessionProvider.notifier).join(code);
    transport.last.emit(roomFrame('a'));
    await Future<void>.delayed(Duration.zero);
  });

  LiveSessionState state() => container.read(liveSessionProvider);

  test(
    'enquanto segue, cada foco do gestor navega e followingFocus fica true',
    () async {
      expect(navigated, ['/leitor?key=a']);
      transport.last.emit(snapshotFrame(2, 'b'));
      await Future<void>.delayed(Duration.zero);
      expect(navigated, ['/leitor?key=a', '/leitor?key=b']);
      expect(state().followingFocus, isTrue);
      expect(container.read(carouselFocusedKeyProvider), 'b');
    },
  );

  test('navegação própria do consumidor desliga followingFocus; o próximo foco do gestor só sinaliza', () async {
    container.read(carouselFocusedIndexProvider.notifier).focusKey('c');
    expect(state().followingFocus, isFalse);
    transport.last.emit(snapshotFrame(2, 'b'));
    await Future<void>.delayed(Duration.zero);
    expect(navigated, ['/leitor?key=a']);
    expect(container.read(carouselFocusedKeyProvider), 'c');
  });

  test(
    'returnToLeader volta ao foco do gestor e religa o seguimento',
    () async {
      container.read(carouselFocusedIndexProvider.notifier).focusKey('c');
      transport.last.emit(snapshotFrame(2, 'b'));
      await Future<void>.delayed(Duration.zero);
      container.read(liveSessionProvider.notifier).returnToLeader();
      await Future<void>.delayed(Duration.zero);
      expect(navigated.last, '/leitor?key=b');
      expect(state().followingFocus, isTrue);
      transport.last.emit(snapshotFrame(3, 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(navigated.last, '/leitor?key=a');
    },
  );

  test(
    'o foco aplicado pelo próprio controller não conta como desvio',
    () async {
      transport.last.emit(snapshotFrame(2, 'c'));
      await Future<void>.delayed(Duration.zero);
      expect(state().followingFocus, isTrue);
    },
  );

  test('sair reinicia followingFocus', () async {
    container.read(carouselFocusedIndexProvider.notifier).focusKey('c');
    await container.read(liveSessionProvider.notifier).leave();
    expect(state().followingFocus, isTrue);
  });
}
