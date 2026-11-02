import 'dart:convert';

import 'package:flutter/foundation.dart';

/// v4 일일·주간 온습도 분석 리포트(서버 `env_daily_reports`·`env_weekly_reports`).
///
/// 문구(`title`·`lines`·안내 `title`/`body`)는 서버가 기획 원문대로 완성해
/// 저장한다 — 앱은 **그대로 그린다**(조합·문장부호 추가 금지). 집계 구간은 서버
/// 기준 08:00~다음 08:00 KST라 앱이 다시 계산하지 않는다. 카드 `status`는
/// `alerts.severity`와 어휘가 다르다(`danger`/`caution`/`normal`).
///
/// 파싱은 관대하다: 깨진 카드·안내는 그 항목만 빠지고 나머지는 산다.

enum EnvReportElement { temp, humid }

/// 카드 상태. 모르는 값은 [unknown] — 주간 칩을 생략하고 카드는 그린다.
enum EnvReportStatus { danger, caution, normal, unknown }

EnvReportElement? _element(Object? v) => switch (v) {
      'temp' => EnvReportElement.temp,
      'humid' => EnvReportElement.humid,
      _ => null,
    };

EnvReportStatus _status(Object? v) => switch (v) {
      'danger' => EnvReportStatus.danger,
      'caution' => EnvReportStatus.caution,
      'normal' => EnvReportStatus.normal,
      _ => EnvReportStatus.unknown,
    };

/// jsonb는 보통 Map/List로 오지만 문자열 JSON으로 와도 받는다.
Object? _decoded(Object? json) {
  if (json is! String) return json;
  try {
    return jsonDecode(json);
  } catch (_) {
    return null;
  }
}

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : v;
}

