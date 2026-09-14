import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivnanaut/features/my_cage/data/motion_clip_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip_page.dart';

void main() {
  test('동일 촬영시각 241개를 복합 커서로 누락 없이 순회한다', () async {
    final stamp = DateTime.utc(2026, 9, 12, 3);
    final rows = List.generate(241, (i) => {
      'id': '00000000-0000-0000-0000-${(241-i).toString().padLeft(12, '0')}',
      'camera_id': 'camera-a', 'started_at': stamp.toIso8601String(), 'duration_sec': 8,
    });
    final requests = <Uri>[];
    final client = SupabaseClient('https://example.test', 'anon', httpClient: MockClient((request) async {
      if (!request.url.path.endsWith('motion_clips')) return http.Response('[]', 200, request: request);
      final params = request.url.queryParameters;
      requests.add(request.url);
      expect(params['owner_id'], 'eq.owner-a');
      expect(params['camera_id'], 'eq.camera-a');
      expect(params['order'], 'started_at.desc.nullslast,id.desc.nullslast');
      expect(params['limit'], '61');
      final cursor = params['or'];
      var start = 0;
      if (cursor != null) {
        expect(cursor, contains('started_at.lt.${stamp.toIso8601String()}'));
        expect(cursor, contains('started_at.eq.${stamp.toIso8601String()}'));
        final id = RegExp(r'id\.lt\.([^,)]+)').firstMatch(cursor)!.group(1);
        start = rows.indexWhere((row) => row['id'] == id) + 1;
      }
      return http.Response(jsonEncode(rows.skip(start).take(61).toList()), 200,
        request: request, headers: {'content-type': 'application/json'});
    }));
    final repo = MotionClipRepository(supabase: client, terraApiUrl: 'https://example.test', tokenProvider: () async => null);
    MotionClipCursor? cursor;
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      final page = await repo.listPage((ownerId:'owner-a', cameraId:'camera-a', range:null), before: cursor);
      ids.addAll(page.items.map((clip) => clip.id));
      cursor = page.nextCursor;
      expect(page.hasMore, i < 4);
    }
    expect(ids, rows.map((row) => row['id']).toList());
    expect(ids.toSet().length, 241);
    expect(requests.length, 5);
  });

  test('명시 범위만 UTC의 시작 포함 다음 자정 제외 조건을 붙인다', () async {
    final start = DateTime.utc(2026,9,12);
    final end = DateTime.utc(2026,9,13);
    final client = SupabaseClient('https://example.test', 'anon', httpClient: MockClient((request) async {
      final dateFilters = request.url.queryParametersAll['started_at'];
      expect(dateFilters, containsAll(['gte.${start.toIso8601String()}', 'lt.${end.toIso8601String()}']));
      expect(request.url.queryParameters['or'], isNull);
      return http.Response('[]', 200, request: request, headers: {'content-type':'application/json'});
    }));
    final repo = MotionClipRepository(supabase:client, terraApiUrl:'https://example.test', tokenProvider:() async => null);
    final page = await repo.listPage((ownerId:'a', cameraId:'c', range:(start:start,endExclusive:end)));
    expect(page.items, isEmpty);
    expect(page.hasMore, false);
    expect(page.nextCursor, isNull);
  });
}
