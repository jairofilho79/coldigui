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
  String get filtersClear => 'Clear filters';

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
    return 'Showing $from–$to of $total results';
  }

  @override
  String get libraryResultsEmpty => 'No hymns match the current filters';

  @override
  String get coldigomFilterTonality => 'Key';

  @override
  String get coldigomFilterRhythm => 'Rhythm';

  @override
  String get coldigomFilterTags => 'Tags';

  @override
  String get coldigomFilterSubtags => 'Subtags';

  @override
  String get coldigomFilterMaterials => 'Materials';

  @override
  String get materialTypeFilterLabel => 'Type';

  @override
  String get materialTypeAll => 'All';

  @override
  String get materialTypePdf => 'PDF';

  @override
  String get materialTypeChord => 'Chords';

  @override
  String get materialTypeAudio => 'Audio';

  @override
  String get materialTypeYoutube => 'YouTube';

  @override
  String get materialTypeGesture => 'Gestures';

  @override
  String get materialKindOtherClass => 'Other';

  @override
  String materialKindHiddenByType(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count materials hidden by type',
      one: '1 material hidden by type',
    );
    return '$_temp0';
  }

  @override
  String materialKindShowVariants(String name) {
    return 'Show variants of $name';
  }

  @override
  String materialKindFamilyVariantsLabel(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count variants',
      one: '1 variant',
    );
    return '$name, $_temp0';
  }

  @override
  String get materialKindFamilyRefinedValue => 'Partially selected';

  @override
  String get offlineTitle => 'Offline';

  @override
  String get offlineStoppingDownload => 'Stopping...';

  @override
  String get offlineInsufficientDiskSpace =>
      'Not enough disk space for download';

  @override
  String get offlineStorageUnavailable =>
      'Local storage is unavailable. Reload the page or free up space.';

  @override
  String offlineStatsDiskUsage(String used, String free) {
    return 'Offline library: $used | Available: $free';
  }

  @override
  String offlineStatsDiskUsageUsedOnly(String used) {
    return 'Offline library: $used';
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
  String get offlineDismissRemoved => 'Dismiss';

  @override
  String get pdfOfflineUnavailableMessage =>
      'This PDF was not downloaded for offline use. Connect to the internet or download its type in Offline → Download for offline use.';

  @override
  String get pdfLocalReadFailedMessage =>
      'Could not read the file. Please try again.';

  @override
  String get pdfExternallyDeleted =>
      'The PDF was removed from this device. Go online or download its type again in Offline → Download for offline use.';

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
  String get readerSwitchPraiseSwipe => 'Swipe to switch version';

  @override
  String get relatedPraisesTitle => 'Versions';

  @override
  String relatedPraisesSwapped(String tag) {
    return 'Switched to version: $tag';
  }

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
  String get gestureSectionVerse => 'verse';

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
  String get lyricsAutoscrollPlay => 'Start autoscroll';

  @override
  String get lyricsAutoscrollPause => 'Pause autoscroll';

  @override
  String lyricsAutoscrollSpeed(int speed) {
    return 'Scroll speed: $speed';
  }

  @override
  String get autoscrollSpeedTooltip => 'Scroll speed';

  @override
  String get autoscrollSlow => 'Slow';

  @override
  String get autoscrollFast => 'Fast';

  @override
  String get autoscrollClose => 'Close speed settings';

  @override
  String get coldigomMetaTonality => 'Key';

  @override
  String get coldigomMetaAuthor => 'Author';

  @override
  String get coldigomMetaRhythm => 'Rhythm';

  @override
  String get coldigomMetaBiblical => 'Biblical Insight';

  @override
  String get coldigomMetaTags => 'Tags';

  @override
  String get coldigomMetaMoreDetails => 'More details';

  @override
  String get coldigomMetaLessDetails => 'Less details';

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
  String get miniPlayerBackToReading => 'Back to reading';

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
  String playlistImportedWithSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs were left out',
      one: '1 song was left out',
    );
    return 'Playlist imported — $_temp0';
  }

  @override
  String playlistImportAlreadySaved(String nome) {
    return 'Playlist was already saved: $nome';
  }

  @override
  String get playlistImportInvalidUrl => 'Invalid link.';

  @override
  String get deepLinkImportFailed => 'Could not import the shared playlist.';

  @override
  String get playlistShareLegacyLinkUnsupported =>
      'This link is from an older version and no longer opens. Ask the person for a new link.';

  @override
  String get playlistShareError => 'Could not share the playlist.';

  @override
  String playlistShareSkippedEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count list items were left out of the link',
      one: '1 list item was left out of the link',
    );
    return '$_temp0';
  }

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
      'This PDF was not downloaded for offline use. Connect to the internet or download its type in Offline → Download for offline use.';

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
  String get offlineSectionTitle => 'Download for offline use';

  @override
  String get offlineKindsAll => 'Types';

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
      'Sign in with Google to see your favorite types first';

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
  String get offlineColdigomRemove => 'Remove all downloads';

  @override
  String get offlineColdigomRemoveConfirmBody =>
      'All PDFs and audio stored on this device are removed, including recently opened ones. Chords, gestures and lyrics stay.';

  @override
  String get offlineColdigomRemoveConfirmTitle => 'Remove all downloads?';

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

  @override
  String get contributeClearForm => 'Clear form';

  @override
  String get contributeClearFormConfirmTitle => 'Clear form?';

  @override
  String get contributeClearFormConfirmMessage =>
      'Are you sure you want to clear all filled fields? This action cannot be undone.';

  @override
  String get contributeClearFormCancel => 'Cancel';

  @override
  String get contributeClearFormConfirm => 'Clear';

  @override
  String get contributeSendDeviceData =>
      'Send device data to help with diagnosis';

  @override
  String get contributeBodyHint =>
      'Describe the issue, error, or suggestion you encountered here...';

  @override
  String get contributeLinkedPraise => 'Report linked to song';

  @override
  String get contributeEditorTitle => 'Suggest material improvement';

  @override
  String get contributeEditorRawTab => 'Editor';

  @override
  String get contributeEditorPreviewTab => 'Preview';

  @override
  String get contributeEditorAddLine => 'Add line';

  @override
  String get contributeEditorRemoveLine => 'Remove line';

  @override
  String get contributeEditorChangeGesture => 'Change gesture';

  @override
  String get contributeEditorSearchGesture =>
      'Search gesture by name or trigger...';

  @override
  String get contributeEditorRestore => 'Restore original';

  @override
  String get contributeEditorNotesLabel =>
      'Notes about the suggestion (optional)';

  @override
  String get contributeEditorNotesHint =>
      'Briefly describe what you adjusted or why...';

  @override
  String get contributeEditorTriggerLabel => 'Trigger';

  @override
  String get contributeEditorLyricsLabel => 'Lyrics';

  @override
  String get contributeEditorAddGestureLine => 'Add gesture';

  @override
  String get contributeEditorAddTextLine => 'Add text line';

  @override
  String get contributeEditorAddChorus => 'Add chorus';

  @override
  String get contributeEditorAddRepeat => 'Add repeat';

  @override
  String get contributeEditorMoveUp => 'Move up';

  @override
  String get contributeEditorMoveDown => 'Move down';

  @override
  String get contributeEditorInsertChord => 'Insert chord [ ]';

  @override
  String get contributeEditorInsertComment => 'Insert comment (chorus)';

  @override
  String get contributeEditorSwitchToGeneral => 'Switch to general form';

  @override
  String get contributeEditorSwitchToExtracted => 'Edit extracted material';

  @override
  String get contributeEditorLoading => 'Loading material...';

  @override
  String get contributeEditorNoGestureFound => 'No gestures found';

  @override
  String get contributeEditorSelectGesture => 'Choose gesture';

  @override
  String get contributeEditorLyricsKind => 'Lyrics';

  @override
  String get contributeEditorChordKind => 'Chord';

  @override
  String get contributeEditorGestureKind => 'Gestures';

  @override
  String get contributeEditorGeneralKind => 'General';

  @override
  String get contributeEditorGeneralHint =>
      'To suggest edits for Lyrics, Chords, or Gestures, open the desired song in the app and tap the 🤝 icon in the top toolbar.';

  @override
  String get praiseOpenDetailsTooltip => 'Open full praise page';

  @override
  String get praiseShareTooltip => 'Share praise';

  @override
  String get praiseShareLinkCopied => 'Praise link copied!';

  @override
  String get praiseNotFound => 'Praise not found';

  @override
  String get praiseBackToSearch => 'Back to home';

  @override
  String get praiseLyricsSectionTitle => 'Lyrics';

  @override
  String get praiseMaterialsSectionTitle => 'Materials';

  @override
  String get praiseLyricsCopyTooltip => 'Copy lyrics';

  @override
  String get praiseLyricsCopied => 'Lyrics copied!';

  @override
  String get praiseOpenLyricsReader => 'Open in lyrics reader';

  @override
  String get praiseNoLyricsAvailable => 'Lyrics not available for this praise';

  @override
  String get praiseIncreaseFontSizeTooltip => 'Increase font size';

  @override
  String get praiseDecreaseFontSizeTooltip => 'Decrease font size';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get backTooltip => 'Back';

  @override
  String get homeTooltip => 'Home';

  @override
  String get placeholderComingSoon => 'Coming soon';

  @override
  String get degradedStorageBannerMessage =>
      'Local storage unavailable. The online catalog continues to work; playlists and offline mode are disabled.';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabAbout => 'About';

  @override
  String get tabPraise => 'Praise';

  @override
  String get tabPublicPlaylists => 'Public playlists';

  @override
  String get aboutTitle => 'About';

  @override
  String get profileResetTutorials => 'Reset Tutorials';

  @override
  String get profileResetTutorialsDialogTitle => 'Reset Tutorials';

  @override
  String get profileResetTutorialsDialogContent =>
      'Do you want to reset all tutorials? Introductory guides will be shown again automatically when accessing app screens.';

  @override
  String get profileResetTutorialsConfirm => 'Reset';

  @override
  String get profileResetTutorialsSuccess => 'Tutorials reset successfully!';

  @override
  String get profileSyncPromptTitle => 'Sign in to sync your data';

  @override
  String get profileSyncPromptBody =>
      'Use your Google account to sync playlists and other features.';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get shortcutsTitle => 'Keyboard Shortcuts';

  @override
  String get shortcutsSubtitle =>
      'Fast productivity commands for Desktop and Web';

  @override
  String get shortcutsAboutDescription =>
      'View high-productivity quick commands for Desktop and Web.';

  @override
  String get welcomeTourAboutTitle => 'Welcome Tour';

  @override
  String get welcomeTourAboutDescription =>
      'Take the 4-step guided tour learning the flow from catalog to worship.';

  @override
  String get shortcutsTabAll => 'All';

  @override
  String get shortcutsTabNavigation => 'Navigation';

  @override
  String get shortcutsTabRepertoireAudio => 'Repertoire & Audio';

  @override
  String get shortcutsTabSheetMusic => 'Sheet Music';

  @override
  String get shortcutsTabChordsGestures => 'Chords & Gestures';

  @override
  String get shortcutsFooterTip =>
      'Press ? on any screen to open this panel at any time.';

  @override
  String get shortcutsGotIt => 'Got it';

  @override
  String get shortcutsEmpty => 'No shortcuts found.';

  @override
  String get shortcutsOr => 'or';

  @override
  String get shortcutCatNavigation => 'Navigation & Search';

  @override
  String get shortcutCatRepertoireAudio => 'Repertoire & Audio';

  @override
  String get shortcutCatSheetMusic => 'Sheet Music (PDF)';

  @override
  String get shortcutCatChordsGestures => 'Chords & Gestures';

  @override
  String get shortcutActionHomeSearch => 'Go to Home and focus search field';

  @override
  String get shortcutActionOpenShortcuts =>
      'Open this Keyboard Shortcuts Center';

  @override
  String get shortcutActionEscape =>
      'Exit full screen, clear search, or close dialogs';

  @override
  String get shortcutActionNextPraise => 'Go to next praise in repertoire';

  @override
  String get shortcutActionPreviousPraise =>
      'Go to previous praise in repertoire';

  @override
  String get shortcutActionCarouselQueue => 'Navigate praise carousel queue';

  @override
  String get shortcutActionToggleAudio => 'Play or pause praise audio';

  @override
  String get shortcutActionToggleAudioPdf =>
      'Play or pause audio even with sheet music open';

  @override
  String get shortcutActionSeekAudioBack => 'Rewind audio 10 seconds';

  @override
  String get shortcutActionSeekAudioForward => 'Fast-forward audio 10 seconds';

  @override
  String get shortcutActionToggleFullscreen => 'Toggle full-screen mode';

  @override
  String get shortcutActionNextPagePdf => 'Next page or scroll sheet music';

  @override
  String get shortcutActionPrevPagePdf => 'Previous sheet music page';

  @override
  String get shortcutActionFirstPagePdf => 'Go to first page';

  @override
  String get shortcutActionLastPagePdf => 'Go to last page';

  @override
  String get shortcutActionFitModePdf => 'Toggle fit mode (width / height)';

  @override
  String get shortcutActionPageGridPdf => 'Open quick page grid selector';

  @override
  String get shortcutActionToggleAutoscroll => 'Toggle autoscroll on or off';

  @override
  String get shortcutActionAdjustAutoscrollSpeed =>
      'Decrease or increase scroll speed';

  @override
  String get shortcutActionTransposePitch =>
      'Transpose praise pitch (+1 / -1 semitone)';

  @override
  String get shortcutActionNextGesture => 'Next or previous conducting gesture';

  @override
  String get shortcutBadgeReader => 'Reader';

  @override
  String get shortcutBadgeGeneral => 'General';

  @override
  String get shortcutBadgeReaderPdf => 'PDF Reader';

  @override
  String get shortcutBadgeChordsLyrics => 'Chords/Lyrics';

  @override
  String get shortcutBadgeAutoscroll => 'Autoscroll';

  @override
  String get shortcutBadgeChords => 'Chords';

  @override
  String get shortcutBadgeFocusModeCias => 'Focus Mode CIAs';

  @override
  String get materialKindChordExtracted => 'Extracted (chords)';

  @override
  String get materialKindGestureExtracted => 'Extracted (gestures)';

  @override
  String offlineKindVariantsCount(int count) {
    return '$count var.';
  }

  @override
  String offlineKindVariantsTitle(String name, int count) {
    return 'Variants of $name ($count):';
  }

  @override
  String get offlineSearchMaterialTypeHint => 'Search material type...';

  @override
  String get offlineClearSearchTooltip => 'Clear search';

  @override
  String get offlineFilterButton => 'Filter';

  @override
  String offlineSearchNoResults(String query) {
    return 'No material types found for \"$query\"';
  }

  @override
  String get tutorialTooltipHowToShare => 'How to share';

  @override
  String get tutorialTooltipHowToPublish => 'How to publish';

  @override
  String get tutorialTooltipHowToUseFilters => 'How to use filters';

  @override
  String get tutorialTooltipHowToUseMaterialSheet => 'How to use this selector';

  @override
  String get tutorialTooltipHowToManageList => 'How to manage list';

  @override
  String get tutorialTooltipHowToUseFocusMode => 'How to use Focus Mode';

  @override
  String get tutorialTooltipHowToJoinLive => 'How to join';

  @override
  String get tutorialTooltipHowToUseShortcuts => 'How to use shortcuts';

  @override
  String get contributeNeedHelp => 'Need help?';

  @override
  String get contributeHelpIntro =>
      'This page allows you to submit contributions and help us improve the app and the PLPCG catalog. Choose the option that best describes your case:';

  @override
  String get contributeHelpDescBug =>
      'App issues (crashes, black screen, unresponsive buttons, or audio/reader failure). Attach a screenshot if possible.';

  @override
  String get contributeHelpDescWrongInfo =>
      'Incorrect data in an existing praise (number, key, title, author, rhythm, or duplicate entry).';

  @override
  String get contributeHelpDescContent =>
      'Submitting or suggesting new materials (chords, sheet music, audio, or lyrics) or improvements to existing files.';

  @override
  String get contributeHelpDescImprovement =>
      'Feature suggestions, visual changes, or ideas to make the app more practical for rehearsals and worship services.';

  @override
  String get contributeHelpDescOther =>
      'General questions, notes for the team, or any other topic not listed above.';

  @override
  String get contributeHelpTipAttachments =>
      'You can also attach files (up to 32 MB) or paste Google Drive and YouTube links to support your submission.';

  @override
  String get contributeEditorChordProExampleHint =>
      '[G]Example of [D]ChordPro chords...';

  @override
  String contributeEditorLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String get contributeEditorGestureEmptyDocument =>
      'No items in document. Add a line above.';

  @override
  String contributeEditorGestureBlocksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks/lines',
      one: '1 block/line',
    );
    return '$_temp0';
  }

  @override
  String contributeEditorGestureInstructionLabel(String kind) {
    return 'Instruction: $kind';
  }

  @override
  String authGoogleSignInError(String error) {
    return 'Failed to sign in: $error';
  }

  @override
  String tutorialStepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get tutorialDismissForever => 'Don\'t show again';

  @override
  String get tutorialSkip => 'Skip';

  @override
  String get tutorialPrevious => 'Back';

  @override
  String get tutorialNext => 'Next';

  @override
  String get tutorialFinish => 'Finish';

  @override
  String get tutorialHowToUseScreen => 'How to use this screen';

  @override
  String get welcomeHeroTitle => 'Welcome to PLPCG!';

  @override
  String get welcomeHeroSubtitle =>
      'The digital hymnal and praise organizer for musicians, instrumentalists, and worship teams.';

  @override
  String get welcomeHeroFeatureSearch =>
      'Fast search by number, title, rhythm, and tags.';

  @override
  String get welcomeHeroFeaturePlaylists =>
      'Create playlists and setlists for worship services.';

  @override
  String get welcomeHeroFeatureReader =>
      'Sheet music and chord reader with Bluetooth pedals.';

  @override
  String get welcomeHeroPrompt =>
      'Would you like a quick 1-minute tour to explore the main features?';

  @override
  String get welcomeHeroStartTour => 'Take Quick Tour (1 min)';

  @override
  String get welcomeHeroDismiss => 'Explore on My Own';

  @override
  String get authSigningIn => 'Signing in…';

  @override
  String get aboutWhoWeAreTitle => 'Who we are';

  @override
  String get aboutWhoWeAreBody =>
      'The Peace of the Lord Jesus. We are brothers and sisters from the Maranatha Christian Church in the Triângulo Mineiro region serving at the Maanaim of Uberlândia-MG. This application is not an official church application, but its purpose is to help all those in the praise ministry serving in the Work, following Church guidelines, 100% free of charge.';

  @override
  String get aboutObjectiveTitle => 'Objective';

  @override
  String get aboutObjectiveParagraph1 =>
      'The goal of this application — called Praise Researcher in Sheet Music, Chords in General — is to assist worship team members with essential praise materials. To make it easy to search, access, and work offline, as many churches lack internet access.';

  @override
  String get aboutObjectiveParagraph2 =>
      'Therefore, let us remain in prayer for all brethren involved in this project, whether in app development, content creation, app testing, or related efforts.';

  @override
  String get tutorialAboutStep1Title => 'About Us';

  @override
  String get tutorialAboutStep1Message =>
      'Learn about the history and the team behind the application. A **100% free** and collaborative initiative built to assist worship teams.';

  @override
  String get tutorialAboutStep2Title => 'Our Mission';

  @override
  String get tutorialAboutStep2Message =>
      'The main purpose is to facilitate access to **sheet music, chords, gestures, and audio**, with guaranteed **offline** operation even in places without internet.';

  @override
  String get tutorialAboutStep3Title => 'Help & Tutorials';

  @override
  String get tutorialAboutStep3Message =>
      'Tap the **(i) icon** anytime you want to review this guide or check detailed instructions on any screen of the app!';

  @override
  String get tutorialAppShortcutsStep1Title => 'Shortcut Categories';

  @override
  String get tutorialAppShortcutsStep1Message =>
      'Navigate between tabs to explore commands grouped by context: **Navigation & Search**, **Setlist & Audio**, **Sheet Music**, and **Chords & Gestures**.';

  @override
  String get tutorialAppShortcutsStep2Title => 'High-Productivity Shortcuts';

  @override
  String get tutorialAppShortcutsStep2Message =>
      'Review shortcut keys and their actions. Side badges highlight the **contexts and viewers where each command operates**.';

  @override
  String get tutorialAppShortcutsStep3Title => 'Quick Access with the ? Key';

  @override
  String get tutorialAppShortcutsStep3Message =>
      'Press **?** (or **Shift + /**) on any app screen to open this **shortcuts center instantly** on Desktop and Web.';

  @override
  String get tutorialAppShortcutsStep4Title => 'Shortcuts Center Help';

  @override
  String get tutorialAppShortcutsStep4Message =>
      'Tap this icon to review instructions on PLPCG\'s **quick commands and shortcuts**.';

  @override
  String get tutorialAudioStep1Title => 'Track Information';

  @override
  String get tutorialAudioStep1Message =>
      'View the **title**, **number**, **author**, and **classification** of the praise or audio currently playing.';

  @override
  String get tutorialAudioStep2Title => 'Actions and Synchronization';

  @override
  String get tutorialAudioStep2Message =>
      'Access the **linked sheet music**, add **audio markers**, enable **follow audio** mode in the reader, and adjust **playback speed**.';

  @override
  String get tutorialAudioStep3Title => 'Progress Bar';

  @override
  String get tutorialAudioStep3Message =>
      'Track **current time**, **total duration**, and drag the slider to seek forward or backward. Registered **markers** are highlighted on the timeline.';

  @override
  String get tutorialAudioStep4Title => 'Playback Controls';

  @override
  String get tutorialAudioStep4Message =>
      'Control playback with **Play/Pause**, skip to the **previous or next track**, and quickly seek forward or backward by **10 seconds**.';

  @override
  String get tutorialAudioStep5Title => 'Practice Markers';

  @override
  String get tutorialAudioStep5Message =>
      'See all **timestamped markers** added to the track. Tap any marker to jump directly to that point in the rehearsal.';

  @override
  String get tutorialAudioStep6Title => 'Help & Tutorials';

  @override
  String get tutorialAudioStep6Message =>
      'Whenever you have questions about the audio player, tap this **(i) icon** to review this step-by-step tutorial!';

  @override
  String get tutorialCarouselSelectionStep1Title => 'Reorder Setlist';

  @override
  String get tutorialCarouselSelectionStep1Message =>
      'Hold and drag the **drag handle** icon to change the order of praises in real time during the service or rehearsal.';

  @override
  String get tutorialCarouselSelectionStep2Title => 'Quick Navigation';

  @override
  String get tutorialCarouselSelectionStep2Message =>
      'Tap the **body of the praise** to jump immediately to it in the active sheet music or chord reader.';

  @override
  String get tutorialCarouselSelectionStep3Title => 'Remove from Selection';

  @override
  String get tutorialCarouselSelectionStep3Message =>
      'Tap the **×** button to remove the praise from the temporary service list without deleting your saved playlists.';

  @override
  String get tutorialCarouselSelectionStep4Title => 'Clear or Reset List';

  @override
  String get tutorialCarouselSelectionStep4Message =>
      'Use this action to **clear the active list** and start a new selection from scratch or discard the current draft.';

  @override
  String get tutorialCarouselSelectionStep5Title => 'Active Setlist Help';

  @override
  String get tutorialCarouselSelectionStep5Message =>
      'Check this **quick guide** whenever you have questions about organizing and operating your setlist.';

  @override
  String get tutorialChordsStep1Title => 'Key Transposition';

  @override
  String get tutorialChordsStep1Message =>
      'Raise or lower the song key in **semitones** using the **+** and **-** buttons (or keyboard). Tap the key number to **restore the original key**.';

  @override
  String get tutorialChordsStep2Title => 'Font Size';

  @override
  String get tutorialChordsStep2Message =>
      'Adjust the **text and chord size** for optimal reading on your screen using the **decrease** and **increase font** buttons.';

  @override
  String get tutorialChordsStep3Title => 'Auto-Scroll';

  @override
  String get tutorialChordsStep3Message =>
      'Start **auto-scroll** (**S** key) to play hands-free. Adjust **speed** with the speedometer icon or with the **[** and **]** keys.';

  @override
  String get tutorialChordsStep4Title => 'Theme and Fullscreen';

  @override
  String get tutorialChordsStep4Message =>
      'Switch between **light and dark mode** for better ambient visibility, and use **fullscreen** (**F** key) to focus exclusively on chords.';

  @override
  String get tutorialChordsStep5Title => 'Reading and Layout';

  @override
  String get tutorialChordsStep5Message =>
      'On wide screens, the **chords** are automatically arranged into **two columns**. Tapping or manually scrolling the screen **automatically pauses** auto-scroll.';

  @override
  String get tutorialChordsStep6Title => 'Help & Tutorials';

  @override
  String get tutorialChordsStep6Message =>
      'Whenever you want to review this guide or clarify questions about using the Chord Reader, tap this **(i) icon**!';

  @override
  String get tutorialCollaborationDialogsStep1Title => 'Illustrated Bulletin';

  @override
  String get tutorialCollaborationDialogsStep1Message =>
      'Generates and shares an **image with the praise list** along with the direct link for viewing.';

  @override
  String get tutorialCollaborationDialogsStep2Title => 'Direct Link';

  @override
  String get tutorialCollaborationDialogsStep2Message =>
      'Copies or shares only the **shortened link**, ideal for quick messaging.';

  @override
  String get tutorialCollaborationDialogsStep3Title => 'Sharing Help';

  @override
  String get tutorialCollaborationDialogsStep3Message =>
      'Tap this icon to review **setlist sharing** options.';

  @override
  String get tutorialCollaborationDialogsStep4Title => 'Setlist Category';

  @override
  String get tutorialCollaborationDialogsStep4Message =>
      'Classify the setlist as **Evangelism**, **Learning**, **Medleys**, or **Special Service** to help others find it easily.';

  @override
  String get tutorialCollaborationDialogsStep5Title => 'Setlist Scope';

  @override
  String get tutorialCollaborationDialogsStep5Message =>
      'Check as **one-time** for sporadic events or leave unchecked if it is a **regular selection for regular services**.';

  @override
  String get tutorialCollaborationDialogsStep6Title => 'Community Publishing';

  @override
  String get tutorialCollaborationDialogsStep6Message =>
      'Tap **Publish** to make the list available on the public tab. The list can be accessed and imported by the entire church.';

  @override
  String get tutorialCollaborationDialogsStep7Title => 'Publishing Help';

  @override
  String get tutorialCollaborationDialogsStep7Message =>
      'Tap this icon to review instructions on **publishing setlists** in the community.';

  @override
  String get tutorialCollaborationDialogsStep8Title => 'Room Code or Link';

  @override
  String get tutorialCollaborationDialogsStep8Message =>
      'Type or paste the **7-character code** or **full URL** provided by the live room leader.';

  @override
  String get tutorialCollaborationDialogsStep9Title => 'Paste from Clipboard';

  @override
  String get tutorialCollaborationDialogsStep9Message =>
      'Tap **Paste** to instantly fill with the link you just copied from WhatsApp or messaging.';

  @override
  String get tutorialCollaborationDialogsStep10Title => 'Connect to Room';

  @override
  String get tutorialCollaborationDialogsStep10Message =>
      'Tap **Join** to enter the broadcast and follow **praise changes in real time**.';

  @override
  String get tutorialCollaborationDialogsStep11Title => 'Live Room Help';

  @override
  String get tutorialCollaborationDialogsStep11Message =>
      'Tap this icon to review instructions for **syncing as a follower** in a live room.';

  @override
  String get tutorialContributeStep1Title => 'Submission Context';

  @override
  String get tutorialContributeStep1Message =>
      'Indicate whether your contribution is **linked to a specific praise** or is a **general suggestion** for the app.';

  @override
  String get tutorialContributeStep2Title => 'Suggestion Description';

  @override
  String get tutorialContributeStep2Message =>
      'Describe in detail the **problem encountered**, **lyric or key correction**, or the **improvement** you would like to propose.';

  @override
  String get tutorialContributeStep3Title => 'Device Diagnostics';

  @override
  String get tutorialContributeStep3Message =>
      'Keep enabled to send **anonymous technical data** (system, browser, resolution), speeding up bug resolution.';

  @override
  String get tutorialContributeStep4Title => 'Attachments and Links';

  @override
  String get tutorialContributeStep4Message =>
      'Add **supporting files** (audio, sheet music, or screenshots up to 32 MB) and YouTube or Google Drive **links**.';

  @override
  String get tutorialContributeStep5Title => 'Submit Contribution';

  @override
  String get tutorialContributeStep5Message =>
      'Tap **Submit** to send your report. If you are not signed in, sign in with your **Google account** to submit.';

  @override
  String get tutorialContributeStep6Title => 'Help & Tutorials';

  @override
  String get tutorialContributeStep6Message =>
      'Tap this icon anytime to review this **step-by-step guide** for the suggestion submission screen.';

  @override
  String get tutorialContributionDetailStep1Title =>
      'Submission Title and Status';

  @override
  String get tutorialContributionDetailStep1Message =>
      'Track the **contribution title** and its current status (**Pending**, **Approved**, or **Rejected**).';

  @override
  String get tutorialContributionDetailStep2Title => 'Contribution Type';

  @override
  String get tutorialContributionDetailStep2Message =>
      'Indicates the category of collaboration sent, such as **Chords**, **Lyrics**, **Sheet Music**, or **Information Correction**.';

  @override
  String get tutorialContributionDetailStep3Title => 'Description and Notes';

  @override
  String get tutorialContributionDetailStep3Message =>
      'Here you can see the **descriptive text**, justifications, and external links added when the proposal was submitted.';

  @override
  String get tutorialContributionDetailStep4Title => 'Changed Fields';

  @override
  String get tutorialContributionDetailStep4Message =>
      'When the contribution proposes correcting data, see the direct comparison between the **current** and **proposed** value.';

  @override
  String get tutorialContributionDetailStep5Title =>
      'Files and Antivirus Check';

  @override
  String get tutorialContributionDetailStep5Message =>
      'View the list of **submitted attachments** and real-time security check status (**Clean**, **Scanning**, or **Blocked**).';

  @override
  String get tutorialContributionDetailStep6Title => 'Moderation Feedback';

  @override
  String get tutorialContributionDetailStep6Message =>
      'When the PLPCG team evaluates the submission, the **reviewers\' feedback and justification** will appear in this area.';

  @override
  String get tutorialContributionDetailStep7Title => 'Help & Tutorials';

  @override
  String get tutorialContributionDetailStep7Message =>
      'Whenever you have questions about contribution details, tap this **(i) icon** to review this step-by-step tutorial!';

  @override
  String get tutorialExtractedMaterialEditorStep1Title => 'Toolbar & Shortcuts';

  @override
  String get tutorialExtractedMaterialEditorStep1Message =>
      'Use quick shortcuts to **add verses**, **remove lines**, **insert chords or annotations**, and restore original text.';

  @override
  String get tutorialExtractedMaterialEditorStep2Title => 'Editing Area';

  @override
  String get tutorialExtractedMaterialEditorStep2Message =>
      'Edit content directly. For chords, use the **[Chord]** syntax immediately before the syllable to sync placement with lyrics.';

  @override
  String get tutorialExtractedMaterialEditorStep3Title =>
      'Children\'s Gestures Selector';

  @override
  String get tutorialExtractedMaterialEditorStep3Message =>
      'Tap **Change Gesture** to open the official dictionary and link the movement to the corresponding trigger phrase.';

  @override
  String get tutorialExtractedMaterialEditorStep4Title => 'Live Preview';

  @override
  String get tutorialExtractedMaterialEditorStep4Message =>
      'Track changes **in real time** with rendering identical to what users will see in the praise reader.';

  @override
  String get tutorialExtractedMaterialEditorStep5Title => 'Proposal Submission';

  @override
  String get tutorialExtractedMaterialEditorStep5Message =>
      'Add notes if desired and tap **Submit** to make your suggestion available for community review.';

  @override
  String get tutorialExtractedMaterialEditorStep6Title => 'Help & Tutorials';

  @override
  String get tutorialExtractedMaterialEditorStep6Message =>
      'Tap this icon anytime to review this **step-by-step guide** for the material editor.';

  @override
  String get tutorialFavoriteMaterialKindsStep1Title => 'Material Priority';

  @override
  String get tutorialFavoriteMaterialKindsStep1Message =>
      'Set up to **4 favorite materials** to prioritize your instruments and voices at the top of search results and in the reader.';

  @override
  String get tutorialFavoriteMaterialKindsStep2Title =>
      'Your Favorites and Order';

  @override
  String get tutorialFavoriteMaterialKindsStep2Message =>
      'Track your selected materials. Drag by the **side handle** to set priority, toggle **preferred format**, or tap **(X)** to remove.';

  @override
  String get tutorialFavoriteMaterialKindsStep3Title => 'Add New Materials';

  @override
  String get tutorialFavoriteMaterialKindsStep3Message =>
      'Search for instruments (e.g., **guitar**, **bass**, **organ**) or voices and tap the **(+)** icon to add them to your priority list.';

  @override
  String get tutorialFavoriteMaterialKindsStep4Title => 'Cloud Sync';

  @override
  String get tutorialFavoriteMaterialKindsStep4Message =>
      'Sign in with your **Google account** to save and synchronize your material preferences across any device.';

  @override
  String get tutorialFavoriteMaterialKindsStep5Title => 'Help & Tutorials';

  @override
  String get tutorialFavoriteMaterialKindsStep5Message =>
      'Tap the **(i) icon** anytime to review this guide or learn more about application features!';

  @override
  String get tutorialFiltersStep1Title => 'Key Filter';

  @override
  String get tutorialFiltersStep1Message =>
      'Filter the catalog by **musical key** (C, D, E...) and accidentals to find praises in your team\'s exact key.';

  @override
  String get tutorialFiltersStep2Title => 'Rhythm Filter';

  @override
  String get tutorialFiltersStep2Message =>
      'Select specific time signatures and rhythms such as **Waltz**, **March**, **Basic**, or **Toada** to tailor setlists to the service.';

  @override
  String get tutorialFiltersStep3Title => 'Worship Categories and Tags';

  @override
  String get tutorialFiltersStep3Message =>
      'Refine hymns by **service occasion**, such as **Communion**, **Lord\'s Supper**, **Children**, or devotional moments.';

  @override
  String get tutorialFiltersStep4Title => 'Material Types';

  @override
  String get tutorialFiltersStep4Message =>
      'Restrict results to display only praises that have **Chords**, **Sheet Music**, **Children\'s Gestures**, or **Audio** available.';

  @override
  String get tutorialFiltersStep5Title => 'Clear Filters';

  @override
  String get tutorialFiltersStep5Message =>
      'Tap **Clear** to instantly reset all applied filters and view the full collection.';

  @override
  String get tutorialFiltersStep6Title => 'Filters Help';

  @override
  String get tutorialFiltersStep6Message =>
      'Tap this icon whenever you want to review guidelines on **combining advanced filters**.';

  @override
  String get tutorialGestureFocusStep1Title => 'Featured Gesture Card';

  @override
  String get tutorialGestureFocusStep1Message =>
      'View the gesture movement in an **enlarged size**, with animation or illustration for easy following by the conductor.';

  @override
  String get tutorialGestureFocusStep2Title => 'Trigger Phrase & Lyric';

  @override
  String get tutorialGestureFocusStep2Message =>
      'Follow the associated lyric, highlighted in **red on the trigger** where the gesture should be executed by the worship group.';

  @override
  String get tutorialGestureFocusStep3Title => 'Gesture Navigation';

  @override
  String get tutorialGestureFocusStep3Message =>
      'Tap the **sides of the screen**, **swipe horizontally**, or use the **keyboard arrows (← and →)** to step forward or backward.';

  @override
  String get tutorialGestureFocusStep4Title => 'Next Trigger';

  @override
  String get tutorialGestureFocusStep4Message =>
      'Check the footer for the **word or phrase of the next gesture**, preparing the transition before it happens.';

  @override
  String get tutorialGestureFocusStep5Title => 'Focus Mode Help';

  @override
  String get tutorialGestureFocusStep5Message =>
      'Tap this icon to review this **step-by-step guide** or press **Esc** to close and return to the reader at any time.';

  @override
  String get tutorialGesturesStep1Title => 'Lyrics Font Size';

  @override
  String get tutorialGesturesStep1Message =>
      'Increase or decrease the **text size** of praises for more comfortable reading during rehearsals or services.';

  @override
  String get tutorialGesturesStep2Title => 'Auto-Scroll';

  @override
  String get tutorialGesturesStep2Message =>
      'Enable **auto-scroll** (**S** key) to follow gestures without touching the screen. Adjust **speed** on the speedometer or with **[** and **]**.';

  @override
  String get tutorialGesturesStep3Title => 'Linear vs. Structured Mode';

  @override
  String get tutorialGesturesStep3Message =>
      'Switch between **structured** display (grouped by stanzas and choruses) and **linear** reading (continuous sequence with all full repeats).';

  @override
  String get tutorialGesturesStep4Title => 'Theme and Fullscreen';

  @override
  String get tutorialGesturesStep4Message =>
      'Switch between **light and dark mode** for better visibility, and use **fullscreen** mode (**F** key) to hide bars and focus on gestures.';

  @override
  String get tutorialGesturesStep5Title => 'Gesture Cards';

  @override
  String get tutorialGesturesStep5Message =>
      'Gestures appear synchronized with corresponding words. Tap any **gesture card** to open **focus view** with enlarged image and detailed description.';

  @override
  String get tutorialGesturesStep6Title => 'Help & Tutorials';

  @override
  String get tutorialGesturesStep6Message =>
      'Whenever you have questions about using the gesture reader, tap this **(i) icon** to review this step-by-step tutorial!';

  @override
  String get tutorialHomeStep1Title => 'Smart Search';

  @override
  String get tutorialHomeStep1Message =>
      'Type the **number** of the praise, the **title**, or an **excerpt of the lyrics** to locate it instantly in the catalog.';

  @override
  String get tutorialHomeStep2Title => 'Active Filters';

  @override
  String get tutorialHomeStep2Message =>
      'When **active**, the selected filter button gets a **golden highlight**. The header displays the **active filters** count and you can tap **\'Clear filters\'** to reset.';

  @override
  String get tutorialHomeStep3Title => 'Inactive Filters';

  @override
  String get tutorialHomeStep3Message =>
      'With filters **inactive** (unselected), search covers **the entire catalog**. Tap any button to **activate it** or collapse the panel to save space.';

  @override
  String get tutorialHomeStep4Title => 'Main Navigation';

  @override
  String get tutorialHomeStep4Message =>
      'Easily switch between the Praise **Search**, your saved **Playlists**, and your user **Profile**.';

  @override
  String get tutorialHomeStep5Title => 'Help & Tutorials';

  @override
  String get tutorialHomeStep5Message =>
      'Whenever you have questions about using any screen, tap this **(i) icon** to review step-by-step explanations!';

  @override
  String get tutorialLibraryStep1Title => 'Catalog Filters';

  @override
  String get tutorialLibraryStep1Message =>
      'Refine the full library by **musical key**, **rhythm**, **categories/tags**, or **material type** (sheet music, chords, audio). Tap the header to **expand or collapse** filters.';

  @override
  String get tutorialLibraryStep2Title => 'Catalog Sorting';

  @override
  String get tutorialLibraryStep2Message =>
      'Quickly switch the order of praises between **\'By number\'** (official hymnal number) or **\'By name\'** (alphabetical order of titles).';

  @override
  String get tutorialLibraryStep3Title => 'Pagination and Display';

  @override
  String get tutorialLibraryStep3Message =>
      'Check the **total praises** found, select the **items per page** (10, 20, 50...), and use the **navigation arrows** to browse the catalog.';

  @override
  String get tutorialLibraryStep4Title => 'Praise Cards';

  @override
  String get tutorialLibraryStep4Message =>
      'Each card shows the praise number, title, and details. Tap it to directly access its **sheet music**, **chords**, **audio**, and **full details**.';

  @override
  String get tutorialLibraryStep5Title => 'Help & Tutorials';

  @override
  String get tutorialLibraryStep5Message =>
      'Whenever you have questions about navigating or using the Library, tap this **(i) icon** to review this step-by-step guide!';

  @override
  String get tutorialLiveRoomStep1Title => 'Room Code and QR Code';

  @override
  String get tutorialLiveRoomStep1Message =>
      'Participants can scan this **QR code** with their phone camera or use the **direct link** to follow the service.';

  @override
  String get tutorialLiveRoomStep2Title => 'Share and Manage';

  @override
  String get tutorialLiveRoomStep2Message =>
      'Copy or **share the link** to the broadcast with the group or tap **generate new link** if you need to reset access.';

  @override
  String get tutorialLiveRoomStep3Title => 'Connected Participants';

  @override
  String get tutorialLiveRoomStep3Message =>
      'Track in real time the **number of members** who are tuned in and following chords and lyrics in your room.';

  @override
  String get tutorialLiveRoomStep4Title => 'End Broadcast';

  @override
  String get tutorialLiveRoomStep4Message =>
      'Tap **End** to conclude the live session with participants and return to your playlists.';

  @override
  String get tutorialLiveRoomStep5Title => 'Broadcast Status';

  @override
  String get tutorialLiveRoomStep5Message =>
      'Track session progress: see if the leader is **live**, waiting for the service, or if the connection is **syncing**.';

  @override
  String get tutorialLiveRoomStep6Title => 'Save Copy';

  @override
  String get tutorialLiveRoomStep6Message =>
      'At the end of the service, tap **Save copy** to save the setlist directly to your personal playlists.';

  @override
  String get tutorialLiveRoomStep7Title => 'Help & Tutorials';

  @override
  String get tutorialLiveRoomStep7Message =>
      'Tap this icon anytime to review this **step-by-step guide** for the live room.';

  @override
  String get tutorialLyricsStep1Title => 'Lyrics Font Size';

  @override
  String get tutorialLyricsStep1Message =>
      'Increase or decrease the **font size** of lyrics for more comfortable reading during rehearsals or services. You can also use **Ctrl + ↑ / ↓** (or **Cmd + ↑ / ↓**).';

  @override
  String get tutorialLyricsStep2Title => 'Auto-Scroll';

  @override
  String get tutorialLyricsStep2Message =>
      'Enable **auto-scroll** (**S** key) to read lyrics hands-free. Tap the **speedometer** to adjust speed (or use the **[** and **]** keys).';

  @override
  String get tutorialLyricsStep3Title => 'Fullscreen Mode';

  @override
  String get tutorialLyricsStep3Message =>
      'Tap the **fullscreen** button (or **F** key) to hide all bars and focus entirely on reading lyrics.';

  @override
  String get tutorialLyricsStep4Title => 'Text Reading and Selection';

  @override
  String get tutorialLyricsStep4Message =>
      'Lyrics are available **completely offline**. Text is selectable for copying excerpts, and scrolling smoothly pauses when you touch the screen.';

  @override
  String get tutorialLyricsStep5Title => 'Help & Tutorials';

  @override
  String get tutorialLyricsStep5Message =>
      'Whenever you have questions about using the lyrics reader, tap this **(i) icon** to review this step-by-step tutorial!';

  @override
  String get tutorialMaterialSheetStep1Title => 'Available Formats';

  @override
  String get tutorialMaterialSheetStep1Message =>
      'Switch between **Sheet Music**, **Chords**, **Children\'s Gestures**, **Audio**, and **YouTube** videos to choose the ideal format for service or rehearsal.';

  @override
  String get tutorialMaterialSheetStep2Title => 'Add to Setlist';

  @override
  String get tutorialMaterialSheetStep2Message =>
      'Tap the **+** button to include this arrangement directly in your active **Service Carousel** list or one of your **Playlists**.';

  @override
  String get tutorialMaterialSheetStep3Title => 'Metadata and Lyrics';

  @override
  String get tutorialMaterialSheetStep3Message =>
      'Check the **original key**, **rhythm**, **worship categories**, and preview the praise lyrics.';

  @override
  String get tutorialMaterialSheetStep4Title => 'Related Versions';

  @override
  String get tutorialMaterialSheetStep4Message =>
      'Quickly select **alternative arrangements**, versions in other keys, or hymns related to the selected praise.';

  @override
  String get tutorialMaterialSheetStep5Title => 'Suggest Improvement';

  @override
  String get tutorialMaterialSheetStep5Message =>
      'Found any discrepancy in chords, lyrics, or sheet music? Tap here to send a **correction suggestion** to curators.';

  @override
  String get tutorialMaterialSheetStep6Title => 'Selector Help';

  @override
  String get tutorialMaterialSheetStep6Message =>
      'Tap this icon whenever you need guidance on how to **choose materials** and **organize your setlist**.';

  @override
  String get tutorialMyContributionsStep1Title => 'Sign-In Required';

  @override
  String get tutorialMyContributionsStep1Message =>
      'Sign in with your **Google account** to access the history of suggestions, corrections, and materials you submitted.';

  @override
  String get tutorialMyContributionsStep2Title => 'No Submissions Yet';

  @override
  String get tutorialMyContributionsStep2Message =>
      'All **lyric, sheet music, or correction suggestions** submitted by you via the **Contribute** button will be listed on this screen.';

  @override
  String get tutorialMyContributionsStep3Title => 'Submission History';

  @override
  String get tutorialMyContributionsStep3Message =>
      'View the title, material type, and date of your collaboration. Tap any row to open the **details screen** and view team notes.';

  @override
  String get tutorialMyContributionsStep4Title => 'Review Status';

  @override
  String get tutorialMyContributionsStep4Message =>
      'Track the progress of your request: **pending**, **under review**, **approved**, or **rejected**.';

  @override
  String get tutorialMyContributionsStep5Title => 'Help & Tutorials';

  @override
  String get tutorialMyContributionsStep5Message =>
      'Tap the **(i) icon** anytime to review this guide or learn more about application screens!';

  @override
  String get tutorialOfflineStep1Title => 'Status and Disk Usage';

  @override
  String get tutorialOfflineStep1Message =>
      'Track total praises in the **local catalog**, the **last sync** date, and the **used and free space** on the device. Tap **Refresh** to recalculate data.';

  @override
  String get tutorialOfflineStep2Title => 'Material Search';

  @override
  String get tutorialOfflineStep2Message =>
      'Use the search field to quickly find specific types of sheet music or chords (e.g., **guitar**, **collection**, **choir**) and enable **Filter** to display only matching results.';

  @override
  String get tutorialOfflineStep3Title => 'Format Selection';

  @override
  String get tutorialOfflineStep3Message =>
      'Select the **material types** you want to keep available offline. On each item you can individually toggle between **sheet music (PDF)**, **chords**, and **audio**.';

  @override
  String get tutorialOfflineStep4Title => 'Download and Manage Storage';

  @override
  String get tutorialOfflineStep4Message =>
      'Tap **Download selected** to save files to the device for offline use. When you need to free disk space, tap **Remove downloads**.';

  @override
  String get tutorialOfflineStep5Title => 'Help & Tutorials';

  @override
  String get tutorialOfflineStep5Message =>
      'Whenever you have questions about offline storage, tap this **(i) icon** to review this step-by-step tutorial!';

  @override
  String get tutorialPlaylistsStep1Title => 'Setlist Tabs';

  @override
  String get tutorialPlaylistsStep1Message =>
      'Switch between your **Unsaved** lists (quick rehearsal picks), **Saved** lists (stored and synced setlists), and **Favorites** (for quick access).';

  @override
  String get tutorialPlaylistsStep2Title => 'Import Setlist';

  @override
  String get tutorialPlaylistsStep2Message =>
      'Received a shared list? Tap **Import setlist** and paste the link or code to load praises into your app.';

  @override
  String get tutorialPlaylistsStep3Title => 'Live Room';

  @override
  String get tutorialPlaylistsStep3Message =>
      'Open a room or connect to church rehearsal. All musicians follow the **real-time praise switching** during worship.';

  @override
  String get tutorialPlaylistsStep4Title => 'Create New Setlists';

  @override
  String get tutorialPlaylistsStep4Message =>
      'To assemble a new list, go to **Search** and tap the **\'+\'** button on any praise or sheet music version.';

  @override
  String get tutorialPlaylistsStep5Title => 'Help & Tutorials';

  @override
  String get tutorialPlaylistsStep5Message =>
      'Tap the **(i)** icon whenever you have questions about using any screen in the app!';

  @override
  String get tutorialPraiseStep1Title => 'Praise Information';

  @override
  String get tutorialPraiseStep1Message =>
      'See the **number** and **title** of the praise. Tap **Share** to copy the direct link or **Suggest improvement** to send us corrections.';

  @override
  String get tutorialPraiseStep2Title => 'Related Versions';

  @override
  String get tutorialPraiseStep2Message =>
      'When there are different **arrangements, keys, or variants**, you can easily switch between them by tapping related praise buttons.';

  @override
  String get tutorialPraiseStep3Title => 'Materials and Sheet Music';

  @override
  String get tutorialPraiseStep3Message =>
      'Access all **sheet music**, **chords**, **gestures**, and **audio** available for this praise. Tap an item to open or **+** to add it to your active list.';

  @override
  String get tutorialPraiseStep4Title => 'Lyrics and Metadata';

  @override
  String get tutorialPraiseStep4Message =>
      'View full **praise lyrics**, adjust font size, copy text, or tap the play button to open in the **dedicated reader** with auto-scroll.';

  @override
  String get tutorialPraiseStep5Title => 'Help & Tutorials';

  @override
  String get tutorialPraiseStep5Message =>
      'Whenever you have questions about praise details, tap this **(i) icon** to review this step-by-step tutorial!';

  @override
  String get tutorialProfileStep1Title => 'Account & Sync';

  @override
  String get tutorialProfileStep1Message =>
      'Connect your **Google** account to automatically sync your **praise lists**, preferences, and favorite materials across devices.';

  @override
  String get tutorialProfileStep2Title => 'Full Library';

  @override
  String get tutorialProfileStep2Message =>
      'Access the **Library** to explore the entire catalog in a **paginated list** format, with detailed instrument and category filters.';

  @override
  String get tutorialProfileStep3Title => 'Contribute';

  @override
  String get tutorialProfileStep3Message =>
      'Submit **new sheet music**, chords, gestures, or lyric corrections. Community collaboration keeps the collection updated and accurate!';

  @override
  String get tutorialProfileStep4Title => 'Offline Mode';

  @override
  String get tutorialProfileStep4Message =>
      'Download sheet music and lyrics files to use the app **without internet** during services and rehearsals with maximum speed.';

  @override
  String get tutorialProfileStep5Title => 'Help & Tutorials';

  @override
  String get tutorialProfileStep5Message =>
      'Tap the **(i)** icon anytime you want to review instructions and tips for this screen!';

  @override
  String get tutorialPublicPlaylistsStep1Title => 'Your Username';

  @override
  String get tutorialPublicPlaylistsStep1Message =>
      'Sign in with your Google account and create your **@username** to share your own public lists with the church.';

  @override
  String get tutorialPublicPlaylistsStep2Title => 'Search Members and Teams';

  @override
  String get tutorialPublicPlaylistsStep2Message =>
      'Type the **@username** of other team members to locate their public lists and shared setlists.';

  @override
  String get tutorialPublicPlaylistsStep3Title => 'Setlists and Import';

  @override
  String get tutorialPublicPlaylistsStep3Message =>
      'In results, view published lists and tap **import** to add praises to your active list.';

  @override
  String get tutorialPublicPlaylistsStep4Title => 'Help & Tutorials';

  @override
  String get tutorialPublicPlaylistsStep4Message =>
      'Tap the **(i) icon** anytime to review this step-by-step guide!';

  @override
  String get tutorialReaderStep1Title => 'Screen Fit';

  @override
  String get tutorialReaderStep1Message =>
      'Switch between fitting to **screen width** (great for enlarging sheet music) or **full page**. You can also press the **Z** key.';

  @override
  String get tutorialReaderStep2Title => 'Fullscreen Mode';

  @override
  String get tutorialReaderStep2Message =>
      'Tap to hide all bars and **focus on sheet music** during rehearsal or service. Use the **F** key to enter or **Esc** to exit.';

  @override
  String get tutorialReaderStep3Title => 'Page Indicator';

  @override
  String get tutorialReaderStep3Message =>
      'Displays the **current page** and **total pages**. Tap to jump to a page or **long press** to return directly to the **first page**!';

  @override
  String get tutorialReaderStep4Title => 'Tap on Margins (Sides)';

  @override
  String get tutorialReaderStep4Message =>
      'Tap the **left outer fifth** to go back and the **right outer fifth** to advance pages instantly, without dragging sheet music.';

  @override
  String get tutorialReaderStep5Title => 'Bluetooth Pedals & Keyboard';

  @override
  String get tutorialReaderStep5Message =>
      'Connect any **Bluetooth page-turner pedal** (AirTurn, PageFlip, Donner via PageUp/Down or Arrows) to turn pages and switch praises **hands-free**.';

  @override
  String get tutorialReaderStep6Title => 'Help & Tutorials';

  @override
  String get tutorialReaderStep6Message =>
      'Tap the **(i)** icon whenever you have questions about using the reader tools!';

  @override
  String get tutorialWelcomeTourStep1Title => '1. Search the Hymnal';

  @override
  String get tutorialWelcomeTourStep1Message =>
      'Type the **number**, the **title**, or any **lyric excerpt** to instantly locate hymns and songs in the collection.';

  @override
  String get tutorialWelcomeTourStep2Title => '2. Specialized Formats';

  @override
  String get tutorialWelcomeTourStep2Message =>
      'Tap the praise to select between **Sheet Music**, **Chords**, **Children\'s Gestures**, or **Lyrics**, with key transposition and auto-scroll.';

  @override
  String get tutorialWelcomeTourStep3Title => '3. Build Your Worship Setlist';

  @override
  String get tutorialWelcomeTourStep3Message =>
      'Tap the **(+)** button to include praises in the **Active Carousel**, allowing you to quickly switch between sheets during worship.';

  @override
  String get tutorialWelcomeTourStep4Title => '4. Setlist Always with You';

  @override
  String get tutorialWelcomeTourStep4Message =>
      'Access the **Playlists** tab to organize rehearsal playlists and open **Offline Storage** in Profile to praise **offline** anywhere!';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get privacyPolicyAboutDescription =>
      'Learn how we protect your data and privacy.';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteAccountDialogTitle => 'Delete account and data?';

  @override
  String get profileDeleteAccountDialogContent =>
      'This action is irreversible. Your account, synced playlists, audio flags, and preferences will be permanently deleted from the PLPCG servers.';

  @override
  String get profileDeleteAccountConfirm => 'Delete permanently';

  @override
  String get profileDeleteAccountSuccess =>
      'Your account and all associated data were successfully deleted.';

  @override
  String get profileDeleteAccountError =>
      'Could not delete your account. Check your connection and try again.';
}
