import 'dart:convert';

/// 자동 환기·자동 분무 출시 스위치(계획 2026-11-05 Task 5).
///
/// 판정과 실행은 전부 서버가 한다. 서버가 "전체 켬"을 알리기 전에 토글을
/// 보이면, 마이그레이션 전 서버가 `auto_*_enabled`를 무시해 사용자가 켠
/// 스위치가 아무 일도 하지 않는다. 그래서 **토글 노출만** 이 값으로 막는다 —
/// 타이머 판정·제어 기록 해석은 스위치와 무관하게 늘 동작한다.
///
/// 2026-11-06 사용자 결정으로 켰다 — 서버 배포 상태는 "구현 착수·서버 스위치
/// 꺼짐"이었다(terra-server `docs/APP_AUTO_ENV_2026-11-05.md`). 서버 전체 켬
/// 전까지 토글이 동작하지 않을 수 있다.
const bool kAutoEnvReleased = true;

/// 서버 자동 환경 제어의 지금 상태 — `devices.auto_env_state`(jsonb, 계약 C3).
///
/// 앱은 `vent.active`(자동이 켠 팬이 지금 도는 중)만 읽는다. 시트의 작동 시간
/// 칩이 사용자가 고르지 않은 "계속"을 선택해 보이지 않게 하려는 용도다(D5).
/// `schedule_hold`·`paused_until`·`runtime_today_sec`·`mist.*`는 Figma에 없어
/// 담지 않는다 — 담으면 무관한 값 변화로 `==`가 달라져 하위가 다시 그려진다.
class AutoEnvState {
  const AutoEnvState({required this.ventActive});

  final bool ventActive;

  /// 기록 없음(null)·모르는 모양 — 자동이 켠 팬이 없는 것으로 본다.
  static const none = AutoEnvState(ventActive: false);

  /// `vent.active == true`일 때만 켜짐. 그 밖(키 없음·다른 타입·깨진 값)은
  /// 전부 [none] — 3초마다 오는 행을 파싱하므로 **throw하지 않는다**.
  /// 문자열 JSON도 받는다(LCD 설정 파서와 같은 Realtime 대비).
  static AutoEnvState fromJson(Object? raw) {
    final vent = _asMap(raw)?['vent'];
    if (vent is! Map) return none;
    return vent['active'] == true ? const AutoEnvState(ventActive: true) : none;
  }

  static Map<Object?, Object?>? _asMap(Object? raw) {
    if (raw is Map) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// 값 비교 — `DeviceLinkStatus`는 생존 신호 행에도 다시 만들어지므로
  /// 참조 비교면 같은 상태에도 하위가 다시 그려진다.
  @override
  bool operator ==(Object other) =>
      other is AutoEnvState && other.ventActive == ventActive;

  @override
  int get hashCode => ventActive.hashCode;

  @override
  String toString() => 'AutoEnvState(ventActive: $ventActive)';
}

/// 서버 자동 명령의 원인 — `commands.reason`(계약 C2).
///
/// 요청서의 `humid_high`/`temp_high`/`humid_low`와 문자열이 다르다. 계약 표의
/// 여덟 값만 알아보고, 모르는 값은 null로 둔다(원인 없이 시각만 보인다).
enum AutoEnvReason {
  ventHumidHigh('auto_vent:humid_high'),
  ventTempHigh('auto_vent:temp_high'),
  ventBoth('auto_vent:humid_high+temp_high'),
  ventEnd('auto_vent_end'),
  ventCold('auto_vent_cold'),
  ventCap('auto_vent_cap'),
  ventDisabled('auto_vent_disabled'),
  mist('auto_mist');

  const AutoEnvReason(this.wire);

  /// 서버가 `commands.reason`에 쓰는 문자열.
  final String wire;

  static AutoEnvReason? fromWire(Object? s) {
    if (s is! String) return null;
    for (final r in values) {
      if (r.wire == s) return r;
    }
    return null;
  }

  /// ko.json 문구 키 — `auto_reason_` + 이름의 snake_case
  /// (`ventHumidHigh` → `auto_reason_vent_humid_high`).
  String get labelKey =>
      'auto_reason_${name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')}';
}

/// 자동 토글 저장 응답이 보낸 값과 다르다 — 마이그레이션 전 서버는 모르는
/// 필드를 무시하고 200을 준다(Review Focus 1). 성공으로 보면 스위치가 아무
/// 안내 없이 꺼짐으로 돌아가므로 실패로 다룬다.
class AutoEnvSaveMismatch implements Exception {
  const AutoEnvSaveMismatch();

  @override
  String toString() => 'AutoEnvSaveMismatch';
}
