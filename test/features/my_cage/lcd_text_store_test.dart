import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/lcd_text_store.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lcd_texts');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveLcdTextStore.boxName);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('계정·기기별로 저장하고 watch가 지금 값과 바뀐 값을 흘린다', () async {
    const store = HiveLcdTextStore();
    await store.save('a', 'd1', '도도네 집');
    expect(store.load('a', 'd1'), '도도네 집');
    expect(store.load('b', 'd1'), isNull);

    final values = <String?>[];
    final sub = store.watch('a', 'd1').listen(values.add);
    await Future<void>.delayed(Duration.zero);
    await store.save('a', 'd1', '밥 6시');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(values, ['도도네 집', '밥 6시']);
  });

  // 로그아웃 뒤엔 문구를 남기지 않는다(CLAUDE.md 3층 계정 격리 ③).
  test('clearAll은 모든 계정의 LCD 문구만 지운다', () async {
    const store = HiveLcdTextStore();
    await store.save('a', 'd1', '도도네 집');
    await store.save('b', 'd2', '밥 6시');
    final box = Hive.box<dynamic>(HiveLcdTextStore.boxName);
    await box.put('theme_mode', 'light');
    await box.put('device_wifi_a_device_d1', 'home');
    await store.clearAll();
    expect(store.load('a', 'd1'), isNull);
    expect(store.load('b', 'd2'), isNull);
    expect(box.get('theme_mode'), 'light');
    expect(box.get('device_wifi_a_device_d1'), 'home');
  });
}
