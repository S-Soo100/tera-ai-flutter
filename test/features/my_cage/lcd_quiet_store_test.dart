import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/lcd_quiet_store.dart';
import 'package:vivanaut/features/my_cage/data/lcd_text_store.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lcd_quiet');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveLcdQuietStore.boxName);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  const late = LcdQuietWindow(startMinute: 23 * 60, endMinute: 7 * 60 + 30);

  test('계정·기기별로 기억한다', () async {
    const store = HiveLcdQuietStore();
    expect(store.load('a', 'd1'), isNull, reason: '처음엔 모른다(호출측이 기본값)');
    await store.save('a', 'd1', late);
    expect(store.load('a', 'd1'), late);
    expect(store.load('b', 'd1'), isNull);
    expect(store.load('a', 'd2'), isNull);
    final box = Hive.box<dynamic>(HiveLcdQuietStore.boxName);
    expect(box.get('lcd_quiet_a_d1'), '23:00-07:30');
  });

  test('시작=종료는 저장하지 않고, 깨진 값은 모른다고 답한다', () async {
    const store = HiveLcdQuietStore();
    await store.save(
        'a', 'd1', const LcdQuietWindow(startMinute: 60, endMinute: 60));
    expect(store.load('a', 'd1'), isNull);
    final box = Hive.box<dynamic>(HiveLcdQuietStore.boxName);
    for (final bad in ['garbage', '23:00', 42, '08:00-08:00', '25:00-07:00']) {
      await box.put(HiveLcdQuietStore.keyFor('a', 'd1'), bad);
      expect(store.load('a', 'd1'), isNull, reason: '$bad');
    }
  });

  // 로그아웃 뒤엔 남기지 않는다(CLAUDE.md 3층 계정 격리 ③).
  test('clearAll은 모든 계정의 예약 시간만 지운다', () async {
    const store = HiveLcdQuietStore();
    await store.save('a', 'd1', late);
    await store.save('b', 'd2', LcdQuietWindow.defaults);
    await const HiveLcdTextStore().save('a', 'd1', '도도네 집');
    final box = Hive.box<dynamic>(HiveLcdQuietStore.boxName);
    await box.put('theme_mode', 'light');
    await store.clearAll();
    expect(store.load('a', 'd1'), isNull);
    expect(store.load('b', 'd2'), isNull);
    expect(const HiveLcdTextStore().load('a', 'd1'), '도도네 집');
    expect(box.get('theme_mode'), 'light');
  });

  test('박스가 안 열려 있으면 모른다고 답하고 저장은 건너뛴다', () async {
    await Hive.close();
    const store = HiveLcdQuietStore();
    expect(store.load('a', 'd1'), isNull);
    await store.save('a', 'd1', late);
    await store.clearAll();
  });
}
