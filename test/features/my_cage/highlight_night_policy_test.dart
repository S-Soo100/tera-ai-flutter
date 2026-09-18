import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_night_policy.dart';
import 'package:vivanaut/features/my_cage/domain/highlight_publication.dart';
import 'package:vivanaut/features/my_cage/domain/nightly_highlight.dart';

NightlyHighlight _h(String id, DateTime startedAtUtc,
        {String dayKey = '2026-08-16', HighlightPublication? publication}) =>
    NightlyHighlight(
      clipId: id,
      cameraId: 'cam',
      startedAt: startedAtUtc.toLocal(),
      tier: 'featured',
      dayKey: dayKey,
      publication: publication,
    );

void main() {
  // 사용자 예시(2026-09-19): 8/16 밤~8/17 아침 촬영 → 8/18 아침 8시 공개.
  test('밤 구간은 D 20:00~D+1 08:00 KST, 공개는 D+2 08:00 KST', () {
    final w = nightWindowFor('2026-08-16')!;
    expect(w.captureStart, DateTime.utc(2026, 8, 16, 11)); // 8/16 20:00 KST
    expect(w.captureEnd, DateTime.utc(2026, 8, 16, 23)); // 8/17 08:00 KST
    expect(w.publishedAt, DateTime.utc(2026, 8, 17, 23)); // 8/18 08:00 KST
  });

  test('월말을 넘겨도 공개 시각이 맞다', () {
    expect(nightWindowFor('2026-08-31')!.publishedAt,
        DateTime.utc(2026, 9, 1, 23)); // 9/2 08:00 KST
  });

  test('형식이 깨진 day_key는 null', () {
    expect(nightWindowFor(''), isNull);
    expect(nightWindowFor('2026-8-16'), isNull);
  });

  test('공개 시각 전에는 숨기고, 정각부터 보인다', () {
    final night = _h('a', DateTime.utc(2026, 8, 16, 15)); // 8/17 00:00 KST
    expect(applyNightPolicy([night], DateTime.utc(2026, 8, 17, 22, 59)),
        isEmpty);
    final shown = applyNightPolicy([night], DateTime.utc(2026, 8, 17, 23));
    expect(shown.single.clipId, 'a');
    expect(shown.single.publication!.batchId, 'night:2026-08-16');
    expect(shown.single.publication!.publishedAt,
        DateTime.utc(2026, 8, 17, 23));
  });

  test('낮(08:00 KST 이후) 촬영분은 하이라이트에서 뺀다', () {
    final day = _h('d', DateTime.utc(2026, 8, 17, 1)); // 8/17 10:00 KST
    final edge = _h('e', DateTime.utc(2026, 8, 16, 23)); // 정확히 08:00 KST
    final night = _h('n', DateTime.utc(2026, 8, 16, 22, 59));
    final shown =
        applyNightPolicy([day, edge, night], DateTime.utc(2026, 8, 20));
    expect(shown.map((h) => h.clipId), ['n']);
  });

  test('서버가 publication을 주면 그 값을 우선한다', () {
    final server = HighlightPublication(
      batchId: 'srv',
      captureStart: DateTime.utc(2026, 8, 16, 11),
      captureEnd: DateTime.utc(2026, 8, 16, 23),
      publishedAt: DateTime.utc(2026, 8, 18, 23), // 서버가 하루 늦게 공개
      status: 'ready',
    );
    final h = _h('s', DateTime.utc(2026, 8, 16, 15), publication: server);
    expect(applyNightPolicy([h], DateTime.utc(2026, 8, 18)), isEmpty);
    expect(
        applyNightPolicy([h], DateTime.utc(2026, 8, 19)).single.publication!
            .batchId,
        'srv');
  });

  test('다음 공개 시각은 다음 23:00 UTC(08:00 KST)', () {
    expect(nextPublishAfter(DateTime.utc(2026, 8, 17, 22)),
        DateTime.utc(2026, 8, 17, 23));
    expect(nextPublishAfter(DateTime.utc(2026, 8, 17, 23)),
        DateTime.utc(2026, 8, 18, 23));
  });
}
