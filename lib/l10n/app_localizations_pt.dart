// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'PLPCG';

  @override
  String browserTitleLouvor(String numero, String nome) {
    return '$numero — $nome · PLPCG';
  }

  @override
  String browserTitleLouvorSemNumero(String nome) {
    return '$nome · PLPCG';
  }

  @override
  String browserTitleTab(String label) {
    return '$label · PLPCG';
  }

  @override
  String get searchHint => 'Buscar por número ou título';

  @override
  String get searchLabel => 'Buscar';

  @override
  String get searchClear => 'Limpar busca';

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filtersTapToExpand => 'Toque para ver mais';

  @override
  String get sharePdf => 'Compartilhar';

  @override
  String get savePdf => 'Baixar';

  @override
  String get pdfShareSuccess => 'PDF pronto para compartilhar';

  @override
  String get pdfSaveSuccess => 'PDF salvo com sucesso';

  @override
  String get pdfActionError => 'Não foi possível concluir a ação';

  @override
  String get readerFullscreenTooltip => 'Tela cheia (F)';

  @override
  String get readerExitFullscreenTooltip => 'Sair da tela cheia (Esc)';

  @override
  String get readerFitModeTooltip => 'Ajustar largura/página (Z)';

  @override
  String get readerGoToPageTitle => 'Ir para página';

  @override
  String get readerGoToPageFieldLabel => 'Número da página';

  @override
  String get readerGoToPageCancel => 'Cancelar';

  @override
  String get readerGoToPageConfirm => 'Ir';

  @override
  String get louvorPdfDownloading => 'Baixando...';

  @override
  String louvorPdfDownloadingWithProgress(int percent) {
    return 'Baixando... $percent%';
  }

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryViewTitle => 'Visualização';

  @override
  String get sortByLabel => 'Ordenar por';

  @override
  String get sortByNumber => 'Número';

  @override
  String get sortByName => 'Nome';

  @override
  String get itemsPerPage => 'Itens por página';

  @override
  String itemsPerPageValue(int count) {
    return '$count por página';
  }

  @override
  String get pagePrevious => 'Anterior';

  @override
  String get pageNext => 'Próxima';

  @override
  String pageIndicator(int current, int total) {
    return 'Página $current de $total';
  }

  @override
  String pageCurrent(int page) {
    return 'Página $page';
  }

  @override
  String get specialArrangementPadrao => 'Padrão';

  @override
  String get filtersSpecialArrangementTitle => 'Arranjo especial';

  @override
  String get catalogStaleBanner =>
      'Catálogo atualizado há mais de 7 dias. Conecte-se para atualizar.';

  @override
  String get catalogLoadError => 'Não foi possível carregar o catálogo';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get storagePreparing => 'Preparando o armazenamento local…';

  @override
  String get storageUnavailableTitle => 'Armazenamento local indisponível';

  @override
  String get storageUnavailableBody =>
      'Esta área precisa do banco local do app. O catálogo online e o leitor de PDF continuam disponíveis nas outras abas.';

  @override
  String libraryResultsSummary(int from, int to, int total) {
    return 'Mostrando $from–$to de $total louvores';
  }

  @override
  String get libraryResultsEmpty =>
      'Nenhum louvor encontrado com os filtros atuais';

  @override
  String get libraryCatalogModeLabel => 'Fonte';

  @override
  String get libraryCatalogModePlpcg => 'PLPCG';

  @override
  String get libraryCatalogModeColdigom => 'Coldigom';

  @override
  String get coldigomFilterTonality => 'Tom';

  @override
  String get coldigomFilterRhythm => 'Ritmo';

  @override
  String get coldigomFilterCategory => 'Categoria';

  @override
  String get coldigomFilterTags => 'Tags';

  @override
  String get coldigomFilterMaterials => 'Materiais';

  @override
  String get coldigomLoadError =>
      'Não foi possível carregar o catálogo Coldigom';

  @override
  String get coldigomUnavailableRetry =>
      'Coldigom indisponível · tentar de novo';

  @override
  String get offlineTitle => 'Offline';

  @override
  String get offlineSelectCategories => 'Selecione as categorias';

  @override
  String get offlineDownloadSelected => 'Baixar selecionados';

  @override
  String get offlineStopDownload => 'Parar';

  @override
  String get offlineStoppingDownload => 'Parando...';

  @override
  String get offlineCancelDownload => 'Cancelar';

  @override
  String get offlineResumeBanner => 'Há um download offline interrompido.';

  @override
  String get offlineResumeDownload => 'Retomar';

  @override
  String get offlineDismissCheckpoint => 'Descartar';

  @override
  String get offlineDownloadCompleted => 'Download offline concluído';

  @override
  String offlineDownloadCompletedWithFailures(int failedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      failedCount,
      locale: localeName,
      other: 'Download concluído com $failedCount arquivos com falha',
      one: 'Download concluído com 1 arquivo com falha',
    );
    return '$_temp0';
  }

  @override
  String get offlineKeepAppOpenDuringDownload =>
      'Mantenha o app aberto durante o download.';

  @override
  String get offlineInsufficientDiskSpace =>
      'Espaço em disco insuficiente para o download';

  @override
  String get offlineStorageUnavailable =>
      'Armazenamento local indisponível. Recarregue a página ou libere espaço.';

  @override
  String get offlineMaintenanceBusy =>
      'Outra operação offline está em andamento. Tente de novo em instantes.';

  @override
  String get offlinePhaseFetching => 'baixando';

  @override
  String get offlinePhaseExtracting => 'extraindo';

  @override
  String get offlinePhaseStoring => 'armazenando';

  @override
  String get offlinePhaseSyncing => 'sincronizando';

  @override
  String offlineProgressDetail(
    String category,
    int part,
    int totalParts,
    int done,
    int total,
    String phase,
  ) {
    return '$category — parte $part/$totalParts — $done/$total PDFs ($phase)';
  }

  @override
  String offlineProgressDetailWeb(
    String category,
    int done,
    int total,
    String phase,
  ) {
    return '$category — $done/$total PDFs ($phase)';
  }

  @override
  String offlineFetchProgress(
    int part,
    int totalParts,
    String received,
    String total,
  ) {
    return 'Baixando pacote $part/$totalParts — $received / $total';
  }

  @override
  String get offlineStatsTitle => 'PDFs armazenados';

  @override
  String offlineStatsTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs offline',
      one: '1 PDF offline',
      zero: 'Nenhum PDF offline',
    );
    return '$_temp0';
  }

  @override
  String offlineStatsCategory(String category, int count) {
    return '$category: $count';
  }

  @override
  String offlineStatsCategoryWithMissing(
    String category,
    int downloaded,
    int missing,
  ) {
    return '$category: $downloaded ($missing faltantes)';
  }

  @override
  String offlineStatsTotalMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs faltantes no total',
      one: '1 PDF faltante no total',
    );
    return '$_temp0';
  }

  @override
  String get offlineStatsMissingUnreliable =>
      'Faltantes indisponíveis (sem conexão)';

  @override
  String offlineStatsDiskUsage(String used, String free) {
    return 'Acervo offline: $used | Disponível: $free';
  }

  @override
  String offlineStatsDiskUsageUsedOnly(String used) {
    return 'Acervo offline: $used';
  }

  @override
  String offlineStatsCategoryUnreliableMissing(
    String category,
    int downloaded,
  ) {
    return '$category: $downloaded (— faltantes, sem conexão)';
  }

  @override
  String get offlineRefreshStats => 'Atualizar';

  @override
  String get offlineRefreshSuccess => 'Informações offline atualizadas';

  @override
  String get offlineRefreshError =>
      'Não foi possível atualizar as informações offline';

  @override
  String offlineRemovedBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs deixaram de estar disponíveis localmente',
      one: '1 PDF deixou de estar disponível localmente',
    );
    return '$_temp0';
  }

  @override
  String get offlineDownloadMissing => 'Baixar faltantes';

  @override
  String offlineMissingLouvoresSheetTitle(String category) {
    return '$category — faltantes';
  }

  @override
  String get offlineMissingLouvoresEmpty =>
      'Nenhum PDF faltante nesta categoria';

  @override
  String get offlineMissingLouvoresLoadError =>
      'Não foi possível carregar os faltantes';

  @override
  String get offlineDismissRemoved => 'Dispensar';

  @override
  String get offlineClearCache => 'Limpar cache offline';

  @override
  String get offlineClearCacheConfirmTitle => 'Limpar cache offline?';

  @override
  String offlineClearCacheConfirmBody(String categories) {
    return 'Os PDFs baixados de $categories serão removidos. Esta ação não pode ser desfeita.';
  }

  @override
  String get offlineClearCacheConfirmBodyAll =>
      'Todos os PDFs offline serão removidos. Esta ação não pode ser desfeita.';

  @override
  String get offlineClearCacheConfirm => 'Limpar';

  @override
  String get offlineClearCacheCancel => 'Cancelar';

  @override
  String get offlineClearCacheSuccess => 'Cache offline limpo';

  @override
  String offlineClearCacheSuccessPartial(String categories) {
    return 'Cache de $categories limpo';
  }

  @override
  String offlineMissingProgress(int done, int total) {
    return 'Baixando faltantes: $done/$total';
  }

  @override
  String offlineMissingCompleted(int downloaded, int failed) {
    return 'Download concluído: $downloaded baixados, $failed falhas';
  }

  @override
  String get offlineMissingError => 'Não foi possível baixar os PDFs faltantes';

  @override
  String get pdfOfflineUnavailableMessage =>
      'Este PDF não foi baixado para uso offline. Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.';

  @override
  String get pdfLocalReadFailedMessage =>
      'Não foi possível ler o arquivo. Tente novamente.';

  @override
  String get pdfExternallyDeleted =>
      'O PDF foi removido do dispositivo. Conecte-se ou use Configurações Offline → Baixar faltantes.';

  @override
  String get pdfLocalCorrupted =>
      'O PDF salvo no dispositivo está corrompido. Baixe de novo para continuar.';

  @override
  String get pdfOfflineGoToSettings => 'Baixar';

  @override
  String get pdfOfflinePersistentTooltip =>
      'Disponível offline (download garantido)';

  @override
  String get pdfOfflineCachedLruTooltip =>
      'Cache temporário — pode ser removido para liberar espaço';

  @override
  String get carouselClear => 'Limpar seleção';

  @override
  String get carouselClearConfirmTitle => 'Limpar seleção?';

  @override
  String get carouselClearConfirmMessage =>
      'Nova Lista esvazia a seleção e mantém a lista atual. Apagar lista remove o rascunho permanentemente.';

  @override
  String get carouselClearCancel => 'Cancelar';

  @override
  String get carouselClearNewList => 'Nova Lista';

  @override
  String get carouselClearDeleteList => 'Apagar lista';

  @override
  String get carouselAdded => 'Adicionado à seleção';

  @override
  String get carouselAlreadyAdded => 'Já está na seleção';

  @override
  String get materialRemoveTooltip => 'Remover da lista';

  @override
  String get materialRemoveConfirmTitle => 'Remover da lista?';

  @override
  String materialRemoveConfirmMessage(String name) {
    return '«$name» sai da lista ativa.';
  }

  @override
  String get materialRemoved => 'Removido da lista';

  @override
  String get carouselRemoveTooltip => 'Remover';

  @override
  String get carouselAddTooltip => 'Adicionar à seleção';

  @override
  String get carouselSharePlaylist => 'Compartilhar';

  @override
  String get carouselGenerateLeaflet => 'Gerar folheto';

  @override
  String get carouselOpen => 'Abrir';

  @override
  String get carouselMaterial => 'Material';

  @override
  String get carouselList => 'Lista';

  @override
  String get carouselClearShort => 'Limpar';

  @override
  String get carouselListTitle => 'Seleção temporária';

  @override
  String get carouselListClose => 'Fechar';

  @override
  String get readerCarouselPrevious => 'Louvor anterior';

  @override
  String get readerCarouselNext => 'Próximo louvor';

  @override
  String get readerSwitchMaterial => 'Trocar material';

  @override
  String get cardAddedSwapMaterial => 'Adicionado à lista';

  @override
  String get cardSwapMaterialAction => 'Trocar material';

  @override
  String readerCarouselPosition(int current, int total) {
    return '$current de $total';
  }

  @override
  String get leafletGenerating => 'Gerando folheto…';

  @override
  String get leafletShareSubject => 'Folheto PLPCG';

  @override
  String get leafletGenerateFailed => 'Não foi possível gerar o folheto';

  @override
  String get leafletHeaderTitle => 'LOUVORES';

  @override
  String get leafletColumnNumber => 'NÚMERO';

  @override
  String get leafletColumnName => 'NOME DO HINO';

  @override
  String get leafletFooterPeace => 'A PAZ DO SENHOR JESUS CRISTO';

  @override
  String get leafletFooterGreeting => 'Bom culto!';

  @override
  String get leafletWeekdayMonday => 'SEGUNDA-FEIRA';

  @override
  String get leafletWeekdayTuesday => 'TERÇA-FEIRA';

  @override
  String get leafletWeekdayWednesday => 'QUARTA-FEIRA';

  @override
  String get leafletWeekdayThursday => 'QUINTA-FEIRA';

  @override
  String get leafletWeekdayFriday => 'SEXTA-FEIRA';

  @override
  String get leafletWeekdaySaturday => 'SÁBADO';

  @override
  String get leafletWeekdaySunday => 'DOMINGO';

  @override
  String get playlistSaveTitle => 'Salvar lista';

  @override
  String get playlistSaveNameLabel => 'Nome da lista';

  @override
  String get playlistSaveCancel => 'Cancelar';

  @override
  String get playlistSaveConfirm => 'Salvar';

  @override
  String get playlistSaved => 'Lista salva';

  @override
  String get playlistViewLists => 'Ver listas';

  @override
  String get playlistEmptyCarousel => 'A seleção está vazia';

  @override
  String get playlistEmptyList =>
      'Nenhuma lista salva. Monte uma seleção na Home ou Biblioteca e use \"Salvar como lista\".';

  @override
  String get playlistRename => 'Renomear';

  @override
  String get playlistRenameTitle => 'Renomear lista';

  @override
  String get playlistRenameConfirm => 'Salvar';

  @override
  String get playlistDelete => 'Excluir';

  @override
  String get playlistDeletedUndo => 'Lista removida';

  @override
  String get playlistDuplicate => 'Duplicar';

  @override
  String playlistCopyName(String nome) {
    return '$nome (cópia)';
  }

  @override
  String get playlistDraftLabel => 'Rascunho';

  @override
  String get playlistFavoriteOn => 'Marcar como favorita';

  @override
  String get playlistFavoriteOff => 'Remover dos favoritos';

  @override
  String playlistPdfCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count louvores',
      one: '1 louvor',
    );
    return '$_temp0';
  }

  @override
  String playlistSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partituras',
      one: '1 partitura',
    );
    return '$_temp0';
  }

  @override
  String playlistAudioOnlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count áudios',
      one: '1 áudio',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyCount => 'Vazia';

  @override
  String get playlistDeleteLastPdfTitle => 'Remover último louvor?';

  @override
  String get playlistDeleteLastPdfMessage =>
      'A lista ficará vazia e será excluída.';

  @override
  String get playlistActivate => 'Tornar lista ativa';

  @override
  String get playlistOpenInReader => 'Abrir no leitor';

  @override
  String get playlistOpenInAudioPlayer => 'Abrir no reprodutor';

  @override
  String get playlistAudioEmpty => 'Esta lista não tem áudios.';

  @override
  String get audioPlayerTitle => 'Áudio';

  @override
  String get pdfMaterialSection => 'Partituras';

  @override
  String get audioMaterialSection => 'Áudio';

  @override
  String get youtubeMaterialSection => 'YouTube';

  @override
  String get chordMaterialSection => 'Cifras';

  @override
  String get chordUnavailableRetry => 'Cifra indisponível · tentar de novo';

  @override
  String get playlistStorageUnavailable =>
      'Armazenamento local indisponível. Listas não podem ser salvas.';

  @override
  String get chordReaderUnavailable => 'Cifra ainda não disponível';

  @override
  String get chordReaderToggleTheme => 'Alternar tema do leitor';

  @override
  String get chordReaderIncreaseFont => 'Aumentar letra';

  @override
  String get chordReaderDecreaseFont => 'Diminuir letra';

  @override
  String get chordReaderTransposeUp => 'Subir meio tom';

  @override
  String get chordReaderTransposeDown => 'Descer meio tom';

  @override
  String get chordReaderResetTranspose => 'Voltar ao tom original';

  @override
  String get gestureNotFound => 'gesto não encontrado';

  @override
  String get gesturesMaterialLabel => 'Gestos';

  @override
  String get gesturesMaterialSection => 'Gestos';

  @override
  String get gesturesReaderTitle => 'Leitor de gestos';

  @override
  String get gesturesReaderEmpty => 'Este louvor ainda não tem gestos';

  @override
  String get gesturesReaderUnavailable =>
      'Gestos indisponíveis · tentar de novo';

  @override
  String get gesturesReaderIncreaseFont => 'Aumentar letra dos gestos';

  @override
  String get gesturesReaderDecreaseFont => 'Diminuir letra dos gestos';

  @override
  String get gesturesReaderFullscreen => 'Tela cheia';

  @override
  String get gesturesNewerSchemaWarning =>
      'Documento em formato mais novo; atualize o app.';

  @override
  String get gestureInstructionInstruments => 'Instrumentos';

  @override
  String get gestureInstructionRepeatPraise => 'Repetir o louvor';

  @override
  String get gestureInstructionBackToChorus => 'Voltar ao coro';

  @override
  String get gestureInstructionBackToChorusAndFinish =>
      'Voltar ao coro e finalizar';

  @override
  String gestureContextRepeat(int count) {
    return '${count}x';
  }

  @override
  String get gestureContextChorus => 'CORO';

  @override
  String get gestureContextFinal => 'FINAL';

  @override
  String get gestureContextLink => 'ligação';

  @override
  String get gestureFocusNext => 'próximo:';

  @override
  String get gestureFocusEnd => 'fim';

  @override
  String get gestureFocusClose => 'Fechar';

  @override
  String get chordAutoscrollPlay => 'Iniciar rolagem automática';

  @override
  String get chordAutoscrollPause => 'Pausar rolagem automática';

  @override
  String chordAutoscrollSpeed(int speed) {
    return 'Velocidade da rolagem: $speed';
  }

  @override
  String get coldigomMetaTonality => 'Tom';

  @override
  String get coldigomMetaAuthor => 'Autor';

  @override
  String get coldigomMetaRhythm => 'Ritmo';

  @override
  String get coldigomMetaCategory => 'Categoria';

  @override
  String get coldigomMetaTags => 'Tags';

  @override
  String get youtubeOpenError => 'Não foi possível abrir o YouTube';

  @override
  String get audioPlay => 'Reproduzir';

  @override
  String get audioPause => 'Pausar';

  @override
  String get audioPrevious => 'Anterior';

  @override
  String get audioNext => 'Próximo';

  @override
  String get audioSeekBack10 => 'Voltar 10 s';

  @override
  String get audioSeekForward10 => 'Avançar 10 s';

  @override
  String get audioSpeed => 'Velocidade de reprodução';

  @override
  String audioSpeedValue(String value) {
    return '$value×';
  }

  @override
  String get miniPlayerPrevious => 'Faixa anterior';

  @override
  String get miniPlayerNext => 'Próxima faixa';

  @override
  String get miniPlayerOpenScreen => 'Abrir tela do áudio';

  @override
  String get audioClosePlayer => 'Encerrar e voltar à busca';

  @override
  String get audioOpenSheetMusic => 'Partitura/cifra deste louvor';

  @override
  String get audioFollowReader => 'Seguir o áudio';

  @override
  String get audioFlagAdd => 'Adicionar marcador';

  @override
  String get audioFlagAddTitle => 'Novo marcador';

  @override
  String get audioFlagLabelHint => 'Rótulo opcional';

  @override
  String get audioFlagCancel => 'Cancelar';

  @override
  String get audioFlagSave => 'Salvar';

  @override
  String get audioFlagListTitle => 'Marcadores';

  @override
  String get audioFlagListEmpty =>
      'Nenhum marcador. Pause e toque no botão de bandeira.';

  @override
  String get audioFlagDelete => 'Remover marcador';

  @override
  String get audioFlagsSyncFailed => 'Marcadores não sincronizados';

  @override
  String get audioPlaybackError => 'Não foi possível reproduzir este áudio.';

  @override
  String get audioWebBackgroundNotice =>
      'Na Web, a reprodução em segundo plano e os controles do sistema dependem do navegador — isso não é um bug do app.';

  @override
  String get audioWebPlatformHintTooltip => 'Sobre reprodução na Web';

  @override
  String get audioWebIosPwaNotice =>
      'No iPhone com o app instalado na tela inicial, o áudio pode pausar ao bloquear a tela ou trocar de app. Mantenha o app aberto para ouvir.';

  @override
  String playlistActivated(String nome) {
    return 'Lista «$nome» ativa';
  }

  @override
  String get undo => 'Desfazer';

  @override
  String get playlistEmptyPdfList => 'Esta lista não tem louvores.';

  @override
  String get playlistShare => 'Compartilhar';

  @override
  String get playlistImport => 'Importar lista';

  @override
  String get playlistImportTitle => 'Importar lista compartilhada';

  @override
  String get playlistImportUrlLabel => 'URL ou link compartilhado';

  @override
  String get playlistImportPaste => 'Colar';

  @override
  String get playlistImportConfirm => 'Importar';

  @override
  String get playlistSyncFailed => 'Não foi possível sincronizar suas listas';

  @override
  String playlistSyncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas em conflito',
      one: '1 lista em conflito',
    );
    return '$_temp0';
  }

  @override
  String playlistConflictCopySaved(String nome, String copia) {
    return 'Edições locais de «$nome» guardadas em «$copia»';
  }

  @override
  String playlistsRemovedRemotely(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas removidas em outro aparelho',
      one: '1 lista removida em outro aparelho',
    );
    return '$_temp0';
  }

  @override
  String get playlistImported => 'Lista importada';

  @override
  String playlistImportAlreadySaved(String nome) {
    return 'Lista já estava salva: $nome';
  }

  @override
  String get playlistImportInvalidUrl =>
      'Link inválido. Use uma URL com sharepdfs e sharename.';

  @override
  String get deepLinkImportFailed =>
      'Não foi possível importar a lista compartilhada.';

  @override
  String get playlistShareError => 'Não foi possível compartilhar a lista.';

  @override
  String get playlistShareSheetTitle => 'Compartilhar';

  @override
  String get playlistShareOptionLink => 'Só o link';

  @override
  String get playlistShareOptionLinkSubtitle =>
      'Quem receber importa a lista no PLPCG';

  @override
  String get playlistShareOptionLeaflet => 'Só o folheto';

  @override
  String get playlistShareOptionLeafletSubtitle =>
      'Imagem com a lista de louvores';

  @override
  String get playlistShareOptionLinkWithLeaflet => 'Link com folheto';

  @override
  String get playlistShareOptionLinkWithLeafletSubtitle =>
      'Imagem e link na mesma mensagem';

  @override
  String get playlistShareOptionWhatsApp => 'Link + folheto';

  @override
  String get playlistShareOptionWhatsAppSubtitle =>
      'Para WhatsApp — envia foto e depois o link';

  @override
  String get playlistShareWhatsAppStepTitle => 'Envie o link';

  @override
  String get playlistShareWhatsAppStepMessage =>
      'Envie o link no mesmo chat em que você mandou o folheto.';

  @override
  String get playlistShareWhatsAppStepContinue => 'Enviar link';

  @override
  String get playlistShareWhatsAppStepCancel => 'Agora não';

  @override
  String playlistShareLinkWithLeafletMessage(String name, String url) {
    return '$name\n\n$url';
  }

  @override
  String get playlistTabUnsaved => 'Não Salvas';

  @override
  String get playlistTabSaved => 'Salvas';

  @override
  String get playlistTabFavorites => 'Favoritas';

  @override
  String get playlistSaveAction => 'Salvar lista';

  @override
  String get playlistEmptyUnsaved =>
      'Nenhuma lista não salva. Abra um louvor no leitor para criar uma automaticamente.';

  @override
  String get playlistEmptySaved => 'Nenhuma lista salva.';

  @override
  String get playlistEmptyFavorites => 'Nenhuma lista favorita.';

  @override
  String get playlistDeleteAllUnsaved => 'Apagar todas';

  @override
  String get playlistDeleteAllUnsavedTitle =>
      'Apagar todas as listas não salvas?';

  @override
  String get playlistDeleteAllUnsavedMessage =>
      'Todas as listas da aba Não Salvas serão removidas permanentemente.';

  @override
  String get playlistDeleteAllUnsavedDone => 'Listas não salvas apagadas';

  @override
  String get playlistPublish => 'Publicar';

  @override
  String get playlistPublishTitle => 'Publicar lista?';

  @override
  String get playlistPublishMessage =>
      'Publicar é irreversível. Para remover a publicação, exclua a lista.';

  @override
  String get playlistPublishConfirm => 'Publicar';

  @override
  String get playlistPublishCancel => 'Cancelar';

  @override
  String get playlistPublishCategoryLabel => 'Categoria';

  @override
  String get playlistPublishReachLabel => 'Alcance';

  @override
  String get playlistPublishReachUsual => 'Usual';

  @override
  String get playlistPublishReachPontual => 'Pontual';

  @override
  String get playlistPublishCategoryRequired =>
      'Escolha uma categoria para publicar.';

  @override
  String get playlistPublished => 'Lista publicada';

  @override
  String get playlistPublicBadge => 'Pública';

  @override
  String get playlistCategoryEvangelizacao => 'Evangelização';

  @override
  String get playlistCategoryAprendizado => 'Aprendizado';

  @override
  String get playlistCategoryMedleys => 'Medleys';

  @override
  String get playlistCategoryCultoEspecial => 'Culto especial';

  @override
  String get playlistClearSavedBlocked =>
      'Listas salvas não podem ser limpas pela barra. Use o menu da lista.';

  @override
  String louvorGroupMetadataSummary(int entryCount, int arrangementCount) {
    String _temp0 = intl.Intl.pluralLogic(
      entryCount,
      locale: localeName,
      other: '$entryCount entradas',
      one: '1 entrada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      arrangementCount,
      locale: localeName,
      other: '$arrangementCount arranjos',
      one: '1 arranjo',
    );
    return '$_temp0 com $_temp1';
  }

  @override
  String get usernameCreateButton => 'Criar nome de usuário';

  @override
  String get usernameCreateTitle => 'Criar nome de usuário';

  @override
  String get usernameCreateMessage =>
      'Escolha um nome de usuário único no app. Ele identifica você e suas listas públicas. Use 3 a 30 caracteres: letras minúsculas, números ou _.';

  @override
  String get usernameCreatePrompt =>
      'Cadastre um nome de usuário para publicar listas.';

  @override
  String get usernameFieldLabel => 'Nome de usuário';

  @override
  String get usernameFieldHint => 'ex.: maria_silva';

  @override
  String get usernameCreateCancel => 'Cancelar';

  @override
  String get usernameCreateConfirm => 'Salvar';

  @override
  String get usernameErrorInvalid => 'Use 3–30 caracteres: a-z, 0-9 ou _.';

  @override
  String get usernameErrorTaken => 'Esse nome de usuário já está em uso.';

  @override
  String get usernameErrorAlreadySet => 'Você já tem um nome de usuário.';

  @override
  String get usernameErrorGeneric =>
      'Não foi possível salvar. Tente novamente.';

  @override
  String get usernameRequiredToPublish => 'Cadastrar Nome de Usuário';

  @override
  String get socialSearchHint => 'Buscar pessoa por nome de usuário';

  @override
  String get socialSearchEmptyHint =>
      'Digite um nome de usuário para encontrar pessoas.';

  @override
  String get socialSearchNoResults => 'Nenhuma pessoa encontrada.';

  @override
  String get socialSearchError => 'Não foi possível buscar. Tente novamente.';

  @override
  String get publicPlaylistsTitle => 'Listas públicas';

  @override
  String get socialSignInRequired =>
      'Entre com o Google para explorar as listas públicas.';

  @override
  String socialPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String get socialPlaylistsError => 'Não foi possível carregar as listas.';

  @override
  String get socialPlaylistsEmpty =>
      'Este perfil ainda não tem listas públicas.';

  @override
  String get socialCategoryOther => 'Outras';

  @override
  String socialPlaylistImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count louvores adicionados à sua lista',
      one: '1 louvor adicionado à sua lista',
    );
    return '$_temp0';
  }

  @override
  String get socialPlaylistImportNone => 'Nenhum louvor novo para adicionar.';

  @override
  String get deferredLoaderLoading => 'Carregando…';

  @override
  String get deferredLoaderError => 'Não foi possível carregar esta seção.';

  @override
  String get deferredLoaderRetry => 'Tentar novamente';

  @override
  String get authSignInUnavailable => 'Login indisponível no momento.';

  @override
  String get authSignInRetry => 'Tentar novamente';

  @override
  String get authSignInWithGoogle => 'Entrar com o Google';

  @override
  String get authSignInContextMismatchTitle =>
      'Não conseguimos concluir o login';

  @override
  String get authSignInContextMismatchBody =>
      'O Google respondeu em outra janela. Toque para tentar novamente.';

  @override
  String get authSignInOpenInBrowserHint =>
      'Se continuar, abra v2.plpcg.com no Safari.';

  @override
  String get errorNoConnection =>
      'Sem conexão com a internet. Verifique sua rede e tente de novo.';

  @override
  String get errorTimeout => 'A conexão demorou demais. Tente de novo.';

  @override
  String get errorServer =>
      'O servidor está indisponível no momento. Tente de novo em instantes.';

  @override
  String get errorSessionExpired =>
      'Sua sessão expirou. Entre novamente para continuar.';

  @override
  String get errorGeneric => 'Não foi possível concluir a ação. Tente de novo.';

  @override
  String get failureNetwork =>
      'Sem conexão com a internet. Verifique sua rede e tente de novo.';

  @override
  String get failureOffline =>
      'Este PDF não foi baixado para uso offline. Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.';

  @override
  String get failureNotFound =>
      'Não foi possível encontrar. O item pode ter sido removido.';

  @override
  String get failureStorage =>
      'Armazenamento local indisponível. Recarregue a página ou libere espaço.';

  @override
  String get failureAuth =>
      'Sua sessão expirou. Entre novamente para continuar.';

  @override
  String get failureConflict => 'Conflito de sincronização. Tente novamente.';

  @override
  String get failureUnknown =>
      'Não foi possível concluir a ação. Tente de novo.';

  @override
  String get sessionExpiredBanner => 'Sessão expirada';

  @override
  String get sessionExpiredSignInAgain => 'Entrar de novo';

  @override
  String get homeEmptyHint => 'Busque por título ou número';

  @override
  String get homeEmptyRecent => 'Abertos recentemente';

  @override
  String homeNoResults(String query) {
    return 'Nenhum louvor para «$query»';
  }

  @override
  String get homeNoResultsTips =>
      'Tente outro termo, ou confira o número e a grafia.';

  @override
  String get homeClearFilters => 'Limpar filtros';

  @override
  String get homeColdigomOffline =>
      'Sem conexão — o acervo Coldigom pode estar incompleto nesta busca.';

  @override
  String get favoriteMaterialKindsTitle => 'Materiais favoritos';

  @override
  String favoriteMaterialKindsHelp(int max) {
    return 'Escolha até $max tipos de material. Eles aparecem primeiro ao abrir um louvor.';
  }

  @override
  String favoriteMaterialKindsYours(int count, int max) {
    return 'Seus favoritos ($count de $max)';
  }

  @override
  String get favoriteMaterialKindsEmpty => 'Nenhum favorito ainda';

  @override
  String get favoriteMaterialKindsAdd => 'Adicionar';

  @override
  String get favoriteMaterialKindsSearchHint => 'Buscar tipo de material';

  @override
  String favoriteMaterialKindsLimitReached(int max) {
    return 'Limite de $max — remova um para trocar';
  }

  @override
  String get favoriteMaterialKindsSignInPrompt =>
      'Entre com Google para escolher seus materiais favoritos.';

  @override
  String get favoriteMaterialKindsSyncPending => 'Sincronização pendente';

  @override
  String get favoriteMaterialKindsRemoveTooltip => 'Remover dos favoritos';

  @override
  String get favoriteMaterialKindsAddTooltip => 'Adicionar aos favoritos';

  @override
  String get favoriteMaterialKindsUnknownKind => 'Desconhecido';

  @override
  String get favoriteMaterialKindsLoadError =>
      'Não foi possível carregar os tipos de material';

  @override
  String get favoriteMaterialKindsRetry => 'Tentar de novo';

  @override
  String get favoriteMaterialKindsNoMatch => 'Nenhum tipo com esse nome';

  @override
  String get favoriteMaterialKindsTypePreferenceTooltip =>
      'Escolher formato preferido';

  @override
  String favoriteMaterialKindsTypePreferenceTitle(String kind) {
    return 'Formato preferido de $kind';
  }

  @override
  String get favoriteMaterialKindsTypePreferenceHelp =>
      'Arraste para ordenar — o primeiro da lista é o formato preferido.';
}
