import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';

/// 애플 날씨 10일 예보의 **온도 범위 바**.
///
/// 트랙(이번 주 전체 폭)은 어두운 회색, 채움(그날 최저~최고)은 노랑→주황
/// 그라데이션. [dot]이 있으면(오늘 행) 그 위치에 흰 점을 얹는다 — "지금 몇 도"가
/// 그날 범위 안 어디쯤인지 한눈에 읽힌다.
///
/// 값은 전부 0~1 정규화다. 정규화는 도메인([WeeklyEnvRows.positionOf])이 하고
/// 여기는 그리기만 한다 — 위젯이 온도를 알면 축 계산이 두 벌이 된다.
class TempRangeBar extends StatelessWidget {
  const TempRangeBar({
    super.key,
    required this.start,
    required this.end,
    this.dot,
    this.height = barHeight,
  });

  /// 채움 시작(최저)·끝(최고), 0~1. 둘 다 null이면 트랙만 그린다.
  final double? start;
  final double? end;

  /// 현재 온도 점 위치(0~1). 오늘 행만 준다.
  final double? dot;

  final double height;

  /// 바 두께. 애플은 ~6pt.
  static const double barHeight = 6;

  /// 점 반지름·테두리.
  static const double dotRadius = 5;
  static const double dotBorder = 2;

  @override
  Widget build(BuildContext context) {
    // 점이 바보다 크므로 세로 여유를 점 지름만큼 준다 — 안 주면 위아래가 잘린다.
    return SizedBox(
      height: (dotRadius + dotBorder) * 2,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TempRangeBarPainter(
          start: start,
          end: end,
          dot: dot,
          height: height,
          glass: context.glass,
        ),
      ),
    );
  }
}

class _TempRangeBarPainter extends CustomPainter {
  const _TempRangeBarPainter({
    required this.start,
    required this.end,
    required this.dot,
    required this.height,
    required this.glass,
  });

  final double? start;
  final double? end;
  final double? dot;
  final double height;

  /// 색은 팔레트에서 — 페인터는 context가 없어 위젯이 넘겨준다.
  final GlassPalette glass;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = Radius.circular(height / 2);
    final track =
        RRect.fromLTRBR(0, cy - height / 2, size.width, cy + height / 2, r);
    canvas.drawRRect(track, Paint()..color = glass.weatherBarTrack);

    final s = start;
    final e = end;
    if (s != null && e != null) {
      // 최저=최고인 날도 점 하나만큼은 보여야 "값이 있었다"가 읽힌다.
      var left = (s * size.width).clamp(0.0, size.width);
      var right = (e * size.width).clamp(0.0, size.width);
      if (right - left < height) {
        // 폭이 두께보다 좁으면 두께만큼 벌리되 트랙 밖으로 나가지 않는다.
        right = (left + height).clamp(0.0, size.width);
        left = right - height < 0 ? 0.0 : right - height;
      }
      final fill =
          RRect.fromLTRBR(left, cy - height / 2, right, cy + height / 2, r);
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            colors: [glass.weatherBarWarmStart, glass.weatherBarWarmEnd],
          ).createShader(fill.outerRect),
      );
    }

    final d = dot;
    if (d != null) {
      final cx = (d * size.width).clamp(0.0, size.width);
      canvas.drawCircle(
        Offset(cx, cy),
        TempRangeBar.dotRadius + TempRangeBar.dotBorder,
        Paint()..color = glass.weatherDotBorder,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        TempRangeBar.dotRadius,
        Paint()..color = glass.weatherDot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TempRangeBarPainter old) =>
      old.start != start ||
      old.end != end ||
      old.dot != dot ||
      old.height != height ||
      old.glass != glass;
}
