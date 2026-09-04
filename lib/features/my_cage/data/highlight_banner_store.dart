import 'package:hive/hive.dart';

/// 하이라이트 도착 배너 dismiss 저장소. Widget → Provider → Repository 체인을
/// 지킨다 — 화면이 Hive를 직접 만지지 않는다(HiveThemeModeRepository 선례).
abstract class HighlightBannerStore {
  /// 마지막으로 dismiss한 그룹 key(from ISO 문자열). 없으면 null.
  String? load();

  Future<void> save(String groupKey);
}

/// Hive `app_settings` 박스의 `crecam_highlight_banner_dismissed` 키.
///
/// 박스는 `main.dart`가 앱 기동 시 연다(`openUntypedBoxSafely('app_settings')`).
/// 안 열려 있으면(테스트 등) null로 동작하고 저장은 건너뛴다 — 여기서 박스를
/// 열지 않는다(기동 순서를 이 파일이 소유하지 않는다).
class HiveHighlightBannerStore implements HighlightBannerStore {
  const HiveHighlightBannerStore();

  static const boxName = 'app_settings';
  static const key = 'crecam_highlight_banner_dismissed';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  String? load() {
    final raw = _box?.get(key);
    return raw is String ? raw : null;
  }

  @override
  Future<void> save(String groupKey) async {
    await _box?.put(key, groupKey);
  }
}
