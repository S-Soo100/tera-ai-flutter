import '../../../core/network/terra_rest_client.dart';
import '../domain/schedule.dart';

/// 예약 CRUD 실패. REST 공통부로 추출되며 [TerraRestException]으로 통합됐다 —
/// 사용처(`routine_settings_screen.dart` 등)와 테스트가 안 깨지게 이름을 남긴다.
typedef ScheduleException = TerraRestException;

/// terra-api `schedules` 접근.
///
/// **REST 전용이다.** 테이블에 RLS가 있어 Supabase 직결 INSERT도 통과하지만,
/// `next_run_at`을 서버가 계산하므로 직접 넣으면 예약이 영영 안 돈다
/// (`APP_TIMER_MIST.md` §2). 조회만이라면 직결도 가능하지만, 생성 직후 목록이
/// 서버 계산값과 어긋나지 않도록 읽기도 같은 통로로 맞춘다.
class ScheduleRepository {
  final TerraRestClient _client;

  ScheduleRepository(this._client);

  Future<List<Schedule>> list(String deviceId) async {
    final decoded = await _client.get('/devices/$deviceId/schedules');
    if (decoded is! List) return const [];
    return decoded
        .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Schedule> create(
    String deviceId, {
    required ScheduleAction action,
    required ScheduleKind kind,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    Map<String, dynamic>? payload,
    ScheduleGuard? guard,
  }) async {
    final body = Schedule.createBody(
      action: action,
      kind: kind,
      hour: hour,
      minute: minute,
      daysOfWeek: daysOfWeek,
      payload: payload,
      guard: guard,
    );
    final decoded = await _client.post('/devices/$deviceId/schedules', body);
    return Schedule.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  /// 부분 수정. `action`은 서버가 안 받는다(payload만 바꿀 수 있다).
  Future<Schedule> patch(
    String scheduleId,
    Map<String, dynamic> changes,
  ) async {
    final decoded = await _client.patch('/schedules/$scheduleId', changes);
    return Schedule.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<void> delete(String scheduleId) =>
      _client.delete('/schedules/$scheduleId');
}
