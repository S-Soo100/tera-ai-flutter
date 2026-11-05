import '../../../shared/domain/env_thresholds.dart';
import '../../../shared/domain/num_format.dart';

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

  /// 서버 자동 환기·자동 분무 켬(계약 C1, 기본 false). 판정·실행은 서버가
  /// 하고 앱은 이 값을 읽고 쓰기만 한다. 마이그레이션 전 서버는 키를 안
  /// 보내므로 false다.
  final bool autoVentEnabled;
  final bool autoMistEnabled;
  final DateTime? updatedAt;

  const DeviceSettings({
    required this.deviceId,
    this.targetTempC,
    this.targetHumidityPct,
    this.targetTempMin,
    this.targetTempMax,
    this.targetHumidMin,
    this.targetHumidMax,
    this.autoVentEnabled = false,
    this.autoMistEnabled = false,
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

  /// v4 적정 온도 범위(2026-11-02). 미설정·범위 밖·스텝 밖·`min >= max`는
  /// [EnvRange.fromSettings] 규칙으로 디폴트(18~27℃)나 허용값으로 맞춘다.
  /// 위 "임의 기본값 금지"는 단일 목표값([targetTempC]) 얘기다 — 적정 범위는
  /// 기획 v4 1-1이 크레스티드 게코 디폴트를 정했고 서버 판정도 같은 디폴트를 쓴다.
  EnvRange get tempRange => EnvRange.fromSettings(
      targetTempMin, targetTempMax, EnvRangeRule.temp, EnvRange.tempDefault);

  /// v4 적정 습도 범위(디폴트 40~80%). 규칙은 [tempRange]와 같다.
  EnvRange get humidRange => EnvRange.fromSettings(targetHumidMin,
      targetHumidMax, EnvRangeRule.humid, EnvRange.humidDefault);

  factory DeviceSettings.fromJson(Map<String, dynamic> j) {
    return DeviceSettings(
      deviceId: j['device_id'] as String? ?? '',
      targetTempC: parseDouble(j['target_temp_c']),
      targetHumidityPct: parseDouble(j['target_humidity_pct']),
      targetTempMin: parseDouble(j['target_temp_min']),
      targetTempMax: parseDouble(j['target_temp_max']),
      targetHumidMin: parseDouble(j['target_humid_min']),
      targetHumidMax: parseDouble(j['target_humid_max']),
      // `== true`만 켬 — 서버는 bool만 받는다(문자열 "true"는 422). 다른
      // 모양이 오면 켜졌다고 믿지 않는다.
      autoVentEnabled: j['auto_vent_enabled'] == true,
      autoMistEnabled: j['auto_mist_enabled'] == true,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'].toString())?.toLocal()
          : null,
    );
  }

  /// PATCH 본문. **보낸 필드만 갱신**되므로 바꾸지 않을 값은 키째로 뺀다.
  ///
  /// v4 적정 범위(`target_*_min/max`)는 한 화면에서 MIN·MAX를 **함께** 보낸다
  /// — 한쪽만 보내면 서버의 `min ≤ max` 검증이 저장된 반대쪽과 비교한다.
  ///
  /// 자동 토글(`auto_*_enabled`)은 두 필드만 보내도 된다(계약 C1).
  static Map<String, dynamic> patchBody({
    double? targetTempC,
    double? targetHumidityPct,
    double? targetTempMin,
    double? targetTempMax,
    double? targetHumidMin,
    double? targetHumidMax,
    bool? autoVentEnabled,
    bool? autoMistEnabled,
  }) =>
      {
        if (targetTempC != null) 'target_temp_c': targetTempC,
        if (targetHumidityPct != null) 'target_humidity_pct': targetHumidityPct,
        if (targetTempMin != null) 'target_temp_min': targetTempMin,
        if (targetTempMax != null) 'target_temp_max': targetTempMax,
        if (targetHumidMin != null) 'target_humid_min': targetHumidMin,
        if (targetHumidMax != null) 'target_humid_max': targetHumidMax,
        if (autoVentEnabled != null) 'auto_vent_enabled': autoVentEnabled,
        if (autoMistEnabled != null) 'auto_mist_enabled': autoMistEnabled,
      };
}
