import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/known_device_store.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

const cam = DeviceAddCandidate(
    physicalId: 'AA:BB',
    kind: PairTargetKind.camera,
    name: 'FB2_P4_CAM_A1B2',
    rssi: -40);

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('known_device_store');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveKnownDeviceStore.boxName);
  });
  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  const store = HiveKnownDeviceStore();

  test('기억한 카메라는 같은 계정·같은 BLE 주소·같은 광고 이름일 때만 찾는다', () async {
    await store.save('owner', cam, 'row-1');
    expect(store.load('owner', cam), 'row-1');
    expect(store.load('other', cam), isNull);
    expect(
        store.load(
            'owner',
            const DeviceAddCandidate(
                physicalId: 'AA:BB',
                kind: PairTargetKind.camera,
                name: 'FB2_P4_CAM_FFFF',
                rssi: -40)),
        isNull);
  });

  test('잊으면 다시 등록 대상이 된다', () async {
    await store.save('owner', cam, 'row-1');
    await store.forget('owner', cam);
    expect(store.load('owner', cam), isNull);
  });

  test('박스가 안 열려 있으면 모른다고 답한다', () async {
    await Hive.close();
    expect(store.load('owner', cam), isNull);
    await store.save('owner', cam, 'row-1');
  });

  // 사육장도 기억한다(2026-09-21, 스캔 목록 '이미 등록됨'). 카메라 키는
  // 그대로라 이미 기억한 카메라가 사라지지 않는다.
  test('사육장은 카메라와 다른 키로 기억한다', () async {
    const dev = DeviceAddCandidate(
        physicalId: 'AA:BB',
        kind: PairTargetKind.device,
        name: 'terra-iot',
        rssi: -40);
    await store.save('owner', cam, 'camera-row');
    await store.save('owner', dev, 'device-row');
    expect(store.load('owner', cam), 'camera-row');
    expect(store.load('owner', dev), 'device-row');
    expect(
        HiveKnownDeviceStore.keyFor('owner', cam), 'known_camera_owner_AA:BB');
    expect(
        HiveKnownDeviceStore.keyFor('owner', dev), 'known_device_owner_AA:BB');
  });
}
