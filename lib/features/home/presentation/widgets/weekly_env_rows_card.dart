import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/weekly_env_row.dart';
import '../home_control_providers.dart';
import 'env_section_label.dart';
import 'temp_range_bar.dart';

/// 홈 "이번 주" — 애플 날씨 10일 예보 문법의 온습도 7행 (2026-08-17).
///
/// 행: `요일 | 분무 횟수 | 최저° | ━ 범위 바 ━ | 최고° | 습도 평균%`.
/// 오늘이 맨 위이고 오늘 행에는 **현재 온도 점**이 바 위에 얹힌다.
///
/// 통계 탭의 연속 곡선([EnvChart])과 일부러 다르다 — 홈은 훑는 자리라 숫자와
/// 바로 읽히는 리스트가 맞고, 통계는 시간축을 따라가는 자리다. 행을 누르면
/// 통계 탭으로 간다(예전 미니 차트의 "통계 보기" 동선 승계).
///
/// 데이터: [homeWeeklyRowsProvider](오늘 07:00~지금 + 지난 6완결일). 현재
/// 온도 점만 [telemetryStreamProvider]에서 따로 읽는다.
class WeeklyEnvRowsCard extends ConsumerWidget {
  const WeeklyEnvRowsCard({super.key});

  static const cardKey = Key('weekly_env_rows');
  static const todayDotKey = Key('weekly_env_today_dot');
  static Key rowKey(int index) => Key('weekly_env_row_$index');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(homeWeeklyRowsProvider);
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    final current = deviceId == null
        ? null
        : ref.watch(telemetryStreamProvider(deviceId)).valueOrNull?.tA;

    return Padding(
      key: cardKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(
          AppStyles.spacing16,
          AppStyles.spacing12,
          AppStyles.spacing16,
          AppStyles.spacing8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnvSectionLabel(
              icon: Icons.calendar_today_outlined,
              label: 'home_week_title'.tr(),
              trailing: const Icon(Icons.chevron_right,
                  size: 16, color: AppTheme.glassTextSecondary),
            ),
            const SizedBox(height: AppStyles.spacing4),
            rowsAsync.when(
              loading: () => const _Skeleton(),
              // 실패는 빈 상태로 흡수 — 온습도 행이 없다고 홈이 깨질 이유는 없다.
              error: (_, __) => const _Empty(),
              data: (rows) => !rows.hasData
                  ? const _Empty()
                  : _Rows(rows: rows, current: current),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows, required this.current});

  final WeeklyEnvRows rows;
  final double? current;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.rows.length; i++) ...[
          if (i > 0)
            const Divider(
                height: 1, thickness: 1, color: AppTheme.weatherRowDivider),
          _Row(
            key: WeeklyEnvRowsCard.rowKey(i),
            row: rows.rows[i],
            barStart: rows.positionOf(rows.rows[i].tMin),
            barEnd: rows.positionOf(rows.rows[i].tMax),
            dot: rows.rows[i].isToday ? rows.positionOf(current) : null,
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.row,
    required this.barStart,
    required this.barEnd,
    required this.dot,
  });

  final WeeklyEnvRow row;
  final double? barStart;
  final double? barEnd;
  final double? dot;

  static const _dayWidth = 36.0;
  static const _mistWidth = 44.0;
  static const _tempWidth = 32.0;
  static const _humidWidth = 40.0;

  String _dayLabel() => row.isToday
      ? 'home_week_today'.tr()
      : 'home_weekday_${row.day.weekday}'.tr();

  String _fmt(double? v) => v == null ? '--' : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabular = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      button: true,
      label: 'home_week_row_semantics'.tr(namedArgs: {
        'day': _dayLabel(),
        'min': _fmt(row.tMin),
        'max': _fmt(row.tMax),
        'humid': _fmt(row.hAvg),
        'mist': '${row.mistCount}',
      }),
      child: InkWell(
        onTap: () => context.go('/stats'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing8),
          child: Row(
            children: [
              SizedBox(
                width: _dayWidth,
                child: Text(
                  _dayLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tabular?.copyWith(
                    color: AppTheme.glassTextPrimary,
                    fontWeight: row.isToday ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                  width: _mistWidth, child: _MistCell(count: row.mistCount)),
              SizedBox(
                width: _tempWidth,
                child: _Num(
                  row.hasRange
                      ? 'home_week_temp'.tr(args: [_fmt(row.tMin)])
                      : '',
                  style: tabular?.copyWith(color: AppTheme.glassTextSecondary),
                  align: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppStyles.spacing8),
              Expanded(
                child: TempRangeBar(
                  key: dot != null ? WeeklyEnvRowsCard.todayDotKey : null,
                  start: barStart,
                  end: barEnd,
                  dot: dot,
                ),
              ),
              const SizedBox(width: AppStyles.spacing8),
              SizedBox(
                width: _tempWidth,
                child: _Num(
                  row.hasRange
                      ? 'home_week_temp'.tr(args: [_fmt(row.tMax)])
                      : '',
                  style: tabular?.copyWith(
                    color: AppTheme.glassTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  align: TextAlign.left,
                ),
              ),
              SizedBox(
                width: _humidWidth,
                child: _Num(
                  row.hAvg == null
                      ? ''
                      : 'home_week_humid'.tr(args: [_fmt(row.hAvg)]),
                  style: tabular?.copyWith(color: AppTheme.chartHumidity),
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 숫자 칸. 폭이 고정이라 큰 글씨 설정에서는 **줄여서** 넣는다 — 줄바꿈이나
/// 말줄임은 숫자를 못 읽게 만든다.
class _Num extends StatelessWidget {
  const _Num(this.text, {required this.style, required this.align});

  final String text;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }
}

/// 분무 열 — 애플의 강수확률 자리. 아이콘 + "N회" 작은 파랑 글씨, 없으면 점.
class _MistCell extends StatelessWidget {
  const _MistCell({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (count <= 0) {
      return Text('·',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: AppTheme.glassTextTertiary));
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop,
              size: 11, color: AppTheme.deviceMistTint),
          const SizedBox(width: 2),
          Text(
            'home_week_mist_count'.tr(args: ['$count']),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.deviceMistTint,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppStyles.spacing8),
            child: SkeletonLoading(width: double.infinity, height: 16),
          ),
      ],
    );
  }
}

/// 빈 상태 — 예전 미니 차트의 문구를 그대로 승계한다.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'home_chart_empty_title'.tr(),
      description: 'home_chart_empty_desc'.tr(),
    );
  }
}
