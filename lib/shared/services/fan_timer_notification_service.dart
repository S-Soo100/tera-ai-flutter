/// 팬 타이머 완료 로컬 알림 (2026-08-24 A안).
///
/// 자동 OFF는 펌웨어가 수행하고 서버에 "타이머 끝" 이벤트가 없으므로, 명령을
/// 보낸 이 폰이 만료 시각에 맞춰 OS 로컬 알림을 예약한다. FCM 서버 푸시는
/// 보류 — 도입되면 이 서비스를 서버발로 승격하면 된다. 판단 로직(어떤 명령이
/// 예약/취소인가)은 순수 함수 [FanTimerNotificationPlan]에 있고 여기는 플러그인
/// 배선만 맡는다. 초기화·권한은 [LocalNotifications] 공용 코어 경유.
///
/// **알림 실패가 팬 제어를 막으면 안 된다** — 권한 거부·플러그인 오류는 전부
/// 삼키고 debugPrint만 남긴다. 알림은 부가 기능이고 명령은 이미 나갔다.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/fan_timer_notification_plan.dart';
import 'local_notifications.dart';

final fanTimerNotificationServiceProvider =
    Provider<FanTimerNotificationService>(
        (ref) => FanTimerNotificationService());

class FanTimerNotificationService {
  FanTimerNotificationService([LocalNotifications? core])
      : _core = core ?? LocalNotifications.instance;

  final LocalNotifications _core;

  /// 팬 명령 전송 **성공 후** 호출한다. 실패한 명령에 알림을 걸면 기기는 안
  /// 도는데 "꺼졌어요" 알림만 온다.
  Future<void> onFanCommandSent(
    String deviceId,
    String action,
    int? durationMs,
  ) async {
    final plan = FanTimerNotificationPlan.of(action, durationMs);
    if (plan == null) return;
    try {
      await _core.ensureInitialized();
      switch (plan) {
        case ScheduleFanDone p:
          await _schedule(deviceId, p);
        case CancelFanDone():
          await _core.plugin.cancel(id: notificationIdFor(deviceId));
      }
    } catch (e, st) {
      debugPrint('[fan-timer-notif] $action failed: $e\n$st');
    }
  }

  /// 서버 `commands` 이력에서 재계산한 타이머 상태로 알림을 맞춘다 (앱 열 때
  /// 재동기화, 2026-08-25). 다른 폰이 타이머를 취소·대체했으면 알림을 내리고,
  /// 다른 폰이 **시작**한 타이머면 이 폰에도 알림을 건다.
  ///
  /// 명령 발행 경로와 달리 **권한을 요청하지 않는다** — 앱을 열자마자 맥락
  /// 없는 권한 팝업이 뜨면 안 된다. 권한이 없으면 OS가 표시만 막는다.
  Future<void> resyncTimer(
    String deviceId, {
    DateTime? endsAt,
    int? minutes,
  }) async {
    try {
      await _core.ensureInitialized();
      final id = notificationIdFor(deviceId);
      if (endsAt == null || !endsAt.isAfter(DateTime.now())) {
        await _core.plugin.cancel(id: id);
        return;
      }
      await _core.plugin.zonedSchedule(
        id: id,
        title: 'notif_fan_timer_done_title'.tr(),
        body: 'notif_fan_timer_done_body'.tr(args: ['${minutes ?? 0}']),
        // 여기는 상대가 아니라 **절대 시각**이다 — 타이머를 시작한 폰과 같은
        // 종료 시각(issued_at + duration_ms)에 울려야 한다.
        scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: await _core.scheduleMode(),
      );
    } catch (e, st) {
      debugPrint('[fan-timer-notif] resync failed for $deviceId: $e\n$st');
    }
  }

  Future<void> _schedule(String deviceId, ScheduleFanDone plan) async {
    await _core.requestPermission();
    await _core.plugin.zonedSchedule(
      id: notificationIdFor(deviceId),
      title: 'notif_fan_timer_done_title'.tr(),
      body: 'notif_fan_timer_done_body'.tr(args: ['${plan.minutes}']),
      // 이름 있는 시간대가 필요 없다 — 상대 시간 예약이라 tz.local이 무엇으로
      // 잡혀 있든 "지금 + duration"의 절대 시각은 같다.
      scheduledDate: tz.TZDateTime.now(tz.local).add(plan.duration),
      notificationDetails: _details(),
      androidScheduleMode: await _core.scheduleMode(),
    );
  }

  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          'fan_timer',
          'notif_channel_timer_name'.tr(),
          channelDescription: 'notif_channel_timer_desc'.tr(),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentBanner: true,
          presentSound: true,
        ),
      );
}
