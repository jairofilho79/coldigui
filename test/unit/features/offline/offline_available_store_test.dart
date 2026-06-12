import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('clear persiste OFFLINE_AVAILABLE=FALSE', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineAvailableStore(prefs);

    await store.markConfigured();
    expect(store.isConfigured, isTrue);

    await store.clear();
    expect(store.isConfigured, isFalse);
    expect(store.isExplicitlyDisabled, isTrue);
    expect(
      prefs.getString(StorageKeys.offlineAvailable),
      OfflineAvailableStore.disabledValue,
    );
  });
}
