import '../../../shared/domain/num_format.dart';

/// `telemetry` 원본 한 행(메인 센서 A만). [TelemetryBucket.aggregate]의 입력.
typedef RawEnvSample = ({DateTime ts, double? t, double? h, bool ok});

/// Supabase `telemetry_30m` row 매핑 (30분 집계, 영구 보관).
///
/// 장기 온습도 추이 그래프의 데이터 소스. 메인 센서 A(`t_a_*`, `h_a_*`)만
/// 사용한다 — 이 디바이스에서 보조 센서 B는 항상 0이라 무시한다.
class TelemetryBucket {
  /// 30분 경계 시각 (UTC, timestamptz). 예: 12:00:00, 12:30:00.
  final DateTime bucket;

  /// 이 30분 버킷에 집계된 원본 telemetry 행 수. 정상 ≈ 600 (30분÷3초).
  final int sampleCount;

  /// Optional server contract: counts after the same validity filter as avg.
  /// null means unsupported; sampleCount must never be substituted.
  final int? tValidCount, hValidCount;

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
    this.tValidCount,
    this.hValidCount,
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
      // 2026-09-16 배포 컬럼명은 `t_a_count`/`h_a_count`(센서 정상 보고분만).
      // 2026-09-15 이전 버킷은 null → 평균 `--`. 구 제안명(`*_valid_count`)은
      // 호환용 폴백.
      tValidCount: _optionalInt(j['t_a_count'] ?? j['t_a_valid_count']),
      hValidCount: _optionalInt(j['h_a_count'] ?? j['h_a_valid_count']),
      tAvg: parseDouble(j['t_a_avg']),
      tMin: parseDouble(j['t_a_min']),
      tMax: parseDouble(j['t_a_max']),
      hAvg: parseDouble(j['h_a_avg']),
      hMin: parseDouble(j['h_a_min']),
      hMax: parseDouble(j['h_a_max']),
    );
  }

  static const span = Duration(minutes: 30);

  /// 원본 행을 30분 칸으로 묶는다 — 서버 `telemetry_30m`과 같은 규칙
  /// (`a_ok` + 값>0만 평균·최소·최대·유효 개수, 행 수는 전부. 2026-11-04 운영
  /// 11:30 칸 대조 일치). 아직 마감 전인 칸을 채우는 데 쓴다. 시간 오름차순.
  static List<TelemetryBucket> aggregate(Iterable<RawEnvSample> samples) {
    final groups = <int, List<RawEnvSample>>{};
    for (final s in samples) {
      final ms = s.ts.toUtc().millisecondsSinceEpoch;
      final start = ms - ms % span.inMilliseconds;
      (groups[start] ??= []).add(s);
    }
    final starts = groups.keys.toList()..sort();
    return [
      for (final start in starts)
        _fromSamples(
            DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
            groups[start]!),
    ];
  }

  static TelemetryBucket _fromSamples(DateTime bucket, List<RawEnvSample> rows) {
    bool valid(double? v) => v != null && v.isFinite && v > 0;
    final ts = [for (final r in rows) if (r.ok && valid(r.t)) r.t!];
    final hs = [for (final r in rows) if (r.ok && valid(r.h)) r.h!];
    double? avg(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    double? lo(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a < b ? a : b);
    double? hi(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
    return TelemetryBucket(
      bucket: bucket,
      sampleCount: rows.length,
      tValidCount: ts.length,
      hValidCount: hs.length,
      tAvg: avg(ts),
      tMin: lo(ts),
      tMax: hi(ts),
      hAvg: avg(hs),
      hMin: lo(hs),
      hMax: hi(hs),
    );
  }

  /// 원본 꼬리를 읽기 시작할 시각 — 마지막 마감 칸의 끝, 마감 칸이 없으면 [from].
  static DateTime tailFrom(List<TelemetryBucket> closed, DateTime from) {
    if (closed.isEmpty) return from;
    final end = closed.last.bucket.add(span);
    return end.isAfter(from) ? end : from;
  }

  /// 마감 칸([closed]) 뒤에 원본으로 만든 열린 칸([tail])을 잇는다. 같은 칸이
  /// 이미 마감됐으면 마감 쪽을 쓴다(서버 값이 기준).
  static List<TelemetryBucket> withOpenTail(
      List<TelemetryBucket> closed, List<TelemetryBucket> tail) {
    final last = closed.isEmpty ? null : closed.last.bucket;
    return [
      ...closed,
      for (final b in tail)
        if (last == null || b.bucket.isAfter(last)) b,
    ];
  }

  static int? _optionalInt(Object? v) => v == null ? null : _parseInt(v);

  /// DB 컬럼은 int/num/String 어느 형태로도 올 수 있다. 파싱 실패는 0.
  static int _parseInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
