import 'dart:convert';

import '../../../shared/domain/num_format.dart';

/// v4 실시간 이탈의 지표.
enum EnvAlertMetric { temp, humid }

/// v4 실시간 이탈 등급(`alerts.context.level`).
enum EnvAlertLevel { caution, danger }

/// 서버 v4 실시간 판정 한 건(`alerts` 행, kind `env_*` + `context.rule == 'v4'`).
///
/// 판정은 **서버만** 한다 — 앱은 열린 행을 그리기만 한다. 칩·제목은 서버
/// `message`(`"[고온 주의] 적정 온도보다 +0.3℃"`)를 나눠 쓰기만 하고 숫자를
/// 다시 계산하거나 단위를 바꾸지 않는다(계획 D4 — 습도 `%p`도 그대로).
/// 펌웨어 발 `temp_high`·`heater_latched` 등은 여기서 걸러진다.
class EnvAlert {
  const EnvAlert({
    required this.id,
    required this.kind,
    required this.metric,
    required this.level,
    required this.chip,
    required this.title,
    required this.triggeredAt,
    required this.resolvedAt,
  });

  final String id;

  /// `env_temp_high` 등 서버 원문.
  final String kind;
  final EnvAlertMetric metric;
  final EnvAlertLevel level;

  /// `message`의 `[ ]` 안(예: "고온 주의"). `[ ]` 형식이 아니면 null.
  final String? chip;

  /// `]` 뒤를 trim한 것. `[ ]` 형식이 아니면 `message` 전체.
  final String title;
  final DateTime triggeredAt;

  /// 열린 행이면 null.
  final DateTime? resolvedAt;

  bool get isOpen => resolvedAt == null;

  static const Map<String, EnvAlertMetric> _metricByKind = {
    'env_temp_high': EnvAlertMetric.temp,
    'env_temp_low': EnvAlertMetric.temp,
    'env_humid_low': EnvAlertMetric.humid,
    'env_humid_high': EnvAlertMetric.humid,
  };

  static final RegExp _message = RegExp(r'^\s*\[([^\]]*)\]\s*(.*)$', dotAll: true);

  /// v4 행만 통과시킨다. 아니면(다른 kind·rule·등급·필수 값 누락) null.
  static EnvAlert? fromRow(Map<String, dynamic> row) {
    final kind = row['kind'];
    if (kind is! String) return null;
    final metric = _metricByKind[kind];
    if (metric == null) return null;

    final context = _contextOf(row['context']);
    if (context == null || context['rule'] != 'v4') return null;
    final level = switch (context['level']) {
      'caution' => EnvAlertLevel.caution,
      'danger' => EnvAlertLevel.danger,
      _ => null,
    };
    // 서버 계약상 v4 행은 등급이 늘 있다. 모르는 등급은 설명 문구·순서를
    // 정할 수 없어 그리지 않는다.
    if (level == null) return null;

    final id = row['id'];
    if (id == null) return null;
    final triggeredAt = parseLocalDateTime(row['triggered_at']);
    if (triggeredAt == null) return null;

    final message = row['message'] is String ? row['message'] as String : '';
    final match = _message.firstMatch(message);
    final chip = match?.group(1)?.trim();
    return EnvAlert(
      id: id.toString(),
      kind: kind,
      metric: metric,
      level: level,
      chip: chip == null || chip.isEmpty ? null : chip,
      title: match == null ? message.trim() : match.group(2)!.trim(),
      triggeredAt: triggeredAt,
      resolvedAt: parseLocalDateTime(row['resolved_at']),
    );
  }

  /// PostgREST·Realtime은 jsonb를 Map으로 준다. 문자열로 오는 경우만 한 번 푼다.
  static Map<String, dynamic>? _contextOf(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// 화면에 그릴 열린 행 — **지표별 `triggeredAt` 최신 1개**(G8: 주의→경고는
  /// 기존 행 종료 + 새 행이라 잠깐 둘 다 열려 보일 수 있다. 시각이 같으면
  /// 경고를 남긴다). 순서는 경고 먼저, 같은 등급이면 온도 → 습도.
  static List<EnvAlert> openLatestPerMetric(Iterable<EnvAlert> alerts) {
    final latest = <EnvAlertMetric, EnvAlert>{};
    for (final a in alerts) {
      if (!a.isOpen) continue;
      final cur = latest[a.metric];
      if (cur == null || _newer(a, cur)) latest[a.metric] = a;
    }
    final list = latest.values.toList()
      ..sort((a, b) {
        final byLevel = b.level.index.compareTo(a.level.index);
        if (byLevel != 0) return byLevel;
        return a.metric.index.compareTo(b.metric.index);
      });
    return list;
  }

  static bool _newer(EnvAlert a, EnvAlert b) {
    final t = a.triggeredAt.compareTo(b.triggeredAt);
    if (t != 0) return t > 0;
    final l = a.level.index.compareTo(b.level.index);
    if (l != 0) return l > 0;
    return a.id.compareTo(b.id) > 0;
  }

  /// 설명 한 줄의 ko.json 키 — 노션 v4 1-5 설명 열을 `kind + level`로 고정 매핑.
  String get hintKey => switch ((kind, level)) {
        ('env_temp_low', EnvAlertLevel.danger) => 'env_alert_hint_temp_low_danger',
        ('env_temp_low', _) => 'env_alert_hint_temp_low_caution',
        ('env_temp_high', _) => 'env_alert_hint_temp_high',
        ('env_humid_low', _) => 'env_alert_hint_humid_low',
        _ => 'env_alert_hint_humid_high',
      };

  @override
  bool operator ==(Object other) =>
      other is EnvAlert &&
      other.id == id &&
      other.kind == kind &&
      other.level == level &&
      other.chip == chip &&
      other.title == title &&
      other.triggeredAt == triggeredAt &&
      other.resolvedAt == resolvedAt;

  @override
  int get hashCode =>
      Object.hash(id, kind, level, chip, title, triggeredAt, resolvedAt);

  @override
  String toString() => 'EnvAlert($id, $kind, ${level.name}, "$chip" "$title")';
}
