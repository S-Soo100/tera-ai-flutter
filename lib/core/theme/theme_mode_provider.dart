import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 화면 모드(시스템/라이트/다크) 저장소. Widget → Provider → Repository 체인을
/// 지킨다 — 프로필 화면이 Hive를 직접 만지지 않는다.
abstract class ThemeModeRepository {
  ThemeMode load();
  Future<void> save(ThemeMode mode);
}

/// Hive `app_settings` 박스의 `theme_mode` 키. 값은 [ThemeMode.name] 문자열.
///
/// 박스는 `main.dart`가 앱 기동 시 연다(`openUntypedBoxSafely('app_settings')`).
/// 안 열려 있으면(테스트 등) 기본값으로 동작하고 저장은 건너뛴다 — 여기서
/// 박스를 열지 않는다(기동 순서를 이 파일이 소유하지 않는다).
class HiveThemeModeRepository implements ThemeModeRepository {
  const HiveThemeModeRepository();

  static const boxName = 'app_settings';
  static const key = 'theme_mode';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  ThemeMode load() {
    final raw = _box?.get(key);
    if (raw is! String) return ThemeMode.system;
    // 알 수 없는 값(과거 버전·손상)은 시스템으로 — 던지지 않는다.
    return ThemeMode.values.cast<ThemeMode?>().firstWhere(
              (m) => m!.name == raw,
              orElse: () => null,
            ) ??
        ThemeMode.system;
  }

  @override
  Future<void> save(ThemeMode mode) async {
    await _box?.put(key, mode.name);
  }
}

final themeModeRepositoryProvider = Provider<ThemeModeRepository>(
  (_) => const HiveThemeModeRepository(),
);

/// 앱 전역 화면 모드. 기본 `system`. `app.dart`의 `themeMode:`가 watch한다.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(themeModeRepositoryProvider).load();

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(themeModeRepositoryProvider).save(mode);
  }
}
