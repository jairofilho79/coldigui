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
  String get specialArrangementPadrao => 'Padrão';

  @override
  String get filtersSpecialArrangementTitle => 'Arranjo especial';

  @override
  String get catalogRefreshAction => 'Atualizar lista';

  @override
  String get catalogRefreshLabel => 'Catálogo';

  @override
  String get catalogRefreshMessage =>
      'Baixar a versão mais recente do catálogo';

  @override
  String get catalogRefreshSuccess => 'Catálogo atualizado';

  @override
  String get catalogRefreshError => 'Não foi possível atualizar o catálogo';

  @override
  String get catalogStaleBanner =>
      'Catálogo atualizado há mais de 7 dias. Conecte-se para atualizar.';

  @override
  String get catalogLoadError => 'Não foi possível carregar o catálogo';

  @override
  String libraryResultsSummary(int from, int to, int total) {
    return 'Mostrando $from–$to de $total louvores';
  }

  @override
  String get libraryResultsEmpty =>
      'Nenhum louvor encontrado com os filtros atuais';

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
  String get offlineDownloadError =>
      'Não foi possível concluir o download offline';

  @override
  String get offlineDownloadTimeout =>
      'Conexão lenta. Toque em Retomar quando a rede melhorar.';

  @override
  String get offlineDownloadNetworkError =>
      'Sem conexão. Verifique a internet e retome.';

  @override
  String get offlineKeepAppOpenDuringDownload =>
      'Mantenha o app aberto durante o download.';

  @override
  String get offlineInsufficientDiskSpace =>
      'Espaço em disco insuficiente para o download';

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
  String get carouselRemoveTooltip => 'Remover';

  @override
  String get carouselAddTooltip => 'Adicionar à seleção';

  @override
  String get carouselSavePlaylist => 'Salvar como lista';

  @override
  String get carouselSharePlaylist => 'Compartilhar';

  @override
  String get carouselGenerateLeaflet => 'Gerar folheto';

  @override
  String get carouselOverflowMenu => 'Mais ações';

  @override
  String get carouselOpenList => 'Ver seleção';

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
  String get playlistDeleteConfirmTitle => 'Excluir lista?';

  @override
  String get playlistDeleteConfirmMessage =>
      'Esta lista será removida permanentemente.';

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
  String get playlistDeleteLastPdfTitle => 'Remover último louvor?';

  @override
  String get playlistDeleteLastPdfMessage =>
      'A lista ficará vazia e será excluída.';

  @override
  String get playlistLoadIntoCarousel => 'Carregar no carousel';

  @override
  String get playlistOpenInReader => 'Abrir no leitor';

  @override
  String get playlistLoadConfirmTitle => 'Substituir seleção?';

  @override
  String get playlistLoadConfirmMessage =>
      'A seleção atual será substituída pelos louvores desta lista.';

  @override
  String get playlistLoaded => 'Lista carregada no carousel';

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
  String get playlistImported => 'Lista importada';

  @override
  String get playlistImportInvalidUrl =>
      'Link inválido. Use uma URL com sharepdfs e sharename.';

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
  String get playlistClearSavedBlocked =>
      'Listas salvas não podem ser limpas pela barra. Use o menu da lista.';

  @override
  String get playlistOpenLouvorChoiceTitle => 'Como adicionar à lista?';

  @override
  String get playlistOpenLouvorChoiceMessage =>
      'Este louvor não está na lista atual. Como deseja continuar?\n\nAo criar uma nova lista, a lista atual não será perdida — ela permanecerá em Listas não salvas.';

  @override
  String get playlistOpenLouvorChoiceAddToCurrent => 'Adicionar à lista atual';

  @override
  String get playlistOpenLouvorChoiceCreateNew => 'Criar nova lista';

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
}
