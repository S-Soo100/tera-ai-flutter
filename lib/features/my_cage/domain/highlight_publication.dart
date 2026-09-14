/// Optional publication contract. Legacy dynamically selected highlights have
/// no publication and must not be presented as a newly delivered batch.
class HighlightPublication {
  const HighlightPublication(
      {required this.batchId,
      required this.captureStart,
      required this.captureEnd,
      required this.publishedAt,
      required this.status});
  final String batchId, status;
  final DateTime captureStart, captureEnd, publishedAt;
  bool availableAt(DateTime now) =>
      status == 'ready' &&
      batchId.isNotEmpty &&
      captureStart.isBefore(captureEnd) &&
      !captureEnd.isAfter(publishedAt) &&
      !publishedAt.isAfter(now);
  static HighlightPublication? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['batch_id'];
    final start = DateTime.tryParse('${value['capture_start']}');
    final end = DateTime.tryParse('${value['capture_end']}');
    final published = DateTime.tryParse('${value['published_at']}');
    if (id is! String ||
        id.isEmpty ||
        start == null ||
        end == null ||
        published == null) {
      return null;
    }
    return HighlightPublication(
        batchId: id,
        captureStart: start,
        captureEnd: end,
        publishedAt: published,
        status: '${value['status']}');
  }
}

/// Initialization, buffering and seeking do not count as viewing. Only a
/// progressing playhead after playback begins acknowledges the arrival.
class HighlightPlaybackTracker {
  Duration? _previous;
  bool _read = false;
  void resetPosition(Duration position) => _previous = position;
  bool observe(
      {required Duration position,
      required bool playing,
      bool buffering = false,
      bool seeking = false}) {
    final previous = _previous;
    _previous = position;
    if (_read ||
        previous == null ||
        seeking ||
        buffering ||
        !playing ||
        position <= previous) {
      return false;
    }
    _read = true;
    return true;
  }
}
