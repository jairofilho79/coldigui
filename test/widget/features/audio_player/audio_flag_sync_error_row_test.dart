import 'package:coldigui/features/audio_flags/domain/usecases/sync_audio_flags.dart';
import 'package:coldigui/features/audio_flags/presentation/providers/audio_flag_sync_provider.dart';
import 'package:coldigui/features/audio_flags/presentation/widgets/audio_flag_sync_error_row.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Estado de sync fixo, sem `ref.listen` de auth nem rede.
class _FakeSyncNotifier extends AudioFlagSyncNotifier {
  _FakeSyncNotifier(this.initial);

  final AudioFlagSyncState initial;
  var retryCalls = 0;

  @override
  AudioFlagSyncState build() => initial;

  @override
  Future<void> retryAndReload() async {
    retryCalls++;
  }

  @override
  Future<AudioFlagSyncResult> sync() async => const AudioFlagSyncResult();
}

void main() {
  Widget buildSubject(AudioFlagSyncState state, _FakeSyncNotifier notifier) {
    return ProviderScope(
      overrides: [audioFlagSyncProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const Scaffold(body: AudioFlagSyncErrorRow()),
      ),
    );
  }

  testWidgets('sync sem problema não mostra nada', (tester) async {
    final notifier = _FakeSyncNotifier(const AudioFlagSyncState());
    await tester.pumpWidget(buildSubject(const AudioFlagSyncState(), notifier));
    await tester.pumpAndSettle();

    expect(find.text('Marcadores não sincronizados'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('erro vira linha traduzida com Tentar novamente', (tester) async {
    final state = AudioFlagSyncState(
      lastErrorCause: DioException(
        requestOptions: RequestOptions(path: '/api/audio-flags'),
        type: DioExceptionType.connectionError,
      ),
    );
    final notifier = _FakeSyncNotifier(state);
    await tester.pumpWidget(buildSubject(state, notifier));
    await tester.pumpAndSettle();

    expect(find.text('Marcadores não sincronizados'), findsOneWidget);
    expect(find.textContaining('Sem conexão com a internet'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(notifier.retryCalls, 1);
  });

  testWidgets('conflito sem erro também mostra a linha', (tester) async {
    const state = AudioFlagSyncState(conflicts: 1);
    final notifier = _FakeSyncNotifier(state);
    await tester.pumpWidget(buildSubject(state, notifier));
    await tester.pumpAndSettle();

    expect(find.text('Marcadores não sincronizados'), findsOneWidget);
  });
}
