import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/data/home_selection_store.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';

/// 등록 시각은 id 숫자 순(1이 가장 먼저 등록).
Device _device(String id) => Device(
    id: id,
    ownerId: 'u',
    enclosureId: null,
    name: '사육장 $id',
    isOnline: true,
    lastSeenAt: null,
    createdAt: int.tryParse(id) == null
        ? null
        : DateTime.utc(2026, 1, int.parse(id)));

class _MemoryStore implements HomeSelectionStore {
  final values = <String, String>{};
  @override
  String? load(String userId) => values[userId];
  @override
  Future<void> save(String userId, String? deviceId) async {
    if (deviceId == null) {
      values.remove(userId);
    } else {
      values[userId] = deviceId;
    }
  }

  @override
  Future<void> clearAll() async => values.clear();
}

/// 앱 한 번 실행 = 컨테이너 하나. [devices]는 서버가 준 순서(최근 신호 순).
ProviderContainer _launch(_MemoryStore store, String userId, List<String> devices) {
  final c = ProviderContainer(overrides: [
    homeSelectionStoreProvider.overrideWithValue(store),
    currentUserProvider.overrideWith((ref) => User(
        id: userId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01')),
    deviceListProvider
        .overrideWith((ref) async => [for (final id in devices) _device(id)]),
    enclosureSetsProvider.overrideWith((ref) async => const []),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  // 2026-11-05 실기기 QA: 홈 선택을 저장하지 않아, 앱을 켤 때마다 기기 목록
  // (last_seen_at 내림차순)의 첫 사육장이 떴다 — 사육장이 여러 대면 매번 바뀐다.
  test('고른 사육장은 앱을 다시 켜도(기기 순서가 바뀌어도) 그대로다', () async {
    final store = _MemoryStore();
    final first = _launch(store, 'u', ['1', '2', '3']);
    expect((await first.read(currentSetProvider.future))!.device!.id, '1');
    first.read(selectedHomeDeviceIdProvider.notifier).state = '2';
    await Future<void>.delayed(Duration.zero);

    final second = _launch(store, 'u', ['3', '1', '2']);
    expect(second.read(selectedHomeDeviceIdProvider), '2');
    expect((await second.read(currentSetProvider.future))!.device!.id, '2');
  });

  test('기억한 선택이 없으면 신호 순서와 무관하게 먼저 등록한 사육장', () async {
    final store = _MemoryStore();
    for (final order in [
      ['3', '1', '2'],
      ['2', '3', '1'],
    ]) {
      final c = _launch(store, 'u', order);
      final sets = await c.read(homeDeviceSetsProvider.future);
      expect([for (final s in sets) s.device!.id], ['1', '2', '3']);
      expect((await c.read(currentSetProvider.future))!.device!.id, '1');
    }
  });

  test('저장한 사육장이 없어졌으면 첫 사육장, 다른 계정은 따로 기억한다', () async {
    final store = _MemoryStore()..values['u'] = 'gone';
    final c = _launch(store, 'u', ['3', '1']);
    expect((await c.read(currentSetProvider.future))!.device!.id, '1');

    final other = _launch(store, 'other', ['1', '2']);
    expect(other.read(selectedHomeDeviceIdProvider), isNull);
    other.read(selectedHomeDeviceIdProvider.notifier).state = '2';
    await Future<void>.delayed(Duration.zero);
    expect(store.values, {'u': 'gone', 'other': '2'});
  });

  group('HiveHomeSelectionStore', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('home_selection');
      Hive.init(dir.path);
      await Hive.openBox<dynamic>(HiveHomeSelectionStore.boxName);
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('계정별로 저장·삭제하고 로그아웃 정리는 이 키만 지운다', () async {
      const store = HiveHomeSelectionStore();
      final box = Hive.box<dynamic>(HiveHomeSelectionStore.boxName);
      await box.put('theme_mode', 'light');
      await store.save('a', 'd1');
      await store.save('b', 'd2');
      expect(store.load('a'), 'd1');
      expect(store.load('b'), 'd2');

      await store.save('a', null);
      expect(store.load('a'), isNull);

      await box.put(HiveHomeSelectionStore.keyFor('c'), '');
      expect(store.load('c'), isNull);

      await store.clearAll();
      expect(store.load('b'), isNull);
      expect(box.get('theme_mode'), 'light');
    });
  });
}
