/// 팬 타이머 완료 로컬 알림 (2026-08-24 A안).
///
/// 자동 OFF는 펌웨어가 수행하고 서버에 "타이머 끝" 이벤트가 없으므로, 명령을
/// 보낸 이 폰이 만료 시각에 맞춰 OS 로컬 알림을 예약한다. FCM 서버 푸시는
/// 보류 — 도입되면 이 서비스를 서버발로 승격하면 된다. 판단 로직(어떤 명령이
/// 예약/취소인가)은 순수 함수 [FanTimerNotificationPlan]에 있고 여기는 플러그인
/// 배선만 맡는다.
///
/// **알림 실패가 팬 제어를 막으면 안 된다** — 권한 거부·플러그인 오류는 전부
/// 삼키고 debugPrint만 남긴다. 알림은 부가 기능이고 명령은 이미 나갔다.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/fan_timer_notification_plan.dart';

final fanTimerNotificationServiceProvider =
    Provider<FanTimerNotificationService>(
        (ref) => FanTimerNotificationService());

class FanTimerNotificationService {
  FanTimerNotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

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
      await _ensureInitialized();
      switch (plan) {
        case ScheduleFanDone p:
          await _schedule(deviceId, p);
        case CancelFanDone():
          await _plugin.cancel(id: notificationIdFor(deviceId));
      }
    } catch (e, st) {
      debugPrint('[fan-timer-notif] $action failed: $e\n$st');
    }
  }

  /// 지연 초기화 — 알림을 처음 쓸 때 한 번. 앱 기동을 안 건드리고, 타이머를 한
  /// 번도 안 쓰는 사용자는 timezone DB 파싱 비용도 안 낸다.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // 권한은 기동 시가 아니라 첫 예약 직전에 요청한다 — 맥락 없는 권한
        // 팝업은 거부율만 높인다.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<void> _schedule(String deviceId, ScheduleFanDone plan) async {
    await _requestPermission();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // SCHEDULE_EXACT_ALARM은 Android 14+에서 기본 거부다. 설정 화면으로
    // 내모는 대신 inexact로 물러선다 — 몇 분 늦은 "팬 꺼짐" 알림이 설정 강요보다
    // 낫다.
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: notificationIdFor(deviceId),
      title: 'notif_fan_timer_done_title'.tr(),
      body: 'notif_fan_timer_done_body'.tr(args: ['${plan.minutes}']),
      // 이름 있는 시간대가 필요 없다 — 상대 시간 예약이라 tz.local이 무엇으로
      // 잡혀 있든 "지금 + duration"의 절대 시각은 같다.
      scheduledDate: tz.TZDateTime.now(tz.local).add(plan.duration),
      notificationDetails: NotificationDetails(
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
      ),
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _requestPermission() async {
    // 거부돼도 던지지 않는다 — 예약 자체는 걸어두고, OS가 표시만 막는다.
    // 사용자가 나중에 설정에서 허용하면 그때부터 울린다.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }
}
