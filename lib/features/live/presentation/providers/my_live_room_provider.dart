import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../data/live_room_remote_datasource.dart';
import '../../data/providers/live_providers.dart';

final liveRoomRemoteDatasourceProvider = Provider<LiveRoomRemoteDatasource>((
  ref,
) {
  return LiveRoomRemoteDatasource(
    ref.watch(dioProvider),
    sessionToken: () => ref.read(authStateProvider).asData?.value?.sessionToken,
  );
});

/// A sala do usuário logado. `null` deslogado; carregada sob demanda
/// ([ensure]) — o boot não bate no Worker por isto.
class MyLiveRoomNotifier extends AsyncNotifier<LiveRoomInfo?> {
  @override
  Future<LiveRoomInfo?> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) {
      ref.read(liveMyRoomCodeProvider.notifier).set(null);
      return null;
    }
    return null;
  }

  Future<LiveRoomInfo> ensure() async {
    final current = state.asData?.value;
    if (current != null) return current;
    final info = await ref.read(liveRoomRemoteDatasourceProvider).ensureRoom();
    ref.read(liveMyRoomCodeProvider.notifier).set(info.code);
    state = AsyncData(info);
    return info;
  }

  Future<LiveRoomInfo> regenerate() async {
    final info = await ref.read(liveRoomRemoteDatasourceProvider).regenerate();
    ref.read(liveMyRoomCodeProvider.notifier).set(info.code);
    state = AsyncData(info);
    return info;
  }
}

final myLiveRoomProvider =
    AsyncNotifierProvider<MyLiveRoomNotifier, LiveRoomInfo?>(
      MyLiveRoomNotifier.new,
    );
