import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/highlight_group.dart';
import '../domain/nightly_highlight.dart';
import 'my_cage_providers.dart';
import 'widgets/clip_grid_radius.dart';
import 'widgets/crecam_detail_top_bar.dart';

/// 하이라이트 날짜 필터(startedAt 기준, 자정 경계). null = 전체(묶음 보기).
/// autoDispose — 화면 이탈 시 리셋.
final highlightsDayFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

/// 하이라이트 상세 (Figma 668:600 배너有 / 668:655 배너無, 재설계 T4).
///
/// 묶음([highlightGroupsProvider], 72h 창) 섹션 + 최신 묶음 도착 배너(dismiss는
/// Hive `app_settings`에 그룹 key 저장 — 같은 묶음은 재방문에도 숨김).
/// 날짜 필터 중엔 묶음 대신 그 날짜의 하이라이트만 평면 그리드 1섹션.
/// 행동 필터는 만들지 않는다(Figma 정책 노트).
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  /// 테스트용 — 도착 배너·닫기 버튼 식별.
  static const bannerKey = Key('crecam_highlight_banner');
  static const bannerCloseKey = Key('crecam_highlight_banner_close');

  /// Figma 콘텐츠 좌우 마진·섹션 간격.
  static const double _margin = 12;
  static const double _sectionGap = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final groupsAsync = ref.watch(highlightGroupsProvider);
    final day = ref.watch(highlightsDayFilterProvider);
    final dismissedKey = ref.watch(highlightBannerDismissedProvider);

    return Scaffold(
      backgroundColor: glass.wallpaper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CrecamDetailTopBar(
              title: 'crecam_highlights_title'.tr(),
              onCalendarTap: () => _pickDay(context, ref, day),
            ),
            if (day != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(_margin, 8, _margin, 0),
                child: CrecamDateFilterChip(
                  day: day,
                  onClear: () =>
                      ref.read(highlightsDayFilterProvider.notifier).state =
                          null,
                ),
              ),
            Expanded(
              child: groupsAsync.when(
                loading: () => const _Skeleton(),
                error: (_, __) => _ErrorRetry(
                  onRetry: () => ref.invalidate(highlightGroupsProvider),
                ),
                data: (groups) => day != null
                    ? _dayView(context, groups, day)
                    : _groupView(context, ref, groups, dismissedKey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDay(
      BuildContext context, WidgetRef ref, DateTime? current) async {
    final picked = await showCrecamDayPicker(context, current);
    if (picked == null || !context.mounted) return;
    ref.read(highlightsDayFilterProvider.notifier).state = picked;
  }

  /// 날짜 필터 뷰 — 그 날짜의 하이라이트만 평면 그리드 1섹션.
  Widget _dayView(
      BuildContext context, List<HighlightGroup> groups, DateTime day) {
    final items = [
      for (final g in groups)
        for (final h in g.items)
          if (_isSameDay(h.startedAt.toLocal(), day)) h,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (items.isEmpty) {
      return _EmptyMessage(message: 'crecam_home_empty_day'.tr());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(_margin, 24, _margin, 24),
      children: [
        _Section(
          header: DateFormat('yyyy. M. d').format(day),
          items: items,
        ),
      ],
    );
  }

  /// 기본 뷰 — 도착 배너(최신 묶음, 미dismiss 시) + 묶음 섹션들.
  Widget _groupView(BuildContext context, WidgetRef ref,
      List<HighlightGroup> groups, String? dismissedKey) {
    if (groups.isEmpty) {
      return _EmptyMessage(message: 'crecam_highlights_empty'.tr());
    }
    final newest = groups.first;
    final showBanner = dismissedKey != highlightGroupKey(newest);

    return ListView(
      // Figma 실측: 배너가 있으면 상단바→배너 12(668:600), 없으면
      // 상단바→첫 섹션 24(668:655).
      padding: EdgeInsets.fromLTRB(
          _margin, showBanner ? 12 : 24, _margin, 24),
      children: [
        if (showBanner) ...[
          _ArrivalBanner(
            group: newest,
            onDismiss: () => ref
                .read(highlightBannerDismissedProvider.notifier)
                .dismiss(highlightGroupKey(newest)),
          ),
          const SizedBox(height: _sectionGap),
        ],
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: _sectionGap),
          _Section(
            header: _rangeLabel(groups[i], padded: false),
            items: groups[i].items,
          ),
        ],
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 묶음 기간 라벨 — from(과거)→to(최신). 같은 날이면 단일 날짜.
  /// [padded]=true는 배너용 "2026. 08. 28 - 08. 31", false는 섹션 헤더용
  /// "2026. 8. 28 - 8. 31".
  static String _rangeLabel(HighlightGroup group, {required bool padded}) {
    final from = group.from.toLocal();
    final to = group.to.toLocal();
    final full = DateFormat(padded ? 'yyyy. MM. dd' : 'yyyy. M. d');
    if (_isSameDay(from, to)) return full.format(from);
    final short = from.year == to.year
        ? DateFormat(padded ? 'MM. dd' : 'M. d')
        : full;
    return '${full.format(from)} - ${short.format(to)}';
  }
}

/// 도착 배너 (Figma 668:644) — bg surfaceTint r12 패딩 20, 우상단 X 44.
/// 배너 탭(X 제외) → 그 묶음 재생목록으로 플레이어.
class _ArrivalBanner extends ConsumerWidget {
  const _ArrivalBanner({required this.group, required this.onDismiss});

  final HighlightGroup group;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final representative = group.items.first;

    return GestureDetector(
      key: HighlightsScreen.bannerKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context, group, representative.clipId),
      child: Container(
        decoration: BoxDecoration(
          color: glass.surfaceTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'crecam_highlights_banner_title'.tr(),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 18 * -0.02,
                      color: glass.textPrimary, // = textStrong(#1E1E1E)
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    HighlightsScreen._rangeLabel(group, padded: true),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 14 * -0.02,
                      color: glass.textSecondary,
                    ),
                  ),
                  // Figma 실측 9 (날짜 줄끝 4312 → 썸네일 4321).
                  const SizedBox(height: 9),
                  _BannerThumbStack(clipId: representative.clipId),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: HighlightsScreen.bannerCloseKey,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close, size: 24, color: glass.textSecondary),
                  tooltip: MaterialLocalizations.of(context)
                      .closeButtonTooltip,
                  onPressed: onDismiss,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 배너 대표 썸네일 — Figma 668:648 스택 장식: 뒤에 살짝 좁은 카드(#9DA3BA,
/// 폭 290/329, h 160.5)가 위로 10.5 삐죽 보이고, 앞 이미지(폭 가득, h 161.8)가
/// 그 위에 얹힌다. 전체 프레임 329×172.3 — 치수는 프레임 폭 대비 비율로 그린다.
class _BannerThumbStack extends StatelessWidget {
  const _BannerThumbStack({required this.clipId});

  final String clipId;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return AspectRatio(
      aspectRatio: 329 / 172.3,
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth / 329; // Figma 329pt 기준 스케일
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 19.5 * s,
                right: 19.5 * s,
                height: 160.5 * s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: glass.deviceOff,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                top: 10.5 * s,
                left: 0,
                right: 0,
                height: 161.8 * s,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: _Thumbnail(clipId: clipId),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 묶음 섹션 — 헤더(16 SemiBold textSecondary) + 8 갭 + 3열 그리드
/// (Camera Home과 동일 규격: 셀 121.67:113, 갭 2, 그룹 radius 12).
class _Section extends StatelessWidget {
  const _Section({required this.header, required this.items});

  final String header;

  /// startedAt 내림차순.
  final List<NightlyHighlight> items;

  static const double _cellAspect = 121.67 / 113;
  static const double _cellGap = 2;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final rows = <List<NightlyHighlight?>>[];
    for (var i = 0; i < items.length; i += 3) {
      rows.add([
        for (var j = i; j < i + 3; j++) j < items.length ? items[j] : null,
      ]);
    }
    final rowCounts = [
      for (final row in rows) row.whereType<NightlyHighlight>().length,
    ];
    final playlist = [for (final h in items) h.clipId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          header,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 16 * -0.02,
            color: glass.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        // 셀별 노출 모서리 라운드 — Camera Home 그리드와 동일 규칙
        // (clip_grid_radius.dart, 2026-09-04 사용자 지시).
        Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _cellGap),
              Row(
                children: [
                  for (var c = 0; c < 3; c++) ...[
                    if (c > 0) const SizedBox(width: _cellGap),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: _cellAspect,
                        child: rows[r][c] == null
                            ? const SizedBox.shrink()
                            : ClipRRect(
                                borderRadius: clipGridCellRadius(
                                  row: r,
                                  col: c,
                                  rowCounts: rowCounts,
                                ),
                                child: _Cell(
                                  highlight: rows[r][c]!,
                                  playlist: playlist,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 썸네일 셀 — 탭 → 세로 플레이어(재생목록 = 그 묶음, 내림차순).
class _Cell extends StatelessWidget {
  const _Cell({required this.highlight, required this.playlist});

  final NightlyHighlight highlight;
  final List<String> playlist;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('highlight_cell_${highlight.clipId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/crecam/player/${highlight.clipId}',
          extra: playlist),
      child: _Thumbnail(clipId: highlight.clipId),
    );
  }
}

void _openPlayer(BuildContext context, HighlightGroup group, String clipId) {
  final playlist = [for (final h in group.items) h.clipId];
  context.push('/crecam/player/$clipId', extra: playlist);
}

/// terra-api presigned 썸네일 — 없음·실패 시 surfaceTint + 무비 아이콘 폴백.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.clipId});

  final String clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final thumbAsync = ref.watch(motionThumbnailProvider(clipId));

    final fallback = ColoredBox(
      color: glass.surfaceTint,
      child: Center(
        child: Icon(Icons.movie_outlined, size: 20, color: glass.textTertiary),
      ),
    );

    return thumbAsync.when(
      data: (url) => url != null
          ? CachedNetworkImage(
              imageUrl: url,
              // presign 서명이 매번 달라도 디스크 캐시가 맞도록(리뷰 2026-09-04)
              cacheKey: 'thumb_$clipId',
              fit: BoxFit.cover,
              placeholder: (_, __) => const SkeletonLoading(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
              errorWidget: (_, __, ___) => fallback,
            )
          : fallback,
      loading: () => const SkeletonLoading(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 0,
      ),
      error: (_, __) => fallback,
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 14 * -0.02,
          color: glass.textTertiary,
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'error_generic'.tr(),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: glass.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text('retry'.tr())),
        ],
      ),
    );
  }
}

/// 로딩 스켈레톤 — 배너 면 + 헤더 줄 + 3열 셀 한 그룹(shimmer, CPI 금지).
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          HighlightsScreen._margin, 12, HighlightsScreen._margin, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const AspectRatio(
          aspectRatio: 369 / 265,
          child: SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 12,
          ),
        ),
        const SizedBox(height: HighlightsScreen._sectionGap),
        const SkeletonLoading(width: 140, height: 16),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var c = 0; c < 3; c++) ...[
              if (c > 0) const SizedBox(width: _Section._cellGap),
              const Expanded(
                child: AspectRatio(
                  aspectRatio: _Section._cellAspect,
                  child: SkeletonLoading(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
