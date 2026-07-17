// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PLPCG';

  @override
  String get searchHint => 'Search by number or title';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchClear => 'Clear search';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersTapToExpand => 'Tap to see more';

  @override
  String get sharePdf => 'Share';

  @override
  String get savePdf => 'Download';

  @override
  String get pdfShareSuccess => 'PDF ready to share';

  @override
  String get pdfSaveSuccess => 'PDF saved successfully';

  @override
  String get pdfActionError => 'Could not complete the action';

  @override
  String get louvorPdfDownloading => 'Downloading...';

  @override
  String louvorPdfDownloadingWithProgress(int percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryViewTitle => 'View';

  @override
  String get sortByLabel => 'Sort by';

  @override
  String get sortByNumber => 'Number';

  @override
  String get sortByName => 'Name';

  @override
  String get itemsPerPage => 'Items per page';

  @override
  String itemsPerPageValue(int count) {
    return '$count per page';
  }

  @override
  String get pagePrevious => 'Previous';

  @override
  String get pageNext => 'Next';

  @override
  String pageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String pageCurrent(int page) {
    return 'Page $page';
  }

  @override
  String get specialArrangementPadrao => 'Default';

  @override
  String get filtersSpecialArrangementTitle => 'Special arrangement';

  @override
  String get catalogRefreshAction => 'Update list';

  @override
  String get catalogRefreshLabel => 'Catalog';

  @override
  String get catalogRefreshMessage => 'Download the latest catalog';

  @override
  String get catalogRefreshSuccess => 'Catalog updated';

  @override
  String get catalogRefreshError => 'Could not update the catalog';

  @override
  String get catalogStaleBanner =>
      'Catalog last updated over 7 days ago. Connect to refresh.';

  @override
  String get catalogLoadError => 'Could not load the catalog';

  @override
  String libraryResultsSummary(int from, int to, int total) {
    return 'Showing $from–$to of $total hymns';
  }

  @override
  String get libraryResultsEmpty => 'No hymns match the current filters';

  @override
  String get libraryCatalogModeLabel => 'Source';

  @override
  String get libraryCatalogModePlpcg => 'PLPCG';

  @override
  String get libraryCatalogModeColdigom => 'Coldigom';

  @override
  String get coldigomFilterTonality => 'Key';

  @override
  String get coldigomFilterRhythm => 'Rhythm';

  @override
  String get coldigomFilterCategory => 'Category';

  @override
  String get coldigomFilterTags => 'Tags';

  @override
  String get coldigomFilterMaterials => 'Materials';

  @override
  String get coldigomLoadError => 'Could not load the Coldigom catalog';

  @override
  String get offlineTitle => 'Offline';

  @override
  String get offlineSelectCategories => 'Select categories';

  @override
  String get offlineDownloadSelected => 'Download selected';

  @override
  String get offlineStopDownload => 'Stop';

  @override
  String get offlineStoppingDownload => 'Stopping...';

  @override
  String get offlineCancelDownload => 'Cancel';

  @override
  String get offlineResumeBanner => 'An offline download was interrupted.';

  @override
  String get offlineResumeDownload => 'Resume';

  @override
  String get offlineDismissCheckpoint => 'Dismiss';

  @override
  String get offlineDownloadCompleted => 'Offline download completed';

  @override
  String get offlineDownloadError => 'Could not complete offline download';

  @override
  String get offlineDownloadTimeout =>
      'Slow connection. Tap Resume when the network improves.';

  @override
  String get offlineDownloadNetworkError =>
      'No connection. Check your internet and resume.';

  @override
  String get offlineKeepAppOpenDuringDownload =>
      'Keep the app open while downloading.';

  @override
  String get offlineInsufficientDiskSpace =>
      'Not enough disk space for download';

  @override
  String get offlinePhaseFetching => 'downloading';

  @override
  String get offlinePhaseExtracting => 'extracting';

  @override
  String get offlinePhaseStoring => 'storing';

  @override
  String get offlinePhaseSyncing => 'syncing';

  @override
  String offlineProgressDetail(
    String category,
    int part,
    int totalParts,
    int done,
    int total,
    String phase,
  ) {
    return '$category — part $part/$totalParts — $done/$total PDFs ($phase)';
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
    return 'Downloading package $part/$totalParts — $received / $total';
  }

  @override
  String get offlineStatsTitle => 'Stored PDFs';

  @override
  String offlineStatsTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offline PDFs',
      one: '1 offline PDF',
      zero: 'No offline PDFs',
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
    return '$category: $downloaded ($missing missing)';
  }

  @override
  String offlineStatsTotalMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs missing in total',
      one: '1 PDF missing in total',
    );
    return '$_temp0';
  }

  @override
  String get offlineStatsMissingUnreliable =>
      'Missing count unavailable (offline)';

  @override
  String offlineStatsDiskUsage(String used, String free) {
    return 'Offline library: $used | Available: $free';
  }

  @override
  String offlineStatsDiskUsageUsedOnly(String used) {
    return 'Offline library: $used';
  }

  @override
  String offlineStatsCategoryUnreliableMissing(
    String category,
    int downloaded,
  ) {
    return '$category: $downloaded (— missing, offline)';
  }

  @override
  String get offlineRefreshStats => 'Refresh';

  @override
  String get offlineRefreshSuccess => 'Offline info updated';

  @override
  String get offlineRefreshError => 'Could not update offline info';

  @override
  String offlineRemovedBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs are no longer available locally',
      one: '1 PDF is no longer available locally',
    );
    return '$_temp0';
  }

  @override
  String get offlineDownloadMissing => 'Download missing';

  @override
  String offlineMissingLouvoresSheetTitle(String category) {
    return '$category — missing';
  }

  @override
  String get offlineMissingLouvoresEmpty => 'No missing PDFs in this category';

  @override
  String get offlineMissingLouvoresLoadError => 'Could not load missing PDFs';

  @override
  String get offlineDismissRemoved => 'Dismiss';

  @override
  String get offlineClearCache => 'Clear offline cache';

  @override
  String get offlineClearCacheConfirmTitle => 'Clear offline cache?';

  @override
  String offlineClearCacheConfirmBody(String categories) {
    return 'Downloaded PDFs for $categories will be removed. This action cannot be undone.';
  }

  @override
  String get offlineClearCacheConfirmBodyAll =>
      'All offline PDFs will be removed. This action cannot be undone.';

  @override
  String get offlineClearCacheConfirm => 'Clear';

  @override
  String get offlineClearCacheCancel => 'Cancel';

  @override
  String get offlineClearCacheSuccess => 'Offline cache cleared';

  @override
  String offlineClearCacheSuccessPartial(String categories) {
    return 'Cache cleared for $categories';
  }

  @override
  String offlineMissingProgress(int done, int total) {
    return 'Downloading missing: $done/$total';
  }

  @override
  String offlineMissingCompleted(int downloaded, int failed) {
    return 'Download complete: $downloaded downloaded, $failed failed';
  }

  @override
  String get offlineMissingError => 'Could not download missing PDFs';

  @override
  String get pdfOfflineUnavailableMessage =>
      'This PDF was not downloaded for offline use. Connect to the internet or go to Offline Settings → Download Missing.';

  @override
  String get pdfOfflineGoToSettings => 'Download';

  @override
  String get pdfOfflinePersistentTooltip =>
      'Available offline (guaranteed download)';

  @override
  String get pdfOfflineCachedLruTooltip =>
      'Temporary cache — may be removed to free space';

  @override
  String get carouselClear => 'Clear selection';

  @override
  String get carouselClearConfirmTitle => 'Clear selection?';

  @override
  String get carouselClearConfirmMessage =>
      'New list clears the selection and keeps the current playlist. Delete list permanently removes the unsaved draft.';

  @override
  String get carouselClearCancel => 'Cancel';

  @override
  String get carouselClearNewList => 'New list';

  @override
  String get carouselClearDeleteList => 'Delete list';

  @override
  String get carouselAdded => 'Added to selection';

  @override
  String get carouselAlreadyAdded => 'Already in selection';

  @override
  String get carouselRemoveTooltip => 'Remove';

  @override
  String get carouselAddTooltip => 'Add to selection';

  @override
  String get carouselSavePlaylist => 'Save as playlist';

  @override
  String get carouselSharePlaylist => 'Share';

  @override
  String get carouselGenerateLeaflet => 'Generate leaflet';

  @override
  String get carouselOverflowMenu => 'More actions';

  @override
  String get carouselOpenList => 'View selection';

  @override
  String get carouselListTitle => 'Temporary selection';

  @override
  String get carouselListClose => 'Close';

  @override
  String get readerCarouselPrevious => 'Previous hymn';

  @override
  String get readerCarouselNext => 'Next hymn';

  @override
  String get readerSwitchMaterial => 'Switch material';

  @override
  String readerCarouselPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get leafletGenerating => 'Generating leaflet…';

  @override
  String get leafletShareSubject => 'PLPCG leaflet';

  @override
  String get leafletGenerateFailed => 'Could not generate leaflet';

  @override
  String get leafletHeaderTitle => 'HYMNS';

  @override
  String get leafletColumnNumber => 'NUMBER';

  @override
  String get leafletColumnName => 'HYMN NAME';

  @override
  String get leafletFooterPeace => 'THE PEACE OF THE LORD JESUS CHRIST';

  @override
  String get leafletFooterGreeting => 'Have a blessed service!';

  @override
  String get leafletWeekdayMonday => 'MONDAY';

  @override
  String get leafletWeekdayTuesday => 'TUESDAY';

  @override
  String get leafletWeekdayWednesday => 'WEDNESDAY';

  @override
  String get leafletWeekdayThursday => 'THURSDAY';

  @override
  String get leafletWeekdayFriday => 'FRIDAY';

  @override
  String get leafletWeekdaySaturday => 'SATURDAY';

  @override
  String get leafletWeekdaySunday => 'SUNDAY';

  @override
  String get playlistSaveTitle => 'Save playlist';

  @override
  String get playlistSaveNameLabel => 'Playlist name';

  @override
  String get playlistSaveCancel => 'Cancel';

  @override
  String get playlistSaveConfirm => 'Save';

  @override
  String get playlistSaved => 'Playlist saved';

  @override
  String get playlistViewLists => 'View playlists';

  @override
  String get playlistEmptyCarousel => 'Selection is empty';

  @override
  String get playlistEmptyList =>
      'No saved playlists. Build a selection on Home or Library and use \"Save as playlist\".';

  @override
  String get playlistRename => 'Rename';

  @override
  String get playlistRenameTitle => 'Rename playlist';

  @override
  String get playlistRenameConfirm => 'Save';

  @override
  String get playlistDelete => 'Delete';

  @override
  String get playlistDeleteConfirmTitle => 'Delete playlist?';

  @override
  String get playlistDeleteConfirmMessage =>
      'This playlist will be permanently removed.';

  @override
  String get playlistFavoriteOn => 'Mark as favorite';

  @override
  String get playlistFavoriteOff => 'Remove from favorites';

  @override
  String playlistPdfCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteLastPdfTitle => 'Remove last song?';

  @override
  String get playlistDeleteLastPdfMessage =>
      'The playlist will be empty and will be deleted.';

  @override
  String get playlistLoadIntoCarousel => 'Load into carousel';

  @override
  String get playlistOpenInReader => 'Open in reader';

  @override
  String get playlistOpenInAudioPlayer => 'Open in audio player';

  @override
  String get playlistFacePdf => 'PDFs';

  @override
  String get playlistFaceAudio => 'Audio';

  @override
  String get playlistFaceToggleSemantics =>
      'Switch playlist face between PDFs and audio';

  @override
  String playlistAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No audio',
    );
    return '$_temp0';
  }

  @override
  String get playlistAudioEmpty => 'This playlist has no audio tracks.';

  @override
  String get audioPlayerTitle => 'Audio';

  @override
  String get audioMaterialSection => 'Audio';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioPrevious => 'Previous';

  @override
  String get audioNext => 'Next';

  @override
  String get audioOpenPlayer => 'Open player';

  @override
  String get audioClosePlayer => 'Close and return to search';

  @override
  String get audioFlagComingSoon => 'Audio flags coming soon';

  @override
  String get audioPlaybackError => 'Could not play this audio.';

  @override
  String get audioWebBackgroundNotice =>
      'On the web, background playback and system controls depend on the browser — this is not an app bug.';

  @override
  String get playlistLoadConfirmTitle => 'Replace selection?';

  @override
  String get playlistLoadConfirmMessage =>
      'The current selection will be replaced with songs from this playlist.';

  @override
  String get playlistLoaded => 'Playlist loaded into carousel';

  @override
  String get playlistEmptyPdfList => 'This playlist has no songs.';

  @override
  String get playlistShare => 'Share';

  @override
  String get playlistImport => 'Import playlist';

  @override
  String get playlistImportTitle => 'Import shared playlist';

  @override
  String get playlistImportUrlLabel => 'Shared URL or link';

  @override
  String get playlistImportPaste => 'Paste';

  @override
  String get playlistImportConfirm => 'Import';

  @override
  String get playlistImported => 'Playlist imported';

  @override
  String get playlistImportInvalidUrl =>
      'Invalid link. Use a URL with sharepdfs and sharename.';

  @override
  String get playlistShareError => 'Could not share the playlist.';

  @override
  String get playlistShareSheetTitle => 'Share';

  @override
  String get playlistShareOptionLink => 'Link only';

  @override
  String get playlistShareOptionLinkSubtitle =>
      'Recipients can import the playlist in PLPCG';

  @override
  String get playlistShareOptionLeaflet => 'Leaflet only';

  @override
  String get playlistShareOptionLeafletSubtitle => 'Image with the hymn list';

  @override
  String get playlistShareOptionLinkWithLeaflet => 'Link with leaflet';

  @override
  String get playlistShareOptionLinkWithLeafletSubtitle =>
      'Image and link in one message';

  @override
  String get playlistShareOptionWhatsApp => 'Link + leaflet';

  @override
  String get playlistShareOptionWhatsAppSubtitle =>
      'For WhatsApp — sends photo then link';

  @override
  String get playlistShareWhatsAppStepTitle => 'Send the link';

  @override
  String get playlistShareWhatsAppStepMessage =>
      'Send the link in the same chat where you sent the leaflet.';

  @override
  String get playlistShareWhatsAppStepContinue => 'Send link';

  @override
  String get playlistShareWhatsAppStepCancel => 'Not now';

  @override
  String playlistShareLinkWithLeafletMessage(String name, String url) {
    return '$name\n\n$url';
  }

  @override
  String get playlistTabUnsaved => 'Unsaved';

  @override
  String get playlistTabSaved => 'Saved';

  @override
  String get playlistTabFavorites => 'Favorites';

  @override
  String get playlistSaveAction => 'Save playlist';

  @override
  String get playlistEmptyUnsaved =>
      'No unsaved playlists. Open a song in the reader to create one automatically.';

  @override
  String get playlistEmptySaved => 'No saved playlists.';

  @override
  String get playlistEmptyFavorites => 'No favorite playlists.';

  @override
  String get playlistDeleteAllUnsaved => 'Delete all';

  @override
  String get playlistDeleteAllUnsavedTitle => 'Delete all unsaved playlists?';

  @override
  String get playlistDeleteAllUnsavedMessage =>
      'All playlists in the Unsaved tab will be permanently removed.';

  @override
  String get playlistDeleteAllUnsavedDone => 'Unsaved playlists deleted';

  @override
  String get playlistPublish => 'Publish';

  @override
  String get playlistPublishTitle => 'Publish playlist?';

  @override
  String get playlistPublishMessage =>
      'Publishing is irreversible. To remove the publication, delete the playlist.';

  @override
  String get playlistPublishConfirm => 'Publish';

  @override
  String get playlistPublishCancel => 'Cancel';

  @override
  String get playlistPublishCategoryLabel => 'Category';

  @override
  String get playlistPublishReachLabel => 'Reach';

  @override
  String get playlistPublishReachUsual => 'Usual';

  @override
  String get playlistPublishReachPontual => 'One-off';

  @override
  String get playlistPublishCategoryRequired => 'Choose a category to publish.';

  @override
  String get playlistPublished => 'Playlist published';

  @override
  String get playlistPublicBadge => 'Public';

  @override
  String get playlistCategoryEvangelizacao => 'Evangelism';

  @override
  String get playlistCategoryAprendizado => 'Learning';

  @override
  String get playlistCategoryMedleys => 'Medleys';

  @override
  String get playlistCategoryCultoEspecial => 'Special service';

  @override
  String get playlistClearSavedBlocked =>
      'Saved playlists cannot be cleared from the bar. Use the playlist menu.';

  @override
  String get playlistOpenLouvorChoiceTitle => 'How to add to the playlist?';

  @override
  String get playlistOpenLouvorChoiceMessage =>
      'This song is not in the current playlist. How would you like to continue?\n\nWhen creating a new playlist, the current one will not be lost — it will remain in Unsaved playlists.';

  @override
  String get playlistOpenLouvorChoiceAddToCurrent => 'Add to current playlist';

  @override
  String get playlistOpenLouvorChoiceCreateNew => 'Create new playlist';

  @override
  String louvorGroupMetadataSummary(int entryCount, int arrangementCount) {
    String _temp0 = intl.Intl.pluralLogic(
      entryCount,
      locale: localeName,
      other: '$entryCount entries',
      one: '1 entry',
    );
    String _temp1 = intl.Intl.pluralLogic(
      arrangementCount,
      locale: localeName,
      other: '$arrangementCount arrangements',
      one: '1 arrangement',
    );
    return '$_temp0 with $_temp1';
  }

  @override
  String get usernameCreateButton => 'Create username';

  @override
  String get usernameCreateTitle => 'Create username';

  @override
  String get usernameCreateMessage =>
      'Choose a unique username for the app. It identifies you and your public playlists. Use 3 to 30 characters: lowercase letters, numbers, or _.';

  @override
  String get usernameCreatePrompt => 'Create a username to publish playlists.';

  @override
  String get usernameFieldLabel => 'Username';

  @override
  String get usernameFieldHint => 'e.g. maria_silva';

  @override
  String get usernameCreateCancel => 'Cancel';

  @override
  String get usernameCreateConfirm => 'Save';

  @override
  String get usernameErrorInvalid => 'Use 3–30 characters: a-z, 0-9, or _.';

  @override
  String get usernameErrorTaken => 'That username is already taken.';

  @override
  String get usernameErrorAlreadySet => 'You already have a username.';

  @override
  String get usernameErrorGeneric => 'Could not save. Please try again.';

  @override
  String get usernameRequiredToPublish => 'Register Username';

  @override
  String get socialSearchHint => 'Search people by username';

  @override
  String get socialSearchEmptyHint => 'Type a username to find people.';

  @override
  String get socialSearchNoResults => 'No people found.';

  @override
  String get socialSearchError => 'Search failed. Please try again.';

  @override
  String get socialSignInRequired => 'Sign in with Google to explore Social.';

  @override
  String socialPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get socialPlaylistsError => 'Could not load playlists.';

  @override
  String get socialPlaylistsEmpty =>
      'This profile has no public playlists yet.';

  @override
  String get socialCategoryOther => 'Other';

  @override
  String socialPlaylistImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs added to your playlist',
      one: '1 song added to your playlist',
    );
    return '$_temp0';
  }

  @override
  String get socialPlaylistImportNone => 'No new songs to add.';
}
