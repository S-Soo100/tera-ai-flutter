import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';

/// Microsoft Clarity 프로젝트 ID (대시보드 Settings 페이지 값).
/// 비밀이 아니다 — 앱 바이너리에 그대로 들어가는 공개 식별자라 `.env`가 아니라
/// 코드 상수로 둔다.
const String kClarityProjectId = 'ygr536qm34';

/// 앱 진입점(`main.dart`)의 `ClarityWidget`에 넘기는 설정.
///
/// - 디버그 빌드: `Verbose` — 초기화 실패를 콘솔에서 바로 볼 수 있게.
/// - 릴리즈 빌드: `None` — SDK도 릴리즈에선 강제로 None이지만 의도를 명시.
///
/// 마스킹 모드(전체 텍스트 마스킹 등)는 코드가 아니라 Clarity 대시보드에서
/// 정한다. 개별 위젯은 `ClarityMask`/`ClarityUnmask`로 덮어쓴다.
ClarityConfig buildClarityConfig() {
  return ClarityConfig(
    projectId: kClarityProjectId,
    logLevel: kDebugMode ? LogLevel.Verbose : LogLevel.None,
  );
}
