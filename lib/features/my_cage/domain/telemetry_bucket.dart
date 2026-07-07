/// Supabase `telemetry_30m` row 매핑 (30분 집계, 영구 보관).
///
/// 장기 온습도 추이 그래프의 데이터 소스. 메인 센서 A(`t_a_*`, `h_a_*`)만
/// 사용한다 — 이 디바이스에서 보조 센서 B는 항상 0이라 무시한다.
class TelemetryBucket {
  /// 30분 경계 시각 (UTC, timestamptz). 예: 12:00:00, 12:30:00.
  final DateTime bucket;

  /// 이 30분 버킷에 집계된 원본 telemetry 행 수. 정상 ≈ 600 (30분÷3초).
  final int sampleCount;

  /// 메인 센서 A 온도 평균/최소/최대 (°C).
  final double? tAvg;
  final double? tMin;
  final double? tMax;

  /// 메인 센서 A 습도 평균/최소/최대 (%RH).
  final double? hAvg;
  final double? hMin;
  final double? hMax;

  const TelemetryBucket({
    required this.bucket,
    required this.sampleCount,
    required this.tAvg,
    required this.tMin,
    required this.tMax,
    required this.hAvg,
    required this.hMin,
    required this.hMax,
  });

  /// sample_count가 정상(≈600)에 크게 못 미치는 부분 집계 버킷.
  /// 300 미만이면 불완전 → 차트에서 옅게 표시(문서 §4).
  bool get isPartial => sampleCount < 300;

  factory TelemetryBucket.fromJson(Map<String, dynamic> j) {
    return TelemetryBucket(
      bucket: DateTime.parse(j['bucket'].toString()),
      sampleCount: _parseInt(j['sample_count']),
      tAvg: _parseDouble(j['t_a_avg']),
      tMin: _parseDouble(j['t_a_min']),
      tMax: _parseDouble(j['t_a_max']),
      hAvg: _parseDouble(j['h_a_avg']),
      hMin: _parseDouble(j['h_a_min']),
      hMax: _parseDouble(j['h_a_max']),
    );
  }

  /// DB 컬럼은 int/num/String 어느 형태로도 올 수 있다. 파싱 실패는 0.
  static int _parseInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
