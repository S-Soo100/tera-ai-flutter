/// 예약(스케줄) 실행 시각 로컬 알림 동기화 (2026-08-25).
///
/// 예약 실행 주체는 서버라 폰은 실행 순간을 모른다(FCM 보류). 대신 폰이 아는
/// 예약 목록으로 **실행 시각에 맞춘 반복 로컬 알림**을 건다 — daily는 매일
/// 반복, weekly는 요일별 반복이라 앱을 다시 열지 않아도 계속 울린다.
/// 스펙 전개는 순수 함수(`scheduleNotificationSpecs`), 여기는 플러그인 배선.
///
/// 동기화 시점은 `SchedulesNotifier`(목록 로드·모든 수정 경로). 전량
/// 지우고 다시 걸어 삭제·수정·토글이 자연히 반영된다. 우리 것만 지우도록
/// payload에 `sched:{deviceId}` 마커를 심는다 — 팬 타이머 알림(payload 없음)은
/// 건드리지 않는다.
///
/// **알림 실패가 예약 CRUD를 막으면 안 된다** — 전부 삼키고 debugPrint만.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/services/local_notifications.dart';
import '../domain/schedule.dart';
import '../domain/schedule_notification_plan.dart';

class ScheduleNotificationSync {
  ScheduleNotificationSync([LocalNotifications? core])
      : _core = core ?? LocalNotifications.instance;

  final LocalNotifications _core;

  /// [schedules]는 [deviceId] 기기의 **전체** 예약 목록이어야 한다 — 여기
  /// 없는 예약의 알림은 지워진 것으로 보고 취소한다.
  Future<void> sync(String deviceId, List<Schedule> schedules) async {
    try {
      await _core.ensureInitialized();
      final plugin = _core.plugin;
      final marker = 'sched:$deviceId';

      // 이 기기 몫 전량 취소 후 재등록. 스펙 id가 예약 id 기반이라 대부분
      // 같은 id를 덮어쓰지만, 삭제된 예약·요일 축소는 취소로만 정리된다.
      for (final p in await plugin.pendingNotificationRequests()) {
        if (p.payload == marker) await plugin.cancel(id: p.id);
      }

      final specs = scheduleNotificationSpecs(schedules);
      if (specs.isEmpty) return;
      await _core.requestPermission();

      final mode = await _core.scheduleMode();
      final now = DateTime.now();
      for (final spec in specs) {
        final first = nextOccurrence(now, spec.hour, spec.minute, spec.weekday);
        final hhmm = '${spec.hour.toString().padLeft(2, '0')}:'
            '${spec.minute.toString().padLeft(2, '0')}';
        await plugin.zonedSchedule(
          id: spec.id,
          title: 'notif_schedule_fire_title'
              .tr(args: [spec.actionDisplayKey.tr()]),
          // 가드 예약은 서버가 조건으로 건너뛸 수 있다 — 알림만 보고 "실행됐다"
          // 로 믿지 않게 문구에 밝힌다.
          body: (spec.guarded
                  ? 'notif_schedule_fire_body_guarded'
                  : 'notif_schedule_fire_body')
              .tr(args: [hhmm]),
          scheduledDate: tz.TZDateTime.from(first, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'schedule',
              'notif_channel_schedule_name'.tr(),
              channelDescription: 'notif_channel_schedule_desc'.tr(),
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentBanner: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: mode,
          payload: marker,
          matchDateTimeComponents: spec.weekday == null
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e, st) {
      debugPrint('[sched-notif] sync failed for $deviceId: $e\n$st');
    }
  }
}
