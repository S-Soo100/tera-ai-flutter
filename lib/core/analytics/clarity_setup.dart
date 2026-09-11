import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';

/// Microsoft Clarity 프로젝트 ID (대시보드 Settings 페이지 값).
/// 비밀이 아니다 — 앱 바이너리에 그대로 들어가는 공개 식별자라 `.env`가 아니라
/// 코드 상수로 둔다.
const String kClarityProjectId = 'ygr536qm34';

/// 동의와 수집 가능 화면을 확인한 뒤 SDK adapter가 사용하는 설정.
///
/// - 디버그 빌드: `Verbose` — 초기화 실패를 콘솔에서 바로 볼 수 있게.
/// - 릴리즈 빌드: `None` — SDK도 릴리즈에선 강제로 None이지만 의도를 명시.
///
/// 앱의 영구 root `ClarityMask`가 대시보드 설정보다 우선한다.
ClarityConfig buildClarityConfig({String projectId = kClarityProjectId}) {
  return ClarityConfig(
    projectId: projectId,
    logLevel: kDebugMode ? LogLevel.Verbose : LogLevel.None,
  );
}

/// Deployment approval and account consent are independent switches.
class ClarityRuntimeConfig {
  const ClarityRuntimeConfig(
      {this.enabled = false,
      this.mobile = false,
      this.release = false,
      this.projectId = ''});

  final bool enabled;
  final bool mobile;
  final bool release;
  final String projectId;

  String get resolvedProjectId =>
      projectId.isEmpty && release ? kClarityProjectId : projectId;
  String get environmentName =>
      resolvedProjectId == kClarityProjectId ? 'production' : 'qa';
  bool get canCollect =>
      enabled &&
      mobile &&
      RegExp(r'^[a-zA-Z0-9]+$').hasMatch(resolvedProjectId) &&
      (release || resolvedProjectId != kClarityProjectId);

  static ClarityRuntimeConfig get environment => ClarityRuntimeConfig(
        enabled: const bool.fromEnvironment('CLARITY_ENABLED'),
        mobile: !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS),
        release: kReleaseMode,
        projectId: const String.fromEnvironment('CLARITY_PROJECT_ID'),
      );
}
