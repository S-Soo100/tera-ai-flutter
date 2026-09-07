import 'package:hive/hive.dart';

import '../domain/fan_timer_duration.dart';

/// 환기팬 "직전 설정" 저장소 — 홈 타일 원탭이 재실행할 값(2026-09-08 UX 개편:
/// 탭=직전 설정 즉시 켜기, 꾹=방식 시트). Widget → Provider → Repository
/// 체인을 지킨다([HiveHighlightBannerStore] 선례 — 화면이 Hive를 직접 만지지
/// 않는다).
///
/// 값 의미: `null` = 계속 켜기, [FanTimerDuration] = 일회성 타이머.
/// **미저장 기본은 30분**(사용자 결정) — load가 기본값까지 책임진다.
abstract class FanChoiceStore {
  /// [deviceId] 기기의 직전 설정. 저장된 적 없으면 [FanTimerDuration.m30].
  FanTimerDuration? load(String deviceId);

  Future<void> save(String deviceId, FanTimerDuration? duration);
}

/// Hive `app_settings` 박스의 `home_fan_last_choice_<deviceId>` 키.
///
/// 박스는 `main.dart`가 앱 기동 시 연다. 안 열려 있으면(테스트 등) 기본값으로
/// 동작하고 저장은 건너뛴다 — 여기서 박스를 열지 않는다.
///
/// 저장 표현은 분(int), **0 = 계속 켜기**. 기기별 키다 — 세트마다 환기
/// 습관(베이비룸 10분, 성체장 1시간)이 다를 수 있다.
class HiveFanChoiceStore implements FanChoiceStore {
  const HiveFanChoiceStore();

  static const boxName = 'app_settings';

  static String keyFor(String deviceId) => 'home_fan_last_choice_$deviceId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  FanTimerDuration? load(String deviceId) {
    final raw = _box?.get(keyFor(deviceId));
    if (raw is! int) return FanTimerDuration.m30; // 미저장·손상 → 기본 30분
    if (raw == 0) return null; // 계속 켜기
    for (final d in FanTimerDuration.values) {
      if (d.minutes == raw) return d;
    }
    return FanTimerDuration.m30; // 옵션에서 사라진 과거 값 → 기본
  }

  @override
  Future<void> save(String deviceId, FanTimerDuration? duration) async {
    final box = _box;
    if (box == null) return;
    await box.put(keyFor(deviceId), duration?.minutes ?? 0);
  }
}
