import 'device_add_flow.dart';
import 'pair_target_kind.dart';
import 'sys_health.dart';

/// 네트워크 관리 목록에 보일 이 계정 기기 행(2026-11-19, Figma 1913:6570).
///
/// 판정용 [OwnedDeviceRow]와 따로 둔다 — 목록 표시 값(이름·신호·Wi-Fi 이름)과
/// 재부팅 판정용 가동 시간이 더 있다.
class OwnedNetworkDevice {
  const OwnedNetworkDevice(
      {required this.kind,
      required this.id,
      required this.name,
      this.hardwareId,
      this.isOnline,
      this.lastSeen,
      this.wifiRssi,
      this.wifiSsid,
      this.uptimeSeconds});
  final PairTargetKind kind;

  /// `devices.id`/`cameras.id`(행 UUID).
  final String id;
  final String name;

  /// 서버 `hw_id` — 목록 둘째 줄이자 BLE 알아보기 근거.
  final String? hardwareId;
  final bool? isOnline;
  final DateTime? lastSeen;

  /// 사육장 `sys_state.rssi`, 카메라 `clip_stats.sys.rssi`.
  final int? wifiRssi;

  /// 서버 `wifi_ssid`(아직 보고 안 함 — 생기면 앱 수정 없이 읽는다).
  final String? wifiSsid;

  /// 카메라 재부팅 판정용(`SysHealth.uptimeSeconds`).
  final int? uptimeSeconds;
}

/// 이 기기를 어떻게 알아봤나 — [memory]는 이 폰이 붙인 기억, [hardware]는
/// [bleMatchesHardware] 힌트.
enum NetworkMatchVia { memory, hardware }

typedef NetworkMatch = ({OwnedNetworkDevice device, NetworkMatchVia via});

/// 근처 BLE 후보를 이 계정 기기 행에 맞춘다. 키는 [DeviceAddCandidate.physicalId],
/// [remembered]는 `physicalId → 행 id`(이 폰의 기억).
///
/// 같은 종류끼리만 본다. ① 기억이 그 종류 행을 가리키면 memory ② 아니면
/// `hw_id`가 맞는 행이 정확히 하나일 때 hardware ③ 한 행에 후보가 둘 이상
/// 맞으면 모두 뺀다 — 단 기억으로 맞은 후보가 정확히 하나면 그것만 남긴다.
/// 엉뚱한 기기에 Wi-Fi를 보내지 않는 것이 빈 줄보다 중요하다.
Map<String, NetworkMatch> matchOwnedDevices(List<DeviceAddCandidate> candidates,
    List<OwnedNetworkDevice> rows, Map<String, String> remembered) {
  final byRow = <(PairTargetKind, String), List<(String, NetworkMatch)>>{};
  for (final c in candidates) {
    final sameKind = rows.where((r) => r.kind == c.kind);
    NetworkMatch? match;
    final memoryId = remembered[c.physicalId];
    if (memoryId != null) {
      for (final r in sameKind) {
        if (r.id == memoryId) {
          match = (device: r, via: NetworkMatchVia.memory);
          break;
        }
      }
    }
    if (match == null) {
      final hits =
          sameKind.where((r) => bleMatchesHardware(c, r.hardwareId)).toList();
      if (hits.length == 1) {
        match = (device: hits.single, via: NetworkMatchVia.hardware);
      }
    }
    if (match == null) continue;
    byRow.putIfAbsent((match.device.kind, match.device.id), () => []).add(
        (c.physicalId, match));
  }
  final result = <String, NetworkMatch>{};
  for (final entries in byRow.values) {
    if (entries.length == 1) {
      result[entries.single.$1] = entries.single.$2;
      continue;
    }
    final byMemory =
        entries.where((e) => e.$2.via == NetworkMatchVia.memory).toList();
    if (byMemory.length == 1) result[byMemory.single.$1] = byMemory.single.$2;
  }
  return result;
}

/// 서버가 오프라인이라 했을 때만 — 모르면(null) 오프라인으로 보지 않는다.
bool networkOffline(OwnedNetworkDevice d) => d.isOnline == false;

/// 신호 그림 — 기기 추가 목록과 네트워크 관리 목록이 같은 경계를 쓴다.
String networkSignalIcon(int rssi) => rssi >= -60
    ? 'redesign_v2/signal_cellular_alt'
    : rssi >= kWeakRssi
        ? 'redesign_v2/signal_cellular_alt_2_bar'
        : 'redesign_v2/signal_cellular_alt_1_bar';

/// 목록 순서 — 바꿔야 할 기기가 위로. 미리 체크([preferredIds]의 행 id) →
/// 오프라인 → 신호 약한 순(모름은 뒤) → 이름.
int compareNetworkRows(
    NetworkMatch a, NetworkMatch b, Set<String> preferredIds) {
  int flag(bool x, bool y) => x == y ? 0 : (x ? -1 : 1);
  final byPreferred = flag(
      preferredIds.contains(a.device.id), preferredIds.contains(b.device.id));
  if (byPreferred != 0) return byPreferred;
  final byOffline = flag(networkOffline(a.device), networkOffline(b.device));
  if (byOffline != 0) return byOffline;
  final ra = a.device.wifiRssi, rb = b.device.wifiRssi;
  if (ra != rb) {
    if (ra == null) return 1;
    if (rb == null) return -1;
    return ra.compareTo(rb);
  }
  return a.device.name.compareTo(b.device.name);
}
