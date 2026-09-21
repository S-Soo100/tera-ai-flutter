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

MotionClipPage _page(List<MotionClip> items, {bool more = false}) => (
      items: items,
      nextCursor: items.isEmpty || !more
          ? null
          : (startedAt: items.last.startedAt, id: items.last.id, token: null),
      hasMore: more,
    );

const ClipFeedQuery _all = (ownerId: 'u', cameraId: 'cam', range: null);

/// 2026-09-21 사용자 결정 — **아직 판정되지 않은 영상은 일단 보여준다.**
///
/// 정책 v2는 미통과 영상을 완전히 숨기는데, petcam-lab의 판정이 늦으면
/// "미통과"와 "아직 안 봄"이 구분되지 않아 최근 영상이 통째로 사라진 것처럼
/// 보인다(실측: 한 카메라가 8/4 이후 판정이 멈춰 미판정 1187건).
///
/// 그래서 **판정 전 구간을 먼저 끝까지 읽고 그다음 통과 목록으로 넘어간다.**
/// 맨 위에 한 페이지만 얹으면 가운데가 뚫린 목록이 된다.
void main() {
  final judged = DateTime.utc(2026, 8, 4, 20);
  final newer1 = DateTime.utc(2026, 9, 20, 11);
  final newer2 = DateTime.utc(2026, 9, 20, 12);

  test('판정 지점보다 뒤 영상을 먼저 보여준다', () async {
    DateTime? askedAfter;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'judged': judged}),
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range, before}) async {
        askedAfter = after;
        return _page([_clip('p2', newer2), _clip('p1', newer1)]);
      },
    );

    final page = await source.loadPage(_all);

    expect(askedAfter, judged, reason: '판정이 끝난 지점부터 본다');
    expect(page.items.map((c) => c.id), ['p2', 'p1']);
    expect(page.hasMore, isTrue, reason: '아래에 통과 목록이 남아 있다');
    expect(page.nextCursor?.token, startsWith('pending:'));
  });

  test('판정 전 구간이 여러 페이지여도 끝까지 읽는다 — 가운데가 뚫리지 않는다', () async {
    final pending = [
      for (var i = 0; i < 120; i++)
        _clip('p$i', DateTime.utc(2026, 9, 20).subtract(Duration(minutes: i)))
    ];
    final asked = <MotionClipCursor?>[];
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'judged': judged}),
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range, before}) async {
        asked.add(before);
        final start = before == null
            ? 0
            : pending.indexWhere((c) => c.id == before.id) + 1;
        final slice = pending.skip(start).take(60).toList();
        return _page(slice, more: start + 60 < pending.length);
      },
    );

    final first = await source.loadPage(_all);
    expect(first.items.length, 60);
    final second = await source.loadPage(_all, before: first.nextCursor);
    expect(second.items.length, 60);
    expect(second.items.first.id, 'p60', reason: '61번째부터 이어 읽는다');
    expect(asked.last?.id, 'p59', reason: '커서로 이어 읽는다');

    // 판정 전이 떨어지면 통과 목록으로 넘어간다.
    final third = await source.loadPage(_all, before: second.nextCursor);
    expect(third.items.map((c) => c.id), ['judged']);
  });

  test('판정 지점을 커서에 실어 페이지마다 다시 묻지 않는다', () async {
    var refCalls = 0;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        refCalls++;
        return _refs({'judged': judged});
      },
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range, before}) async {
        expect(after, judged);
        return _page([_clip(before == null ? 'p1' : 'p2', newer1)]);
      },
    );

    final first = await source.loadPage(_all);
    expect(refCalls, 1);
    await source.loadPage(_all, before: first.nextCursor);
    expect(refCalls, 1, reason: '판정 지점은 커서에 실려 있다');
  });

  test('통과분이 하나도 없으면 전부 판정 전으로 본다', () async {
    DateTime? askedAfter;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async => _refs({}),
      hydrate: (ids) async => const [],
      listPending: ({required cameraId, required after, range, before}) async {
        askedAfter = after;
        return _page([_clip('p1', newer1)]);
      },
    );

    final page = await source.loadPage(_all);

    expect(askedAfter, DateTime.utc(1970), reason: '판정된 지점이 없다');
    expect(page.items.map((c) => c.id), ['p1']);
  });

  test('판정 전 조회가 실패해도 통과 목록은 그대로 보여준다', () async {
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'judged': judged}),
      hydrate: (ids) async => [_clip('judged', judged)],
      listPending: ({required cameraId, required after, range, before}) async =>
          throw Exception('네트워크'),
    );

    final page = await source.loadPage(_all);
    expect(page.items.map((c) => c.id), ['judged']);
  });

  test('통과 목록 커서로 들어오면 판정 전을 다시 붙이지 않는다', () async {
    var pendingCalls = 0;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'old': DateTime.utc(2026, 7)}),
      hydrate: (ids) async => [_clip('old', DateTime.utc(2026, 7))],
      listPending: ({required cameraId, required after, range, before}) async {
        pendingCalls++;
        return _page([_clip('p1', newer1)]);
      },
    );

    await source.loadPage(_all,
        before: (startedAt: judged, id: 'judged', token: 'tok'));

    expect(pendingCalls, 0);
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

  test('기간을 골라도 판정 지점은 전체에서 보고, 범위는 그 기간으로 자른다', () async {
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
      listPending: ({required cameraId, required after, range, before}) async {
        pendingRange = range;
        return _page([_clip('p1', newer1)]);
      },
    );

    final page =
        await source.loadPage((ownerId: 'u', cameraId: 'cam', range: range));

    expect(asked.first, (since: null, until: null),
        reason: '판정 지점은 기간과 무관하게 전체에서 본다');
    expect(pendingRange, range);
    expect(page.items.map((c) => c.id), ['p1']);
  });
}
