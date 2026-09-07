import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivnanaut/features/home/data/fan_choice_store.dart';
import 'package:vivnanaut/features/home/domain/fan_timer_duration.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fan_choice_store');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveFanChoiceStore.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  const store = HiveFanChoiceStore();

  test('미저장 기본은 30분 — 첫 원탭이 여기서 나온다', () {
    expect(store.load('d1'), FanTimerDuration.m30);
  });

  test('타이머 저장 → 그대로 재현, 기기별 분리', () async {
    await store.save('d1', FanTimerDuration.h2);
    expect(store.load('d1'), FanTimerDuration.h2);
    expect(store.load('d2'), FanTimerDuration.m30); // 다른 기기는 기본
  });

  test('계속 켜기(null) 저장 → null로 재현(0 센티널)', () async {
    await store.save('d1', null);
    expect(store.load('d1'), isNull);
  });

  test('손상·미지원 값은 기본 30분으로 방어', () async {
    final box = Hive.box<dynamic>(HiveFanChoiceStore.boxName);
    await box.put(HiveFanChoiceStore.keyFor('d1'), 'garbage');
    expect(store.load('d1'), FanTimerDuration.m30);
    await box.put(HiveFanChoiceStore.keyFor('d1'), 45); // 옵션에 없는 분
    expect(store.load('d1'), FanTimerDuration.m30);
  });

  test('박스가 닫혀 있으면(load) 기본값, (save) 조용히 스킵', () async {
    await Hive.box<dynamic>(HiveFanChoiceStore.boxName).close();
    expect(store.load('d1'), FanTimerDuration.m30);
    await store.save('d1', FanTimerDuration.h1); // no throw
  });
}
