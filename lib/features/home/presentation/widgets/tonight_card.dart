import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../my_cage/domain/species_comfort.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/night_progress.dart';
import '../../domain/weekly_env_row.dart';
import '../home_control_providers.dart';

/// "오늘 밤" 카드 — B안(Flighty) 비행 카드 문법의 홈 주인공(2026-08-18).
///
/// ```
/// 오늘 밤                                   [안정]
/// 22:00 활동 시작            활동 종료 06:00
/// ━━━━━━━━━━🦎━━━━━━━━━━━━━━━━━━━━━━━━━
/// 밤 활동 시간 진행 중 / 다음 밤까지 3시간 20분
/// ─────────────────────────────────────────
/// LAST NIGHT      MAX TEMP        MIST
/// 42분            27.4℃           2회
/// ```
///
/// **전부 실데이터다.**
/// - 진행 바: [NightProgress] — 차트 밤 띠와 같은 22:00~06:00. 1분 tick으로
///   움직인다([nowTickProvider]).
/// - LAST NIGHT: [nightlyReportProvider]의 활동 분(22~06시 집계, 전 카메라).
///   06시 이전이면 진행 중인 밤이 곧 "어젯밤"이다.
/// - MAX TEMP · MIST: [homeWeeklyRowsProvider]의 **오늘 행**(07:00~지금) —
///   "이번 주" 카드와 같은 숫자다. 따로 세면 두 카드가 다른 값을 말한다.
/// - 배지: 현재 온도를 종 안심존([currentSetComfortProvider])에 대본다 —
///   [classifyComfort] 재사용, 임의 수치 없음. 종이나 현재값이 없으면 **배지를
///   생략**한다.
///
/// 값이 없으면 `--`. 0으로 위장하지 않는다.
class TonightCard extends ConsumerWidget {
  const TonightCard({super.key});

  static const cardKey = Key('tonight_card');
  static const badgeKey = Key('tonight_badge');
  static const progressKey = Key('tonight_progress');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
    final night = NightProgress.at(now);

    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    final temp = deviceId == null
        ? null
        : ref.watch(telemetryStreamProvider(deviceId)).valueOrNull?.tA;
    final comfort = ref.watch(currentSetComfortProvider).valueOrNull;

    final report = ref.watch(nightlyReportProvider).valueOrNull;
    final rows = ref.watch(homeWeeklyRowsProvider).valueOrNull;
    final today = _todayRow(rows);

    final none = 'home_value_none'.tr();
    final tabular = glass.bodySecondary;

    return Padding(
      key: cardKey,
      padding: const EdgeInsets.fromLTRB(
        AppStyles.spacing16,
        AppStyles.spacing8,
        AppStyles.spacing16,
        AppStyles.spacing4,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('home_tonight_title'.tr(),
                      style: glass.tileTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (temp != null && comfort != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ComfortBadge(
                        key: badgeKey,
                        level: classifyComfort(
                            temp, comfort.tempMin, comfort.tempMax, 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppStyles.spacing12),
            // 좌우 반쪽을 각각 FittedBox로 — 큰 글씨 설정·좁은 폭에서 시각
            // 숫자가 밀리는 대신 비율을 지킨 채 줄어든다.
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_hm(night.start), style: glass.figureMid),
                          const SizedBox(width: AppStyles.spacing8),
                          Text('home_tonight_start'.tr(),
                              style: glass.labelCaps),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppStyles.spacing8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('home_tonight_end'.tr(),
                              style: glass.labelCaps),
                          const SizedBox(width: AppStyles.spacing8),
                          Text(_hm(night.end), style: glass.figureMid),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppStyles.spacing8),
            _NightProgressBar(key: progressKey, progress: night.progress),
            const SizedBox(height: AppStyles.spacing4),
            Text(
              night.isRunning
                  ? 'home_tonight_running'.tr()
                  : 'home_tonight_until_next'
                      .tr(args: [_formatDuration(night.untilNext)]),
              style: glass.tileStatus.copyWith(color: tabular),
            ),
            const SizedBox(height: AppStyles.spacing12),
            Divider(color: glass.border, height: 1),
            const SizedBox(height: AppStyles.spacing12),
            Row(
              children: [
                Expanded(
                  child: _GridStat(
                    label: 'home_tonight_col_activity'.tr(),
                    value: report == null
                        ? none
                        : 'home_tonight_minutes'
                            .tr(args: ['${report.activityMinutes}']),
                  ),
                ),
                Expanded(
                  child: _GridStat(
                    label: 'home_tonight_col_max_temp'.tr(),
                    value: today?.tMax == null
                        ? none
                        : 'home_tonight_temp'
                            .tr(args: [today!.tMax!.toStringAsFixed(1)]),
                  ),
                ),
                Expanded(
                  child: _GridStat(
                    label: 'home_tonight_col_mist'.tr(),
                    value: today == null
                        ? none
                        : 'home_count'
                            .tr(namedArgs: {'n': '${today.mistCount}'}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static WeeklyEnvRow? _todayRow(WeeklyEnvRows? rows) {
    if (rows == null) return null;
    for (final r in rows.rows) {
      if (r.isToday) return r;
    }
    return null;
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return 'home_minutes'.tr(namedArgs: {'m': '$m'});
    if (m == 0) return 'home_hours'.tr(namedArgs: {'h': '$h'});
    return 'home_hours_minutes'.tr(namedArgs: {'h': '$h', 'm': '$m'});
  }
}

/// 안정/주의 배지 — 전광판 시맨틱(그린 = 안심존 안, 앰버 = 밖).
///
/// 위험(danger)도 앰버 "주의"로 낸다 — 이 카드는 상태를 짚어주는 자리지
/// 경보 창이 아니다. 단계별 문구는 사육장 탭 추이 차트가 맡는다.
class _ComfortBadge extends StatelessWidget {
  const _ComfortBadge({super.key, required this.level});

  final ComfortLevel level;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final ok = level.isGood;
    final tone = glass.badgeTone(ok ? glass.signalOk : glass.signalWarn);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ok ? 'home_tonight_badge_ok'.tr() : 'home_tonight_badge_warn'.tr(),
        style: glass.labelCaps
            .copyWith(color: tone.fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 비행 진행 바 — 비행기 대신 게코 아이콘이 진행 위치에 앉는다.
class _NightProgressBar extends StatelessWidget {
  const _NightProgressBar({super.key, required this.progress});

  final double progress;

  static const double _trackHeight = 6;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) => LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return SizedBox(
            height: 22,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: glass.weatherBarTrack,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Container(
                  height: _trackHeight,
                  width: w * p,
                  decoration: BoxDecoration(
                    color: glass.signalWarn,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Positioned(
                  left: (w * p - _iconSize / 2).clamp(0.0, w - _iconSize),
                  child: Icon(Icons.pets,
                      size: _iconSize, color: glass.signalWarn),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GridStat extends StatelessWidget {
  const _GridStat({required this.label, required this.value});

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
          child: Text(value, style: glass.figureMid, maxLines: 1),
        ),
      ],
    );
  }
}
