import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../../../auth/domain/entities/auth_user.dart';
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
///
/// `build()` não faz `ref.watch(authStateProvider)` nem grava em outro
/// provider durante a própria inicialização — o Riverpod 3.3 proíbe isso
/// (`_debugAssertNotificationAllowed`, "Providers are not allowed to modify
/// other providers during their initialization"). Em vez disso, escuta o
/// logout via [Ref.listen] e só aí zera o estado e [liveMyRoomCodeProvider];
/// uma reemissão de `authStateProvider` com o mesmo usuário (ex.: refresh de
/// perfil) não derruba uma sala já carregada por [ensure].
class MyLiveRoomNotifier extends AsyncNotifier<LiveRoomInfo?> {
  @override
  Future<LiveRoomInfo?> build() async {
    ref.listen(authStateProvider, (previous, next) {
      // Só `AsyncData(null)` é logout — `AsyncLoading` (refresh do perfil,
      // boot) também tem `asData == null` e não pode derrubar a sala.
      if (next is AsyncData<AuthUser?> && next.value == null) {
        state = const AsyncData(null);
        ref.read(liveMyRoomCodeProvider.notifier).set(null);
      }
    });
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
