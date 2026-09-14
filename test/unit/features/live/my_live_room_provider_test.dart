import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/live/data/live_room_remote_datasource.dart';
import 'package:coldigui/features/live/data/providers/live_providers.dart';
import 'package:coldigui/features/live/presentation/providers/my_live_room_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/test_overrides.dart';

const user = AuthUser(
  googleSub: 'owner',
  sessionToken: 'sess_owner',
  name: 'Fulano',
);

const roomInfo = LiveRoomInfo(
  code: 'k7x2m9q',
  url: 'https://plpcg.com/ao-vivo/k7x2m9q',
  ownerName: 'Fulano',
);

/// Fake de [LiveRoomRemoteDatasource]: nunca toca em Dio de verdade, devolve
/// [info] fixo e conta chamadas — para provar reuso em [ensure] e chamada
/// incondicional em `regenerate`.
class _FakeLiveRoomRemoteDatasource extends LiveRoomRemoteDatasource {
  _FakeLiveRoomRemoteDatasource(this.info)
    : super(Dio(), sessionToken: () => null);
  final LiveRoomInfo info;
  int ensureCalls = 0;
  int regenerateCalls = 0;

  @override
  Future<LiveRoomInfo> ensureRoom() async {
    ensureCalls++;
    return info;
  }

  @override
  Future<LiveRoomInfo> regenerate() async {
    regenerateCalls++;
    return info;
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('build() deslogado não lança e resolve null (sem watch/side effect '
      'síncrono na inicialização)', () async {
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        authStateProvider.overrideWith(() => FakeAuthNotifier(null)),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(myLiveRoomProvider.future);
    expect(result, isNull);
  });

  test('ensure() faz POST uma vez, cacheia (2ª chamada não bate na rede) e '
      'grava liveMyRoomCodeProvider', () async {
    final fakeDatasource = _FakeLiveRoomRemoteDatasource(roomInfo);
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        authStateProvider.overrideWith(() => FakeAuthNotifier(user)),
        liveRoomRemoteDatasourceProvider.overrideWithValue(fakeDatasource),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(myLiveRoomProvider.notifier);
    final first = await notifier.ensure();
    expect(first.code, roomInfo.code);
    expect(fakeDatasource.ensureCalls, 1);
    expect(container.read(liveMyRoomCodeProvider), roomInfo.code);

    final second = await notifier.ensure();
    expect(second.code, roomInfo.code);
    expect(fakeDatasource.ensureCalls, 1); // sem nova chamada — reuso.
  });

  test('regenerate() sempre chama o datasource e atualiza o código', () async {
    final fakeDatasource = _FakeLiveRoomRemoteDatasource(roomInfo);
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        authStateProvider.overrideWith(() => FakeAuthNotifier(user)),
        liveRoomRemoteDatasourceProvider.overrideWithValue(fakeDatasource),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(myLiveRoomProvider.notifier);
    await notifier.ensure();
    expect(fakeDatasource.ensureCalls, 1);

    await notifier.regenerate();
    expect(fakeDatasource.regenerateCalls, 1);
    expect(container.read(liveMyRoomCodeProvider), roomInfo.code);

    await notifier.regenerate();
    expect(fakeDatasource.regenerateCalls, 2); // sempre bate, sem cache.
  });

  test('logout limpa o estado do notifier e liveMyRoomCodeProvider', () async {
    final fakeDatasource = _FakeLiveRoomRemoteDatasource(roomInfo);
    final authNotifier = FakeAuthNotifier(user);
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        authStateProvider.overrideWith(() => authNotifier),
        liveRoomRemoteDatasourceProvider.overrideWithValue(fakeDatasource),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(myLiveRoomProvider.notifier);
    await notifier.ensure();
    expect(
      container.read(myLiveRoomProvider).asData?.value?.code,
      roomInfo.code,
    );
    expect(container.read(liveMyRoomCodeProvider), roomInfo.code);

    authNotifier.setUser(null);
    await pumpEventQueue();

    expect(container.read(myLiveRoomProvider).asData?.value, isNull);
    expect(container.read(liveMyRoomCodeProvider), isNull);
  });

  test(
    'AsyncLoading do auth (refresh) não é logout: sala e código ficam',
    () async {
      final fakeDatasource = _FakeLiveRoomRemoteDatasource(roomInfo);
      final authNotifier = FakeAuthNotifier(user);
      final container = ProviderContainer(
        overrides: [
          ...standardTestOverrides(prefs: prefs),
          authStateProvider.overrideWith(() => authNotifier),
          liveRoomRemoteDatasourceProvider.overrideWithValue(fakeDatasource),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(myLiveRoomProvider.notifier);
      await notifier.ensure();

      authNotifier.setLoading();
      await pumpEventQueue();

      expect(
        container.read(myLiveRoomProvider).asData?.value?.code,
        roomInfo.code,
      );
      expect(container.read(liveMyRoomCodeProvider), roomInfo.code);
    },
  );
}
