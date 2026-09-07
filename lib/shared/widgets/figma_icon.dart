import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma에서 내보낸 SVG 아이콘.
///
/// Material 아이콘 대용이 아니라 **디자인이 지정한 그림** 자체다. 온도계·물방울은
/// 색까지 디자인이 정한 것이라 그대로 쓰고([FigmaIcon.metric]), 차트 위 동작
/// 마커는 배경 위에 얹히므로 테마에 맞춰 색을 갈아끼운다([FigmaIcon.tinted]).
class FigmaIcon extends StatelessWidget {
  /// 파일이 가진 색을 그대로 쓴다. 온도 `#ff3752`·습도 `#68a7f6`처럼 **의미가
  /// 붙은 색**은 라이트/다크가 같아야 해서 건드리지 않는다.
  const FigmaIcon.metric(this.name, {super.key, this.size = 20}) : color = null;

  /// 단색으로 칠해 쓴다. 배경 대비가 테마마다 달라지는 자리에 쓴다.
  const FigmaIcon.tinted(this.name, {super.key, required Color this.color, this.size = 20});

  /// `assets/icons/{name}.svg`의 파일명(확장자 제외).
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

/// Figma 아이콘 파일명. 오타로 빈 자리가 나지 않게 상수로 묶는다.
abstract final class FigmaIcons {
  static const thermometer = 'thermometer';
  static const waterDrop = 'water_drop';
  static const shower = 'shower';
  static const modeFan = 'mode_fan_2';
}
