import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../../my_cage/domain/species_comfort.dart';
import '../../../my_cage/domain/telemetry_bucket.dart';
import '../weekly_providers.dart';

/// 통계 주간 모드의 B안(Flighty) 전광판 보드(2026-08-18).
///
/// `WEEKLY REPORT` 라벨 → 요약 카드(주간 평균 온·습도 대형 수치 + 일별 최고
/// 온도 미니 바) → FIDS 표(DATE | MAX | MIN | STATUS, 최신이 위). 그 아래에는
/// 기존 [EnvChart] 곡선이 정밀 분석 도구로 남는다(홈=행, 통계=곡선 원칙).
///
/// 데이터는 전부 [weeklyDailyBucketsProvider](완결 7일, 07:00 경계, 0 센티넬
/// 제거) 한 벌이다 — 주간 차트·극값과 **같은 접기**라 화면마다 숫자가 다르지
/// 않다. 안심존은 [currentSetComfortProvider](종 care_info 실값) — 없으면
/// STATUS 배지·바 색 판정을 **생략**한다(임의 수치 금지).
class WeeklyReportBoard extends ConsumerWidget {
  const WeeklyReportBoard({super.key});

  static const boardKey = Key('stats_weekly_report_board');
  static const summaryKey = Key('stats_weekly_summary');
  static const fidsKey = Key('stats_weekly_fids');
  static Key fidsRowKey(int i) => Key('stats_weekly_fids_row_$i');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final days = ref.watch(weeklyDailyBucketsProvider);
    final comfort = ref.watch(currentSetComfortProvider).valueOrNull;

    return Padding(
      key: boardKey,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('stats_weekly_report_label'.tr(), style: glass.labelCaps),
          const SizedBox(height: AppStyles.spacing8),
          days.when(
            loading: () => const Column(
              children: [
                SkeletonCard(lineCount: 2, height: 150),
                SizedBox(height: AppStyles.spacing12),
                SkeletonCard(lineCount: 4, height: 260),
              ],
            ),
            // 실패·빈 데이터는 아래 곡선 섹션이 이미 밝힌다(EmptyState/재시도).
            // 여기서 한 번 더 말하면 같은 안내가 두 장 선다.
            error: (_, __) => const SizedBox.shrink(),
            data: (list) => !_hasAny(list)
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _SummaryCard(
                          key: summaryKey, days: list, comfort: comfort),
                      const SizedBox(height: AppStyles.spacing12),
                      _FidsCard(key: fidsKey, days: list, comfort: comfort),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static bool _hasAny(List<TelemetryBucket> days) =>
      days.any((d) => d.tAvg != null || d.hAvg != null);
}

// ─────────────────────────────────────────────────────────────────────────────
// 요약 카드 — 대형 평균 수치 2종 + 일별 최고 온도 미니 바
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({super.key, required this.days, required this.comfort});

  final List<TelemetryBucket> days;
  final SpeciesComfort? comfort;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final none = 'home_value_none'.tr();
    final tAvg = _mean(days.map((d) => d.tAvg));
    final hAvg = _mean(days.map((d) => d.hAvg));

    return GlassCard(
      padding: const EdgeInsets.all(AppStyles.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'stats_avg_temp'.tr(),
                  value: tAvg == null
                      ? none
                      : 'home_tonight_temp'.tr(args: [tAvg.toStringAsFixed(1)]),
                ),
              ),
              Container(width: 1, height: 44, color: glass.border),
              const SizedBox(width: AppStyles.spacing16),
              Expanded(
                child: _BigStat(
                  label: 'stats_avg_humid'.tr(),
                  value: hAvg == null
                      ? none
                      : 'home_live_humid_value'.tr(args: ['${hAvg.round()}']),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyles.spacing16),
          Text('stats_daily_max_label'.tr(), style: glass.labelCaps),
          const SizedBox(height: AppStyles.spacing8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, grow, _) => CustomPaint(
              size: const Size(double.infinity, 72),
              painter: _DailyMaxBarsPainter(
                maxes: [for (final d in days) d.tMax],
                grow: grow,
                warnAbove: comfort?.tempMax,
                okColor: glass.signalOk,
                warnColor: glass.signalWarn,
                // 안심존을 모르면 판정색을 쓰지 않는다 — 중립 톤.
                neutralColor: glass.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Text(
                    'home_weekday_${_dayOf(d).weekday}'.tr(),
                    textAlign: TextAlign.center,
                    style: glass.labelCaps.copyWith(fontSize: 10),
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static double? _mean(Iterable<double?> xs) {
    var n = 0;
    var sum = 0.0;
    for (final x in xs) {
      if (x == null) continue;
      n++;
      sum += x;
    }
    return n == 0 ? null : sum / n;
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: glass.labelCaps, maxLines: 1),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: glass.figure, maxLines: 1),
        ),
      ],
    );
  }
}

/// 일별 최고온도 바. 축은 **그 주의 최저 최고~최고 최고**에 맞춰 잡는다 —
/// 고정 축(24~29.5)은 종마다 다른 안심존과 어긋난다. 값이 없는 날은 빈 칸.
class _DailyMaxBarsPainter extends CustomPainter {
  _DailyMaxBarsPainter({
    required this.maxes,
    required this.grow,
    required this.warnAbove,
    required this.okColor,
    required this.warnColor,
    required this.neutralColor,
  });

