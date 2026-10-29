import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/audio_player/data/datasources/audio_playback_position_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sem valor gravado, read devolve null', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    expect(store.read(), isNull);
  });

  test('write grava e read relê o mesmo trackId/posição', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    await store.write('aud-1', const Duration(seconds: 42));
    final result = store.read();

    expect(result?.trackId, 'aud-1');
    expect(result?.position, const Duration(seconds: 42));
  });

  test('write com duration grava e read relê durationMs', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    await store.write(
      'aud-1',
      const Duration(seconds: 42),
      duration: const Duration(minutes: 3),
    );
    final result = store.read();

    expect(result?.trackId, 'aud-1');
    expect(result?.position, const Duration(seconds: 42));
    expect(result?.duration, const Duration(minutes: 3));
  });

  test('write sem duration grava e read relê duration null', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    await store.write('aud-1', const Duration(seconds: 10));
    final result = store.read();

    expect(result?.duration, isNull);
  });

  test(
    'JSON sem durationMs (formato anterior à C12 r1) lê duration null',
    () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.audioLastPosition: '{"trackId":"aud-1","positionMs":5000}',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = AudioPlaybackPositionStore(prefs);

      final result = store.read();

      expect(result?.trackId, 'aud-1');
      expect(result?.position, const Duration(seconds: 5));
      expect(result?.duration, isNull);
    },
  );

  test('write sobrescreve o valor anterior', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    await store.write('aud-1', const Duration(seconds: 10));
    await store.write('aud-2', const Duration(seconds: 20));
    final result = store.read();

    expect(result?.trackId, 'aud-2');
    expect(result?.position, const Duration(seconds: 20));
  });

  test('JSON inválido no prefs devolve null (e limpa a chave)', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.audioLastPosition: 'não é json',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    expect(store.read(), isNull);
  });

  test('JSON válido mas sem os campos esperados devolve null', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.audioLastPosition: '{"foo":"bar"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    expect(store.read(), isNull);
  });

  test('clear apaga o valor gravado', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AudioPlaybackPositionStore(prefs);

    await store.write('aud-1', const Duration(seconds: 5));
    await store.clear();

    expect(store.read(), isNull);
  });
}
