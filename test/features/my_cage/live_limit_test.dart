// 라이브 시청 제한(2026-09-30) — 서버 응답 파싱·Realtime 행 판정·기기 이름.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vivanaut/features/my_cage/data/camera_exceptions.dart';
import 'package:vivanaut/features/my_cage/data/live_viewer_identity.dart';
import 'package:vivanaut/features/my_cage/data/webrtc_signaling_repository.dart';
import 'package:vivanaut/features/my_cage/domain/live_limit.dart';
import 'package:vivanaut/features/my_cage/presentation/live_limit_providers.dart';

Exception? _parse(int code, String body, {Map<String, String>? headers}) =>
    WebRtcSignalingRepository.liveLimitException(
        http.Response(body, code, headers: headers ?? const {}));

void main() {
  group('offer 응답 → 시청 제한 예외', () {
    test('409 live_in_use — 시청 기기 이름', () {
      final e = _parse(409,
          '{"detail":{"code":"live_in_use","viewer":"iPhone 15","since":"x"}}');
      expect(e, isA<LiveInUseException>());
      expect((e as LiveInUseException).viewer, 'iPhone 15');
    });

    test('409 다른 code는 건드리지 않는다', () {
      expect(_parse(409, '{"detail":"conflict"}'), isNull);
    });

    test('429 live_cooldown — retry_after 초', () {
      final e = _parse(
          429, '{"detail":{"code":"live_cooldown","retry_after":240}}',
          headers: {'retry-after': '240'});
      expect((e as LiveCooldownException).retryAfter,
          const Duration(seconds: 240));
    });

    test('429 rate_limited', () {
      final e =
          _parse(429, '{"detail":{"code":"rate_limited","retry_after":90}}');
      expect((e as LiveRateLimitedException).retryAfter,
          const Duration(seconds: 90));
    });

    test('구 서버 429(문자열 detail)는 시도 과다 — 헤더 Retry-After', () {
      final e = _parse(429,
          '{"detail":"live offer rate limit exceeded for this camera"}',
          headers: {'retry-after': '120'});
      expect((e as LiveRateLimitedException).retryAfter,
          const Duration(seconds: 120));
    });

    test('200·504는 해당 없음', () {
      expect(_parse(200, '{}'), isNull);
      expect(_parse(504, '{}'), isNull);
    });
  });

  group('cameras 행 → 내 세션이 끝났나', () {
    final now = DateTime.utc(2026, 9, 30, 12);

    test('다른 세션 + taken_over → 가져가짐', () {
      final r = CameraLiveSession.fromRow({
        'live_session_id': 'other',
        'live_viewer_id': 'install-b',
        'live_viewer': 'Galaxy S24',
        'live_end_reason': 'taken_over',
      }).endedFor('mine', 'me', now)!;
      expect(r.kind, LiveLimitKind.takenOver);
      expect(r.viewer, 'Galaxy S24');
    });

    test('우리 기기의 옛 세션 행(taken_over 잔존)은 가져가짐이 아니다', () {
      // 우리가 예전에 가져온 행이 새 세션 뒤에 늦게 도착한 경우.
      final row = CameraLiveSession.fromRow({
        'live_session_id': 'mine-old',
        'live_viewer_id': 'me',
        'live_viewer': 'iPhone 15',
        'live_end_reason': 'taken_over',
      });
      expect(row.endedFor('mine', 'me', now), isNull);
      expect(row.heldByOther('me'), isNull);
      expect(row.heldByOther('install-b'), isNotNull);
    });

    test('세션 없음 + time_limit → 쉼(서버 시각, 5분 상한)', () {
      final r = CameraLiveSession.fromRow({
        'live_session_id': null,
        'live_end_reason': 'time_limit',
        'live_cooldown_until': '2026-09-30T12:04:00+00:00',
      }).endedFor('mine', 'me', now)!;
      expect(r.kind, LiveLimitKind.cooldown);
      expect(r.remaining(now), const Duration(minutes: 4));

      // 폰 시계가 크게 어긋나도 5분을 넘지 않는다.
      final skew = CameraLiveSession.fromRow({
        'live_end_reason': 'time_limit',
        'live_cooldown_until': '2026-09-30T13:00:00Z',
      }).endedFor('mine', 'me', now)!;
      expect(skew.remaining(now), kLiveCooldownDuration);
    });

    test('내 세션·직접 닫음·구 DB(컬럼 없음)는 판정 없음', () {
      expect(
          CameraLiveSession.fromRow({
            'live_session_id': 'mine',
            'live_end_reason': 'taken_over',
          }).endedFor('mine', 'me', now),
          isNull);
      expect(
          CameraLiveSession.fromRow({'live_end_reason': 'closed'})
              .endedFor('mine', 'me', now),
          isNull);
      expect(CameraLiveSession.fromRow({'is_online': true}).endedFor('mine', 'me', now),
          isNull);
    });
  });

  test('안드로이드 기기 이름 — 제조사 + 모델 코드', () {
    expect(androidLabel('samsung', 'SM-S921N'), 'Samsung SM-S921N');
    expect(androidLabel('Xiaomi', 'Xiaomi 13T'), 'Xiaomi 13T');
    expect(androidLabel('', 'Pixel 8'), 'Pixel 8');
  });

  group('끝나기 직전 알약 카운트', () {
    Future<Duration?> first(DateTime until) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(liveEndingSoonProvider(until), (_, __) {});
      addTearDown(sub.close);
      return c.read(liveEndingSoonProvider(until).future);
    }

    test('1분보다 많이 남으면 null(알약 없음)', () async {
      expect(await first(DateTime.now().add(const Duration(minutes: 5))),
          isNull);
    });

    test('1분 안이면 남은 시간', () async {
      final left =
          await first(DateTime.now().add(const Duration(seconds: 30)));
      expect(left!.inSeconds, inInclusiveRange(28, 30));
    });

    test('지나면 0 — 알약은 "곧"으로 남는다', () async {
      expect(await first(DateTime.now().subtract(const Duration(seconds: 3))),
          Duration.zero);
    });
  });
}
