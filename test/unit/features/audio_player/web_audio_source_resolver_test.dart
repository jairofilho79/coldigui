import 'package:coldigui/features/audio_player/data/web_audio_source_resolver_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stub devolve streamFallbackUrl quando informado', () async {
    final resolver = WebAudioSourceResolver();
    final uri = await resolver.resolveForPlayback(
      'https://plpcg.com/api/coldigom/assets/a.mp3',
      streamFallbackUrl: 'https://coldigom.example/assets/a.mp3',
    );
    expect(uri.toString(), 'https://coldigom.example/assets/a.mp3');
  });

  test('stub devolve fetchUrl sem fallback', () async {
    final resolver = WebAudioSourceResolver();
    final uri = await resolver.resolveForPlayback(
      'https://plpcg.com/api/coldigom/assets/a.mp3',
    );
    expect(uri.toString(), 'https://plpcg.com/api/coldigom/assets/a.mp3');
  });

  test('stub revokeAll não lança', () {
    final resolver = WebAudioSourceResolver();
    expect(resolver.revokeAll, returnsNormally);
  });
}
