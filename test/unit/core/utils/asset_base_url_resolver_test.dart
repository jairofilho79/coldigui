import 'package:coldigui/core/utils/asset_base_url_resolver.dart';
import 'package:coldigui/features/coldigom/data/constants/coldigom_api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssetBaseUrlResolver', () {
    test('assets/praises usa base coldigom', () {
      expect(
        AssetBaseUrlResolver.baseUrlForAssetPath('assets/praises/uuid/mat.pdf'),
        ColdigomApiConfig.baseUrl,
      );
    });

    test('assets/ColAdultos usa base PLPCG do ambiente', () {
      const plpcgBase = String.fromEnvironment('PLPCG_API_BASE_URL');
      expect(
        AssetBaseUrlResolver.baseUrlForAssetPath('assets/ColAdultos/001.pdf'),
        plpcgBase,
      );
    });

    test('joinAssetUrl monta URL coldigom completa', () {
      expect(
        AssetBaseUrlResolver.joinAssetUrl('/assets/praises/p1/m1.pdf'),
        '${ColdigomApiConfig.baseUrl}/assets/praises/p1/m1.pdf',
      );
    });
  });
}
