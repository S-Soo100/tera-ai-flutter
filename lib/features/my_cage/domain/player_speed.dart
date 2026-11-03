/// 재생 배속 단계 — Figma "배속 버튼 수정 261103"(1689:5771)의 1x/2x/3x/4x.
///
/// 누를 때마다 다음 단계로 가고 끝에서 처음으로 돌아온다(2x → 3x → 4x → 1x).
/// 2026-11-03 이전에는 1X/1.2X/1.5X/2X였다.
const List<double> kPlayerSpeeds = [1.0, 2.0, 3.0, 4.0];

/// 저장된 배속이 없을 때의 배속(Figma 메모 "디폴트 값: 2x").
const double kDefaultPlayerSpeed = 2.0;

/// [current] 다음 단계. 목록에 없는 값(옛 1.2·1.5 등)이면 기본 배속.
double nextPlayerSpeed(double current) {
  final index = kPlayerSpeeds.indexWhere((s) => (s - current).abs() < 0.001);
  if (index < 0) return kDefaultPlayerSpeed;
  return kPlayerSpeeds[(index + 1) % kPlayerSpeeds.length];
}

/// 저장소에서 읽은 값을 단계 하나로. 숫자가 아니거나 목록 밖(옛 1.2·1.5)이면
/// 기본 배속 — 예전에 1X·2X를 고른 사람만 그 값이 이어진다(2026-11-03 사용자 결정).
double normalizePlayerSpeed(Object? raw) {
  if (raw is! num) return kDefaultPlayerSpeed;
  return kPlayerSpeeds.firstWhere((s) => (s - raw).abs() < 0.001,
      orElse: () => kDefaultPlayerSpeed);
}
