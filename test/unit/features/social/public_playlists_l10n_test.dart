import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec D4 — os textos da antiga aba Social passam a falar em «listas
/// públicas», em pt e en.
void main() {
  late AppLocalizations pt;
  late AppLocalizations en;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('publicPlaylistsTitle', () {
    expect(pt.publicPlaylistsTitle, 'Listas públicas');
    expect(en.publicPlaylistsTitle, 'Public playlists');
  });

  test('socialSignInRequired não cita mais a «aba Social»', () {
    expect(
      pt.socialSignInRequired,
      'Entre com o Google para explorar as listas públicas.',
    );
    expect(
      en.socialSignInRequired,
      'Sign in with Google to explore public playlists.',
    );
  });
}
