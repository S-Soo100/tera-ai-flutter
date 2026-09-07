import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vivnanaut/core/theme/theme_mode_provider.dart';

class _MemoryRepo implements ThemeModeRepository {
  ThemeMode stored = ThemeModeRepository.defaultMode;
  int saves = 0;

  @override
  ThemeMode load() => stored;

  @override
  Future<void> save(ThemeMode mode) async {
    stored = mode;
    saves++;
  }
}

void main() {
  group('themeModeProvider', () {
    test('기본은 light — 저장소가 비어 있으면 B안 라이트(2026-08-14 저녁 결정)', () {
      final c = ProviderContainer(overrides: [
        themeModeRepositoryProvider.overrideWithValue(_MemoryRepo()),
      ]);
      addTearDown(c.dispose);
      expect(ThemeModeRepository.defaultMode, ThemeMode.light);
      expect(c.read(themeModeProvider), ThemeMode.light);
    });

    test('저장된 값으로 복원한다', () {
      final repo = _MemoryRepo()..stored = ThemeMode.dark;
      final c = ProviderContainer(overrides: [
        themeModeRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      expect(c.read(themeModeProvider), ThemeMode.dark);
    });

    test('set은 상태를 바꾸고 저장한다 — 같은 값은 다시 쓰지 않는다', () async {
      final repo = _MemoryRepo();
      final c = ProviderContainer(overrides: [
        themeModeRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(c.read(themeModeProvider), ThemeMode.dark);
      expect(repo.stored, ThemeMode.dark);
      expect(repo.saves, 1);
      await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(repo.saves, 1);
    });
  });

  group('HiveThemeModeRepository', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('theme_mode_test');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('박스가 안 열려 있으면 기본(light), 저장은 조용히 건너뛴다', () async {
      const repo = HiveThemeModeRepository();
      expect(repo.load(), ThemeMode.light);
      await repo.save(ThemeMode.dark); // throw 없음
      expect(repo.load(), ThemeMode.light);
    });

    test('저장 → 재로드 왕복 + 손상값은 기본(light)', () async {
      final box = await Hive.openBox(HiveThemeModeRepository.boxName);
      const repo = HiveThemeModeRepository();
      await repo.save(ThemeMode.dark);
      expect(box.get(HiveThemeModeRepository.key), 'dark');
      expect(repo.load(), ThemeMode.dark);
      await repo.save(ThemeMode.system);
      expect(repo.load(), ThemeMode.system);

      await box.put(HiveThemeModeRepository.key, 'sepia');
      expect(repo.load(), ThemeMode.light);
      await box.put(HiveThemeModeRepository.key, 42);
      expect(repo.load(), ThemeMode.light);
    });
  });
}
