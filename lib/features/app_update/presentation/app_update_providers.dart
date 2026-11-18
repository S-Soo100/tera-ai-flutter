import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shared/providers/external_url_launcher.dart';
import '../data/app_release_policy_repository.dart';
import '../data/update_dismissal_store.dart';
import '../domain/app_update_state.dart';
import '../domain/update_policy.dart';

/// 설치된 앱 정보. 테스트는 덮어 쓴다.
final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppBuildInfo(
      packageName: info.packageName,
      buildNumber: info.buildNumber,
      platform: defaultTargetPlatform);
});

/// 업데이트 안내 상태(계획 §1-C·D, §2.1).
///
/// - [check]: 앱 시작 1회·[다시 확인]. 동시에 불리면 조회는 한 번. 기준을
///   읽었으면(또는 안내 대상이 아니면) true, 조회에 실패하면 false — 화면이
///   "인터넷 확인"과 "여전히 강제"를 구분한다.
/// - [checkOnResume]: 강제 상태면 매번, 아니면 마지막 성공 확인에서
///   [kUpdateRecheckInterval]이 지났을 때만.
/// - 조회 실패는 이전 상태를 그대로 둔다(강제를 실패로 풀지 않고, 오프라인에
///   새 안내를 만들지 않는다). 결과를 캐시하지 않는다(§6-3 추천).
class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier({
    required AppReleasePolicyRepository repository,
    required UpdateDismissalStore dismissals,
    required Future<AppBuildInfo> Function() readBuildInfo,
  })  : _repository = repository,
        _dismissals = dismissals,
        _readBuildInfo = readBuildInfo,
        super(const AppUpdateState());

  final AppReleasePolicyRepository _repository;
  final UpdateDismissalStore _dismissals;
  final Future<AppBuildInfo> Function() _readBuildInfo;

  AppBuildInfo? _build;
  Future<bool>? _inFlight;

  Future<bool> check() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> checkOnResume() {
    final last = state.lastCheckedAt;
    if (!state.isRequired &&
        last != null &&
        clock.now().difference(last) < kUpdateRecheckInterval) {
      return Future<void>.value();
    }
    return check();
  }

  /// 권장 창의 [나중에]를 **직접** 눌렀을 때만 부른다. 그 `latest_build`는
  /// 다시 권장하지 않는다. 강제 상태면 아무것도 바꾸지 않는다.
  Future<void> dismissRecommended() async {
    final policy = state.policy;
    if (state.status != AppUpdateStatus.recommended || policy == null) return;
    await _dismissals.save(policy.latestBuild);
    if (!mounted || state.status != AppUpdateStatus.recommended) return;
    state = state.copyWith(status: AppUpdateStatus.none);
  }

  Future<bool> _check() async {
    final build = await _buildInfo();
    if (build == null) return false;
    final platform = updatePlatformFor(
        packageName: build.packageName, platform: build.platform);
    if (platform == null) return true; // 베타 번들·그 밖의 플랫폼 — 안내 없음.
    final policy = await _repository.fetch(platform);
    if (!mounted || policy == null) return false;
    state = AppUpdateState(
        status: decideUpdate(build.buildNumber, policy, _dismissals.load()),
        policy: policy,
        lastCheckedAt: clock.now());
    return true;
  }

  Future<AppBuildInfo?> _buildInfo() async {
    if (_build case final cached?) return cached;
    try {
      return _build = await _readBuildInfo();
    } catch (e) {
      debugPrint('[app-update] build info unavailable: ${e.runtimeType}');
      return null;
    }
  }
}

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>(
        (ref) => AppUpdateNotifier(
              repository: ref.watch(appReleasePolicyRepositoryProvider),
              dismissals: ref.watch(updateDismissalStoreProvider),
              readBuildInfo: () => ref.read(appBuildInfoProvider.future),
            ));

/// 업데이트 화면의 [다시 확인]이 도는 중.
final updateRecheckingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// 업데이트 화면의 한 줄 안내(ko.json 키). 스토어 열기 실패·다시 확인해도
/// 여전히 강제일 때. 없으면 null.
final updateNoticeProvider = StateProvider.autoDispose<String?>((ref) => null);

/// 지금 정책의 스토어를 외부 앱으로 연다. 주소가 없거나 열지 못하면 false.
Future<bool> openUpdateStore(WidgetRef ref) async {
  final uri = ref.read(appUpdateProvider).policy?.storeUri;
  if (uri == null) return false;
  return ref.read(externalUrlLauncherProvider)(uri);
}
