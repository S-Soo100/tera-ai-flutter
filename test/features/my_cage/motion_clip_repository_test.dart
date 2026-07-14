import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tera_ai/features/my_cage/data/motion_clip_repository.dart';

void main() {
  final from = DateTime.utc(2026, 7, 13, 7);
  final to = DateTime.utc(2026, 7, 14, 7);

  MotionClipRepository repository(ActivityRowsLoader loader) {
    return MotionClipRepository(
      supabase: SupabaseClient('http://localhost', 'test-anon-key'),
      terraApiUrl: 'http://localhost',
      tokenProvider: () async => null,
      activityRowsLoader: loader,
    );
  }

  test('motionSeconds는 effective view를 우선 합산한다', () async {
    final tables = <String>[];
    final repo = repository(({
      required table,
      required columns,
      required cameraId,
      required from,
      required to,
    }) async {
      tables.add(table);
      return [
        {
          'started_at': '2026-07-13T07:10:00Z',
          'effective_activity_sec': 30,
          'raw_duration_sec': 30,
        },
        {
          'started_at': '2026-07-13T08:10:00Z',
          'effective_activity_sec': 0,
          'raw_duration_sec': 30,
        },
      ];
    });

    expect(await repo.motionSeconds('camera-a', from, to), 30);
    expect(tables, ['v_clip_effective_activity']);
  });

  test('view query 실패 시 motion_clips raw 합으로 fail-open한다', () async {
    final tables = <String>[];
    final repo = repository(({
      required table,
      required columns,
      required cameraId,
      required from,
      required to,
    }) async {
      tables.add(table);
      if (table == 'v_clip_effective_activity') {
        throw const PostgrestException(message: 'view unavailable');
      }
      return [
        {
          'started_at': '2026-07-13T07:10:00Z',
          'duration_sec': 30,
        },
        {
          'started_at': '2026-07-13T08:10:00Z',
          'duration_sec': 30,
        },
      ];
    });

    expect(await repo.motionSeconds('camera-a', from, to), 60);
    expect(tables, ['v_clip_effective_activity', 'motion_clips']);
  });

  test('view와 raw query가 모두 실패하면 0으로 숨기지 않고 오류를 전파한다', () async {
    final repo = repository(({
      required table,
      required columns,
      required cameraId,
      required from,
      required to,
    }) async {
      throw PostgrestException(message: '$table unavailable');
    });

    await expectLater(
      repo.motionSeconds('camera-a', from, to),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('시간대 그래프와 총합은 같은 effective 초를 사용한다', () async {
    final repo = repository(({
      required table,
      required columns,
      required cameraId,
      required from,
      required to,
    }) async {
      return [
        {
          'started_at': '2026-07-13T07:10:00Z',
          'effective_activity_sec': 30,
          'raw_duration_sec': 30,
        },
        {
          'started_at': '2026-07-13T08:10:00Z',
          'effective_activity_sec': 0,
          'raw_duration_sec': 30,
        },
        {
          'started_at': '2026-07-13T09:10:00Z',
          'effective_activity_sec': null,
          'raw_duration_sec': 20,
        },
      ];
    });

    final total = await repo.motionSeconds('camera-a', from, to);
    final hourly = await repo.motionSecondsByHour('camera-a', from, to);

    expect(total, 50);
    expect(hourly.fold<int>(0, (sum, value) => sum + value), total);
  });

  test('서로 다른 시간대의 소수 duration도 총합과 그래프 합이 일치한다', () async {
    // 서로 다른 시간대에 10.4초씩. 총합을 끝에 한 번 반올림하면 round(20.8)=21,
    // 그래프는 버킷별 반올림 10+10=20으로 어긋난다. 총합은 그래프 합과 같아야 한다.
    final repo = repository(({
      required table,
      required columns,
      required cameraId,
      required from,
      required to,
    }) async {
      return [
        {
          'started_at': '2026-07-13T07:10:00Z',
          'effective_activity_sec': 10.4,
          'raw_duration_sec': 10.4,
        },
        {
          'started_at': '2026-07-13T08:10:00Z',
          'effective_activity_sec': 10.4,
          'raw_duration_sec': 10.4,
        },
      ];
    });

    final total = await repo.motionSeconds('camera-a', from, to);
    final hourly = await repo.motionSecondsByHour('camera-a', from, to);

    expect(total, hourly.fold<int>(0, (sum, value) => sum + value));
  });
}
