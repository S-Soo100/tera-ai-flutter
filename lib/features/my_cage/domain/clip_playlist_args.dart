enum ClipPlaybackSource { hour, highlight, bookmark, single }

class ClipPlaylistArgs {
  const ClipPlaylistArgs(
      {required this.playlist,
      this.playFromSec = const {},
      this.source = ClipPlaybackSource.single,
      this.cameraId,
      this.hourStart,
      this.hourEndExclusive,
      this.highlightBatchId});
  final List<String> playlist;
  final Map<String, double> playFromSec;
  final ClipPlaybackSource source;
  final String? cameraId;
  final DateTime? hourStart, hourEndExclusive;
  final String? highlightBatchId;
}
