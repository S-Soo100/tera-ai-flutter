import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/num_format.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../env_detail_providers.dart';
import '../env_live_providers.dart';
import '../home_control_providers.dart';
import '../../domain/env_realtime_values.dart';

/// 온습도 요약 카드 — Figma A.4 ③ (369×69, bg surfaceTint, radius 12).
///
/// 2열: 현재값(20 SemiBold, textStrong) + `최고: X° 최저: Y°`(14 Medium,
/// textTertiary). 현재값은 telemetry 실시간, 최고/최저는 **오늘(자정~)**
/// 창([homeTodayExtremesProvider], B.4 결정 — 홈 24h 차트 창과 다른 구간).
///
/// **카드 탭 → 온습도 상세(`/env-detail`)**. 라우트 등록은 Task 5 몫이다.
class EnvSummaryCard extends ConsumerWidget {
  const EnvSummaryCard({super.key});

  static const cardKey = Key('env_summary_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 재계산 중에도 이전 기기 id를 쓴다 — 접으면 아래 제어 그리드가 위로 튀었다
    // 돌아와 화면이 깜빡인다(CageControlGrid·DeviceOfflineNotice와 같은 규칙).
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    // 마지막 정상값을 지우지 않고, 오래되면 흐리게 + 안내(2026-09-28 백엔드
    // 표시 규칙). 전엔 센서 단발 실패·12초 무소식·폰 시계 차이마다 `--`가 됐다.
    final values = ref.watch(envLiveViewProvider(deviceId));
    final caption = envLiveCaption(values);
    final ex = ref.watch(homeTodayExtremesProvider).valueOrNull;
    final glass = context.glass;
    final valueColor = switch (values.freshness) {
      EnvFreshness.fresh => glass.textPrimary,
      EnvFreshness.aging => glass.textTertiary,
      EnvFreshness.offline => glass.deviceOff,
    };

    return Material(
      key: cardKey,
      color: glass.surfaceTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/env-detail'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _EnvColumn(
                      value: values.temperature == null
                          ? '--'
                          : 'home_live_temp_value'
                              .tr(args: [formatCompact(values.temperature!)]),
                      color: valueColor,
                      minMax: 'home_env_minmax_temp'.tr(args: [
                        _fmt(ex?.tempMax),
                        _fmt(ex?.tempMin),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: _EnvColumn(
                      value: values.humidity == null
                          ? '--'
                          : 'home_live_humid_value'
                              .tr(args: [formatCompact(values.humidity!)]),
                      color: valueColor,
                      minMax: 'home_env_minmax_humid'.tr(args: [
                        _fmt(ex?.humidMax),
                        _fmt(ex?.humidMin),
                      ]),
                    ),
                  ),
                  FigmaIcon.tinted(FigmaIcons.arrowNext,
                      color: glass.textSecondary, size: 18),
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: 6),
                Text(caption,
                    key: const Key('env_live_caption'),
                    style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: glass.textTertiary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double? v) => v == null ? '--' : formatCompact(v);
}

class _EnvColumn extends StatelessWidget {
  const _EnvColumn(
      {required this.value, required this.minMax, required this.color});

  final String value;
  final String minMax;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            height: 1.193359375,
            fontWeight: FontWeight.w600,
            letterSpacing: 20 * -0.02,
            color: color,
          ),
        ),
        // Figma 668:866 실측 4 (현재값끝 2652 → 최고최저 2656) — 카드 h69의
        // 구성분(12+24+4+17+12).
        const SizedBox(height: 4),
        // 좁은 폰에서 줄바꿈 대신 한 줄 유지 — 공간이 모자랄 때만 축소(키우지 않음).
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            minMax,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              height: 1.193359375,
              fontWeight: FontWeight.w500,
              letterSpacing: 14 * -0.02,
              color: glass.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
