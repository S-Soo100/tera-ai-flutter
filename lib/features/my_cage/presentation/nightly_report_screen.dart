import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/inline_retry.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/clip_action.dart';
import '../domain/nightly_highlight.dart';
import 'my_cage_providers.dart';

/// vlm_action 라벨(clip_action_* 키, 없으면 원문 폴백).
String highlightActionLabel(String action) {
  final key = 'clip_action_$action';
  final t = key.tr();
  return t == key ? action : t;
}

class NightlyReportScreen extends ConsumerWidget {
  const NightlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(nightlyHighlightsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('nightly_report_title'.tr())),
      body: async.when(
        loading: () => ListView(
          padding: AppStyles.pagePadding,
          children: const [
            SkeletonCard(lineCount: 2, height: 120),
            SizedBox(height: 12),
            SkeletonCard(lineCount: 2, height: 120),
          ],
        ),
        error: (_, __) => Center(
          child: InlineRetry(
              onRetry: () =>
                  ref.read(nightlyHighlightsProvider.notifier).refresh()),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('nightly_report_empty'.tr(),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            );
          }
          return ListView.separated(
            padding: AppStyles.pagePadding,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _HighlightCard(highlight: list[i]),
          );
        },
      ),
    );
  }
}

class _HighlightCard extends ConsumerWidget {
  const _HighlightCard({required this.highlight});
  final NightlyHighlight highlight;

  Color _careColor(ColorScheme cs) =>
      highlight.careLevel == 'enrichment' ? cs.secondary : cs.primary;

  Future<void> _showCorrectSheet(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('nightly_correct_sheet_title'.tr(),
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...kClipActions.map((a) => ListTile(
                  title: Text(highlightActionLabel(a)),
                  onTap: () => Navigator.of(ctx).pop(a),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    await ref.read(nightlyHighlightsProvider.notifier).correct(highlight, action);
    messenger.showSnackBar(
        SnackBar(content: Text('nightly_confirm_thanks'.tr())));
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(nightlyHighlightsProvider.notifier).confirm(highlight);
    messenger.showSnackBar(
        SnackBar(content: Text('nightly_confirm_thanks'.tr())));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final careColor = _careColor(cs);
    final thumbAsync = ref.watch(motionThumbnailProvider(highlight.clipId));
    final reviewed = highlight.review != HighlightReview.pending;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: reviewed ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 썸네일 (탭 → 재생)
            InkWell(
              onTap: () =>
                  context.push('/home/highlights/${highlight.clipId}'),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbAsync.when(
                  data: (url) => url != null
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SkeletonLoading(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: 0),
                          errorWidget: (_, __, ___) =>
                              _thumbFallback(cs),
                        )
                      : _thumbFallback(cs),
                  loading: () => const SkeletonLoading(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0),
                  error: (_, __) => _thumbFallback(cs),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 행동 칩 (care/enrichment 색)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: careColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          highlightActionLabel(highlight.correctedAction ??
                              highlight.vlmAction),
                          style: theme.textTheme.labelMedium
                              ?.copyWith(
                                  color: careColor,
                                  fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MM.dd HH:mm')
                            .format(highlight.startedAt.toLocal()),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                      const Spacer(),
                      // AI 추정 태그
                      Text(
                        '${'nightly_report_ai_estimate'.tr()} ${(highlight.confidence * 100).round()}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (reviewed)
                    Text(
                      highlight.review == HighlightReview.corrected
                          ? 'nightly_corrected_to'.tr(namedArgs: {
                              'action': highlightActionLabel(
                                  highlight.correctedAction ?? '')
                            })
                          : 'nightly_confirm_done'.tr(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: careColor),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: Text('nightly_confirm_yes'.tr()),
                            onPressed: () => _confirm(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text('nightly_confirm_correct'.tr()),
                            onPressed: () =>
                                _showCorrectSheet(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'nightly_confirm_dismiss'.tr(),
                          icon: const Icon(Icons.close),
                          onPressed: () => ref
                              .read(nightlyHighlightsProvider.notifier)
                              .dismiss(highlight.clipId),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.play_circle_outline,
            color: cs.onSurface.withValues(alpha: 0.35), size: 40),
      );
}
