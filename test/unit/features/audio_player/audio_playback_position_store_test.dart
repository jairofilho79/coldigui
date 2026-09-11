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
