import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('estado inicial sem prefs é o default (10 itens por página)', () {
    final container = createContainer();

    expect(container.read(libraryViewSettingsProvider).itemsPerPage, 10);
  });

  test('setItemsPerPage(25) persiste em StorageKeys.libraryItemsPerPage', () {
    final container = createContainer();

    container.read(libraryViewSettingsProvider.notifier).setItemsPerPage(25);

    expect(container.read(libraryViewSettingsProvider).itemsPerPage, 25);
    expect(prefs.getInt(StorageKeys.libraryItemsPerPage), 25);
  });

  test('novo container com o mesmo prefs relê itemsPerPage persistido', () {
    final first = createContainer();
    first.read(libraryViewSettingsProvider.notifier).setItemsPerPage(50);

    final second = createContainer();

    expect(second.read(libraryViewSettingsProvider).itemsPerPage, 50);
  });

  test('setDefaultForWidth(1200) sem valor gravado escolhe 25', () {
    final container = createContainer();

    container
        .read(libraryViewSettingsProvider.notifier)
        .setDefaultForWidth(1200);

    expect(container.read(libraryViewSettingsProvider).itemsPerPage, 25);
  });

  test('setDefaultForWidth(600) sem valor gravado escolhe 10', () {
    final container = createContainer();

    container
        .read(libraryViewSettingsProvider.notifier)
        .setDefaultForWidth(600);

    expect(container.read(libraryViewSettingsProvider).itemsPerPage, 10);
  });

  test('setDefaultForWidth com valor gravado não sobrescreve', () {
    final first = createContainer();
    first.read(libraryViewSettingsProvider.notifier).setItemsPerPage(10);

    final second = createContainer();
    second.read(libraryViewSettingsProvider.notifier).setDefaultForWidth(1200);

    expect(second.read(libraryViewSettingsProvider).itemsPerPage, 10);
  });

  test('setDefaultForWidth não age depois de hydrateFromUrl com page_size', () {
    final container = createContainer();
    container
        .read(libraryViewSettingsProvider.notifier)
        .hydrateFromUrl(itensPorPagina: '50');

    container
        .read(libraryViewSettingsProvider.notifier)
        .setDefaultForWidth(1200);

    expect(container.read(libraryViewSettingsProvider).itemsPerPage, 50);
  });

  test('URL vence o gravado', () {
    final first = createContainer();
    first.read(libraryViewSettingsProvider.notifier).setItemsPerPage(50);

    final second = createContainer();
    second
        .read(libraryViewSettingsProvider.notifier)
        .hydrateFromUrl(itensPorPagina: '25');

    expect(second.read(libraryViewSettingsProvider).itemsPerPage, 25);
  });
}
