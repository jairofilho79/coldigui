import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _itemA = CarouselItem(
  materialId: 'pdf-a',
  index: 0,
  numero: '001',
  nome: 'A',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
);

const _itemB = CarouselItem(
  materialId: 'pdf-b',
  index: 1,
  numero: '002',
  nome: 'B',
  categoria: 'Cifra nível I',
  classificacao: 'ColCIAs',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('activePlaylistId sobrevive a um novo ProviderContainer', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);

    first.read(activePlaylistIdProvider.notifier).set('pl-1');
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(kActivePlaylistIdPrefsKey), 'pl-1');

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);
    expect(second.read(activePlaylistIdProvider), 'pl-1');

    first.read(activePlaylistIdProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(kActivePlaylistIdPrefsKey), isNull);
  });

  test('foco do PDF sobrevive a um novo ProviderContainer', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        carouselItemsProvider.overrideWithValue(const [_itemA, _itemB]),
      ],
    );
    addTearDown(first.dispose);

    first.read(carouselFocusedIndexProvider.notifier).focusKey('pdf-b');
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), 'pdf-b');

    final second = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        carouselItemsProvider.overrideWithValue(const [_itemA, _itemB]),
      ],
    );
    addTearDown(second.dispose);
    expect(second.read(carouselFocusedIndexProvider), 1);

    first.read(carouselFocusedIndexProvider.notifier).clearFocus();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), isNull);
  });

  test('close da sessão remove o audioId persistido', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPlaylistFocusedAudioIdPrefsKey, 'aud-1');
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(audioPlayerSessionProvider.notifier).close();
    expect(prefs.getString(kPlaylistFocusedAudioIdPrefsKey), isNull);
  });
}
