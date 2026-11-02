// v4 일일·주간 분석 리포트 파싱(계획 2026-11-03 Task 1).
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/env_report.dart';

void main() {
  test('일일 행 파싱 — 서버 예시', () {
    final r = EnvDailyReport.fromRow({
      'device_id': 'd1',
      'report_date': '2026-11-02',
      'temp_card': {
        'element': 'temp',
        'code': 'TEMP_DANGER_HIGH',
        'status': 'danger',
        'title': '위험한 온도가 기록되었어요',
        'lines': [
          '14:00~14:30 적정 온도보다 최대 +1.8℃ 이탈',
          '14:30~16:20 위험 온도 29.6℃ 감지'
        ],
      },
      'humid_card': null,
    })!;
    expect(r.deviceId, 'd1');
    expect(r.reportDate, DateTime(2026, 11, 2));
    expect(r.cards.single.element, EnvReportElement.temp);
    expect(r.cards.single.status, EnvReportStatus.danger);
    expect(r.cards.single.code, 'TEMP_DANGER_HIGH');
    expect(r.cards.single.lines, hasLength(2));
  });

  test('카드 순서는 온도 → 습도', () {
    final r = EnvDailyReport.fromRow({
      'device_id': 'd1',
      'report_date': '2026-11-02',
      'humid_card': {'element': 'humid', 'title': '건조를 주의해 주세요'},
      'temp_card': {'element': 'temp', 'title': '높은 온도가 기록됐어요'},
    })!;
    expect(r.cards.map((c) => c.element),
        [EnvReportElement.temp, EnvReportElement.humid]);
  });

  test('title 없는 카드는 null', () {
    expect(
        EnvReportCard.fromJson({
          'element': 'temp',
          'lines': ['a']
        }),
        isNull);
    expect(EnvReportCard.fromJson({'element': 'temp', 'title': '  '}), isNull);
  });

  test('element 모르면 null', () {
    expect(EnvReportCard.fromJson({'element': 'co2', 'title': 't'}), isNull);
  });

  test('lines의 비문자열·공백은 버린다', () {
    expect(
        EnvReportCard.fromJson({
          'element': 'humid',
          'title': 't',
          'lines': ['a', 3, ' ', null]
        })!
            .lines,
        ['a']);
    expect(EnvReportCard.fromJson({'element': 'humid', 'title': 't'})!.lines,
        isEmpty);
  });

  test('unknown_status_keeps_card', () {
    final c = EnvReportCard.fromJson(
        {'element': 'temp', 'title': 't', 'status': 'weird', 'lines': []})!;
    expect(c.status, EnvReportStatus.unknown);
    expect(c.code, '');
  });

  test('jsonb 문자열도 받는다, 깨진 문자열은 null', () {
    expect(EnvReportCard.fromJson('{"element":"temp","title":"t","lines":[]}'),
        isNotNull);
    expect(EnvReportCard.fromJson('{not json'), isNull);
  });

  test('같은 내용이면 같다', () {
    Map<String, dynamic> j() => {
          'element': 'temp',
          'title': 't',
          'status': 'normal',
          'lines': ['a']
        };
    expect(EnvReportCard.fromJson(j()), EnvReportCard.fromJson(j()));
  });

  test('주간 notices 지표 매핑·ERR_NO_DATA는 카드 대체', () {
    final w = EnvWeeklyReport.fromRow({
      'device_id': 'd1',
      'week_start': '2026-11-02',
      'temp_card': null,
      'humid_card': {
        'element': 'humid',
        'status': 'caution',
        'title': '사육장이 건조한 날이 많았어요'
      },
      'notices': [
        {
          'code': 'ERR_NO_DATA',
          'metric': 't_a',
          'title': '주간 분석을 위한 데이터를 모으고 있어요',
          'body': '최소 3일의 데이터가 필요해요'
        },
        {'code': 'ERR_DISCONNECT', 'metric': 'h_a', 'title': '수집이 불안정했어요'},
        {'code': 'ERR_X', 'metric': 'co2', 'title': '모르는 지표'},
        {'code': 'ERR_X', 'metric': 't_a', 'title': ''},
      ],
    })!;
    expect(w.weekStart, DateTime(2026, 11, 2));
    expect(w.noticesFor(EnvReportElement.temp).single.replacesCard, isTrue);
    expect(w.noticesFor(EnvReportElement.humid).single.replacesCard, isFalse);
    expect(w.noticesFor(EnvReportElement.humid).single.body, '');
    expect(w.cardFor(EnvReportElement.temp), isNull);
    expect(w.cardFor(EnvReportElement.humid)!.status, EnvReportStatus.caution);
  });

  test('notices가 없거나 깨지면 빈 목록', () {
    expect(EnvReportNotice.listFrom(null), isEmpty);
    expect(EnvReportNotice.listFrom('nope'), isEmpty);
  });

  test('device_id·날짜 없거나 깨지면 null', () {
    expect(EnvDailyReport.fromRow({'report_date': '2026-11-02'}), isNull);
    expect(EnvDailyReport.fromRow({'device_id': 'd1', 'report_date': 'x'}),
        isNull);
    expect(EnvWeeklyReport.fromRow({'device_id': 'd1'}), isNull);
  });

  test('날짜 키 0 채움', () {
    expect(envReportDateKey(DateTime(2026, 1, 5, 13)), '2026-01-05');
  });

  test('lines가 목록이 아니면 줄 없이 카드 유지', () {
    for (final lines in [
      '한 줄',
      {'a': 1},
      null
    ]) {
      final c = EnvReportCard.fromJson(
          {'element': 'temp', 'title': 't', 'lines': lines});
      expect(c!.lines, isEmpty);
    }
  });

  test('집계 구간은 로컬 시각으로', () {
    final r = EnvDailyReport.fromRow({
      'device_id': 'd1',
      'report_date': '2026-11-02',
      'window_start': '2026-11-01T23:00:00+00:00',
      'window_end': '2026-11-02T23:00:00+00:00',
    })!;
    expect(r.windowStart, DateTime.utc(2026, 11, 1, 23).toLocal());
    expect(r.windowEnd!.isAfter(r.windowStart!), isTrue);
    expect(
        EnvDailyReport.fromRow({
          'device_id': 'd1',
          'report_date': '2026-11-02',
          'window_start': 'x'
        })!
            .windowStart,
        isNull);
  });
}
