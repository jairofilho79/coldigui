import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/currently_open_item_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioSessionNotifier extends AudioPlayerSessionNotifier {
  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  void setTrack(AudioTrack track) {
    state = state.copyWith(queue: [track], currentIndex: 0);
  }
}

void main() {
  group('currentlyOpenItemProvider', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioPlayerSessionProvider.overrideWith(_FakeAudioSessionNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test('retorna null quando leitor e audio estao vazios', () {
      final item = container.read(currentlyOpenItemProvider);
      expect(item, isNull);
      expect(container.read(isCurrentItemInActivePlaylistProvider), isFalse);
    });

    test('resolve louvor a partir de readerRouteParamsProvider (PDF)', () {
      final pdfId = encodePdfId('assets/ColAdultos/001.pdf');
      container.read(readerRouteParamsProvider.notifier).update({
        UrlSyncParams.pdfId: pdfId,
        UrlSyncParams.titulo: 'Santo, Santo, Santo',
        UrlSyncParams.subtitulo: '001',
      });

      final item = container.read(currentlyOpenItemProvider);
      expect(item, isNotNull);
      expect(item!.materialId, pdfId);
      expect(item.nome, 'Santo, Santo, Santo');
      expect(item.numero, '001');
      expect(item.kind, MaterialKind.pdf);
    });

    test('resolve cifra a partir de readerRouteParamsProvider (Chord)', () {
      final chordId = encodePdfId('assets/ColAdultos/002.chord');
      container.read(readerRouteParamsProvider.notifier).update({
        UrlSyncParams.pdfId: chordId,
        UrlSyncParams.titulo: 'Cifra Louvor',
        UrlSyncParams.subtitulo: '002',
      });

      final item = container.read(currentlyOpenItemProvider);
      expect(item, isNotNull);
      expect(item!.materialId, chordId);
      expect(item.kind, MaterialKind.chord);
    });

    test('resolve faixa de audio quando presente no audioPlayerSessionProvider', () {
      const track = AudioTrack(
        audioId: 'audio-123',
        r2Key: 'assets/praises/005.mp3',
        groupId: 'grp-1',
        nome: 'Faixa Teste',
        numero: '005',
        categoria: 'Coro',
        classificacao: 'ColAdultos',
      );
      (container.read(audioPlayerSessionProvider.notifier) as _FakeAudioSessionNotifier)
          .setTrack(track);

      final item = container.read(currentlyOpenItemProvider);
      expect(item, isNotNull);
      expect(item!.materialId, 'audio-123');
      expect(item.nome, 'Faixa Teste');
      expect(item.numero, '005');
      expect(item.kind, MaterialKind.audio);
    });

    test('isCurrentItemInActivePlaylistProvider reflete pertinencia a lista ativa', () {
      final pdfId = encodePdfId('assets/ColAdultos/001.pdf');
      container.read(readerRouteParamsProvider.notifier).update({
        UrlSyncParams.pdfId: pdfId,
        UrlSyncParams.titulo: 'Louvor 1',
      });

      // Inicialmente fora da lista ativa
      expect(container.read(isCurrentItemInActivePlaylistProvider), isFalse);

      // Criamos override com a lista contendo o louvor
      final containerWithList = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeEntriesProvider.overrideWithValue([
            ActiveEntry(
              index: 0,
              entry: PlaylistEntry(id: pdfId, kind: MaterialKind.pdf),
              key: pdfId,
            ),
          ]),
        ],
      );
      addTearDown(containerWithList.dispose);

      containerWithList.read(readerRouteParamsProvider.notifier).update({
        UrlSyncParams.pdfId: pdfId,
        UrlSyncParams.titulo: 'Louvor 1',
      });

      expect(containerWithList.read(isCurrentItemInActivePlaylistProvider), isTrue);
    });
  });
}
