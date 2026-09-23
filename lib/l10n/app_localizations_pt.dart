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
  String get searchFreshnessChecking => 'Em cache · a verificar…';

  @override
  String get searchFreshnessUpdated => 'Atualizado';

  @override
  String searchFreshnessUpdatedNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atualizado · $count novos',
      one: 'Atualizado · 1 novo',
    );
    return '$_temp0';
  }

  @override
  String get searchFreshnessOffline => 'Em cache · sem ligação';

  @override
  String get searchFreshnessFailed => 'Em cache · não foi possível verificar';

  @override
  String get searchResultNew => 'novo';

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
  String offlineProgressDetail(
    String category,
    int done,
    int total,
    String phase,
  ) {
    return '$category — $done/$total PDFs ($phase)';
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
  String get leafletShareQrCaption => 'Abrir lista no PLPCG';

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
  String get playlistActivate => 'Editar por aqui';

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
  String get materialNotDownloadedOffline => 'Não baixado · sem ligação';

  @override
  String get materialNeedsConnection => 'Precisa de ligação';

  @override
  String get materialSheetOfflineBanner =>
      'Sem ligação · só o que está no aparelho abre';

  @override
  String get playlistStorageUnavailable =>
      'Armazenamento local indisponível. Listas não podem ser salvas.';

  @override
  String get liveFollowingCannotEdit =>
      'Você está seguindo a lista de outra pessoa — saia da sessão para editar a sua';

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
  String get gestureSectionChorus => 'coro';

  @override
  String gestureSectionPass(int n) {
    return '$nª vez';
  }

  @override
  String get gesturesReaderToggleTheme => 'Alternar tema do leitor';

  @override
  String get gesturesReaderLinear => 'Mudar para leitura linear';

  @override
  String get gesturesReaderStructured => 'Mudar para leitura estruturada';

  @override
  String get gesturesAutoscrollPlay => 'Iniciar rolagem automática';

  @override
  String get gesturesAutoscrollPause => 'Pausar rolagem automática';

  @override
  String gesturesAutoscrollSpeed(int speed) {
    return 'Velocidade da rolagem: $speed';
  }

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
  String get audioNotDownloaded =>
      'Este áudio não foi baixado — sem ligação, só o que está no aparelho toca';

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
  String get playlistGoLive => 'Iniciar ao vivo';

  @override
  String get playlistShare => 'Compartilhar';

  @override
  String get playlistImport => 'Importar lista';

  @override
  String get liveJoinRoom => 'Entrar na sala';

  @override
  String get liveJoinRoomTitle => 'Entrar numa sala ao vivo';

  @override
  String get liveJoinRoomInputLabel => 'Link ou código da sala';

  @override
  String get liveJoinRoomInvalid => 'Link ou código de sala inválido';

  @override
  String get liveJoinRoomConfirm => 'Entrar';

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
  String get playlistShareOptionLinkWithLeaflet => 'Folheto';

  @override
  String get playlistShareOptionLinkWithLeafletSubtitle =>
      'Imagem da lista com o link e QR code';

  @override
  String playlistShareLinkWithLeafletMessage(String name, String url) {
    return '$name\n\n$url';
  }

  @override
  String get playlistShareColdigomTitle => 'Lista com materiais do Coldigom';

  @override
  String get playlistShareColdigomBodyLeaflet =>
      'O link e o QR code só funcionam com hinos do PLPCG. Remova os cards do Coldigom da lista para compartilhar com link, ou envie só o folheto.';

  @override
  String get playlistShareColdigomBodyLink =>
      'O link só funciona com hinos do PLPCG. Remova os cards do Coldigom da lista para compartilhar o link.';

  @override
  String get playlistShareColdigomCancel => 'Cancelar';

  @override
  String get playlistShareColdigomLeafletOnly => 'Só o folheto';

  @override
  String get playlistShareColdigomDismiss => 'Entendi';

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

  @override
  String liveFollowing(String owner, String list) {
    return 'Seguindo $owner · $list';
  }

  @override
  String get liveLeaderAway => 'gestor ausente';

  @override
  String liveWaitingFor(String owner) {
    return 'Aguardando $owner';
  }

  @override
  String get liveReconnecting => 'Reconectando…';

  @override
  String get liveReturnToLeader => 'Voltar ao gestor';

  @override
  String get liveLeave => 'Sair';

  @override
  String liveOnAir(int viewers) {
    return 'AO VIVO · $viewers';
  }

  @override
  String get liveRoom => 'Sala';

  @override
  String get liveEnd => 'Encerrar';

  @override
  String get liveEndConfirmTitle => 'Encerrar a sessão ao vivo?';

  @override
  String get liveEndConfirmBody =>
      'Todos os que estão seguindo vão parar de receber a lista.';

  @override
  String get liveReplacedElsewhere => 'Sessão assumida em outro dispositivo';

  @override
  String get liveColdigomOnlyTitle => 'Só materiais do Coldigom';

  @override
  String get liveColdigomOnlyBody =>
      'Para transmitir ao vivo, todos os materiais da lista precisam ser do Coldigom. Troque os do PLPCG e tente de novo.';

  @override
  String get liveColdigomOnlyAdd => 'Ao vivo, só entram materiais do Coldigom';

  @override
  String get liveOk => 'OK';

  @override
  String liveWasLive(String list) {
    return 'Você estava ao vivo com «$list»';
  }

  @override
  String get liveResume => 'Retomar';

  @override
  String get liveJoining => 'Entrando…';

  @override
  String get liveUnavailableTitle => 'Não foi possível conectar à sessão';

  @override
  String get liveUnavailableBody =>
      'Esta rede pode bloquear conexões ao vivo. Tente outra rede ou peça o link da lista pública.';

  @override
  String get liveRetry => 'Tentar de novo';

  @override
  String get liveNotFound =>
      'Este link não existe ou foi substituído por um novo.';

  @override
  String liveIdleTitle(String owner) {
    return '$owner não está ao vivo agora';
  }

  @override
  String get liveIdleBody =>
      'Fique por aqui — quando começar, você entra sozinho.';

  @override
  String liveFollowingTitle(String owner) {
    return 'Você está seguindo $owner';
  }

  @override
  String get liveGoToList => 'Ir para a lista';

  @override
  String get liveEndedTitle => 'Sessão encerrada';

  @override
  String get liveSaveCopy => 'Guardar cópia';

  @override
  String liveCopyName(String list, String owner) {
    return '$list (ao vivo com $owner)';
  }

  @override
  String get liveCopySaved => 'Cópia guardada em Listas';

  @override
  String get liveLeftTitle => 'Você saiu da sessão';

  @override
  String get liveJoinAgain => 'Entrar de novo';

  @override
  String get liveYourRoom => 'Sua sala ao vivo';

  @override
  String get liveShareHint =>
      'Quem abrir este link vê a sua lista em tempo real.';

  @override
  String get liveCopyLink => 'Copiar link';

  @override
  String get liveLinkCopied => 'Link copiado';

  @override
  String get liveShareLink => 'Compartilhar';

  @override
  String get liveRegenerateLink => 'Gerar novo link';

  @override
  String get liveRegenerateConfirmTitle => 'Gerar um novo link?';

  @override
  String get liveRegenerateConfirmBody =>
      'O link atual deixa de funcionar para todos.';

  @override
  String liveViewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas conectadas',
      one: '1 pessoa conectada',
      zero: 'Ninguém conectado',
    );
    return '$_temp0';
  }

  @override
  String get liveRoomError => 'Não foi possível carregar a sua sala';

  @override
  String get liveLoginRequired => 'Entre com o Google para transmitir ao vivo';

  @override
  String get liveRoomMenu => 'Sala ao Vivo';

  @override
  String get liveOpenRoom => 'Abrir Sala';

  @override
  String get lyricsTitle => 'Letra';

  @override
  String get lyricsTab => 'Letra';

  @override
  String get lyricsReaderEmpty => 'Este louvor não tem letra guardada';

  @override
  String get lyricsReaderIncreaseFont => 'Aumentar letra';

  @override
  String get lyricsReaderDecreaseFont => 'Diminuir letra';

  @override
  String get offlineColdigomPlpcgSection => 'Acervo PLPCG (PDFs)';

  @override
  String get offlineColdigomSection => 'Coldigom por tipo de material';

  @override
  String offlineColdigomCatalogStatus(int count, String ago) {
    return 'Catálogo: $count louvores · atualizado $ago';
  }

  @override
  String get offlineColdigomCatalogMissing =>
      'Ligue-se à internet para baixar o catálogo';

  @override
  String get offlineColdigomAgoJustNow => 'agora mesmo';

  @override
  String offlineColdigomAgoMinutes(int n) {
    return 'há $n min';
  }

  @override
  String offlineColdigomAgoHours(int n) {
    return 'há $n h';
  }

  @override
  String offlineColdigomAgoDays(int n) {
    return 'há $n d';
  }

  @override
  String get offlineColdigomSignInPrompt =>
      'Entre com Google para baixar os seus tipos favoritos';

  @override
  String get offlineColdigomFavoriteKinds => 'Seus tipos favoritos';

  @override
  String get offlineColdigomNoFavorites =>
      'Sem favoritos — escolha em Materiais favoritos ou abra «Outros tipos»';

  @override
  String get offlineColdigomOtherKinds => 'Outros tipos';

  @override
  String offlineColdigomKindSummary(int count, String size) {
    return '$count materiais · $size';
  }

  @override
  String offlineColdigomDownloadSelected(String size) {
    return 'Baixar selecionados ($size)';
  }

  @override
  String get offlineColdigomStop => 'Parar';

  @override
  String offlineColdigomProgress(String kind, int done, int total) {
    return '$kind · $done/$total';
  }

  @override
  String offlineColdigomDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count materiais baixados',
      one: '1 material baixado',
      zero: 'Nada novo para baixar',
    );
    return '$_temp0';
  }

  @override
  String offlineColdigomFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count não baixados',
      one: '1 não baixado',
    );
    return '$_temp0';
  }

  @override
  String offlineColdigomStopped(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Parado — $n restantes',
      one: 'Parado — 1 restante',
    );
    return '$_temp0';
  }

  @override
  String get offlineColdigomOutOfSpace => 'Sem espaço no aparelho';

  @override
  String get offlineColdigomRetry => 'Tentar de novo';

  @override
  String get offlineColdigomRemove =>
      'Remover áudios e PDFs baixados do Coldigom';

  @override
  String get offlineColdigomRemoveNote =>
      'Cifras, gestos e letras ficam no aparelho.';

  @override
  String get offlineColdigomRemoveConfirmTitle =>
      'Remover baixados do Coldigom?';

  @override
  String offlineColdigomRemoved(int pdfs, int audios) {
    return '$pdfs PDFs e $audios áudios removidos';
  }

  @override
  String offlineColdigomSpaceWarning(String size, String free) {
    return 'Estimativa de $size acima do espaço livre ($free) — o download pode parar a meio.';
  }

  @override
  String get contributeTitle => 'Ajude a melhorar o PLPCG';

  @override
  String get contributeSignInPrompt => 'Entre com Google para contribuir.';

  @override
  String get contributeKindLabel => 'O que você quer contar?';

  @override
  String get contributeKindBug => 'Bug na app';

  @override
  String get contributeKindWrongInfo => 'Informação errada';

  @override
  String get contributeKindContent => 'Conteúdo';

  @override
  String get contributeKindImprovement => 'Melhoria';

  @override
  String get contributeKindOther => 'Outro';

  @override
  String get contributeSubkindLabel => 'Sobre o quê?';

  @override
  String get contributeSubkindBugScreen => 'Uma tela';

  @override
  String get contributeSubkindBugReader => 'Leitor';

  @override
  String get contributeSubkindBugAudio => 'Áudio';

  @override
  String get contributeSubkindBugSearch => 'Busca';

  @override
  String get contributeSubkindBugOffline => 'Offline';

  @override
  String get contributeSubkindBugLogin => 'Login';

  @override
  String get contributeSubkindBugPlaylistLive => 'Listas / ao vivo';

  @override
  String get contributeSubkindBugOther => 'Outro';

  @override
  String get contributeSubkindWrongMetadata => 'Título, número, tom…';

  @override
  String get contributeSubkindWrongLyrics => 'Letra';

  @override
  String get contributeSubkindWrongMaterial => 'Material de outro louvor';

  @override
  String get contributeSubkindWrongKind => 'Tipo de material errado';

  @override
  String get contributeSubkindDuplicate => 'Louvor duplicado';

  @override
  String get contributeSubkindAddMaterial => 'Adicionar material';

  @override
  String get contributeSubkindAddPraise => 'Adicionar louvor';

  @override
  String get contributeSubkindReplaceMaterial => 'Substituir material';

  @override
  String get contributeSubkindRemove => 'Remover';

  @override
  String get contributeSubkindFeature => 'Funcionalidade nova';

  @override
  String get contributeSubkindBehavior => 'Mudar um comportamento';

  @override
  String get contributeMaterialLabel => 'Sobre qual material?';

  @override
  String get contributeMaterialWhole => 'O louvor em geral';

  @override
  String get contributeMetadataField => 'Campo';

  @override
  String get contributeMetadataCurrent => 'Valor atual';

  @override
  String get contributeMetadataProposed => 'Valor correto';

  @override
  String get contributeMetadataTitle => 'Título';

  @override
  String get contributeMetadataNumber => 'Número';

  @override
  String get contributeMetadataAuthor => 'Autor';

  @override
  String get contributeMetadataTonality => 'Tom';

  @override
  String get contributeMetadataRhythm => 'Ritmo';

  @override
  String get contributeMetadataCategory => 'Categoria';

  @override
  String get contributeMetadataTags => 'Tags';

  @override
  String get contributeDuplicateOf => 'É o mesmo que (número ou título)';

  @override
  String get contributeSuggestedKind => 'Tipo de material (opcional)';

  @override
  String get contributeTitleField => 'Título';

  @override
  String get contributeBodyField => 'Descrição';

  @override
  String get contributeBodyHintBug =>
      'O que você fez, o que esperava e o que aconteceu';

  @override
  String get contributeAttachments => 'Anexos';

  @override
  String get contributeAddFile => 'Anexar arquivo';

  @override
  String get contributeAttachmentTooLarge =>
      'Acima de 32 MB, envie pelo link do Drive.';

  @override
  String get contributeAttachmentTypeNotAllowed =>
      'Tipo de arquivo não aceito.';

  @override
  String get contributeAttachmentTooMany => 'No máximo 5 arquivos.';

  @override
  String get contributeAttachmentTotalTooLarge =>
      'No total, os anexos não podem passar de 96 MB.';

  @override
  String get contributeLinks => 'Links (YouTube / Drive)';

  @override
  String get contributeAddLink => 'Adicionar link';

  @override
  String get contributeLinkNotAllowed =>
      'Só links do YouTube ou do Google Drive.';

  @override
  String get contributeTooManyLinks => 'No máximo 5 links.';

  @override
  String get contributeDeviceTitle => 'Isto será enviado';

  @override
  String get contributeDeviceLineApp => 'App';

  @override
  String get contributeDeviceLinePlatform => 'Plataforma';

  @override
  String get contributeDeviceLineDevice => 'Dispositivo';

  @override
  String get contributeDeviceLineSystem => 'Sistema';

  @override
  String get contributeDeviceLineBrowser => 'Navegador';

  @override
  String get contributeDeviceLineScreen => 'Tela';

  @override
  String get contributeDeviceLineLocale => 'Idioma';

  @override
  String get contributeDeviceLineOnline => 'Online';

  @override
  String get contributeDeviceLinePwa => 'PWA instalada';

  @override
  String get commonYes => 'sim';

  @override
  String get commonNo => 'não';

  @override
  String get contributeSameDeviceQuestion =>
      'O bug aconteceu neste dispositivo?';

  @override
  String get contributeSameDeviceYes => 'Sim';

  @override
  String get contributeSameDeviceNo => 'Não';

  @override
  String get contributeOtherDevice => 'Em qual dispositivo?';

  @override
  String get contributeSend => 'Enviar';

  @override
  String get contributeSent => 'Recebido, obrigado!';

  @override
  String get contributeErrorOffline => 'Sem ligação. Tente de novo.';

  @override
  String contributeErrorQuota(String time) {
    return 'Limite diário atingido; volta às $time.';
  }

  @override
  String contributeErrorRejected(String error) {
    return 'O envio foi recusado: $error';
  }

  @override
  String get contributeErrorUnknown =>
      'Não foi possível enviar. Tente de novo.';

  @override
  String get contributeReportTooltip => 'Reportar';

  @override
  String get myContributionsTitle => 'Minhas contribuições';

  @override
  String get myContributionsEmpty =>
      'Você ainda não enviou nenhuma contribuição.';

  @override
  String get contributionStatusRecebida => 'Enviada · verificando anexos';

  @override
  String get contributionStatusPendente => 'Aguardando análise';

  @override
  String get contributionStatusEmAnalise => 'Em análise';

  @override
  String get contributionStatusAceita => 'Aceita';

  @override
  String get contributionStatusRecusada => 'Recusada';

  @override
  String get contributionStatusAplicada => 'Aplicada';

  @override
  String get contributionStatusBloqueada =>
      'Não pôde ser analisada: anexo recusado pela verificação de segurança';

  @override
  String get contributionDecisionNote => 'Nota da equipe';

  @override
  String get contributionFilesTitle => 'Anexos';

  @override
  String get contributionFileScanPending => 'verificando';

  @override
  String get contributionFileScanClean => 'ok';

  @override
  String get contributionFileScanBlocked => 'recusado';
}
