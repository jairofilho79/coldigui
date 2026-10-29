// ignore_for_file: prefer_const_constructors
import 'package:coldigui/core/utils/coldigom_asset_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = 'assets/praises/abc/def.chord';

  group('ColdigomAssetUrl.fetchUrlForKey', () {
    test('monta proxy same-policy quando ha apiBase', () {
      expect(
        ColdigomAssetUrl.fetchUrlForKey(key, apiBase: 'https://plpcg.com'),
        'https://plpcg.com/api/coldigom/assets/praises/abc/def.chord',
      );
    });

    test('remove barra final do apiBase', () {
      expect(
        ColdigomAssetUrl.fetchUrlForKey(key, apiBase: 'https://plpcg.com/'),
        'https://plpcg.com/api/coldigom/assets/praises/abc/def.chord',
      );
    });

    test('remove barra inicial da chave', () {
      expect(
        ColdigomAssetUrl.fetchUrlForKey('/$key', apiBase: 'https://plpcg.com'),
        'https://plpcg.com/api/coldigom/assets/praises/abc/def.chord',
      );
    });

    test('cai para URL direta quando apiBase vazio', () {
      final url = ColdigomAssetUrl.fetchUrlForKey(key, apiBase: '');
      expect(url, endsWith('/assets/praises/abc/def.chord'));
      expect(url, isNot(contains('/api/coldigom/')));
      expect(url, ColdigomAssetUrl.directUrlForKey(key));
    });

    test('devolve a propria chave quando ja e URL absoluta', () {
      const absolute = 'https://exemplo.com/x.chord';
      expect(
        ColdigomAssetUrl.fetchUrlForKey(absolute, apiBase: 'https://plpcg.com'),
        absolute,
      );
    });
  });
}
