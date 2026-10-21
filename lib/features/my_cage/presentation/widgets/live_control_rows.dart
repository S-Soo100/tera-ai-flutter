import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import 'management_widgets.dart';

/// 세로 확대 화면 제어 목록(Figma 1523:5049) 공용 조각.
///
/// 줄 높이 40, 왼쪽 36 원(#3C3C3C) 안 흰 24 글리프 → 12 → 제목 16/600
/// #1E1E1E + 4 + 부제 14/500 #949090, 오른쪽 컨트롤. 못 쓰는 상태(오프라인·
/// 영상 없음)면 원과 제목이 #949090으로 흐려진다.
class LiveControlRow extends StatelessWidget {
  const LiveControlRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.dimmed = false,
    this.subtitleKey,
  });

  /// 원 안에 그릴 흰 글리프(24 프레임).
  final Widget Function(Color color) icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool dimmed;
  final Key? subtitleKey;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    // 높이 40은 최소 — 휴대폰 글자를 키우면 제목·부제만큼 늘어난다.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: dimmed ? glass.textTertiary : glass.textSecondary,
              shape: BoxShape.circle),
          child: icon(glass.buttonForeground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: managementStyle(context,
                        weight: FontWeight.w600,
                        color:
                            dimmed ? glass.textTertiary : glass.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    key: subtitleKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: managementStyle(context,
                            size: 14, color: glass.textTertiary)
                        .copyWith(fontFeatures: const [
                      FontFeature.tabularFigures()
                    ])),
              ]),
        ),
        const SizedBox(width: 12),
        trailing,
      ]),
    );
  }
}

/// Figma에서 SVG를 못 받아 4배 PNG로 보관한 글리프(`assets/icons/redesign_v2/png/`,
/// 흰색+알파). [color]가 null이면 원본 색 그대로(빨간 정지 원).
class LiveRasterIcon extends StatelessWidget {
  const LiveRasterIcon(this.name, {super.key, this.size = 24, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icons/redesign_v2/png/$name.png',
          width: size,
          height: size,
          color: color,
          filterQuality: FilterQuality.medium);
}

/// 전원 글리프 — export가 그림 크기로 잘려 있어 20 프레임 안 17로 되돌린다
/// ([ManagementSymbolBadge]와 같은 보정).
Widget livePowerGlyph(Color color) => SizedBox.square(
    dimension: 20,
    child: Center(
        child: FigmaIcon.tinted('redesign_v2/power_settings_new',
            size: 17, color: color)));

/// 카메라 180° 회전 토글(Figma 80×32 r16) — 켜짐 #C00306, 꺼짐·비활성
/// #B4AEAE, 손잡이 50×28 r14 #F4F4F4(안쪽 2, 켜지면 오른쪽).
class LiveRotateSwitch extends StatelessWidget {
  const LiveRotateSwitch(
      {super.key, required this.value, required this.onChanged});

  final bool value;

  /// null이면 비활성(녹화 중·오프라인·적용 대기).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: 'live_rotate_title'.tr(),
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 80,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color:
                      enabled && value ? glass.selectionOn : glass.selectionOff,
                  borderRadius: BorderRadius.circular(16)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 50,
                  height: 28,
                  decoration: BoxDecoration(
                      color: glass.overlay,
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 전원 [켬|끔](Figma 112×40 r12, 56.5|55.5) — 기기 상세와 같은 읽기 전용 표시.
/// 누름 효과도 명령도 없다(ON 고정 계약).
class LivePowerSegment extends StatelessWidget {
  const LivePowerSegment({super.key, this.dimmed = false});

  final bool dimmed;

  static const segmentKey = Key('live_power_segment');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final style = managementStyle(context,
        color: dimmed ? glass.textTertiary : glass.textSecondary);
    return Container(
      key: segmentKey,
      width: 112,
      height: 40,
      decoration: BoxDecoration(
          color: dimmed ? glass.border : glass.overlay,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 56.5,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border(
                  right: BorderSide(
                      color: dimmed ? glass.overlay : glass.border))),
          child: Text('management_on'.tr(), maxLines: 1, style: style),
        ),
        Expanded(
            child: Center(
                child: Text('management_off'.tr(), maxLines: 1, style: style))),
      ]),
    );
  }
}
