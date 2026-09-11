import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/highlight_group.dart';
import '../domain/nightly_highlight.dart';
import 'highlights_controller.dart';
import 'my_cage_providers.dart';
import 'widgets/clip_grid.dart';
import 'widgets/crecam_states.dart';
import 'widgets/favorite_bookmark_badge.dart';
import 'widgets/motion_clip_thumb.dart';
import 'widgets/crecam_detail_top_bar.dart';

/// 하이라이트 날짜 필터(startedAt 기준, 자정 경계). null = 전체(묶음 보기).
/// autoDispose — 화면 이탈 시 리셋.
final highlightsDayFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

/// 후보를 펼쳐 둔 day_key 집합. autoDispose — 화면 이탈 시 접힘으로 리셋.
final expandedCandidateDaysProvider =
    StateProvider.autoDispose<Set<String>>((ref) => const {});

/// 하이라이트 상세 — 하루(20:00 KST 경계, 서버 day_key) 묶음 보기.
///
/// 2026-09-11 `/highlights/featured` 전환: 묶음([highlightGroupsProvider])은
/// 서버 day_key 그대로, 기본은 ⭐ 대표 카드만 보이고 후보는 하루마다
/// "후보 N개 더 보기"로 접는다. 최신 묶음 도착 배너(dismiss는 Hive
/// `app_settings`에 그룹 key 저장 — 같은 묶음은 재방문에도 숨김)는 유지.
/// 날짜 필터 중엔 묶음 대신 그 날짜의 하이라이트만 평면 그리드 1섹션.
/// 행동 필터는 만들지 않는다(Figma 정책 노트 — 이 계약에 행동 이름이 없다).
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  /// 테스트용 — 도착 배너·닫기 버튼 식별.
  static const bannerKey = Key('crecam_highlight_banner');
  static const bannerCloseKey = Key('crecam_highlight_banner_close');

  /// 테스트용 — 묶음별 "후보 N개 더 보기" 토글.
  static Key moreCandidatesKey(String dayKey) =>
      ValueKey('highlight_more_$dayKey');

  /// Figma 콘텐츠 좌우 마진·섹션 간격.
  static const double _margin = 12;
  static const double _sectionGap = 24;
  static const double _groupGap = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final groupsAsync = ref.watch(highlightGroupsProvider);
    final day = ref.watch(highlightsDayFilterProvider);
    final dismissedKey = ref.watch(highlightBannerDismissedProvider);

    return Scaffold(
      backgroundColor: glass.wallpaper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Figma Rectangle 113 — status bar까지 surfaceHeader + 헤어라인.
          CrecamDetailHeaderArea(
            child: CrecamDetailTopBar(
              title: 'crecam_highlights_title'.tr(),
              onCalendarTap: () => _pickDay(context, ref, day),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (day != null)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(_margin, 8, _margin, 0),
                      child: CrecamDateFilterChip(
                        day: day,
                        onClear: () => ref
                            .read(highlightsDayFilterProvider.notifier)
                            .state = null,
                      ),
                    ),
                  Expanded(
                    child: groupsAsync.when(
                      loading: () => const _Skeleton(),
                      error: (_, __) => CrecamErrorRetry(
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
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(
      BuildContext context, WidgetRef ref, DateTime? current) async {
    final picked = await showCrecamDayPicker(context, current);
    if (picked == null || !context.mounted) return;
    ref.read(highlightsDayFilterProvider.notifier).state = picked;
  }

  /// 날짜 필터 뷰 — 그 날짜(startedAt 자정 경계)의 대표+후보 평면 그리드 1섹션.
  Widget _dayView(
      BuildContext context, List<DayHighlightGroup> groups, DateTime day) {
    final items = [
      for (final g in groups)
        for (final h in [...g.featured, ...g.candidates])
          if (_isSameDay(h.startedAt.toLocal(), day)) h,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (items.isEmpty) {
      return CrecamEmptyMessage(message: 'crecam_home_empty_day'.tr());
    }
    final playlist = [for (final h in items) h.clipId];
    return ListView(
      padding: const EdgeInsets.fromLTRB(_margin, 24, _margin, 24),
      children: [
        _sectionHeader(context, DateFormat('yyyy. M. d').format(day)),
        const SizedBox(height: 8),
        ClipGrid<NightlyHighlight>(
          items: items,
          cellBuilder: (h) => _Cell(highlight: h, playlist: playlist),
        ),
      ],
    );
  }

  /// 기본 뷰 — 도착 배너(최신 묶음, 미dismiss 시) + day_key 묶음 섹션들.
  Widget _groupView(BuildContext context, WidgetRef ref,
      List<DayHighlightGroup> groups, String? dismissedKey) {
    if (groups.isEmpty) {
      return CrecamEmptyMessage(message: 'crecam_highlights_empty'.tr());
    }
    final now = DateTime.now();
    final newest = groups.first;
    final showBanner = dismissedKey != highlightGroupKey(newest);

    return ListView(
      // Figma 실측: 배너가 있으면 상단바→배너 12(668:600), 없으면
      // 상단바→첫 섹션 24(668:655).
      padding: EdgeInsets.fromLTRB(_margin, showBanner ? 12 : 24, _margin, 24),
      children: [
        if (showBanner) ...[
          _ArrivalBanner(
            group: newest,
            label: nightLabel(newest.dayKey, now),
            onDismiss: () => ref
                .read(highlightBannerDismissedProvider.notifier)
                .dismiss(highlightGroupKey(newest)),
          ),
          const SizedBox(height: _sectionGap),
        ],
        for (var i = 0; i < groups.length; i++) ...[
          // 그룹 간 20 (Figma 668:655 실측 4517→4537 — 배너 아래 24와 다르다).
          if (i > 0) const SizedBox(height: _groupGap),
          _Section(group: groups[i], now: now),
        ],
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 묶음 헤더 라벨 — 어젯밤 day_key([lastNightDayKey])면 "어젯밤", 그 전날이면
  /// "그저께 밤", 나머지는 "9월 8일 밤"(20:00 경계라 "밤"이 맞다).
  static String nightLabel(String dayKey, DateTime now) {
    final lastKey = lastNightDayKey(now);
    if (dayKey == lastKey) return 'crecam_highlights_last_night'.tr();
    final date = parseDayKey(dayKey);
    if (date == null) return dayKey; // 방어 — 서버 계약 밖 형식은 원문 표시
    final last = parseDayKey(lastKey)!;
    if (date == last.subtract(const Duration(days: 1))) {
      return 'crecam_highlights_prev_night'.tr();
    }
    return 'crecam_highlights_night_of'
        .tr(namedArgs: {'month': '${date.month}', 'day': '${date.day}'});
  }

  static Widget _sectionHeader(BuildContext context, String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 16 * -0.02,
        color: context.glass.textSecondary,
      ),
    );
  }
}

/// 도착 배너 (Figma 668:644) — bg surfaceTint r12 패딩 20, 우상단 X 44.
/// 배너 탭(X 제외) → 그 묶음 대표 재생목록으로 플레이어(대표 1위부터).
class _ArrivalBanner extends ConsumerWidget {
  const _ArrivalBanner({
    required this.group,
    required this.label,
    required this.onDismiss,
  });

  final DayHighlightGroup group;
  final String label;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    // 대표 1위(방어: 대표가 없으면 최신 후보)가 배너 얼굴.
    final representative =
        group.featured.isNotEmpty ? group.featured.first : group.candidates.first;
    final playlist = [
      for (final h in group.featured.isNotEmpty ? group.featured : group.candidates)
        h.clipId,
    ];

    return GestureDetector(
      key: HighlightsScreen.bannerKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context, representative.clipId, playlist),
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
                    label,
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
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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
                  child: MotionClipThumb(clipId: clipId),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// day_key 묶음 섹션 — 헤더("어젯밤" 등) + ⭐ 대표 카드(rank 순, 카메라가
/// 여러 대면 카메라별 top_n) + "후보 N개 더 보기" 토글(후보 0이면 없음).
class _Section extends ConsumerWidget {
  const _Section({required this.group, required this.now});

  final DayHighlightGroup group;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded =
        ref.watch(expandedCandidateDaysProvider).contains(group.dayKey);
    final featuredPlaylist = [for (final h in group.featured) h.clipId];
    final candidatePlaylist = [for (final h in group.candidates) h.clipId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HighlightsScreen._sectionHeader(
            context, HighlightsScreen.nightLabel(group.dayKey, now)),
        const SizedBox(height: 8),
        for (final h in group.featured) ...[
          _FeaturedCard(highlight: h, playlist: featuredPlaylist),
          const SizedBox(height: 12),
        ],
        if (group.candidates.isNotEmpty) ...[
          _MoreCandidatesButton(
            dayKey: group.dayKey,
            count: group.candidates.length,
            expanded: expanded,
            onTap: () {
              final s = ref.read(expandedCandidateDaysProvider);
              ref.read(expandedCandidateDaysProvider.notifier).state =
                  expanded ? ({...s}..remove(group.dayKey)) : {...s, group.dayKey};
            },
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            ClipGrid<NightlyHighlight>(
              items: group.candidates,
              cellBuilder: (h) =>
                  _Cell(highlight: h, playlist: candidatePlaylist),
            ),
          ],
        ],
      ],
    );
  }
}

/// ⭐ 대표 카드 — 썸네일(16:9) + 시각.
/// 탭 → 세로 플레이어(재생목록 = 그 묶음 대표, rank 순).
///
/// 순위·움직임·클립 수 배지와 판정 사유·사람 확정 체크는 **표시하지 않는다**
/// (2026-09-11 사용자 지시 — 규칙 진단 정보는 관리자 라벨러 웹 몫, 고객
/// 화면에는 내부 판정 문구를 노출하지 않는다). 데이터 자체는 도메인에 남아
/// 정렬(rank)에만 쓰인다.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.highlight, required this.playlist});

  final NightlyHighlight highlight;
  final List<String> playlist;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;

    return GestureDetector(
      key: ValueKey('highlight_featured_${highlight.clipId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context, highlight.clipId, playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MotionClipThumb(clipId: highlight.clipId),
                  // Figma 668:679 — 즐겨찾기한 하이라이트는 좌하단 북마크 표시.
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: FavoriteBookmarkBadge(clipId: highlight.clipId),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('HH:mm').format(highlight.startedAt.toLocal()),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: glass.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "후보 N개 더 보기" / "후보 접기" 토글 버튼.
class _MoreCandidatesButton extends StatelessWidget {
  const _MoreCandidatesButton({
    required this.dayKey,
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final String dayKey;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return GestureDetector(
      key: HighlightsScreen.moreCandidatesKey(dayKey),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: glass.surfaceTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded
                  ? 'crecam_highlights_less_candidates'.tr()
                  : 'crecam_highlights_more_candidates'
                      .tr(namedArgs: {'n': '$count'}),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 14 * -0.02,
                color: glass.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: glass.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 후보 썸네일 셀 — 탭 → 세로 플레이어(재생목록 = 그 묶음 후보, 시간 내림차순).
class _Cell extends StatelessWidget {
  const _Cell({required this.highlight, required this.playlist});

  final NightlyHighlight highlight;
  final List<String> playlist;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('highlight_cell_${highlight.clipId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context, highlight.clipId, playlist),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MotionClipThumb(clipId: highlight.clipId),
          // Figma 668:679 — 즐겨찾기한 하이라이트는 좌하단 북마크 표시.
          Positioned(
            left: 0,
            bottom: 0,
            child: FavoriteBookmarkBadge(clipId: highlight.clipId),
          ),
        ],
      ),
    );
  }
}

void _openPlayer(BuildContext context, String clipId, List<String> playlist) {
  context.push('/crecam/player/$clipId', extra: playlist);
}

/// 로딩 스켈레톤 — 배너 면 + 헤더 줄 + 대표 카드 한 장(shimmer, CPI 금지).
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          HighlightsScreen._margin, 12, HighlightsScreen._margin, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        AspectRatio(
          aspectRatio: 369 / 265,
          child: SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 12,
          ),
        ),
        SizedBox(height: HighlightsScreen._sectionGap),
        SkeletonLoading(width: 140, height: 16),
        SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 12,
          ),
        ),
        SizedBox(height: 8),
        SkeletonLoading(width: 200, height: 14),
      ],
    );
  }
}
