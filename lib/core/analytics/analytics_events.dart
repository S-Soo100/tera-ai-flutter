/// Only fixed vocabulary may cross the analytics boundary. No identifiers,
/// free text, URLs, exception messages or device values are accepted.
enum AnalyticsFeature {
  live,
  clips,
  highlights,
  bookmarks,
  environment,
  control,
  routines,
  pets,
  reports,
  community;

  String get wireName => 'feature_${name}_used';
}

enum AnalyticsEvent {
  pairStarted,
  pairDeviceSelected,
  pairWifiSubmitted,
  pairWifiSucceeded,
  pairFailed,
  pairCancelled,
  liveRequested,
  liveConnected,
  liveFailed,
  clipRequested,
  clipPlaying,
  clipAutoPlaying,
  clipFailed,
  bookmarkAdded,
  bookmarkRemoved,
  bookmarkReplayed,
  clipShareOpened,
  controlRequested,
  controlAccepted,
  controlFailed,
  routineSaved,
  petSaved,
  communityPublished,
  communityLiked;

  String get wireName => name.replaceAllMapped(
        RegExp('[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      );
}
