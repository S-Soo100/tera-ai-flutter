/// flutter_local_notifications 공용 코어 — 팬 타이머·예약 알림이 나눠 쓴다.
///
/// 초기화·권한·스케줄 모드 판단을 한 곳에 둔다. 소비처를 늘릴 때 플러그인
/// 초기화를 복붙하면 iOS 권한 요청 시점이 화면마다 달라진다 — 반드시 여기를
/// 경유할 것.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifications {
  LocalNotifications._();

  static final LocalNotifications instance = LocalNotifications._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 지연 초기화 — 알림을 처음 쓸 때 한 번. 앱 기동을 안 건드리고, 알림을 한
  /// 번도 안 쓰는 사용자는 timezone DB 파싱 비용도 안 낸다.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      // 시각 반복 알림(daily 09:15 등)은 tz.local의 벽시계 성분으로 반복된다
      // — 실제 기기 시간대를 심어야 한다. 실패해도 치명적이지 않아 삼킨다:
      // 한국은 DST가 없어 UTC 기본값으로도 첫 발화 절대시각 기준의 반복이
      // 같은 벽시계 시각에 떨어진다.
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('[local-notif] timezone detect failed, using default: $e');
    }
    await plugin.initialize(
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

  /// 거부돼도 던지지 않는다 — 예약 자체는 걸어두고, OS가 표시만 막는다.
  /// 사용자가 나중에 설정에서 허용하면 그때부터 울린다.
  Future<void> requestPermission() async {
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// SCHEDULE_EXACT_ALARM은 Android 14+에서 기본 거부다. 설정 화면으로
  /// 내모는 대신 inexact로 물러선다 — 몇 분 늦은 알림이 설정 강요보다 낫다.
  Future<AndroidScheduleMode> scheduleMode() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
