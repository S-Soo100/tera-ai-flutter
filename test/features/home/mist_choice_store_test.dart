import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/home/data/mist_choice_store.dart';
import 'package:vivanaut/features/home/domain/mist_duration.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mist_choice_store');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HiveMistChoiceStore.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  const store = HiveMistChoiceStore();

  test('미저장 기본은 5초', () {
    expect(store.load('d1'), MistDuration.fiveSeconds);
  });

  test('저장 → 그대로 재현, 기기별 분리', () async {
    await store.save('d1', MistDuration.tenSeconds);
    expect(store.load('d1'), MistDuration.tenSeconds);
    expect(store.load('d2'), MistDuration.fiveSeconds);
  });

  test('손상·옛 값(3초·빠진 7초)은 기본 5초로', () async {
    final box = Hive.box<dynamic>(HiveMistChoiceStore.boxName);
    await box.put(HiveMistChoiceStore.keyFor('d1'), 'garbage');
    expect(store.load('d1'), MistDuration.fiveSeconds);
    await box.put(HiveMistChoiceStore.keyFor('d1'), 3000);
    expect(store.load('d1'), MistDuration.fiveSeconds);
    await box.put(HiveMistChoiceStore.keyFor('d1'), 7000);
    expect(store.load('d1'), MistDuration.fiveSeconds);
  });
}
