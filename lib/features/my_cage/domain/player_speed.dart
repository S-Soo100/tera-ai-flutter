/// 재생 배속 단계 — Figma 아이콘 시트(1X / 1.2X / 1.5X / 2X)를 그대로 따른다.
///
/// 누를 때마다 다음 단계로 가고 끝에서 처음으로 돌아온다. 2026-09-21 이전에는
/// 1×↔2× 둘뿐이었고 1×는 아이콘이 아니라 글자로 그렸다.
const List<double> kPlayerSpeeds = [1.0, 1.2, 1.5, 2.0];

/// [current] 다음 단계. 목록에 없는 값(옛 상태)이면 처음으로 돌린다.
double nextPlayerSpeed(double current) {
  final index = kPlayerSpeeds.indexWhere((s) => (s - current).abs() < 0.001);
  if (index < 0) return kPlayerSpeeds.first;
  return kPlayerSpeeds[(index + 1) % kPlayerSpeeds.length];
}
