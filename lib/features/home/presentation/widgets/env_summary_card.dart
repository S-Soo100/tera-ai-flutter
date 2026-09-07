import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/num_format.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../env_detail_providers.dart';
import '../home_control_providers.dart';

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
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(homeTodayExtremesProvider).valueOrNull;
    final glass = context.glass;

    return Material(
      key: cardKey,
      color: glass.surfaceTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/env-detail'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _EnvColumn(
                  value: t?.tA == null
                      ? '--'
                      : 'home_live_temp_value'
                          .tr(args: [formatCompact(t!.tA!)]),
                  minMax: 'home_env_minmax_temp'.tr(args: [
                    _fmt(ex?.tempMax),
                    _fmt(ex?.tempMin),
                  ]),
                ),
              ),
              Expanded(
                child: _EnvColumn(
                  value: t?.hA == null
                      ? '--'
                      : 'home_live_humid_value'
                          .tr(args: [formatCompact(t!.hA!)]),
                  minMax: 'home_env_minmax_humid'.tr(args: [
                    _fmt(ex?.humidMax),
                    _fmt(ex?.humidMin),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double? v) => v == null ? '--' : formatCompact(v);
}

class _EnvColumn extends StatelessWidget {
  const _EnvColumn({required this.value, required this.minMax});

  final String value;
  final String minMax;

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
            fontWeight: FontWeight.w600,
            letterSpacing: 20 * -0.02,
            color: glass.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          minMax,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 14 * -0.02,
            color: glass.textTertiary,
          ),
        ),
      ],
    );
  }
}
