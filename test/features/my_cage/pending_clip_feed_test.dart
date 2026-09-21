import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/highlight_repository.dart';
import 'package:vivanaut/features/my_cage/data/passed_clip_feed_source.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip_page.dart';

PassedClipRefPage _refs(Map<String, DateTime> items,
        {String? next, bool more = false}) =>
    (
      clipIds: items.keys.toList(),
      startedAts: items.values.toList(),
      oldestStartedAt: items.isEmpty
          ? null
          : items.values.reduce((a, b) => a.isBefore(b) ? a : b),
      nextCursor: next,
      hasMore: more,
    );

MotionClip _clip(String id, DateTime at) =>
    MotionClip(id: id, cameraId: 'cam', startedAt: at, durationSec: 60);

const ClipFeedQuery _all = (ownerId: 'u', cameraId: 'cam', range: null);

/// 2026-09-21 사용자 결정 — **아직 판정되지 않은 영상은 일단 보여준다.**
///
/// 정책 v2는 미통과 영상을 완전히 숨기는데, petcam-lab의 판정이 늦으면
/// "미통과"와 "아직 안 봄"이 구분되지 않아 어제 찍힌 영상이 통째로 사라진
/// 것처럼 보인다. 통과 목록의 맨 위(가장 최근 통과분)를 **판정이 끝난
/// 지점**으로 보고, 그보다 뒤 영상은 판정 전으로 간주해 같이 보여준다.
void main() {
  final judged = DateTime.utc(2026, 9, 20, 10);
  final newer1 = DateTime.utc(2026, 9, 20, 11);
  final newer2 = DateTime.utc(2026, 9, 20, 12);

  test('가장 최근 통과분보다 뒤 영상은 판정 전으로 보고 함께 보여준다', () async {
    DateTime? askedAfter;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'judged': judged}),
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range}) async {
        askedAfter = after;
        return [_clip('p2', newer2), _clip('p1', newer1)];
      },
    );

    final page = await source.loadPage(_all);

    expect(askedAfter, judged, reason: '판정이 끝난 지점부터 본다');
    expect(page.items.map((c) => c.id), ['p2', 'p1', 'judged'],
        reason: '판정 전 영상이 최신순 맨 위에 붙는다');
  });

  test('통과분이 하나도 없으면 전부 판정 전으로 본다', () async {
    DateTime? askedAfter;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async => _refs({}),
      hydrate: (ids) async => const [],
      listPending: ({required cameraId, required after, range}) async {
        askedAfter = after;
        return [_clip('p1', newer1)];
      },
    );

    final page = await source.loadPage(_all);

    expect(askedAfter, DateTime.utc(1970), reason: '판정된 지점이 없다');
    expect(page.items.map((c) => c.id), ['p1']);
  });

  test('두 번째 페이지에는 판정 전 영상을 또 붙이지 않는다', () async {
    var pendingCalls = 0;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'old': DateTime.utc(2026, 9, 19)}),
      hydrate: (ids) async => [_clip('old', DateTime.utc(2026, 9, 19))],
      listPending: ({required cameraId, required after, range}) async {
        pendingCalls++;
        return [_clip('p1', newer1)];
      },
    );

    await source.loadPage(_all,
        before: (startedAt: judged, id: 'judged', token: 'tok'));

    expect(pendingCalls, 0, reason: '맨 위 페이지에서만 붙인다');
  });

  test('통과분과 겹치는 id는 한 번만 나온다', () async {
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'a': newer1}),
      hydrate: (ids) async => [_clip('a', newer1)],
      listPending: ({required cameraId, required after, range}) async =>
          [_clip('a', newer1)],
    );

    final page = await source.loadPage(_all);
    expect(page.items.map((c) => c.id), ['a']);
  });

  test('판정 전 조회가 실패해도 통과 목록은 그대로 보여준다', () async {
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'judged': judged}),
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range}) async =>
          throw Exception('네트워크'),
    );

    final page = await source.loadPage(_all);
    expect(page.items.map((c) => c.id), ['judged']);
  });

  test('판정 전 조회를 안 붙이면 예전 그대로다', () async {
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'judged': judged}),
      hydrate: (ids) async => [_clip('judged', judged)],
    );

    final page = await source.loadPage(_all);
    expect(page.items.map((c) => c.id), ['judged']);
  });

  test('기간을 고르면 그 기간의 판정 지점을 따로 묻는다', () async {
    final range = (
      start: DateTime.utc(2026, 9, 20),
      endExclusive: DateTime.utc(2026, 9, 21)
    );
    final asked = <({DateTime? since, DateTime? until})>[];
    ClipDateRange? pendingRange;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        asked.add((since: since, until: until));
        return _refs({'judged': judged});
      },
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range}) async {
        pendingRange = range;
        return [_clip('p1', newer1)];
      },
    );

    final page = await source
        .loadPage((ownerId: 'u', cameraId: 'cam', range: range));

    expect(asked.any((a) => a.since == null && a.until == null), isTrue,
        reason: '판정 지점은 기간과 무관하게 전체에서 본다');
    expect(pendingRange, range, reason: '보여줄 범위는 고른 기간으로 자른다');
    expect(page.items.map((c) => c.id), ['p1', 'judged']);
  });
}
