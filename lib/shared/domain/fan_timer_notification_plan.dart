/// 팬 타이머 로컬 알림의 예약/취소 판단 (순수 로직).
///
/// 팬 자동 OFF는 펌웨어가 수행하고 서버에 "타이머 끝" 이벤트가 없으므로
/// (2026-08-14 핸드오프 §1.3), 완료 알림은 **명령을 보낸 이 폰이 로컬로
/// 예약**한다(2026-08-24 A안 확정 — FCM 서버 푸시는 보류). 다른 폰이나 예약
/// 스케줄이 팬을 끄면 이 폰의 알림이 그대로 울리는 한계는 수용했다.
///
/// `actuator_marker.dart`처럼 wire 문자열(`fan_on` 등)을 받는다 — feature
/// 도메인(`CommandAction`)에 의존하지 않아 홈·사육장 탭 어느 쪽에서도 쓴다.
library;

sealed class FanTimerNotificationPlan {
  const FanTimerNotificationPlan();

  /// 명령 1건이 팬 타이머 알림에 미치는 영향.
  ///
  /// - `fan_on` + 양수 duration → 예약 ([ScheduleFanDone])
  /// - `fan_on` duration 없음(계속 켜기) → **취소** — duration 없는 fan_on은
  ///   진행 중 타이머를 대체(소멸)시킨다. `handleFanTap`의 invalidate와 같은 이유.
  /// - `fan_off` → 취소 (타이머 취소도 fan_off다)
  /// - 그 외(팬 무관, fan_toggle 포함) → null(알림에 영향 없음)
  static FanTimerNotificationPlan? of(String action, int? durationMs) {
    switch (action) {
      case 'fan_on':
        if (durationMs != null && durationMs > 0) {
          return ScheduleFanDone(
            minutes: durationMs ~/ 60000,
            duration: Duration(milliseconds: durationMs),
          );
        }
        return const CancelFanDone();
      case 'fan_off':
        return const CancelFanDone();
      default:
        return null;
    }
  }
}

class ScheduleFanDone extends FanTimerNotificationPlan {
  const ScheduleFanDone({required this.minutes, required this.duration});

  /// 알림 문구용 분 단위 (칩 문구 `팬 30분 타이머`와 같은 값).
  final int minutes;

  /// 지금부터 알림까지의 시간.
  final Duration duration;
}

class CancelFanDone extends FanTimerNotificationPlan {
  const CancelFanDone();
}

/// 기기 → 알림 id. **실행 간 안정**이어야 한다 — 예약한 세션과 취소하는
/// 세션이 다를 수 있다(앱 재시작 후 끄기). Dart `String.hashCode`는 실행 간
/// 안정을 보장하지 않아 FNV-1a 32bit를 직접 쓴다. 상위 비트를 지워 Android
/// 알림 id가 요구하는 32bit 양수로 맞춘다.
int notificationIdFor(String deviceId) {
  var hash = 0x811C9DC5;
  for (final byte in deviceId.codeUnits) {
    // codeUnit은 UTF-16이라 0xFFFF까지 온다 — 바이트 둘로 쪼개 섞는다.
    hash ^= byte & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
    hash ^= byte >> 8;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
