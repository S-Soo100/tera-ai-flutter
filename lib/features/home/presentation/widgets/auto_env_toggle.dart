import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../routine_settings_screen.dart' show ScheduleSwitch;
import 'control_loading_overlay.dart';

/// 제어 시트의 "자동 환기"·"자동 분무" 블록 — 표시 전용(상태 없음).
///
/// Figma `1635:6168`(환기)·`1657:5353`(분무) 실측: 스위치 줄 345×48 r16
/// `surfaceHeader`, 라벨 왼쪽 12·18/600 ls −0.36 `textSecondary`, 스위치는
/// [ScheduleSwitch](80×32, 오른쪽 8). 설명은 줄 아래 8·좌우 12·14/500 lh16.7
/// ls −0.28 `textTertiary`, 줄 수 제한 없음(글자 확대 시 그대로 늘어난다).
/// 비활성은 바탕 `outline`·라벨 `textTertiary`(`1657:5326`).
///
/// 저장 흐름·실패 안내는 시트가 맡는다. 이 위젯은 받은 값만 그린다 —
/// 낙관적 반영 없이 서버 응답 값을 [value]로 받는다.
class AutoEnvToggle extends StatelessWidget {
  const AutoEnvToggle({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onChanged,
    required this.accent,
    this.saving = false,
    this.onRetry,
  });

  final String label;
  final String description;
  final bool value;

  /// false면 탭을 무시하고 비활성 모양으로 그린다(설정 조회 실패). 저장 중은
  /// [saving]이 탭을 막는다 — 모양은 그대로 둔다.
  final bool enabled;

  /// 비활성 줄을 눌렀을 때(조회 실패 → 다시 불러오기). null이면 무시.
  final VoidCallback? onRetry;

  /// 설정을 불러오는 중 — 같은 높이의 shimmer 스켈레톤으로 대신한다.
  final bool loading;

  /// 저장 왕복 중 — 스위치 줄 위에 [ControlLoadingOverlay]를 흘린다.
  final bool saving;

  /// 켜짐 트랙 색 — 그 시트의 기기색(환기 초록·분무 `humidAccent`).
  final Color accent;
  final ValueChanged<bool> onChanged;

  static const rowKey = Key('auto_env_toggle_row');
  static const savingKey = Key('auto_env_toggle_saving');
  static const skeletonKey = Key('auto_env_toggle_skeleton');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final interactive = enabled && !loading && !saving;
    Widget row = MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 줄 전체가 터치 영역 — 스위치만 누르게 하면 48 높이 줄에서 빗맞는다.
        onTap: interactive
            ? () => onChanged(!value)
            : (!enabled && !loading && !saving ? onRetry : null),
        child: Container(
          key: rowKey,
          height: 48,
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
              color: enabled ? glass.surfaceHeader : glass.outline,
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: managementStyle(context,
                        size: 18,
                        weight: FontWeight.w600,
                        color: enabled
                            ? glass.textSecondary
                            : glass.textTertiary))),
            ScheduleSwitch(
                value: value,
                color: accent,
                onChanged: interactive ? onChanged : (_) {}),
          ]),
        ),
      ),
    );
    if (saving) {
      row = Stack(children: [
        row,
        Positioned.fill(
            child: ControlLoadingOverlay(
                key: savingKey, borderRadius: BorderRadius.circular(16))),
      ]);
    }
    final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(description,
                  style: managementStyle(context,
                      size: 14, color: glass.textTertiary))),
        ]);
    if (!loading) return content;
    // 불러오는 중: 실제 블록을 자리만 잡아 두고(같은 높이) 그 위에 줄·설명
    // 모양의 스켈레톤을 그린다 — 값이 오면 아래 내용이 밀리지 않는다.
    return Stack(children: [
      Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: content),
      Positioned.fill(
          child: Shimmer.fromColors(
              key: skeletonKey,
              baseColor: glass.skeletonBase,
              highlightColor: glass.skeletonHighlight,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                        height: 48,
                        decoration: BoxDecoration(
                            color: glass.skeletonBase,
                            borderRadius: BorderRadius.circular(16))),
                    const SizedBox(height: 8),
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: glass.skeletonBase,
                                    borderRadius: BorderRadius.circular(4))))),
                  ]))),
    ]);
  }
}
