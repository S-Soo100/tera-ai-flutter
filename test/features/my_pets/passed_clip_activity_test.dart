import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_pets/data/passed_clip_activity_repository.dart';
import 'package:vivanaut/features/my_pets/data/activity_repository.dart';
import 'package:vivanaut/features/my_pets/domain/activity_summary.dart';
import 'package:vivanaut/features/my_pets/domain/activity_window.dart';

MotionClip _clip(String id, DateTime startedAt, double seconds) => MotionClip(
    id: id, cameraId: 'cam', startedAt: startedAt, durationSec: seconds);

/// 통과 clip id 페이지를 흉내 낸다. 커서 하나로 두 페이지를 준다.
class _Refs {
  _Refs(this.pages);
  final List<List<MotionClip>> pages;
  final List<({DateTime? since, DateTime? until, String? cursor})> calls = [];

  Future<PassedClipRefPageLike> load(
      {required String cameraId,
      DateTime? since,
      DateTime? until,
      String? cursor}) async {
    calls.add((since: since, until: until, cursor: cursor));
    final index = cursor == null ? 0 : int.parse(cursor);
    final page = pages[index];
    final more = index + 1 < pages.length;
    return (
      clipIds: [for (final c in page) c.id],
      startedAts: [for (final c in page) c.startedAt],
      oldestStartedAt: page.isEmpty ? null : page.last.startedAt,
      nextCursor: more ? '${index + 1}' : null,
      hasMore: more,
    );
  }
}

/// 2026-09-21 사용자 결정: 활동시간 = **하이라이트 규칙을 통과한 영상**의
/// 길이 합. 실제로 움직인 구간의 합이 아니다.
void main() {
  final day = ActivityWindow(
      startUtc: DateTime.utc(2026, 9, 19), endUtc: DateTime.utc(2026, 9, 20));

  PassedClipActivityRepository repoFor(List<List<MotionClip>> pages,
      {_Refs? spy}) {
    final refs = spy ?? _Refs(pages);
    final all = [for (final page in pages) ...page];
    return PassedClipActivityRepository(
      listRefs: refs.load,
      hydrate: (ids) async => [
        for (final c in all)
          if (ids.contains(c.id)) c
      ],
    );
  }

  test('통과 영상 길이의 합이 활동 시간이다', () async {
    final data = await repoFor([
      [
        _clip('a', DateTime.utc(2026, 9, 19, 1), 60),
        _clip('b', DateTime.utc(2026, 9, 19, 5), 30),
      ]
    ]).load(cameraId: 'cam', window: day);

    expect(data.intervals.length, 2);
    final total = data.intervals.fold<double>(
        0, (sum, i) => sum + i.endUtc.difference(i.startUtc).inSeconds);
    expect(total, 90);
    expect(data.videoClipCount, 2);
    expect(data.dataStatus, ActivityDataStatus.exact);
  });

  test('길이를 아는 영상이므로 추정이 아니다', () async {
    final data = await repoFor([
      [_clip('a', DateTime.utc(2026, 9, 19, 1), 60)]
    ]).load(cameraId: 'cam', window: day);

    expect(data.intervals.single.quality, ActivityQuality.exact);
    expect(data.fallbackClipCount, 0);
    expect(data.exactClipCount, 1);
  });

  test('창 밖으로 넘치는 영상은 창 끝에서 자른다', () async {
    // 23:50에 시작한 60초 클립은 다음 날로 10초 넘어간다.
    final data = await repoFor([
      [_clip('a', DateTime.utc(2026, 9, 19, 23, 59, 30), 60)]
    ]).load(cameraId: 'cam', window: day);

    expect(data.intervals.single.endUtc, day.endUtc);
    expect(data.intervals.single.endUtc.difference(day.startUtc).inHours, 24);
  });

  test('커서를 따라 끝까지 읽는다', () async {
    final pages = [
      [_clip('a', DateTime.utc(2026, 9, 19, 3), 60)],
      [_clip('b', DateTime.utc(2026, 9, 19, 2), 60)],
      [_clip('c', DateTime.utc(2026, 9, 19, 1), 60)],
    ];
    final spy = _Refs(pages);
    final data =
        await repoFor(pages, spy: spy).load(cameraId: 'cam', window: day);

    expect(data.intervals.length, 3);
    expect(spy.calls.length, 3);
    expect(spy.calls.first.since, day.startUtc);
    expect(spy.calls.first.until, day.endUtc);
  });

  test('통과 영상이 없으면 noVideo — 0으로 단정하지 않는다', () async {
    final data =
        await repoFor([<MotionClip>[]]).load(cameraId: 'cam', window: day);

    expect(data.intervals, isEmpty);
    expect(data.videoClipCount, 0);
    expect(data.dataStatus, ActivityDataStatus.noVideo);
  });

  test('길이가 0인 영상은 구간을 만들지 않는다', () async {
    final data = await repoFor([
      [_clip('a', DateTime.utc(2026, 9, 19, 1), 0)]
    ]).load(cameraId: 'cam', window: day);

    expect(data.intervals, isEmpty);
    expect(data.videoClipCount, 1, reason: '영상은 있었다');
  });

  test('원본이 지워져 메타를 못 채운 id는 조용히 빠진다', () async {
    final refs = _Refs([
      [
        _clip('a', DateTime.utc(2026, 9, 19, 1), 60),
        _clip('gone', DateTime.utc(2026, 9, 19, 2), 60),
      ]
    ]);
    final repo = PassedClipActivityRepository(
      listRefs: refs.load,
      hydrate: (ids) async => [_clip('a', DateTime.utc(2026, 9, 19, 1), 60)],
    );

    final data = await repo.load(cameraId: 'cam', window: day);
    expect(data.intervals.length, 1);
    expect(data.videoClipCount, 1);
  });
}
