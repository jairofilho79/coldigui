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
  String get searchHint => 'Search by number or title';

  @override
  String get searchLabel => 'Search';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchFreshnessChecking => 'Cached · checking…';

  @override
  String get searchFreshnessUpdated => 'Up to date';

  @override
  String searchFreshnessUpdatedNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to date · $count new',
      one: 'Up to date · 1 new',
    );
    return '$_temp0';
  }

  @override
  String get searchFreshnessOffline => 'Cached · offline';

  @override
  String get searchFreshnessFailed => 'Cached · could not verify';

  @override
  String get searchResultNew => 'new';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersTapToExpand => 'Tap to see more';

  @override
  String filtersActiveCount(int count) {
    return 'Filters ($count)';
  }

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
  String get readerFullscreenTooltip => 'Fullscreen (F)';

  @override
  String get readerExitFullscreenTooltip => 'Exit fullscreen (Esc)';

  @override
  String get readerFitModeTooltip => 'Fit width/page (Z)';

  @override
  String get readerGoToPageTitle => 'Go to page';

  @override
  String get readerGoToPageFieldLabel => 'Page number';

  @override
  String get readerGoToPageCancel => 'Cancel';

  @override
  String get readerGoToPageConfirm => 'Go';

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
  String get catalogLoadError => 'Could not load the catalog';

  @override
  String get retry => 'Try again';

  @override
  String get storagePreparing => 'Preparing local storage…';

  @override
  String get storageUnavailableTitle => 'Local storage unavailable';

  @override
  String get storageUnavailableBody =>
      'This area needs the app\'s local database. The online catalog and the PDF reader are still available on the other tabs.';

  @override
  String libraryResultsSummary(int from, int to, int total) {
    return 'Showing $from–$to of $total hymns';
  }

  @override
  String get libraryResultsEmpty => 'No hymns match the current filters';

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
  String get offlineDownloadCompleted => 'Offline download completed';

  @override
  String offlineDownloadCompletedWithFailures(int failedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      failedCount,
      locale: localeName,
      other: 'Download completed with $failedCount failed files',
      one: 'Download completed with 1 failed file',
    );
    return '$_temp0';
  }

  @override
  String get offlineKeepAppOpenDuringDownload =>
      'Keep the app open while downloading.';

  @override
  String get offlineInsufficientDiskSpace =>
      'Not enough disk space for download';

  @override
  String get offlineStorageUnavailable =>
      'Local storage is unavailable. Reload the page or free up space.';

  @override
  String get offlineMaintenanceBusy =>
      'Another offline operation is running. Try again shortly.';

  @override
  String get offlinePhaseFetching => 'downloading';

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
  String get pdfLocalReadFailedMessage =>
      'Could not read the file. Please try again.';

  @override
  String get pdfExternallyDeleted =>
      'The PDF was removed from this device. Go online or use Offline Settings → Download missing.';

  @override
  String get pdfLocalCorrupted =>
      'The PDF saved on this device is corrupted. Download it again to continue.';

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
  String get materialRemoveTooltip => 'Remove from list';

  @override
  String get materialRemoveConfirmTitle => 'Remove from list?';

  @override
  String materialRemoveConfirmMessage(String name) {
    return '“$name” will leave the active list.';
  }

  @override
  String get materialRemoved => 'Removed from list';

  @override
  String get carouselRemoveTooltip => 'Remove';

  @override
  String get carouselAddTooltip => 'Add to selection';

  @override
  String get carouselSharePlaylist => 'Share';

  @override
  String get carouselGenerateLeaflet => 'Generate leaflet';

  @override
  String get carouselOpen => 'Open';

  @override
  String get carouselMaterial => 'Material';

  @override
  String get carouselList => 'List';

  @override
  String get carouselClearShort => 'Clear';

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
  String get cardAddedSwapMaterial => 'Added to the list';

  @override
  String get cardSwapMaterialAction => 'Switch material';

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
  String get leafletShareQrCaption => 'Open the list in PLPCG';

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
  String get playlistDeletedUndo => 'Playlist removed';

  @override
  String get playlistDuplicate => 'Duplicate';

  @override
  String playlistCopyName(String nome) {
    return '$nome (copy)';
  }

  @override
  String get playlistDraftLabel => 'Draft';

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
  String playlistSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sheets',
      one: '1 sheet',
    );
    return '$_temp0';
  }

  @override
  String playlistAudioOnlyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audios',
      one: '1 audio',
    );
    return '$_temp0';
  }

  @override
  String get playlistEmptyCount => 'Empty';

  @override
  String get playlistDeleteLastPdfTitle => 'Remove last song?';

  @override
  String get playlistDeleteLastPdfMessage =>
      'The playlist will be empty and will be deleted.';

  @override
  String get playlistActivate => 'Edit from here';

  @override
  String get playlistOpenInReader => 'Open in reader';

  @override
  String get playlistOpenInAudioPlayer => 'Open in audio player';

  @override
  String get playlistAudioEmpty => 'This playlist has no audio tracks.';

  @override
  String get audioPlayerTitle => 'Audio';

  @override
  String get pdfMaterialSection => 'Sheet music';

  @override
  String get audioMaterialSection => 'Audio';

  @override
  String get youtubeMaterialSection => 'YouTube';

  @override
  String get chordMaterialSection => 'Chords';

  @override
  String get chordUnavailableRetry => 'Chord sheet unavailable · try again';

  @override
  String get materialNotDownloadedOffline => 'Not downloaded · offline';

  @override
  String get materialNeedsConnection => 'Needs a connection';

  @override
  String get materialSheetOfflineBanner =>
      'Offline · only what is on the device opens';

  @override
  String get playlistStorageUnavailable =>
      'Local storage is unavailable. Playlists can\'t be saved.';

  @override
  String get liveFollowingCannotEdit =>
      'You\'re following someone else\'s list — leave the session to edit yours';

  @override
  String get chordReaderUnavailable => 'Chord chart not available yet';

  @override
  String get chordReaderToggleTheme => 'Toggle reader theme';

  @override
  String get chordReaderIncreaseFont => 'Increase text size';

  @override
  String get chordReaderDecreaseFont => 'Decrease text size';

  @override
  String get chordReaderTransposeUp => 'Transpose up a semitone';

  @override
  String get chordReaderTransposeDown => 'Transpose down a semitone';

  @override
  String get chordReaderResetTranspose => 'Back to original key';

  @override
  String get gestureNotFound => 'gesture not found';

  @override
  String get gesturesMaterialLabel => 'Gestures';

  @override
  String get gesturesMaterialSection => 'Gestures';

  @override
  String get gesturesReaderTitle => 'Gesture reader';

  @override
  String get gesturesReaderEmpty => 'This hymn has no gestures yet';

  @override
  String get gesturesReaderUnavailable => 'Gestures unavailable · try again';

  @override
  String get gesturesReaderIncreaseFont => 'Increase gesture text';

  @override
  String get gesturesReaderDecreaseFont => 'Decrease gesture text';

  @override
  String get gesturesReaderFullscreen => 'Full screen';

  @override
  String get gesturesNewerSchemaWarning =>
      'Document in a newer format; update the app.';

  @override
  String get gestureInstructionInstruments => 'Instruments';

  @override
  String get gestureInstructionRepeatPraise => 'Repeat the hymn';

  @override
  String get gestureInstructionBackToChorus => 'Back to chorus';

  @override
  String get gestureInstructionBackToChorusAndFinish =>
      'Back to chorus and finish';

  @override
  String gestureContextRepeat(int count) {
    return '${count}x';
  }

  @override
  String get gestureContextChorus => 'CHORUS';

  @override
  String get gestureContextFinal => 'END';

  @override
  String get gestureContextLink => 'link';

  @override
  String get gestureFocusNext => 'next:';

  @override
  String get gestureFocusEnd => 'end';

  @override
  String get gestureFocusClose => 'Close';

  @override
  String get gestureSectionChorus => 'chorus';

  @override
  String gestureSectionPass(int n) {
    return 'time $n';
  }

  @override
  String get gesturesReaderToggleTheme => 'Toggle reader theme';

  @override
  String get gesturesReaderLinear => 'Switch to linear reading';

  @override
  String get gesturesReaderStructured => 'Switch to structured reading';

  @override
  String get gesturesAutoscrollPlay => 'Start autoscroll';

  @override
  String get gesturesAutoscrollPause => 'Pause autoscroll';

  @override
  String gesturesAutoscrollSpeed(int speed) {
    return 'Scroll speed: $speed';
  }

  @override
  String get chordAutoscrollPlay => 'Start autoscroll';

  @override
  String get chordAutoscrollPause => 'Pause autoscroll';

  @override
  String chordAutoscrollSpeed(int speed) {
    return 'Scroll speed: $speed';
  }

  @override
  String get coldigomMetaTonality => 'Key';

  @override
  String get coldigomMetaAuthor => 'Author';

  @override
  String get coldigomMetaRhythm => 'Rhythm';

  @override
  String get coldigomMetaCategory => 'Category';

  @override
  String get coldigomMetaTags => 'Tags';

  @override
  String get youtubeOpenError => 'Could not open YouTube';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioPrevious => 'Previous';

  @override
  String get audioNext => 'Next';

  @override
  String get audioSeekBack10 => 'Back 10 s';

  @override
  String get audioSeekForward10 => 'Forward 10 s';

  @override
  String get audioSpeed => 'Playback speed';

  @override
  String audioSpeedValue(String value) {
    return '${value}x';
  }

  @override
  String get miniPlayerPrevious => 'Previous track';

  @override
  String get miniPlayerNext => 'Next track';

  @override
  String get miniPlayerOpenScreen => 'Open audio screen';

  @override
  String get audioClosePlayer => 'Close and return to search';

  @override
  String get audioOpenSheetMusic => 'Sheet music for this hymn';

  @override
  String get audioFollowReader => 'Follow the audio';

  @override
  String get audioFlagAdd => 'Add audio flag';

  @override
  String get audioFlagAddTitle => 'New audio flag';

  @override
  String get audioFlagLabelHint => 'Optional label';

  @override
  String get audioFlagCancel => 'Cancel';

  @override
  String get audioFlagSave => 'Save';

  @override
  String get audioFlagListTitle => 'Flags';

  @override
  String get audioFlagListEmpty =>
      'No flags yet. Pause and tap the flag button.';

  @override
  String get audioFlagDelete => 'Remove flag';

  @override
  String get audioFlagsSyncFailed => 'Markers not synced';

  @override
  String get audioPlaybackError => 'Could not play this audio.';

  @override
  String get audioNotDownloaded =>
      'This audio was not downloaded — offline, only what is on the device plays';

  @override
  String get audioWebBackgroundNotice =>
      'On the web, background playback and system controls depend on the browser — this is not an app bug.';

  @override
  String get audioWebPlatformHintTooltip => 'About web playback';

  @override
  String get audioWebIosPwaNotice =>
      'On iPhone with the app installed on the Home Screen, audio may pause when you lock the screen or switch apps. Keep the app open to listen.';

  @override
  String playlistActivated(String nome) {
    return 'List \"$nome\" is active';
  }

  @override
  String get undo => 'Undo';

  @override
  String get playlistEmptyPdfList => 'This playlist has no songs.';

  @override
  String get playlistGoLive => 'Go live';

  @override
  String get playlistShare => 'Share';

  @override
  String get playlistImport => 'Import playlist';

  @override
  String get liveJoinRoom => 'Join room';

  @override
  String get liveJoinRoomTitle => 'Join a live room';

  @override
  String get liveJoinRoomInputLabel => 'Room link or code';

  @override
  String get liveJoinRoomInvalid => 'Invalid room link or code';

  @override
  String get liveJoinRoomConfirm => 'Join';

  @override
  String get playlistImportTitle => 'Import shared playlist';

  @override
  String get playlistImportUrlLabel => 'Shared URL or link';

  @override
  String get playlistImportPaste => 'Paste';

  @override
  String get playlistImportConfirm => 'Import';

  @override
  String get playlistSyncFailed => 'Could not sync your playlists';

  @override
  String playlistSyncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists in conflict',
      one: '1 playlist in conflict',
    );
    return '$_temp0';
  }

  @override
  String playlistConflictCopySaved(String nome, String copia) {
    return 'Local edits to “$nome” saved in “$copia”';
  }

  @override
  String playlistsRemovedRemotely(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists removed on another device',
      one: '1 playlist removed on another device',
    );
    return '$_temp0';
  }

  @override
  String get playlistImported => 'Playlist imported';

  @override
  String playlistImportAlreadySaved(String nome) {
    return 'Playlist was already saved: $nome';
  }

  @override
  String get playlistImportInvalidUrl =>
      'Invalid link. Use a URL with sharepdfs and sharename.';

  @override
  String get deepLinkImportFailed => 'Could not import the shared playlist.';

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
  String get playlistShareOptionLinkWithLeaflet => 'Leaflet';

  @override
  String get playlistShareOptionLinkWithLeafletSubtitle =>
      'List image with link and QR code';

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
  String get publicPlaylistsTitle => 'Public playlists';

  @override
  String get socialSignInRequired =>
      'Sign in with Google to explore public playlists.';

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

  @override
  String get deferredLoaderLoading => 'Loading…';

  @override
  String get deferredLoaderError => 'Could not load this section.';

  @override
  String get deferredLoaderRetry => 'Try again';

  @override
  String get authSignInUnavailable => 'Sign-in is unavailable right now.';

  @override
  String get authSignInRetry => 'Try again';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authSignInContextMismatchTitle =>
      'We couldn\'t finish signing you in';

  @override
  String get authSignInContextMismatchBody =>
      'Google answered in another window. Tap to try again.';

  @override
  String get authSignInOpenInBrowserHint =>
      'If this keeps happening, open v2.plpcg.com in Safari.';

  @override
  String get errorNoConnection =>
      'No internet connection. Check your network and try again.';

  @override
  String get errorTimeout => 'The connection took too long. Try again.';

  @override
  String get errorServer =>
      'The server is unavailable right now. Try again in a moment.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Sign in again to continue.';

  @override
  String get errorGeneric => 'Could not complete the action. Try again.';

  @override
  String get failureNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get failureOffline =>
      'This PDF was not downloaded for offline use. Connect to the internet or go to Offline Settings → Download Missing.';

  @override
  String get failureNotFound =>
      'Could not find this. It may have been removed.';

  @override
  String get failureStorage =>
      'Local storage is unavailable. Reload the page or free up space.';

  @override
  String get failureAuth =>
      'Your session has expired. Sign in again to continue.';

  @override
  String get failureConflict => 'Sync conflict. Please try again.';

  @override
  String get failureUnknown => 'Could not complete the action. Try again.';

  @override
  String get homeEmptyHint => 'Search by title or number';

  @override
  String get homeEmptyRecent => 'Recently opened';

  @override
  String homeNoResults(String query) {
    return 'No songs found for “$query”';
  }

  @override
  String get homeNoResultsTips =>
      'Try another term, or check the number and spelling.';

  @override
  String get homeClearFilters => 'Clear filters';

  @override
  String get homeColdigomOffline =>
      'No connection — the catalog may be incomplete for this search.';

  @override
  String get favoriteMaterialKindsTitle => 'Favorite materials';

  @override
  String favoriteMaterialKindsHelp(int max) {
    return 'Pick up to $max material types. They show first when you open a hymn.';
  }

  @override
  String favoriteMaterialKindsYours(int count, int max) {
    return 'Your favorites ($count of $max)';
  }

  @override
  String get favoriteMaterialKindsEmpty => 'No favorites yet';

  @override
  String get favoriteMaterialKindsAdd => 'Add';

  @override
  String get favoriteMaterialKindsSearchHint => 'Search material type';

  @override
  String favoriteMaterialKindsLimitReached(int max) {
    return 'Limit of $max — remove one to swap';
  }

  @override
  String get favoriteMaterialKindsSignInPrompt =>
      'Sign in with Google to pick your favorite materials.';

  @override
  String get favoriteMaterialKindsSyncPending => 'Sync pending';

  @override
  String get favoriteMaterialKindsRemoveTooltip => 'Remove from favorites';

  @override
  String get favoriteMaterialKindsAddTooltip => 'Add to favorites';

  @override
  String get favoriteMaterialKindsUnknownKind => 'Unknown';

  @override
  String get favoriteMaterialKindsLoadError => 'Couldn\'t load material types';

  @override
  String get favoriteMaterialKindsRetry => 'Try again';

  @override
  String get favoriteMaterialKindsNoMatch => 'No type with that name';

  @override
  String get favoriteMaterialKindsTypePreferenceTooltip =>
      'Choose preferred format';

  @override
  String favoriteMaterialKindsTypePreferenceTitle(String kind) {
    return 'Preferred format for $kind';
  }

  @override
  String get favoriteMaterialKindsTypePreferenceHelp =>
      'Drag to reorder — the top of the list is the preferred format.';

  @override
  String liveFollowing(String owner, String list) {
    return 'Following $owner · $list';
  }

  @override
  String get liveLeaderAway => 'host away';

  @override
  String liveWaitingFor(String owner) {
    return 'Waiting for $owner';
  }

  @override
  String get liveReconnecting => 'Reconnecting…';

  @override
  String get liveReturnToLeader => 'Back to host';

  @override
  String get liveLeave => 'Leave';

  @override
  String liveOnAir(int viewers) {
    return 'LIVE · $viewers';
  }

  @override
  String get liveRoom => 'Room';

  @override
  String get liveEnd => 'End';

  @override
  String get liveEndConfirmTitle => 'End the live session?';

  @override
  String get liveEndConfirmBody =>
      'Everyone following will stop receiving the list.';

  @override
  String get liveReplacedElsewhere => 'Session taken over on another device';

  @override
  String get liveColdigomOnlyTitle => 'Coldigom materials only';

  @override
  String get liveColdigomOnlyBody =>
      'To broadcast live, every material in the list must come from Coldigom. Replace the PLPCG ones and try again.';

  @override
  String get liveColdigomOnlyAdd =>
      'While live, only Coldigom materials can be added';

  @override
  String get liveOk => 'OK';

  @override
  String liveWasLive(String list) {
    return 'You were live with “$list”';
  }

  @override
  String get liveResume => 'Resume';

  @override
  String get liveJoining => 'Joining…';

  @override
  String get liveUnavailableTitle => 'Couldn\'t connect to the session';

  @override
  String get liveUnavailableBody =>
      'This network may block live connections. Try another network or ask for the public list link.';

  @override
  String get liveRetry => 'Try again';

  @override
  String get liveNotFound =>
      'This link doesn\'t exist or was replaced by a new one.';

  @override
  String liveIdleTitle(String owner) {
    return '$owner isn\'t live right now';
  }

  @override
  String get liveIdleBody =>
      'Stay here — when it starts, you\'ll join automatically.';

  @override
  String liveFollowingTitle(String owner) {
    return 'You\'re following $owner';
  }

  @override
  String get liveGoToList => 'Go to the list';

  @override
  String get liveEndedTitle => 'Session ended';

  @override
  String get liveSaveCopy => 'Save a copy';

  @override
  String liveCopyName(String list, String owner) {
    return '$list (live with $owner)';
  }

  @override
  String get liveCopySaved => 'Copy saved to Lists';

  @override
  String get liveLeftTitle => 'You left the session';

  @override
  String get liveJoinAgain => 'Join again';

  @override
  String get liveYourRoom => 'Your live room';

  @override
  String get liveShareHint =>
      'Anyone who opens this link sees your list in real time.';

  @override
  String get liveCopyLink => 'Copy link';

  @override
  String get liveLinkCopied => 'Link copied';

  @override
  String get liveShareLink => 'Share';

  @override
  String get liveRegenerateLink => 'Generate new link';

  @override
  String get liveRegenerateConfirmTitle => 'Generate a new link?';

  @override
  String get liveRegenerateConfirmBody =>
      'The current link stops working for everyone.';

  @override
  String liveViewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people connected',
      one: '1 person connected',
      zero: 'Nobody connected',
    );
    return '$_temp0';
  }

  @override
  String get liveRoomError => 'Couldn\'t load your room';

  @override
  String get liveLoginRequired => 'Sign in with Google to go live';

  @override
  String get liveRoomMenu => 'Live Room';

  @override
  String get liveOpenRoom => 'Open Room';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsTab => 'Lyrics';

  @override
  String get lyricsReaderEmpty => 'No lyrics stored for this hymn';

  @override
  String get lyricsReaderIncreaseFont => 'Increase text size';

  @override
  String get lyricsReaderDecreaseFont => 'Decrease text size';

  @override
  String get offlineColdigomPlpcgSection => 'PLPCG collection (PDFs)';

  @override
  String get offlineColdigomSection => 'Coldigom by material type';

  @override
  String offlineColdigomCatalogStatus(int count, String ago) {
    return 'Catalog: $count hymns · updated $ago';
  }

  @override
  String get offlineColdigomCatalogMissing =>
      'Connect to the internet to download the catalog';

  @override
  String get offlineColdigomAgoJustNow => 'just now';

  @override
  String offlineColdigomAgoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String offlineColdigomAgoHours(int n) {
    return '$n h ago';
  }

  @override
  String offlineColdigomAgoDays(int n) {
    return '$n d ago';
  }

  @override
  String get offlineColdigomSignInPrompt =>
      'Sign in with Google to download your favorite types';

  @override
  String get offlineColdigomFavoriteKinds => 'Your favorite types';

  @override
  String get offlineColdigomNoFavorites =>
      'No favorites — pick some in Favorite materials or open “Other types”';

  @override
  String get offlineColdigomOtherKinds => 'Other types';

  @override
  String offlineColdigomKindSummary(int count, String size) {
    return '$count materials · $size';
  }

  @override
  String offlineColdigomDownloadSelected(String size) {
    return 'Download selected ($size)';
  }

  @override
  String get offlineColdigomStop => 'Stop';

  @override
  String offlineColdigomProgress(String kind, int done, int total) {
    return '$kind · $done/$total';
  }

  @override
  String offlineColdigomDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count materials downloaded',
      one: '1 material downloaded',
      zero: 'Nothing new to download',
    );
    return '$_temp0';
  }

  @override
  String offlineColdigomFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count not downloaded',
      one: '1 not downloaded',
    );
    return '$_temp0';
  }

  @override
  String offlineColdigomStopped(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Stopped — $n remaining',
      one: 'Stopped — 1 remaining',
    );
    return '$_temp0';
  }

  @override
  String get offlineColdigomOutOfSpace => 'Not enough space on this device';

  @override
  String get offlineColdigomRetry => 'Try again';

  @override
  String get offlineColdigomRemove =>
      'Remove downloaded Coldigom audio and PDFs';

  @override
  String get offlineColdigomRemoveNote =>
      'Chords, gestures and lyrics stay on the device.';

  @override
  String get offlineColdigomRemoveConfirmTitle => 'Remove Coldigom downloads?';

  @override
  String offlineColdigomRemoved(int pdfs, int audios) {
    return '$pdfs PDFs and $audios audios removed';
  }

  @override
  String offlineColdigomSpaceWarning(String size, String free) {
    return 'Estimated $size exceeds free space ($free) — the download may stop midway.';
  }

  @override
  String get contributeTitle => 'Help improve PLPCG';

  @override
  String get contributeSignInPrompt => 'Sign in with Google to contribute.';

  @override
  String get contributeKindLabel => 'What do you want to tell us?';

  @override
  String get contributeKindBug => 'App bug';

  @override
  String get contributeKindWrongInfo => 'Wrong information';

  @override
  String get contributeKindContent => 'Content';

  @override
  String get contributeKindImprovement => 'Improvement';

  @override
  String get contributeKindOther => 'Other';

  @override
  String get contributeSubkindLabel => 'About what?';

  @override
  String get contributeSubkindBugScreen => 'A screen';

  @override
  String get contributeSubkindBugReader => 'Reader';

  @override
  String get contributeSubkindBugAudio => 'Audio';

  @override
  String get contributeSubkindBugSearch => 'Search';

  @override
  String get contributeSubkindBugOffline => 'Offline';

  @override
  String get contributeSubkindBugLogin => 'Login';

  @override
  String get contributeSubkindBugPlaylistLive => 'Playlists / live';

  @override
  String get contributeSubkindBugOther => 'Other';

  @override
  String get contributeSubkindWrongMetadata => 'Title, number, key…';

  @override
  String get contributeSubkindWrongLyrics => 'Lyrics';

  @override
  String get contributeSubkindWrongMaterial => 'Material from another praise';

  @override
  String get contributeSubkindWrongKind => 'Wrong material type';

  @override
  String get contributeSubkindDuplicate => 'Duplicate praise';

  @override
  String get contributeSubkindAddMaterial => 'Add material';

  @override
  String get contributeSubkindAddPraise => 'Add praise';

  @override
  String get contributeSubkindReplaceMaterial => 'Replace material';

  @override
  String get contributeSubkindRemove => 'Remove';

  @override
  String get contributeSubkindFeature => 'New feature';

  @override
  String get contributeSubkindBehavior => 'Change a behavior';

  @override
  String get contributeMaterialLabel => 'About which material?';

  @override
  String get contributeMaterialWhole => 'The praise in general';

  @override
  String get contributeMetadataField => 'Field';

  @override
  String get contributeMetadataCurrent => 'Current value';

  @override
  String get contributeMetadataProposed => 'Correct value';

  @override
  String get contributeMetadataTitle => 'Title';

  @override
  String get contributeMetadataNumber => 'Number';

  @override
  String get contributeMetadataAuthor => 'Author';

  @override
  String get contributeMetadataTonality => 'Key';

  @override
  String get contributeMetadataRhythm => 'Rhythm';

  @override
  String get contributeMetadataCategory => 'Category';

  @override
  String get contributeMetadataTags => 'Tags';

  @override
  String get contributeDuplicateOf => 'Same as (number or title)';

  @override
  String get contributeSuggestedKind => 'Material type (optional)';

  @override
  String get contributeTitleField => 'Title';

  @override
  String get contributeBodyField => 'Description';

  @override
  String get contributeBodyHintBug =>
      'What you did, what you expected and what happened';

  @override
  String get contributeAttachments => 'Attachments';

  @override
  String get contributeAddFile => 'Attach file';

  @override
  String get contributeAttachmentTooLarge =>
      'Above 32 MB, send via a Drive link.';

  @override
  String get contributeAttachmentTypeNotAllowed => 'File type not accepted.';

  @override
  String get contributeAttachmentTooMany => '5 files maximum.';

  @override
  String get contributeAttachmentTotalTooLarge =>
      'Attachments can\'t total more than 96 MB.';

  @override
  String get contributeLinks => 'Links (YouTube / Drive)';

  @override
  String get contributeAddLink => 'Add link';

  @override
  String get contributeLinkNotAllowed => 'Only YouTube or Google Drive links.';

  @override
  String get contributeTooManyLinks => '5 links maximum.';

  @override
  String get contributeDeviceTitle => 'This will be sent';

  @override
  String get contributeDeviceLineApp => 'App';

  @override
  String get contributeDeviceLinePlatform => 'Platform';

  @override
  String get contributeDeviceLineDevice => 'Device';

  @override
  String get contributeDeviceLineSystem => 'System';

  @override
  String get contributeDeviceLineBrowser => 'Browser';

  @override
  String get contributeDeviceLineScreen => 'Screen';

  @override
  String get contributeDeviceLineLocale => 'Language';

  @override
  String get contributeDeviceLineOnline => 'Online';

  @override
  String get contributeDeviceLinePwa => 'PWA installed';

  @override
  String get commonYes => 'yes';

  @override
  String get commonNo => 'no';

  @override
  String get contributeSameDeviceQuestion =>
      'Did the bug happen on this device?';

  @override
  String get contributeSameDeviceYes => 'Yes';

  @override
  String get contributeSameDeviceNo => 'No';

  @override
  String get contributeOtherDevice => 'On which device?';

  @override
  String get contributeSend => 'Send';

  @override
  String get contributeSent => 'Received, thank you!';

  @override
  String get contributeErrorOffline => 'No connection. Try again.';

  @override
  String contributeErrorQuota(String time) {
    return 'Daily limit reached; back at $time.';
  }

  @override
  String contributeErrorRejected(String error) {
    return 'The submission was rejected: $error';
  }

  @override
  String get contributeErrorUnknown => 'Couldn\'t send. Try again.';

  @override
  String get contributeReportTooltip => 'Report';

  @override
  String get myContributionsTitle => 'My contributions';

  @override
  String get myContributionsEmpty => 'You haven\'t sent any contributions yet.';

  @override
  String get contributionStatusRecebida => 'Sent · checking attachments';

  @override
  String get contributionStatusPendente => 'Awaiting review';

  @override
  String get contributionStatusEmAnalise => 'Under review';

  @override
  String get contributionStatusAceita => 'Accepted';

  @override
  String get contributionStatusRecusada => 'Rejected';

  @override
  String get contributionStatusAplicada => 'Applied';

  @override
  String get contributionStatusBloqueada =>
      'Could not be reviewed: attachment rejected by security scan';

  @override
  String get contributionDecisionNote => 'Team\'s note';

  @override
  String get contributionFilesTitle => 'Attachments';

  @override
  String get contributionFileScanPending => 'checking';

  @override
  String get contributionFileScanClean => 'ok';

  @override
  String get contributionFileScanBlocked => 'rejected';
}
