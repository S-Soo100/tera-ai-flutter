/// 기기 목표 환경(setpoint) — terra-api `GET/PATCH /devices/{id}/settings`
/// (2026-08-18 백엔드 회신 §5).
///
/// 미설정 기기도 404가 아니라 **값이 전부 null인 200**이다. 그래서 필드는
/// 모두 nullable이고, 화면은 null을 "목표 미설정"으로 그린다 — 앱이 임의
/// 기본값을 채워 넣지 않는다(온습도는 종마다 다르고 틀린 목표는 해롭다).
///
/// 서버 검증(위반 시 400): 온도 −20~60℃, 습도 0~100%, `*_min ≤ *_max`.
/// 앱도 같은 범위를 [validateTemp]/[validateHumidity]로 미리 막는다.
class DeviceSettings {
  final String deviceId;
  final double? targetTempC;
  final double? targetHumidityPct;
  final double? targetTempMin;
  final double? targetTempMax;
  final double? targetHumidMin;
  final double? targetHumidMax;
  final DateTime? updatedAt;

  const DeviceSettings({
    required this.deviceId,
    this.targetTempC,
    this.targetHumidityPct,
    this.targetTempMin,
    this.targetTempMax,
    this.targetHumidMin,
    this.targetHumidMax,
    this.updatedAt,
  });

  static const double tempMin = -20;
  static const double tempMax = 60;
  static const double humidityMin = 0;
  static const double humidityMax = 100;

  static bool validateTemp(double v) => v >= tempMin && v <= tempMax;
  static bool validateHumidity(double v) =>
      v >= humidityMin && v <= humidityMax;

  /// 목표가 하나라도 있는가. 둘 다 null이면 "미설정" 상태.
  bool get hasTarget => targetTempC != null || targetHumidityPct != null;

  factory DeviceSettings.fromJson(Map<String, dynamic> j) {
    return DeviceSettings(
      deviceId: j['device_id'] as String? ?? '',
      targetTempC: _d(j['target_temp_c']),
      targetHumidityPct: _d(j['target_humidity_pct']),
      targetTempMin: _d(j['target_temp_min']),
      targetTempMax: _d(j['target_temp_max']),
      targetHumidMin: _d(j['target_humid_min']),
      targetHumidMax: _d(j['target_humid_max']),
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString())?.toLocal()
          : null,
    );
  }

  /// PATCH 본문. **보낸 필드만 갱신**되므로 바꾸지 않을 값은 키째로 뺀다.
  static Map<String, dynamic> patchBody({
    double? targetTempC,
    double? targetHumidityPct,
  }) =>
      {
        if (targetTempC != null) 'target_temp_c': targetTempC,
        if (targetHumidityPct != null) 'target_humidity_pct': targetHumidityPct,
      };

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
