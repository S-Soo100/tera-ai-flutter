/// flutter_local_notifications 공용 코어 — 팬 타이머·예약 알림이 나눠 쓴다.
///
/// 초기화·권한·스케줄 모드 판단을 한 곳에 둔다. 소비처를 늘릴 때 플러그인
/// 초기화를 복붙하면 iOS 권한 요청 시점이 화면마다 달라진다 — 반드시 여기를
/// 경유할 것.
library;

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifications {
  LocalNotifications._();

  static final LocalNotifications instance = LocalNotifications._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;
  bool _initialTapDelivered = false;
  void Function(String payload)? onTap;

  /// 이 폰에 걸어 둔 로컬 알림(예약 시각·팬 타이머)을 모두 내린다. 로그아웃
  /// 뒤에도 이전 계정 기기의 예약 알림이 매일 울렸다(2026-09-25 점검).
  Future<void> cancelAll() async {
    await ensureInitialized();
    await plugin.cancelAll();
  }

  /// 지연 초기화 — 알림을 처음 쓸 때 한 번. 앱 기동을 안 건드리고, 알림을 한
  /// 번도 안 쓰는 사용자는 timezone DB 파싱 비용도 안 낸다.
  Future<void> ensureInitialized() {
    if (_initialized) return Future.value();
    return _initializing ??=
        _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
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
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap?.call(payload);
      },
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      'vivanaut_default',
      'push_channel_default_name'.tr(),
      description: 'push_channel_default_description'.tr(),
      importance: Importance.defaultImportance,
    ));
    await android?.createNotificationChannel(AndroidNotificationChannel(
      'vivanaut_safety',
      'push_channel_safety_name'.tr(),
      description: 'push_channel_safety_description'.tr(),
      importance: Importance.high,
    ));
    _initialized = true;
  }

  Future<void> deliverInitialTap() async {
    if (_initialTapDelivered || onTap == null) return;
    await ensureInitialized();
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (_initialTapDelivered) return;
    _initialTapDelivered = true;
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      onTap?.call(payload);
    }
  }

  Future<void> showRemote(
      {required int id,
      required String title,
      required String body,
      required bool safety,
      required String payload}) async {
    await ensureInitialized();
    await plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
        safety ? 'vivanaut_safety' : 'vivanaut_default',
        (safety ? 'push_channel_safety_name' : 'push_channel_default_name')
            .tr(),
        importance: safety ? Importance.high : Importance.defaultImportance,
        priority: safety ? Priority.high : Priority.defaultPriority,
      )),
    );
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

  /// 사육장 알림 프리팝업을 이미 거쳤으면 OS 권한 창을 다시 띄우지 않는다 —
  /// 프리팝업에서 '받지 않기'를 고른 뒤에도 예약 화면·팬 타이머가 OS 창을
  /// 바로 띄웠다(2026-09-25 점검). 허용했다면 이미 권한이 있다. 아직 안
  /// 물은 사용자(프리팝업 전 등록)는 예전처럼 묻는다.
  Future<void> requestPermissionUnlessPrompted() async {
    final box =
        Hive.isBoxOpen('app_settings') ? Hive.box<dynamic>('app_settings') : null;
    if (box?.get('push_prompt_asked_device') == true) return;
    await requestPermission();
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
