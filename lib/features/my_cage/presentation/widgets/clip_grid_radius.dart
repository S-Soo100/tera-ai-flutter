import 'package:flutter/widgets.dart';

/// 3열 클립 그리드의 셀별 모서리 반경 — **노출된 바깥 모서리만 둥글린다**
/// (2026-09-04 사용자 지시: 클립이 1개뿐이면 네 모서리 전부, 여럿이면
/// 실루엣의 바깥 모서리만).
///
/// 구 방식(그룹 전체 ClipRRect)은 마지막 행이 3칸을 못 채우면 외톨이 셀의
/// 오른쪽 모서리가 그룹 라운드 영역 밖이라 각지게 남았다.
///
/// 규칙: 모서리에 맞닿은 가로·세로 이웃 셀이 **둘 다 없을 때만** 둥글린다 —
/// 한쪽이라도 있으면 그 변이 이웃과 이어져 있어(갭 2뿐) 둥글리면 틈이 생긴다.
/// [rowCounts]는 행별 채워진 셀 수(왼쪽부터 채움 전제 — 그룹핑이 보장).
BorderRadius clipGridCellRadius({
  required int row,
  required int col,
  required List<int> rowCounts,
  double radius = 12,
}) {
  bool has(int r, int c) =>
      r >= 0 && r < rowCounts.length && c >= 0 && c < rowCounts[r];

  final left = has(row, col - 1);
  final right = has(row, col + 1);
  final above = has(row - 1, col);
  final below = has(row + 1, col);
  final r0 = Radius.circular(radius);

  return BorderRadius.only(
    topLeft: !left && !above ? r0 : Radius.zero,
    topRight: !right && !above ? r0 : Radius.zero,
    bottomLeft: !left && !below ? r0 : Radius.zero,
    bottomRight: !right && !below ? r0 : Radius.zero,
  );
}