/// `date` 열(`YYYY-MM-DD`) → 로컬 자정.
DateTime? _date(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// timestamptz → 로컬 시각. 없거나 깨지면 null.
DateTime? _instant(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// 로컬 달력 날짜 → `date` 열 조회 키 `YYYY-MM-DD`.
String envReportDateKey(DateTime localDate) =>
    '${localDate.year.toString().padLeft(4, '0')}-'
    '${localDate.month.toString().padLeft(2, '0')}-'
    '${localDate.day.toString().padLeft(2, '0')}';

/// 카드 한 장(`temp_card`·`humid_card`). 일일·주간 같은 형식이다.
@immutable
class EnvReportCard {
  const EnvReportCard({
    required this.element,
    required this.code,
    required this.status,
    required this.title,
    required this.lines,
  });

  final EnvReportElement element;

  /// 카드 종류(`TEMP_DANGER_HIGH` 등). 없으면 ''.
  final String code;
  final EnvReportStatus status;
  final String title;

  /// 세부 설명 — 이벤트 카드는 이벤트 1건 = 1줄, 시작 시각순(서버 순서 그대로).
  final List<String> lines;

  /// `element`를 모르거나 `title`이 비면 null.
  static EnvReportCard? fromJson(Object? json) {
    final j = _decoded(json);
    if (j is! Map) return null;
    final element = _element(j['element']);
    final title = _text(j['title']);
    if (element == null || title == null) return null;
    final rawLines = j['lines'];
    return EnvReportCard(
      element: element,
      code: j['code'] is String ? j['code'] as String : '',
      status: _status(j['status']),
      title: title,
      lines: [
        if (rawLines is List)
          for (final l in rawLines)
            if (_text(l) case final String s) s,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EnvReportCard &&
      other.element == element &&
      other.code == code &&
      other.status == status &&
      other.title == title &&
      listEquals(other.lines, lines);

  @override
  int get hashCode =>
      Object.hash(element, code, status, title, Object.hashAll(lines));
}

/// 주간 예외 안내(`notices` 항목).
@immutable
class EnvReportNotice {
  const EnvReportNotice({
    required this.code,
    required this.element,
    required this.title,
    required this.body,
  });

  /// `ERR_NO_DATA`(유효 수집일 3일 미만 — 카드 없음) / `ERR_DISCONNECT`(누락률
  /// 50% 이상 — 카드와 함께).
  final String code;

  /// `metric` `t_a` → 온도, `h_a` → 습도, 그 외 null(어느 카드에도 붙지 않는다).
  final EnvReportElement? element;
  final String title;
  final String body;

  /// 카드 자리를 대신하는 안내인가.
  bool get replacesCard => code == 'ERR_NO_DATA';

  static List<EnvReportNotice> listFrom(Object? json) {
    final j = _decoded(json);
    if (j is! List) return const [];
    return [
      for (final n in j)
        if (n is Map)
          if (_text(n['title']) case final String title)
            EnvReportNotice(
              code: n['code'] is String ? n['code'] as String : '',
              element: switch (n['metric']) {
                't_a' => EnvReportElement.temp,
                'h_a' => EnvReportElement.humid,
                _ => null,
              },
              title: title,
              body: _text(n['body']) ?? '',
            ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is EnvReportNotice &&
      other.code == code &&
      other.element == element &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(code, element, title, body);
}

/// 일일 리포트 — 기기 × [reportDate](집계 시작일, 그날 08:00 ~ 다음 날 08:00).
@immutable
class EnvDailyReport {
  const EnvDailyReport({
    required this.deviceId,
    required this.reportDate,
    this.windowStart,
    this.windowEnd,
    this.tempCard,
    this.humidCard,
  });

  final String deviceId;
  final DateTime reportDate;

  /// 서버 집계 구간(로컬 시각). 화면 캡션용 — 앱이 다시 계산하지 않는다.
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final EnvReportCard? tempCard;
  final EnvReportCard? humidCard;

  /// 그릴 카드 — 온도 → 습도, null 제외.
  List<EnvReportCard> get cards => [
        if (tempCard != null) tempCard!,
        if (humidCard != null) humidCard!,
      ];

  @override
  bool operator ==(Object other) =>
      other is EnvDailyReport &&
      other.deviceId == deviceId &&
      other.reportDate == reportDate &&
      other.windowStart == windowStart &&
      other.windowEnd == windowEnd &&
      other.tempCard == tempCard &&
      other.humidCard == humidCard;

  @override
  int get hashCode => Object.hash(
      deviceId, reportDate, windowStart, windowEnd, tempCard, humidCard);

  static EnvDailyReport? fromRow(Map<String, dynamic> row) {
    final device = row['device_id'];
    final date = _date(row['report_date']);
    if (device == null || date == null) return null;
    return EnvDailyReport(
      deviceId: device.toString(),
      reportDate: date,
      windowStart: _instant(row['window_start']),
      windowEnd: _instant(row['window_end']),
      tempCard: EnvReportCard.fromJson(row['temp_card']),
      humidCard: EnvReportCard.fromJson(row['humid_card']),
    );
  }
}

/// 주간 리포트 — 기기 × [weekStart](월요일, 월 08:00 ~ 다음 월 08:00).
@immutable
class EnvWeeklyReport {
  const EnvWeeklyReport({
    required this.deviceId,
    required this.weekStart,
    this.windowStart,
    this.windowEnd,
    this.tempCard,
    this.humidCard,
    this.notices = const [],
  });

  final String deviceId;
  final DateTime weekStart;

  /// 서버 집계 구간(로컬 시각). 화면 캡션용 — 앱이 다시 계산하지 않는다.
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final EnvReportCard? tempCard;
  final EnvReportCard? humidCard;
  final List<EnvReportNotice> notices;

  EnvReportCard? cardFor(EnvReportElement e) => switch (e) {
        EnvReportElement.temp => tempCard,
        EnvReportElement.humid => humidCard,
      };

  List<EnvReportNotice> noticesFor(EnvReportElement e) => [
        for (final n in notices)
          if (n.element == e) n
      ];

  @override
  bool operator ==(Object other) =>
      other is EnvWeeklyReport &&
      other.deviceId == deviceId &&
      other.weekStart == weekStart &&
      other.windowStart == windowStart &&
      other.windowEnd == windowEnd &&
      other.tempCard == tempCard &&
      other.humidCard == humidCard &&
      listEquals(other.notices, notices);

  @override
  int get hashCode => Object.hash(deviceId, weekStart, windowStart, windowEnd,
      tempCard, humidCard, Object.hashAll(notices));

  static EnvWeeklyReport? fromRow(Map<String, dynamic> row) {
    final device = row['device_id'];
    final week = _date(row['week_start']);
    if (device == null || week == null) return null;
    return EnvWeeklyReport(
      deviceId: device.toString(),
      weekStart: week,
      windowStart: _instant(row['window_start']),
      windowEnd: _instant(row['window_end']),
      tempCard: EnvReportCard.fromJson(row['temp_card']),
      humidCard: EnvReportCard.fromJson(row['humid_card']),
      notices: EnvReportNotice.listFrom(row['notices']),
    );
  }
}
