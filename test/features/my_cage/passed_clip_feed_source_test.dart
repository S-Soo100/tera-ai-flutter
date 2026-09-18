import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/data/camera_exceptions.dart';
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
    MotionClip(id: id, cameraId: 'cam', startedAt: at, durationSec: 10);

const ClipFeedQuery _all = (ownerId: 'u', cameraId: 'cam', range: null);

void main() {
  test('통과 id를 모션 클립으로 채워 최신순으로 돌려주고 서버 커서를 싣는다', () async {
    final t1 = DateTime.utc(2026, 9, 7, 15), t2 = DateTime.utc(2026, 9, 7, 16);
    String? askedCursor = 'unset';
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        askedCursor = cursor;
        return _refs({'a': t1, 'b': t2}, next: 'tok', more: true);
      },
      hydrate: (ids) async => [_clip('a', t1), _clip('b', t2)],
    );
    final page = await source.loadPage(_all);
    expect(askedCursor, isNull);
    expect(page.items.map((c) => c.id), ['b', 'a']);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, (startedAt: t1, id: 'a', token: 'tok'));
  });

  test('다음 페이지는 이전 커서의 token으로 요청한다', () async {
    String? askedCursor;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        askedCursor = cursor;
        return _refs({});
      },
      hydrate: (ids) async => const [],
    );
    await source.loadPage(_all,
        before: (startedAt: DateTime.utc(2026), id: 'x', token: 'tok'));
    expect(askedCursor, 'tok');
  });

  test('원본이 지워진 id는 빠진다', () async {
    final t = DateTime.utc(2026, 9, 7, 15);
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          _refs({'gone': t, 'kept': t}),
      hydrate: (ids) async => [_clip('kept', t)],
    );
    expect((await source.loadPage(_all)).items.map((c) => c.id), ['kept']);
  });

  test('범위 상한을 앱에서도 거르고, 범위 안이 나올 때까지 넘긴다', () async {
    final range = (
      start: DateTime.utc(2026, 9, 5),
      endExclusive: DateTime.utc(2026, 9, 6),
    );
    final after = DateTime.utc(2026, 9, 7),
        inside = DateTime.utc(2026, 9, 5, 12);
    var calls = 0;
    DateTime? askedSince, askedUntil;
    final source = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        calls++;
        askedSince = since;
        askedUntil = until;
        return cursor == null
            ? _refs({'late': after}, next: 'p2', more: true)
            : _refs({'in': inside});
      },
      hydrate: (ids) async => [
        for (final id in ids) _clip(id, id == 'in' ? inside : after),
      ],
    );
    final page =
        await source.loadPage((ownerId: 'u', cameraId: 'cam', range: range));
    expect(calls, 2);
    expect(askedSince, range.start);
    expect(askedUntil, range.endExclusive);
    expect(page.items.map((c) => c.id), ['in']);
    expect(page.hasMore, isFalse);
  });

  test('504는 한 번 재시도하고, 다른 에러는 바로 던진다', () async {
    var calls = 0;
    final retry = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async {
        if (++calls == 1) throw const BackendException(504, 'timeout');
        return _refs({});
      },
      hydrate: (ids) async => const [],
      retryDelay: Duration.zero,
    );
    await retry.loadPage(_all);
    expect(calls, 2);

    final fail = PassedClipFeedSource(
      listRefs: ({required cameraId, since, until, cursor}) async =>
          throw const BackendException(502, 'db'),
      hydrate: (ids) async => const [],
      retryDelay: Duration.zero,
    );
    expect(fail.loadPage(_all), throwsA(isA<BackendException>()));
  });
}
