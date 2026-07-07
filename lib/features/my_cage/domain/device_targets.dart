/// Supabase `device_settings` row의 목표 온습도 범위.
///
/// 이 디바이스에 device_settings 행이 없을 수 있다. 그럴 땐 repository가 null을
/// 반환하고 차트는 목표 밴드를 그리지 않는다. **임의 목표값을 지어내지 않는다**
/// — 파충류 사육정보는 생명과 직결되므로 데이터 정확성 원칙을 따른다.
class DeviceTargets {
  final double? tempMin;
  final double? tempMax;
  final double? humidMin;
  final double? humidMax;

  const DeviceTargets({
    required this.tempMin,
    required this.tempMax,
    required this.humidMin,
    required this.humidMax,
  });

  /// 온도 목표 밴드를 그릴 수 있는가 (min/max 둘 다 존재).
  bool get hasTempBand => tempMin != null && tempMax != null;

  /// 습도 목표 밴드를 그릴 수 있는가 (min/max 둘 다 존재).
  bool get hasHumidBand => humidMin != null && humidMax != null;

  factory DeviceTargets.fromJson(Map<String, dynamic> j) {
    return DeviceTargets(
      tempMin: _parseDouble(j['target_temp_min']),
      tempMax: _parseDouble(j['target_temp_max']),
      humidMin: _parseDouble(j['target_humid_min']),
      humidMax: _parseDouble(j['target_humid_max']),
    );
  }

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
