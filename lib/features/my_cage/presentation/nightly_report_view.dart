import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/nightly_highlight.dart';
import '../domain/nightly_report.dart';
import 'highlights_controller.dart';
import 'my_cage_providers.dart';
import 'widgets/favorite_toggle_button.dart';

/// vlm_action 라벨(clip_action_* 키, 없으면 원문 폴백).
String reportActionLabel(String action) {
  final key = 'clip_action_$action';
  final t = key.tr();
  return t == key ? action : t;
}

/// 마이 크레 > 리포트 탭 내용. 어젯밤 요약 + 하이라이트(보기/재생).
class NightlyReportView extends ConsumerWidget {
  const NightlyReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nightlyReportProvider);
    // 하단은 플로팅 독 높이를 [glassDockListPadding]이 직접 소비한다 —
    // padding을 명시한 ListView는 자동 인셋이 꺼져 마지막 카드가 독에 가려진다.
    final padding = glassDockListPadding(context, base: AppStyles.pagePadding);
    return async.when(
      loading: () => ListView(
        padding: padding,
        children: const [
          SkeletonCard(lineCount: 2, height: 90),
          SizedBox(height: 12),
          SkeletonCard(lineCount: 2, height: 120),
        ],
      ),
      error: (_, __) => Center(
        child:
            InlineRetry(onRetry: () => ref.invalidate(nightlyReportProvider)),
      ),
      data: (report) => ListView(
        padding: padding,
        children: [
          _SummaryCard(report: report),
          const SizedBox(height: 16),
          if (report.highlights.isEmpty)
            _QuietBox()
          else
            ...report.highlights.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HighlightCard(highlight: h),
                )),
        ],
      ),
    );
  }
}

/// 어젯밤 요약 카드 — B안 **활동/휴식 비율 진행 바**(2026-08-18) + 행동 카운트.
///
/// 비율의 분모는 [nightlyReportProvider]와 같은 창([lastNightSince]~
/// [lastNightEnd], 22~06시 — 06시 이전이면 지금까지)이다. 분모를 8시간으로
/// 박아두면 새벽 2시에 "휴식 7시간"이 나온다(홈 타임라인 요약과 같은 함정).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final NightlyReport report;

  static const ratioKey = Key('nightly_ratio_bar');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = context.glass;
    final now = DateTime.now();
    final windowSec =
        lastNightEnd(now).difference(lastNightSince(now)).inSeconds;
    final activeSec = report.activitySeconds.clamp(0, windowSec);
    final restSec = windowSec - activeSec;
    final ratio = windowSec <= 0 ? 0.0 : activeSec / windowSec;

    final stats = <(String, String, String)>[
      (
        '💧',
        'nightly_count_drink'.tr(),
        'nightly_count_unit'.tr(namedArgs: {'n': '${report.drinkCount}'})
      ),
      (
        '🍽️',
        'nightly_count_eat'.tr(),
        'nightly_count_unit'.tr(namedArgs: {'n': '${report.eatCount}'})
      ),
      if (report.shedCount > 0)
        (
          '🐍',
          'nightly_count_shed'.tr(),
          'nightly_count_unit'.tr(namedArgs: {'n': '${report.shedCount}'})
        ),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('nightly_report_window'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          // 활동/휴식 비율 바 — 홈 "오늘 밤" 진행 바와 같은 앰버 문법.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, r, _) => ClipRRect(
              key: ratioKey,
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: (r * 1000).round().clamp(1, 999),
                      child: ColoredBox(color: glass.signalWarn),
                    ),
                    Expanded(
                      flex: (1000 - (r * 1000).round()).clamp(1, 999),
                      child: ColoredBox(color: glass.weatherBarTrack),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RatioStat(
                  label: 'nightly_ratio_active'.tr(),
                  value: _hm(activeSec),
                ),
              ),
              Expanded(
                child: _RatioStat(
                  label: 'nightly_ratio_rest'.tr(),
                  value: _hm(restSec),
                ),
              ),
              for (final s in stats)
                Expanded(
                  child: _RatioStat(label: '${s.$1} ${s.$2}', value: s.$3),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _hm(int seconds) {
    final m = (seconds / 60).round();
    final h = m ~/ 60;
    final mm = m % 60;
    return h > 0 ? '${h}h ${mm}m' : '${mm}m';
  }
}

class _RatioStat extends StatelessWidget {
  const _RatioStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: glass.labelCaps,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: glass.tileTitle.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _QuietBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text('nightly_quiet'.tr(),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline)),
    );
  }
}

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard({required this.highlight});
  final NightlyHighlight highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final careColor =
        highlight.careLevel == 'enrichment' ? cs.secondary : cs.primary;
    final thumb = ref.watch(motionThumbnailProvider(highlight.clipId));
    // A안 유리 카드. onTap을 주면 GlassCard가 InkWell로 감싼다 —
    // 재생 이동·즐겨찾기 로직은 불변.
    return GlassCard(
      onTap: () => context.push('/my-pets/clips/${highlight.clipId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: thumb.when(
              data: (url) => url != null
                  ? CachedNetworkImage(
                      imageUrl: url,
                      cacheKey: 'thumb_${highlight.clipId}',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonLoading(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0),
                      errorWidget: (_, __, ___) => _fallback(cs),
                    )
                  : _fallback(cs),
              loading: () => const SkeletonLoading(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0),
              error: (_, __) => _fallback(cs),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: careColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(reportActionLabel(highlight.vlmAction),
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: careColor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MM.dd HH:mm')
                      .format(highlight.startedAt.toLocal()),
                  // 테마 outline은 솔리드 표면 위에서 안 읽힌다 — 팔레트
                  // 텍스트 위계 토큰을 쓴다.
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: context.glass.textSecondary),
                ),
                const Spacer(),
                FavoriteToggleButton(clipId: highlight.clipId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.play_circle_outline,
            color: cs.onSurface.withValues(alpha: 0.35), size: 40),
      );
}
