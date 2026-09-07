/// 앱 열 때 팬 타이머 알림 재동기화 (2026-08-25).
///
/// 로컬 알림은 예약한 폰만 안다 — 다른 폰이 `fan_off`로 타이머를 취소해도
/// 이 폰의 "종료" 알림은 그대로 울린다(2026-08-25 실사례: 시뮬레이터 타이머를
/// 실기기에서 끔). FCM 승격 전의 완화책으로, **앱을 열 때** `commands` 이력에서
/// 타이머를 재계산해 알림을 맞춘다. 알림이 울리기 전에 앱을 열었을 때만
/// 효과가 있는 반쪽짜리임을 알고 쓴다 — 근본 해법은 FCM(보류).
///
/// 판정은 칩과 같은 소스([RunningTimer.fanTimerFrom], 같은 쿼리)를 쓴다 —
/// 화면과 알림이 타이머 유무를 다르게 말하면 안 된다.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/fan_timer_notification_service.dart';
import '../domain/running_timer.dart';

class FanTimerNotificationResync {
  FanTimerNotificationResync(this._client, this._service);

  final SupabaseClient _client;
  final FanTimerNotificationService _service;

  /// [deviceIds] 각각의 최신 팬 명령으로 타이머를 재계산해 알림을 걸거나
  /// 내린다. 기기 하나의 실패가 나머지를 막지 않는다.
  Future<void> run(Iterable<String> deviceIds) async {
    for (final deviceId in deviceIds) {
      try {
        // runningTimersProvider(칩)와 같은 쿼리 — 판정 소스를 하나로 유지.
        final rows = await _client
            .from('commands')
            .select('id, device_id, action, status, payload, issued_at')
            .eq('device_id', deviceId)
            .inFilter('action', ['fan_on', 'fan_off', 'fan_toggle'])
            .order('issued_at', ascending: false)
            .limit(10);
        final t = RunningTimer.fanTimerFrom(
          (rows as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          DateTime.now(),
        );
        await _service.resyncTimer(
          deviceId,
          endsAt: t?.endsAt,
          minutes: t?.durationMinutes,
        );
      } catch (e) {
        debugPrint('[fan-timer-notif] resync query failed for $deviceId: $e');
      }
    }
  }
}
