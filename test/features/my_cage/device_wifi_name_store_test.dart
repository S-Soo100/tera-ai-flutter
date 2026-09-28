import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/device_wifi_name_store.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wifi_names');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveDeviceWifiNameStore.boxName);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  // 로그아웃 뒤엔 집·사무실 Wi-Fi 이름을 남기지 않는다(CLAUDE.md 3층 계정 격리 ③).
  test('clearAll은 모든 계정의 Wi-Fi 이름만 지운다', () async {
    const store = HiveDeviceWifiNameStore();
    await store.save('a', PairTargetKind.device, 'd1', 'home');
    await store.save('b', PairTargetKind.camera, 'c1', 'office');
    final box = Hive.box<dynamic>(HiveDeviceWifiNameStore.boxName);
    await box.put('theme_mode', 'light');
    expect(store.load('a', PairTargetKind.device, 'd1'), 'home');
    await store.clearAll();
    expect(store.load('a', PairTargetKind.device, 'd1'), isNull);
    expect(store.load('b', PairTargetKind.camera, 'c1'), isNull);
    expect(box.get('theme_mode'), 'light');
  });
}
