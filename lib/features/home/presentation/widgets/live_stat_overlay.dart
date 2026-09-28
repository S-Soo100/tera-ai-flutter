import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../domain/env_realtime_values.dart';
import '../env_live_providers.dart';
import '../home_control_providers.dart';

/// 라이브 면 하단의 **전광판 수치 오버레이**(B안, 2026-08-18).
///
/// `TEMP 24.5℃ | HUMIDITY 68%` — 실시간 [telemetryStreamProvider] 값을 라이브
/// 영상 위에 바로 얹는다. 예전 홈은 영상 아래 별도 카드(`LiveEnvCard`)로
/// 현재값을 보여줬는데, 카메라가 주인공인 화면에서 숫자가 한 장 아래로
/// 밀려 있었다. 이제 영상과 숫자가 한 프레임 안에 있다.
///
/// - 좌우 끝에 붙는다 — 가운데는 페이지 인디케이터([LiveSurface.footer])
///   자리라 비워 둔다.
/// - **항상 흰 글씨**다. 라이브 면은 테마와 무관하게 어둡다(`LiveSurface`).
/// - 전체가 [IgnorePointer]다 — 면의 스와이프(세트 전환)를 가로채지 않는다.
/// - 값이 없으면 `--`. 0으로 위장하지 않는다.
class LiveStatOverlay extends ConsumerWidget {
  const LiveStatOverlay({super.key});

  static const overlayKey = Key('live_stat_overlay');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    // 제어기 없는 세트(캠 단품)는 온습도가 없다 — 빈 라벨을 띄우지 않는다.
    if (deviceId == null) return const SizedBox.shrink();

    // 마지막 정상값을 지우지 않는다 — 센서 단발 실패 행에 "없음"이 깜빡였다
    // (2026-09-28 백엔드 표시 규칙). 오래되면 흐리게 + 안내.
    final live = ref.watch(envLiveViewProvider(deviceId));
    final caption = envLiveCaption(live);
    final glass = context.glass;
    final label = glass.labelCaps.copyWith(color: Colors.white70);
    final figure = glass.figure.copyWith(
        color: switch (live.freshness) {
      EnvFreshness.fresh => Colors.white,
      EnvFreshness.aging => Colors.white60,
      EnvFreshness.offline => Colors.white38,
    });

    return IgnorePointer(
      key: overlayKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 아래로 갈수록 어두워지는 스크림 — 밝은 사육장 영상 위에서도 숫자가
          // 읽히게 한다. 위쪽 55%는 건드리지 않아 영상이 가려지지 않는다.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.62),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: AppStyles.spacing16,
            right: AppStyles.spacing16,
            bottom: AppStyles.spacing12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Stat(
                  label: 'home_live_stat_temp'.tr(),
                  value: live.temperature == null
                      ? 'home_value_none'.tr()
                      : 'home_live_temp_value'
                          .tr(args: [live.temperature!.toStringAsFixed(1)]),
                  labelStyle: label,
                  figureStyle: figure,
                  alignEnd: false,
                ),
                Expanded(
                    child: caption == null
                        ? const SizedBox.shrink()
                        : Text(caption,
                            key: const Key('env_live_caption'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: label)),
                _Stat(
                  label: 'home_live_stat_humid'.tr(),
                  value: live.humidity == null
                      ? 'home_value_none'.tr()
                      : 'home_live_humid_value'
                          .tr(args: [live.humidity!.round().toString()]),
                  labelStyle: label,
                  figureStyle: figure,
                  alignEnd: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.figureStyle,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle figureStyle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 2),
        Text(value, style: figureStyle),
      ],
    );
  }
}