  final List<double?> maxes;
  final double grow;
  final double? warnAbove;
  final Color okColor;
  final Color warnColor;
  final Color neutralColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (maxes.isEmpty) return;
    final present = maxes.whereType<double>().toList();
    if (present.isEmpty) return;
    var lo = present.reduce((a, b) => a < b ? a : b);
    var hi = present.reduce((a, b) => a > b ? a : b);
    // 바닥은 최저보다 2도 아래 — 최저값 바가 0 높이로 사라지지 않게.
    lo -= 2;
    if (hi - lo < 1) hi = lo + 1;

    final slot = size.width / maxes.length;
    final barW = slot * 0.42;
    for (var i = 0; i < maxes.length; i++) {
      final v = maxes[i];
      if (v == null) continue;
      final ratio = ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
      final h = size.height * ratio * grow;
      final x = slot * i + (slot - barW) / 2;
      final color = warnAbove == null
          ? neutralColor
          : (v > warnAbove! ? warnColor : okColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DailyMaxBarsPainter old) =>
      old.grow != grow ||
      old.maxes != maxes ||
      old.warnAbove != warnAbove ||
      old.okColor != okColor ||
      old.warnColor != warnColor ||
      old.neutralColor != neutralColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// FIDS 표 — DATE | MAX | MIN | STATUS (최신이 위)
// ─────────────────────────────────────────────────────────────────────────────

class _FidsCard extends StatelessWidget {
  const _FidsCard({super.key, required this.days, required this.comfort});

  final List<TelemetryBucket> days;
  final SpeciesComfort? comfort;

  static const double _col = 60;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    // 전광판은 최신이 위 — 접기 결과(오래된 날 먼저)를 뒤집는다.
    final rows = days.reversed.toList(growable: false);

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
            child: Row(
              children: [
                Expanded(
                    child:
                        Text('stats_fids_date'.tr(), style: glass.labelCaps)),
                SizedBox(
                  width: _col,
                  child: Text('stats_fids_max'.tr(),
                      textAlign: TextAlign.right, style: glass.labelCaps),
                ),
                SizedBox(
                  width: _col,
                  child: Text('stats_fids_min'.tr(),
                      textAlign: TextAlign.right, style: glass.labelCaps),
                ),
                if (comfort != null)
                  SizedBox(
                    width: _col,
                    child: Text('stats_fids_status'.tr(),
                        textAlign: TextAlign.right, style: glass.labelCaps),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(color: glass.border, height: 1, thickness: 1),
            _FidsRow(
              key: WeeklyReportBoard.fidsRowKey(i),
              day: rows[i],
              comfort: comfort,
            ),
          ],
        ],
      ),
    );
  }
}

class _FidsRow extends StatelessWidget {
  const _FidsRow({super.key, required this.day, required this.comfort});

  final TelemetryBucket day;
  final SpeciesComfort? comfort;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final none = 'home_value_none'.tr();
    final tabular = glass.tileTitle.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final date = _dayOf(day);
    final level = _statusOf(day, comfort);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppStyles.spacing16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'stats_fids_date_fmt'.tr(namedArgs: {
                'm': '${date.month}',
                'd': '${date.day}',
                'w': 'home_weekday_${date.weekday}'.tr(),
              }),
              style: tabular,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _FidsCard._col,
            child: Text(
              day.tMax == null
                  ? none
                  : 'home_tonight_temp'.tr(args: [day.tMax!.toStringAsFixed(1)]),
              textAlign: TextAlign.right,
              style: tabular,
            ),
          ),
          SizedBox(
            width: _FidsCard._col,
            child: Text(
              day.tMin == null
                  ? none
                  : 'home_tonight_temp'.tr(args: [day.tMin!.toStringAsFixed(1)]),
              textAlign: TextAlign.right,
              style: tabular.copyWith(color: glass.textSecondary),
            ),
          ),
          if (comfort != null)
            SizedBox(
              width: _FidsCard._col,
              child: Align(
                alignment: Alignment.centerRight,
                child: level == null
                    ? Text(none, style: tabular)
                    : _StatusBadge(ok: level.isGood),
              ),
            ),
        ],
      ),
    );
  }

  /// 그날 최고·최저 둘 다 안심존 안이어야 안정. 값이 없으면 null(판정 불가).
  static ComfortLevel? _statusOf(TelemetryBucket d, SpeciesComfort? c) {
    if (c == null || d.tMax == null || d.tMin == null) return null;
    final hi = classifyComfort(d.tMax!, c.tempMin, c.tempMax, 1.5);
    final lo = classifyComfort(d.tMin!, c.tempMin, c.tempMax, 1.5);
    return hi.severity >= lo.severity ? hi : lo;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final tone = glass.badgeTone(ok ? glass.signalOk : glass.signalWarn);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        ok ? 'home_tonight_badge_ok'.tr() : 'home_tonight_badge_warn'.tr(),
        style: glass.labelCaps
            .copyWith(color: tone.fg, fontWeight: FontWeight.w700),
        maxLines: 1,
      ),
    );
  }
}

/// 일간 버킷의 사육일. [rollupByDay]는 스탬프를 하루 **중앙**(07:00+12h =
/// 19:00)에 찍으므로 그 날짜가 곧 사육일 날짜다.
DateTime _dayOf(TelemetryBucket d) =>
    DateTime(d.bucket.year, d.bucket.month, d.bucket.day);
