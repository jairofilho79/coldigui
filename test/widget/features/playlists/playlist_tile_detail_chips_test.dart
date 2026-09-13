import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/playlists/presentation/widgets/playlist_tile_detail_chips.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/test_overrides.dart';

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _audioA = encodePdfId('ColAdultos/001.mp3');

void main() {
  testWidgets('mostra chips de partitura e de áudio na ordem da lista', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tappedPdf = <String>[];
    final tappedAudio = <String>[];

    final playlist = SavedPlaylist(
      playlistId: 'p1',
      nome: 'Culto',
      entries: [
        PlaylistEntry(id: _pdfA, kind: MaterialKind.pdf),
        PlaylistEntry(id: _audioA, kind: MaterialKind.audio),
      ],
      createdAt: DateTime(2026, 9, 12),
      salva: true,
    );

    // Container próprio (em vez de `ProviderScope` + merge dentro do
    // `builder`): o Riverpod atual não permite mutar provider durante o
    // build da árvore — o cache precisa estar quente **antes** do primeiro
    // frame.
    final container = ProviderContainer(
      overrides: [
        ...standardTestOverrides(prefs: prefs),
        // Sem isto, o lookup do manifest tenta a rede de verdade (falha) e o
        // retry automático do Riverpod deixa um Timer pendente no fim do
        // teste — mesmo remendo dos demais testes de catálogo.
        louvoresManifestOverride(
          const LouvoresManifest(louvores: [], availableArranjos: {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Louvor em cache: sem ele o chip de partitura cai no fallback por
    // `pdfLabels` (categoria vazia, sem ícone) — a asserção de ícone abaixo
    // precisa de metadados reais, como a tela de verdade tem.
    container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
      Louvor(
        pdfId: _pdfA,
        pdf: '001.pdf',
        groupId: '001',
        numero: '001',
        nome: 'Santo',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
        searchTitleNorm: 'santo',
        searchContentTokens: const [],
        searchCompactContent: '',
      ),
    ]);
    container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
      AudioTrack(
        audioId: _audioA,
        r2Key: 'ColAdultos/001.mp3',
        nome: 'Santo',
        numero: '001',
        groupId: '001',
        categoria: 'Áudio',
        classificacao: 'ColAdultos',
      ),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: PlaylistTileDetailChips(
              item: PlaylistViewItem(
                playlist: playlist,
                pdfLabels: const ['001 — Santo'],
              ),
              loading: false,
              onPdfTap: (id) async => tappedPdf.add(id),
              onAudioTap: (track) async => tappedAudio.add(track.audioId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Título do chip é «#numero — nome» (variante modal, D2): a asserção
    // busca pelo trecho, não pelo texto inteiro do `Text`.
    expect(find.textContaining('Santo'), findsNWidgets(2));
    expect(find.byIcon(LouvorMaterialIcons.audio), findsOneWidget);
    expect(find.byIcon(Icons.piano), findsOneWidget);

    await tester.tap(find.textContaining('Santo').last);
    await tester.pump();
    expect(tappedAudio, [_audioA]);
    expect(tappedPdf, isEmpty);
  });

  testWidgets(
    'áudio ainda sem faixa em cache usa fallback e fica inerte até o cache '
    'aquecer (Importante #4)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tappedAudio = <String>[];

      final playlist = SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto',
        entries: [PlaylistEntry(id: _audioA, kind: MaterialKind.audio)],
        createdAt: DateTime(2026, 9, 12),
        salva: true,
      );

      final container = ProviderContainer(
        overrides: [
          ...standardTestOverrides(prefs: prefs),
          louvoresManifestOverride(
            const LouvoresManifest(louvores: [], availableArranjos: {}),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Scaffold(
              body: PlaylistTileDetailChips(
                item: PlaylistViewItem(playlist: playlist, pdfLabels: const []),
                loading: false,
                onPdfTap: (id) async {},
                onAudioTap: (track) async => tappedAudio.add(track.audioId),
              ),
            ),
          ),
        ),
      );
      // Não `pumpAndSettle`: o spinner do chip (Importante #4) anima para
      // sempre enquanto a faixa não chega.
      await tester.pump();

      // Fallback: nem o id cru (base64), nem uma string vazia — e o toque
      // não faz nada enquanto a faixa não chega.
      expect(find.textContaining(_audioA), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      expect(tappedAudio, isEmpty);

      // Cache aquece: o `watch` reconstrói o chip com nome, ícone e toque de
      // verdade, sem precisar reabrir a tela (era `ref.read` antes do fix).
      container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
        AudioTrack(
          audioId: _audioA,
          r2Key: 'ColAdultos/001.mp3',
          nome: 'Santo',
          numero: '001',
          groupId: '001',
          categoria: 'Áudio',
          classificacao: 'ColAdultos',
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Santo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.textContaining('Santo'));
      await tester.pump();
      expect(tappedAudio, [_audioA]);
    },
  );
}
