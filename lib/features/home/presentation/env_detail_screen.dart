import '../domain/env_realtime_values.dart';
import 'env_live_providers.dart';
import '../../../shared/widgets/figma_icon.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../core/theme/viva_colors.dart';
import '../../../shared/domain/env_day.dart';
import '../../../shared/domain/num_format.dart';
import '../../my_cage/presentation/device_settings_providers.dart';
import '../../../shared/domain/week_range.dart';
import 'env_detail_providers.dart';
import 'home_control_providers.dart';
import 'widgets/control_log_list.dart';
import 'widgets/env_range_bar.dart';
import 'widgets/env_day_chart.dart';
import 'widgets/week_range_chart.dart';

/// 온습도 상세 (`/env-detail`, Figma §A.5·§A.6 — 계획서 T5).
///
/// 홈 요약 카드가 진입점이다. 일간(자정 경계 [EnvDay] 페이징)과 주간(월요일
/// 시작 [WeekRange] 페이징)을 세그먼트로 오간다. 하루 경계가 자정인 화면은
/// 여기뿐이다 — 홈 24h 차트(6시간 프레임)·어젯밤 리포트(07:00 경계)와 혼용
/// 금지.
class EnvDetailScreen extends ConsumerStatefulWidget {
  const EnvDetailScreen({super.key});

  static const closeKey = Key('env_detail_close');
  static const settingsKey = Key('env_detail_settings');
  static const segmentDailyKey = Key('env_detail_segment_daily');
  static const segmentWeeklyKey = Key('env_detail_segment_weekly');
  static const dayPrevKey = Key('env_detail_day_prev');
  static const dayNextKey = Key('env_detail_day_next');
  static const weekPrevKey = Key('env_detail_week_prev');
  static const weekNextKey = Key('env_detail_week_next');

  @override
  ConsumerState<EnvDetailScreen> createState() => _EnvDetailScreenState();
}

class _EnvDetailScreenState extends ConsumerState<EnvDetailScreen> {
  bool get _weekly => ref.watch(envDetailWeeklyProvider);

