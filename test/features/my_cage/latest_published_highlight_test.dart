import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_publication.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';

HighlightPublication _pub(String batchId, DateTime publishedAt,
        {String status = 'ready'}) =>
    HighlightPublication(
      batchId: batchId,
      captureStart: publishedAt.subtract(const Duration(hours: 36)),
      captureEnd: publishedAt.subtract(const Duration(hours: 24)),
      publishedAt: publishedAt,
      status: status,
    );

NightlyHighlight _h(String clipId,
        {String cameraId = 'cam',
        HighlightPublication? publication,
        int rank = 1}) =>
    NightlyHighlight(
      clipId: clipId,
      cameraId: cameraId,
      startedAt: DateTime.utc(2026, 9, 14, 13),
      tier: 'featured',
      dayKey: '2026-09-14',
      episodeRank: rank,
      publication: publication,
    );

DayHighlightGroup _group(List<NightlyHighlight> featured) =>
    (dayKey: '2026-09-14', featured: featured, candidates: const []);

void main() {
  final now = DateTime.utc(2026, 9, 19, 3);

  test('가장 늦게 공개된 묶음의 대표를 고른다', () {
    final older = _h('a',
        publication: _pub('night:09-13', DateTime.utc(2026, 9, 14, 23)));
    final newer = _h('b',
        publication: _pub('night:09-14', DateTime.utc(2026, 9, 15, 23)));
    final picked = latestPublishedHighlight([
      _group([older]),
      _group([newer]),
    ], now);
    expect(picked?.clipId, 'b');
  });

  test('같은 묶음이면 순위가 높은(작은) 대표를 고른다', () {
    final pub = _pub('night:09-14', DateTime.utc(2026, 9, 15, 23));
    final picked = latestPublishedHighlight([
      _group([_h('r2', publication: pub, rank: 2), _h('r1', publication: pub)]),
    ], now);
    expect(picked?.clipId, 'r1');
  });

  test('아직 공개 전이거나 공개 정보·카메라가 없으면 고르지 않는다', () {
    final future = _h('future',
        publication: _pub('night:09-18', DateTime.utc(2026, 9, 19, 23)));
    final noPublication = _h('none');
    final noCamera = _h('nocam',
        cameraId: '',
        publication: _pub('night:09-14', DateTime.utc(2026, 9, 15, 23)));
    expect(
        latestPublishedHighlight([
          _group([future, noPublication, noCamera])
        ], now),
        isNull);
  });
}
