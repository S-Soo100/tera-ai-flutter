import 'package:hive/hive.dart';

import '../domain/lcd_screen_state.dart';

/// 기기별로 이 폰이 기억하는 화면 꺼짐 예약 시간(2026-11-03, 기획 D2·§11-3).
///
/// 서버는 예약 해제(`DELETE …/lcd/quiet`) 때 시간을 NULL로 지운다 — 그런데
/// Figma는 예약 스위치를 꺼도 시간 줄을 그대로 보이고, 다시 켜면 마지막 시간으로
/// 돌아가야 한다. 그래서 끌 때 직전 시간을, 예약이 꺼진 채 시간을 고르면 그
/// 시간을 여기 둔다. 다른 폰에선 기본값(20:00~08:00)으로 보이는 한계가 있다.
///
/// 시간의 진실 순서: 서버 값 → 이 기억값 → [LcdQuietWindow.defaults].
abstract class LcdQuietStore {
  /// 기억한 시간. 없거나 못 읽으면 null.
  LcdQuietWindow? load(String account, String deviceId);
  Future<void> save(String account, String deviceId, LcdQuietWindow window);

  /// 로그아웃 때 모든 계정의 값을 지운다(CLAUDE.md 3층 계정 격리 ③).
  Future<void> clearAll();
}

/// Hive `app_settings` 박스의 `lcd_quiet_<계정>_<기기 행 id>` 키,
/// 값은 `HH:MM-HH:MM`(KST). 박스는 `main.dart`가 연다 — 안 열려 있으면 모른다고
/// 답하고 저장은 건너뛴다.
///
/// ⚠️ 키 접두사가 `HiveLcdTextStore`의 `device_lcd_`로 시작한다 — 그쪽
/// `clearAll`도 이 값을 지운다(둘 다 로그아웃 정리라 결과는 같다).
class HiveLcdQuietStore implements LcdQuietStore {
  const HiveLcdQuietStore();

  static const boxName = 'app_settings';
  static const _prefix = 'lcd_quiet_';

  static String keyFor(String account, String deviceId) =>
      '$_prefix${account}_$deviceId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  static String encode(LcdQuietWindow w) {
    final api = w.toApi();
    return '${api['start']}-${api['end']}';
  }

  static LcdQuietWindow? decode(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    final w = LcdQuietWindow.parse(parts[0], parts[1]);
    return w != null && w.isValid ? w : null;
  }

  @override
  LcdQuietWindow? load(String account, String deviceId) =>
      decode(_box?.get(keyFor(account, deviceId)));

  @override
  Future<void> save(
      String account, String deviceId, LcdQuietWindow window) async {
    if (!window.isValid) return;
    await _box?.put(keyFor(account, deviceId), encode(window));
  }

  @override
  Future<void> clearAll() async {
    final box = _box;
    if (box == null) return;
    await box.deleteAll(
        box.keys.where((k) => k is String && k.startsWith(_prefix)).toList());
  }
}
