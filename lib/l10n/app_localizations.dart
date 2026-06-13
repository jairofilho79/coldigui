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
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt, this message translates to:
  /// **'PLPCG'**
  String get appTitle;

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

  /// No description provided for @specialArrangementPadrao.
  ///
  /// In pt, this message translates to:
  /// **'Padrão'**
  String get specialArrangementPadrao;

  /// No description provided for @filtersSpecialArrangementTitle.
  ///
  /// In pt, this message translates to:
  /// **'Arranjo especial'**
  String get filtersSpecialArrangementTitle;

  /// No description provided for @catalogRefreshAction.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar lista'**
  String get catalogRefreshAction;

  /// No description provided for @catalogRefreshLabel.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo'**
  String get catalogRefreshLabel;

  /// No description provided for @catalogRefreshMessage.
  ///
  /// In pt, this message translates to:
  /// **'Baixar a versão mais recente do catálogo'**
  String get catalogRefreshMessage;

  /// No description provided for @catalogRefreshSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo atualizado'**
  String get catalogRefreshSuccess;

  /// No description provided for @catalogRefreshError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível atualizar o catálogo'**
  String get catalogRefreshError;

  /// No description provided for @catalogLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar o catálogo'**
  String get catalogLoadError;

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

  /// No description provided for @offlineCancelDownload.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get offlineCancelDownload;

  /// No description provided for @offlineResumeBanner.
  ///
  /// In pt, this message translates to:
  /// **'Há um download offline interrompido.'**
  String get offlineResumeBanner;

  /// No description provided for @offlineResumeDownload.
  ///
  /// In pt, this message translates to:
  /// **'Retomar'**
  String get offlineResumeDownload;

  /// No description provided for @offlineDismissCheckpoint.
  ///
  /// In pt, this message translates to:
  /// **'Descartar'**
  String get offlineDismissCheckpoint;

  /// No description provided for @offlineDownloadCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Download offline concluído'**
  String get offlineDownloadCompleted;

  /// No description provided for @offlineDownloadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir o download offline'**
  String get offlineDownloadError;

  /// No description provided for @offlineInsufficientDiskSpace.
  ///
  /// In pt, this message translates to:
  /// **'Espaço em disco insuficiente para o download'**
  String get offlineInsufficientDiskSpace;

  /// No description provided for @offlinePhaseFetching.
  ///
  /// In pt, this message translates to:
  /// **'baixando'**
  String get offlinePhaseFetching;

  /// No description provided for @offlinePhaseExtracting.
  ///
  /// In pt, this message translates to:
  /// **'extraindo'**
  String get offlinePhaseExtracting;

  /// No description provided for @offlinePhaseStoring.
  ///
  /// In pt, this message translates to:
  /// **'armazenando'**
  String get offlinePhaseStoring;

  /// No description provided for @offlinePhaseSyncing.
  ///
  /// In pt, this message translates to:
  /// **'sincronizando'**
  String get offlinePhaseSyncing;

  /// No description provided for @offlineProgressDetail.
  ///
  /// In pt, this message translates to:
  /// **'{category} — parte {part}/{totalParts} — {done}/{total} PDFs ({phase})'**
  String offlineProgressDetail(String category, int part, int totalParts,
      int done, int total, String phase);

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
      String category, int downloaded, int missing);

  /// No description provided for @offlineStatsTotalMissing.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 PDF faltante no total} other{{count} PDFs faltantes no total}}'**
  String offlineStatsTotalMissing(int count);

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
  /// **'Todos os PDFs baixados serão removidos. Esta ação não pode ser desfeita.'**
  String get offlineClearCacheConfirmBody;

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
  /// **'Todos os louvores serão removidos da seleção.'**
  String get carouselClearConfirmMessage;

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

  /// No description provided for @carouselSavePlaylist.
  ///
  /// In pt, this message translates to:
  /// **'Salvar como lista'**
  String get carouselSavePlaylist;

  /// Menu overflow e tooltip do botão compartilhar na barra do carousel (UC-07).
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar lista'**
  String get carouselSharePlaylist;

  /// No description provided for @carouselGenerateLeaflet.
  ///
  /// In pt, this message translates to:
  /// **'Gerar folheto'**
  String get carouselGenerateLeaflet;

  /// No description provided for @carouselOverflowMenu.
  ///
  /// In pt, this message translates to:
  /// **'Mais ações'**
  String get carouselOverflowMenu;

  /// No description provided for @carouselOpenList.
  ///
  /// In pt, this message translates to:
  /// **'Ver seleção'**
  String get carouselOpenList;

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

  /// No description provided for @playlistDeleteConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir lista?'**
  String get playlistDeleteConfirmTitle;

  /// No description provided for @playlistDeleteConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'Esta lista será removida permanentemente.'**
  String get playlistDeleteConfirmMessage;

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

  /// No description provided for @playlistLoadIntoCarousel.
  ///
  /// In pt, this message translates to:
  /// **'Carregar no carousel'**
  String get playlistLoadIntoCarousel;

  /// No description provided for @playlistOpenInReader.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no leitor'**
  String get playlistOpenInReader;

  /// No description provided for @playlistLoadConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Substituir seleção?'**
  String get playlistLoadConfirmTitle;

  /// No description provided for @playlistLoadConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'A seleção atual será substituída pelos louvores desta lista.'**
  String get playlistLoadConfirmMessage;

  /// No description provided for @playlistLoaded.
  ///
  /// In pt, this message translates to:
  /// **'Lista carregada no carousel'**
  String get playlistLoaded;

  /// No description provided for @playlistEmptyPdfList.
  ///
  /// In pt, this message translates to:
  /// **'Esta lista não tem louvores.'**
  String get playlistEmptyPdfList;

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

  /// No description provided for @playlistImported.
  ///
  /// In pt, this message translates to:
  /// **'Lista importada'**
  String get playlistImported;

  /// No description provided for @playlistImportInvalidUrl.
  ///
  /// In pt, this message translates to:
  /// **'Link inválido. Use uma URL com sharepdfs e sharename.'**
  String get playlistImportInvalidUrl;

  /// No description provided for @playlistShareError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível compartilhar a lista.'**
  String get playlistShareError;

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
      'that was used.');
}
