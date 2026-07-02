/// BLE 프로비저닝 대상 기기가 스캔한 WiFi AP 1건.
///
/// TX notify 라인 `AP:<no>,<ssid>,<rssi>,<channel>`을 파싱해 생성한다.
/// ssid에 콤마가 포함될 수 있어 파싱은 Repository에서 토큰 경계로 처리한다.
class WifiAccessPoint {
  final int no;
  final String ssid;
  final int rssi;
  final int channel;

  const WifiAccessPoint({
    required this.no,
    required this.ssid,
    required this.rssi,
    required this.channel,
  });

  /// rssi를 4단계 신호강도(0~3)로 변환.
  /// -55 이상=3(강) / -66 이상=2 / -77 이상=1 / 그 미만=0(약).
  WifiSignalLevel get signalLevel {
    if (rssi >= -55) return WifiSignalLevel.strong;
    if (rssi >= -66) return WifiSignalLevel.good;
    if (rssi >= -77) return WifiSignalLevel.fair;
    return WifiSignalLevel.weak;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WifiAccessPoint &&
          other.no == no &&
          other.ssid == ssid &&
          other.rssi == rssi &&
          other.channel == channel;

  @override
  int get hashCode => Object.hash(no, ssid, rssi, channel);
}

/// WiFi 신호강도 4단계. UI 아이콘/라벨 매핑용.
enum WifiSignalLevel { weak, fair, good, strong }
