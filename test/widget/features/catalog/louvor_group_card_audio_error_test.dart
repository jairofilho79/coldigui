import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_state.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlaylistsNotifier extends PlaylistsNotifier {
  @override
  List<PlaylistViewItem> build() => const [];

  // `openLouvorInReader` resolve o PDF e adiciona à lista ativa dentro de um
  // `Future.wait`, que só completa quando **os dois** terminam — sem este
  // override o teste ficaria pendurado no Isar e o erro nunca chegaria à UI.
  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async => true;
}

/// `playAudioInSession` entra na lista ativa pelo editor — sem storage aqui.
class _FakeActiveEditor extends ActivePlaylistEditor {
  @override
  List<PlaylistEntry>? build() => null;

  @override
  Future<AddToActiveOutcome> addToActive(
    String materialId, {
    MaterialKind? kind,
    bool allowDuplicate = false,
  }) async => AddToActiveOutcome.added;
}

/// Sessão de áudio que sempre falha ao tocar — `playQueue` é o único `await`
/// de `openAudioInPlayer`, então o erro chega ao `catch` do card.
class _FailingAudioSession extends AudioPlayerSessionNotifier {
  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    throw StateError('detalhe_interno_feio');
  }
}

/// Resolve do PDF que encontra o índice apontando para um arquivo apagado —
/// é a exceção que `openLouvorInReader` deixa escapar para o `catch` do card.
class _DeletedPdfDownloadNotifier extends LouvorPdfDownloadNotifier {
  @override
  Map<String, LouvorPdfDownloadState> build() => const {};

  @override
  Future<LocalPdfSource> resolveLouvorPdf({
    required String pdfId,
    required String remotePath,
  }) async {
    throw PdfExternallyDeletedException(pdfId: pdfId);
  }
}

void main() {
  const track = AudioTrack(
    audioId: 'a1',
    r2Key: 'assets/praises/001.mp3',
    nome: 'Aleluia',
    numero: '001',
    groupId: '001:aleluia',
    categoria: 'Áudio',
    classificacao: 'Coro',
    source: LouvorDataSource.coldigom,
  );

  LouvorGroup audioOnlyGroup() => LouvorGroup(
    groupId: '001:aleluia',
    numero: '001',
    nome: 'Aleluia',
    sections: const [],
    audioTracks: const [track],
  );

  final pdfId = encodePdfId('ColAdultos/001.pdf');

  Louvor louvorFixture() => Louvor(
    nome: 'Aleluia',
    numero: '001',
    categoria: 'ColAdultos',
    classificacao: 'Partitura',
    pdf: 'ColAdultos/001.pdf',
    pdfId: pdfId,
    groupId: '001:aleluia',
    searchTitleNorm: 'aleluia',
    searchContentTokens: const [],
    searchCompactContent: '',
  );

  /// Grupo com um único material (PDF): o toque no card abre direto, sem sheet.
  LouvorGroup pdfOnlyGroup() => LouvorGroup(
    groupId: '001:aleluia',
    numero: '001',
    nome: 'Aleluia',
    sections: [
      LouvorMaterialSection(
        classificacao: 'Partitura',
        displayLabel: 'Partitura',
        materials: [
          LouvorMaterialEntry(
            categoria: 'ColAdultos',
            pdfId: pdfId,
            louvor: louvorFixture(),
          ),
        ],
      ),
    ],
  );

  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'falha ao abrir áudio mostra mensagem traduzida, não o toString',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(_FakeActiveEditor.new),
            playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
            audioPlayerSessionProvider.overrideWith(_FailingAudioSession.new),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      Scaffold(body: LouvorGroupCard(group: audioOnlyGroup())),
                ),
                GoRoute(
                  path: '/audio',
                  builder: (_, _) => const Scaffold(body: Text('player')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Aleluia'));
      await tester.pumpAndSettle();

      expect(find.text(pt.errorGeneric), findsOneWidget);
      expect(find.textContaining('detalhe_interno_feio'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);
    },
  );

  testWidgets(
    'PDF removido do dispositivo mostra o texto do l10n, não o genérico',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playlistsProvider.overrideWith(_FakePlaylistsNotifier.new),
            louvorPdfDownloadProvider.overrideWith(
              _DeletedPdfDownloadNotifier.new,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      Scaffold(body: LouvorGroupCard(group: pdfOnlyGroup())),
                ),
                GoRoute(
                  path: '/leitor',
                  builder: (_, _) => const Scaffold(body: Text('leitor')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Aleluia'));
      await tester.pumpAndSettle();

      expect(find.text(pt.pdfExternallyDeleted), findsOneWidget);
      expect(find.text(pt.errorGeneric), findsNothing);
      expect(find.text(pt.pdfActionError), findsNothing);
    },
  );
}
