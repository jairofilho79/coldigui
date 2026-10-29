import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toString nomeia a operação que falhou', () {
    const e = StorageUnavailableException('playlists.insert');
    expect(e.operation, 'playlists.insert');
    expect(e.toString(), 'StorageUnavailableException(playlists.insert)');
    expect(e, isA<Exception>());
  });
}
