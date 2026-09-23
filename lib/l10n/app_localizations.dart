import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt, this message translates to:
  /// **'PLPCG'**
  String get appTitle;

  /// Título da aba do navegador no leitor/cifra com número (C14)
  ///
  /// In pt, this message translates to:
  /// **'{numero} — {nome} · PLPCG'**
  String browserTitleLouvor(String numero, String nome);

  /// Título da aba do navegador no leitor/cifra sem número (C14)
  ///
  /// In pt, this message translates to:
  /// **'{nome} · PLPCG'**
  String browserTitleLouvorSemNumero(String nome);

  /// Título da aba do navegador fora do leitor/cifra/áudio (C14)
  ///
  /// In pt, this message translates to:
  /// **'{label} · PLPCG'**
  String browserTitleTab(String label);

  /// No description provided for @searchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar por número ou título'**
  String get searchHint;

  /// No description provided for @searchLabel.
  ///
  /// In pt, this message translates to:
  /// **'Buscar'**
  String get searchLabel;

  /// Tooltip do botão X dentro do SearchBar (UC-01 Home)
  ///
  /// In pt, this message translates to:
  /// **'Limpar busca'**
  String get searchClear;

  /// No description provided for @searchFreshnessChecking.
  ///
  /// In pt, this message translates to:
  /// **'Em cache · a verificar…'**
  String get searchFreshnessChecking;

  /// No description provided for @searchFreshnessUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado'**
  String get searchFreshnessUpdated;

  /// No description provided for @searchFreshnessUpdatedNew.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{Atualizado · 1 novo} other{Atualizado · {count} novos}}'**
  String searchFreshnessUpdatedNew(int count);

  /// No description provided for @searchFreshnessOffline.
  ///
  /// In pt, this message translates to:
  /// **'Em cache · sem ligação'**
  String get searchFreshnessOffline;

  /// No description provided for @searchFreshnessFailed.
  ///
  /// In pt, this message translates to:
  /// **'Em cache · não foi possível verificar'**
  String get searchFreshnessFailed;

  /// No description provided for @searchResultNew.
  ///
  /// In pt, this message translates to:
  /// **'novo'**
  String get searchResultNew;

  /// No description provided for @filtersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Filtros'**
  String get filtersTitle;

  /// No description provided for @filtersTapToExpand.
  ///
  /// In pt, this message translates to:
  /// **'Toque para ver mais'**
  String get filtersTapToExpand;

  /// Cabeçalho do painel de filtros com filtros ativos (gravados ou da URL) — {count} valores escolhidos
  ///
  /// In pt, this message translates to:
  /// **'Filtros ({count})'**
  String filtersActiveCount(int count);

  /// No description provided for @sharePdf.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get sharePdf;

  /// No description provided for @savePdf.
  ///
  /// In pt, this message translates to:
  /// **'Baixar'**
  String get savePdf;

  /// No description provided for @pdfShareSuccess.
  ///
  /// In pt, this message translates to:
  /// **'PDF pronto para compartilhar'**
  String get pdfShareSuccess;

  /// No description provided for @pdfSaveSuccess.
  ///
  /// In pt, this message translates to:
  /// **'PDF salvo com sucesso'**
  String get pdfSaveSuccess;

  /// No description provided for @pdfActionError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir a ação'**
  String get pdfActionError;

  /// No description provided for @readerFullscreenTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Tela cheia (F)'**
  String get readerFullscreenTooltip;

  /// No description provided for @readerExitFullscreenTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Sair da tela cheia (Esc)'**
  String get readerExitFullscreenTooltip;

  /// No description provided for @readerFitModeTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Ajustar largura/página (Z)'**
  String get readerFitModeTooltip;

  /// No description provided for @readerGoToPageTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ir para página'**
  String get readerGoToPageTitle;

  /// No description provided for @readerGoToPageFieldLabel.
  ///
  /// In pt, this message translates to:
  /// **'Número da página'**
  String get readerGoToPageFieldLabel;

  /// No description provided for @readerGoToPageCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get readerGoToPageCancel;

  /// No description provided for @readerGoToPageConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Ir'**
  String get readerGoToPageConfirm;

  /// No description provided for @louvorPdfDownloading.
  ///
  /// In pt, this message translates to:
  /// **'Baixando...'**
  String get louvorPdfDownloading;

  /// No description provided for @louvorPdfDownloadingWithProgress.
  ///
  /// In pt, this message translates to:
  /// **'Baixando... {percent}%'**
  String louvorPdfDownloadingWithProgress(int percent);

  /// No description provided for @libraryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Biblioteca'**
  String get libraryTitle;

  /// No description provided for @libraryViewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Visualização'**
  String get libraryViewTitle;

  /// No description provided for @sortByLabel.
  ///
  /// In pt, this message translates to:
  /// **'Ordenar por'**
  String get sortByLabel;

  /// No description provided for @sortByNumber.
  ///
  /// In pt, this message translates to:
  /// **'Número'**
  String get sortByNumber;

  /// No description provided for @sortByName.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get sortByName;

  /// No description provided for @itemsPerPage.
  ///
  /// In pt, this message translates to:
  /// **'Itens por página'**
  String get itemsPerPage;

  /// No description provided for @itemsPerPageValue.
  ///
  /// In pt, this message translates to:
  /// **'{count} por página'**
  String itemsPerPageValue(int count);

  /// No description provided for @pagePrevious.
  ///
  /// In pt, this message translates to:
  /// **'Anterior'**
  String get pagePrevious;

  /// No description provided for @pageNext.
  ///
  /// In pt, this message translates to:
  /// **'Próxima'**
  String get pageNext;

  /// No description provided for @pageIndicator.
  ///
  /// In pt, this message translates to:
  /// **'Página {current} de {total}'**
  String pageIndicator(int current, int total);

  /// No description provided for @pageCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Página {page}'**
  String pageCurrent(int page);

  /// No description provided for @catalogLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar o catálogo'**
  String get catalogLoadError;

  /// No description provided for @retry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retry;

  /// No description provided for @storagePreparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando o armazenamento local…'**
  String get storagePreparing;

  /// No description provided for @storageUnavailableTitle.
  ///
  /// In pt, this message translates to:
  /// **'Armazenamento local indisponível'**
  String get storageUnavailableTitle;

  /// No description provided for @storageUnavailableBody.
  ///
  /// In pt, this message translates to:
  /// **'Esta área precisa do banco local do app. O catálogo online e o leitor de PDF continuam disponíveis nas outras abas.'**
  String get storageUnavailableBody;

  /// No description provided for @libraryResultsSummary.
  ///
  /// In pt, this message translates to:
  /// **'Mostrando {from}–{to} de {total} louvores'**
  String libraryResultsSummary(int from, int to, int total);

  /// No description provided for @libraryResultsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum louvor encontrado com os filtros atuais'**
  String get libraryResultsEmpty;

  /// No description provided for @coldigomFilterTonality.
  ///
  /// In pt, this message translates to:
  /// **'Tom'**
  String get coldigomFilterTonality;

  /// No description provided for @coldigomFilterRhythm.
  ///
  /// In pt, this message translates to:
  /// **'Ritmo'**
  String get coldigomFilterRhythm;

  /// No description provided for @coldigomFilterCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get coldigomFilterCategory;

  /// No description provided for @coldigomFilterTags.
  ///
  /// In pt, this message translates to:
  /// **'Tags'**
  String get coldigomFilterTags;

  /// No description provided for @coldigomFilterMaterials.
  ///
  /// In pt, this message translates to:
  /// **'Materiais'**
  String get coldigomFilterMaterials;

  /// No description provided for @offlineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Offline'**
  String get offlineTitle;

  /// No description provided for @offlineSelectCategories.
  ///
  /// In pt, this message translates to:
  /// **'Selecione as categorias'**
  String get offlineSelectCategories;

  /// No description provided for @offlineDownloadSelected.
  ///
  /// In pt, this message translates to:
  /// **'Baixar selecionados'**
  String get offlineDownloadSelected;

  /// No description provided for @offlineStopDownload.
  ///
  /// In pt, this message translates to:
  /// **'Parar'**
  String get offlineStopDownload;

  /// No description provided for @offlineStoppingDownload.
  ///
  /// In pt, this message translates to:
  /// **'Parando...'**
  String get offlineStoppingDownload;

  /// No description provided for @offlineCancelDownload.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get offlineCancelDownload;

  /// No description provided for @offlineDownloadCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Download offline concluído'**
  String get offlineDownloadCompleted;

  /// No description provided for @offlineDownloadCompletedWithFailures.
  ///
  /// In pt, this message translates to:
  /// **'{failedCount, plural, one{Download concluído com 1 arquivo com falha} other{Download concluído com {failedCount} arquivos com falha}}'**
  String offlineDownloadCompletedWithFailures(int failedCount);

  /// No description provided for @offlineKeepAppOpenDuringDownload.
  ///
  /// In pt, this message translates to:
  /// **'Mantenha o app aberto durante o download.'**
  String get offlineKeepAppOpenDuringDownload;

  /// No description provided for @offlineInsufficientDiskSpace.
  ///
  /// In pt, this message translates to:
  /// **'Espaço em disco insuficiente para o download'**
  String get offlineInsufficientDiskSpace;

  /// No description provided for @offlineStorageUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Armazenamento local indisponível. Recarregue a página ou libere espaço.'**
  String get offlineStorageUnavailable;

  /// No description provided for @offlineMaintenanceBusy.
  ///
  /// In pt, this message translates to:
  /// **'Outra operação offline está em andamento. Tente de novo em instantes.'**
  String get offlineMaintenanceBusy;

  /// No description provided for @offlinePhaseFetching.
  ///
  /// In pt, this message translates to:
  /// **'baixando'**
  String get offlinePhaseFetching;

  /// No description provided for @offlineProgressDetail.
  ///
  /// In pt, this message translates to:
  /// **'{category} — {done}/{total} PDFs ({phase})'**
  String offlineProgressDetail(
    String category,
    int done,
    int total,
    String phase,
  );

  /// No description provided for @offlineStatsTitle.
  ///
  /// In pt, this message translates to:
  /// **'PDFs armazenados'**
  String get offlineStatsTitle;

  /// No description provided for @offlineStatsTotal.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum PDF offline} one{1 PDF offline} other{{count} PDFs offline}}'**
  String offlineStatsTotal(int count);

  /// No description provided for @offlineStatsCategory.
  ///
  /// In pt, this message translates to:
  /// **'{category}: {count}'**
  String offlineStatsCategory(String category, int count);

  /// No description provided for @offlineStatsCategoryWithMissing.
  ///
  /// In pt, this message translates to:
  /// **'{category}: {downloaded} ({missing} faltantes)'**
  String offlineStatsCategoryWithMissing(
    String category,
    int downloaded,
    int missing,
  );

  /// No description provided for @offlineStatsTotalMissing.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 PDF faltante no total} other{{count} PDFs faltantes no total}}'**
  String offlineStatsTotalMissing(int count);

  /// No description provided for @offlineStatsMissingUnreliable.
  ///
  /// In pt, this message translates to:
  /// **'Faltantes indisponíveis (sem conexão)'**
  String get offlineStatsMissingUnreliable;

  /// No description provided for @offlineStatsDiskUsage.
  ///
  /// In pt, this message translates to:
  /// **'Acervo offline: {used} | Disponível: {free}'**
  String offlineStatsDiskUsage(String used, String free);

  /// No description provided for @offlineStatsDiskUsageUsedOnly.
  ///
  /// In pt, this message translates to:
  /// **'Acervo offline: {used}'**
  String offlineStatsDiskUsageUsedOnly(String used);

  /// No description provided for @offlineStatsCategoryUnreliableMissing.
  ///
  /// In pt, this message translates to:
  /// **'{category}: {downloaded} (— faltantes, sem conexão)'**
  String offlineStatsCategoryUnreliableMissing(String category, int downloaded);

  /// No description provided for @offlineRefreshStats.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get offlineRefreshStats;

  /// No description provided for @offlineRefreshSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Informações offline atualizadas'**
  String get offlineRefreshSuccess;

  /// No description provided for @offlineRefreshError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar as informações offline'**
  String get offlineRefreshError;

  /// No description provided for @offlineRemovedBanner.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 PDF deixou de estar disponível localmente} other{{count} PDFs deixaram de estar disponíveis localmente}}'**
  String offlineRemovedBanner(int count);

  /// No description provided for @offlineDownloadMissing.
  ///
  /// In pt, this message translates to:
  /// **'Baixar faltantes'**
  String get offlineDownloadMissing;

  /// No description provided for @offlineMissingLouvoresSheetTitle.
  ///
  /// In pt, this message translates to:
  /// **'{category} — faltantes'**
  String offlineMissingLouvoresSheetTitle(String category);

  /// No description provided for @offlineMissingLouvoresEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum PDF faltante nesta categoria'**
  String get offlineMissingLouvoresEmpty;

  /// No description provided for @offlineMissingLouvoresLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os faltantes'**
  String get offlineMissingLouvoresLoadError;

  /// No description provided for @offlineDismissRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Dispensar'**
  String get offlineDismissRemoved;

  /// No description provided for @offlineClearCache.
  ///
  /// In pt, this message translates to:
  /// **'Limpar cache offline'**
  String get offlineClearCache;

  /// No description provided for @offlineClearCacheConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limpar cache offline?'**
  String get offlineClearCacheConfirmTitle;

  /// No description provided for @offlineClearCacheConfirmBody.
  ///
  /// In pt, this message translates to:
  /// **'Os PDFs baixados de {categories} serão removidos. Esta ação não pode ser desfeita.'**
  String offlineClearCacheConfirmBody(String categories);

  /// No description provided for @offlineClearCacheConfirmBodyAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos os PDFs offline serão removidos. Esta ação não pode ser desfeita.'**
  String get offlineClearCacheConfirmBodyAll;

  /// No description provided for @offlineClearCacheConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get offlineClearCacheConfirm;

  /// No description provided for @offlineClearCacheCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get offlineClearCacheCancel;

  /// No description provided for @offlineClearCacheSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Cache offline limpo'**
  String get offlineClearCacheSuccess;

  /// No description provided for @offlineClearCacheSuccessPartial.
  ///
  /// In pt, this message translates to:
  /// **'Cache de {categories} limpo'**
  String offlineClearCacheSuccessPartial(String categories);

  /// No description provided for @offlineMissingProgress.
  ///
  /// In pt, this message translates to:
  /// **'Baixando faltantes: {done}/{total}'**
  String offlineMissingProgress(int done, int total);

  /// No description provided for @offlineMissingCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Download concluído: {downloaded} baixados, {failed} falhas'**
  String offlineMissingCompleted(int downloaded, int failed);

  /// No description provided for @offlineMissingError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível baixar os PDFs faltantes'**
  String get offlineMissingError;

  /// No description provided for @pdfOfflineUnavailableMessage.
  ///
  /// In pt, this message translates to:
  /// **'Este PDF não foi baixado para uso offline. Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.'**
  String get pdfOfflineUnavailableMessage;

  /// PDF local existe mas a leitura falhou sem evidência de corrupção (B3) — arquivo é preservado, usuário pode tentar novamente
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ler o arquivo. Tente novamente.'**
  String get pdfLocalReadFailedMessage;

  /// PDF indexado cujo arquivo sumiu do disco e não deu para rebaixar (D.6)
  ///
  /// In pt, this message translates to:
  /// **'O PDF foi removido do dispositivo. Conecte-se ou use Configurações Offline → Baixar faltantes.'**
  String get pdfExternallyDeleted;

  /// PDF em cache passou na validação de disco mas não abre no leitor (D.6)
  ///
  /// In pt, this message translates to:
  /// **'O PDF salvo no dispositivo está corrompido. Baixe de novo para continuar.'**
  String get pdfLocalCorrupted;

  /// No description provided for @pdfOfflineGoToSettings.
  ///
  /// In pt, this message translates to:
  /// **'Baixar'**
  String get pdfOfflineGoToSettings;

  /// No description provided for @pdfOfflinePersistentTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Disponível offline (download garantido)'**
  String get pdfOfflinePersistentTooltip;

  /// No description provided for @pdfOfflineCachedLruTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Cache temporário — pode ser removido para liberar espaço'**
  String get pdfOfflineCachedLruTooltip;

  /// No description provided for @carouselClear.
  ///
  /// In pt, this message translates to:
  /// **'Limpar seleção'**
  String get carouselClear;

  /// No description provided for @carouselClearConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limpar seleção?'**
  String get carouselClearConfirmTitle;

  /// No description provided for @carouselClearConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'Nova Lista esvazia a seleção e mantém a lista atual. Apagar lista remove o rascunho permanentemente.'**
  String get carouselClearConfirmMessage;

  /// No description provided for @carouselClearCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get carouselClearCancel;

  /// No description provided for @carouselClearNewList.
  ///
  /// In pt, this message translates to:
  /// **'Nova Lista'**
  String get carouselClearNewList;

  /// No description provided for @carouselClearDeleteList.
  ///
  /// In pt, this message translates to:
  /// **'Apagar lista'**
  String get carouselClearDeleteList;

  /// No description provided for @carouselAdded.
  ///
  /// In pt, this message translates to:
  /// **'Adicionado à seleção'**
  String get carouselAdded;

  /// No description provided for @carouselAlreadyAdded.
  ///
  /// In pt, this message translates to:
  /// **'Já está na seleção'**
  String get carouselAlreadyAdded;

  /// Tooltip do × no trailing do sheet de materiais quando o material já está na lista ativa
  ///
  /// In pt, this message translates to:
  /// **'Remover da lista'**
  String get materialRemoveTooltip;

  /// No description provided for @materialRemoveConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover da lista?'**
  String get materialRemoveConfirmTitle;

  /// No description provided for @materialRemoveConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'«{name}» sai da lista ativa.'**
  String materialRemoveConfirmMessage(String name);

  /// No description provided for @materialRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Removido da lista'**
  String get materialRemoved;

  /// No description provided for @carouselRemoveTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get carouselRemoveTooltip;

  /// No description provided for @carouselAddTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar à seleção'**
  String get carouselAddTooltip;

  /// Tooltip do botão compartilhar na barra do carousel (UC-07/UC-08).
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get carouselSharePlaylist;

  /// No description provided for @carouselGenerateLeaflet.
  ///
  /// In pt, this message translates to:
  /// **'Gerar folheto'**
  String get carouselGenerateLeaflet;

  /// No description provided for @carouselOpen.
  ///
  /// In pt, this message translates to:
  /// **'Abrir'**
  String get carouselOpen;

  /// No description provided for @carouselMaterial.
  ///
  /// In pt, this message translates to:
  /// **'Material'**
  String get carouselMaterial;

  /// No description provided for @carouselList.
  ///
  /// In pt, this message translates to:
  /// **'Lista'**
  String get carouselList;

  /// No description provided for @carouselClearShort.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get carouselClearShort;

  /// No description provided for @carouselListTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seleção temporária'**
  String get carouselListTitle;

  /// No description provided for @carouselListClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get carouselListClose;

  /// No description provided for @readerCarouselPrevious.
  ///
  /// In pt, this message translates to:
  /// **'Louvor anterior'**
  String get readerCarouselPrevious;

  /// No description provided for @readerCarouselNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximo louvor'**
  String get readerCarouselNext;

  /// Tooltip do ícone de troca de material na barra do leitor PDF
  ///
  /// In pt, this message translates to:
  /// **'Trocar material'**
  String get readerSwitchMaterial;

  /// Snackbar do «+» sempre visível do card de louvor (C5) — o material preferido foi adicionado à lista ativa
  ///
  /// In pt, this message translates to:
  /// **'Adicionado à lista'**
  String get cardAddedSwapMaterial;

  /// Ação da snackbar de `cardAddedSwapMaterial` — reabre o sheet de materiais no fluxo de troca da entrada recém-adicionada
  ///
  /// In pt, this message translates to:
  /// **'Trocar material'**
  String get cardSwapMaterialAction;

  /// No description provided for @readerCarouselPosition.
  ///
  /// In pt, this message translates to:
  /// **'{current} de {total}'**
  String readerCarouselPosition(int current, int total);

  /// No description provided for @leafletGenerating.
  ///
  /// In pt, this message translates to:
  /// **'Gerando folheto…'**
  String get leafletGenerating;

  /// No description provided for @leafletShareSubject.
  ///
  /// In pt, this message translates to:
  /// **'Folheto PLPCG'**
  String get leafletShareSubject;

  /// No description provided for @leafletGenerateFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível gerar o folheto'**
  String get leafletGenerateFailed;

  /// No description provided for @leafletHeaderTitle.
  ///
  /// In pt, this message translates to:
  /// **'LOUVORES'**
  String get leafletHeaderTitle;

  /// No description provided for @leafletColumnNumber.
  ///
  /// In pt, this message translates to:
  /// **'NÚMERO'**
  String get leafletColumnNumber;

  /// No description provided for @leafletColumnName.
  ///
  /// In pt, this message translates to:
  /// **'NOME DO HINO'**
  String get leafletColumnName;

  /// No description provided for @leafletFooterPeace.
  ///
  /// In pt, this message translates to:
  /// **'A PAZ DO SENHOR JESUS CRISTO'**
  String get leafletFooterPeace;

  /// No description provided for @leafletFooterGreeting.
  ///
  /// In pt, this message translates to:
  /// **'Bom culto!'**
  String get leafletFooterGreeting;

  /// No description provided for @leafletShareQrCaption.
  ///
  /// In pt, this message translates to:
  /// **'Abrir lista no PLPCG'**
  String get leafletShareQrCaption;

  /// No description provided for @leafletWeekdayMonday.
  ///
  /// In pt, this message translates to:
  /// **'SEGUNDA-FEIRA'**
  String get leafletWeekdayMonday;

  /// No description provided for @leafletWeekdayTuesday.
  ///
  /// In pt, this message translates to:
  /// **'TERÇA-FEIRA'**
  String get leafletWeekdayTuesday;

  /// No description provided for @leafletWeekdayWednesday.
  ///
  /// In pt, this message translates to:
  /// **'QUARTA-FEIRA'**
  String get leafletWeekdayWednesday;

  /// No description provided for @leafletWeekdayThursday.
  ///
  /// In pt, this message translates to:
  /// **'QUINTA-FEIRA'**
  String get leafletWeekdayThursday;

  /// No description provided for @leafletWeekdayFriday.
  ///
  /// In pt, this message translates to:
  /// **'SEXTA-FEIRA'**
  String get leafletWeekdayFriday;

  /// No description provided for @leafletWeekdaySaturday.
  ///
  /// In pt, this message translates to:
  /// **'SÁBADO'**
  String get leafletWeekdaySaturday;

  /// No description provided for @leafletWeekdaySunday.
  ///
  /// In pt, this message translates to:
  /// **'DOMINGO'**
  String get leafletWeekdaySunday;

  /// No description provided for @playlistSaveTitle.
  ///
  /// In pt, this message translates to:
  /// **'Salvar lista'**
  String get playlistSaveTitle;

  /// No description provided for @playlistSaveNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome da lista'**
  String get playlistSaveNameLabel;

  /// No description provided for @playlistSaveCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get playlistSaveCancel;

  /// No description provided for @playlistSaveConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get playlistSaveConfirm;

  /// No description provided for @playlistSaved.
  ///
  /// In pt, this message translates to:
  /// **'Lista salva'**
  String get playlistSaved;

  /// No description provided for @playlistViewLists.
  ///
  /// In pt, this message translates to:
  /// **'Ver listas'**
  String get playlistViewLists;

  /// No description provided for @playlistEmptyCarousel.
  ///
  /// In pt, this message translates to:
  /// **'A seleção está vazia'**
  String get playlistEmptyCarousel;

  /// No description provided for @playlistEmptyList.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista salva. Monte uma seleção na Home ou Biblioteca e use \"Salvar como lista\".'**
  String get playlistEmptyList;

  /// No description provided for @playlistRename.
  ///
  /// In pt, this message translates to:
  /// **'Renomear'**
  String get playlistRename;

  /// No description provided for @playlistRenameTitle.
  ///
  /// In pt, this message translates to:
  /// **'Renomear lista'**
  String get playlistRenameTitle;

  /// No description provided for @playlistRenameConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get playlistRenameConfirm;

  /// No description provided for @playlistDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get playlistDelete;

  /// Snackbar depois de apagar uma lista, com ação Desfazer (C11)
  ///
  /// In pt, this message translates to:
  /// **'Lista removida'**
  String get playlistDeletedUndo;

  /// Item do menu do tile que cria uma cópia da lista (C11)
  ///
  /// In pt, this message translates to:
  /// **'Duplicar'**
  String get playlistDuplicate;

  /// Nome default da cópia criada por «Duplicar» (C11)
  ///
  /// In pt, this message translates to:
  /// **'{nome} (cópia)'**
  String playlistCopyName(String nome);

  /// Rótulo da lista ativa não salva na barra do carousel (C11)
  ///
  /// In pt, this message translates to:
  /// **'Rascunho'**
  String get playlistDraftLabel;

  /// No description provided for @playlistFavoriteOn.
  ///
  /// In pt, this message translates to:
  /// **'Marcar como favorita'**
  String get playlistFavoriteOn;

  /// No description provided for @playlistFavoriteOff.
  ///
  /// In pt, this message translates to:
  /// **'Remover dos favoritos'**
  String get playlistFavoriteOff;

  /// No description provided for @playlistPdfCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 louvor} other{{count} louvores}}'**
  String playlistPdfCount(int count);

  /// No description provided for @playlistSheetCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 partitura} other{{count} partituras}}'**
  String playlistSheetCount(int count);

  /// No description provided for @playlistAudioOnlyCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 áudio} other{{count} áudios}}'**
  String playlistAudioOnlyCount(int count);

  /// No description provided for @playlistEmptyCount.
  ///
  /// In pt, this message translates to:
  /// **'Vazia'**
  String get playlistEmptyCount;

  /// No description provided for @playlistDeleteLastPdfTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover último louvor?'**
  String get playlistDeleteLastPdfTitle;

  /// No description provided for @playlistDeleteLastPdfMessage.
  ///
  /// In pt, this message translates to:
  /// **'A lista ficará vazia e será excluída.'**
  String get playlistDeleteLastPdfMessage;

  /// No description provided for @playlistActivate.
  ///
  /// In pt, this message translates to:
  /// **'Editar por aqui'**
  String get playlistActivate;

  /// No description provided for @playlistOpenInReader.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no leitor'**
  String get playlistOpenInReader;

  /// No description provided for @playlistOpenInAudioPlayer.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no reprodutor'**
  String get playlistOpenInAudioPlayer;

  /// No description provided for @playlistAudioEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Esta lista não tem áudios.'**
  String get playlistAudioEmpty;

  /// No description provided for @audioPlayerTitle.
  ///
  /// In pt, this message translates to:
  /// **'Áudio'**
  String get audioPlayerTitle;

  /// No description provided for @pdfMaterialSection.
  ///
  /// In pt, this message translates to:
  /// **'Partituras'**
  String get pdfMaterialSection;

  /// No description provided for @audioMaterialSection.
  ///
  /// In pt, this message translates to:
  /// **'Áudio'**
  String get audioMaterialSection;

  /// No description provided for @youtubeMaterialSection.
  ///
  /// In pt, this message translates to:
  /// **'YouTube'**
  String get youtubeMaterialSection;

  /// No description provided for @chordMaterialSection.
  ///
  /// In pt, this message translates to:
  /// **'Cifras'**
  String get chordMaterialSection;

  /// No description provided for @chordUnavailableRetry.
  ///
  /// In pt, this message translates to:
  /// **'Cifra indisponível · tentar de novo'**
  String get chordUnavailableRetry;

  /// No description provided for @materialNotDownloadedOffline.
  ///
  /// In pt, this message translates to:
  /// **'Não baixado · sem ligação'**
  String get materialNotDownloadedOffline;

  /// No description provided for @materialNeedsConnection.
  ///
  /// In pt, this message translates to:
  /// **'Precisa de ligação'**
  String get materialNeedsConnection;

  /// No description provided for @materialSheetOfflineBanner.
  ///
  /// In pt, this message translates to:
  /// **'Sem ligação · só o que está no aparelho abre'**
  String get materialSheetOfflineBanner;

  /// No description provided for @playlistStorageUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Armazenamento local indisponível. Listas não podem ser salvas.'**
  String get playlistStorageUnavailable;

  /// Snackbar ao tentar editar a lista ativa enquanto ela é a projeção de um gestor ao vivo (spec lista-ao-vivo D4)
  ///
  /// In pt, this message translates to:
  /// **'Você está seguindo a lista de outra pessoa — saia da sessão para editar a sua'**
  String get liveFollowingCannotEdit;

  /// No description provided for @chordReaderUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Cifra ainda não disponível'**
  String get chordReaderUnavailable;

  /// No description provided for @chordReaderToggleTheme.
  ///
  /// In pt, this message translates to:
  /// **'Alternar tema do leitor'**
  String get chordReaderToggleTheme;

  /// No description provided for @chordReaderIncreaseFont.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar letra'**
  String get chordReaderIncreaseFont;

  /// No description provided for @chordReaderDecreaseFont.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir letra'**
  String get chordReaderDecreaseFont;

  /// No description provided for @chordReaderTransposeUp.
  ///
  /// In pt, this message translates to:
  /// **'Subir meio tom'**
  String get chordReaderTransposeUp;

  /// No description provided for @chordReaderTransposeDown.
  ///
  /// In pt, this message translates to:
  /// **'Descer meio tom'**
  String get chordReaderTransposeDown;

  /// No description provided for @chordReaderResetTranspose.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao tom original'**
  String get chordReaderResetTranspose;

  /// No description provided for @gestureNotFound.
  ///
  /// In pt, this message translates to:
  /// **'gesto não encontrado'**
  String get gestureNotFound;

  /// No description provided for @gesturesMaterialLabel.
  ///
  /// In pt, this message translates to:
  /// **'Gestos'**
  String get gesturesMaterialLabel;

  /// No description provided for @gesturesMaterialSection.
  ///
  /// In pt, this message translates to:
  /// **'Gestos'**
  String get gesturesMaterialSection;

  /// No description provided for @gesturesReaderTitle.
  ///
  /// In pt, this message translates to:
  /// **'Leitor de gestos'**
  String get gesturesReaderTitle;

  /// No description provided for @gesturesReaderEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Este louvor ainda não tem gestos'**
  String get gesturesReaderEmpty;

  /// No description provided for @gesturesReaderUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Gestos indisponíveis · tentar de novo'**
  String get gesturesReaderUnavailable;

  /// No description provided for @gesturesReaderIncreaseFont.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar letra dos gestos'**
  String get gesturesReaderIncreaseFont;

  /// No description provided for @gesturesReaderDecreaseFont.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir letra dos gestos'**
  String get gesturesReaderDecreaseFont;

  /// No description provided for @gesturesReaderFullscreen.
  ///
  /// In pt, this message translates to:
  /// **'Tela cheia'**
  String get gesturesReaderFullscreen;

  /// No description provided for @gesturesNewerSchemaWarning.
  ///
  /// In pt, this message translates to:
  /// **'Documento em formato mais novo; atualize o app.'**
  String get gesturesNewerSchemaWarning;

  /// No description provided for @gestureInstructionInstruments.
  ///
  /// In pt, this message translates to:
  /// **'Instrumentos'**
  String get gestureInstructionInstruments;

  /// No description provided for @gestureInstructionRepeatPraise.
  ///
  /// In pt, this message translates to:
  /// **'Repetir o louvor'**
  String get gestureInstructionRepeatPraise;

  /// No description provided for @gestureInstructionBackToChorus.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao coro'**
  String get gestureInstructionBackToChorus;

  /// No description provided for @gestureInstructionBackToChorusAndFinish.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao coro e finalizar'**
  String get gestureInstructionBackToChorusAndFinish;

  /// No description provided for @gestureContextRepeat.
  ///
  /// In pt, this message translates to:
  /// **'{count}x'**
  String gestureContextRepeat(int count);

  /// No description provided for @gestureContextChorus.
  ///
  /// In pt, this message translates to:
  /// **'CORO'**
  String get gestureContextChorus;

  /// No description provided for @gestureContextFinal.
  ///
  /// In pt, this message translates to:
  /// **'FINAL'**
  String get gestureContextFinal;

  /// No description provided for @gestureContextLink.
  ///
  /// In pt, this message translates to:
  /// **'ligação'**
  String get gestureContextLink;

  /// No description provided for @gestureFocusNext.
  ///
  /// In pt, this message translates to:
  /// **'próximo:'**
  String get gestureFocusNext;

  /// No description provided for @gestureFocusEnd.
  ///
  /// In pt, this message translates to:
  /// **'fim'**
  String get gestureFocusEnd;

  /// No description provided for @gestureFocusClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get gestureFocusClose;

  /// No description provided for @gestureSectionChorus.
  ///
  /// In pt, this message translates to:
  /// **'coro'**
  String get gestureSectionChorus;

  /// No description provided for @gestureSectionPass.
  ///
  /// In pt, this message translates to:
  /// **'{n}ª vez'**
  String gestureSectionPass(int n);

  /// No description provided for @gesturesReaderToggleTheme.
  ///
  /// In pt, this message translates to:
  /// **'Alternar tema do leitor'**
  String get gesturesReaderToggleTheme;

  /// No description provided for @gesturesReaderLinear.
  ///
  /// In pt, this message translates to:
  /// **'Mudar para leitura linear'**
  String get gesturesReaderLinear;

  /// No description provided for @gesturesReaderStructured.
  ///
  /// In pt, this message translates to:
  /// **'Mudar para leitura estruturada'**
  String get gesturesReaderStructured;

  /// No description provided for @gesturesAutoscrollPlay.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar rolagem automática'**
  String get gesturesAutoscrollPlay;

  /// No description provided for @gesturesAutoscrollPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar rolagem automática'**
  String get gesturesAutoscrollPause;

  /// No description provided for @gesturesAutoscrollSpeed.
  ///
  /// In pt, this message translates to:
  /// **'Velocidade da rolagem: {speed}'**
  String gesturesAutoscrollSpeed(int speed);

  /// No description provided for @chordAutoscrollPlay.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar rolagem automática'**
  String get chordAutoscrollPlay;

  /// No description provided for @chordAutoscrollPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar rolagem automática'**
  String get chordAutoscrollPause;

  /// No description provided for @chordAutoscrollSpeed.
  ///
  /// In pt, this message translates to:
  /// **'Velocidade da rolagem: {speed}'**
  String chordAutoscrollSpeed(int speed);

  /// No description provided for @coldigomMetaTonality.
  ///
  /// In pt, this message translates to:
  /// **'Tom'**
  String get coldigomMetaTonality;

  /// No description provided for @coldigomMetaAuthor.
  ///
  /// In pt, this message translates to:
  /// **'Autor'**
  String get coldigomMetaAuthor;

  /// No description provided for @coldigomMetaRhythm.
  ///
  /// In pt, this message translates to:
  /// **'Ritmo'**
  String get coldigomMetaRhythm;

  /// No description provided for @coldigomMetaCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get coldigomMetaCategory;

  /// No description provided for @coldigomMetaTags.
  ///
  /// In pt, this message translates to:
  /// **'Tags'**
  String get coldigomMetaTags;

  /// No description provided for @youtubeOpenError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir o YouTube'**
  String get youtubeOpenError;

  /// No description provided for @audioPlay.
  ///
  /// In pt, this message translates to:
  /// **'Reproduzir'**
  String get audioPlay;

  /// No description provided for @audioPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar'**
  String get audioPause;

  /// No description provided for @audioPrevious.
  ///
  /// In pt, this message translates to:
  /// **'Anterior'**
  String get audioPrevious;

  /// No description provided for @audioNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximo'**
  String get audioNext;

  /// Tooltip do botão que volta 10 s no áudio (C12)
  ///
  /// In pt, this message translates to:
  /// **'Voltar 10 s'**
  String get audioSeekBack10;

  /// Tooltip do botão que avança 10 s no áudio (C12)
  ///
  /// In pt, this message translates to:
  /// **'Avançar 10 s'**
  String get audioSeekForward10;

  /// Tooltip do menu de velocidade de reprodução (C12)
  ///
  /// In pt, this message translates to:
  /// **'Velocidade de reprodução'**
  String get audioSpeed;

  /// Rótulo de uma velocidade de reprodução no menu, ex.: 1,25× (C12)
  ///
  /// In pt, this message translates to:
  /// **'{value}×'**
  String audioSpeedValue(String value);

  /// Tooltip do botão de faixa anterior no mini-player persistente (D5)
  ///
  /// In pt, this message translates to:
  /// **'Faixa anterior'**
  String get miniPlayerPrevious;

  /// Tooltip do botão de próxima faixa no mini-player persistente (D5)
  ///
  /// In pt, this message translates to:
  /// **'Próxima faixa'**
  String get miniPlayerNext;

  /// Tooltip do botão que abre a tela cheia do áudio (/audio) a partir do mini-player persistente — única forma de voltar a ela depois que a barra sem faces (D5) parou de expor essa ação
  ///
  /// In pt, this message translates to:
  /// **'Abrir tela do áudio'**
  String get miniPlayerOpenScreen;

  /// No description provided for @audioClosePlayer.
  ///
  /// In pt, this message translates to:
  /// **'Encerrar e voltar à busca'**
  String get audioClosePlayer;

  /// Tooltip do botão que abre no leitor o material do louvor da faixa tocando
  ///
  /// In pt, this message translates to:
  /// **'Partitura/cifra deste louvor'**
  String get audioOpenSheetMusic;

  /// Tooltip do toggle que troca o material do leitor quando a faixa muda
  ///
  /// In pt, this message translates to:
  /// **'Seguir o áudio'**
  String get audioFollowReader;

  /// No description provided for @audioFlagAdd.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar marcador'**
  String get audioFlagAdd;

  /// No description provided for @audioFlagAddTitle.
  ///
  /// In pt, this message translates to:
  /// **'Novo marcador'**
  String get audioFlagAddTitle;

  /// No description provided for @audioFlagLabelHint.
  ///
  /// In pt, this message translates to:
  /// **'Rótulo opcional'**
  String get audioFlagLabelHint;

  /// No description provided for @audioFlagCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get audioFlagCancel;

  /// No description provided for @audioFlagSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get audioFlagSave;

  /// No description provided for @audioFlagListTitle.
  ///
  /// In pt, this message translates to:
  /// **'Marcadores'**
  String get audioFlagListTitle;

  /// No description provided for @audioFlagListEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum marcador. Pause e toque no botão de bandeira.'**
  String get audioFlagListEmpty;

  /// No description provided for @audioFlagDelete.
  ///
  /// In pt, this message translates to:
  /// **'Remover marcador'**
  String get audioFlagDelete;

  /// Título da linha de erro de sync de marcadores no player de áudio
  ///
  /// In pt, this message translates to:
  /// **'Marcadores não sincronizados'**
  String get audioFlagsSyncFailed;

  /// No description provided for @audioPlaybackError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível reproduzir este áudio.'**
  String get audioPlaybackError;

  /// No description provided for @audioNotDownloaded.
  ///
  /// In pt, this message translates to:
  /// **'Este áudio não foi baixado — sem ligação, só o que está no aparelho toca'**
  String get audioNotDownloaded;

  /// No description provided for @audioWebBackgroundNotice.
  ///
  /// In pt, this message translates to:
  /// **'Na Web, a reprodução em segundo plano e os controles do sistema dependem do navegador — isso não é um bug do app.'**
  String get audioWebBackgroundNotice;

  /// Tooltip do ícone no player que revela o aviso de segundo plano na Web
  ///
  /// In pt, this message translates to:
  /// **'Sobre reprodução na Web'**
  String get audioWebPlatformHintTooltip;

  /// No description provided for @audioWebIosPwaNotice.
  ///
  /// In pt, this message translates to:
  /// **'No iPhone com o app instalado na tela inicial, o áudio pode pausar ao bloquear a tela ou trocar de app. Mantenha o app aberto para ouvir.'**
  String get audioWebIosPwaNotice;

  /// Snackbar depois de tornar uma lista a lista ativa
  ///
  /// In pt, this message translates to:
  /// **'Lista «{nome}» ativa'**
  String playlistActivated(String nome);

  /// Ação de desfazer em snackbars
  ///
  /// In pt, this message translates to:
  /// **'Desfazer'**
  String get undo;

  /// No description provided for @playlistEmptyPdfList.
  ///
  /// In pt, this message translates to:
  /// **'Esta lista não tem louvores.'**
  String get playlistEmptyPdfList;

  /// Item do menu da lista salva: começa a transmitir a lista ao vivo (spec lista-ao-vivo)
  ///
  /// In pt, this message translates to:
  /// **'Iniciar ao vivo'**
  String get playlistGoLive;

  /// No description provided for @playlistShare.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get playlistShare;

  /// No description provided for @playlistImport.
  ///
  /// In pt, this message translates to:
  /// **'Importar lista'**
  String get playlistImport;

  /// FAB da tela de listas: abre o diálogo para colar o link/código de uma sala ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Entrar na sala'**
  String get liveJoinRoom;

  /// No description provided for @liveJoinRoomTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar numa sala ao vivo'**
  String get liveJoinRoomTitle;

  /// No description provided for @liveJoinRoomInputLabel.
  ///
  /// In pt, this message translates to:
  /// **'Link ou código da sala'**
  String get liveJoinRoomInputLabel;

  /// No description provided for @liveJoinRoomInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Link ou código de sala inválido'**
  String get liveJoinRoomInvalid;

  /// No description provided for @liveJoinRoomConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get liveJoinRoomConfirm;

  /// No description provided for @playlistImportTitle.
  ///
  /// In pt, this message translates to:
  /// **'Importar lista compartilhada'**
  String get playlistImportTitle;

  /// No description provided for @playlistImportUrlLabel.
  ///
  /// In pt, this message translates to:
  /// **'URL ou link compartilhado'**
  String get playlistImportUrlLabel;

  /// No description provided for @playlistImportPaste.
  ///
  /// In pt, this message translates to:
  /// **'Colar'**
  String get playlistImportPaste;

  /// No description provided for @playlistImportConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Importar'**
  String get playlistImportConfirm;

  /// No description provided for @playlistSyncFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível sincronizar suas listas'**
  String get playlistSyncFailed;

  /// No description provided for @playlistSyncConflicts.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 lista em conflito} other{{count} listas em conflito}}'**
  String playlistSyncConflicts(int count);

  /// No description provided for @playlistConflictCopySaved.
  ///
  /// In pt, this message translates to:
  /// **'Edições locais de «{nome}» guardadas em «{copia}»'**
  String playlistConflictCopySaved(String nome, String copia);

  /// No description provided for @playlistsRemovedRemotely.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 lista removida em outro aparelho} other{{count} listas removidas em outro aparelho}}'**
  String playlistsRemovedRemotely(int count);

  /// No description provided for @playlistImported.
  ///
  /// In pt, this message translates to:
  /// **'Lista importada'**
  String get playlistImported;

  /// Snackbar do import de link quando louvores do link não entraram (fora do catálogo local ou sem material adicionável)
  ///
  /// In pt, this message translates to:
  /// **'Lista importada — {count, plural, one{1 louvor ficou de fora} other{{count} louvores ficaram de fora}}'**
  String playlistImportedWithSkipped(int count);

  /// Snackbar ao importar um link de share cujo conteúdo já é uma lista salva (dedupe, D7)
  ///
  /// In pt, this message translates to:
  /// **'Lista já estava salva: {nome}'**
  String playlistImportAlreadySaved(String nome);

  /// No description provided for @playlistImportInvalidUrl.
  ///
  /// In pt, this message translates to:
  /// **'Link inválido.'**
  String get playlistImportInvalidUrl;

  /// No description provided for @deepLinkImportFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível importar a lista compartilhada.'**
  String get deepLinkImportFailed;

  /// Snackbar ao abrir ou colar um link de lista antigo (?s=, sharepdfs, shareitems…) — spec fim-fonte-plpcg §4.4
  ///
  /// In pt, this message translates to:
  /// **'Este link é de uma versão antiga e já não abre. Peça um link novo à pessoa.'**
  String get playlistShareLegacyLinkUnsupported;

  /// No description provided for @playlistShareError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível compartilhar a lista.'**
  String get playlistShareError;

  /// Snackbar depois de partilhar o link quando entradas legadas (fora do acervo Coldigom) ficaram fora dele
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 item da lista ficou fora do link} other{{count} itens da lista ficaram fora do link}}'**
  String playlistShareSkippedEntries(int count);

  /// No description provided for @playlistShareSheetTitle.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get playlistShareSheetTitle;

  /// No description provided for @playlistShareOptionLink.
  ///
  /// In pt, this message translates to:
  /// **'Só o link'**
  String get playlistShareOptionLink;

  /// No description provided for @playlistShareOptionLinkSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Quem receber importa a lista no PLPCG'**
  String get playlistShareOptionLinkSubtitle;

  /// No description provided for @playlistShareOptionLinkWithLeaflet.
  ///
  /// In pt, this message translates to:
  /// **'Folheto'**
  String get playlistShareOptionLinkWithLeaflet;

  /// No description provided for @playlistShareOptionLinkWithLeafletSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Imagem da lista com o link e QR code'**
  String get playlistShareOptionLinkWithLeafletSubtitle;

  /// No description provided for @playlistShareLinkWithLeafletMessage.
  ///
  /// In pt, this message translates to:
  /// **'{name}\n\n{url}'**
  String playlistShareLinkWithLeafletMessage(String name, String url);

  /// No description provided for @playlistTabUnsaved.
  ///
  /// In pt, this message translates to:
  /// **'Não Salvas'**
  String get playlistTabUnsaved;

  /// No description provided for @playlistTabSaved.
  ///
  /// In pt, this message translates to:
  /// **'Salvas'**
  String get playlistTabSaved;

  /// No description provided for @playlistTabFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Favoritas'**
  String get playlistTabFavorites;

  /// No description provided for @playlistSaveAction.
  ///
  /// In pt, this message translates to:
  /// **'Salvar lista'**
  String get playlistSaveAction;

  /// No description provided for @playlistEmptyUnsaved.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista não salva. Abra um louvor no leitor para criar uma automaticamente.'**
  String get playlistEmptyUnsaved;

  /// No description provided for @playlistEmptySaved.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista salva.'**
  String get playlistEmptySaved;

  /// No description provided for @playlistEmptyFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista favorita.'**
  String get playlistEmptyFavorites;

  /// No description provided for @playlistDeleteAllUnsaved.
  ///
  /// In pt, this message translates to:
  /// **'Apagar todas'**
  String get playlistDeleteAllUnsaved;

  /// No description provided for @playlistDeleteAllUnsavedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar todas as listas não salvas?'**
  String get playlistDeleteAllUnsavedTitle;

  /// No description provided for @playlistDeleteAllUnsavedMessage.
  ///
  /// In pt, this message translates to:
  /// **'Todas as listas da aba Não Salvas serão removidas permanentemente.'**
  String get playlistDeleteAllUnsavedMessage;

  /// No description provided for @playlistDeleteAllUnsavedDone.
  ///
  /// In pt, this message translates to:
  /// **'Listas não salvas apagadas'**
  String get playlistDeleteAllUnsavedDone;

  /// No description provided for @playlistPublish.
  ///
  /// In pt, this message translates to:
  /// **'Publicar'**
  String get playlistPublish;

  /// No description provided for @playlistPublishTitle.
  ///
  /// In pt, this message translates to:
  /// **'Publicar lista?'**
  String get playlistPublishTitle;

  /// No description provided for @playlistPublishMessage.
  ///
  /// In pt, this message translates to:
  /// **'Publicar é irreversível. Para remover a publicação, exclua a lista.'**
  String get playlistPublishMessage;

  /// No description provided for @playlistPublishConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Publicar'**
  String get playlistPublishConfirm;

  /// No description provided for @playlistPublishCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get playlistPublishCancel;

  /// No description provided for @playlistPublishCategoryLabel.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get playlistPublishCategoryLabel;

  /// No description provided for @playlistPublishReachLabel.
  ///
  /// In pt, this message translates to:
  /// **'Alcance'**
  String get playlistPublishReachLabel;

  /// No description provided for @playlistPublishReachUsual.
  ///
  /// In pt, this message translates to:
  /// **'Usual'**
  String get playlistPublishReachUsual;

  /// No description provided for @playlistPublishReachPontual.
  ///
  /// In pt, this message translates to:
  /// **'Pontual'**
  String get playlistPublishReachPontual;

  /// No description provided for @playlistPublishCategoryRequired.
  ///
  /// In pt, this message translates to:
  /// **'Escolha uma categoria para publicar.'**
  String get playlistPublishCategoryRequired;

  /// No description provided for @playlistPublished.
  ///
  /// In pt, this message translates to:
  /// **'Lista publicada'**
  String get playlistPublished;

  /// No description provided for @playlistPublicBadge.
  ///
  /// In pt, this message translates to:
  /// **'Pública'**
  String get playlistPublicBadge;

  /// No description provided for @playlistCategoryEvangelizacao.
  ///
  /// In pt, this message translates to:
  /// **'Evangelização'**
  String get playlistCategoryEvangelizacao;

  /// No description provided for @playlistCategoryAprendizado.
  ///
  /// In pt, this message translates to:
  /// **'Aprendizado'**
  String get playlistCategoryAprendizado;

  /// No description provided for @playlistCategoryMedleys.
  ///
  /// In pt, this message translates to:
  /// **'Medleys'**
  String get playlistCategoryMedleys;

  /// No description provided for @playlistCategoryCultoEspecial.
  ///
  /// In pt, this message translates to:
  /// **'Culto especial'**
  String get playlistCategoryCultoEspecial;

  /// No description provided for @playlistClearSavedBlocked.
  ///
  /// In pt, this message translates to:
  /// **'Listas salvas não podem ser limpas pela barra. Use o menu da lista.'**
  String get playlistClearSavedBlocked;

  /// Subtítulo do card quando o louvor agrupa vários PDFs (Home/Biblioteca)
  ///
  /// In pt, this message translates to:
  /// **'{entryCount, plural, one{1 entrada} other{{entryCount} entradas}} com {arrangementCount, plural, one{1 arranjo} other{{arrangementCount} arranjos}}'**
  String louvorGroupMetadataSummary(int entryCount, int arrangementCount);

  /// No description provided for @usernameCreateButton.
  ///
  /// In pt, this message translates to:
  /// **'Criar nome de usuário'**
  String get usernameCreateButton;

  /// No description provided for @usernameCreateTitle.
  ///
  /// In pt, this message translates to:
  /// **'Criar nome de usuário'**
  String get usernameCreateTitle;

  /// No description provided for @usernameCreateMessage.
  ///
  /// In pt, this message translates to:
  /// **'Escolha um nome de usuário único no app. Ele identifica você e suas listas públicas. Use 3 a 30 caracteres: letras minúsculas, números ou _.'**
  String get usernameCreateMessage;

  /// No description provided for @usernameCreatePrompt.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre um nome de usuário para publicar listas.'**
  String get usernameCreatePrompt;

  /// No description provided for @usernameFieldLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome de usuário'**
  String get usernameFieldLabel;

  /// No description provided for @usernameFieldHint.
  ///
  /// In pt, this message translates to:
  /// **'ex.: maria_silva'**
  String get usernameFieldHint;

  /// No description provided for @usernameCreateCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get usernameCreateCancel;

  /// No description provided for @usernameCreateConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get usernameCreateConfirm;

  /// No description provided for @usernameErrorInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Use 3–30 caracteres: a-z, 0-9 ou _.'**
  String get usernameErrorInvalid;

  /// No description provided for @usernameErrorTaken.
  ///
  /// In pt, this message translates to:
  /// **'Esse nome de usuário já está em uso.'**
  String get usernameErrorTaken;

  /// No description provided for @usernameErrorAlreadySet.
  ///
  /// In pt, this message translates to:
  /// **'Você já tem um nome de usuário.'**
  String get usernameErrorAlreadySet;

  /// No description provided for @usernameErrorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar. Tente novamente.'**
  String get usernameErrorGeneric;

  /// No description provided for @usernameRequiredToPublish.
  ///
  /// In pt, this message translates to:
  /// **'Cadastrar Nome de Usuário'**
  String get usernameRequiredToPublish;

  /// No description provided for @socialSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar pessoa por nome de usuário'**
  String get socialSearchHint;

  /// No description provided for @socialSearchEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Digite um nome de usuário para encontrar pessoas.'**
  String get socialSearchEmptyHint;

  /// No description provided for @socialSearchNoResults.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma pessoa encontrada.'**
  String get socialSearchNoResults;

  /// No description provided for @socialSearchError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível buscar. Tente novamente.'**
  String get socialSearchError;

  /// No description provided for @publicPlaylistsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Listas públicas'**
  String get publicPlaylistsTitle;

  /// No description provided for @socialSignInRequired.
  ///
  /// In pt, this message translates to:
  /// **'Entre com o Google para explorar as listas públicas.'**
  String get socialSignInRequired;

  /// No description provided for @socialPlaylistCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 lista} other{{count} listas}}'**
  String socialPlaylistCount(int count);

  /// No description provided for @socialPlaylistsError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar as listas.'**
  String get socialPlaylistsError;

  /// No description provided for @socialPlaylistsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Este perfil ainda não tem listas públicas.'**
  String get socialPlaylistsEmpty;

  /// No description provided for @socialCategoryOther.
  ///
  /// In pt, this message translates to:
  /// **'Outras'**
  String get socialCategoryOther;

  /// No description provided for @socialPlaylistImported.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 louvor adicionado à sua lista} other{{count} louvores adicionados à sua lista}}'**
  String socialPlaylistImported(int count);

  /// No description provided for @socialPlaylistImportNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum louvor novo para adicionar.'**
  String get socialPlaylistImportNone;

  /// No description provided for @deferredLoaderLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando…'**
  String get deferredLoaderLoading;

  /// No description provided for @deferredLoaderError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar esta seção.'**
  String get deferredLoaderError;

  /// No description provided for @deferredLoaderRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get deferredLoaderRetry;

  /// No description provided for @authSignInUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Login indisponível no momento.'**
  String get authSignInUnavailable;

  /// No description provided for @authSignInRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get authSignInRetry;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com o Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authSignInContextMismatchTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não conseguimos concluir o login'**
  String get authSignInContextMismatchTitle;

  /// No description provided for @authSignInContextMismatchBody.
  ///
  /// In pt, this message translates to:
  /// **'O Google respondeu em outra janela. Toque para tentar novamente.'**
  String get authSignInContextMismatchBody;

  /// No description provided for @authSignInOpenInBrowserHint.
  ///
  /// In pt, this message translates to:
  /// **'Se continuar, abra v2.plpcg.com no Safari.'**
  String get authSignInOpenInBrowserHint;

  /// userMessageFor: DioException de conexão (C.5)
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com a internet. Verifique sua rede e tente de novo.'**
  String get errorNoConnection;

  /// userMessageFor: DioException de timeout (C.5)
  ///
  /// In pt, this message translates to:
  /// **'A conexão demorou demais. Tente de novo.'**
  String get errorTimeout;

  /// userMessageFor: resposta 5xx do Worker (C.5)
  ///
  /// In pt, this message translates to:
  /// **'O servidor está indisponível no momento. Tente de novo em instantes.'**
  String get errorServer;

  /// userMessageFor: 401/403 ou AuthUnauthorizedException (C.5)
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Entre novamente para continuar.'**
  String get errorSessionExpired;

  /// userMessageFor: fallback para erro não classificado (C.5)
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir a ação. Tente de novo.'**
  String get errorGeneric;

  /// failureMessage (E8): NetworkFailure — DioException sem resposta, SocketException
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com a internet. Verifique sua rede e tente de novo.'**
  String get failureNetwork;

  /// failureMessage (E8): OfflineFailure — PdfOfflineUnavailableException
  ///
  /// In pt, this message translates to:
  /// **'Este PDF não foi baixado para uso offline. Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.'**
  String get failureOffline;

  /// failureMessage (E8): NotFoundFailure — HTTP 404, PlaylistNotFoundException, PdfExternallyDeletedException
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível encontrar. O item pode ter sido removido.'**
  String get failureNotFound;

  /// failureMessage (E8): StorageFailure — StorageUnavailableException, PdfStorageWriteException, InsufficientDiskSpaceException, PdfLocalCorruptedException
  ///
  /// In pt, this message translates to:
  /// **'Armazenamento local indisponível. Recarregue a página ou libere espaço.'**
  String get failureStorage;

  /// failureMessage (E8): AuthFailure — HTTP 401/403
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Entre novamente para continuar.'**
  String get failureAuth;

  /// failureMessage (E8): ConflictFailure — HTTP 409, PlaylistConflictException, AudioFlagConflictException
  ///
  /// In pt, this message translates to:
  /// **'Conflito de sincronização. Tente novamente.'**
  String get failureConflict;

  /// failureMessage (E8): UnknownFailure — fallback para erro não classificado
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir a ação. Tente de novo.'**
  String get failureUnknown;

  /// Hint da Home sem consulta nem lista ativa/recentes (C4)
  ///
  /// In pt, this message translates to:
  /// **'Busque por título ou número'**
  String get homeEmptyHint;

  /// Título das chips de materiais recentes na Home sem consulta (C4)
  ///
  /// In pt, this message translates to:
  /// **'Abertos recentemente'**
  String get homeEmptyRecent;

  /// Título da Home quando a busca não encontrou nada (C4)
  ///
  /// In pt, this message translates to:
  /// **'Nenhum louvor para «{query}»'**
  String homeNoResults(String query);

  /// Dicas da Home quando a busca não encontrou nada (C4)
  ///
  /// In pt, this message translates to:
  /// **'Tente outro termo, ou confira o número e a grafia.'**
  String get homeNoResultsTips;

  /// Botão da Home sem resultado, visível só com filtro fora do padrão (C4)
  ///
  /// In pt, this message translates to:
  /// **'Limpar filtros'**
  String get homeClearFilters;

  /// Aviso da página inicial sem resultado quando a busca remota não foi chamada por falta de rede e o catálogo local está vazio (spec fim-fonte §9.2)
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão — o catálogo pode estar incompleto nesta busca.'**
  String get homeColdigomOffline;

  /// No description provided for @favoriteMaterialKindsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Materiais favoritos'**
  String get favoriteMaterialKindsTitle;

  /// No description provided for @favoriteMaterialKindsHelp.
  ///
  /// In pt, this message translates to:
  /// **'Escolha até {max} tipos de material. Eles aparecem primeiro ao abrir um louvor.'**
  String favoriteMaterialKindsHelp(int max);

  /// No description provided for @favoriteMaterialKindsYours.
  ///
  /// In pt, this message translates to:
  /// **'Seus favoritos ({count} de {max})'**
  String favoriteMaterialKindsYours(int count, int max);

  /// No description provided for @favoriteMaterialKindsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum favorito ainda'**
  String get favoriteMaterialKindsEmpty;

  /// No description provided for @favoriteMaterialKindsAdd.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get favoriteMaterialKindsAdd;

  /// No description provided for @favoriteMaterialKindsSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar tipo de material'**
  String get favoriteMaterialKindsSearchHint;

  /// No description provided for @favoriteMaterialKindsLimitReached.
  ///
  /// In pt, this message translates to:
  /// **'Limite de {max} — remova um para trocar'**
  String favoriteMaterialKindsLimitReached(int max);

  /// No description provided for @favoriteMaterialKindsSignInPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Entre com Google para escolher seus materiais favoritos.'**
  String get favoriteMaterialKindsSignInPrompt;

  /// No description provided for @favoriteMaterialKindsSyncPending.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização pendente'**
  String get favoriteMaterialKindsSyncPending;

  /// No description provided for @favoriteMaterialKindsRemoveTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Remover dos favoritos'**
  String get favoriteMaterialKindsRemoveTooltip;

  /// No description provided for @favoriteMaterialKindsAddTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar aos favoritos'**
  String get favoriteMaterialKindsAddTooltip;

  /// No description provided for @favoriteMaterialKindsUnknownKind.
  ///
  /// In pt, this message translates to:
  /// **'Desconhecido'**
  String get favoriteMaterialKindsUnknownKind;

  /// No description provided for @favoriteMaterialKindsLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os tipos de material'**
  String get favoriteMaterialKindsLoadError;

  /// No description provided for @favoriteMaterialKindsRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get favoriteMaterialKindsRetry;

  /// No description provided for @favoriteMaterialKindsNoMatch.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum tipo com esse nome'**
  String get favoriteMaterialKindsNoMatch;

  /// No description provided for @favoriteMaterialKindsTypePreferenceTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Escolher formato preferido'**
  String get favoriteMaterialKindsTypePreferenceTooltip;

  /// No description provided for @favoriteMaterialKindsTypePreferenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Formato preferido de {kind}'**
  String favoriteMaterialKindsTypePreferenceTitle(String kind);

  /// No description provided for @favoriteMaterialKindsTypePreferenceHelp.
  ///
  /// In pt, this message translates to:
  /// **'Arraste para ordenar — o primeiro da lista é o formato preferido.'**
  String get favoriteMaterialKindsTypePreferenceHelp;

  /// Banner do consumidor numa sessão ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Seguindo {owner} · {list}'**
  String liveFollowing(String owner, String list);

  /// Sufixo do banner do consumidor quando o gestor está ausente
  ///
  /// In pt, this message translates to:
  /// **'gestor ausente'**
  String get liveLeaderAway;

  /// Banner do consumidor numa sala ainda sem transmissão
  ///
  /// In pt, this message translates to:
  /// **'Aguardando {owner}'**
  String liveWaitingFor(String owner);

  /// Banner de sessão ao vivo tentando reconectar
  ///
  /// In pt, this message translates to:
  /// **'Reconectando…'**
  String get liveReconnecting;

  /// Ação do banner do consumidor para voltar a seguir o foco do gestor (D3)
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao gestor'**
  String get liveReturnToLeader;

  /// Ação do banner de sessão ao vivo para sair da sala
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get liveLeave;

  /// Banner do gestor; viewers = pessoas conectadas
  ///
  /// In pt, this message translates to:
  /// **'AO VIVO · {viewers}'**
  String liveOnAir(int viewers);

  /// Ação do banner do gestor para abrir a tela da sala ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Sala'**
  String get liveRoom;

  /// Ação do banner de sessão ao vivo para encerrar a transmissão
  ///
  /// In pt, this message translates to:
  /// **'Encerrar'**
  String get liveEnd;

  /// Título da confirmação de encerramento da sessão ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Encerrar a sessão ao vivo?'**
  String get liveEndConfirmTitle;

  /// Corpo da confirmação de encerramento da sessão ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Todos os que estão seguindo vão parar de receber a lista.'**
  String get liveEndConfirmBody;

  /// Banner do gestor quando outro dispositivo assumiu a sessão ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Sessão assumida em outro dispositivo'**
  String get liveReplacedElsewhere;

  /// Ação genérica de confirmação do banner de sessão ao vivo
  ///
  /// In pt, this message translates to:
  /// **'OK'**
  String get liveOk;

  /// Banner de sessão de gestor pendente encontrada no boot (§7)
  ///
  /// In pt, this message translates to:
  /// **'Você estava ao vivo com «{list}»'**
  String liveWasLive(String list);

  /// Ação do banner de sessão de gestor pendente para retomar a transmissão
  ///
  /// In pt, this message translates to:
  /// **'Retomar'**
  String get liveResume;

  /// Tela da sala ao vivo: estado enquanto conecta
  ///
  /// In pt, this message translates to:
  /// **'Entrando…'**
  String get liveJoining;

  /// Tela da sala ao vivo: título quando a conexão falha de vez
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível conectar à sessão'**
  String get liveUnavailableTitle;

  /// Tela da sala ao vivo: corpo quando a conexão falha de vez
  ///
  /// In pt, this message translates to:
  /// **'Esta rede pode bloquear conexões ao vivo. Tente outra rede ou peça o link da lista pública.'**
  String get liveUnavailableBody;

  /// Tela da sala ao vivo: ação para tentar conectar de novo
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get liveRetry;

  /// Tela da sala ao vivo: sala inexistente ou substituída
  ///
  /// In pt, this message translates to:
  /// **'Este link não existe ou foi substituído por um novo.'**
  String get liveNotFound;

  /// Tela da sala ao vivo: consumidor numa sala ainda sem transmissão
  ///
  /// In pt, this message translates to:
  /// **'{owner} não está ao vivo agora'**
  String liveIdleTitle(String owner);

  /// Tela da sala ao vivo: corpo do estado idle do consumidor
  ///
  /// In pt, this message translates to:
  /// **'Fique por aqui — quando começar, você entra sozinho.'**
  String get liveIdleBody;

  /// Tela da sala ao vivo: consumidor seguindo a transmissão
  ///
  /// In pt, this message translates to:
  /// **'Você está seguindo {owner}'**
  String liveFollowingTitle(String owner);

  /// Tela da sala ao vivo: ação do consumidor para ir para a lista ativa
  ///
  /// In pt, this message translates to:
  /// **'Ir para a lista'**
  String get liveGoToList;

  /// Tela da sala ao vivo: título quando a sessão terminou
  ///
  /// In pt, this message translates to:
  /// **'Sessão encerrada'**
  String get liveEndedTitle;

  /// Tela da sala ao vivo: ação para guardar uma cópia da lista do gestor (D4)
  ///
  /// In pt, this message translates to:
  /// **'Guardar cópia'**
  String get liveSaveCopy;

  /// Nome dado à cópia salva de uma lista ao vivo
  ///
  /// In pt, this message translates to:
  /// **'{list} (ao vivo com {owner})'**
  String liveCopyName(String list, String owner);

  /// Confirmação depois de guardar a cópia da lista ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Cópia guardada em Listas'**
  String get liveCopySaved;

  /// Tela da sala ao vivo: título depois de sair da sala
  ///
  /// In pt, this message translates to:
  /// **'Você saiu da sessão'**
  String get liveLeftTitle;

  /// Tela da sala ao vivo: ação para voltar a entrar depois de sair
  ///
  /// In pt, this message translates to:
  /// **'Entrar de novo'**
  String get liveJoinAgain;

  /// Tela da sala ao vivo: título para o gestor
  ///
  /// In pt, this message translates to:
  /// **'Sua sala ao vivo'**
  String get liveYourRoom;

  /// Tela da sala ao vivo: explicação do link para o gestor
  ///
  /// In pt, this message translates to:
  /// **'Quem abrir este link vê a sua lista em tempo real.'**
  String get liveShareHint;

  /// Tela da sala ao vivo: ação para copiar o link da sala
  ///
  /// In pt, this message translates to:
  /// **'Copiar link'**
  String get liveCopyLink;

  /// Confirmação depois de copiar o link da sala ao vivo
  ///
  /// In pt, this message translates to:
  /// **'Link copiado'**
  String get liveLinkCopied;

  /// Tela da sala ao vivo: ação para compartilhar o link da sala
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get liveShareLink;

  /// Tela da sala ao vivo: ação para gerar um novo link de sala
  ///
  /// In pt, this message translates to:
  /// **'Gerar novo link'**
  String get liveRegenerateLink;

  /// Título da confirmação para gerar um novo link de sala
  ///
  /// In pt, this message translates to:
  /// **'Gerar um novo link?'**
  String get liveRegenerateConfirmTitle;

  /// Corpo da confirmação para gerar um novo link de sala
  ///
  /// In pt, this message translates to:
  /// **'O link atual deixa de funcionar para todos.'**
  String get liveRegenerateConfirmBody;

  /// Tela da sala ao vivo: contagem de pessoas conectadas
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Ninguém conectado} =1{1 pessoa conectada} other{{count} pessoas conectadas}}'**
  String liveViewers(int count);

  /// Erro genérico ao carregar/regenerar a sala ao vivo do gestor
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar a sua sala'**
  String get liveRoomError;

  /// Snackbar ao tentar «Iniciar ao vivo» sem estar logado
  ///
  /// In pt, this message translates to:
  /// **'Entre com o Google para transmitir ao vivo'**
  String get liveLoginRequired;

  /// FAB da tela de listas que expande em «Abrir Sala» e «Entrar na sala»
  ///
  /// In pt, this message translates to:
  /// **'Sala ao Vivo'**
  String get liveRoomMenu;

  /// Sub-botão do FAB «Sala ao Vivo» que abre a sala ao vivo do usuário logado
  ///
  /// In pt, this message translates to:
  /// **'Abrir Sala'**
  String get liveOpenRoom;

  /// No description provided for @lyricsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Letra'**
  String get lyricsTitle;

  /// No description provided for @lyricsTab.
  ///
  /// In pt, this message translates to:
  /// **'Letra'**
  String get lyricsTab;

  /// No description provided for @lyricsReaderEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Este louvor não tem letra guardada'**
  String get lyricsReaderEmpty;

  /// No description provided for @lyricsReaderIncreaseFont.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar letra'**
  String get lyricsReaderIncreaseFont;

  /// No description provided for @lyricsReaderDecreaseFont.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir letra'**
  String get lyricsReaderDecreaseFont;

  /// No description provided for @offlineColdigomPlpcgSection.
  ///
  /// In pt, this message translates to:
  /// **'Acervo PLPCG (PDFs)'**
  String get offlineColdigomPlpcgSection;

  /// No description provided for @offlineColdigomSection.
  ///
  /// In pt, this message translates to:
  /// **'Coldigom por tipo de material'**
  String get offlineColdigomSection;

  /// No description provided for @offlineColdigomCatalogStatus.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo: {count} louvores · atualizado {ago}'**
  String offlineColdigomCatalogStatus(int count, String ago);

  /// No description provided for @offlineColdigomCatalogMissing.
  ///
  /// In pt, this message translates to:
  /// **'Ligue-se à internet para baixar o catálogo'**
  String get offlineColdigomCatalogMissing;

  /// No description provided for @offlineColdigomAgoJustNow.
  ///
  /// In pt, this message translates to:
  /// **'agora mesmo'**
  String get offlineColdigomAgoJustNow;

  /// No description provided for @offlineColdigomAgoMinutes.
  ///
  /// In pt, this message translates to:
  /// **'há {n} min'**
  String offlineColdigomAgoMinutes(int n);

  /// No description provided for @offlineColdigomAgoHours.
  ///
  /// In pt, this message translates to:
  /// **'há {n} h'**
  String offlineColdigomAgoHours(int n);

  /// No description provided for @offlineColdigomAgoDays.
  ///
  /// In pt, this message translates to:
  /// **'há {n} d'**
  String offlineColdigomAgoDays(int n);

  /// No description provided for @offlineColdigomSignInPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Entre com Google para baixar os seus tipos favoritos'**
  String get offlineColdigomSignInPrompt;

  /// No description provided for @offlineColdigomFavoriteKinds.
  ///
  /// In pt, this message translates to:
  /// **'Seus tipos favoritos'**
  String get offlineColdigomFavoriteKinds;

  /// No description provided for @offlineColdigomNoFavorites.
  ///
  /// In pt, this message translates to:
  /// **'Sem favoritos — escolha em Materiais favoritos ou abra «Outros tipos»'**
  String get offlineColdigomNoFavorites;

  /// No description provided for @offlineColdigomOtherKinds.
  ///
  /// In pt, this message translates to:
  /// **'Outros tipos'**
  String get offlineColdigomOtherKinds;

  /// No description provided for @offlineColdigomKindSummary.
  ///
  /// In pt, this message translates to:
  /// **'{count} materiais · {size}'**
  String offlineColdigomKindSummary(int count, String size);

  /// No description provided for @offlineColdigomDownloadSelected.
  ///
  /// In pt, this message translates to:
  /// **'Baixar selecionados ({size})'**
  String offlineColdigomDownloadSelected(String size);

  /// No description provided for @offlineColdigomStop.
  ///
  /// In pt, this message translates to:
  /// **'Parar'**
  String get offlineColdigomStop;

  /// No description provided for @offlineColdigomProgress.
  ///
  /// In pt, this message translates to:
  /// **'{kind} · {done}/{total}'**
  String offlineColdigomProgress(String kind, int done, int total);

  /// No description provided for @offlineColdigomDone.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nada novo para baixar} one{1 material baixado} other{{count} materiais baixados}}'**
  String offlineColdigomDone(int count);

  /// No description provided for @offlineColdigomFailures.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 não baixado} other{{count} não baixados}}'**
  String offlineColdigomFailures(int count);

  /// No description provided for @offlineColdigomStopped.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, one{Parado — 1 restante} other{Parado — {n} restantes}}'**
  String offlineColdigomStopped(int n);

  /// No description provided for @offlineColdigomOutOfSpace.
  ///
  /// In pt, this message translates to:
  /// **'Sem espaço no aparelho'**
  String get offlineColdigomOutOfSpace;

  /// No description provided for @offlineColdigomRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get offlineColdigomRetry;

  /// No description provided for @offlineColdigomRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover áudios e PDFs baixados do Coldigom'**
  String get offlineColdigomRemove;

  /// No description provided for @offlineColdigomRemoveNote.
  ///
  /// In pt, this message translates to:
  /// **'Cifras, gestos e letras ficam no aparelho.'**
  String get offlineColdigomRemoveNote;

  /// No description provided for @offlineColdigomRemoveConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover baixados do Coldigom?'**
  String get offlineColdigomRemoveConfirmTitle;

  /// No description provided for @offlineColdigomRemoved.
  ///
  /// In pt, this message translates to:
  /// **'{pdfs} PDFs e {audios} áudios removidos'**
  String offlineColdigomRemoved(int pdfs, int audios);

  /// No description provided for @offlineColdigomSpaceWarning.
  ///
  /// In pt, this message translates to:
  /// **'Estimativa de {size} acima do espaço livre ({free}) — o download pode parar a meio.'**
  String offlineColdigomSpaceWarning(String size, String free);

  /// No description provided for @contributeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajude a melhorar o PLPCG'**
  String get contributeTitle;

  /// No description provided for @contributeSignInPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Entre com Google para contribuir.'**
  String get contributeSignInPrompt;

  /// No description provided for @contributeKindLabel.
  ///
  /// In pt, this message translates to:
  /// **'O que você quer contar?'**
  String get contributeKindLabel;

  /// No description provided for @contributeKindBug.
  ///
  /// In pt, this message translates to:
  /// **'Bug na app'**
  String get contributeKindBug;

  /// No description provided for @contributeKindWrongInfo.
  ///
  /// In pt, this message translates to:
  /// **'Informação errada'**
  String get contributeKindWrongInfo;

  /// No description provided for @contributeKindContent.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo'**
  String get contributeKindContent;

  /// No description provided for @contributeKindImprovement.
  ///
  /// In pt, this message translates to:
  /// **'Melhoria'**
  String get contributeKindImprovement;

  /// No description provided for @contributeKindOther.
  ///
  /// In pt, this message translates to:
  /// **'Outro'**
  String get contributeKindOther;

  /// No description provided for @contributeSubkindLabel.
  ///
  /// In pt, this message translates to:
  /// **'Sobre o quê?'**
  String get contributeSubkindLabel;

  /// No description provided for @contributeSubkindBugScreen.
  ///
  /// In pt, this message translates to:
  /// **'Uma tela'**
  String get contributeSubkindBugScreen;

  /// No description provided for @contributeSubkindBugReader.
  ///
  /// In pt, this message translates to:
  /// **'Leitor'**
  String get contributeSubkindBugReader;

  /// No description provided for @contributeSubkindBugAudio.
  ///
  /// In pt, this message translates to:
  /// **'Áudio'**
  String get contributeSubkindBugAudio;

  /// No description provided for @contributeSubkindBugSearch.
  ///
  /// In pt, this message translates to:
  /// **'Busca'**
  String get contributeSubkindBugSearch;

  /// No description provided for @contributeSubkindBugOffline.
  ///
  /// In pt, this message translates to:
  /// **'Offline'**
  String get contributeSubkindBugOffline;

  /// No description provided for @contributeSubkindBugLogin.
  ///
  /// In pt, this message translates to:
  /// **'Login'**
  String get contributeSubkindBugLogin;

  /// No description provided for @contributeSubkindBugPlaylistLive.
  ///
  /// In pt, this message translates to:
  /// **'Listas / ao vivo'**
  String get contributeSubkindBugPlaylistLive;

  /// No description provided for @contributeSubkindBugOther.
  ///
  /// In pt, this message translates to:
  /// **'Outro'**
  String get contributeSubkindBugOther;

  /// No description provided for @contributeSubkindWrongMetadata.
  ///
  /// In pt, this message translates to:
  /// **'Título, número, tom…'**
  String get contributeSubkindWrongMetadata;

  /// No description provided for @contributeSubkindWrongLyrics.
  ///
  /// In pt, this message translates to:
  /// **'Letra'**
  String get contributeSubkindWrongLyrics;

  /// No description provided for @contributeSubkindWrongMaterial.
  ///
  /// In pt, this message translates to:
  /// **'Material de outro louvor'**
  String get contributeSubkindWrongMaterial;

  /// No description provided for @contributeSubkindWrongKind.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de material errado'**
  String get contributeSubkindWrongKind;

  /// No description provided for @contributeSubkindDuplicate.
  ///
  /// In pt, this message translates to:
  /// **'Louvor duplicado'**
  String get contributeSubkindDuplicate;

  /// No description provided for @contributeSubkindAddMaterial.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar material'**
  String get contributeSubkindAddMaterial;

  /// No description provided for @contributeSubkindAddPraise.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar louvor'**
  String get contributeSubkindAddPraise;

  /// No description provided for @contributeSubkindReplaceMaterial.
  ///
  /// In pt, this message translates to:
  /// **'Substituir material'**
  String get contributeSubkindReplaceMaterial;

  /// No description provided for @contributeSubkindRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get contributeSubkindRemove;

  /// No description provided for @contributeSubkindFeature.
  ///
  /// In pt, this message translates to:
  /// **'Funcionalidade nova'**
  String get contributeSubkindFeature;

  /// No description provided for @contributeSubkindBehavior.
  ///
  /// In pt, this message translates to:
  /// **'Mudar um comportamento'**
  String get contributeSubkindBehavior;

  /// No description provided for @contributeMaterialLabel.
  ///
  /// In pt, this message translates to:
  /// **'Sobre qual material?'**
  String get contributeMaterialLabel;

  /// No description provided for @contributeMaterialWhole.
  ///
  /// In pt, this message translates to:
  /// **'O louvor em geral'**
  String get contributeMaterialWhole;

  /// No description provided for @contributeMetadataField.
  ///
  /// In pt, this message translates to:
  /// **'Campo'**
  String get contributeMetadataField;

  /// No description provided for @contributeMetadataCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Valor atual'**
  String get contributeMetadataCurrent;

  /// No description provided for @contributeMetadataProposed.
  ///
  /// In pt, this message translates to:
  /// **'Valor correto'**
  String get contributeMetadataProposed;

  /// No description provided for @contributeMetadataTitle.
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get contributeMetadataTitle;

  /// No description provided for @contributeMetadataNumber.
  ///
  /// In pt, this message translates to:
  /// **'Número'**
  String get contributeMetadataNumber;

  /// No description provided for @contributeMetadataAuthor.
  ///
  /// In pt, this message translates to:
  /// **'Autor'**
  String get contributeMetadataAuthor;

  /// No description provided for @contributeMetadataTonality.
  ///
  /// In pt, this message translates to:
  /// **'Tom'**
  String get contributeMetadataTonality;

  /// No description provided for @contributeMetadataRhythm.
  ///
  /// In pt, this message translates to:
  /// **'Ritmo'**
  String get contributeMetadataRhythm;

  /// No description provided for @contributeMetadataCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get contributeMetadataCategory;

  /// No description provided for @contributeMetadataTags.
  ///
  /// In pt, this message translates to:
  /// **'Tags'**
  String get contributeMetadataTags;

  /// No description provided for @contributeDuplicateOf.
  ///
  /// In pt, this message translates to:
  /// **'É o mesmo que (número ou título)'**
  String get contributeDuplicateOf;

  /// No description provided for @contributeSuggestedKind.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de material (opcional)'**
  String get contributeSuggestedKind;

  /// No description provided for @contributeTitleField.
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get contributeTitleField;

  /// No description provided for @contributeBodyField.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get contributeBodyField;

  /// No description provided for @contributeBodyHintBug.
  ///
  /// In pt, this message translates to:
  /// **'O que você fez, o que esperava e o que aconteceu'**
  String get contributeBodyHintBug;

  /// No description provided for @contributeAttachments.
  ///
  /// In pt, this message translates to:
  /// **'Anexos'**
  String get contributeAttachments;

  /// No description provided for @contributeAddFile.
  ///
  /// In pt, this message translates to:
  /// **'Anexar arquivo'**
  String get contributeAddFile;

  /// No description provided for @contributeAttachmentTooLarge.
  ///
  /// In pt, this message translates to:
  /// **'Acima de 32 MB, envie pelo link do Drive.'**
  String get contributeAttachmentTooLarge;

  /// No description provided for @contributeAttachmentTypeNotAllowed.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de arquivo não aceito.'**
  String get contributeAttachmentTypeNotAllowed;

  /// No description provided for @contributeAttachmentTooMany.
  ///
  /// In pt, this message translates to:
  /// **'No máximo 5 arquivos.'**
  String get contributeAttachmentTooMany;

  /// No description provided for @contributeAttachmentTotalTooLarge.
  ///
  /// In pt, this message translates to:
  /// **'No total, os anexos não podem passar de 96 MB.'**
  String get contributeAttachmentTotalTooLarge;

  /// No description provided for @contributeLinks.
  ///
  /// In pt, this message translates to:
  /// **'Links (YouTube / Drive)'**
  String get contributeLinks;

  /// No description provided for @contributeAddLink.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar link'**
  String get contributeAddLink;

  /// No description provided for @contributeLinkNotAllowed.
  ///
  /// In pt, this message translates to:
  /// **'Só links do YouTube ou do Google Drive.'**
  String get contributeLinkNotAllowed;

  /// No description provided for @contributeTooManyLinks.
  ///
  /// In pt, this message translates to:
  /// **'No máximo 5 links.'**
  String get contributeTooManyLinks;

  /// No description provided for @contributeDeviceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Isto será enviado'**
  String get contributeDeviceTitle;

  /// No description provided for @contributeDeviceLineApp.
  ///
  /// In pt, this message translates to:
  /// **'App'**
  String get contributeDeviceLineApp;

  /// No description provided for @contributeDeviceLinePlatform.
  ///
  /// In pt, this message translates to:
  /// **'Plataforma'**
  String get contributeDeviceLinePlatform;

  /// No description provided for @contributeDeviceLineDevice.
  ///
  /// In pt, this message translates to:
  /// **'Dispositivo'**
  String get contributeDeviceLineDevice;

  /// No description provided for @contributeDeviceLineSystem.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get contributeDeviceLineSystem;

  /// No description provided for @contributeDeviceLineBrowser.
  ///
  /// In pt, this message translates to:
  /// **'Navegador'**
  String get contributeDeviceLineBrowser;

  /// No description provided for @contributeDeviceLineScreen.
  ///
  /// In pt, this message translates to:
  /// **'Tela'**
  String get contributeDeviceLineScreen;

  /// No description provided for @contributeDeviceLineLocale.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get contributeDeviceLineLocale;

  /// No description provided for @contributeDeviceLineOnline.
  ///
  /// In pt, this message translates to:
  /// **'Online'**
  String get contributeDeviceLineOnline;

  /// No description provided for @contributeDeviceLinePwa.
  ///
  /// In pt, this message translates to:
  /// **'PWA instalada'**
  String get contributeDeviceLinePwa;

  /// No description provided for @commonYes.
  ///
  /// In pt, this message translates to:
  /// **'sim'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In pt, this message translates to:
  /// **'não'**
  String get commonNo;

  /// No description provided for @contributeSameDeviceQuestion.
  ///
  /// In pt, this message translates to:
  /// **'O bug aconteceu neste dispositivo?'**
  String get contributeSameDeviceQuestion;

  /// No description provided for @contributeSameDeviceYes.
  ///
  /// In pt, this message translates to:
  /// **'Sim'**
  String get contributeSameDeviceYes;

  /// No description provided for @contributeSameDeviceNo.
  ///
  /// In pt, this message translates to:
  /// **'Não'**
  String get contributeSameDeviceNo;

  /// No description provided for @contributeOtherDevice.
  ///
  /// In pt, this message translates to:
  /// **'Em qual dispositivo?'**
  String get contributeOtherDevice;

  /// No description provided for @contributeSend.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get contributeSend;

  /// No description provided for @contributeSent.
  ///
  /// In pt, this message translates to:
  /// **'Recebido, obrigado!'**
  String get contributeSent;

  /// No description provided for @contributeErrorOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sem ligação. Tente de novo.'**
  String get contributeErrorOffline;

  /// No description provided for @contributeErrorQuota.
  ///
  /// In pt, this message translates to:
  /// **'Limite diário atingido; volta às {time}.'**
  String contributeErrorQuota(String time);

  /// No description provided for @contributeErrorRejected.
  ///
  /// In pt, this message translates to:
  /// **'O envio foi recusado: {error}'**
  String contributeErrorRejected(String error);

  /// No description provided for @contributeErrorUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível enviar. Tente de novo.'**
  String get contributeErrorUnknown;

  /// No description provided for @contributeReportTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Reportar'**
  String get contributeReportTooltip;

  /// No description provided for @myContributionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Minhas contribuições'**
  String get myContributionsTitle;

  /// No description provided for @myContributionsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não enviou nenhuma contribuição.'**
  String get myContributionsEmpty;

  /// No description provided for @contributionStatusRecebida.
  ///
  /// In pt, this message translates to:
  /// **'Enviada · verificando anexos'**
  String get contributionStatusRecebida;

  /// No description provided for @contributionStatusPendente.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando análise'**
  String get contributionStatusPendente;

  /// No description provided for @contributionStatusEmAnalise.
  ///
  /// In pt, this message translates to:
  /// **'Em análise'**
  String get contributionStatusEmAnalise;

  /// No description provided for @contributionStatusAceita.
  ///
  /// In pt, this message translates to:
  /// **'Aceita'**
  String get contributionStatusAceita;

  /// No description provided for @contributionStatusRecusada.
  ///
  /// In pt, this message translates to:
  /// **'Recusada'**
  String get contributionStatusRecusada;

  /// No description provided for @contributionStatusAplicada.
  ///
  /// In pt, this message translates to:
  /// **'Aplicada'**
  String get contributionStatusAplicada;

  /// No description provided for @contributionStatusBloqueada.
  ///
  /// In pt, this message translates to:
  /// **'Não pôde ser analisada: anexo recusado pela verificação de segurança'**
  String get contributionStatusBloqueada;

  /// No description provided for @contributionDecisionNote.
  ///
  /// In pt, this message translates to:
  /// **'Nota da equipe'**
  String get contributionDecisionNote;

  /// No description provided for @contributionFilesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Anexos'**
  String get contributionFilesTitle;

  /// No description provided for @contributionFileScanPending.
  ///
  /// In pt, this message translates to:
  /// **'verificando'**
  String get contributionFileScanPending;

  /// No description provided for @contributionFileScanClean.
  ///
  /// In pt, this message translates to:
  /// **'ok'**
  String get contributionFileScanClean;

  /// No description provided for @contributionFileScanBlocked.
  ///
  /// In pt, this message translates to:
  /// **'recusado'**
  String get contributionFileScanBlocked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
