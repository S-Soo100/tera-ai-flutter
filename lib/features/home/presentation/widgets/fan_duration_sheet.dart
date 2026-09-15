import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/fan_actuator.dart';
import '../../domain/fan_timer_duration.dart';

final fanDurationSelectionProvider =
    StateProvider.autoDispose<FanTimerDuration?>((ref) => FanTimerDuration.m30);
final _submittedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Options only change selection. Only Start returns an executable choice.
///
/// Figma 1106:4296(환기팬) / 4394(냉각팬): 시트 #F4F4F4, 안쪽 24, 라벨
/// 16/500 #949090, 칩 44 r16 흰색(선택=장치색 16/700 #FAFAFA) 간격 4,
/// '계속'은 80 고정. 원본의 즉시/예약 segment·전원 스위치는 송신 시점이
/// 미결(P11)이라 붙이지 않고, 시작 버튼(기존 확정: 선택→시작 송신)을 둔다.
/// 냉각팬은 원본대로 30분/1시간/2시간 '뒤'만 — '계속'·2시간 초과 없음.
class FanDurationSheet extends ConsumerWidget {
  const FanDurationSheet({super.key, this.actuator = FanActuator.ventilation});
  final FanActuator actuator;

  static const double chipHeight = 44;
  static const double steadyWidth = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(fanDurationSelectionProvider);
    final submitted = ref.watch(_submittedProvider);
    final glass = context.glass;
    final cooling = actuator == FanActuator.cooling;
    final accent = cooling ? glass.deviceCool : glass.deviceFan;
    final durations = [
      for (final d in FanTimerDuration.values)
        if (!cooling || d != FanTimerDuration.m10) d
    ];
    // 냉각팬 시트에서 '계속'이 없으므로 기본 선택이 null이면 30분으로 맞춘다.
    final effective = cooling && selected == null ? FanTimerDuration.m30 : selected;

    Widget chip(
        {required Key key,
        required String label,
        required bool active,
        required VoidCallback onTap,
        double? width}) {
      final child = Material(
          color: active ? accent : glass.surfaceHeader,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(16),
              onTap: submitted ? null : onTap,
              child: SizedBox(
                  height: chipHeight,
                  child: Center(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              height: 19.09375 / 16,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w600,
                              letterSpacing: -0.32,
                              color: active
                                  ? glass.buttonForeground
                                  : glass.textSecondary))))));
      return width == null
          ? Expanded(child: child)
          : SizedBox(width: width, child: child);
    }

    final labelStyle = TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        height: 19.09375 / 16,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.32,
        color: glass.textTertiary);

    return ColoredBox(
      color: glass.overlay,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                      (cooling
                              ? 'home_cooling_end_label'
                              : 'home_fan_duration_label')
                          .tr(),
                      style: labelStyle)),
              if (cooling)
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text('home_cooling_end_hint'.tr(),
                        style: labelStyle.copyWith(
                            fontSize: 14,
                            height: 16.70703125 / 14,
                            letterSpacing: -0.28))),
              const SizedBox(height: 8),
              Row(children: [
                for (final (i, duration) in durations.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  chip(
                      key: Key('fan_timer_${duration.minutes}'),
                      label: cooling
                          ? 'home_timer_later_fmt'
                              .tr(args: [duration.labelKey.tr()])
                          : duration.labelKey.tr(),
                      active: effective == duration,
                      onTap: () => ref
                          .read(fanDurationSelectionProvider.notifier)
                          .state = duration),
                ],
                if (!cooling) ...[
                  const SizedBox(width: 4),
                  chip(
                      key: const Key('fan_steady_on'),
                      label: 'home_fan_steady_on'.tr(),
                      active: effective == null,
                      width: steadyWidth,
                      onTap: () => ref
                          .read(fanDurationSelectionProvider.notifier)
                          .state = null),
                ],
              ]),
              const SizedBox(height: 24),
              SizedBox(
                  height: 56,
                  child: FilledButton(
                    key: const Key('fan_start'),
                    style: FilledButton.styleFrom(
                        backgroundColor: glass.textPrimary,
                        foregroundColor: glass.buttonForeground,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.36)),
                    onPressed: submitted
                        ? null
                        : () {
                            if (ref.read(_submittedProvider)) return;
                            ref.read(_submittedProvider.notifier).state = true;
                            Navigator.of(context).pop((effective,));
                          },
                    child: Text('home_fan_start'.tr()),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
