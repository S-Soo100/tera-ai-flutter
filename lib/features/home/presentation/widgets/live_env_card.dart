import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../home_control_providers.dart';

/// 현재 온·습도 리드아웃.
///
/// **이 앱은 숫자를 확인하러 켜는 앱이다.** 게코는 반응을 주지 않으므로 온습도가
/// 사용자와 개체 사이의 거의 유일한 대화 수단이다. 그래서 현재값을 카드에 담아
/// 정리하지 않고 화면에 직접, 크게 놓는다 — 어두운 방에서 멀리서도 읽혀야 한다.
///
/// 지표 색(온도 빨강 / 습도 파랑)은 **숫자가 아니라 라벨 앞 점**에만 쓴다.
/// 숫자를 칠하면 값에 따라 색이 변하는 것처럼 오해되고, 아래 차트의 선 색과
/// 이어지는 연결고리만 있으면 충분하다.
class LiveEnvCard extends ConsumerWidget {
  const LiveEnvCard({super.key});

  static const cardKey = Key('live_env_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(todayExtremesProvider).valueOrNull;

    return Padding(
      key: cardKey,
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing16,
        AppStyles.spacing16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Readout(
              value: t?.tA?.toStringAsFixed(1),
              unit: '°',
              label: 'home_env_temp_label'.tr(),
              dot: AppTheme.chartTemperature,
              range: _range(ex?.tempMax, ex?.tempMin, 1),
            ),
          ),
          Expanded(
            child: _Readout(
              value: t?.hA?.toStringAsFixed(0),
              unit: '%',
              label: 'home_env_humid_label'.tr(),
              dot: AppTheme.chartHumidity,
              range: _range(ex?.humidMax, ex?.humidMin, 0),
            ),
          ),
        ],
      ),
    );
  }

  /// 당일 최고/최저. 둘 중 하나라도 없으면 줄 자체를 내지 않는다 —
  /// `-- / 23.5` 같은 반쪽짜리는 읽는 사람을 헷갈리게 한다.
  static String? _range(double? max, double? min, int digits) {
    if (max == null || min == null) return null;
    return 'home_env_range_short'.tr(namedArgs: {
      'max': max.toStringAsFixed(digits),
      'min': min.toStringAsFixed(digits),
    });
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.value,
    required this.unit,
    required this.label,
    required this.dot,
    required this.range,
  });

  /// 현재값. null이면 아직 안 들어온 것 — 0으로 위장하지 않고 `--`로 둔다.
  final String? value;
  final String unit;
  final String label;
  final Color dot;
  final String? range;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppStyles.spacing4),
            Flexible(
              child: Text(label,
                  style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: AppStyles.spacing4),
        // 48px는 이 화면에서 가장 큰 글자라 가장 먼저 넘친다. 좁은 기기·큰 글씨
        // 설정에서 잘리는 대신 **비율을 유지한 채 줄어들게** 한다 — 숫자는
        // 잘리면 값이 바뀌어 보이므로 ellipsis를 쓸 수 없다.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value ?? '--',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  // 화면에서 가장 큰 글자. 이 앱이 무엇을 보는 앱인지 말한다.
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -1.5,
                  color: scheme.onSurface,
                  // 값이 바뀔 때 숫자 폭이 흔들리지 않게 고정폭 숫자를 쓴다.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (range != null) ...[
          const SizedBox(height: 2),
          Text(range!,
              style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}
