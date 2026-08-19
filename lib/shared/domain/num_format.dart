/// 숫자 표기·파싱 공용 (2026-08-18 리뷰 반영 — 5곳에 흩어져 있던 복제 통합).
library;

/// `28.0 → "28"`, `28.5 → "28.5"`, `28.333 → "28.3"`(기본 소수 1자리, 뒤 0 제거).
///
/// 목표 온습도·가드 값·차트 라벨처럼 "정수면 정수로, 아니면 짧게" 보여주는
/// 자리에 쓴다. [maxFractionDigits]는 표시 상한 — 사용자가 친 값을 편집기에
/// 되채울 땐 넉넉히(2) 줘서 되돌림에서 값이 바뀌지 않게 한다.
String formatCompact(double v, {int maxFractionDigits = 1}) {
  if (v == v.roundToDouble()) return '${v.toInt()}';
  var s = v.toStringAsFixed(maxFractionDigits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// JSON 값 → double. Supabase/REST는 numeric을 num 또는 문자열로 준다.
/// 그 외(null·bool·Map)는 null.
double? parseDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// JSON 타임스탬프 → **로컬** DateTime. Supabase `timestamptz`는 `+00:00`으로
/// 오고 `DateTime.tryParse`는 그것을 **UTC 객체**로 만든다 — 그대로 두면
/// `DateFormat('HH:mm')`이 UTC 시각을 찍어 한국에서 9시간 빠르게 보이고,
/// 07:00 하루 경계 비교도 어긋난다(2026-08-19 타임라인 실기기 버그).
/// 표시·날짜 경계에 쓰는 모든 시각은 이 헬퍼로 파싱해 로컬로 통일한다.
/// 오프셋 없는 문자열은 Dart 규칙대로 로컬로 해석된다(그대로 둔다).
DateTime? parseLocalDateTime(Object? v) {
  if (v == null) return null;
  final parsed = DateTime.tryParse(v.toString());
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}
