import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma에서 내보낸 SVG 아이콘.
///
/// Material 아이콘 대용이 아니라 **디자인이 지정한 그림** 자체다. 온도계·물방울은
/// 색까지 디자인이 정한 것이라 그대로 쓰고([FigmaIcon.metric]), 차트 위 동작
/// 마커는 배경 위에 얹히므로 테마에 맞춰 색을 갈아끼운다([FigmaIcon.tinted]).
class FigmaIcon extends StatelessWidget {
  /// 파일이 가진 색을 그대로 쓴다. 온도 `#F85478`·습도 `#00B2F3`처럼 **의미가
  /// 붙은 색**은 라이트/다크가 같아야 해서 건드리지 않는다.
  const FigmaIcon.metric(this.name, {super.key, this.size = 20}) : color = null;

  /// 단색으로 칠해 쓴다. 배경 대비가 테마마다 달라지는 자리에 쓴다.
  const FigmaIcon.tinted(this.name,
      {super.key, required Color this.color, this.size = 20});

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
  // 2026-09-15 원본 → runtime 변환 이력은 redesign-asset-map.json에 보관.
  // 원형 면이 들어 있는 28/36/40px 파일은 metric으로 그린다.
  static const management = 'redesign_v2/discover_tune';
  static const memo = 'redesign_v2/sticky_note_2';
  static const edit = 'redesign_v2/edit';
  static const more = 'redesign_v2/more_vert';
  static const pause = 'final_pause';
  static const envTemperature = 'final_temperature';
  static const envHumidity = 'final_humidity';
  static const close = 'close';
  static const cancel = 'redesign_v2/cancel';

  /// 44 프레임 export(글리프 17×19 가운데) — 예약 목록 휴지통(Figma 1106:5317).
  static const trash = 'redesign_v2/delete';

  /// 플레이어 가로 축소(36) — 세로의 [expand](zoom_out_map)와 짝(Figma 941:1928).
  static const zoomInMap = 'redesign_v2/zoom_in_map';

  /// ±10초 피드백 칩 글리프 26(Figma 941:1928 Toast_V). 되감기는 좌우 반전.
  static const fastForward = 'redesign_v2/fast_forward';
  static const arrowPrevious = 'arrow_previous';
  static const arrowNext = 'arrow_next';
  static const download = 'download';
  static const share = 'share';
  static const bookmark = 'bookmark';
  static const delete = 'delete';
  static const play = 'play';
  static const speed2x = 'speed_2x';
  static const expand = 'expand';
  static const calendar = 'calendar';
  static const bookmarkBadge = 'bookmark_badge';
  static const dropdown = 'dropdown';
  static const add = 'add';
  static const person = 'person';
  static const liveExpand = 'live_expand';
  static const fanOn = 'fan_on';
  static const fanOff = 'fan_off';
  static const mistOn = 'mist_on';
  static const mistOff = 'mist_off';
  static const coolOn = 'cool_on';
  static const coolOff = 'cool_off';
  static const ledOn = 'led_on';
  static const ledOff = 'led_off';

  // 기록 36px / 차트 28px 전용 export. 40px 홈 아이콘을 축소하지 않는다.
  static String fanBadge({required bool on, required bool compact}) =>
      'redesign_v2/${compact ? '2828' : '3636'}/${on ? 'mode_fan_2' : 'mode_fan_off'}';
  static String coolingBadge({required bool on, required bool compact}) =>
      'redesign_v2/${compact ? '2828' : '3636'}/${on ? 'mode_cool' : 'mode_cool_off'}';
  static String ledBadge({required bool on, required bool compact}) =>
      'redesign_v2/${compact ? '2828' : '3636'}/${on ? 'lightbulb' : 'light_off'}';
  static String mistBadge({required bool compact}) =>
      'redesign_v2/${compact ? '2828' : '3636'}/humidity_high';

  static const thermometer = 'thermometer';
  static const waterDrop = 'water_drop';
  static const shower = 'shower';
  static const modeFan = 'mode_fan_2';
  // 카메라 탭 엔트리 카드(2026-09-07 Figma 대조 — Material 근사치 교체).
  static const cardsStar = 'redesign_v2/cards_star';
  static const bookmarkCheck = 'redesign_v2/bookmark_check';
  // 홈 제어 타일(2026-09-07 재대조 — Material 근사치 교체). 배경 원은
  // 타일이 그리므로 export의 rect는 제거하고 글리프만 담았다. viewBox가
  // 제각각(분무 40 패딩 포함 / 냉각 28 패딩 포함 / 팬 20 글리프만)이라
  // 소비처가 크기를 달리 준다 — cage_control_grid 참조.
  static const formatColorReset = 'format_color_reset';
  static const modeCool = 'mode_cool';
  // 분무 켜짐 글리프(2026-09-08 사용자 지시) — 글리프만 17×20.
  static const humidityHigh = 'humidity_high';
}

/// 사용자가 제공한 PNG의 x3 배율. 파일 이름의 x3만으로 배율이 적용되지 않는다.
/// Empty 원본 1035×681 → 345×227, favicon 168×168 → 56×56.
abstract final class FigmaImages {
  static const emptyCamera = ExactAssetImage(
    'assets/figma/2026-09-15/images/Empty_02x3.png',
    scale: 3,
  );
  static const emptyPet = ExactAssetImage(
    'assets/figma/2026-09-15/images/Empty_01x3.png',
    scale: 3,
  );
  static const emptyEnclosure = ExactAssetImage(
    'assets/figma/2026-09-15/images/Empty_03x3.png',
    scale: 3,
  );
  static const petPlaceholder = ExactAssetImage(
    'assets/figma/2026-09-15/images/favicon_viva_50x3.png',
    scale: 3,
  );
}