  /// 스크러버 위치(0~1). 손 떼도 유지, **날짜가 바뀌면 해제**(§A.5).
  double? get _scrubX => ref.watch(envDetailScrubProvider);

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Scaffold(
      backgroundColor: glass.wallpaper,
      body: Column(
        children: [
          _topBar(glass),
          const SizedBox(height: 18),
          _segment(glass),
          const SizedBox(height: 16),
          Expanded(child: _weekly ? _weeklyBody(glass) : _dailyBody(glass)),
        ],
      ),
    );
  }

  // ── 상단바 (Figma S03·A06 — bg appBar #FAFAFA + 하단 1px, 타이틀 중앙,
  //    ✕ 왼쪽 위, 설정(discover_tune) 오른쪽 위) ──

  Widget _topBar(GlassPalette glass) {
    final device = ref.watch(currentDeviceIdProvider);
    // 기기가 없거나 아직 모르면 설정 아이콘을 숨긴다 — 대상 없는 설정 화면은 없다.
    final deviceId = device.isLoading ? null : device.valueOrNull;
    return Container(
      decoration: BoxDecoration(color: glass.appBar),
      // Figma 1081:4873 — 헤더 106(62+44) 안에서 하단선을 그린다(높이 미추가).
      foregroundDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: glass.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'env_detail_title'.tr(),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 16 * -0.02,
                  color: glass.textPrimary,
                ),
              ),
              // Figma Button/Enabled (12,62 44×44) — 글리프 24가 22에서 시작.
              Positioned(
                left: 12,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    key: EnvDetailScreen.closeKey,
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                    icon: FigmaIcon.tinted(FigmaIcons.close,
                        color: glass.textSecondary, size: 24),
                  ),
                ),
              ),
              // Figma discover_tune (337,62 44×44) — 44 프레임 export 그대로.
              if (deviceId != null)
                Positioned(
                  right: 12,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      key: EnvDetailScreen.settingsKey,
                      tooltip: 'temp_humid_title'.tr(),
                      onPressed: () =>
                          context.push(tempHumidSettingPath(deviceId)),
                      padding: EdgeInsets.zero,
                      iconSize: 44,
                      icon: FigmaIcon.tinted(FigmaIcons.management,
                          color: glass.textSecondary, size: 44),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 세그먼트 [일간|주간] (§A.2 수평 토글) ──

  Widget _segment(GlassPalette glass) {
    Widget half({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 28,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    // Figma는 white — 다크에서도 성립하게 카드색 토큰으로.
                    color: glass.surfaceHeader,
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                height: 16.70703125 / 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 14 * -0.02,
                color: selected ? glass.textSecondary : glass.bodySecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: glass.outline,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            half(
              key: EnvDetailScreen.segmentDailyKey,
              label: 'env_detail_daily'.tr(),
              selected: !_weekly,
              onTap: () =>
                  ref.read(envDetailWeeklyProvider.notifier).state = false,
            ),
            half(
              key: EnvDetailScreen.segmentWeeklyKey,
              label: 'env_detail_weekly'.tr(),
              selected: _weekly,
              onTap: () =>
                  ref.read(envDetailWeeklyProvider.notifier).state = true,
            ),
          ],
        ),
      ),
    );
  }

  // ── 일간 ──

  Widget _dailyBody(GlassPalette glass) {
    final day = ref.watch(envDetailDayProvider);
    final chartAsync = ref.watch(envDayChartDataProvider);
    final logAsync = ref.watch(envDayControlLogProvider);
    final log = logAsync.valueOrNull ?? const [];

    return ListView(
      // 안드로이드 edge-to-edge — 하단 시스템 바 높이를 직접 비운다(padding을
      // 지정하면 ListView가 자동으로 더해 주지 않는다).
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        _dayPager(glass, day),
        // Figma A06 — 날짜(172~212) → 범위 바 228.
        const SizedBox(height: 16),
        Semantics(
            label: (day.isToday ? 'env_value_realtime' : 'env_value_daily_mean')
                .tr(),
            child: _valueBar(glass, day)),
        if (!day.isToday) _averageStatus(glass),
        // Figma A06 — 범위 바(228~298) → 그래프 319.
        const SizedBox(height: 21),
        chartAsync.when(
          loading: () => _skeleton(glass, height: EnvDayChart.totalHeight),
          error: (_, __) => _noData(glass, height: EnvDayChart.totalHeight),
          data: (d) => !d.hasData
              ? _noData(glass, height: EnvDayChart.totalHeight)
              : EnvDayChart(
                  data: d,
                  log: log,
                  scrubX: _scrubX,
                  onScrubChanged: (x) =>
                      ref.read(envDetailScrubProvider.notifier).state = x,
                  initialFraction: _nowFraction(day),
                ),
        ),
        // Figma A06 — 그래프(319~575) → 제어 기록 패널 601.
        const SizedBox(height: 26),
        logAsync.when(
          loading: () => _skeleton(glass, height: 160),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text('env_log_load_failed'.tr(),
                  style: TextStyle(color: glass.textSecondary)),
              TextButton(
                onPressed: () => ref.invalidate(envDayControlLogProvider),
                child: Text('retry'.tr()),
              ),
            ]),
          ),
          data: (entries) => ControlLogList(entries: entries),
        ),
      ],
    );
  }

  /// 오늘이면 현재 시각의 하루 내 비율(초기 스크롤용), 과거일은 0.
  double _nowFraction(EnvDay day) {
    final now = DateTime.now();
    if (!day.containsNow(now)) return 0;
    final span = day.end.difference(day.start).inMicroseconds;
    if (span <= 0) return 0;
    return now.difference(day.start).inMicroseconds / span;
  }

  Widget _dayPager(GlassPalette glass, EnvDay day) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            _pagerButton(
              key: EnvDetailScreen.dayPrevKey,
              icon: Icons.chevron_left,
              glass: glass,
              onTap: () {
                ref.read(envDetailDayProvider.notifier).state = day.previous;
                ref.read(envDetailScrubProvider.notifier).state =
                    null; // 날짜 변경 시 해제(§A.5)
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  // 숫자+구두점 조립이라 번역 키가 아니다(계획서 T5 지시).
                  '${day.date.year}. ${day.date.month}. ${day.date.day}',
                  style: _pagerLabelStyle(glass),
                ),
              ),
            ),
            // 오늘이면 → 비표시 — 미래는 데이터가 있을 수 없다. 자리는 남긴다.
            if (day.isToday)
              _pagerSpacer(glass)
            else
              _pagerButton(
                key: EnvDetailScreen.dayNextKey,
                icon: Icons.chevron_right,
                glass: glass,
                onTap: () {
                  ref.read(envDetailDayProvider.notifier).state = day.next;
                  ref.read(envDetailScrubProvider.notifier).state = null;
                },
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _pagerLabelStyle(GlassPalette glass) => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        height: 21.48046875 / 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 18 * -0.02,
        color: glass.textSecondary,
      );

  Widget _pagerButton({
    required Key key,
    required IconData icon,
    required GlassPalette glass,
    required VoidCallback onTap,
  }) {
    return IconButton(
      key: key,
      onPressed: onTap,
      iconSize: 24,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: FigmaIcon.tinted(
          icon == Icons.chevron_left
              ? FigmaIcons.arrowPrevious
              : FigmaIcons.arrowNext,
          color: glass.textSecondary,
          size: 24),
    );
  }

  /// 숨긴 [>] 자리 — 왼쪽 [<]와 같은 버튼을 안 보이게 둬 폭을 맞춘다. 전엔
  /// 40 빈칸이라 실제 48(최소 터치 영역)인 [<]보다 좁아 날짜가 4pt 오른쪽으로
  /// 밀렸다(2026-10-20 시뮬레이터 대조).
  Widget _pagerSpacer(GlassPalette glass) => Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: _pagerButton(
          key: const Key('env_detail_pager_spacer'),
          icon: Icons.chevron_right,
          glass: glass,
          onTap: () {}));

  Widget _averageStatus(GlassPalette glass) {
    final average = ref.watch(envDailyAverageProvider);
    if (average.isLoading) return _skeleton(glass, height: 14);
    if (average.hasError) {
      return TextButton(
          onPressed: () => ref.invalidate(envDayBucketsProvider),
          child: Text('retry'.tr()));
    }
    if (average.valueOrNull?.countUnavailable == true) {
      return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text('env_average_unavailable'.tr(),
              style: TextStyle(fontSize: 12, color: glass.textTertiary)));
    }
    return const SizedBox.shrink();
  }

  /// 맨 위 범위 바 두 줄(Figma A04·A06). 오늘은 유효한 실시간 값, 과거는
  /// 지표별 유효 개수로 계산한 일평균. 바 양옆은 그날 최저·최고, 적정 구간은
  /// 지난 날에도 **현재** 설정이다(Figma A14와 같다 — 과거 설정 이력은 없다).
  Widget _valueBar(GlassPalette glass, EnvDay day) {
    final ex = ref.watch(envDayExtremesProvider).valueOrNull;

    final now = ref.watch(envDetailNowProvider).valueOrNull ?? DateTime.now();
    final today = day.start.year == now.year &&
        day.start.month == now.month &&
        day.start.day == now.day;
    final device = ref.watch(currentDeviceIdProvider);
    final deviceId = device.isLoading ? null : device.valueOrNull;
    double? temp;
    double? humid;
    // 오늘 현재값 — 홈 카드와 같은 규칙(마지막 정상값 유지 + 신선도, 2026-09-28).
    EnvLiveView? live;
    if (today) {
      if (deviceId != null) {
        final view = ref.watch(envLiveViewProvider(deviceId));
        live = view;
        temp = view.temperature;
        humid = view.humidity;
      }
    } else {
      final average = ref.watch(envDailyAverageProvider);
      // Do not reuse a previous date's value while a new date/device loads.
      if (!average.isLoading && !average.hasError) {
        temp = average.valueOrNull?.temperature;
        humid = average.valueOrNull?.humidity;
      }
    }
    if (temp != null && (!temp.isFinite || temp <= 0)) temp = null;
    if (humid != null && (!humid.isFinite || humid <= 0)) humid = null;

    // 적정 구간 — 조회 중·실패면 null(구간 없이 그린다, 기본값으로 대신하지 않음).
    final settings = deviceId == null
        ? null
        : ref.watch(deviceSettingsProvider(deviceId)).valueOrNull;

    final caption = live == null ? null : envLiveCaption(live);
    // 오래됐으면 값 색을 흐리게(값은 지우지 않는다).
    final dim = switch (live?.freshness) {
      EnvFreshness.aging => 0.55,
      EnvFreshness.offline => 0.35,
      _ => 1.0,
    };

    return Padding(
      // Figma A06 BarGraph (15,228 363×70).
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnvRangeBar(
            kind: EnvBarKind.temp,
            value: temp,
            low: ex?.tempMin,
            high: ex?.tempMax,
            range: settings?.tempRange,
            dim: dim,
          ),
          const SizedBox(height: 12),
          EnvRangeBar(
            kind: EnvBarKind.humid,
            value: humid,
            low: ex?.humidMin,
            high: ex?.humidMax,
            range: settings?.humidRange,
            dim: dim,
          ),
          if (caption != null) ...[
            // 습도 바 아래 눈금(12)이 바 줄 밖으로 내려와 있어 그만큼 띄운다.
            const SizedBox(height: 16),
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
    );
  }

  // ── 주간 ──

  Widget _weeklyBody(GlassPalette glass) {
    final week = ref.watch(envDetailWeekProvider);
    final rowsAsync = ref.watch(envWeekRowsProvider);

    return ListView(
      padding:
          EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _weekPager(glass, week),
        // Figma 1081:5052 — 페이저(172~212) → 헤더 236.
        const SizedBox(height: 24),
        rowsAsync.when(
          loading: () => Column(
            children: [
              _skeleton(glass, height: WeekRangeChart.chartHeight),
              const SizedBox(height: 24),
              _skeleton(glass, height: WeekRangeChart.chartHeight),
            ],
          ),
          error: (_, __) => _noData(glass, height: WeekRangeChart.chartHeight),
          data: (rows) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WeekRangeChart(
                  rows: rows.temp,
                  // Figma 1081:5052 — 최고 막대 #D61619, 수치·헤더 #C00306.
                  accent: glass.tempAccent,
                  valueColor: VivaColors.mainDark,
                  iconAsset: 'redesign_v2/env_temperature',
                  headerFormat: (v) =>
                      'env_detail_temp_value'.tr(args: [formatCompact(v)]),
                  axisFormat: (v, d) => 'stats_axis_temp'
                      .tr(namedArgs: {'v': v.toStringAsFixed(d)}),
                ),
                const SizedBox(height: 40),
                WeekRangeChart(
                  rows: rows.humid,
                  // Figma 1081:5052 — 최고 막대 #2E408C, 수치·헤더 #192553.
                  accent: glass.humidAccent,
                  valueColor: VivaColors.subDark,
                  iconAsset: 'redesign_v2/env_humidity',
                  headerFormat: (v) =>
                      'env_detail_humid_value'.tr(args: [formatCompact(v)]),
                  axisFormat: (v, d) => 'stats_axis_humid'
                      .tr(namedArgs: {'v': v.toStringAsFixed(d)}),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekPager(GlassPalette glass, WeekRange week) {
    final isCurrentWeek = week.containsNowWeek(DateTime.now());
    final last = week.days.last; // 일요일 (표기는 포함 경계)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            _pagerButton(
              key: EnvDetailScreen.weekPrevKey,
              icon: Icons.chevron_left,
              glass: glass,
              onTap: () => ref.read(envDetailWeekProvider.notifier).state =
                  week.previous,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${week.monday.year}. ${week.monday.month}. ${week.monday.day}'
                  ' - ${last.month}. ${last.day}',
                  style: _pagerLabelStyle(glass),
                ),
              ),
            ),
            if (isCurrentWeek)
              _pagerSpacer(glass)
            else
              _pagerButton(
                key: EnvDetailScreen.weekNextKey,
                icon: Icons.chevron_right,
                glass: glass,
                onTap: () =>
                    ref.read(envDetailWeekProvider.notifier).state = week.next,
              ),
          ],
        ),
      ),
    );
  }

  // ── 공용 ──

  Widget _noData(GlassPalette glass, {required double height}) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          'env_detail_no_data'.tr(),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: glass.textTertiary,
          ),
        ),
      ),
    );
  }

  /// 로딩은 shimmer 스켈레톤 — CircularProgressIndicator 금지(프로젝트 규칙).
  Widget _skeleton(GlassPalette glass, {required double height}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Shimmer.fromColors(
        baseColor: glass.skeletonBase,
        highlightColor: glass.skeletonHighlight,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: glass.skeletonBase,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// [WeekRange]에 "지금이 이 주인가"가 없어 화면 쪽에 확장으로 둔다 —
/// 도메인 파일은 Task 3 산출물이라 시그니처를 건드리지 않는다.
extension on WeekRange {
  bool containsNowWeek(DateTime now) =>
      !now.isBefore(start) && now.isBefore(end);
}
