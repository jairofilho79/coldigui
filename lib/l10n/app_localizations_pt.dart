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
  String filtersActiveCount(int count) {
    return 'Filtros ($count)';
  }

  @override
  String get filtersClear => 'Limpar filtros';

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
    return 'Mostrando $from–$to de $total resultados';
  }

  @override
  String get libraryResultsEmpty =>
      'Nenhum louvor encontrado com os filtros atuais';

  @override
  String get coldigomFilterTonality => 'Tom';

  @override
  String get coldigomFilterRhythm => 'Ritmo';

  @override
  String get coldigomFilterTags => 'Tags';

  @override
  String get coldigomFilterSubtags => 'Subtags';

  @override
  String get coldigomFilterMaterials => 'Materiais';

  @override
  String get materialTypeFilterLabel => 'Tipo';

  @override
  String get materialTypeAll => 'Todos';

  @override
  String get materialTypePdf => 'PDF';

  @override
  String get materialTypeChord => 'Cifra';

  @override
  String get materialTypeAudio => 'Áudio';

  @override
  String get materialTypeYoutube => 'YouTube';

  @override
  String get materialTypeGesture => 'Gestos';

  @override
  String get materialKindOtherClass => 'Outros';

  @override
  String materialKindHiddenByType(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count materiais ocultos pelo tipo',
      one: '1 material oculto pelo tipo',
    );
    return '$_temp0';
  }

  @override
  String materialKindShowVariants(String name) {
    return 'Ver variantes de $name';
  }

  @override
  String materialKindFamilyVariantsLabel(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variantes',
      one: '1 variante',
    );
    return '$name, $_temp0';
  }

  @override
  String get materialKindFamilyRefinedValue => 'Parcialmente selecionado';

  @override
  String get offlineTitle => 'Offline';

  @override
  String get offlineStoppingDownload => 'Parando...';

  @override
  String get offlineInsufficientDiskSpace =>
      'Espaço em disco insuficiente para o download';

  @override
  String get offlineStorageUnavailable =>
      'Armazenamento local indisponível. Recarregue a página ou libere espaço.';

  @override
  String offlineStatsDiskUsage(String used, String free) {
    return 'Acervo offline: $used | Disponível: $free';
  }

  @override
  String offlineStatsDiskUsageUsedOnly(String used) {
    return 'Acervo offline: $used';
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
  String get offlineDismissRemoved => 'Dispensar';

  @override
  String get pdfOfflineUnavailableMessage =>
      'Este PDF não foi baixado para uso offline. Conecte-se à internet ou baixe o tipo dele em Offline → Baixar para usar offline.';

  @override
  String get pdfLocalReadFailedMessage =>
      'Não foi possível ler o arquivo. Tente novamente.';

  @override
  String get pdfExternallyDeleted =>
      'O PDF foi removido do dispositivo. Conecte-se ou baixe o tipo dele de novo em Offline → Baixar para usar offline.';

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
  String get readerSwitchPraiseSwipe => 'Deslize para trocar de versão';

  @override
  String get relatedPraisesTitle => 'Versões';

  @override
  String relatedPraisesSwapped(String tag) {
    return 'Versão trocada: $tag';
  }

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
  String get gestureSectionVerse => 'estrofe';

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
  String get lyricsAutoscrollPlay => 'Iniciar rolagem automática';

  @override
  String get lyricsAutoscrollPause => 'Pausar rolagem automática';

  @override
  String lyricsAutoscrollSpeed(int speed) {
    return 'Velocidade da rolagem: $speed';
  }

  @override
  String get autoscrollSpeedTooltip => 'Velocidade da rolagem';

  @override
  String get autoscrollSlow => 'Lento';

  @override
  String get autoscrollFast => 'Rápido';

  @override
  String get autoscrollClose => 'Fechar ajuste de velocidade';

  @override
  String get coldigomMetaTonality => 'Tom';

  @override
  String get coldigomMetaAuthor => 'Autor';

  @override
  String get coldigomMetaRhythm => 'Ritmo';

  @override
  String get coldigomMetaBiblical => 'Iluminação Bíblica';

  @override
  String get coldigomMetaTags => 'Tags';

  @override
  String get coldigomMetaMoreDetails => 'Mais detalhes';

  @override
  String get coldigomMetaLessDetails => 'Menos detalhes';

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
  String get miniPlayerBackToReading => 'Voltar à leitura';

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
  String playlistImportedWithSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count louvores ficaram de fora',
      one: '1 louvor ficou de fora',
    );
    return 'Lista importada — $_temp0';
  }

  @override
  String playlistImportAlreadySaved(String nome) {
    return 'Lista já estava salva: $nome';
  }

  @override
  String get playlistImportInvalidUrl => 'Link inválido.';

  @override
  String get deepLinkImportFailed =>
      'Não foi possível importar a lista compartilhada.';

  @override
  String get playlistShareLegacyLinkUnsupported =>
      'Este link é de uma versão antiga e já não abre. Peça um link novo à pessoa.';

  @override
  String get playlistShareError => 'Não foi possível compartilhar a lista.';

  @override
  String playlistShareSkippedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens da lista ficaram fora do link',
      one: '1 item da lista ficou fora do link',
    );
    return '$_temp0';
  }

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
      'Este PDF não foi baixado para uso offline. Conecte-se à internet ou baixe o tipo dele em Offline → Baixar para usar offline.';

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
      'Sem conexão — o catálogo pode estar incompleto nesta busca.';

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
  String get offlineSectionTitle => 'Baixar para usar offline';

  @override
  String get offlineKindsAll => 'Tipos';

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
      'Entre com Google para ver os seus tipos favoritos primeiro';

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
  String get offlineColdigomRemove => 'Remover todos os baixados';

  @override
  String get offlineColdigomRemoveConfirmBody =>
      'Todos os PDFs e áudios guardados no aparelho saem, incluindo os abertos recentemente. Cifras, gestos e letras ficam.';

  @override
  String get offlineColdigomRemoveConfirmTitle => 'Remover todos os baixados?';

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

  @override
  String get contributeClearForm => 'Limpar formulário';

  @override
  String get contributeClearFormConfirmTitle => 'Limpar formulário?';

  @override
  String get contributeClearFormConfirmMessage =>
      'Tem certeza de que deseja limpar todos os campos preenchidos? Esta ação não pode ser desfeita.';

  @override
  String get contributeClearFormCancel => 'Cancelar';

  @override
  String get contributeClearFormConfirm => 'Limpar';

  @override
  String get contributeSendDeviceData =>
      'Enviar dados do aparelho para ajudar no diagnóstico';

  @override
  String get contributeBodyHint =>
      'Descreva aqui o problema, erro ou sugestão que você encontrou...';

  @override
  String get contributeLinkedPraise => 'Relato vinculado ao louvor';

  @override
  String get contributeEditorTitle => 'Sugerir melhoria no material';

  @override
  String get contributeEditorRawTab => 'Editor';

  @override
  String get contributeEditorPreviewTab => 'Pré-visualização';

  @override
  String get contributeEditorAddLine => 'Adicionar linha';

  @override
  String get contributeEditorRemoveLine => 'Remover linha';

  @override
  String get contributeEditorChangeGesture => 'Trocar gesto';

  @override
  String get contributeEditorSearchGesture =>
      'Buscar gesto por nome ou gatilho...';

  @override
  String get contributeEditorRestore => 'Restaurar original';

  @override
  String get contributeEditorNotesLabel =>
      'Observações sobre a sugestão (opcional)';

  @override
  String get contributeEditorNotesHint =>
      'Descreva brevemente o que você ajustou ou por que...';

  @override
  String get contributeEditorTriggerLabel => 'Gatilho';

  @override
  String get contributeEditorLyricsLabel => 'Texto cantado';

  @override
  String get contributeEditorAddGestureLine => 'Adicionar gesto';

  @override
  String get contributeEditorAddTextLine => 'Adicionar texto livre';

  @override
  String get contributeEditorAddChorus => 'Adicionar coro';

  @override
  String get contributeEditorAddRepeat => 'Adicionar repetição';

  @override
  String get contributeEditorMoveUp => 'Mover para cima';

  @override
  String get contributeEditorMoveDown => 'Mover para baixo';

  @override
  String get contributeEditorInsertChord => 'Inserir acorde [ ]';

  @override
  String get contributeEditorInsertComment => 'Inserir comentário (coro)';

  @override
  String get contributeEditorSwitchToGeneral =>
      'Alternar para formulário comum';

  @override
  String get contributeEditorSwitchToExtracted => 'Editar material extraído';

  @override
  String get contributeEditorLoading => 'Carregando material...';

  @override
  String get contributeEditorNoGestureFound => 'Nenhum gesto encontrado';

  @override
  String get contributeEditorSelectGesture => 'Escolher gesto';

  @override
  String get contributeEditorLyricsKind => 'Letra';

  @override
  String get contributeEditorChordKind => 'Cifra';

  @override
  String get contributeEditorGestureKind => 'Gestos';

  @override
  String get contributeEditorGeneralKind => 'Geral';

  @override
  String get contributeEditorGeneralHint =>
      'Para sugerir ajustes em Letras, Cifras ou Gestos, abra o louvor desejado no app e toque no ícone 🤝 na barra superior.';

  @override
  String get praiseOpenDetailsTooltip => 'Ver página completa';

  @override
  String get praiseShareTooltip => 'Compartilhar louvor';

  @override
  String get praiseShareLinkCopied => 'Link do louvor copiado!';

  @override
  String get praiseNotFound => 'Louvor não encontrado';

  @override
  String get praiseBackToSearch => 'Voltar para o início';

  @override
  String get praiseLyricsSectionTitle => 'Letra';

  @override
  String get praiseMaterialsSectionTitle => 'Materiais';

  @override
  String get praiseLyricsCopyTooltip => 'Copiar letra';

  @override
  String get praiseLyricsCopied => 'Letra copiada!';

  @override
  String get praiseOpenLyricsReader => 'Abrir no leitor de letra';

  @override
  String get praiseNoLyricsAvailable => 'Letra não disponível para este louvor';

  @override
  String get praiseIncreaseFontSizeTooltip => 'Aumentar fonte';

  @override
  String get praiseDecreaseFontSizeTooltip => 'Diminuir fonte';

  @override
  String get confirm => 'Confirmar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Fechar';

  @override
  String get back => 'Voltar';

  @override
  String get backTooltip => 'Voltar';

  @override
  String get homeTooltip => 'Início';

  @override
  String get placeholderComingSoon => 'Em breve';

  @override
  String get degradedStorageBannerMessage =>
      'Armazenamento local indisponível. O catálogo online continua funcionando; listas e offline ficam desativados.';

  @override
  String get tabEvents => 'Eventos';

  @override
  String get tabPlaylists => 'Listas';

  @override
  String get tabSearch => 'Pesquisar';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get tabAbout => 'Sobre';

  @override
  String get tabPraise => 'Louvor';

  @override
  String get tabPublicPlaylists => 'Listas públicas';

  @override
  String get aboutTitle => 'Sobre';

  @override
  String get profileResetTutorials => 'Redefinir Tutoriais';

  @override
  String get profileResetTutorialsDialogTitle => 'Redefinir Tutoriais';

  @override
  String get profileResetTutorialsDialogContent =>
      'Deseja redefinir todos os tutoriais? Os guias de introdução voltarão a ser exibidos automaticamente ao acessar as telas do aplicativo.';

  @override
  String get profileResetTutorialsConfirm => 'Redefinir';

  @override
  String get profileResetTutorialsSuccess =>
      'Tutoriais redefinidos com sucesso!';

  @override
  String get profileSyncPromptTitle => 'Entrar para sincronizar seus dados';

  @override
  String get profileSyncPromptBody =>
      'Use sua conta Google para sincronizar listas e outras features.';

  @override
  String get profileSignOut => 'Sair';

  @override
  String get shortcutsTitle => 'Atalhos de Teclado';

  @override
  String get shortcutsSubtitle =>
      'Comandos rápidos de produtividade para Desktop e Web';

  @override
  String get shortcutsAboutDescription =>
      'Consulte os comandos rápidos de alta produtividade para Desktop e Web.';

  @override
  String get welcomeTourAboutTitle => 'Tour de Boas-Vindas';

  @override
  String get welcomeTourAboutDescription =>
      'Faça o tour guiado de 4 passos conhecendo o fluxo do acervo ao culto.';

  @override
  String get shortcutsTabAll => 'Todos';

  @override
  String get shortcutsTabNavigation => 'Navegação';

  @override
  String get shortcutsTabRepertoireAudio => 'Repertório & Áudio';

  @override
  String get shortcutsTabSheetMusic => 'Partituras';

  @override
  String get shortcutsTabChordsGestures => 'Cifras & Gestos';

  @override
  String get shortcutsFooterTip =>
      'Pressione ? em qualquer tela para abrir este painel a qualquer momento.';

  @override
  String get shortcutsGotIt => 'Entendi';

  @override
  String get shortcutsEmpty => 'Nenhum atalho encontrado.';

  @override
  String get shortcutsOr => 'ou';

  @override
  String get shortcutCatNavigation => 'Navegação & Busca';

  @override
  String get shortcutCatRepertoireAudio => 'Repertório & Áudio';

  @override
  String get shortcutCatSheetMusic => 'Partituras (PDF)';

  @override
  String get shortcutCatChordsGestures => 'Cifras & Gestos';

  @override
  String get shortcutActionHomeSearch =>
      'Ir para a Home e focar campo de busca';

  @override
  String get shortcutActionOpenShortcuts =>
      'Abrir esta Central de Atalhos de Teclado';

  @override
  String get shortcutActionEscape =>
      'Sair de tela cheia, limpar busca ou fechar janelas';

  @override
  String get shortcutActionNextPraise =>
      'Avançar para o próximo louvor do repertório';

  @override
  String get shortcutActionPreviousPraise =>
      'Voltar para o louvor anterior do repertório';

  @override
  String get shortcutActionCarouselQueue =>
      'Navegar pela fila do carrossel de louvores';

  @override
  String get shortcutActionToggleAudio => 'Tocar ou pausar o áudio do louvor';

  @override
  String get shortcutActionToggleAudioPdf =>
      'Tocar ou pausar áudio mesmo com partitura aberta';

  @override
  String get shortcutActionSeekAudioBack => 'Voltar 10 segundos no áudio';

  @override
  String get shortcutActionSeekAudioForward => 'Avançar 10 segundos no áudio';

  @override
  String get shortcutActionToggleFullscreen => 'Alternar modo de tela cheia';

  @override
  String get shortcutActionNextPagePdf => 'Avançar página ou rolar partitura';

  @override
  String get shortcutActionPrevPagePdf => 'Voltar página da partitura';

  @override
  String get shortcutActionFirstPagePdf => 'Ir para a primeira página';

  @override
  String get shortcutActionLastPagePdf => 'Ir para a última página';

  @override
  String get shortcutActionFitModePdf =>
      'Alternar modo de ajuste (largura / altura)';

  @override
  String get shortcutActionPageGridPdf =>
      'Abrir seletor rápido de páginas em grade';

  @override
  String get shortcutActionToggleAutoscroll =>
      'Ligar ou desligar rolagem automática (autoscroll)';

  @override
  String get shortcutActionAdjustAutoscrollSpeed =>
      'Diminuir ou aumentar velocidade de rolagem';

  @override
  String get shortcutActionTransposePitch =>
      'Transpor tom do louvor (+1 / -1 semitom)';

  @override
  String get shortcutActionNextGesture =>
      'Próximo gesto ou gesto anterior na regência';

  @override
  String get shortcutBadgeReader => 'Leitor';

  @override
  String get shortcutBadgeGeneral => 'Geral';

  @override
  String get shortcutBadgeReaderPdf => 'Leitor PDF';

  @override
  String get shortcutBadgeChordsLyrics => 'Cifras/Letras';

  @override
  String get shortcutBadgeAutoscroll => 'Autoscroll';

  @override
  String get shortcutBadgeChords => 'Cifras';

  @override
  String get shortcutBadgeFocusModeCias => 'Modo Foco CIAs';

  @override
  String get materialKindChordExtracted => 'Extraídos (chords)';

  @override
  String get materialKindGestureExtracted => 'Extraídos (gestos)';

  @override
  String offlineKindVariantsCount(int count) {
    return '$count var.';
  }

  @override
  String offlineKindVariantsTitle(String name, int count) {
    return 'Variantes de $name ($count):';
  }

  @override
  String get offlineSearchMaterialTypeHint => 'Pesquisar tipo de material...';

  @override
  String get offlineClearSearchTooltip => 'Limpar pesquisa';

  @override
  String get offlineFilterButton => 'Filtrar';

  @override
  String offlineSearchNoResults(String query) {
    return 'Nenhum tipo de material encontrado para \"$query\"';
  }

  @override
  String get tutorialTooltipHowToShare => 'Como compartilhar';

  @override
  String get tutorialTooltipHowToPublish => 'Como publicar';

  @override
  String get tutorialTooltipHowToUseFilters => 'Como usar os filtros';

  @override
  String get tutorialTooltipHowToUseMaterialSheet => 'Como usar este seletor';

  @override
  String get tutorialTooltipHowToManageList => 'Como gerenciar a lista';

  @override
  String get tutorialTooltipHowToUseFocusMode => 'Como usar o Modo Foco';

  @override
  String get tutorialTooltipHowToJoinLive => 'Como ingressar';

  @override
  String get tutorialTooltipHowToUseShortcuts => 'Como usar os atalhos';

  @override
  String get contributeNeedHelp => 'Precisa de ajuda?';

  @override
  String get contributeHelpIntro =>
      'Esta página permite que você envie contribuições e nos ajude a aprimorar o aplicativo e o acervo do PLPCG. Escolha a opção que melhor descreve o seu caso:';

  @override
  String get contributeHelpDescBug =>
      'Problemas no app (travamento, tela preta, botões sem resposta ou falha no áudio/leitor). Se puder, anexe uma captura de tela.';

  @override
  String get contributeHelpDescWrongInfo =>
      'Dados incorretos em um louvor existente (número, tom, título, autor, ritmo ou louvor duplicado).';

  @override
  String get contributeHelpDescContent =>
      'Envio ou sugestão de novos materiais (cifras, partituras, áudios ou letras) ou melhoria em arquivo existente.';

  @override
  String get contributeHelpDescImprovement =>
      'Sugestões de novos recursos, mudanças no visual ou ideias para deixar o app mais prático nos ensaios e cultos.';

  @override
  String get contributeHelpDescOther =>
      'Dúvidas gerais, recados para a equipe ou qualquer outro assunto não listado acima.';

  @override
  String get contributeHelpTipAttachments =>
      'Você também pode anexar arquivos (até 32 MB) ou colar links do Google Drive e YouTube para enriquecer seu envio.';

  @override
  String get contributeEditorChordProExampleHint =>
      '[G]Exemplo de [D]cifra ChordPro...';

  @override
  String contributeEditorLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linhas',
      one: '1 linha',
    );
    return '$_temp0';
  }

  @override
  String get contributeEditorGestureEmptyDocument =>
      'Nenhum item no documento. Adicione uma linha acima.';

  @override
  String contributeEditorGestureBlocksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocos/linhas',
      one: '1 bloco/linha',
    );
    return '$_temp0';
  }

  @override
  String contributeEditorGestureInstructionLabel(String kind) {
    return 'Instrução: $kind';
  }

  @override
  String authGoogleSignInError(String error) {
    return 'Falha ao entrar: $error';
  }

  @override
  String tutorialStepCounter(int current, int total) {
    return 'Passo $current de $total';
  }

  @override
  String get tutorialDismissForever => 'Não mostrar novamente';

  @override
  String get tutorialSkip => 'Pular';

  @override
  String get tutorialPrevious => 'Voltar';

  @override
  String get tutorialNext => 'Próximo';

  @override
  String get tutorialFinish => 'Concluir';

  @override
  String get tutorialHowToUseScreen => 'Como usar esta tela';

  @override
  String get welcomeHeroTitle => 'Bem-vindo ao PLPCG!';

  @override
  String get welcomeHeroSubtitle =>
      'O hinário digital e organizador de louvores para músicos, instrumentistas e ministérios.';

  @override
  String get welcomeHeroFeatureSearch =>
      'Busca rápida por número, título, ritmo e tags.';

  @override
  String get welcomeHeroFeaturePlaylists =>
      'Criação de listas e repertórios para o culto.';

  @override
  String get welcomeHeroFeatureReader =>
      'Leitor de partituras e cifras com pedais Bluetooth.';

  @override
  String get welcomeHeroPrompt =>
      'Deseja fazer um tour rápido de 1 minuto para conhecer as principais funcionalidades?';

  @override
  String get welcomeHeroStartTour => 'Fazer Tour Rápido (1 min)';

  @override
  String get welcomeHeroDismiss => 'Explorar por Conta Própria';

  @override
  String get authSigningIn => 'Entrando…';

  @override
  String get aboutWhoWeAreTitle => 'Quem somos';

  @override
  String get aboutWhoWeAreBody =>
      'A Paz do Senhor Jesus. Somos irmãos da Igreja Cristã Maranata da Região do Triângulo Mineiro e servimos no Maanaim de Uberlândia-MG. Esta aplicação não é oficial da ICM, mas o objetivo é ajudar a todos que estão no louvor ajudando na Obra. Seguindo as orientações da Igreja. De forma 100% gratuita.';

  @override
  String get aboutObjectiveTitle => 'Objetivo';

  @override
  String get aboutObjectiveParagraph1 =>
      'O objetivo da aplicação - chamada Pesquisador de Louvores em Partitura, Cifra em Geral - é ajudar aos irmãos da equipe de louvor com os materiais mais básicos pro louvor. Que seja fácil de pesquisar, consumir e que funcione offline, pois muita igrejas não tem internet ou é muito difícil o acesso em ESFs.';

  @override
  String get aboutObjectiveParagraph2 =>
      'Portanto, estejamos em oração por todos os irmãos que estão envolvidos nesse projeto. Quer seja diretamente no desenvolvimento da aplicação, quer seja na produção dos materiais, no uso/teste da aplicação e afins.';

  @override
  String get tutorialAboutStep1Title => 'Quem Somos';

  @override
  String get tutorialAboutStep1Message =>
      'Conheça a história e a equipe por trás da aplicação. Uma iniciativa **100% gratuita** e colaborativa desenvolvida para auxiliar equipes de louvor.';

  @override
  String get tutorialAboutStep2Title => 'Nosso Objetivo';

  @override
  String get tutorialAboutStep2Message =>
      'O propósito central é facilitar o acesso a **partituras, cifras, gestos e áudios**, com funcionamento **offline** garantido mesmo em locais sem internet.';

  @override
  String get tutorialAboutStep3Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialAboutStep3Message =>
      'Toque no **ícone (i)** sempre que quiser rever este guia ou conferir instruções detalhadas em qualquer tela do aplicativo!';

  @override
  String get tutorialAppShortcutsStep1Title => 'Categorias de Atalhos';

  @override
  String get tutorialAppShortcutsStep1Message =>
      'Navegue entre as abas para explorar comandos agrupados por contexto: **Navegação & Busca**, **Repertório & Áudio**, **Partituras** e **Cifras & Gestos**.';

  @override
  String get tutorialAppShortcutsStep2Title => 'Comandos de Alta Produtividade';

  @override
  String get tutorialAppShortcutsStep2Message =>
      'Consulte as teclas de atalho e suas ações correspondentes. Os selos laterais destacam os **contextos e leitores em que cada comando atua**.';

  @override
  String get tutorialAppShortcutsStep3Title => 'Acesso Rápido com a Tecla ?';

  @override
  String get tutorialAppShortcutsStep3Message =>
      'Pressione **?** (ou **Shift + /**) em qualquer tela do app para abrir esta **central de atalhos instantaneamente** no Desktop e Web.';

  @override
  String get tutorialAppShortcutsStep4Title => 'Ajuda da Central de Atalhos';

  @override
  String get tutorialAppShortcutsStep4Message =>
      'Toque neste ícone para rever as instruções sobre os **comandos e atalhos rápidos** do PLPCG.';

  @override
  String get tutorialAudioStep1Title => 'Informações da Faixa';

  @override
  String get tutorialAudioStep1Message =>
      'Visualize o **título**, **número**, **autor** e a **classificação** do louvor ou áudio em reprodução.';

  @override
  String get tutorialAudioStep2Title => 'Ações e Sincronização';

  @override
  String get tutorialAudioStep2Message =>
      'Acesse a **partitura vinculada**, adicione **marcadores de áudio**, ative o modo **seguir o áudio** no leitor e ajuste a **velocidade de reprodução**.';

  @override
  String get tutorialAudioStep3Title => 'Barra de Progresso';

  @override
  String get tutorialAudioStep3Message =>
      'Acompanhe o **tempo atual**, a **duração total** e arraste a barra para avançar ou retroceder. Os **marcadores** cadastrados aparecem destacados na linha do tempo.';

  @override
  String get tutorialAudioStep4Title => 'Controles de Reprodução';

  @override
  String get tutorialAudioStep4Message =>
      'Controle o áudio com **Play/Pause**, pule para a **faixa anterior ou seguinte** e avance ou retroceder rapidamente em **10 segundos**.';

  @override
  String get tutorialAudioStep5Title => 'Marcadores de Estudo';

  @override
  String get tutorialAudioStep5Message =>
      'Veja todos os **marcadores com marcação de tempo** adicionados à faixa. Toque em qualquer marcador para ir direto àquele ponto do ensaio.';

  @override
  String get tutorialAudioStep6Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialAudioStep6Message =>
      'Sempre que tiver dúvidas sobre o reprodutor de áudio, toque neste **ícone (i)** para rever este tutorial passo a passo!';

  @override
  String get tutorialCarouselSelectionStep1Title => 'Reordenar Repertório';

  @override
  String get tutorialCarouselSelectionStep1Message =>
      'Segure e arraste o ícone de **alça de ordenação** para mudar a sequência dos louvores em tempo real durante o culto ou ensaio.';

  @override
  String get tutorialCarouselSelectionStep2Title => 'Navegação Rápida';

  @override
  String get tutorialCarouselSelectionStep2Message =>
      'Toque no **corpo do louvor** para saltar imediatamente para ele no leitor de partituras ou cifras ativo.';

  @override
  String get tutorialCarouselSelectionStep3Title => 'Remover da Seleção';

  @override
  String get tutorialCarouselSelectionStep3Message =>
      'Toque no botão **×** para retirar o louvor da lista temporária de culto sem apagar suas playlists salvas.';

  @override
  String get tutorialCarouselSelectionStep4Title => 'Limpar ou Reiniciar Lista';

  @override
  String get tutorialCarouselSelectionStep4Message =>
      'Use esta ação para **limpar a lista ativa** e iniciar uma nova seleção do zero ou descartar o rascunho atual.';

  @override
  String get tutorialCarouselSelectionStep5Title => 'Ajuda da Lista Ativa';

  @override
  String get tutorialCarouselSelectionStep5Message =>
      'Consulte este **guia rápido** sempre que tiver dúvidas sobre como reorganizar e operar seu repertório.';

  @override
  String get tutorialChordsStep1Title => 'Transposição de Tom';

  @override
  String get tutorialChordsStep1Message =>
      'Suba ou desça o tom da música em **semitons** usando os botões **+** e **-** (ou pelo teclado). Toque no número do tom para **restaurar o tom original**.';

  @override
  String get tutorialChordsStep2Title => 'Tamanho da Fonte';

  @override
  String get tutorialChordsStep2Message =>
      'Ajuste o **tamanho do texto** e das cifras para melhor leitura na sua tela através dos botões de **diminuir** e **aumentar fonte**.';

  @override
  String get tutorialChordsStep3Title => 'Rolagem Automática';

  @override
  String get tutorialChordsStep3Message =>
      'Inicie a **rolagem automática** (tecla **S**) para acompanhar a música sem usar as mãos. Ajuste a **velocidade** no ícone de velocímetro ou pelas teclas **[** e **]**.';

  @override
  String get tutorialChordsStep4Title => 'Tema e Tela Cheia';

  @override
  String get tutorialChordsStep4Message =>
      'Alterne entre o **modo claro e escuro** para melhor visibilidade no ambiente, e use **tela cheia** (tecla **F**) para focar exclusivamente na cifra.';

  @override
  String get tutorialChordsStep5Title => 'Leitura e Diagramação';

  @override
  String get tutorialChordsStep5Message =>
      'Em telas largas a **cifra** é diagramada automaticamente em **duas colunas**. Ao tocar ou rolar manualmente na tela, o autoscroll é **pausado automaticamente**.';

  @override
  String get tutorialChordsStep6Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialChordsStep6Message =>
      'Sempre que quiser rever este guia ou tirar dúvidas sobre o uso do Leitor de Cifras, toque neste **ícone (i)**!';

  @override
  String get tutorialCollaborationDialogsStep1Title => 'Folheto Ilustrado';

  @override
  String get tutorialCollaborationDialogsStep1Message =>
      'Gera e compartilha uma **imagem visual com a lista dos louvores** acompanhada do link direto para visualização.';

  @override
  String get tutorialCollaborationDialogsStep2Title => 'Link Direto';

  @override
  String get tutorialCollaborationDialogsStep2Message =>
      'Copia ou envia apenas o **link encurtado**, ideal para envio rápido em aplicativos de mensagens.';

  @override
  String get tutorialCollaborationDialogsStep3Title =>
      'Ajuda de Compartilhamento';

  @override
  String get tutorialCollaborationDialogsStep3Message =>
      'Toque neste ícone para rever as opções de **compartilhamento de repertórios**.';

  @override
  String get tutorialCollaborationDialogsStep4Title => 'Categoria da Lista';

  @override
  String get tutorialCollaborationDialogsStep4Message =>
      'Classifique o repertório como **Evangelização**, **Aprendizado**, **Medleys** ou **Culto Especial** para facilitar a busca por outros irmãos.';

  @override
  String get tutorialCollaborationDialogsStep5Title => 'Alcance do Repertório';

  @override
  String get tutorialCollaborationDialogsStep5Message =>
      'Marque como **pontual** para eventos esporádicos ou mantenha desmarcado se for uma seleção **usual para cultos regulares**.';

  @override
  String get tutorialCollaborationDialogsStep6Title =>
      'Publicação na Comunidade';

  @override
  String get tutorialCollaborationDialogsStep6Message =>
      'Toque em **Publicar** para disponibilizar a lista na aba pública. A lista poderá ser acessada e importada por toda a igreja.';

  @override
  String get tutorialCollaborationDialogsStep7Title => 'Ajuda de Publicação';

  @override
  String get tutorialCollaborationDialogsStep7Message =>
      'Toque neste ícone para rever as instruções sobre a **publicação de repertórios** na comunidade.';

  @override
  String get tutorialCollaborationDialogsStep8Title => 'Código ou Link da Sala';

  @override
  String get tutorialCollaborationDialogsStep8Message =>
      'Digite ou cole o **código de 7 caracteres** ou a **URL completa** fornecida pelo dirigente da sala ao vivo.';

  @override
  String get tutorialCollaborationDialogsStep9Title =>
      'Colar da Área de Transferência';

  @override
  String get tutorialCollaborationDialogsStep9Message =>
      'Toque em **Colar** para preencher instantaneamente com o link que você acabou de copiar no WhatsApp ou mensagem.';

  @override
  String get tutorialCollaborationDialogsStep10Title => 'Conectar à Sala';

  @override
  String get tutorialCollaborationDialogsStep10Message =>
      'Toque em **Entrar** para ingressar na transmissão e acompanhar as **mudanças de louvor em tempo real**.';

  @override
  String get tutorialCollaborationDialogsStep11Title => 'Ajuda da Sala ao Vivo';

  @override
  String get tutorialCollaborationDialogsStep11Message =>
      'Toque neste ícone para rever as instruções de **sincronização como seguidor** de uma sala ao vivo.';

  @override
  String get tutorialContributeStep1Title => 'Contexto do Envio';

  @override
  String get tutorialContributeStep1Message =>
      'Identifique se sua colaboração está **vinculada a um louvor específico** ou se é uma **sugestão geral** para o aplicativo.';

  @override
  String get tutorialContributeStep2Title => 'Descrição da Sugestão';

  @override
  String get tutorialContributeStep2Message =>
      'Descreva detalhadamente o **problema encontrado**, **correção de letra ou tom**, ou a **melhoria** que você gostaria de propor.';

  @override
  String get tutorialContributeStep3Title => 'Diagnóstico do Aparelho';

  @override
  String get tutorialContributeStep3Message =>
      'Mantenha ativado para enviar **dados técnicos anônimos** (sistema, navegador, resolução), acelerando a resolução de bugs.';

  @override
  String get tutorialContributeStep4Title => 'Anexos e Links';

  @override
  String get tutorialContributeStep4Message =>
      'Adicione **arquivos de apoio** (áudios, partituras ou capturas até 32 MB) e **links** do YouTube ou Google Drive.';

  @override
  String get tutorialContributeStep5Title => 'Envio da Contribuição';

  @override
  String get tutorialContributeStep5Message =>
      'Toque em **Enviar** para submeter seu relato. Se não estiver conectado, entre com sua **conta Google** para enviar.';

  @override
  String get tutorialContributeStep6Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialContributeStep6Message =>
      'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da tela de envio de sugestões.';

  @override
  String get tutorialContributionDetailStep1Title => 'Título e Estado do Envio';

  @override
  String get tutorialContributionDetailStep1Message =>
      'Acompanhe o **título da contribuição** e seu status atual (**Em análise**, **Aprovada** ou **Recusada**).';

  @override
  String get tutorialContributionDetailStep2Title => 'Tipo de Contribuição';

  @override
  String get tutorialContributionDetailStep2Message =>
      'Indica a categoria da colaboração enviada, como **Cifra**, **Letra**, **Partitura** ou **Correção de informações**.';

  @override
  String get tutorialContributionDetailStep3Title => 'Descrição e Observações';

  @override
  String get tutorialContributionDetailStep3Message =>
      'Aqui você confere o **texto descritivo**, justificativas e links externos adicionados na submissão da proposta.';

  @override
  String get tutorialContributionDetailStep4Title => 'Campos Alterados';

  @override
  String get tutorialContributionDetailStep4Message =>
      'Quando a contribuição propõe corrigir dados, veja a comparação direta entre o valor **atual** e o **proposto**.';

  @override
  String get tutorialContributionDetailStep5Title =>
      'Arquivos e Verificação Antivírus';

  @override
  String get tutorialContributionDetailStep5Message =>
      'Consulte a lista de **anexos enviados** e o status da verificação de segurança em tempo real (**Limpa**, **Verificando** ou **Bloqueada**).';

  @override
  String get tutorialContributionDetailStep6Title => 'Parecer da Moderação';

  @override
  String get tutorialContributionDetailStep6Message =>
      'Quando a equipe do PLPCG avaliar o envio, o **parecer e justificativa dos revisores** serão exibidos nesta área.';

  @override
  String get tutorialContributionDetailStep7Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialContributionDetailStep7Message =>
      'Sempre que tiver dúvidas sobre os detalhes da contribuição, toque neste **ícone (i)** para rever este tutorial passo a passo!';

  @override
  String get tutorialExtractedMaterialEditorStep1Title =>
      'Barra de Ferramentas & Atalhos';

  @override
  String get tutorialExtractedMaterialEditorStep1Message =>
      'Utilize os atalhos rápidos para **adicionar versos**, **remover linhas**, **inserir acordes ou anotações** e restaurar o texto original.';

  @override
  String get tutorialExtractedMaterialEditorStep2Title => 'Área de Edição';

  @override
  String get tutorialExtractedMaterialEditorStep2Message =>
      'Edite o conteúdo diretamente. Na cifra, use a sintaxe **[Acorde]** imediatamente antes da sílaba para sincronizar a posição com a letra.';

  @override
  String get tutorialExtractedMaterialEditorStep3Title =>
      'Seletor de Gestos CIAs';

  @override
  String get tutorialExtractedMaterialEditorStep3Message =>
      'Toque em **Trocar Gesto** para abrir o dicionário oficial e vincular o movimento e a frase disparadora correspondente.';

  @override
  String get tutorialExtractedMaterialEditorStep4Title =>
      'Pré-visualização ao Vivo';

  @override
  String get tutorialExtractedMaterialEditorStep4Message =>
      'Acompanhe as mudanças **em tempo real** com a renderização idêntica à que os usuários verão no leitor de louvores.';

  @override
  String get tutorialExtractedMaterialEditorStep5Title =>
      'Submissão da Proposta';

  @override
  String get tutorialExtractedMaterialEditorStep5Message =>
      'Adicione observações se desejar e toque em **Enviar** para disponibilizar sua sugestão para revisão pela comunidade.';

  @override
  String get tutorialExtractedMaterialEditorStep6Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialExtractedMaterialEditorStep6Message =>
      'Toque neste ícone a qualquer momento para rever este **guia passo a passo** do editor de materiais.';

  @override
  String get tutorialFavoriteMaterialKindsStep1Title =>
      'Prioridade de Materiais';

  @override
  String get tutorialFavoriteMaterialKindsStep1Message =>
      'Defina até **4 materiais favoritos** para priorizar seus instrumentos e vozes no topo dos resultados de busca e no leitor.';

  @override
  String get tutorialFavoriteMaterialKindsStep2Title =>
      'Seus Favoritos e Ordem';

  @override
  String get tutorialFavoriteMaterialKindsStep2Message =>
      'Acompanhe seus materiais selecionados. Arraste pela **alça lateral** para definir a prioridade, alterne o **formato preferido** ou toque no **(X)** para remover.';

  @override
  String get tutorialFavoriteMaterialKindsStep3Title =>
      'Adicionar Novos Materiais';

  @override
  String get tutorialFavoriteMaterialKindsStep3Message =>
      'Busque por instrumentos (ex: **violão**, **baixo**, **órgão**) ou vozes e toque no ícone **(+)** para adicioná-los à sua lista de prioridades.';

  @override
  String get tutorialFavoriteMaterialKindsStep4Title =>
      'Sincronização na Nuvem';

  @override
  String get tutorialFavoriteMaterialKindsStep4Message =>
      'Entre com sua **conta Google** para salvar e sincronizar suas preferências de materiais em qualquer aparelho.';

  @override
  String get tutorialFavoriteMaterialKindsStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialFavoriteMaterialKindsStep5Message =>
      'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre os recursos do aplicativo!';

  @override
  String get tutorialFiltersStep1Title => 'Filtro por Tonalidade';

  @override
  String get tutorialFiltersStep1Message =>
      'Filtre o acervo pela **tonalidade musical** (Dó, Ré, Mi...) e seus acidentes para encontrar louvores no tom exato da sua equipe.';

  @override
  String get tutorialFiltersStep2Title => 'Filtro por Ritmo';

  @override
  String get tutorialFiltersStep2Message =>
      'Selecione compassos e ritmos específicos como **Valsa**, **Marcha**, **Básico** ou **Toada** para adequar o repertório ao culto.';

  @override
  String get tutorialFiltersStep3Title => 'Categorias e Tags de Culto';

  @override
  String get tutorialFiltersStep3Message =>
      'Refine os hinos por **ocasião de culto**, como **Comunhão**, **Ceia**, **Crianças** ou momentos devocionais.';

  @override
  String get tutorialFiltersStep4Title => 'Tipos de Materiais';

  @override
  String get tutorialFiltersStep4Message =>
      'Restrinja os resultados para exibir apenas louvores que possuam **Cifras**, **Partituras**, **Gestos CIAs** ou **Áudios** disponíveis.';

  @override
  String get tutorialFiltersStep5Title => 'Limpar Filtros';

  @override
  String get tutorialFiltersStep5Message =>
      'Toque em **Limpar** para redefinir instantaneamente todos os filtros aplicados e visualizar o acervo completo.';

  @override
  String get tutorialFiltersStep6Title => 'Ajuda de Filtros';

  @override
  String get tutorialFiltersStep6Message =>
      'Toque neste ícone sempre que desejar rever as orientações sobre como **combinar filtros avançados**.';

  @override
  String get tutorialGestureFocusStep1Title => 'Cartão do Gesto em Destaque';

  @override
  String get tutorialGestureFocusStep1Message =>
      'Visualize o movimento do gesto em **tamanho ampliado**, com animação ou ilustração para fácil acompanhamento pelo regente.';

  @override
  String get tutorialGestureFocusStep2Title => 'Frase & Letra Disparadora';

  @override
  String get tutorialGestureFocusStep2Message =>
      'Acompanhe a letra associada, com destaque em **vermelho no gatilho** em que o gesto deve ser executado pelo grupo de louvor.';

  @override
  String get tutorialGestureFocusStep3Title => 'Navegação entre Gestos';

  @override
  String get tutorialGestureFocusStep3Message =>
      'Toque nas **laterais da tela**, **arraste para os lados** ou use as **setas do teclado (← e →)** para avançar ou retroceder os passos.';

  @override
  String get tutorialGestureFocusStep4Title => 'Próximo Gatilho';

  @override
  String get tutorialGestureFocusStep4Message =>
      'Consulte no rodapé a **palavra ou frase do próximo gesto**, preparando a transição antes que ela aconteça.';

  @override
  String get tutorialGestureFocusStep5Title => 'Ajuda do Modo Foco';

  @override
  String get tutorialGestureFocusStep5Message =>
      'Toque neste ícone para rever este **guia passo a passo** ou pressione **Esc** para fechar e retornar ao leitor a qualquer momento.';

  @override
  String get tutorialGesturesStep1Title => 'Tamanho da Letra';

  @override
  String get tutorialGesturesStep1Message =>
      'Aumente ou diminua o **tamanho do texto** dos louvores para uma leitura mais confortável durante o ensaio ou culto.';

  @override
  String get tutorialGesturesStep2Title => 'Rolagem Automática';

  @override
  String get tutorialGesturesStep2Message =>
      'Ative a **rolagem automática** (tecla **S**) para acompanhar os gestos sem tocar na tela. Ajuste a **velocidade** no velocímetro ou pelas teclas **[** e **]**.';

  @override
  String get tutorialGesturesStep3Title => 'Modo Linear vs. Estruturado';

  @override
  String get tutorialGesturesStep3Message =>
      'Alterne entre a exibição **estruturada** (agrupada por estrofes e refrões) e a leitura **linear** (sequência contínua com todas as repetições completas).';

  @override
  String get tutorialGesturesStep4Title => 'Tema e Tela Cheia';

  @override
  String get tutorialGesturesStep4Message =>
      'Alterne entre o **modo claro e escuro** para melhor visibilidade, e use o modo **tela cheia** (tecla **F**) para ocultar barras e focar na execução dos gestos.';

  @override
  String get tutorialGesturesStep5Title => 'Cartões de Gestos';

  @override
  String get tutorialGesturesStep5Message =>
      'Os gestos aparecem sincronizados com as palavras correspondentes. Toque em qualquer **cartão de gesto** para abrir a **visão em foco** com imagem ampliada e descrição detalhada.';

  @override
  String get tutorialGesturesStep6Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialGesturesStep6Message =>
      'Sempre que tiver dúvidas sobre como usar o leitor de gestos, toque neste **ícone (i)** para rever este tutorial passo a passo!';

  @override
  String get tutorialHomeStep1Title => 'Pesquisa Inteligente';

  @override
  String get tutorialHomeStep1Message =>
      'Digite o **número** do louvor, o **título** ou um **trecho da letra** para localizá-lo instantaneamente no catálogo.';

  @override
  String get tutorialHomeStep2Title => 'Filtros Ativos';

  @override
  String get tutorialHomeStep2Message =>
      'Quando **ativo**, o botão do filtro selecionado ganha **destaque dourado**. O cabeçalho exibe a contagem de **filtros ativos** e você pode tocar em **\"Limpar filtros\"** para desmarcar tudo.';

  @override
  String get tutorialHomeStep3Title => 'Filtros Inativos';

  @override
  String get tutorialHomeStep3Message =>
      'Com os filtros **inativos** (desmarcados), a busca abrange **todo o catálogo**. Toque em qualquer botão para **ativá-lo** ou recolha o painel para ganhar espaço.';

  @override
  String get tutorialHomeStep4Title => 'Navegação Principal';

  @override
  String get tutorialHomeStep4Message =>
      'Alterne facilmente entre o **Pesquisador** de Louvores, suas **Listas** salvas e o seu **Perfil** de usuário.';

  @override
  String get tutorialHomeStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialHomeStep5Message =>
      'Sempre que tiver dúvidas sobre como usar qualquer tela, toque neste **ícone (i)** para rever as explicações passo a passo!';

  @override
  String get tutorialLibraryStep1Title => 'Filtros do Catálogo';

  @override
  String get tutorialLibraryStep1Message =>
      'Refine a biblioteca completa por **tom musical**, **ritmo**, **categorias/tags** ou **tipo de material** (partituras, cifras, áudio). Toque no cabeçalho para **expandir ou recolher** os filtros.';

  @override
  String get tutorialLibraryStep2Title => 'Ordenação do Acervo';

  @override
  String get tutorialLibraryStep2Message =>
      'Alterne rapidamente a ordem dos louvores entre **\"Por número\"** (código oficial no hinário) ou **\"Por nome\"** (ordem alfabética dos títulos).';

  @override
  String get tutorialLibraryStep3Title => 'Paginação e Exibição';

  @override
  String get tutorialLibraryStep3Message =>
      'Consulte o **total de louvores** encontrados, selecione a **quantidade de itens por página** (10, 20, 50...) e use as **setas de navegação** para folhear o catálogo.';

  @override
  String get tutorialLibraryStep4Title => 'Cards de Louvor';

  @override
  String get tutorialLibraryStep4Message =>
      'Cada card apresenta o número, título e detalhes do louvor. Toque nele para acessar diretamente suas **partituras**, **cifras**, **áudios** e **informações completas**.';

  @override
  String get tutorialLibraryStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialLibraryStep5Message =>
      'Sempre que tiver dúvidas sobre como navegar ou usar a Biblioteca, toque neste **ícone (i)** para rever este guia passo a passo!';

  @override
  String get tutorialLiveRoomStep1Title => 'Código e QR Code da Sala';

  @override
  String get tutorialLiveRoomStep1Message =>
      'Os participantes podem ler este **código QR** com a câmera do celular ou acessar o **link direto** para acompanhar o culto.';

  @override
  String get tutorialLiveRoomStep2Title => 'Compartilhar e Gerenciar';

  @override
  String get tutorialLiveRoomStep2Message =>
      'Copie ou **compartilhe o link** da transmissão com o grupo ou toque em **gerar novo link** caso precise redefinir o acesso.';

  @override
  String get tutorialLiveRoomStep3Title => 'Participantes Conectados';

  @override
  String get tutorialLiveRoomStep3Message =>
      'Acompanhe em tempo real o **número de irmãos** que estão sintonizados e seguindo as cifras e letras na sua sala.';

  @override
  String get tutorialLiveRoomStep4Title => 'Finalizar Transmissão';

  @override
  String get tutorialLiveRoomStep4Message =>
      'Toque em **Encerrar** para concluir a sessão ao vivo com os participantes e retornar para as suas listas.';

  @override
  String get tutorialLiveRoomStep5Title => 'Status da Transmissão';

  @override
  String get tutorialLiveRoomStep5Message =>
      'Acompanhe o andamento da sessão: veja se o líder está **ao vivo**, aguardando o culto ou se a conexão está **sincronizando**.';

  @override
  String get tutorialLiveRoomStep6Title => 'Guardar Cópia';

  @override
  String get tutorialLiveRoomStep6Message =>
      'Ao fim do culto, toque em **Guardar cópia** para salvar a lista de louvores executada diretamente nas suas listas pessoais.';

  @override
  String get tutorialLiveRoomStep7Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialLiveRoomStep7Message =>
      'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da sala ao vivo.';

  @override
  String get tutorialLyricsStep1Title => 'Tamanho da Letra';

  @override
  String get tutorialLyricsStep1Message =>
      'Aumente ou diminua o **tamanho da fonte** da letra para uma leitura mais confortável durante o ensaio ou culto. Também é possível usar **Ctrl + ↑ / ↓** (ou **Cmd + ↑ / ↓**).';

  @override
  String get tutorialLyricsStep2Title => 'Rolagem Automática';

  @override
  String get tutorialLyricsStep2Message =>
      'Ative a **rolagem automática** (tecla **S**) para ler a letra sem tocar na tela. Toque no **velocímetro** para ajustar a velocidade (ou pelas teclas **[** e **]**).';

  @override
  String get tutorialLyricsStep3Title => 'Modo Tela Cheia';

  @override
  String get tutorialLyricsStep3Message =>
      'Toque no botão de **tela cheia** (ou tecla **F**) para ocultar todas as barras e focar inteiramente na leitura da letra.';

  @override
  String get tutorialLyricsStep4Title => 'Leitura e Seleção de Texto';

  @override
  String get tutorialLyricsStep4Message =>
      'A letra do louvor fica disponível **completamente offline**. O texto é selecionável para copiar trechos e a rolagem é pausada suavemente ao tocar na tela.';

  @override
  String get tutorialLyricsStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialLyricsStep5Message =>
      'Sempre que tiver dúvidas sobre como usar o leitor de letras, toque neste **ícone (i)** para rever este tutorial passo a passo!';

  @override
  String get tutorialMaterialSheetStep1Title => 'Formatos Disponíveis';

  @override
  String get tutorialMaterialSheetStep1Message =>
      'Alterne entre **Partituras**, **Cifras**, **Gestos CIAs**, **Áudios** e vídeos do **YouTube** para escolher o formato ideal para o culto ou ensaio.';

  @override
  String get tutorialMaterialSheetStep2Title => 'Adicionar ao Repertório';

  @override
  String get tutorialMaterialSheetStep2Message =>
      'Toque no botão **+** para incluir este arranjo diretamente na sua lista ativa do **Carrossel de culto** ou em uma de suas **Playlists**.';

  @override
  String get tutorialMaterialSheetStep3Title => 'Metadados e Letra';

  @override
  String get tutorialMaterialSheetStep3Message =>
      'Consulte a **tonalidade original**, **ritmo**, **categorias de culto** e confira a prévia da letra do louvor.';

  @override
  String get tutorialMaterialSheetStep4Title => 'Versões Relacionadas';

  @override
  String get tutorialMaterialSheetStep4Message =>
      'Selecione rapidamente **arranjos alternativos**, versões com outras tonalidades ou hinos correlacionados ao louvor selecionado.';

  @override
  String get tutorialMaterialSheetStep5Title => 'Sugerir Melhoria';

  @override
  String get tutorialMaterialSheetStep5Message =>
      'Encontrou alguma divergência na cifra, letra ou partitura? Toque aqui para enviar uma **sugestão de correção** aos curadores.';

  @override
  String get tutorialMaterialSheetStep6Title => 'Ajuda deste Seletor';

  @override
  String get tutorialMaterialSheetStep6Message =>
      'Toque neste ícone sempre que precisar de orientação sobre como **escolher materiais** e **organizar o repertório**.';

  @override
  String get tutorialMyContributionsStep1Title => 'Identificação Necessária';

  @override
  String get tutorialMyContributionsStep1Message =>
      'Faça login com sua **conta Google** para acessar o histórico de sugestões, correções e materiais que você enviou.';

  @override
  String get tutorialMyContributionsStep2Title => 'Nenhum Envio Ainda';

  @override
  String get tutorialMyContributionsStep2Message =>
      'Todas as **sugestões de letras, partituras ou correções** enviadas por você através do botão **Contribuir** aparecerão listadas nesta tela.';

  @override
  String get tutorialMyContributionsStep3Title => 'Histórico de Envios';

  @override
  String get tutorialMyContributionsStep3Message =>
      'Visualize o título, tipo de material e data da sua colaboração. Toque em qualquer linha para abrir a **tela de detalhes** e ver anotações da equipe.';

  @override
  String get tutorialMyContributionsStep4Title => 'Status da Análise';

  @override
  String get tutorialMyContributionsStep4Message =>
      'Acompanhe o andamento da sua solicitação: **pendente**, **em análise**, **aprovada** ou **rejeitada**.';

  @override
  String get tutorialMyContributionsStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialMyContributionsStep5Message =>
      'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre as telas do aplicativo!';

  @override
  String get tutorialOfflineStep1Title => 'Status e Uso de Disco';

  @override
  String get tutorialOfflineStep1Message =>
      'Acompanhe o total de louvores no **catálogo local**, a data da **última sincronização** e o **espaço ocupado e livre** no aparelho. Toque em **Atualizar** para recalcular os dados.';

  @override
  String get tutorialOfflineStep2Title => 'Pesquisa de Materiais';

  @override
  String get tutorialOfflineStep2Message =>
      'Use o campo de busca para encontrar rapidamente tipos específicos de partituras ou cifras (ex: **violão**, **coletânea**, **coral**) e ative **Filtrar** para exibir apenas os resultados correspondentes.';

  @override
  String get tutorialOfflineStep3Title => 'Seleção de Formatos';

  @override
  String get tutorialOfflineStep3Message =>
      'Selecione os **tipos de materiais** que você deseja manter disponíveis offline. Em cada item é possível alternar individualmente entre **partitura (PDF)**, **cifra** e **áudio**.';

  @override
  String get tutorialOfflineStep4Title => 'Baixar e Gerenciar Espaço';

  @override
  String get tutorialOfflineStep4Message =>
      'Toque em **Baixar selecionados** para salvar os arquivos no aparelho para uso sem internet. Quando precisar liberar espaço em disco, toque em **Remover downloads**.';

  @override
  String get tutorialOfflineStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialOfflineStep5Message =>
      'Sempre que tiver dúvidas sobre o armazenamento offline, toque neste **ícone (i)** para rever este tutorial passo a passo!';

  @override
  String get tutorialPlaylistsStep1Title => 'Abas de Repertório';

  @override
  String get tutorialPlaylistsStep1Message =>
      'Alterne entre suas listas **Não Salvas** (seleções rápidas de ensaio), listas **Salvas** (repertórios guardados e sincronizados) e **Favoritas** (para acesso rápido).';

  @override
  String get tutorialPlaylistsStep2Title => 'Importar Lista';

  @override
  String get tutorialPlaylistsStep2Message =>
      'Recebeu uma lista compartilhada? Toque em **Importar lista** e cole o link ou código recebido para carregar os louvores no seu aplicativo.';

  @override
  String get tutorialPlaylistsStep3Title => 'Sala ao Vivo';

  @override
  String get tutorialPlaylistsStep3Message =>
      'Abra uma sala ou conecte-se ao ensaio da igreja. Todos os músicos acompanham a **troca de louvores em tempo real** durante a ministração.';

  @override
  String get tutorialPlaylistsStep4Title => 'Criar Novas Listas';

  @override
  String get tutorialPlaylistsStep4Message =>
      'Para montar uma nova lista, vá ao **Pesquisador** e toque no botão **\"+\"** de qualquer louvor ou versão de partitura.';

  @override
  String get tutorialPlaylistsStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialPlaylistsStep5Message =>
      'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar qualquer tela do aplicativo!';

  @override
  String get tutorialPraiseStep1Title => 'Informações do Louvor';

  @override
  String get tutorialPraiseStep1Message =>
      'Veja o **número** e o **título** do louvor. Toque em **Compartilhar** para copiar o link direto ou em **Sugerir melhoria** para nos enviar correções.';

  @override
  String get tutorialPraiseStep2Title => 'Versões Relacionadas';

  @override
  String get tutorialPraiseStep2Message =>
      'Quando houver diferentes **arranjos, tonalidades ou variantes**, você pode alternar facilmente entre elas tocando nos botões de louvores relacionados.';

  @override
  String get tutorialPraiseStep3Title => 'Materiais e Partituras';

  @override
  String get tutorialPraiseStep3Message =>
      'Acesse todas as **partituras**, **cifras**, **gestos** e **áudios** disponíveis para este louvor. Toque em um item para abrir ou no **+** para adicioná-lo à sua lista ativa.';

  @override
  String get tutorialPraiseStep4Title => 'Letra e Metadados';

  @override
  String get tutorialPraiseStep4Message =>
      'Consulte a **letra completa** do louvor, ajuste o tamanho da fonte, copie o texto ou toque no botão de reprodução para abrir no **leitor dedicado** com rolagem automática.';

  @override
  String get tutorialPraiseStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialPraiseStep5Message =>
      'Sempre que tiver dúvidas sobre os detalhes do louvor, toque neste **ícone (i)** para rever este tutorial passo a passo!';

  @override
  String get tutorialProfileStep1Title => 'Conta & Sincronização';

  @override
  String get tutorialProfileStep1Message =>
      'Conecte sua conta **Google** para sincronizar suas **listas de louvores**, preferências e materiais favoritos automaticamente entre seus aparelhos.';

  @override
  String get tutorialProfileStep2Title => 'Biblioteca Completa';

  @override
  String get tutorialProfileStep2Message =>
      'Acesse a **Biblioteca** para explorar o catálogo completo em formato de **lista paginada**, com filtros detalhados de instrumentos e categorias.';

  @override
  String get tutorialProfileStep3Title => 'Contribuir';

  @override
  String get tutorialProfileStep3Message =>
      'Envie **novas partituras**, cifras, gestos ou correções de letras. A colaboração da irmandade mantém o acervo sempre atualizado e preciso!';

  @override
  String get tutorialProfileStep4Title => 'Modo Offline';

  @override
  String get tutorialProfileStep4Message =>
      'Baixe os arquivos de partituras e letras para usar o aplicativo **sem internet** durante cultos e ensaios com total rapidez.';

  @override
  String get tutorialProfileStep5Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialProfileStep5Message =>
      'Toque no ícone **(i)** sempre que quiser rever as instruções e dicas desta tela!';

  @override
  String get tutorialPublicPlaylistsStep1Title => 'Seu Nome de Usuário';

  @override
  String get tutorialPublicPlaylistsStep1Message =>
      'Faça login com sua conta Google e crie seu **@usuário** para compartilhar suas próprias listas públicas com a igreja.';

  @override
  String get tutorialPublicPlaylistsStep2Title => 'Buscar Irmãos e Equipes';

  @override
  String get tutorialPublicPlaylistsStep2Message =>
      'Digite o **@usuário** de outros membros da equipe para localizar suas listas públicas e repertórios compartilhados.';

  @override
  String get tutorialPublicPlaylistsStep3Title => 'Listas e Importação';

  @override
  String get tutorialPublicPlaylistsStep3Message =>
      'Nos resultados, visualize as listas publicadas e toque em **importar** para adicionar os louvores à sua lista ativa.';

  @override
  String get tutorialPublicPlaylistsStep4Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialPublicPlaylistsStep4Message =>
      'Toque no **ícone (i)** a qualquer momento para rever este guia passo a passo!';

  @override
  String get tutorialReaderStep1Title => 'Ajuste de Tela';

  @override
  String get tutorialReaderStep1Message =>
      'Alterne entre ajustar à **largura da tela** (ótimo para ampliar a partitura) ou à **página inteira**. Você também pode pressionar a tecla **Z**.';

  @override
  String get tutorialReaderStep2Title => 'Modo Tela Cheia';

  @override
  String get tutorialReaderStep2Message =>
      'Toque para ocultar todas as barras e **focar na partitura** durante o ensaio ou culto. Use a tecla **F** para entrar ou **Esc** para sair.';

  @override
  String get tutorialReaderStep3Title => 'Indicador de Páginas';

  @override
  String get tutorialReaderStep3Message =>
      'Exibe a **página atual** e o **total de páginas**. Toque para saltar de página ou **segure o toque** para voltar direto à **primeira página**!';

  @override
  String get tutorialReaderStep4Title => 'Toque nas Bordas (Laterais)';

  @override
  String get tutorialReaderStep4Message =>
      'Toque no **quinto lateral esquerdo** para voltar e no **quinto lateral direito** para avançar páginas instantaneamente, sem precisar arrastar a partitura.';

  @override
  String get tutorialReaderStep5Title => 'Pedais Bluetooth & Teclado';

  @override
  String get tutorialReaderStep5Message =>
      'Conecte qualquer **pedal virador de página Bluetooth** (AirTurn, PageFlip, Donner via PageUp/Down ou Setas) para avançar e trocar de louvor **sem tirar as mãos do instrumento**.';

  @override
  String get tutorialReaderStep6Title => 'Ajuda & Tutoriais';

  @override
  String get tutorialReaderStep6Message =>
      'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar as ferramentas do leitor!';

  @override
  String get tutorialWelcomeTourStep1Title => '1. Pesquise no Hinário';

  @override
  String get tutorialWelcomeTourStep1Message =>
      'Digite o **número**, o **título** ou qualquer **trecho da letra** para localizar instantaneamente hinos e cânticos no acervo.';

  @override
  String get tutorialWelcomeTourStep2Title => '2. Formatos Especializados';

  @override
  String get tutorialWelcomeTourStep2Message =>
      'Toque no louvor para selecionar entre **Partitura**, **Cifra**, **Gestos para Crianças** ou **Letra**, com transposição de tom e autoscroll.';

  @override
  String get tutorialWelcomeTourStep3Title =>
      '3. Monte seu Repertório de Culto';

  @override
  String get tutorialWelcomeTourStep3Message =>
      'Toque no botão **(+)** para incluir louvores no **Carrossel Ativo**, permitindo alternar rapidamente entre partituras durante a ministração.';

  @override
  String get tutorialWelcomeTourStep4Title => '4. Repertório Sempre com Você';

  @override
  String get tutorialWelcomeTourStep4Message =>
      'Acesse a aba **Listas** para organizar playlists de ensaio e abra o **Armazenamento Offline** no Perfil para louvar **sem internet** em qualquer lugar!';

  @override
  String get privacyPolicyTitle => 'Política de Privacidade';

  @override
  String get privacyPolicyAboutDescription =>
      'Saiba como protegemos seus dados e sua privacidade.';

  @override
  String get profileDeleteAccount => 'Excluir conta';

  @override
  String get profileDeleteAccountDialogTitle => 'Excluir conta e dados?';

  @override
  String get profileDeleteAccountDialogContent =>
      'Esta ação é irreversível. Sua conta, playlists sincronizadas, marcações e preferências serão permanentemente excluídas dos servidores do PLPCG.';

  @override
  String get profileDeleteAccountConfirm => 'Excluir definitivamente';

  @override
  String get profileDeleteAccountSuccess =>
      'Sua conta e todos os dados foram excluídos com sucesso.';

  @override
  String get profileDeleteAccountError =>
      'Não foi possível excluir sua conta. Verifique sua conexão e tente novamente.';
}
