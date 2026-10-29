import 'package:coldigui/features/coldigom/domain/utils/youtube_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoutubeUrl', () {
    test('aceita youtube.com, subdomínio e youtu.be em https', () {
      expect(
        YoutubeUrl.isValid('https://www.youtube.com/watch?v=1Pks43ceAac'),
        isTrue,
      );
      expect(
        YoutubeUrl.isValid('https://youtube.com/watch?v=1Pks43ceAac'),
        isTrue,
      );
      expect(
        YoutubeUrl.isValid('https://m.youtube.com/watch?v=1Pks43ceAac'),
        isTrue,
      );
      expect(YoutubeUrl.isValid('https://youtu.be/1Pks43ceAac'), isTrue);
    });

    test('rejeita null, vazio, http e domínio estranho', () {
      expect(YoutubeUrl.isValid(null), isFalse);
      expect(YoutubeUrl.isValid(''), isFalse);
      expect(YoutubeUrl.isValid('   '), isFalse);
      expect(
        YoutubeUrl.isValid('http://www.youtube.com/watch?v=1Pks43ceAac'),
        isFalse,
      );
      expect(YoutubeUrl.isValid('https://example.com/watch?v=1'), isFalse);
      expect(YoutubeUrl.isValid('not-a-url'), isFalse);
    });

    test('tryParse retorna Uri ou null', () {
      expect(
        YoutubeUrl.tryParse('https://youtu.be/1Pks43ceAac'),
        Uri.parse('https://youtu.be/1Pks43ceAac'),
      );
      expect(YoutubeUrl.tryParse(null), isNull);
    });
  });
}
