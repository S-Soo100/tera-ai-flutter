// v4 실시간 이탈 행(계획 Task 6, alerts env_*).
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/env_alert.dart';

Map<String, dynamic> _row({
  String id = 'a1',
  String kind = 'env_temp_high',
  String level = 'caution',
  String message = '[고온 주의] 적정 온도보다 +0.3℃',
  String triggeredAt = '2026-11-02T05:00:00+00:00',
  String? resolvedAt,
  Object? context,
}) =>
    {
      'id': id,
      'device_id': 'd1',
      'kind': kind,
      'severity': 'warning',
      'message': message,
      'context': context ?? {'rule': 'v4', 'level': level},
      'triggered_at': triggeredAt,
      'resolved_at': resolvedAt,
    };

void main() {
  final row = _row();

  test('env_* 아닌 kind는 제외', () {
    expect(EnvAlert.fromRow({...row, 'kind': 'temp_high'}), isNull);
    expect(EnvAlert.fromRow({...row, 'kind': 'heater_latched'}), isNull);
    expect(EnvAlert.fromRow({...row, 'kind': 'env_mist_needed'}), isNull);
  });

  test('rule v4 아니면 제외', () {
    expect(
        EnvAlert.fromRow({
          ...row,
          'context': {'rule': 'legacy', 'level': 'caution'}
        }),
        isNull);
    expect(EnvAlert.fromRow({...row, 'context': null}), isNull);
  });

  test('모르는 등급·시각 없는 행은 제외', () {
    expect(EnvAlert.fromRow(_row(level: 'info')), isNull);
    expect(EnvAlert.fromRow({...row, 'triggered_at': null}), isNull);
  });

  test('message 분리 — 칩·제목, 숫자는 그대로', () {
    final a = EnvAlert.fromRow(row)!;
    expect(a.chip, '고온 주의');
    expect(a.title, '적정 온도보다 +0.3℃');
    expect(a.metric, EnvAlertMetric.temp);
    expect(a.level, EnvAlertLevel.caution);
    expect(a.isOpen, isTrue);
    expect(a.triggeredAt.isUtc, isFalse); // 로컬로 바꿔 둔다.

    final humid = EnvAlert.fromRow(
        _row(kind: 'env_humid_low', message: '[건조 주의] 적정 습도보다 -6%p'))!;
    expect(humid.title, '적정 습도보다 -6%p'); // %p → % 바꾸지 않는다(D4).
    expect(humid.metric, EnvAlertMetric.humid);
  });

  test('[ ] 형식이 아니면 칩 없음, 제목은 message 전체', () {
    final a = EnvAlert.fromRow(_row(message: '온도가 너무 낮아요'))!;
    expect(a.chip, isNull);
    expect(a.title, '온도가 너무 낮아요');
  });

  test('context가 JSON 문자열로 와도 읽는다', () {
    final a =
        EnvAlert.fromRow(_row(context: '{"rule":"v4","level":"danger"}'))!;
    expect(a.level, EnvAlertLevel.danger);
  });

  test('지표별 최신 1개', () {
    final old = EnvAlert.fromRow(_row(
        id: 'old',
        level: 'caution',
        triggeredAt: '2026-11-02T05:00:00+00:00'))!;
    final newer = EnvAlert.fromRow(_row(
        id: 'new',
        level: 'caution',
        message: '[고온 주의] 적정 온도보다 +1.0℃',
        triggeredAt: '2026-11-02T05:10:00+00:00'))!;
    final list = EnvAlert.openLatestPerMetric([newer, old]);
    expect(list.map((a) => a.id), ['new']);
  });

  test('주의→경고 전환이 같은 시각이면 경고를 남긴다(G8)', () {
    final caution = EnvAlert.fromRow(
        _row(id: 'c', kind: 'env_temp_low', level: 'caution'))!;
    final danger = EnvAlert.fromRow(_row(
        id: 'd',
        kind: 'env_temp_low',
        level: 'danger',
        message: '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요'))!;
    expect(EnvAlert.openLatestPerMetric([danger, caution]).single.id, 'd');
    expect(EnvAlert.openLatestPerMetric([caution, danger]).single.id, 'd');
  });

  test('종료된 행은 빠지고, 경고 먼저 · 같은 등급이면 온도 → 습도', () {
    final humidDanger = EnvAlert.fromRow(
        _row(id: 'hd', kind: 'env_humid_high', level: 'danger'))!;
    final tempCaution = EnvAlert.fromRow(
        _row(id: 'tc', kind: 'env_temp_high', level: 'caution'))!;
    expect(
        EnvAlert.openLatestPerMetric([tempCaution, humidDanger])
            .map((a) => a.id),
        ['hd', 'tc']);

    final tempC = EnvAlert.fromRow(_row(id: 't', level: 'caution'))!;
    final humidC = EnvAlert.fromRow(
        _row(id: 'h', kind: 'env_humid_low', level: 'caution'))!;
    expect(EnvAlert.openLatestPerMetric([humidC, tempC]).map((a) => a.id),
        ['t', 'h']);

    final resolved = EnvAlert.fromRow(
        _row(id: 'r', resolvedAt: '2026-11-02T06:00:00+00:00'))!;
    expect(resolved.isOpen, isFalse);
    expect(EnvAlert.openLatestPerMetric([resolved]), isEmpty);
  });

  test('설명 문구 키 — kind+level 고정 매핑(노션 v4 1-5)', () {
    String key(String kind, String level) =>
        EnvAlert.fromRow(_row(kind: kind, level: level))!.hintKey;
    expect(key('env_temp_low', 'danger'), 'env_alert_hint_temp_low_danger');
    expect(key('env_temp_low', 'caution'), 'env_alert_hint_temp_low_caution');
    expect(key('env_temp_high', 'danger'), 'env_alert_hint_temp_high');
    expect(key('env_temp_high', 'caution'), 'env_alert_hint_temp_high');
    expect(key('env_humid_low', 'caution'), 'env_alert_hint_humid_low');
    expect(key('env_humid_high', 'caution'), 'env_alert_hint_humid_high');
  });

  group('습기 사이클 — 환기 지연·분무 공백(서버 Stage O, Figma A26·A36)', () {
    test('vent_delay_parsed', () {
      final a = EnvAlert.fromRow(
          _row(kind: 'env_vent_delay', message: '[환기 지연] 분무 후 건기 미도달'))!;
      expect(a.metric, EnvAlertMetric.humid);
      expect(a.chip, '환기 지연');
      expect(a.title, '분무 후 건기 미도달');
      expect(a.isHumidCycle, isTrue);
      expect(a.hintKey, 'env_alert_hint_vent_delay');
    });

    test('mist_gap_parsed', () {
      final a = EnvAlert.fromRow(
          _row(kind: 'env_mist_gap', message: '[건조 주의] 분무 필요'))!;
      expect(a.metric, EnvAlertMetric.humid);
      expect(a.chip, '건조 주의');
      expect(a.title, '분무 필요');
      expect(a.isHumidCycle, isTrue);
      expect(a.hintKey, 'env_alert_hint_mist_gap');
      expect(
          EnvAlert.fromRow(_row(kind: 'env_humid_low'))!.isHumidCycle, isFalse);
    });

    test('missing_level_cycle_kind_is_caution', () {
      for (final ctx in [
        {'rule': 'v4'},
        {'rule': 'v4', 'level': 'warning'},
      ]) {
        final a = EnvAlert.fromRow(_row(kind: 'env_vent_delay', context: ctx))!;
        expect(a.level, EnvAlertLevel.caution, reason: '$ctx');
      }
      expect(
          EnvAlert.fromRow(_row(kind: 'env_mist_gap', level: 'danger'))!.level,
          EnvAlertLevel.danger);
    });

    test('unknown_level_legacy_kind_dropped', () {
      for (final ctx in [
        {'rule': 'v4'},
        {'rule': 'v4', 'level': 'warning'},
      ]) {
        expect(
            EnvAlert.fromRow(_row(kind: 'env_humid_low', context: ctx)), isNull,
            reason: '$ctx');
      }
    });

    test('humid_and_cycle_both_shown — 온도 → 습도 → 사이클', () {
      final cycle = EnvAlert.fromRow(_row(id: 'g', kind: 'env_mist_gap'))!;
      final humid = EnvAlert.fromRow(_row(id: 'h', kind: 'env_humid_low'))!;
      final temp = EnvAlert.fromRow(_row(id: 't'))!;
      expect(
          EnvAlert.openLatestPerMetric([cycle, humid, temp]).map((a) => a.id),
          ['t', 'h', 'g']);
    });

    test('cycle_latest_only', () {
      final vent = EnvAlert.fromRow(_row(
          id: 'v',
          kind: 'env_vent_delay',
          triggeredAt: '2026-11-02T05:00:00+00:00'))!;
      final gap = EnvAlert.fromRow(_row(
          id: 'g',
          kind: 'env_mist_gap',
          triggeredAt: '2026-11-02T06:00:00+00:00'))!;
      expect(EnvAlert.openLatestPerMetric([vent, gap]).map((a) => a.id), ['g']);
    });

    test('danger_first_across_slots', () {
      final cycle = EnvAlert.fromRow(_row(id: 'g', kind: 'env_vent_delay'))!;
      final humidDanger = EnvAlert.fromRow(
          _row(id: 'h', kind: 'env_humid_high', level: 'danger'))!;
      expect(
          EnvAlert.openLatestPerMetric([cycle, humidDanger]).map((a) => a.id),
          ['h', 'g']);
    });
  });
}
