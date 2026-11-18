import 'package:flutter/foundation.dart';

/// 업데이트 안내 강도. 계획 `docs/superpowers/plans/2026-11-16-store-update-and-push-route.md` §1·§2.1.
enum AppUpdateStatus {
  /// 안내 없음(최신·정책 없음·조회 실패·대상 아님).
  none,

  /// 권장 — 확인 창 한 번, [나중에]로 그 빌드는 다시 안 뜬다.
  recommended,

  /// 강제 — 업데이트 화면(`/update-required`)만 보인다.
  required,
}

/// 업데이트 안내를 하는 번들. iOS 베타(`com.vivanaut.beta`)는 TestFlight로만
/// 받으니 스토어 안내를 하지 않는다.
const kUpdateTargetPackage = 'com.vivanaut.app';

/// 설치된 앱 정보(`package_info_plus` + 실행 플랫폼). 테스트가 갈아 끼운다.
@immutable
class AppBuildInfo {
  const AppBuildInfo({
    required this.packageName,
    required this.buildNumber,
    required this.platform,
  });

  final String packageName;

  /// 스토어 빌드 번호(pubspec `+530`). 문자열 그대로 — 해석은 [decideUpdate].
  final String buildNumber;
  final TargetPlatform platform;
}

/// `app_release_policy` 한 줄(플랫폼별).
@immutable
class UpdatePolicy {
  const UpdatePolicy({
    required this.minBuild,
    required this.latestBuild,
    required this.latestVersion,
    required this.storeUrl,
  });

  /// 이보다 작으면 강제.
  final int minBuild;

  /// 이보다 작으면 권장.
  final int latestBuild;

  /// 표시용 버전("0.181.0"). 비면 버전 없이 안내한다.
  final String latestVersion;

  /// 스토어 주소. null·빈 값이면 그 플랫폼은 안내하지 않는다.
  final String? storeUrl;

  /// 열 수 있는 스토어 주소. 없거나 주소 모양이 아니면 null.
  Uri? get storeUri {
    final raw = storeUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  /// DB 행을 읽는다. 빌드 번호를 정수로 못 읽으면 null — 호출부는 조회 실패와
  /// 같게 다룬다(이전 상태 유지).
  static UpdatePolicy? fromJson(Map<String, Object?> json) {
    final min = _int(json['min_build']);
    final latest = _int(json['latest_build']);
    if (min == null || latest == null) return null;
    final version = json['latest_version'];
    final url = json['store_url'];
    return UpdatePolicy(
      minBuild: min,
      latestBuild: latest,
      latestVersion: version is String ? version.trim() : '',
      storeUrl: url is String ? url : null,
    );
  }

  static int? _int(Object? value) => switch (value) {
        final int v => v,
        final double v when v == v.roundToDouble() && v.isFinite => v.toInt(),
        _ => null,
      };

  @override
  bool operator ==(Object other) =>
      other is UpdatePolicy &&
      other.minBuild == minBuild &&
      other.latestBuild == latestBuild &&
      other.latestVersion == latestVersion &&
      other.storeUrl == storeUrl;

  @override
  int get hashCode =>
      Object.hash(minBuild, latestBuild, latestVersion, storeUrl);
}

/// 안내 강도를 정한다(순수 함수).
///
/// - 정책 없음·스토어 주소 없음·빌드 번호를 숫자로 못 읽음 → 안내 없음.
/// - 현재 < `min_build` → 강제([dismissedBuild] 무관).
/// - 현재 < `latest_build`이고 [dismissedBuild]가 `latest_build`가 아니면 → 권장.
AppUpdateStatus decideUpdate(
    String? currentBuild, UpdatePolicy? policy, int? dismissedBuild) {
  if (policy == null || policy.storeUri == null) return AppUpdateStatus.none;
  final current = int.tryParse(currentBuild?.trim() ?? '');
  if (current == null) return AppUpdateStatus.none;
  if (current < policy.minBuild) return AppUpdateStatus.required;
  if (current < policy.latestBuild && dismissedBuild != policy.latestBuild) {
    return AppUpdateStatus.recommended;
  }
  return AppUpdateStatus.none;
}

/// `app_release_policy.platform` 값. 안내 대상이 아니면(베타 번들·그 밖의
/// 플랫폼) null.
String? updatePlatformFor(
    {required String packageName, required TargetPlatform platform}) {
  if (packageName != kUpdateTargetPackage) return null;
  return switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
}
