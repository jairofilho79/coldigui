import 'package:coldigui/features/chords/data/datasources/chord_content_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Interceptor que responde da tabela [routes] sem tocar na rede.
class _FakeAdapter extends Interceptor {
  _FakeAdapter(this.routes, {this.offline = false});

  final Map<String, (int status, String body)> routes;

  /// Simula queda de rede: [DioExceptionType.connectionError] sem resposta.
  final bool offline;
  final requestedPaths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestedPaths.add(options.path);
    if (offline) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      return;
    }
    final route = routes[options.path];
    if (route == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          response: Response<String>(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }
    handler.resolve(
      Response<String>(
        requestOptions: options,
        statusCode: route.$1,
        data: route.$2,
      ),
    );
  }
}

ChordContentDatasource _datasource(_FakeAdapter adapter) {
  final dio = Dio()..interceptors.add(adapter);
  return ChordContentDatasource(dio, apiBase: 'https://plpcg.com');
}

void main() {
  const key = 'assets/praises/p1/m1.chord';
  const url = 'https://plpcg.com/api/coldigom/$key';

  test('devolve a musica parseada em 200 com letra', () async {
    final adapter = _FakeAdapter({
      url: (200, '{title: Comigo}\n{key: Eb}\n\nA [Bb]noite vem,\n'),
    });

    final song = await _datasource(adapter).fetchSong(key);

    expect(song, isNotNull);
    expect(song!.title, 'Comigo');
    expect(song.hasLyrics, isTrue);
  });

  test('busca pelo proxy same-policy', () async {
    final adapter = _FakeAdapter({url: (200, 'letra\n')});

    await _datasource(adapter).fetchSong(key);

    expect(adapter.requestedPaths.single, url);
  });

  test('devolve null em 404', () async {
    final song = await _datasource(_FakeAdapter(const {})).fetchSong(key);
    expect(song, isNull);
  });

  test('devolve null quando o arquivo nao tem letra (lapide)', () async {
    final adapter = _FakeAdapter({
      url: (200, '{title: Clama}\n\n; a cifra errada foi removida.\n'),
    });

    expect(await _datasource(adapter).fetchSong(key), isNull);
  });

  test('devolve null em corpo vazio', () async {
    final adapter = _FakeAdapter({url: (200, '')});
    expect(await _datasource(adapter).fetchSong(key), isNull);
  });

  test('devolve null em r2Key vazio sem ir a rede', () async {
    final adapter = _FakeAdapter(const {});
    expect(await _datasource(adapter).fetchSong(''), isNull);
    expect(adapter.requestedPaths, isEmpty);
  });

  test(
    'lanca ChordFetchFailedException em 500 (nao vira cifra inexistente)',
    () {
      final adapter = _FakeAdapter({url: (500, 'boom')});

      expect(
        () => _datasource(adapter).fetchSong(key),
        throwsA(
          isA<ChordFetchFailedException>().having((e) => e.r2Key, 'r2Key', key),
        ),
      );
    },
  );

  test('lanca ChordFetchFailedException em falha de rede', () {
    final adapter = _FakeAdapter(const {}, offline: true);

    expect(
      () => _datasource(adapter).fetchSong(key),
      throwsA(isA<ChordFetchFailedException>()),
    );
  });

  test('fetchContent devolve o corpo cru para o cache', () async {
    const body = '{title: Comigo}\n\nA [Bb]noite vem,\n';
    final adapter = _FakeAdapter({url: (200, body)});

    expect(await _datasource(adapter).fetchContent(key), body);
  });

  test('fetchContent devolve null em 404', () async {
    expect(await _datasource(_FakeAdapter(const {})).fetchContent(key), isNull);
  });
}
