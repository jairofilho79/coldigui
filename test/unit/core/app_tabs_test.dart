import 'package:coldigui/core/constants/app_tabs.dart';
import 'package:coldigui/core/constants/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appTabsFor', () {
    test('com as flags padrão, omite events e mantém social', () {
      expect(appTabsFor(const FeatureFlags()), [
        AppTab.library,
        AppTab.home,
        AppTab.social,
        AppTab.profile,
      ]);
    });

    test('events: true inclui a aba Eventos como primeira', () {
      expect(appTabsFor(const FeatureFlags(events: true)), [
        AppTab.events,
        AppTab.library,
        AppTab.home,
        AppTab.social,
        AppTab.profile,
      ]);
    });

    test('social: false omite a aba Social', () {
      expect(appTabsFor(const FeatureFlags(social: false)), [
        AppTab.library,
        AppTab.home,
        AppTab.profile,
      ]);
    });

    test('events: true e social: false — só Eventos entra', () {
      expect(appTabsFor(const FeatureFlags(events: true, social: false)), [
        AppTab.events,
        AppTab.library,
        AppTab.home,
        AppTab.profile,
      ]);
    });
  });
}
