import 'package:hive/hive.dart';

/// 하이라이트 도착 배너 dismiss 저장소. Widget → Provider → Repository 체인을
/// 지킨다 — 화면이 Hive를 직접 만지지 않는다(HiveThemeModeRepository 선례).
///
/// **계정별로 격리한다**(2026-09-07, 리뷰 잔여 A1) — 단일 키면 A 계정이
/// dismiss한 상태가 B 계정에도 적용돼, B가 자기 하이라이트 도착 배너를
/// 못 본다(Hive 즐겨찾기 계정 누출과 같은 결).
abstract class HighlightBannerStore {
  /// [ownerId] 계정이 마지막으로 dismiss한 그룹 key(ISO 문자열). 없으면 null.
  String? load(String? ownerId);

  Future<void> save(String? ownerId, String groupKey);
}

/// Hive `app_settings` 박스의 `crecam_highlight_banner_dismissed_<uid>` 키.
///
/// 박스는 `main.dart`가 앱 기동 시 연다(`openUntypedBoxSafely('app_settings')`).
/// 안 열려 있으면(테스트 등) null로 동작하고 저장은 건너뛴다 — 여기서 박스를
/// 열지 않는다(기동 순서를 이 파일이 소유하지 않는다).
///
/// 구 단일 키(`crecam_highlight_banner_dismissed`)는 읽지 않는다 — 어느 계정의
/// dismiss였는지 알 수 없어서다. 격리 도입 직후 한 번은 이미 닫았던 배너가
/// 다시 보일 수 있고, 그게 타 계정 상태를 물려받는 것보다 낫다. 저장 시
/// 구 키는 지워 잔재를 남기지 않는다.
class HiveHighlightBannerStore implements HighlightBannerStore {
  const HiveHighlightBannerStore();

  static const boxName = 'app_settings';
  static const legacyKey = 'crecam_highlight_banner_dismissed';

  static String keyFor(String? ownerId) =>
      ownerId == null ? legacyKey : '${legacyKey}_$ownerId';

  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  String? load(String? ownerId) {
    if (ownerId == null) return null; // 미로그인 — dismiss 상태 없음.
    final raw = _box?.get(keyFor(ownerId));
    return raw is String ? raw : null;
  }

  @override
  Future<void> save(String? ownerId, String groupKey) async {
    if (ownerId == null) return;
    final box = _box;
    if (box == null) return;
    await box.put(keyFor(ownerId), groupKey);
    await box.delete(legacyKey); // 구 단일 키 잔재 제거.
  }
}
