import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/network_manage.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

/// Android 카메라 후보 — 주소가 MAC이다.
DeviceAddCandidate cam(String physicalId) => DeviceAddCandidate(
    physicalId: physicalId,
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM',
    rssi: -50);

/// iOS 카메라 후보 — 주소가 UUID라 광고 이름 끝 `_XXXX`만 본다.
DeviceAddCandidate camNamed(String name) => DeviceAddCandidate(
    physicalId: 'uuid-$name',
    kind: PairTargetKind.camera,
    name: name,
    rssi: -50);

/// Android 사육장 후보.
DeviceAddCandidate dev(String physicalId) => DeviceAddCandidate(
    physicalId: physicalId,
    kind: PairTargetKind.device,
    name: 'terra-iot',
    rssi: -50);

OwnedNetworkDevice camRow(String id, {String? hw}) => OwnedNetworkDevice(
    kind: PairTargetKind.camera, id: id, name: id, hardwareId: hw);

OwnedNetworkDevice devRow(String id, {String? hw}) => OwnedNetworkDevice(
    kind: PairTargetKind.device, id: id, name: id, hardwareId: hw);

// 순서 테스트용 — 미리 체크 표시는 기기 객체에 붙인다.
final _preferred = Expando<bool>('preferred');

NetworkMatch _row(String id, {int? rssi, bool? online = true}) => (
      device: OwnedNetworkDevice(
          kind: PairTargetKind.camera,
          id: id,
          name: id,
          isOnline: online,
          wifiRssi: rssi),
      via: NetworkMatchVia.hardware
    );

NetworkMatch good(String id, int rssi) => _row(id, rssi: rssi);
NetworkMatch weak(String id, int rssi) => _row(id, rssi: rssi);
NetworkMatch offline(String id) => _row(id, online: false);
NetworkMatch pref(String id, int rssi) {
  final m = _row(id, rssi: rssi);
  _preferred[m.device] = true;
  return m;
}

List<NetworkMatch> sorted(List<NetworkMatch> list) {
  final preferred = {
    for (final m in list)
      if (_preferred[m.device] == true) m.device.id
  };
  return [...list]..sort((a, b) => compareNetworkRows(a, b, preferred));
}

void main() {
  group('matchOwnedDevices', () {
    test('기억이 hw보다 우선', () {
      final m = matchOwnedDevices(
          [cam('AA:BB:CC:DD:EE:12')],
          [camRow('c1', hw: 'AABBCCDDEE10'), camRow('c2')],
          {'AA:BB:CC:DD:EE:12': 'c2'});
      expect(m['AA:BB:CC:DD:EE:12']!.device.id, 'c2');
      expect(m['AA:BB:CC:DD:EE:12']!.via, NetworkMatchVia.memory);
    });

    test('Android 차이 0·2만', () {
      expect(
          matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')],
                  [camRow('c1', hw: 'AABBCCDDEE10')], {})['AA:BB:CC:DD:EE:12']!
              .via,
          NetworkMatchVia.hardware);
      expect(
          matchOwnedDevices([cam('AA:BB:CC:DD:EE:13')],
              [camRow('c1', hw: 'AABBCCDDEE10')], {}),
          isEmpty);
    });

    test('한 BLE에 맞는 행이 둘이면 없음', () {
      expect(
          matchOwnedDevices([
            camNamed('FB2_P4_CAM_EE12')
          ], [
            camRow('c1', hw: '00111111EE10'),
            camRow('c2', hw: '00222222EE12')
          ], {}),
          isEmpty);
    });

    test('한 행에 맞는 BLE가 둘이면 둘 다 null', () {
      final m = matchOwnedDevices(
          [camNamed('FB2_P4_CAM_EE12'), camNamed('FB2_P4_CAM_EE10')],
          [camRow('c1', hw: '00111111EE10')],
          {});
      expect(m, isEmpty);
      expect(m['uuid-FB2_P4_CAM_EE12'], isNull);
      expect(m['uuid-FB2_P4_CAM_EE10'], isNull);
    });

    test('한 행에 맞는 BLE가 둘이어도 기억으로 맞은 것이 하나면 그것만 남는다', () {
      final m = matchOwnedDevices(
          [camNamed('FB2_P4_CAM_EE12'), camNamed('FB2_P4_CAM_EE10')],
          [camRow('c1', hw: '00111111EE10')],
          {'uuid-FB2_P4_CAM_EE10': 'c1'});
      expect(m.keys, ['uuid-FB2_P4_CAM_EE10']);
      expect(m['uuid-FB2_P4_CAM_EE10']!.via, NetworkMatchVia.memory);
    });

    test('다른 종류 행은 보지 않는다', () {
      expect(
          matchOwnedDevices([cam('AA:BB:CC:DD:EE:12')],
              [devRow('d1', hw: 'AABBCCDDEE10')], {}),
          isEmpty);
      // 기억이 다른 종류 행을 가리켜도 그 행으로 맞추지 않는다.
      expect(
          matchOwnedDevices([dev('11:22:33:44:55:66')], [camRow('c1')],
              {'11:22:33:44:55:66': 'c1'}),
          isEmpty);
    });

    test('기억이 없는 행을 가리키면 hw로 알아본다', () {
      final m = matchOwnedDevices([dev('11:22:33:44:55:66')],
          [devRow('d1', hw: '112233445564')], {'11:22:33:44:55:66': 'gone'});
      expect(m['11:22:33:44:55:66']!.device.id, 'd1');
      expect(m['11:22:33:44:55:66']!.via, NetworkMatchVia.hardware);
    });
  });

  test('networkOffline은 is_online == false일 때만', () {
    expect(networkOffline(offline('a').device), isTrue);
    expect(networkOffline(good('a', -50).device), isFalse);
    expect(networkOffline(_row('a', online: null).device), isFalse);
  });

  test('신호 그림 경계', () {
    expect(networkSignalIcon(-60), 'redesign_v2/signal_cellular_alt');
    expect(networkSignalIcon(-61), 'redesign_v2/signal_cellular_alt_2_bar');
    expect(networkSignalIcon(-75), 'redesign_v2/signal_cellular_alt_2_bar');
    expect(networkSignalIcon(-76), 'redesign_v2/signal_cellular_alt_1_bar');
  });

  test('순서: 미리 체크 → 오프라인 → 약한 순 → 이름', () {
    expect(
        sorted([good('a', -50), weak('b', -80), offline('c'), pref('d', -40)])
            .map((m) => m.device.id),
        ['d', 'c', 'b', 'a']);
    // rssi 모름은 아는 것 뒤, 같으면 이름 순.
    expect(
        sorted([_row('z'), good('y', -50), good('x', -50)])
            .map((m) => m.device.id),
        ['x', 'y', 'z']);
  });
}
