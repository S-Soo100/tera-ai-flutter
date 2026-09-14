import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import 'motion_clip_thumb.dart';

/// Apple Photos처럼 화면 중앙을 현재 항목으로 사용하는 영상 필름스트립.
///
/// 스크롤 중에는 중앙 후보만 바꾸고, 스크롤이 끝났을 때만 [onSettled]로
/// 실제 영상을 전환한다. 현재 후보는 고정된 중앙 선택창에 크게 그리므로
/// 썸네일 폭이 바뀌어도 스크롤 간격과 스냅 위치는 흔들리지 않는다.
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

  static const double itemExtent = 30;
  static const double height = 48;
  static const double normalWidth = 28;
  static const double normalHeight = 40;
  static const double selectedWidth = 40;

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
                      child: Center(
                        child: index == selected
                            ? const SizedBox(
                                width: normalWidth,
                                height: normalHeight,
                              )
                            : Opacity(
                                opacity: 0.68,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
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
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: Center(
                      child: Container(
                        width: selectedWidth,
                        height: height,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: glass.surfaceHeader,
                            width: 2,
                          ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
