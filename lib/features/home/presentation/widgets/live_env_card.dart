import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../shared/widgets/env_summary_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../home_control_providers.dart';

/// 현재 온·습도 리드아웃 (홈).
///
/// **통계 탭과 같은 표시**([EnvSummaryBar])를 쓴다. 예전에는 홈만 다른 모양이라
/// (라벨 앞 점 + 큰 숫자 + 위험/주의 배지), 바로 아래 차트나 통계 탭과 생김새가
/// 이어지지 않았다.
///
/// 최고/최저는 **바로 아래 차트와 같은 구간**([chartExtremesProvider])이다 —
/// 당일(07:00~) 창을 쓰면 그래프에는 곡선이 있는데 최고/최저는 `--`로 뜬다.
///
/// 스크러버는 넘기지 않는다. 홈 차트는 훑고 통계로 넘어가는 진입점이라
/// 스크럽을 쓰지 않는다.
class LiveEnvCard extends ConsumerWidget {
  const LiveEnvCard({super.key});

  static const cardKey = Key('live_env_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(chartExtremesProvider).valueOrNull;

    // 유리 카드는 겉면만이다 — 안의 표시는 통계 탭과 같은 [EnvSummaryBar].
    return Padding(
      key: cardKey,
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing16,
        AppStyles.spacing4,
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing12),
        child: EnvSummaryBar(
          temperature: t?.tA,
          humidity: t?.hA,
          extremes: ex,
        ),
      ),
    );
  }
}
