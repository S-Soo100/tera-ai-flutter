import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/clip_grid_radius.dart';

/// 3열 클립 그리드 셀별 모서리 규칙(2026-09-04 사용자 지시) —
/// 노출된 바깥 모서리만 둥글린다. 이웃이 있는 변의 모서리를 둥글리면
/// 갭 2 너머 이웃과의 사이에 틈이 생긴다. 배치는 왼쪽부터 채움([ClipGrid]).
void main() {
  const r = Radius.circular(12);
  const z = Radius.zero;

  BorderRadius at(int row, int col, int total) =>
      clipGridCellRadius(row: row, col: col, total: total);

  test('클립 1개 — 네 모서리 전부 라운드', () {
    expect(
      at(0, 0, 1),
      const BorderRadius.only(
          topLeft: r, topRight: r, bottomLeft: r, bottomRight: r),
    );
  });

  test('한 행 3개 — 양 끝 셀만 바깥쪽 라운드, 가운데는 전부 각', () {
    expect(
      at(0, 0, 3),
      const BorderRadius.only(topLeft: r, bottomLeft: r),
    );
    expect(at(0, 1, 3), BorderRadius.zero);
    expect(
      at(0, 2, 3),
      const BorderRadius.only(topRight: r, bottomRight: r),
    );
  });

  test('한 행 2개 — 왼쪽 셀 좌측, 오른쪽 셀 우측 라운드', () {
    expect(
      at(0, 0, 2),
      const BorderRadius.only(topLeft: r, bottomLeft: r),
    );
    expect(
      at(0, 1, 2),
      const BorderRadius.only(topRight: r, bottomRight: r),
    );
  });

  test('3+1 — 외톨이 셀은 아래 양쪽만, 위는 윗행과 이어져 각', () {
    // 윗행 끝 셀: 아래가 비어 bottomRight도 라운드(실루엣 바깥).
    expect(
      at(0, 2, 4),
      const BorderRadius.only(topRight: r, bottomRight: r),
    );
    // 윗행 가운데 셀: 아래가 비지만 좌우 이웃이 있어 아래 모서리도 각.
    expect(at(0, 1, 4), BorderRadius.zero);
    // 외톨이 셀(둘째 행): 위에 셀이 있어 위 모서리는 각, 아래 양쪽 라운드.
    expect(
      at(1, 0, 4),
      const BorderRadius.only(
          topLeft: z, topRight: z, bottomLeft: r, bottomRight: r),
    );
  });

  test('3+2 — 둘째 행 끝(col1) 셀은 오른쪽 위·아래 모두 라운드', () {
    expect(
      at(1, 1, 5),
      const BorderRadius.only(topRight: z, bottomLeft: z, bottomRight: r),
    );
    // col2는 비어 있으므로 윗행 끝 셀 bottomRight가 노출 라운드.
    expect(
      at(0, 2, 5),
      const BorderRadius.only(topRight: r, bottomRight: r),
    );
  });

  test('3+3 꽉 찬 두 행 — 네 귀퉁이 셀만 해당 귀퉁이 라운드', () {
    expect(at(0, 0, 6), const BorderRadius.only(topLeft: r));
    expect(at(0, 2, 6), const BorderRadius.only(topRight: r));
    expect(at(1, 0, 6), const BorderRadius.only(bottomLeft: r));
    expect(at(1, 2, 6), const BorderRadius.only(bottomRight: r));
    expect(at(0, 1, 6), BorderRadius.zero);
    expect(at(1, 1, 6), BorderRadius.zero);
  });
}
