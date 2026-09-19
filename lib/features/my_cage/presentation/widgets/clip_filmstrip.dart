import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import 'motion_clip_thumb.dart';

/// Apple Photos처럼 화면 중앙을 현재 항목으로 사용하는 영상 필름스트립.
///
/// 스크롤 중에는 중앙 후보만 바꾸고, 스크롤이 끝났을 때만 [onSettled]로
/// 실제 영상을 전환한다. 현재 후보는 고정된 중앙 선택창에 크게 그리므로
/// 썸네일 폭이 바뀌어도 스크롤 간격과 스냅 위치는 흔들리지 않는다.
///
/// 치수(Figma 941:1834 / 1928 실측): 썸네일 40×40 r4, 간격 4(항목 44),
/// 현재 항목 54×40 r3, 현재 양옆 간격 12(이웃을 15씩 바깥으로 밀어 만든다),
/// 양 끝 80pt 배경색 그라데이션.
class ClipFilmstrip extends StatelessWidget {
  const ClipFilmstrip({
    super.key,
    required this.listKey,
    required this.controller,
    required this.clipIds,
    required this.cameraId,
    required this.previewIndex,
    required this.onPreviewChanged,
    required this.onSettled,
    required this.onSelected,
  });

  static const double itemExtent = 44;
  static const double height = 48;
  static const double normalWidth = 40;
  static const double normalHeight = 40;
  static const double selectedWidth = 54;
  static const double selectedHeight = 40;

  /// 현재 항목 양옆 간격 12: 이웃 기본 간격 4에서 현재 항목 반폭 차이
  /// (54-40)/2 = 7과 추가 8을 더해 15를 바깥으로 민다.
  static const double neighborSpread = 15;
  static const double edgeFade = 80;

  final Key listKey;
  final ScrollController controller;
  final List<String> clipIds;
  final String cameraId;
  final int previewIndex;
  final ValueChanged<int> onPreviewChanged;
  final ValueChanged<int> onSettled;
  final ValueChanged<int> onSelected;

  static double offsetForIndex(int index) => index * itemExtent;

  int _indexAt(ScrollMetrics metrics) =>
      (metrics.pixels / itemExtent).round().clamp(0, clipIds.length - 1);

  /// 중앙에서 [index]가 떨어진 거리(항목 단위, 부호 있음). 스크롤 중에는
  /// 연속값이라 이웃이 부드럽게 벌어졌다 모인다.
  double _distance(int index, int selected) {
    // 회전 중 한 프레임은 세로·가로 리스트가 같은 컨트롤러에 동시에 붙는다
    // — 그때 offset을 읽으면 단정이 터지므로 마지막 위치를 쓴다.
    final positions = controller.positions;
    final offset =
        positions.isEmpty ? offsetForIndex(selected) : positions.last.pixels;
    return (offsetForIndex(index) - offset) / itemExtent;
  }

  @override
  Widget build(BuildContext context) {
    final selected = previewIndex.clamp(0, clipIds.length - 1);
    final glass = context.glass;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideInset =
              math.max(0.0, (constraints.maxWidth - itemExtent) / 2);
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.horizontal) return false;
              final candidate = _indexAt(notification.metrics);
              if (notification is ScrollUpdateNotification &&
                  candidate != previewIndex) {
                onPreviewChanged(candidate);
              } else if (notification is ScrollEndNotification) {
                onSettled(candidate);
              }
              return false;
            },
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                ListView.builder(
                  key: listKey,
                  controller: controller,
                  padding: EdgeInsets.symmetric(horizontal: sideInset),
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemExtent: itemExtent,
                  itemCount: clipIds.length,
                  itemBuilder: (context, index) => Semantics(
                    button: true,
                    selected: index == selected,
                    label: '${index + 1} / ${clipIds.length}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(index),
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          final d = _distance(index, selected);
                          final spread =
                              d.abs().clamp(0.0, 1.0) * neighborSpread * d.sign;
                          return Transform.translate(
                              offset: Offset(spread, 0), child: child);
                        },
                        child: Center(
                          child: index == selected
                              ? const SizedBox(
                                  width: normalWidth,
                                  height: normalHeight,
                                )
                              : Opacity(
                                  opacity: 0.68,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      width: normalWidth,
                                      height: normalHeight,
                                      child: MotionClipThumb(
                                        clipId: clipIds[index],
                                        cameraId: cameraId,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: Center(
                      child: Container(
                        width: selectedWidth,
                        height: selectedHeight,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: MotionClipThumb(
                          key: ValueKey(clipIds[selected]),
                          clipId: clipIds[selected],
                          cameraId: cameraId,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final left in [true, false])
                  Positioned(
                    left: left ? 0 : null,
                    right: left ? null : 0,
                    top: 0,
                    bottom: 0,
                    width: math.min(edgeFade, constraints.maxWidth / 2),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: left
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            end: left
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            colors: [
                              glass.wallpaper,
                              glass.wallpaper.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
