import 'dart:typed_data';

import 'package:coldigui/features/audio_player/data/web_audio_source_resolver_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stub resolveFromCache devolve null — blob URL é coisa da web',
    () async {
      final resolver = WebAudioSourceResolver();
      expect(await resolver.resolveFromCache('plpcg_audio/x.mp3'), isNull);
    },
  );

  test('stub resolveFromBytes devolve null — blob URL é coisa da web', () {
    final resolver = WebAudioSourceResolver();
    expect(
      resolver.resolveFromBytes('plpcg_audio/x.mp3', Uint8List(0)),
      isNull,
    );
  });

  test('stub revokeAll não lança', () {
    final resolver = WebAudioSourceResolver();
    expect(resolver.revokeAll, returnsNormally);
  });
}
