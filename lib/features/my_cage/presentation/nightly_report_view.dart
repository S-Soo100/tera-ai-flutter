import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/nightly_highlight.dart';
import '../domain/nightly_report.dart';
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
    return async.when(
      loading: () => ListView(
        padding: AppStyles.pagePadding,
        children: const [
          SkeletonCard(lineCount: 2, height: 90),
          SizedBox(height: 12),
          SkeletonCard(lineCount: 2, height: 120),
        ],
      ),
      error: (_, __) => Center(
        child: InlineRetry(
            onRetry: () => ref.invalidate(nightlyReportProvider)),
      ),
      data: (report) => ListView(
        padding: AppStyles.pagePadding,
        children: [
          _SummaryCard(report: report),
          const SizedBox(height: 16),
          if (report.highlights.isEmpty)
            _QuietBox()
          else
            ...report.highlights
                .map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HighlightCard(highlight: h),
                    )),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final NightlyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = report.activityMinutes ~/ 60;
    final m = report.activityMinutes % 60;
    final activity = h > 0 ? '${h}h ${m}m' : '${m}m';
    final stats = <(String, String, String)>[
      ('⏱️', 'nightly_activity'.tr(), activity),
      ('💧', 'nightly_count_drink'.tr(),
          'nightly_count_unit'.tr(namedArgs: {'n': '${report.drinkCount}'})),
      ('🍽️', 'nightly_count_eat'.tr(),
          'nightly_count_unit'.tr(namedArgs: {'n': '${report.eatCount}'})),
      if (report.shedCount > 0)
        ('🐍', 'nightly_count_shed'.tr(),
            'nightly_count_unit'.tr(namedArgs: {'n': '${report.shedCount}'})),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('nightly_report_window'.tr(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: stats
                .map((s) => Expanded(
                      child: Column(
                        children: [
                          Text(s.$1,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(s.$2,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.outline)),
                          const SizedBox(height: 2),
                          Text(s.$3,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                  const Spacer(),
                  FavoriteToggleButton(clipId: highlight.clipId),
                ],
              ),
            ),
          ],
        ),
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
