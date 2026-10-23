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

  /// Botão para limpar todos os filtros ativos de forma rápida no painel de filtros
  ///
  /// In pt, this message translates to:
  /// **'Limpar filtros'**
  String get filtersClear;

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
  /// **'Mostrando {from}–{to} de {total} resultados'**
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

  /// No description provided for @coldigomFilterTags.
  ///
  /// In pt, this message translates to:
  /// **'Tags'**
  String get coldigomFilterTags;

  /// No description provided for @coldigomFilterSubtags.
  ///
  /// In pt, this message translates to:
  /// **'Subtags'**
  String get coldigomFilterSubtags;

  /// No description provided for @coldigomFilterMaterials.
  ///
  /// In pt, this message translates to:
  /// **'Materiais'**
  String get coldigomFilterMaterials;

  /// No description provided for @materialTypeFilterLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get materialTypeFilterLabel;

  /// No description provided for @materialTypeAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get materialTypeAll;

  /// No description provided for @materialTypePdf.
  ///
  /// In pt, this message translates to:
  /// **'PDF'**
  String get materialTypePdf;

  /// No description provided for @materialTypeChord.
  ///
  /// In pt, this message translates to:
  /// **'Cifra'**
  String get materialTypeChord;

  /// No description provided for @materialTypeAudio.
  ///
  /// In pt, this message translates to:
  /// **'Áudio'**
  String get materialTypeAudio;

  /// No description provided for @materialTypeYoutube.
  ///
  /// In pt, this message translates to:
  /// **'YouTube'**
  String get materialTypeYoutube;

  /// No description provided for @materialTypeGesture.
  ///
  /// In pt, this message translates to:
  /// **'Gestos'**
  String get materialTypeGesture;

  /// No description provided for @materialKindOtherClass.
  ///
  /// In pt, this message translates to:
  /// **'Outros'**
  String get materialKindOtherClass;

  /// No description provided for @materialKindHiddenByType.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 material oculto pelo tipo} other{{count} materiais ocultos pelo tipo}}'**
  String materialKindHiddenByType(int count);

  /// No description provided for @materialKindShowVariants.
  ///
  /// In pt, this message translates to:
  /// **'Ver variantes de {name}'**
  String materialKindShowVariants(String name);

  /// No description provided for @materialKindFamilyVariantsLabel.
  ///
  /// In pt, this message translates to:
  /// **'{name}, {count, plural, =1{1 variante} other{{count} variantes}}'**
  String materialKindFamilyVariantsLabel(String name, int count);

  /// No description provided for @materialKindFamilyRefinedValue.
  ///
  /// In pt, this message translates to:
  /// **'Parcialmente selecionado'**
  String get materialKindFamilyRefinedValue;

  /// No description provided for @offlineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Offline'**
  String get offlineTitle;

  /// No description provided for @offlineStoppingDownload.
  ///
  /// In pt, this message translates to:
  /// **'Parando...'**
  String get offlineStoppingDownload;

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

  /// No description provided for @offlineDismissRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Dispensar'**
  String get offlineDismissRemoved;

  /// No description provided for @pdfOfflineUnavailableMessage.
  ///
  /// In pt, this message translates to:
  /// **'Este PDF não foi baixado para uso offline. Conecte-se à internet ou baixe o tipo dele em Offline → Baixar para usar offline.'**
  String get pdfOfflineUnavailableMessage;

  /// PDF local existe mas a leitura falhou sem evidência de corrupção (B3) — arquivo é preservado, usuário pode tentar novamente
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ler o arquivo. Tente novamente.'**
  String get pdfLocalReadFailedMessage;

  /// PDF indexado cujo arquivo sumiu do disco e não deu para rebaixar (D.6)
  ///
  /// In pt, this message translates to:
  /// **'O PDF foi removido do dispositivo. Conecte-se ou baixe o tipo dele de novo em Offline → Baixar para usar offline.'**
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

  /// Dica de swipe no botão de trocar material para alternar entre versões do mesmo louvor
  ///
  /// In pt, this message translates to:
  /// **'Deslize para trocar de versão'**
  String get readerSwitchPraiseSwipe;

  /// Título da seção de versões/praises relacionados no sheet de materiais
  ///
  /// In pt, this message translates to:
  /// **'Versões'**
  String get relatedPraisesTitle;

  /// Mensagem exibida ao alternar a versão do louvor na playlist ativa
  ///
  /// In pt, this message translates to:
  /// **'Versão trocada: {tag}'**
  String relatedPraisesSwapped(String tag);

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

  /// No description provided for @gestureSectionVerse.
  ///
  /// In pt, this message translates to:
  /// **'estrofe'**
  String get gestureSectionVerse;

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

  /// No description provided for @lyricsAutoscrollPlay.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar rolagem automática'**
  String get lyricsAutoscrollPlay;

  /// No description provided for @lyricsAutoscrollPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar rolagem automática'**
  String get lyricsAutoscrollPause;

  /// No description provided for @lyricsAutoscrollSpeed.
  ///
  /// In pt, this message translates to:
  /// **'Velocidade da rolagem: {speed}'**
  String lyricsAutoscrollSpeed(int speed);

  /// No description provided for @autoscrollSpeedTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Velocidade da rolagem'**
  String get autoscrollSpeedTooltip;

  /// No description provided for @autoscrollSlow.
  ///
  /// In pt, this message translates to:
  /// **'Lento'**
  String get autoscrollSlow;

  /// No description provided for @autoscrollFast.
  ///
  /// In pt, this message translates to:
  /// **'Rápido'**
  String get autoscrollFast;

  /// No description provided for @autoscrollClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar ajuste de velocidade'**
  String get autoscrollClose;

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

  /// No description provided for @coldigomMetaBiblical.
  ///
  /// In pt, this message translates to:
  /// **'Iluminação Bíblica'**
  String get coldigomMetaBiblical;

  /// No description provided for @coldigomMetaTags.
  ///
  /// In pt, this message translates to:
  /// **'Tags'**
  String get coldigomMetaTags;

  /// No description provided for @coldigomMetaMoreDetails.
  ///
  /// In pt, this message translates to:
  /// **'Mais detalhes'**
  String get coldigomMetaMoreDetails;

  /// No description provided for @coldigomMetaLessDetails.
  ///
  /// In pt, this message translates to:
  /// **'Menos detalhes'**
  String get coldigomMetaLessDetails;

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

  /// Tooltip do botão do mini-player que, na tela de áudio (/audio), substitui «abrir» e volta à partitura/cifra do louvor da faixa (troca a rota, não empilha)
  ///
  /// In pt, this message translates to:
  /// **'Voltar à leitura'**
  String get miniPlayerBackToReading;

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
  /// **'Este PDF não foi baixado para uso offline. Conecte-se à internet ou baixe o tipo dele em Offline → Baixar para usar offline.'**
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

  /// No description provided for @offlineSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Baixar para usar offline'**
  String get offlineSectionTitle;

  /// No description provided for @offlineKindsAll.
  ///
  /// In pt, this message translates to:
  /// **'Tipos'**
  String get offlineKindsAll;

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
  /// **'Entre com Google para ver os seus tipos favoritos primeiro'**
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
  /// **'Remover todos os baixados'**
  String get offlineColdigomRemove;

  /// No description provided for @offlineColdigomRemoveConfirmBody.
  ///
  /// In pt, this message translates to:
  /// **'Todos os PDFs e áudios guardados no aparelho saem, incluindo os abertos recentemente. Cifras, gestos e letras ficam.'**
  String get offlineColdigomRemoveConfirmBody;

  /// No description provided for @offlineColdigomRemoveConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover todos os baixados?'**
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

  /// No description provided for @contributeClearForm.
  ///
  /// In pt, this message translates to:
  /// **'Limpar formulário'**
  String get contributeClearForm;

  /// No description provided for @contributeClearFormConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limpar formulário?'**
  String get contributeClearFormConfirmTitle;

  /// No description provided for @contributeClearFormConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza de que deseja limpar todos os campos preenchidos? Esta ação não pode ser desfeita.'**
  String get contributeClearFormConfirmMessage;

  /// No description provided for @contributeClearFormCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get contributeClearFormCancel;

  /// No description provided for @contributeClearFormConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get contributeClearFormConfirm;

  /// No description provided for @contributeSendDeviceData.
  ///
  /// In pt, this message translates to:
  /// **'Enviar dados do aparelho para ajudar no diagnóstico'**
  String get contributeSendDeviceData;

  /// No description provided for @contributeBodyHint.
  ///
  /// In pt, this message translates to:
  /// **'Descreva aqui o problema, erro ou sugestão que você encontrou...'**
  String get contributeBodyHint;

  /// No description provided for @contributeLinkedPraise.
  ///
  /// In pt, this message translates to:
  /// **'Relato vinculado ao louvor'**
  String get contributeLinkedPraise;

  /// No description provided for @contributeEditorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sugerir melhoria no material'**
  String get contributeEditorTitle;

  /// No description provided for @contributeEditorRawTab.
  ///
  /// In pt, this message translates to:
  /// **'Editor'**
  String get contributeEditorRawTab;

  /// No description provided for @contributeEditorPreviewTab.
  ///
  /// In pt, this message translates to:
  /// **'Pré-visualização'**
  String get contributeEditorPreviewTab;

  /// No description provided for @contributeEditorAddLine.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar linha'**
  String get contributeEditorAddLine;

  /// No description provided for @contributeEditorRemoveLine.
  ///
  /// In pt, this message translates to:
  /// **'Remover linha'**
  String get contributeEditorRemoveLine;

  /// No description provided for @contributeEditorChangeGesture.
  ///
  /// In pt, this message translates to:
  /// **'Trocar gesto'**
  String get contributeEditorChangeGesture;

  /// No description provided for @contributeEditorSearchGesture.
  ///
  /// In pt, this message translates to:
  /// **'Buscar gesto por nome ou gatilho...'**
  String get contributeEditorSearchGesture;

  /// No description provided for @contributeEditorRestore.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar original'**
  String get contributeEditorRestore;

  /// No description provided for @contributeEditorNotesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Observações sobre a sugestão (opcional)'**
  String get contributeEditorNotesLabel;

  /// No description provided for @contributeEditorNotesHint.
  ///
  /// In pt, this message translates to:
  /// **'Descreva brevemente o que você ajustou ou por que...'**
  String get contributeEditorNotesHint;

  /// No description provided for @contributeEditorTriggerLabel.
  ///
  /// In pt, this message translates to:
  /// **'Gatilho'**
  String get contributeEditorTriggerLabel;

  /// No description provided for @contributeEditorLyricsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Texto cantado'**
  String get contributeEditorLyricsLabel;

  /// No description provided for @contributeEditorAddGestureLine.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar gesto'**
  String get contributeEditorAddGestureLine;

  /// No description provided for @contributeEditorAddTextLine.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar texto livre'**
  String get contributeEditorAddTextLine;

  /// No description provided for @contributeEditorAddChorus.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar coro'**
  String get contributeEditorAddChorus;

  /// No description provided for @contributeEditorAddRepeat.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar repetição'**
  String get contributeEditorAddRepeat;

  /// No description provided for @contributeEditorMoveUp.
  ///
  /// In pt, this message translates to:
  /// **'Mover para cima'**
  String get contributeEditorMoveUp;

  /// No description provided for @contributeEditorMoveDown.
  ///
  /// In pt, this message translates to:
  /// **'Mover para baixo'**
  String get contributeEditorMoveDown;

  /// No description provided for @contributeEditorInsertChord.
  ///
  /// In pt, this message translates to:
  /// **'Inserir acorde [ ]'**
  String get contributeEditorInsertChord;

  /// No description provided for @contributeEditorInsertComment.
  ///
  /// In pt, this message translates to:
  /// **'Inserir comentário (coro)'**
  String get contributeEditorInsertComment;

  /// No description provided for @contributeEditorSwitchToGeneral.
  ///
  /// In pt, this message translates to:
  /// **'Alternar para formulário comum'**
  String get contributeEditorSwitchToGeneral;

  /// No description provided for @contributeEditorSwitchToExtracted.
  ///
  /// In pt, this message translates to:
  /// **'Editar material extraído'**
  String get contributeEditorSwitchToExtracted;

  /// No description provided for @contributeEditorLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando material...'**
  String get contributeEditorLoading;

  /// No description provided for @contributeEditorNoGestureFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum gesto encontrado'**
  String get contributeEditorNoGestureFound;

  /// No description provided for @contributeEditorSelectGesture.
  ///
  /// In pt, this message translates to:
  /// **'Escolher gesto'**
  String get contributeEditorSelectGesture;

  /// No description provided for @contributeEditorLyricsKind.
  ///
  /// In pt, this message translates to:
  /// **'Letra'**
  String get contributeEditorLyricsKind;

  /// No description provided for @contributeEditorChordKind.
  ///
  /// In pt, this message translates to:
  /// **'Cifra'**
  String get contributeEditorChordKind;

  /// No description provided for @contributeEditorGestureKind.
  ///
  /// In pt, this message translates to:
  /// **'Gestos'**
  String get contributeEditorGestureKind;

  /// No description provided for @contributeEditorGeneralKind.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get contributeEditorGeneralKind;

  /// No description provided for @contributeEditorGeneralHint.
  ///
  /// In pt, this message translates to:
  /// **'Para sugerir ajustes em Letras, Cifras ou Gestos, abra o louvor desejado no app e toque no ícone 🤝 na barra superior.'**
  String get contributeEditorGeneralHint;

  /// No description provided for @praiseOpenDetailsTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Ver página completa'**
  String get praiseOpenDetailsTooltip;

  /// No description provided for @praiseShareTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar louvor'**
  String get praiseShareTooltip;

  /// No description provided for @praiseShareLinkCopied.
  ///
  /// In pt, this message translates to:
  /// **'Link do louvor copiado!'**
  String get praiseShareLinkCopied;

  /// No description provided for @praiseNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Louvor não encontrado'**
  String get praiseNotFound;

  /// No description provided for @praiseBackToSearch.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para o início'**
  String get praiseBackToSearch;

  /// No description provided for @praiseLyricsSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Letra'**
  String get praiseLyricsSectionTitle;

  /// No description provided for @praiseMaterialsSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Materiais'**
  String get praiseMaterialsSectionTitle;

  /// No description provided for @praiseLyricsCopyTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Copiar letra'**
  String get praiseLyricsCopyTooltip;

  /// No description provided for @praiseLyricsCopied.
  ///
  /// In pt, this message translates to:
  /// **'Letra copiada!'**
  String get praiseLyricsCopied;

  /// No description provided for @praiseOpenLyricsReader.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no leitor de letra'**
  String get praiseOpenLyricsReader;

  /// No description provided for @praiseNoLyricsAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Letra não disponível para este louvor'**
  String get praiseNoLyricsAvailable;

  /// No description provided for @praiseIncreaseFontSizeTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar fonte'**
  String get praiseIncreaseFontSizeTooltip;

  /// No description provided for @praiseDecreaseFontSizeTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir fonte'**
  String get praiseDecreaseFontSizeTooltip;

  /// No description provided for @confirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get close;

  /// No description provided for @back.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get back;

  /// No description provided for @backTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get backTooltip;

  /// No description provided for @homeTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get homeTooltip;

  /// No description provided for @placeholderComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve'**
  String get placeholderComingSoon;

  /// No description provided for @degradedStorageBannerMessage.
  ///
  /// In pt, this message translates to:
  /// **'Armazenamento local indisponível. O catálogo online continua funcionando; listas e offline ficam desativados.'**
  String get degradedStorageBannerMessage;

  /// No description provided for @tabEvents.
  ///
  /// In pt, this message translates to:
  /// **'Eventos'**
  String get tabEvents;

  /// No description provided for @tabPlaylists.
  ///
  /// In pt, this message translates to:
  /// **'Listas'**
  String get tabPlaylists;

  /// No description provided for @tabSearch.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar'**
  String get tabSearch;

  /// No description provided for @tabProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get tabProfile;

  /// No description provided for @tabAbout.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get tabAbout;

  /// No description provided for @tabPraise.
  ///
  /// In pt, this message translates to:
  /// **'Louvor'**
  String get tabPraise;

  /// No description provided for @tabPublicPlaylists.
  ///
  /// In pt, this message translates to:
  /// **'Listas públicas'**
  String get tabPublicPlaylists;

  /// No description provided for @aboutTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get aboutTitle;

  /// No description provided for @profileResetTutorials.
  ///
  /// In pt, this message translates to:
  /// **'Redefinir Tutoriais'**
  String get profileResetTutorials;

  /// No description provided for @profileResetTutorialsDialogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Redefinir Tutoriais'**
  String get profileResetTutorialsDialogTitle;

  /// No description provided for @profileResetTutorialsDialogContent.
  ///
  /// In pt, this message translates to:
  /// **'Deseja redefinir todos os tutoriais? Os guias de introdução voltarão a ser exibidos automaticamente ao acessar as telas do aplicativo.'**
  String get profileResetTutorialsDialogContent;

  /// No description provided for @profileResetTutorialsConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Redefinir'**
  String get profileResetTutorialsConfirm;

  /// No description provided for @profileResetTutorialsSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Tutoriais redefinidos com sucesso!'**
  String get profileResetTutorialsSuccess;

  /// No description provided for @profileSyncPromptTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar para sincronizar seus dados'**
  String get profileSyncPromptTitle;

  /// No description provided for @profileSyncPromptBody.
  ///
  /// In pt, this message translates to:
  /// **'Use sua conta Google para sincronizar listas e outras features.'**
  String get profileSyncPromptBody;

  /// No description provided for @profileSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get profileSignOut;

  /// No description provided for @shortcutsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Atalhos de Teclado'**
  String get shortcutsTitle;

  /// No description provided for @shortcutsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Comandos rápidos de produtividade para Desktop e Web'**
  String get shortcutsSubtitle;

  /// No description provided for @shortcutsAboutDescription.
  ///
  /// In pt, this message translates to:
  /// **'Consulte os comandos rápidos de alta produtividade para Desktop e Web.'**
  String get shortcutsAboutDescription;

  /// No description provided for @welcomeTourAboutTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tour de Boas-Vindas'**
  String get welcomeTourAboutTitle;

  /// No description provided for @welcomeTourAboutDescription.
  ///
  /// In pt, this message translates to:
  /// **'Faça o tour guiado de 4 passos conhecendo o fluxo do acervo ao culto.'**
  String get welcomeTourAboutDescription;

  /// No description provided for @shortcutsTabAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get shortcutsTabAll;

  /// No description provided for @shortcutsTabNavigation.
  ///
  /// In pt, this message translates to:
  /// **'Navegação'**
  String get shortcutsTabNavigation;

  /// No description provided for @shortcutsTabRepertoireAudio.
  ///
  /// In pt, this message translates to:
  /// **'Repertório & Áudio'**
  String get shortcutsTabRepertoireAudio;

  /// No description provided for @shortcutsTabSheetMusic.
  ///
  /// In pt, this message translates to:
  /// **'Partituras'**
  String get shortcutsTabSheetMusic;

  /// No description provided for @shortcutsTabChordsGestures.
  ///
  /// In pt, this message translates to:
  /// **'Cifras & Gestos'**
  String get shortcutsTabChordsGestures;

  /// No description provided for @shortcutsFooterTip.
  ///
  /// In pt, this message translates to:
  /// **'Pressione ? em qualquer tela para abrir este painel a qualquer momento.'**
  String get shortcutsFooterTip;

  /// No description provided for @shortcutsGotIt.
  ///
  /// In pt, this message translates to:
  /// **'Entendi'**
  String get shortcutsGotIt;

  /// No description provided for @shortcutsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum atalho encontrado.'**
  String get shortcutsEmpty;

  /// No description provided for @shortcutsOr.
  ///
  /// In pt, this message translates to:
  /// **'ou'**
  String get shortcutsOr;

  /// No description provided for @shortcutCatNavigation.
  ///
  /// In pt, this message translates to:
  /// **'Navegação & Busca'**
  String get shortcutCatNavigation;

  /// No description provided for @shortcutCatRepertoireAudio.
  ///
  /// In pt, this message translates to:
  /// **'Repertório & Áudio'**
  String get shortcutCatRepertoireAudio;

  /// No description provided for @shortcutCatSheetMusic.
  ///
  /// In pt, this message translates to:
  /// **'Partituras (PDF)'**
  String get shortcutCatSheetMusic;

  /// No description provided for @shortcutCatChordsGestures.
  ///
  /// In pt, this message translates to:
  /// **'Cifras & Gestos'**
  String get shortcutCatChordsGestures;

  /// No description provided for @shortcutActionHomeSearch.
  ///
  /// In pt, this message translates to:
  /// **'Ir para a Home e focar campo de busca'**
  String get shortcutActionHomeSearch;

  /// No description provided for @shortcutActionOpenShortcuts.
  ///
  /// In pt, this message translates to:
  /// **'Abrir esta Central de Atalhos de Teclado'**
  String get shortcutActionOpenShortcuts;

  /// No description provided for @shortcutActionEscape.
  ///
  /// In pt, this message translates to:
  /// **'Sair de tela cheia, limpar busca ou fechar janelas'**
  String get shortcutActionEscape;

  /// No description provided for @shortcutActionNextPraise.
  ///
  /// In pt, this message translates to:
  /// **'Avançar para o próximo louvor do repertório'**
  String get shortcutActionNextPraise;

  /// No description provided for @shortcutActionPreviousPraise.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para o louvor anterior do repertório'**
  String get shortcutActionPreviousPraise;

  /// No description provided for @shortcutActionCarouselQueue.
  ///
  /// In pt, this message translates to:
  /// **'Navegar pela fila do carrossel de louvores'**
  String get shortcutActionCarouselQueue;

  /// No description provided for @shortcutActionToggleAudio.
  ///
  /// In pt, this message translates to:
  /// **'Tocar ou pausar o áudio do louvor'**
  String get shortcutActionToggleAudio;

  /// No description provided for @shortcutActionToggleAudioPdf.
  ///
  /// In pt, this message translates to:
  /// **'Tocar ou pausar áudio mesmo com partitura aberta'**
  String get shortcutActionToggleAudioPdf;

  /// No description provided for @shortcutActionSeekAudioBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar 10 segundos no áudio'**
  String get shortcutActionSeekAudioBack;

  /// No description provided for @shortcutActionSeekAudioForward.
  ///
  /// In pt, this message translates to:
  /// **'Avançar 10 segundos no áudio'**
  String get shortcutActionSeekAudioForward;

  /// No description provided for @shortcutActionToggleFullscreen.
  ///
  /// In pt, this message translates to:
  /// **'Alternar modo de tela cheia'**
  String get shortcutActionToggleFullscreen;

  /// No description provided for @shortcutActionNextPagePdf.
  ///
  /// In pt, this message translates to:
  /// **'Avançar página ou rolar partitura'**
  String get shortcutActionNextPagePdf;

  /// No description provided for @shortcutActionPrevPagePdf.
  ///
  /// In pt, this message translates to:
  /// **'Voltar página da partitura'**
  String get shortcutActionPrevPagePdf;

  /// No description provided for @shortcutActionFirstPagePdf.
  ///
  /// In pt, this message translates to:
  /// **'Ir para a primeira página'**
  String get shortcutActionFirstPagePdf;

  /// No description provided for @shortcutActionLastPagePdf.
  ///
  /// In pt, this message translates to:
  /// **'Ir para a última página'**
  String get shortcutActionLastPagePdf;

  /// No description provided for @shortcutActionFitModePdf.
  ///
  /// In pt, this message translates to:
  /// **'Alternar modo de ajuste (largura / altura)'**
  String get shortcutActionFitModePdf;

  /// No description provided for @shortcutActionPageGridPdf.
  ///
  /// In pt, this message translates to:
  /// **'Abrir seletor rápido de páginas em grade'**
  String get shortcutActionPageGridPdf;

  /// No description provided for @shortcutActionToggleAutoscroll.
  ///
  /// In pt, this message translates to:
  /// **'Ligar ou desligar rolagem automática (autoscroll)'**
  String get shortcutActionToggleAutoscroll;

  /// No description provided for @shortcutActionAdjustAutoscrollSpeed.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir ou aumentar velocidade de rolagem'**
  String get shortcutActionAdjustAutoscrollSpeed;

  /// No description provided for @shortcutActionTransposePitch.
  ///
  /// In pt, this message translates to:
  /// **'Transpor tom do louvor (+1 / -1 semitom)'**
  String get shortcutActionTransposePitch;

  /// No description provided for @shortcutActionNextGesture.
  ///
  /// In pt, this message translates to:
  /// **'Próximo gesto ou gesto anterior na regência'**
  String get shortcutActionNextGesture;

  /// No description provided for @shortcutBadgeReader.
  ///
  /// In pt, this message translates to:
  /// **'Leitor'**
  String get shortcutBadgeReader;

  /// No description provided for @shortcutBadgeGeneral.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get shortcutBadgeGeneral;

  /// No description provided for @shortcutBadgeReaderPdf.
  ///
  /// In pt, this message translates to:
  /// **'Leitor PDF'**
  String get shortcutBadgeReaderPdf;

  /// No description provided for @shortcutBadgeChordsLyrics.
  ///
  /// In pt, this message translates to:
  /// **'Cifras/Letras'**
  String get shortcutBadgeChordsLyrics;

  /// No description provided for @shortcutBadgeAutoscroll.
  ///
  /// In pt, this message translates to:
  /// **'Autoscroll'**
  String get shortcutBadgeAutoscroll;

  /// No description provided for @shortcutBadgeChords.
  ///
  /// In pt, this message translates to:
  /// **'Cifras'**
  String get shortcutBadgeChords;

  /// No description provided for @shortcutBadgeFocusModeCias.
  ///
  /// In pt, this message translates to:
  /// **'Modo Foco CIAs'**
  String get shortcutBadgeFocusModeCias;

  /// No description provided for @materialKindChordExtracted.
  ///
  /// In pt, this message translates to:
  /// **'Extraídos (chords)'**
  String get materialKindChordExtracted;

  /// No description provided for @materialKindGestureExtracted.
  ///
  /// In pt, this message translates to:
  /// **'Extraídos (gestos)'**
  String get materialKindGestureExtracted;

  /// No description provided for @offlineKindVariantsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} var.'**
  String offlineKindVariantsCount(int count);

  /// No description provided for @offlineKindVariantsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Variantes de {name} ({count}):'**
  String offlineKindVariantsTitle(String name, int count);

  /// No description provided for @offlineSearchMaterialTypeHint.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar tipo de material...'**
  String get offlineSearchMaterialTypeHint;

  /// No description provided for @offlineClearSearchTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Limpar pesquisa'**
  String get offlineClearSearchTooltip;

  /// No description provided for @offlineFilterButton.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar'**
  String get offlineFilterButton;

  /// No description provided for @offlineSearchNoResults.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum tipo de material encontrado para \"{query}\"'**
  String offlineSearchNoResults(String query);

  /// No description provided for @tutorialTooltipHowToShare.
  ///
  /// In pt, this message translates to:
  /// **'Como compartilhar'**
  String get tutorialTooltipHowToShare;

  /// No description provided for @tutorialTooltipHowToPublish.
  ///
  /// In pt, this message translates to:
  /// **'Como publicar'**
  String get tutorialTooltipHowToPublish;

  /// No description provided for @tutorialTooltipHowToUseFilters.
  ///
  /// In pt, this message translates to:
  /// **'Como usar os filtros'**
  String get tutorialTooltipHowToUseFilters;

  /// No description provided for @tutorialTooltipHowToUseMaterialSheet.
  ///
  /// In pt, this message translates to:
  /// **'Como usar este seletor'**
  String get tutorialTooltipHowToUseMaterialSheet;

  /// No description provided for @tutorialTooltipHowToManageList.
  ///
  /// In pt, this message translates to:
  /// **'Como gerenciar a lista'**
  String get tutorialTooltipHowToManageList;

  /// No description provided for @tutorialTooltipHowToUseFocusMode.
  ///
  /// In pt, this message translates to:
  /// **'Como usar o Modo Foco'**
  String get tutorialTooltipHowToUseFocusMode;

  /// No description provided for @tutorialTooltipHowToJoinLive.
  ///
  /// In pt, this message translates to:
  /// **'Como ingressar'**
  String get tutorialTooltipHowToJoinLive;

  /// No description provided for @tutorialTooltipHowToUseShortcuts.
  ///
  /// In pt, this message translates to:
  /// **'Como usar os atalhos'**
  String get tutorialTooltipHowToUseShortcuts;

  /// No description provided for @contributeNeedHelp.
  ///
  /// In pt, this message translates to:
  /// **'Precisa de ajuda?'**
  String get contributeNeedHelp;

  /// No description provided for @contributeHelpIntro.
  ///
  /// In pt, this message translates to:
  /// **'Esta página permite que você envie contribuições e nos ajude a aprimorar o aplicativo e o acervo do PLPCG. Escolha a opção que melhor descreve o seu caso:'**
  String get contributeHelpIntro;

  /// No description provided for @contributeHelpDescBug.
  ///
  /// In pt, this message translates to:
  /// **'Problemas no app (travamento, tela preta, botões sem resposta ou falha no áudio/leitor). Se puder, anexe uma captura de tela.'**
  String get contributeHelpDescBug;

  /// No description provided for @contributeHelpDescWrongInfo.
  ///
  /// In pt, this message translates to:
  /// **'Dados incorretos em um louvor existente (número, tom, título, autor, ritmo ou louvor duplicado).'**
  String get contributeHelpDescWrongInfo;

  /// No description provided for @contributeHelpDescContent.
  ///
  /// In pt, this message translates to:
  /// **'Envio ou sugestão de novos materiais (cifras, partituras, áudios ou letras) ou melhoria em arquivo existente.'**
  String get contributeHelpDescContent;

  /// No description provided for @contributeHelpDescImprovement.
  ///
  /// In pt, this message translates to:
  /// **'Sugestões de novos recursos, mudanças no visual ou ideias para deixar o app mais prático nos ensaios e cultos.'**
  String get contributeHelpDescImprovement;

  /// No description provided for @contributeHelpDescOther.
  ///
  /// In pt, this message translates to:
  /// **'Dúvidas gerais, recados para a equipe ou qualquer outro assunto não listado acima.'**
  String get contributeHelpDescOther;

  /// No description provided for @contributeHelpTipAttachments.
  ///
  /// In pt, this message translates to:
  /// **'Você também pode anexar arquivos (até 32 MB) ou colar links do Google Drive e YouTube para enriquecer seu envio.'**
  String get contributeHelpTipAttachments;

  /// No description provided for @contributeEditorChordProExampleHint.
  ///
  /// In pt, this message translates to:
  /// **'[G]Exemplo de [D]cifra ChordPro...'**
  String get contributeEditorChordProExampleHint;

  /// No description provided for @contributeEditorLinesCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 linha} other{{count} linhas}}'**
  String contributeEditorLinesCount(int count);

  /// No description provided for @contributeEditorGestureEmptyDocument.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item no documento. Adicione uma linha acima.'**
  String get contributeEditorGestureEmptyDocument;

  /// No description provided for @contributeEditorGestureBlocksCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 bloco/linha} other{{count} blocos/linhas}}'**
  String contributeEditorGestureBlocksCount(int count);

  /// No description provided for @contributeEditorGestureInstructionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Instrução: {kind}'**
  String contributeEditorGestureInstructionLabel(String kind);

  /// No description provided for @authGoogleSignInError.
  ///
  /// In pt, this message translates to:
  /// **'Falha ao entrar: {error}'**
  String authGoogleSignInError(String error);

  /// No description provided for @tutorialStepCounter.
  ///
  /// In pt, this message translates to:
  /// **'Passo {current} de {total}'**
  String tutorialStepCounter(int current, int total);

  /// No description provided for @tutorialDismissForever.
  ///
  /// In pt, this message translates to:
  /// **'Não mostrar novamente'**
  String get tutorialDismissForever;

  /// No description provided for @tutorialSkip.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get tutorialSkip;

  /// No description provided for @tutorialPrevious.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get tutorialPrevious;

  /// No description provided for @tutorialNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximo'**
  String get tutorialNext;

  /// No description provided for @tutorialFinish.
  ///
  /// In pt, this message translates to:
  /// **'Concluir'**
  String get tutorialFinish;

  /// No description provided for @tutorialHowToUseScreen.
  ///
  /// In pt, this message translates to:
  /// **'Como usar esta tela'**
  String get tutorialHowToUseScreen;

  /// No description provided for @welcomeHeroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo ao PLPCG!'**
  String get welcomeHeroTitle;

  /// No description provided for @welcomeHeroSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'O hinário digital e organizador de louvores para músicos, instrumentistas e ministérios.'**
  String get welcomeHeroSubtitle;

  /// No description provided for @welcomeHeroFeatureSearch.
  ///
  /// In pt, this message translates to:
  /// **'Busca rápida por número, título, ritmo e tags.'**
  String get welcomeHeroFeatureSearch;

  /// No description provided for @welcomeHeroFeaturePlaylists.
  ///
  /// In pt, this message translates to:
  /// **'Criação de listas e repertórios para o culto.'**
  String get welcomeHeroFeaturePlaylists;

  /// No description provided for @welcomeHeroFeatureReader.
  ///
  /// In pt, this message translates to:
  /// **'Leitor de partituras e cifras com pedais Bluetooth.'**
  String get welcomeHeroFeatureReader;

  /// No description provided for @welcomeHeroPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Deseja fazer um tour rápido de 1 minuto para conhecer as principais funcionalidades?'**
  String get welcomeHeroPrompt;

  /// No description provided for @welcomeHeroStartTour.
  ///
  /// In pt, this message translates to:
  /// **'Fazer Tour Rápido (1 min)'**
  String get welcomeHeroStartTour;

  /// No description provided for @welcomeHeroDismiss.
  ///
  /// In pt, this message translates to:
  /// **'Explorar por Conta Própria'**
  String get welcomeHeroDismiss;

  /// No description provided for @authSigningIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrando…'**
  String get authSigningIn;

  /// No description provided for @aboutWhoWeAreTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quem somos'**
  String get aboutWhoWeAreTitle;

  /// No description provided for @aboutWhoWeAreBody.
  ///
  /// In pt, this message translates to:
  /// **'A Paz do Senhor Jesus. Somos irmãos da Igreja Cristã Maranata da Região do Triângulo Mineiro e servimos no Maanaim de Uberlândia-MG. Esta aplicação não é oficial da ICM, mas o objetivo é ajudar a todos que estão no louvor ajudando na Obra. Seguindo as orientações da Igreja. De forma 100% gratuita.'**
  String get aboutWhoWeAreBody;

  /// No description provided for @aboutObjectiveTitle.
  ///
  /// In pt, this message translates to:
  /// **'Objetivo'**
  String get aboutObjectiveTitle;

  /// No description provided for @aboutObjectiveParagraph1.
  ///
  /// In pt, this message translates to:
  /// **'O objetivo da aplicação - chamada Pesquisador de Louvores em Partitura, Cifra em Geral - é ajudar aos irmãos da equipe de louvor com os materiais mais básicos pro louvor. Que seja fácil de pesquisar, consumir e que funcione offline, pois muita igrejas não tem internet ou é muito difícil o acesso em ESFs.'**
  String get aboutObjectiveParagraph1;

  /// No description provided for @aboutObjectiveParagraph2.
  ///
  /// In pt, this message translates to:
  /// **'Portanto, estejamos em oração por todos os irmãos que estão envolvidos nesse projeto. Quer seja diretamente no desenvolvimento da aplicação, quer seja na produção dos materiais, no uso/teste da aplicação e afins.'**
  String get aboutObjectiveParagraph2;

  /// No description provided for @tutorialAboutStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Quem Somos'**
  String get tutorialAboutStep1Title;

  /// No description provided for @tutorialAboutStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Conheça a história e a equipe por trás da aplicação. Uma iniciativa **100% gratuita** e colaborativa desenvolvida para auxiliar equipes de louvor.'**
  String get tutorialAboutStep1Message;

  /// No description provided for @tutorialAboutStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Nosso Objetivo'**
  String get tutorialAboutStep2Title;

  /// No description provided for @tutorialAboutStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'O propósito central é facilitar o acesso a **partituras, cifras, gestos e áudios**, com funcionamento **offline** garantido mesmo em locais sem internet.'**
  String get tutorialAboutStep2Message;

  /// No description provided for @tutorialAboutStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialAboutStep3Title;

  /// No description provided for @tutorialAboutStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no **ícone (i)** sempre que quiser rever este guia ou conferir instruções detalhadas em qualquer tela do aplicativo!'**
  String get tutorialAboutStep3Message;

  /// No description provided for @tutorialAppShortcutsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Categorias de Atalhos'**
  String get tutorialAppShortcutsStep1Title;

  /// No description provided for @tutorialAppShortcutsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Navegue entre as abas para explorar comandos agrupados por contexto: **Navegação & Busca**, **Repertório & Áudio**, **Partituras** e **Cifras & Gestos**.'**
  String get tutorialAppShortcutsStep1Message;

  /// No description provided for @tutorialAppShortcutsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Comandos de Alta Produtividade'**
  String get tutorialAppShortcutsStep2Title;

  /// No description provided for @tutorialAppShortcutsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte as teclas de atalho e suas ações correspondentes. Os selos laterais destacam os **contextos e leitores em que cada comando atua**.'**
  String get tutorialAppShortcutsStep2Message;

  /// No description provided for @tutorialAppShortcutsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Acesso Rápido com a Tecla ?'**
  String get tutorialAppShortcutsStep3Title;

  /// No description provided for @tutorialAppShortcutsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Pressione **?** (ou **Shift + /**) em qualquer tela do app para abrir esta **central de atalhos instantaneamente** no Desktop e Web.'**
  String get tutorialAppShortcutsStep3Message;

  /// No description provided for @tutorialAppShortcutsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda da Central de Atalhos'**
  String get tutorialAppShortcutsStep4Title;

  /// No description provided for @tutorialAppShortcutsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone para rever as instruções sobre os **comandos e atalhos rápidos** do PLPCG.'**
  String get tutorialAppShortcutsStep4Message;

  /// No description provided for @tutorialAudioStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Informações da Faixa'**
  String get tutorialAudioStep1Title;

  /// No description provided for @tutorialAudioStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Visualize o **título**, **número**, **autor** e a **classificação** do louvor ou áudio em reprodução.'**
  String get tutorialAudioStep1Message;

  /// No description provided for @tutorialAudioStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Ações e Sincronização'**
  String get tutorialAudioStep2Title;

  /// No description provided for @tutorialAudioStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Acesse a **partitura vinculada**, adicione **marcadores de áudio**, ative o modo **seguir o áudio** no leitor e ajuste a **velocidade de reprodução**.'**
  String get tutorialAudioStep2Message;

  /// No description provided for @tutorialAudioStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Barra de Progresso'**
  String get tutorialAudioStep3Title;

  /// No description provided for @tutorialAudioStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe o **tempo atual**, a **duração total** e arraste a barra para avançar ou retroceder. Os **marcadores** cadastrados aparecem destacados na linha do tempo.'**
  String get tutorialAudioStep3Message;

  /// No description provided for @tutorialAudioStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Controles de Reprodução'**
  String get tutorialAudioStep4Title;

  /// No description provided for @tutorialAudioStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Controle o áudio com **Play/Pause**, pule para a **faixa anterior ou seguinte** e avance ou retroceder rapidamente em **10 segundos**.'**
  String get tutorialAudioStep4Message;

  /// No description provided for @tutorialAudioStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Marcadores de Estudo'**
  String get tutorialAudioStep5Title;

  /// No description provided for @tutorialAudioStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Veja todos os **marcadores com marcação de tempo** adicionados à faixa. Toque em qualquer marcador para ir direto àquele ponto do ensaio.'**
  String get tutorialAudioStep5Message;

  /// No description provided for @tutorialAudioStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialAudioStep6Title;

  /// No description provided for @tutorialAudioStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre o reprodutor de áudio, toque neste **ícone (i)** para rever este tutorial passo a passo!'**
  String get tutorialAudioStep6Message;

  /// No description provided for @tutorialCarouselSelectionStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Reordenar Repertório'**
  String get tutorialCarouselSelectionStep1Title;

  /// No description provided for @tutorialCarouselSelectionStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Segure e arraste o ícone de **alça de ordenação** para mudar a sequência dos louvores em tempo real durante o culto ou ensaio.'**
  String get tutorialCarouselSelectionStep1Message;

  /// No description provided for @tutorialCarouselSelectionStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Navegação Rápida'**
  String get tutorialCarouselSelectionStep2Title;

  /// No description provided for @tutorialCarouselSelectionStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no **corpo do louvor** para saltar imediatamente para ele no leitor de partituras ou cifras ativo.'**
  String get tutorialCarouselSelectionStep2Message;

  /// No description provided for @tutorialCarouselSelectionStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Remover da Seleção'**
  String get tutorialCarouselSelectionStep3Title;

  /// No description provided for @tutorialCarouselSelectionStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no botão **×** para retirar o louvor da lista temporária de culto sem apagar suas playlists salvas.'**
  String get tutorialCarouselSelectionStep3Message;

  /// No description provided for @tutorialCarouselSelectionStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Limpar ou Reiniciar Lista'**
  String get tutorialCarouselSelectionStep4Title;

  /// No description provided for @tutorialCarouselSelectionStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Use esta ação para **limpar a lista ativa** e iniciar uma nova seleção do zero ou descartar o rascunho atual.'**
  String get tutorialCarouselSelectionStep4Message;

  /// No description provided for @tutorialCarouselSelectionStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda da Lista Ativa'**
  String get tutorialCarouselSelectionStep5Title;

  /// No description provided for @tutorialCarouselSelectionStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte este **guia rápido** sempre que tiver dúvidas sobre como reorganizar e operar seu repertório.'**
  String get tutorialCarouselSelectionStep5Message;

  /// No description provided for @tutorialChordsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Transposição de Tom'**
  String get tutorialChordsStep1Title;

  /// No description provided for @tutorialChordsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Suba ou desça o tom da música em **semitons** usando os botões **+** e **-** (ou pelo teclado). Toque no número do tom para **restaurar o tom original**.'**
  String get tutorialChordsStep1Message;

  /// No description provided for @tutorialChordsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Tamanho da Fonte'**
  String get tutorialChordsStep2Title;

  /// No description provided for @tutorialChordsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste o **tamanho do texto** e das cifras para melhor leitura na sua tela através dos botões de **diminuir** e **aumentar fonte**.'**
  String get tutorialChordsStep2Message;

  /// No description provided for @tutorialChordsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Rolagem Automática'**
  String get tutorialChordsStep3Title;

  /// No description provided for @tutorialChordsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Inicie a **rolagem automática** (tecla **S**) para acompanhar a música sem usar as mãos. Ajuste a **velocidade** no ícone de velocímetro ou pelas teclas **[** e **]**.'**
  String get tutorialChordsStep3Message;

  /// No description provided for @tutorialChordsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Tema e Tela Cheia'**
  String get tutorialChordsStep4Title;

  /// No description provided for @tutorialChordsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne entre o **modo claro e escuro** para melhor visibilidade no ambiente, e use **tela cheia** (tecla **F**) para focar exclusivamente na cifra.'**
  String get tutorialChordsStep4Message;

  /// No description provided for @tutorialChordsStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Leitura e Diagramação'**
  String get tutorialChordsStep5Title;

  /// No description provided for @tutorialChordsStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Em telas largas a **cifra** é diagramada automaticamente em **duas colunas**. Ao tocar ou rolar manualmente na tela, o autoscroll é **pausado automaticamente**.'**
  String get tutorialChordsStep5Message;

  /// No description provided for @tutorialChordsStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialChordsStep6Title;

  /// No description provided for @tutorialChordsStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que quiser rever este guia ou tirar dúvidas sobre o uso do Leitor de Cifras, toque neste **ícone (i)**!'**
  String get tutorialChordsStep6Message;

  /// No description provided for @tutorialCollaborationDialogsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Folheto Ilustrado'**
  String get tutorialCollaborationDialogsStep1Title;

  /// No description provided for @tutorialCollaborationDialogsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Gera e compartilha uma **imagem visual com a lista dos louvores** acompanhada do link direto para visualização.'**
  String get tutorialCollaborationDialogsStep1Message;

  /// No description provided for @tutorialCollaborationDialogsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Link Direto'**
  String get tutorialCollaborationDialogsStep2Title;

  /// No description provided for @tutorialCollaborationDialogsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Copia ou envia apenas o **link encurtado**, ideal para envio rápido em aplicativos de mensagens.'**
  String get tutorialCollaborationDialogsStep2Message;

  /// No description provided for @tutorialCollaborationDialogsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda de Compartilhamento'**
  String get tutorialCollaborationDialogsStep3Title;

  /// No description provided for @tutorialCollaborationDialogsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone para rever as opções de **compartilhamento de repertórios**.'**
  String get tutorialCollaborationDialogsStep3Message;

  /// No description provided for @tutorialCollaborationDialogsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Categoria da Lista'**
  String get tutorialCollaborationDialogsStep4Title;

  /// No description provided for @tutorialCollaborationDialogsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Classifique o repertório como **Evangelização**, **Aprendizado**, **Medleys** ou **Culto Especial** para facilitar a busca por outros irmãos.'**
  String get tutorialCollaborationDialogsStep4Message;

  /// No description provided for @tutorialCollaborationDialogsStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Alcance do Repertório'**
  String get tutorialCollaborationDialogsStep5Title;

  /// No description provided for @tutorialCollaborationDialogsStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Marque como **pontual** para eventos esporádicos ou mantenha desmarcado se for uma seleção **usual para cultos regulares**.'**
  String get tutorialCollaborationDialogsStep5Message;

  /// No description provided for @tutorialCollaborationDialogsStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Publicação na Comunidade'**
  String get tutorialCollaborationDialogsStep6Title;

  /// No description provided for @tutorialCollaborationDialogsStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Publicar** para disponibilizar a lista na aba pública. A lista poderá ser acessada e importada por toda a igreja.'**
  String get tutorialCollaborationDialogsStep6Message;

  /// No description provided for @tutorialCollaborationDialogsStep7Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda de Publicação'**
  String get tutorialCollaborationDialogsStep7Title;

  /// No description provided for @tutorialCollaborationDialogsStep7Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone para rever as instruções sobre a **publicação de repertórios** na comunidade.'**
  String get tutorialCollaborationDialogsStep7Message;

  /// No description provided for @tutorialCollaborationDialogsStep8Title.
  ///
  /// In pt, this message translates to:
  /// **'Código ou Link da Sala'**
  String get tutorialCollaborationDialogsStep8Title;

  /// No description provided for @tutorialCollaborationDialogsStep8Message.
  ///
  /// In pt, this message translates to:
  /// **'Digite ou cole o **código de 7 caracteres** ou a **URL completa** fornecida pelo dirigente da sala ao vivo.'**
  String get tutorialCollaborationDialogsStep8Message;

  /// No description provided for @tutorialCollaborationDialogsStep9Title.
  ///
  /// In pt, this message translates to:
  /// **'Colar da Área de Transferência'**
  String get tutorialCollaborationDialogsStep9Title;

  /// No description provided for @tutorialCollaborationDialogsStep9Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Colar** para preencher instantaneamente com o link que você acabou de copiar no WhatsApp ou mensagem.'**
  String get tutorialCollaborationDialogsStep9Message;

  /// No description provided for @tutorialCollaborationDialogsStep10Title.
  ///
  /// In pt, this message translates to:
  /// **'Conectar à Sala'**
  String get tutorialCollaborationDialogsStep10Title;

  /// No description provided for @tutorialCollaborationDialogsStep10Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Entrar** para ingressar na transmissão e acompanhar as **mudanças de louvor em tempo real**.'**
  String get tutorialCollaborationDialogsStep10Message;

  /// No description provided for @tutorialCollaborationDialogsStep11Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda da Sala ao Vivo'**
  String get tutorialCollaborationDialogsStep11Title;

  /// No description provided for @tutorialCollaborationDialogsStep11Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone para rever as instruções de **sincronização como seguidor** de uma sala ao vivo.'**
  String get tutorialCollaborationDialogsStep11Message;

  /// No description provided for @tutorialContributeStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Contexto do Envio'**
  String get tutorialContributeStep1Title;

  /// No description provided for @tutorialContributeStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Identifique se sua colaboração está **vinculada a um louvor específico** ou se é uma **sugestão geral** para o aplicativo.'**
  String get tutorialContributeStep1Message;

  /// No description provided for @tutorialContributeStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Descrição da Sugestão'**
  String get tutorialContributeStep2Title;

  /// No description provided for @tutorialContributeStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Descreva detalhadamente o **problema encontrado**, **correção de letra ou tom**, ou a **melhoria** que você gostaria de propor.'**
  String get tutorialContributeStep2Message;

  /// No description provided for @tutorialContributeStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Diagnóstico do Aparelho'**
  String get tutorialContributeStep3Title;

  /// No description provided for @tutorialContributeStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Mantenha ativado para enviar **dados técnicos anônimos** (sistema, navegador, resolução), acelerando a resolução de bugs.'**
  String get tutorialContributeStep3Message;

  /// No description provided for @tutorialContributeStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Anexos e Links'**
  String get tutorialContributeStep4Title;

  /// No description provided for @tutorialContributeStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Adicione **arquivos de apoio** (áudios, partituras ou capturas até 32 MB) e **links** do YouTube ou Google Drive.'**
  String get tutorialContributeStep4Message;

  /// No description provided for @tutorialContributeStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Envio da Contribuição'**
  String get tutorialContributeStep5Title;

  /// No description provided for @tutorialContributeStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Enviar** para submeter seu relato. Se não estiver conectado, entre com sua **conta Google** para enviar.'**
  String get tutorialContributeStep5Message;

  /// No description provided for @tutorialContributeStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialContributeStep6Title;

  /// No description provided for @tutorialContributeStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da tela de envio de sugestões.'**
  String get tutorialContributeStep6Message;

  /// No description provided for @tutorialContributionDetailStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Título e Estado do Envio'**
  String get tutorialContributionDetailStep1Title;

  /// No description provided for @tutorialContributionDetailStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe o **título da contribuição** e seu status atual (**Em análise**, **Aprovada** ou **Recusada**).'**
  String get tutorialContributionDetailStep1Message;

  /// No description provided for @tutorialContributionDetailStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de Contribuição'**
  String get tutorialContributionDetailStep2Title;

  /// No description provided for @tutorialContributionDetailStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Indica a categoria da colaboração enviada, como **Cifra**, **Letra**, **Partitura** ou **Correção de informações**.'**
  String get tutorialContributionDetailStep2Message;

  /// No description provided for @tutorialContributionDetailStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Descrição e Observações'**
  String get tutorialContributionDetailStep3Title;

  /// No description provided for @tutorialContributionDetailStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Aqui você confere o **texto descritivo**, justificativas e links externos adicionados na submissão da proposta.'**
  String get tutorialContributionDetailStep3Message;

  /// No description provided for @tutorialContributionDetailStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Campos Alterados'**
  String get tutorialContributionDetailStep4Title;

  /// No description provided for @tutorialContributionDetailStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Quando a contribuição propõe corrigir dados, veja a comparação direta entre o valor **atual** e o **proposto**.'**
  String get tutorialContributionDetailStep4Message;

  /// No description provided for @tutorialContributionDetailStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Arquivos e Verificação Antivírus'**
  String get tutorialContributionDetailStep5Title;

  /// No description provided for @tutorialContributionDetailStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte a lista de **anexos enviados** e o status da verificação de segurança em tempo real (**Limpa**, **Verificando** ou **Bloqueada**).'**
  String get tutorialContributionDetailStep5Message;

  /// No description provided for @tutorialContributionDetailStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Parecer da Moderação'**
  String get tutorialContributionDetailStep6Title;

  /// No description provided for @tutorialContributionDetailStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Quando a equipe do PLPCG avaliar o envio, o **parecer e justificativa dos revisores** serão exibidos nesta área.'**
  String get tutorialContributionDetailStep6Message;

  /// No description provided for @tutorialContributionDetailStep7Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialContributionDetailStep7Title;

  /// No description provided for @tutorialContributionDetailStep7Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre os detalhes da contribuição, toque neste **ícone (i)** para rever este tutorial passo a passo!'**
  String get tutorialContributionDetailStep7Message;

  /// No description provided for @tutorialExtractedMaterialEditorStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Barra de Ferramentas & Atalhos'**
  String get tutorialExtractedMaterialEditorStep1Title;

  /// No description provided for @tutorialExtractedMaterialEditorStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Utilize os atalhos rápidos para **adicionar versos**, **remover linhas**, **inserir acordes ou anotações** e restaurar o texto original.'**
  String get tutorialExtractedMaterialEditorStep1Message;

  /// No description provided for @tutorialExtractedMaterialEditorStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Área de Edição'**
  String get tutorialExtractedMaterialEditorStep2Title;

  /// No description provided for @tutorialExtractedMaterialEditorStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Edite o conteúdo diretamente. Na cifra, use a sintaxe **[Acorde]** imediatamente antes da sílaba para sincronizar a posição com a letra.'**
  String get tutorialExtractedMaterialEditorStep2Message;

  /// No description provided for @tutorialExtractedMaterialEditorStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Seletor de Gestos CIAs'**
  String get tutorialExtractedMaterialEditorStep3Title;

  /// No description provided for @tutorialExtractedMaterialEditorStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Trocar Gesto** para abrir o dicionário oficial e vincular o movimento e a frase disparadora correspondente.'**
  String get tutorialExtractedMaterialEditorStep3Message;

  /// No description provided for @tutorialExtractedMaterialEditorStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Pré-visualização ao Vivo'**
  String get tutorialExtractedMaterialEditorStep4Title;

  /// No description provided for @tutorialExtractedMaterialEditorStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe as mudanças **em tempo real** com a renderização idêntica à que os usuários verão no leitor de louvores.'**
  String get tutorialExtractedMaterialEditorStep4Message;

  /// No description provided for @tutorialExtractedMaterialEditorStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Submissão da Proposta'**
  String get tutorialExtractedMaterialEditorStep5Title;

  /// No description provided for @tutorialExtractedMaterialEditorStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Adicione observações se desejar e toque em **Enviar** para disponibilizar sua sugestão para revisão pela comunidade.'**
  String get tutorialExtractedMaterialEditorStep5Message;

  /// No description provided for @tutorialExtractedMaterialEditorStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialExtractedMaterialEditorStep6Title;

  /// No description provided for @tutorialExtractedMaterialEditorStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone a qualquer momento para rever este **guia passo a passo** do editor de materiais.'**
  String get tutorialExtractedMaterialEditorStep6Message;

  /// No description provided for @tutorialFavoriteMaterialKindsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Prioridade de Materiais'**
  String get tutorialFavoriteMaterialKindsStep1Title;

  /// No description provided for @tutorialFavoriteMaterialKindsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Defina até **4 materiais favoritos** para priorizar seus instrumentos e vozes no topo dos resultados de busca e no leitor.'**
  String get tutorialFavoriteMaterialKindsStep1Message;

  /// No description provided for @tutorialFavoriteMaterialKindsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Seus Favoritos e Ordem'**
  String get tutorialFavoriteMaterialKindsStep2Title;

  /// No description provided for @tutorialFavoriteMaterialKindsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe seus materiais selecionados. Arraste pela **alça lateral** para definir a prioridade, alterne o **formato preferido** ou toque no **(X)** para remover.'**
  String get tutorialFavoriteMaterialKindsStep2Message;

  /// No description provided for @tutorialFavoriteMaterialKindsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Novos Materiais'**
  String get tutorialFavoriteMaterialKindsStep3Title;

  /// No description provided for @tutorialFavoriteMaterialKindsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Busque por instrumentos (ex: **violão**, **baixo**, **órgão**) ou vozes e toque no ícone **(+)** para adicioná-los à sua lista de prioridades.'**
  String get tutorialFavoriteMaterialKindsStep3Message;

  /// No description provided for @tutorialFavoriteMaterialKindsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Sincronização na Nuvem'**
  String get tutorialFavoriteMaterialKindsStep4Title;

  /// No description provided for @tutorialFavoriteMaterialKindsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Entre com sua **conta Google** para salvar e sincronizar suas preferências de materiais em qualquer aparelho.'**
  String get tutorialFavoriteMaterialKindsStep4Message;

  /// No description provided for @tutorialFavoriteMaterialKindsStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialFavoriteMaterialKindsStep5Title;

  /// No description provided for @tutorialFavoriteMaterialKindsStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre os recursos do aplicativo!'**
  String get tutorialFavoriteMaterialKindsStep5Message;

  /// No description provided for @tutorialFiltersStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Filtro por Tonalidade'**
  String get tutorialFiltersStep1Title;

  /// No description provided for @tutorialFiltersStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Filtre o acervo pela **tonalidade musical** (Dó, Ré, Mi...) e seus acidentes para encontrar louvores no tom exato da sua equipe.'**
  String get tutorialFiltersStep1Message;

  /// No description provided for @tutorialFiltersStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Filtro por Ritmo'**
  String get tutorialFiltersStep2Title;

  /// No description provided for @tutorialFiltersStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Selecione compassos e ritmos específicos como **Valsa**, **Marcha**, **Básico** ou **Toada** para adequar o repertório ao culto.'**
  String get tutorialFiltersStep2Message;

  /// No description provided for @tutorialFiltersStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Categorias e Tags de Culto'**
  String get tutorialFiltersStep3Title;

  /// No description provided for @tutorialFiltersStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Refine os hinos por **ocasião de culto**, como **Comunhão**, **Ceia**, **Crianças** ou momentos devocionais.'**
  String get tutorialFiltersStep3Message;

  /// No description provided for @tutorialFiltersStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Tipos de Materiais'**
  String get tutorialFiltersStep4Title;

  /// No description provided for @tutorialFiltersStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Restrinja os resultados para exibir apenas louvores que possuam **Cifras**, **Partituras**, **Gestos CIAs** ou **Áudios** disponíveis.'**
  String get tutorialFiltersStep4Message;

  /// No description provided for @tutorialFiltersStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Limpar Filtros'**
  String get tutorialFiltersStep5Title;

  /// No description provided for @tutorialFiltersStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Limpar** para redefinir instantaneamente todos os filtros aplicados e visualizar o acervo completo.'**
  String get tutorialFiltersStep5Message;

  /// No description provided for @tutorialFiltersStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda de Filtros'**
  String get tutorialFiltersStep6Title;

  /// No description provided for @tutorialFiltersStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone sempre que desejar rever as orientações sobre como **combinar filtros avançados**.'**
  String get tutorialFiltersStep6Message;

  /// No description provided for @tutorialGestureFocusStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Cartão do Gesto em Destaque'**
  String get tutorialGestureFocusStep1Title;

  /// No description provided for @tutorialGestureFocusStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Visualize o movimento do gesto em **tamanho ampliado**, com animação ou ilustração para fácil acompanhamento pelo regente.'**
  String get tutorialGestureFocusStep1Message;

  /// No description provided for @tutorialGestureFocusStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Frase & Letra Disparadora'**
  String get tutorialGestureFocusStep2Title;

  /// No description provided for @tutorialGestureFocusStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe a letra associada, com destaque em **vermelho no gatilho** em que o gesto deve ser executado pelo grupo de louvor.'**
  String get tutorialGestureFocusStep2Message;

  /// No description provided for @tutorialGestureFocusStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Navegação entre Gestos'**
  String get tutorialGestureFocusStep3Title;

  /// No description provided for @tutorialGestureFocusStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque nas **laterais da tela**, **arraste para os lados** ou use as **setas do teclado (← e →)** para avançar ou retroceder os passos.'**
  String get tutorialGestureFocusStep3Message;

  /// No description provided for @tutorialGestureFocusStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Próximo Gatilho'**
  String get tutorialGestureFocusStep4Title;

  /// No description provided for @tutorialGestureFocusStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte no rodapé a **palavra ou frase do próximo gesto**, preparando a transição antes que ela aconteça.'**
  String get tutorialGestureFocusStep4Message;

  /// No description provided for @tutorialGestureFocusStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda do Modo Foco'**
  String get tutorialGestureFocusStep5Title;

  /// No description provided for @tutorialGestureFocusStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone para rever este **guia passo a passo** ou pressione **Esc** para fechar e retornar ao leitor a qualquer momento.'**
  String get tutorialGestureFocusStep5Message;

  /// No description provided for @tutorialGesturesStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Tamanho da Letra'**
  String get tutorialGesturesStep1Title;

  /// No description provided for @tutorialGesturesStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Aumente ou diminua o **tamanho do texto** dos louvores para uma leitura mais confortável durante o ensaio ou culto.'**
  String get tutorialGesturesStep1Message;

  /// No description provided for @tutorialGesturesStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Rolagem Automática'**
  String get tutorialGesturesStep2Title;

  /// No description provided for @tutorialGesturesStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Ative a **rolagem automática** (tecla **S**) para acompanhar os gestos sem tocar na tela. Ajuste a **velocidade** no velocímetro ou pelas teclas **[** e **]**.'**
  String get tutorialGesturesStep2Message;

  /// No description provided for @tutorialGesturesStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Modo Linear vs. Estruturado'**
  String get tutorialGesturesStep3Title;

  /// No description provided for @tutorialGesturesStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne entre a exibição **estruturada** (agrupada por estrofes e refrões) e a leitura **linear** (sequência contínua com todas as repetições completas).'**
  String get tutorialGesturesStep3Message;

  /// No description provided for @tutorialGesturesStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Tema e Tela Cheia'**
  String get tutorialGesturesStep4Title;

  /// No description provided for @tutorialGesturesStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne entre o **modo claro e escuro** para melhor visibilidade, e use o modo **tela cheia** (tecla **F**) para ocultar barras e focar na execução dos gestos.'**
  String get tutorialGesturesStep4Message;

  /// No description provided for @tutorialGesturesStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Cartões de Gestos'**
  String get tutorialGesturesStep5Title;

  /// No description provided for @tutorialGesturesStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Os gestos aparecem sincronizados com as palavras correspondentes. Toque em qualquer **cartão de gesto** para abrir a **visão em foco** com imagem ampliada e descrição detalhada.'**
  String get tutorialGesturesStep5Message;

  /// No description provided for @tutorialGesturesStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialGesturesStep6Title;

  /// No description provided for @tutorialGesturesStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre como usar o leitor de gestos, toque neste **ícone (i)** para rever este tutorial passo a passo!'**
  String get tutorialGesturesStep6Message;

  /// No description provided for @tutorialHomeStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisa Inteligente'**
  String get tutorialHomeStep1Title;

  /// No description provided for @tutorialHomeStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Digite o **número** do louvor, o **título** ou um **trecho da letra** para localizá-lo instantaneamente no catálogo.'**
  String get tutorialHomeStep1Message;

  /// No description provided for @tutorialHomeStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Filtros Ativos'**
  String get tutorialHomeStep2Title;

  /// No description provided for @tutorialHomeStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Quando **ativo**, o botão do filtro selecionado ganha **destaque dourado**. O cabeçalho exibe a contagem de **filtros ativos** e você pode tocar em **\"Limpar filtros\"** para desmarcar tudo.'**
  String get tutorialHomeStep2Message;

  /// No description provided for @tutorialHomeStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Filtros Inativos'**
  String get tutorialHomeStep3Title;

  /// No description provided for @tutorialHomeStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Com os filtros **inativos** (desmarcados), a busca abrange **todo o catálogo**. Toque em qualquer botão para **ativá-lo** ou recolha o painel para ganhar espaço.'**
  String get tutorialHomeStep3Message;

  /// No description provided for @tutorialHomeStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Navegação Principal'**
  String get tutorialHomeStep4Title;

  /// No description provided for @tutorialHomeStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne facilmente entre o **Pesquisador** de Louvores, suas **Listas** salvas e o seu **Perfil** de usuário.'**
  String get tutorialHomeStep4Message;

  /// No description provided for @tutorialHomeStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialHomeStep5Title;

  /// No description provided for @tutorialHomeStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre como usar qualquer tela, toque neste **ícone (i)** para rever as explicações passo a passo!'**
  String get tutorialHomeStep5Message;

  /// No description provided for @tutorialLibraryStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Filtros do Catálogo'**
  String get tutorialLibraryStep1Title;

  /// No description provided for @tutorialLibraryStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Refine a biblioteca completa por **tom musical**, **ritmo**, **categorias/tags** ou **tipo de material** (partituras, cifras, áudio). Toque no cabeçalho para **expandir ou recolher** os filtros.'**
  String get tutorialLibraryStep1Message;

  /// No description provided for @tutorialLibraryStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Ordenação do Acervo'**
  String get tutorialLibraryStep2Title;

  /// No description provided for @tutorialLibraryStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne rapidamente a ordem dos louvores entre **\"Por número\"** (código oficial no hinário) ou **\"Por nome\"** (ordem alfabética dos títulos).'**
  String get tutorialLibraryStep2Message;

  /// No description provided for @tutorialLibraryStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Paginação e Exibição'**
  String get tutorialLibraryStep3Title;

  /// No description provided for @tutorialLibraryStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte o **total de louvores** encontrados, selecione a **quantidade de itens por página** (10, 20, 50...) e use as **setas de navegação** para folhear o catálogo.'**
  String get tutorialLibraryStep3Message;

  /// No description provided for @tutorialLibraryStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Cards de Louvor'**
  String get tutorialLibraryStep4Title;

  /// No description provided for @tutorialLibraryStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Cada card apresenta o número, título e detalhes do louvor. Toque nele para acessar diretamente suas **partituras**, **cifras**, **áudios** e **informações completas**.'**
  String get tutorialLibraryStep4Message;

  /// No description provided for @tutorialLibraryStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialLibraryStep5Title;

  /// No description provided for @tutorialLibraryStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre como navegar ou usar a Biblioteca, toque neste **ícone (i)** para rever este guia passo a passo!'**
  String get tutorialLibraryStep5Message;

  /// No description provided for @tutorialLiveRoomStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Código e QR Code da Sala'**
  String get tutorialLiveRoomStep1Title;

  /// No description provided for @tutorialLiveRoomStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Os participantes podem ler este **código QR** com a câmera do celular ou acessar o **link direto** para acompanhar o culto.'**
  String get tutorialLiveRoomStep1Message;

  /// No description provided for @tutorialLiveRoomStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar e Gerenciar'**
  String get tutorialLiveRoomStep2Title;

  /// No description provided for @tutorialLiveRoomStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Copie ou **compartilhe o link** da transmissão com o grupo ou toque em **gerar novo link** caso precise redefinir o acesso.'**
  String get tutorialLiveRoomStep2Message;

  /// No description provided for @tutorialLiveRoomStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Participantes Conectados'**
  String get tutorialLiveRoomStep3Title;

  /// No description provided for @tutorialLiveRoomStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe em tempo real o **número de irmãos** que estão sintonizados e seguindo as cifras e letras na sua sala.'**
  String get tutorialLiveRoomStep3Message;

  /// No description provided for @tutorialLiveRoomStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Finalizar Transmissão'**
  String get tutorialLiveRoomStep4Title;

  /// No description provided for @tutorialLiveRoomStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Encerrar** para concluir a sessão ao vivo com os participantes e retornar para as suas listas.'**
  String get tutorialLiveRoomStep4Message;

  /// No description provided for @tutorialLiveRoomStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Status da Transmissão'**
  String get tutorialLiveRoomStep5Title;

  /// No description provided for @tutorialLiveRoomStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe o andamento da sessão: veja se o líder está **ao vivo**, aguardando o culto ou se a conexão está **sincronizando**.'**
  String get tutorialLiveRoomStep5Message;

  /// No description provided for @tutorialLiveRoomStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Guardar Cópia'**
  String get tutorialLiveRoomStep6Title;

  /// No description provided for @tutorialLiveRoomStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Ao fim do culto, toque em **Guardar cópia** para salvar a lista de louvores executada diretamente nas suas listas pessoais.'**
  String get tutorialLiveRoomStep6Message;

  /// No description provided for @tutorialLiveRoomStep7Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialLiveRoomStep7Title;

  /// No description provided for @tutorialLiveRoomStep7Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone a qualquer momento para rever este **guia passo a passo** da sala ao vivo.'**
  String get tutorialLiveRoomStep7Message;

  /// No description provided for @tutorialLyricsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Tamanho da Letra'**
  String get tutorialLyricsStep1Title;

  /// No description provided for @tutorialLyricsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Aumente ou diminua o **tamanho da fonte** da letra para uma leitura mais confortável durante o ensaio ou culto. Também é possível usar **Ctrl + ↑ / ↓** (ou **Cmd + ↑ / ↓**).'**
  String get tutorialLyricsStep1Message;

  /// No description provided for @tutorialLyricsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Rolagem Automática'**
  String get tutorialLyricsStep2Title;

  /// No description provided for @tutorialLyricsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Ative a **rolagem automática** (tecla **S**) para ler a letra sem tocar na tela. Toque no **velocímetro** para ajustar a velocidade (ou pelas teclas **[** e **]**).'**
  String get tutorialLyricsStep2Message;

  /// No description provided for @tutorialLyricsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Modo Tela Cheia'**
  String get tutorialLyricsStep3Title;

  /// No description provided for @tutorialLyricsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no botão de **tela cheia** (ou tecla **F**) para ocultar todas as barras e focar inteiramente na leitura da letra.'**
  String get tutorialLyricsStep3Message;

  /// No description provided for @tutorialLyricsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Leitura e Seleção de Texto'**
  String get tutorialLyricsStep4Title;

  /// No description provided for @tutorialLyricsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'A letra do louvor fica disponível **completamente offline**. O texto é selecionável para copiar trechos e a rolagem é pausada suavemente ao tocar na tela.'**
  String get tutorialLyricsStep4Message;

  /// No description provided for @tutorialLyricsStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialLyricsStep5Title;

  /// No description provided for @tutorialLyricsStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre como usar o leitor de letras, toque neste **ícone (i)** para rever este tutorial passo a passo!'**
  String get tutorialLyricsStep5Message;

  /// No description provided for @tutorialMaterialSheetStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Formatos Disponíveis'**
  String get tutorialMaterialSheetStep1Title;

  /// No description provided for @tutorialMaterialSheetStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne entre **Partituras**, **Cifras**, **Gestos CIAs**, **Áudios** e vídeos do **YouTube** para escolher o formato ideal para o culto ou ensaio.'**
  String get tutorialMaterialSheetStep1Message;

  /// No description provided for @tutorialMaterialSheetStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar ao Repertório'**
  String get tutorialMaterialSheetStep2Title;

  /// No description provided for @tutorialMaterialSheetStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no botão **+** para incluir este arranjo diretamente na sua lista ativa do **Carrossel de culto** ou em uma de suas **Playlists**.'**
  String get tutorialMaterialSheetStep2Message;

  /// No description provided for @tutorialMaterialSheetStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Metadados e Letra'**
  String get tutorialMaterialSheetStep3Title;

  /// No description provided for @tutorialMaterialSheetStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte a **tonalidade original**, **ritmo**, **categorias de culto** e confira a prévia da letra do louvor.'**
  String get tutorialMaterialSheetStep3Message;

  /// No description provided for @tutorialMaterialSheetStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Versões Relacionadas'**
  String get tutorialMaterialSheetStep4Title;

  /// No description provided for @tutorialMaterialSheetStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Selecione rapidamente **arranjos alternativos**, versões com outras tonalidades ou hinos correlacionados ao louvor selecionado.'**
  String get tutorialMaterialSheetStep4Message;

  /// No description provided for @tutorialMaterialSheetStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Sugerir Melhoria'**
  String get tutorialMaterialSheetStep5Title;

  /// No description provided for @tutorialMaterialSheetStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Encontrou alguma divergência na cifra, letra ou partitura? Toque aqui para enviar uma **sugestão de correção** aos curadores.'**
  String get tutorialMaterialSheetStep5Message;

  /// No description provided for @tutorialMaterialSheetStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda deste Seletor'**
  String get tutorialMaterialSheetStep6Title;

  /// No description provided for @tutorialMaterialSheetStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque neste ícone sempre que precisar de orientação sobre como **escolher materiais** e **organizar o repertório**.'**
  String get tutorialMaterialSheetStep6Message;

  /// No description provided for @tutorialMyContributionsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Identificação Necessária'**
  String get tutorialMyContributionsStep1Title;

  /// No description provided for @tutorialMyContributionsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Faça login com sua **conta Google** para acessar o histórico de sugestões, correções e materiais que você enviou.'**
  String get tutorialMyContributionsStep1Message;

  /// No description provided for @tutorialMyContributionsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum Envio Ainda'**
  String get tutorialMyContributionsStep2Title;

  /// No description provided for @tutorialMyContributionsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Todas as **sugestões de letras, partituras ou correções** enviadas por você através do botão **Contribuir** aparecerão listadas nesta tela.'**
  String get tutorialMyContributionsStep2Message;

  /// No description provided for @tutorialMyContributionsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Histórico de Envios'**
  String get tutorialMyContributionsStep3Title;

  /// No description provided for @tutorialMyContributionsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Visualize o título, tipo de material e data da sua colaboração. Toque em qualquer linha para abrir a **tela de detalhes** e ver anotações da equipe.'**
  String get tutorialMyContributionsStep3Message;

  /// No description provided for @tutorialMyContributionsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Status da Análise'**
  String get tutorialMyContributionsStep4Title;

  /// No description provided for @tutorialMyContributionsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe o andamento da sua solicitação: **pendente**, **em análise**, **aprovada** ou **rejeitada**.'**
  String get tutorialMyContributionsStep4Message;

  /// No description provided for @tutorialMyContributionsStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialMyContributionsStep5Title;

  /// No description provided for @tutorialMyContributionsStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no **ícone (i)** a qualquer momento para rever este guia ou aprender mais sobre as telas do aplicativo!'**
  String get tutorialMyContributionsStep5Message;

  /// No description provided for @tutorialOfflineStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Status e Uso de Disco'**
  String get tutorialOfflineStep1Title;

  /// No description provided for @tutorialOfflineStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe o total de louvores no **catálogo local**, a data da **última sincronização** e o **espaço ocupado e livre** no aparelho. Toque em **Atualizar** para recalcular os dados.'**
  String get tutorialOfflineStep1Message;

  /// No description provided for @tutorialOfflineStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisa de Materiais'**
  String get tutorialOfflineStep2Title;

  /// No description provided for @tutorialOfflineStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Use o campo de busca para encontrar rapidamente tipos específicos de partituras ou cifras (ex: **violão**, **coletânea**, **coral**) e ative **Filtrar** para exibir apenas os resultados correspondentes.'**
  String get tutorialOfflineStep2Message;

  /// No description provided for @tutorialOfflineStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Seleção de Formatos'**
  String get tutorialOfflineStep3Title;

  /// No description provided for @tutorialOfflineStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Selecione os **tipos de materiais** que você deseja manter disponíveis offline. Em cada item é possível alternar individualmente entre **partitura (PDF)**, **cifra** e **áudio**.'**
  String get tutorialOfflineStep3Message;

  /// No description provided for @tutorialOfflineStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Baixar e Gerenciar Espaço'**
  String get tutorialOfflineStep4Title;

  /// No description provided for @tutorialOfflineStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque em **Baixar selecionados** para salvar os arquivos no aparelho para uso sem internet. Quando precisar liberar espaço em disco, toque em **Remover downloads**.'**
  String get tutorialOfflineStep4Message;

  /// No description provided for @tutorialOfflineStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialOfflineStep5Title;

  /// No description provided for @tutorialOfflineStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre o armazenamento offline, toque neste **ícone (i)** para rever este tutorial passo a passo!'**
  String get tutorialOfflineStep5Message;

  /// No description provided for @tutorialPlaylistsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Abas de Repertório'**
  String get tutorialPlaylistsStep1Title;

  /// No description provided for @tutorialPlaylistsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne entre suas listas **Não Salvas** (seleções rápidas de ensaio), listas **Salvas** (repertórios guardados e sincronizados) e **Favoritas** (para acesso rápido).'**
  String get tutorialPlaylistsStep1Message;

  /// No description provided for @tutorialPlaylistsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Importar Lista'**
  String get tutorialPlaylistsStep2Title;

  /// No description provided for @tutorialPlaylistsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Recebeu uma lista compartilhada? Toque em **Importar lista** e cole o link ou código recebido para carregar os louvores no seu aplicativo.'**
  String get tutorialPlaylistsStep2Message;

  /// No description provided for @tutorialPlaylistsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Sala ao Vivo'**
  String get tutorialPlaylistsStep3Title;

  /// No description provided for @tutorialPlaylistsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Abra uma sala ou conecte-se ao ensaio da igreja. Todos os músicos acompanham a **troca de louvores em tempo real** durante a ministração.'**
  String get tutorialPlaylistsStep3Message;

  /// No description provided for @tutorialPlaylistsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Criar Novas Listas'**
  String get tutorialPlaylistsStep4Title;

  /// No description provided for @tutorialPlaylistsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Para montar uma nova lista, vá ao **Pesquisador** e toque no botão **\"+\"** de qualquer louvor ou versão de partitura.'**
  String get tutorialPlaylistsStep4Message;

  /// No description provided for @tutorialPlaylistsStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialPlaylistsStep5Title;

  /// No description provided for @tutorialPlaylistsStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar qualquer tela do aplicativo!'**
  String get tutorialPlaylistsStep5Message;

  /// No description provided for @tutorialPraiseStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Informações do Louvor'**
  String get tutorialPraiseStep1Title;

  /// No description provided for @tutorialPraiseStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Veja o **número** e o **título** do louvor. Toque em **Compartilhar** para copiar o link direto ou em **Sugerir melhoria** para nos enviar correções.'**
  String get tutorialPraiseStep1Message;

  /// No description provided for @tutorialPraiseStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Versões Relacionadas'**
  String get tutorialPraiseStep2Title;

  /// No description provided for @tutorialPraiseStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Quando houver diferentes **arranjos, tonalidades ou variantes**, você pode alternar facilmente entre elas tocando nos botões de louvores relacionados.'**
  String get tutorialPraiseStep2Message;

  /// No description provided for @tutorialPraiseStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Materiais e Partituras'**
  String get tutorialPraiseStep3Title;

  /// No description provided for @tutorialPraiseStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Acesse todas as **partituras**, **cifras**, **gestos** e **áudios** disponíveis para este louvor. Toque em um item para abrir ou no **+** para adicioná-lo à sua lista ativa.'**
  String get tutorialPraiseStep3Message;

  /// No description provided for @tutorialPraiseStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Letra e Metadados'**
  String get tutorialPraiseStep4Title;

  /// No description provided for @tutorialPraiseStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Consulte a **letra completa** do louvor, ajuste o tamanho da fonte, copie o texto ou toque no botão de reprodução para abrir no **leitor dedicado** com rolagem automática.'**
  String get tutorialPraiseStep4Message;

  /// No description provided for @tutorialPraiseStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialPraiseStep5Title;

  /// No description provided for @tutorialPraiseStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Sempre que tiver dúvidas sobre os detalhes do louvor, toque neste **ícone (i)** para rever este tutorial passo a passo!'**
  String get tutorialPraiseStep5Message;

  /// No description provided for @tutorialProfileStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Conta & Sincronização'**
  String get tutorialProfileStep1Title;

  /// No description provided for @tutorialProfileStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Conecte sua conta **Google** para sincronizar suas **listas de louvores**, preferências e materiais favoritos automaticamente entre seus aparelhos.'**
  String get tutorialProfileStep1Message;

  /// No description provided for @tutorialProfileStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Biblioteca Completa'**
  String get tutorialProfileStep2Title;

  /// No description provided for @tutorialProfileStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Acesse a **Biblioteca** para explorar o catálogo completo em formato de **lista paginada**, com filtros detalhados de instrumentos e categorias.'**
  String get tutorialProfileStep2Message;

  /// No description provided for @tutorialProfileStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Contribuir'**
  String get tutorialProfileStep3Title;

  /// No description provided for @tutorialProfileStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Envie **novas partituras**, cifras, gestos ou correções de letras. A colaboração da irmandade mantém o acervo sempre atualizado e preciso!'**
  String get tutorialProfileStep3Message;

  /// No description provided for @tutorialProfileStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Modo Offline'**
  String get tutorialProfileStep4Title;

  /// No description provided for @tutorialProfileStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Baixe os arquivos de partituras e letras para usar o aplicativo **sem internet** durante cultos e ensaios com total rapidez.'**
  String get tutorialProfileStep4Message;

  /// No description provided for @tutorialProfileStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialProfileStep5Title;

  /// No description provided for @tutorialProfileStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no ícone **(i)** sempre que quiser rever as instruções e dicas desta tela!'**
  String get tutorialProfileStep5Message;

  /// No description provided for @tutorialPublicPlaylistsStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Seu Nome de Usuário'**
  String get tutorialPublicPlaylistsStep1Title;

  /// No description provided for @tutorialPublicPlaylistsStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Faça login com sua conta Google e crie seu **@usuário** para compartilhar suas próprias listas públicas com a igreja.'**
  String get tutorialPublicPlaylistsStep1Message;

  /// No description provided for @tutorialPublicPlaylistsStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Buscar Irmãos e Equipes'**
  String get tutorialPublicPlaylistsStep2Title;

  /// No description provided for @tutorialPublicPlaylistsStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Digite o **@usuário** de outros membros da equipe para localizar suas listas públicas e repertórios compartilhados.'**
  String get tutorialPublicPlaylistsStep2Message;

  /// No description provided for @tutorialPublicPlaylistsStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Listas e Importação'**
  String get tutorialPublicPlaylistsStep3Title;

  /// No description provided for @tutorialPublicPlaylistsStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Nos resultados, visualize as listas publicadas e toque em **importar** para adicionar os louvores à sua lista ativa.'**
  String get tutorialPublicPlaylistsStep3Message;

  /// No description provided for @tutorialPublicPlaylistsStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialPublicPlaylistsStep4Title;

  /// No description provided for @tutorialPublicPlaylistsStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no **ícone (i)** a qualquer momento para rever este guia passo a passo!'**
  String get tutorialPublicPlaylistsStep4Message;

  /// No description provided for @tutorialReaderStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste de Tela'**
  String get tutorialReaderStep1Title;

  /// No description provided for @tutorialReaderStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Alterne entre ajustar à **largura da tela** (ótimo para ampliar a partitura) ou à **página inteira**. Você também pode pressionar a tecla **Z**.'**
  String get tutorialReaderStep1Message;

  /// No description provided for @tutorialReaderStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'Modo Tela Cheia'**
  String get tutorialReaderStep2Title;

  /// No description provided for @tutorialReaderStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque para ocultar todas as barras e **focar na partitura** durante o ensaio ou culto. Use a tecla **F** para entrar ou **Esc** para sair.'**
  String get tutorialReaderStep2Message;

  /// No description provided for @tutorialReaderStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'Indicador de Páginas'**
  String get tutorialReaderStep3Title;

  /// No description provided for @tutorialReaderStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Exibe a **página atual** e o **total de páginas**. Toque para saltar de página ou **segure o toque** para voltar direto à **primeira página**!'**
  String get tutorialReaderStep3Message;

  /// No description provided for @tutorialReaderStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'Toque nas Bordas (Laterais)'**
  String get tutorialReaderStep4Title;

  /// No description provided for @tutorialReaderStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no **quinto lateral esquerdo** para voltar e no **quinto lateral direito** para avançar páginas instantaneamente, sem precisar arrastar a partitura.'**
  String get tutorialReaderStep4Message;

  /// No description provided for @tutorialReaderStep5Title.
  ///
  /// In pt, this message translates to:
  /// **'Pedais Bluetooth & Teclado'**
  String get tutorialReaderStep5Title;

  /// No description provided for @tutorialReaderStep5Message.
  ///
  /// In pt, this message translates to:
  /// **'Conecte qualquer **pedal virador de página Bluetooth** (AirTurn, PageFlip, Donner via PageUp/Down ou Setas) para avançar e trocar de louvor **sem tirar as mãos do instrumento**.'**
  String get tutorialReaderStep5Message;

  /// No description provided for @tutorialReaderStep6Title.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda & Tutoriais'**
  String get tutorialReaderStep6Title;

  /// No description provided for @tutorialReaderStep6Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no ícone **(i)** sempre que tiver dúvidas sobre como utilizar as ferramentas do leitor!'**
  String get tutorialReaderStep6Message;

  /// No description provided for @tutorialWelcomeTourStep1Title.
  ///
  /// In pt, this message translates to:
  /// **'1. Pesquise no Hinário'**
  String get tutorialWelcomeTourStep1Title;

  /// No description provided for @tutorialWelcomeTourStep1Message.
  ///
  /// In pt, this message translates to:
  /// **'Digite o **número**, o **título** ou qualquer **trecho da letra** para localizar instantaneamente hinos e cânticos no acervo.'**
  String get tutorialWelcomeTourStep1Message;

  /// No description provided for @tutorialWelcomeTourStep2Title.
  ///
  /// In pt, this message translates to:
  /// **'2. Formatos Especializados'**
  String get tutorialWelcomeTourStep2Title;

  /// No description provided for @tutorialWelcomeTourStep2Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no louvor para selecionar entre **Partitura**, **Cifra**, **Gestos para Crianças** ou **Letra**, com transposição de tom e autoscroll.'**
  String get tutorialWelcomeTourStep2Message;

  /// No description provided for @tutorialWelcomeTourStep3Title.
  ///
  /// In pt, this message translates to:
  /// **'3. Monte seu Repertório de Culto'**
  String get tutorialWelcomeTourStep3Title;

  /// No description provided for @tutorialWelcomeTourStep3Message.
  ///
  /// In pt, this message translates to:
  /// **'Toque no botão **(+)** para incluir louvores no **Carrossel Ativo**, permitindo alternar rapidamente entre partituras durante a ministração.'**
  String get tutorialWelcomeTourStep3Message;

  /// No description provided for @tutorialWelcomeTourStep4Title.
  ///
  /// In pt, this message translates to:
  /// **'4. Repertório Sempre com Você'**
  String get tutorialWelcomeTourStep4Title;

  /// No description provided for @tutorialWelcomeTourStep4Message.
  ///
  /// In pt, this message translates to:
  /// **'Acesse a aba **Listas** para organizar playlists de ensaio e abra o **Armazenamento Offline** no Perfil para louvar **sem internet** em qualquer lugar!'**
  String get tutorialWelcomeTourStep4Message;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyAboutDescription.
  ///
  /// In pt, this message translates to:
  /// **'Saiba como protegemos seus dados e sua privacidade.'**
  String get privacyPolicyAboutDescription;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In pt, this message translates to:
  /// **'Excluir conta'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountDialogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir conta e dados?'**
  String get profileDeleteAccountDialogTitle;

  /// No description provided for @profileDeleteAccountDialogContent.
  ///
  /// In pt, this message translates to:
  /// **'Esta ação é irreversível. Sua conta, playlists sincronizadas, marcações e preferências serão permanentemente excluídas dos servidores do PLPCG.'**
  String get profileDeleteAccountDialogContent;

  /// No description provided for @profileDeleteAccountConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Excluir definitivamente'**
  String get profileDeleteAccountConfirm;

  /// No description provided for @profileDeleteAccountSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Sua conta e todos os dados foram excluídos com sucesso.'**
  String get profileDeleteAccountSuccess;

  /// No description provided for @profileDeleteAccountError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível excluir sua conta. Verifique sua conexão e tente novamente.'**
  String get profileDeleteAccountError;
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
