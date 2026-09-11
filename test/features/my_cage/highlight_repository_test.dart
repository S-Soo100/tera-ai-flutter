import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivnanaut/features/my_cage/data/camera_exceptions.dart';
import 'package:vivnanaut/features/my_cage/data/highlight_repository.dart';

/// petcam-api GET /highlights 계약(2026-09-08 자동 규칙 + 사람 확정) 검증.
void main() {
  final since = DateTime.utc(2026, 9, 7, 13);

  HighlightRepository repo(MockClient client, {String? token = 'jwt'}) =>
      HighlightRepository(
        baseUrl: 'https://api.example',
        tokenProvider: () async => token,
        client: client,
      );

  test('요청 경로·쿼리·Bearer 헤더 + source/reason 파싱', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'highlights': [
            {
              'clip_id': 'c1',
              'camera_id': 'cam1',
              'camera_name': '거실',
              'started_at': '2026-09-07T14:00:00Z',
              'duration_sec': 30,
              'source': 'rule',
              'reason': '움직임 12.4초 · 최장 연속 6.1초',
              'rule_version': 'hl-rule-v0',
              'decided_at': null,
            },
            {
              'clip_id': 'c2',
              'camera_id': 'cam1',
              'camera_name': '거실',
              'started_at': '2026-09-07T15:00:00Z',
              'duration_sec': 12.5,
              'source': 'human',
              'reason': '움직임 4.0초',
              'rule_version': 'hl-rule-v0',
              'decided_at': '2026-09-08T01:00:00Z',
            },
          ],
          'count': 2,
          'has_more': false,
          'next_cursor': null,
          'rule_version': 'hl-rule-v0',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final list = await repo(client).list(since: since, limit: 20);

    expect(captured, isNotNull);
    expect(captured!.method, 'GET');
    expect(captured!.url.path, '/highlights');
    expect(captured!.url.queryParameters['since'], '2026-09-07T13:00:00.000Z');
    expect(captured!.url.queryParameters['limit'], '20');
    expect(captured!.headers['Authorization'], 'Bearer jwt');

    expect(list, hasLength(2));
    expect(list[0].clipId, 'c1');
    expect(list[0].source, 'rule');
    expect(list[0].isHumanConfirmed, isFalse);
    expect(list[0].reason, '움직임 12.4초 · 최장 연속 6.1초');
    expect(list[0].ruleVersion, 'hl-rule-v0');
    expect(list[0].decidedAt, isNull);
    expect(list[1].source, 'human');
    expect(list[1].isHumanConfirmed, isTrue);
    expect(list[1].decidedAt?.toUtc(), DateTime.utc(2026, 9, 8, 1));
  });

  test('limit은 1..maxLimit로 클램프, 토큰 없으면 Authorization 생략', () async {
    final limits = <String?>[];
    final auths = <String?>[];
    final client = MockClient((req) async {
      limits.add(req.url.queryParameters['limit']);
      auths.add(req.headers['Authorization']);
      return http.Response('{"highlights": []}', 200);
    });
    final r = repo(client, token: null);
    await r.list(since: since, limit: 500);
    await r.list(since: since, limit: 0);
    expect(limits, ['${HighlightRepository.maxLimit}', '1']);
    expect(auths, [null, null]);
  });

  test('404 → 빈 목록, 그 외 오류 → BackendException', () async {
    final notFound = MockClient((_) async => http.Response('nope', 404));
    expect(await repo(notFound).list(since: since), isEmpty);

    final boom = MockClient((_) async => http.Response('down', 503));
    await expectLater(
      repo(boom).list(since: since),
      throwsA(isA<BackendException>()
          .having((e) => e.statusCode, 'statusCode', 503)),
    );
  });

  group('listFeatured (GET /highlights/featured, 계약 2026-09-11)', () {
    test('경로·쿼리(days/tier, top_n 없음)·Bearer + tier/day_key/episode 파싱',
        () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'highlights': [
              {
                'clip_id': 'c1',
                'camera_id': 'cam1',
                'camera_name': '거실',
                'started_at': '2026-09-08T21:00:00Z',
                'duration_sec': 30,
                'media_ready': true,
                'source': 'human',
                'reason': '움직임 84.0초',
                'rule_version': 'hl-rule-v0',
                'tier': 'featured',
                'day_key': '2026-09-08',
                'activity_sec': 84.0,
                'behavior_flagged': false,
                'episode': {
                  'rank': 1,
                  'hour_rank': 2,
                  'clip_count': 6,
                  'activity_sec': 84.0,
                  'started_at': '2026-09-08T20:58:00Z',
                  'ended_at': '2026-09-08T21:10:00Z',
                },
              },
            ],
            'count': 1,
            'rule_version': 'hl-rule-v0',
            'featured': {
              'top_n': null, // 기준 개정(2026-09-11 후속) — 하루 상한 없음
              'gap_sec': 600,
              'day_start_hour': 20,
              'time_zone': 'Asia/Seoul',
              'days': 7,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final list = await repo(client).listFeatured(days: 7, tier: 'featured');

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/highlights/featured');
      expect(captured!.url.queryParameters['days'], '7');
      expect(captured!.url.queryParameters['tier'], 'featured');
      // top_n을 보내면 서버가 구 방식의 하루 상한을 다시 건다 — 절대 금지.
      expect(captured!.url.queryParameters.containsKey('top_n'), isFalse);
      expect(captured!.headers['Authorization'], 'Bearer jwt');

      expect(list, hasLength(1));
      expect(list.single.isFeatured, isTrue);
      expect(list.single.dayKey, '2026-09-08');
      expect(list.single.episodeRank, 1);
      expect(list.single.episodeHourRank, 2);
      expect(list.single.episodeClipCount, 6);
      expect(list.single.isHumanConfirmed, isTrue);
      expect(list.single.decidedAt, isNull); // 이 응답에는 decided_at이 없다
    });

    test('days는 1..maxFeaturedDays로 클램프 (서버 le=31 → 422 예방)', () async {
      final days = <String?>[];
      final client = MockClient((req) async {
        days.add(req.url.queryParameters['days']);
        return http.Response('{"highlights": []}', 200);
      });
      final r = repo(client);
      await r.listFeatured(days: 32);
      await r.listFeatured(days: 0);
      expect(days, ['${HighlightRepository.maxFeaturedDays}', '1']);
    });

    test('404 → 빈 목록, 500 → BackendException', () async {
      final notFound = MockClient((_) async => http.Response('nope', 404));
      expect(await repo(notFound).listFeatured(), isEmpty);

      final boom = MockClient((_) async => http.Response('down', 500));
      await expectLater(
        repo(boom).listFeatured(),
        throwsA(isA<BackendException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
