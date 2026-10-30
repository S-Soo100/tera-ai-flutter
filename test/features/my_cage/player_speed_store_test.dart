import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivanaut/features/my_cage/data/player_speed_store.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';

/// 2026-10-30 사용자 결정 — 배속을 한 번 바꾸면 다른 영상·앱 재시작에도 이어진다.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('player_speed_store');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>(HivePlayerSpeedStore.boxName);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  const store = HivePlayerSpeedStore();

  test('미저장 기본은 1배', () {
    expect(store.load(), 1.0);
  });

  test('저장 → 그대로 재현', () async {
    await store.save(1.5);
    expect(store.load(), 1.5);
  });

  test('손상·목록 밖 값은 1배로', () async {
    final box = Hive.box<dynamic>(HivePlayerSpeedStore.boxName);
    await box.put(HivePlayerSpeedStore.key, 'garbage');
    expect(store.load(), 1.0);
    await box.put(HivePlayerSpeedStore.key, 1.75);
    expect(store.load(), 1.0);
    await box.put(HivePlayerSpeedStore.key, 2);
    expect(store.load(), 2.0);
  });

  test('박스가 닫혀 있으면 1배·저장 생략', () async {
    await Hive.close();
    await store.save(2.0);
    expect(store.load(), 1.0);
  });

  test('바꾼 배속은 앱을 다시 켠 것(새 컨테이너)에도 남는다', () async {
    final first = ProviderContainer();
    expect(first.read(playerSpeedProvider), 1.0);
    first.read(playerSpeedProvider.notifier).set(1.2);
    expect(first.read(playerSpeedProvider), 1.2);
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(playerSpeedProvider), 1.2);
  });
}
