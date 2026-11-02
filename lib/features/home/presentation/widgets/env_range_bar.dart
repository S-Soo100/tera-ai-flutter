import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/viva_colors.dart';
import '../../../../shared/domain/env_thresholds.dart';
import '../../../../shared/domain/num_format.dart';
import '../../../../shared/widgets/figma_icon.dart';

/// 범위 바 종류 — 전체 바 눈금이 지표마다 고정이다(Figma A04 "전체바").
enum EnvBarKind {
  /// 온도 12~30℃.
  temp(12, 30),

  /// 습도 20~100%.
  humid(20, 100);

  const EnvBarKind(this.scaleMin, this.scaleMax);

  final double scaleMin;
  final double scaleMax;

  /// 전체 바 위 비율(0~1). 바 밖의 값은 끝으로 붙인다(A04 "바 밖의 영역").
  double fractionOf(double v) =>
      ((v - scaleMin) / (scaleMax - scaleMin)).clamp(0.0, 1.0);
}

/// 온습도 상세 맨 위의 한 줄 — `22.0℃ 15 ━━●━━ 26` (Figma A04·A06, 1610:6588).
///
/// - 왼쪽 [value]: 오늘은 현재값, 지난 날은 하루 평균. **NN.N**(소수 0이어도 표시).
/// - 바 양옆 [low]·[high]: 그날 최저·최고. **버림**한 정수(반올림 아님, A04 4-b).
/// - 바: [EnvBarKind] 고정 눈금 위에 적정 구간([range])을 같은 비율 자리에 둔다.
///   원은 [value] 위치, 바 밖이면 끝에 고정. 적정 구간 눈금은 [formatCompact].
///
/// 값만 받는다 — provider를 읽지 않는다(화면이 오늘/지난 날 출처를 고른다).
/// [range]가 null(설정 조회 중 실패·기기 없음)이면 적정 구간과 눈금을 그리지
/// 않는다 — 기본값을 대신 그리면 사용자가 바꾼 범위를 잘못 보여 준다.
class EnvRangeBar extends StatelessWidget {
  const EnvRangeBar({
    super.key,
    required this.kind,
    required this.value,
    required this.low,
    required this.high,
    required this.range,
    this.dim = 1,
  });

  final EnvBarKind kind;
  final double? value;
  final double? low;
  final double? high;
  final EnvRange? range;

  /// 현재값 신선도 흐림(1 = 그대로). 값 글자와 원에 적용한다.
  final double dim;

  static const trackKey = Key('env_range_bar_track');
  static const markerKey = Key('env_range_bar_marker');
  static const bandKey = Key('env_range_bar_band');

  /// Figma A04 수치(393 프레임).
  static const double rowHeight = 29;
  static const double _leftWidth = 110;
  static const double _leftGap = 16;
  static const double _sideWidth = 30;
  static const double _sideGap = 8;
  static const double _trackTop = 8;
  static const double _trackHeight = 12;
  static const double _markerSize = 12;
  static const double _tickTop = 20;
  static const double _tickWidth = 40;

  /// 전체 바 그라데이션 끝색 위치 — Figma GRADIENT_LINEAR가 바보다 길게 걸려
  /// 바 오른쪽 끝이 accent의 일부만큼만 진하다(A06 렌더 픽셀 실측: 온도 0.52,
  /// 습도 0.62).
  static double _gradientEnd(EnvBarKind kind) =>
      kind == EnvBarKind.temp ? 0.52 : 0.62;

  static String formatValue(EnvBarKind kind, double v) =>
      (kind == EnvBarKind.temp ? 'home_live_temp_value' : 'home_live_humid_value')
          .tr(args: [v.toStringAsFixed(1)]);

  /// 버림 — 15.9 → "15". 부동소수 오차(15.999999)로 한 칸 내려가지 않게
  /// 아주 작은 여유를 둔다.
  static String formatEdge(double v) => '${(v + 1e-9).floor()}';

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final temp = kind == EnvBarKind.temp;
    final valueColor =
        (temp ? VivaColors.mainDark : VivaColors.subDark).withValues(alpha: dim);
    final accent = temp ? glass.tempAccent : glass.humidAccent;

    TextStyle big(Color color, FontWeight weight) => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 24,
          height: 28.640625 / 24,
          fontWeight: weight,
          letterSpacing: 24 * -0.02,
          color: color,
        );

    Widget side(double? v, Color color, Key key) => SizedBox(
          width: _sideWidth,
          height: rowHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(v == null ? '--' : formatEdge(v),
                key: key, maxLines: 1, style: big(color, FontWeight.w500)),
          ),
        );

    final v = value;
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _leftWidth,
            child: Row(
              children: [
                FigmaIcon.metric(
                    temp
                        ? 'redesign_v2/env_temperature'
                        : 'redesign_v2/env_humidity',
                    size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      v == null ? '--' : formatValue(kind, v),
                      key: Key('env_range_bar_value_${kind.name}'),
                      maxLines: 1,
                      style: big(valueColor, FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _leftGap),
          side(low, glass.textTertiary, Key('env_range_bar_low_${kind.name}')),
          const SizedBox(width: _sideGap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => _track(
                glass: glass,
                width: c.maxWidth,
                accent: accent,
              ),
            ),
          ),
          const SizedBox(width: _sideGap),
          side(high, glass.textSecondary,
              Key('env_range_bar_high_${kind.name}')),
        ],
      ),
    );
  }

  Widget _track({
    required GlassPalette glass,
    required double width,
    required Color accent,
  }) {
    final r = range;
    final v = value;
    final start = glass.envBarMinimum;
    final end = Color.lerp(start, accent, _gradientEnd(kind)) ?? accent;
    final tickStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 10,
      height: 11.93359375 / 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 10 * -0.02,
      color: glass.deviceOff,
    );

    Widget tick(double at, String label) => Positioned(
          top: _tickTop,
          left: kind.fractionOf(at) * width - _tickWidth / 2,
          width: _tickWidth,
          child: Text(label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              style: tickStyle),
        );

    final bandLeft = r == null ? 0.0 : kind.fractionOf(r.min) * width;
    final bandRight = r == null ? 0.0 : kind.fractionOf(r.max) * width;

    return SizedBox(
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: trackKey,
            top: _trackTop,
            left: 0,
            right: 0,
            height: _trackHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [start, end]),
                      ),
                    ),
                  ),
                  if (r != null)
                    Positioned(
                      key: bandKey,
                      top: 0,
                      bottom: 0,
                      left: bandLeft,
                      width: bandRight - bandLeft,
                      // Figma `#F4F4F4` 면이 그라데이션 위에 60%로 얹혀 있다
                      // (A06 픽셀 실측) — 적정 구간이 밝게 빠져 보인다.
                      child: ColoredBox(
                          color: glass.overlay.withValues(alpha: 0.6)),
                    ),
                ],
              ),
            ),
          ),
          if (r != null) ...[
            tick(r.min, formatCompact(r.min)),
            tick(r.max, formatCompact(r.max)),
          ],
          if (v != null)
            Positioned(
              key: markerKey,
              top: _trackTop,
              // 원은 바 안에 머문다 — 0이면 왼쪽 끝, 1이면 오른쪽 끝에 붙는다.
              left: kind.fractionOf(v) * (width - _markerSize),
              width: _markerSize,
              height: _markerSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: dim),
                  border: Border.all(color: glass.appBar),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
