/// 신규 기기 기본 이름 — `<접두> 1`, `<접두> 2`…
///
/// 확정 기획(2026-09-15 재설계 §7): 첫 항목부터 번호 1을 포함하고, 이미 쓰는
/// 이름은 건너뛴다. 동시 등록 중복 방지는 서버 몫이고(요청 중), 앱은 등록
/// 시점에 아는 목록 기준으로만 고른다.
String nextDefaultDeviceName(String prefix, Iterable<String?> existingNames) {
  final used = existingNames.whereType<String>().map((n) => n.trim()).toSet();
  var n = 1;
  while (used.contains('$prefix $n')) {
    n++;
  }
  return '$prefix $n';
}
