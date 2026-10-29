import 'package:coldigui/core/constants/app_tabs.dart';
import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appTabsFor', () {
    test('com as flags padrão: Listas, Pesquisar, Perfil', () {
      expect(appTabsFor(const FeatureFlags()), [
        AppTab.playlists,
        AppTab.home,
        AppTab.profile,
      ]);
    });

    test('events: true inclui a aba Eventos como primeira', () {
      expect(appTabsFor(const FeatureFlags(events: true)), [
        AppTab.events,
        AppTab.playlists,
        AppTab.home,
        AppTab.profile,
      ]);
    });

    test('social não é mais aba — a flag não muda a lista', () {
      expect(
        appTabsFor(const FeatureFlags(social: false)),
        appTabsFor(const FeatureFlags(social: true)),
      );
    });
  });
}
