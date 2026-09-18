import 'schedule.dart';

/// 예약 편집기가 다루는 시간 입력 종류 — Figma 1106:7234(환기팬·LED 시작/종료),
/// 1107:9131(냉각팬 시작 + 30분/1시간/2시간 뒤 종료), 1107:9236(분무 시작만).
enum ScheduleEditorKind { span, duration, point }

/// 예약 화면의 기기 축(Figma 1106:4955 4타일). 동작([ScheduleAction])을 기기로
/// 묶어 목록 아이콘·편집기 종류·켜기/끄기 짝을 정한다.
///
/// [heater]는 새로 고를 수 없다(홈 타일 숨김 2026-09-04) — 이미 있는 히터 예약을
/// 목록에 그리고 시각을 고칠 때만 쓴다. unknown 동작은 기기가 없으니 [of]가
/// null을 돌려주고, 화면은 회색 원과 기존 동작 라벨로 그린다.
enum ScheduleDevice {
  fan(ScheduleAction.fanOn, ScheduleAction.fanOff, 'device_vent_fan',
      ScheduleEditorKind.span),
  mist(ScheduleAction.mist, null, 'device_mist', ScheduleEditorKind.point),
  cool(ScheduleAction.fan2On, ScheduleAction.fan2Off, 'device_cool_fan',
      ScheduleEditorKind.duration),
  led(ScheduleAction.ledOn, ScheduleAction.ledOff, 'device_led',
      ScheduleEditorKind.span),
  heater(ScheduleAction.heaterOn, ScheduleAction.heaterOff, 'device_heat_fan',
      ScheduleEditorKind.span);

  const ScheduleDevice(this.onAction, this.offAction, this.nameKey, this.kind);

  /// 켜기(또는 유일한) 동작.
  final ScheduleAction onAction;

  /// 끄기 동작. 분무는 정량이라 없다.
  final ScheduleAction? offAction;

  /// 기기 이름 i18n 키(홈 제어 타일과 같은 키).
  final String nameKey;

  /// 새 예약을 만들 때 편집기 종류.
  final ScheduleEditorKind kind;

  /// 기기 선택 화면에 나오는 4종(Figma 1106:4955 순서).
  static const pickable = [fan, mist, cool, led];

  /// 동작 → 기기. 레거시 `*_toggle`·`relay_*`도 같은 부품의 기기로 묶는다
  /// (과거 `relay_toggle`은 분무로 해석 — CLAUDE.md 분무 항목). unknown만 null.
  static ScheduleDevice? of(ScheduleAction action) {
    for (final d in values) {
      if (d.onAction == action || d.offAction == action) return d;
    }
    return switch (action) {
      ScheduleAction.fanToggle => fan,
      ScheduleAction.heaterToggle => heater,
      ScheduleAction.relayToggle ||
      ScheduleAction.relayOn ||
      ScheduleAction.relayOff =>
        mist,
      _ => null,
    };
  }

  /// 냉각팬 종료 선택지(분) — Figma 1107:9131 "30분 뒤 / 1시간 뒤 / 2시간 뒤".
  static const coolDurations = [30, 60, 120];
}
