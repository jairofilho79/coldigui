import 'dart:typed_data';

import 'package:coldigui/features/score_reader/data/datasources/score_byte_store.dart';
import 'package:coldigui/features/score_reader/data/repositories/score_sound_font_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart';

class _Store implements ScoreByteStorePort {
  final values = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async => values[key];
  @override
  Future<bool> contains(String key) async => values.containsKey(key);
  @override
  Future<Set<String>> fileNames() async =>
      values.keys.map(scoreByteStoreFileName).toSet();
  @override
  Future<void> write(String key, Uint8List bytes) async => values[key] = bytes;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late _Store store;
  late Dio dio;
  late ScoreSoundFontRepository repository;

  setUp(() {
    store = _Store();
    dio = Dio();
    repository = ScoreSoundFontRepository(
      store,
      dio,
      apiBase: 'https://example.test',
    );
  });
  tearDown(() => dio.close(force: true));

  void respond(int status, Uint8List bytes) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<List<int>>(
            requestOptions: options,
            statusCode: status,
            data: bytes,
          ),
        ),
      ),
    );
  }

  test('fallback is accepted by the real SoundFont parser', () async {
    final font = await SoundFontFile.fromBytes(repository.fallback);
    expect(font.format, SoundFontFormat.sf2);
    expect(font.presets, isNotEmpty);
    expect(font.samples, isNotEmpty);
  });

  test('a valid downloaded bank survives a new repository offline', () async {
    final bytes = repository.fallback;
    respond(200, bytes);
    expect(await repository.download(), bytes);
    dio.close(force: true);
    final offline = Dio();
    addTearDown(() => offline.close(force: true));
    offline.interceptors.add(
      InterceptorsWrapper(
        onRequest: (_, _) => fail('cached soundfont must not need a network'),
      ),
    );
    final reopened = ScoreSoundFontRepository(
      store,
      offline,
      apiBase: 'https://example.test',
    );
    expect(await reopened.readCached(), bytes);
  });

  test('HTML or another payload is never persisted as a SoundFont', () async {
    respond(200, Uint8List.fromList('<html>unavailable</html>'.codeUnits));
    await expectLater(repository.download(), throwsFormatException);
    expect(store.values, isEmpty);
    expect(
      (await SoundFontFile.fromBytes(repository.fallback)).presets,
      isNotEmpty,
    );
  });

  test('an unsuccessful response is never persisted', () async {
    respond(503, repository.fallback);
    await expectLater(repository.download(), throwsA(isA<StateError>()));
    expect(store.values, isEmpty);
  });

  test(
    'a corrupt cached bank is discarded and fallback remains usable',
    () async {
      store.values[repository.key] = Uint8List.fromList([1, 2, 3]);
      expect(await repository.readCached(), isNull);
      expect(store.values, isEmpty);
      expect(
        (await SoundFontFile.fromBytes(repository.fallback)).presets,
        isNotEmpty,
      );
    },
  );
}
