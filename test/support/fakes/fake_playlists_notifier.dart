// test/support/fakes/fake_playlists_notifier.dart
//
// Fake compartilhada de [PlaylistsNotifier] (E10) — reúne os comportamentos
// que 17 arquivos de teste reimplementavam cada um a seu modo: build() com
// lista inicial fixa, contadores/flags de chamada e resultados configuráveis
// para os métodos que a presentation aciona a partir de futuros não
// aguardados (`addLouvorToActivePlaylist`/`addAudioToActivePlaylist`).
import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';

class FakePlaylistsNotifier extends PlaylistsNotifier {
  FakePlaylistsNotifier([
    this.initial = const [],
    this.deleteAllUnsavedThrows,
    this.addLouvorResult = true,
    this.addAudioResult = true,
    this.importedPlaylistId = 'imported-id',
  ]);

  final List<PlaylistViewItem> initial;

  /// Quando não nulo, [deleteAllUnsaved] lança este erro em vez de suceder.
  final Object? deleteAllUnsavedThrows;

  /// Resultado devolvido por [addLouvorToActivePlaylist].
  final bool addLouvorResult;

  /// Resultado devolvido por [addAudioToActivePlaylist].
  final bool addAudioResult;

  /// Id devolvido por [importSharedFromUrl] quando não há erro.
  final String? importedPlaylistId;

  final addedPdfIds = <String>[];
  final addedAudioIds = <String>[];
  final renamed = <(String, String)>[];

  /// Nomes passados a [saveActivePlaylist]; devolve [saveActiveResult].
  final savedActiveNames = <String>[];
  var saveActiveResult = true;
  PlaylistShareParams? lastImport;

  var refreshCalled = false;
  var reloadCalls = 0;
  var startedNewEmpty = false;
  var deletedActiveUnsaved = false;

  @override
  List<PlaylistViewItem> build() => initial;

  @override
  Future<void> refreshAfterImport() async {
    refreshCalled = true;
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
  }

  @override
  Future<bool> addLouvorToActivePlaylist(String pdfId) async {
    addedPdfIds.add(pdfId);
    return addLouvorResult;
  }

  @override
  Future<bool> addAudioToActivePlaylist(String audioId) async {
    addedAudioIds.add(audioId);
    return addAudioResult;
  }

  @override
  Future<bool> saveActivePlaylist({required String nome}) async {
    savedActiveNames.add(nome);
    return saveActiveResult;
  }

  @override
  Future<void> rename({
    required String playlistId,
    required String nome,
  }) async {
    renamed.add((playlistId, nome));
  }

  /// Como a implementação real, delega no editor da lista ativa — os
  /// testes que precisam observar esse efeito sobrescrevem
  /// `activePlaylistEditorProvider` com uma [FakeActiveEditor].
  @override
  Future<void> startNewEmptySelection() async {
    startedNewEmpty = true;
    await ref.read(activePlaylistEditorProvider.notifier).deleteActiveDraft();
  }

  @override
  Future<void> deleteActiveUnsavedPlaylist() async {
    deletedActiveUnsaved = true;
    await ref.read(activePlaylistEditorProvider.notifier).deleteActiveDraft();
  }

  @override
  Future<void> deleteAllUnsaved() async {
    final error = deleteAllUnsavedThrows;
    if (error != null) throw error;
  }

  @override
  Future<String?> importSharedFromUrl({
    required PlaylistShareParams params,
  }) async {
    lastImport = params;
    return importedPlaylistId;
  }
}
