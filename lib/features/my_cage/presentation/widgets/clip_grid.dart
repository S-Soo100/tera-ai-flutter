import 'package:flutter/material.dart';

import 'clip_grid_radius.dart';

/// 3열 클립 그리드 스캐폴드 — Figma 셀 121.67:113·갭 2, 셀별 노출 모서리
/// 라운드([clipGridCellRadius]).
///
/// 행 분할·빈 칸·모서리 계산이 Camera Home과 하이라이트 상세에 복붙 2벌로
/// 있어 한쪽만 고치면 실루엣이 조용히 갈렸다(리뷰 2026-09-04). 호출자는
/// [cellBuilder]만 다르다. "왼쪽부터 채움" 전제도 여기 한 곳이 보장한다.
class ClipGrid<T> extends StatelessWidget {
  const ClipGrid({
    super.key,
    required this.items,
    required this.cellBuilder,
  });

  final List<T> items;
  final Widget Function(T item) cellBuilder;

  static const int columns = 3;

  /// Figma 셀 실측 121.67×113.
  static const double cellAspect = 121.67 / 113;
  static const double cellGap = 2;

  @override
  Widget build(BuildContext context) {
    final rowCount = (items.length + columns - 1) ~/ columns;
    return Column(
      children: [
        for (var r = 0; r < rowCount; r++) ...[
          if (r > 0) const SizedBox(height: cellGap),
          Row(
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: cellGap),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: cellAspect,
                    child: r * columns + c >= items.length
                        ? const SizedBox.shrink()
                        : ClipRRect(
                            borderRadius: clipGridCellRadius(
                              row: r,
                              col: c,
                              total: items.length,
                            ),
                            child: cellBuilder(items[r * columns + c]),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
