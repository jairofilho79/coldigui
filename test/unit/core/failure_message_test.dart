import 'package:coldigui/core/failures/app_failure.dart';
import 'package:coldigui/core/l10n/failure_message.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations pt;
  late AppLocalizations en;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('NetworkFailure usa failureNetwork', () {
    final failure = NetworkFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureNetwork);
    expect(failureMessage(en, failure), en.failureNetwork);
  });

  test('OfflineFailure usa failureOffline', () {
    final failure = OfflineFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureOffline);
  });

  test('NotFoundFailure usa failureNotFound', () {
    final failure = NotFoundFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureNotFound);
  });

  test('StorageFailure usa failureStorage', () {
    final failure = StorageFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureStorage);
  });

  test('AuthFailure usa failureAuth', () {
    final failure = AuthFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureAuth);
  });

  test('ConflictFailure usa failureConflict', () {
    final failure = ConflictFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureConflict);
  });

  test('UnknownFailure usa failureUnknown', () {
    final failure = UnknownFailure(Exception('x'));
    expect(failureMessage(pt, failure), pt.failureUnknown);
    expect(failureMessage(en, failure), en.failureUnknown);
  });
}
