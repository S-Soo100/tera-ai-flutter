import '../../auth/presentation/auth_providers.dart';
import 'highlight_read_providers.dart';
import '../../../shared/widgets/figma_icon.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/highlight_group.dart';
import '../domain/highlight_publication.dart';
import '../domain/nightly_highlight.dart';
import 'clip_playlist_player_screen.dart';
import 'my_cage_providers.dart';
import 'clip_visibility_providers.dart';
import 'widgets/clip_grid.dart';
import 'widgets/crecam_states.dart';
import 'widgets/favorite_bookmark_badge.dart';
import 'widgets/motion_clip_thumb.dart';
import 'widgets/crecam_detail_top_bar.dart';

/// 하이라이트 날짜 필터(startedAt 기준, 자정 경계). null = 전체(묶음 보기).
/// autoDispose — 화면 이탈 시 리셋.
final highlightsDayFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

/// 하이라이트 상세 — 하루(20:00 KST 경계, 서버 day_key) 묶음 보기.
///
/// 2026-09-16 Figma 1081:5235(P12): 묶음은 날짜(공개 배치의 실제 촬영 구간)
/// 헤더 + **3열 연속 그리드**(Camera Home과 같은 [ClipGrid])다. 전폭 대표
/// 카드·시각 라벨은 원본에 없어 뺐다. 재생 순서(rank)·play_from_sec·읽음
/// 처리·배너 dismiss는 그대로다.
///
/// 2026-09-11 `/highlights/featured` 전환: 묶음([highlightGroupsProvider])은
/// 서버 day_key 그대로, **⭐ 대표만** 보여준다. 후보는 화면에서 완전히 뺐다
/// (2026-09-11 사용자 지시 — "후보 더 보기"도 노출하지 않는다. 조회 자체를
/// tier=featured로 좁혔으므로 후보 데이터는 애초에 받지 않는다). 최신 묶음
/// 도착 배너(dismiss는 Hive `app_settings`에 그룹 key 저장 — 같은 묶음은
/// 재방문에도 숨김)는 유지. 날짜 필터 중엔 묶음 대신 그 날짜의 대표만 평면
/// 그리드 1섹션. 행동 필터는 만들지 않는다(Figma 정책 노트).
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  /// 테스트용 — 도착 배너·닫기 버튼 식별.
  static const bannerKey = Key('crecam_highlight_banner');
  static const bannerCloseKey = Key('crecam_highlight_banner_close');

  /// Figma 콘텐츠 좌우 마진·섹션 간격.
  static const double _margin = 12;
  static const double _sectionGap = 24;
  static const double _groupGap = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clipVisibilityEntryRefreshProvider('highlights'));
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
                      // 진입 직후 숨김 목록 갱신이 이 목록을 다시 계산한다 — 그동안
                      // 이전 목록을 유지해야 스켈레톤 깜빡임·스크롤 초기화가 없다.
                      skipLoadingOnReload: true,
                      loading: () => const _Skeleton(),
                      error: (_, __) => CrecamErrorRetry(
                        onRetry: () {
                          ref.invalidate(
                              clipVisibilityEntryRefreshProvider('highlights'));
                          ref.invalidate(highlightGroupsProvider);
                        },
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

  /// 날짜 필터 뷰 — 그 날짜(startedAt 자정 경계)의 대표 평면 그리드 1섹션.
  Widget _dayView(
      BuildContext context, List<DayHighlightGroup> groups, DateTime day) {
    final items = [
      for (final g in groups)
        for (final h in g.featured)
          if (_isSameDay(h.startedAt.toLocal(), day)) h,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (items.isEmpty) {
      return CrecamEmptyMessage(message: 'crecam_home_empty_day'.tr());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(_margin, 24, _margin, 24),
      children: [
        _sectionHeader(context, DateFormat('yyyy. M. d').format(day)),
        const SizedBox(height: 8),
        ClipGrid<NightlyHighlight>(
          items: items,
          cellBuilder: (h) => _Cell(highlight: h, playlist: items),
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
    final owner = ref.watch(currentUserProvider)?.id ?? '';
    final published = [for (final group in groups) ...group.featured]
        .where((h) =>
            h.cameraId.isNotEmpty && h.publication?.availableAt(now) == true)
        .toList();
    // 카메라 탭 카드("새 하이라이트")와 같은 기준 — 갈라지면 두 곳이 다른 묶음을 본다.
    final latest = latestPublishedHighlight(groups, now);
    final publication = latest?.publication;
    final newest = latest == null
        ? groups.first
        : (
            dayKey: latest.dayKey,
            featured: published
                .where((h) =>
                    h.cameraId == latest.cameraId &&
                    h.publication!.batchId == publication!.batchId)
                .toList(),
            candidates: <NightlyHighlight>[],
          );
    final batchKey =
        latest == null ? '' : '${latest.cameraId}/${publication!.batchId}';
    final isRead = latest != null &&
        ref.watch(highlightReadProvider((
          ownerId: owner,
          cameraId: latest.cameraId,
          batchId: publication!.batchId
        )));
    final showBanner = latest != null && !isRead && dismissedKey != batchKey;

    return ListView(
      // Figma 실측: 배너가 있으면 상단바→배너 12(668:600), 없으면
      // 상단바→첫 섹션 24(668:655).
      padding: EdgeInsets.fromLTRB(_margin, showBanner ? 12 : 24, _margin, 24),
      children: [
        if (showBanner) ...[
          _ArrivalBanner(
            group: newest,
            label: periodLabel(newest, now),
            onDismiss: () => ref
                .read(highlightBannerDismissedProvider.notifier)
                .dismiss(batchKey),
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

  /// 묶음 헤더 라벨 — 전날 시작한 밤 묶음은 도착 당일 내내 "어젯밤",
  /// 이틀 전은 "그저께 밤", 나머지는 "9월 8일 밤"으로 표시한다.
  /// 서버 day_key는 20:00 기준의 **밤 시작 날짜**지만, 표시 기준까지 20시에
  /// 넘기면 같은 묶음이 저녁에 갑자기 "그저께 밤"으로 바뀐다.
  static String nightLabel(String dayKey, DateTime now) {
    final date = parseDayKey(dayKey);
    if (date == null) return dayKey; // 방어 — 서버 계약 밖 형식은 원문 표시
    final today = DateTime(now.year, now.month, now.day);
    final lastNight = today.subtract(const Duration(days: 1));
    if (_isSameDay(date, lastNight)) {
      return 'crecam_highlights_last_night'.tr();
    }
    if (_isSameDay(date, lastNight.subtract(const Duration(days: 1)))) {
      return 'crecam_highlights_prev_night'.tr();
    }
    return 'crecam_highlights_night_of'
        .tr(namedArgs: {'month': '${date.month}', 'day': '${date.day}'});
  }

  /// 묶음·배너 날짜 — 공개 배치의 **실제 촬영 구간**(`capture_start~end`)이
  /// 있을 때만 "2026. 8. 28 - 8. 31"(Figma 1081:5235) 서식으로 그린다. 없으면
  /// 밤 라벨([nightLabel])로 남긴다 — 원본 예시 날짜를 고정하거나 배치를
  /// 합성하지 않는다.
  static String periodLabel(DayHighlightGroup group, DateTime now) {
    final publication = group.featured
        .map((h) => h.publication)
        .whereType<HighlightPublication>()
        .firstOrNull;
    if (publication == null) return nightLabel(group.dayKey, now);
    return formatPeriod(
        publication.captureStart.toLocal(), publication.captureEnd.toLocal());
  }

  /// `2026. 8. 28 - 8. 31` / 같은 날이면 `2026. 8. 31` / 해가 다르면 둘 다 연도.
  static String formatPeriod(DateTime start, DateTime end) {
    final s = DateFormat('yyyy. M. d').format(start);
    if (_isSameDay(start, end)) return s;
    final e = start.year == end.year
        ? DateFormat('M. d').format(end)
        : DateFormat('yyyy. M. d').format(end);
    return '$s - $e';
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
        height: 19.09375 / 16,
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
    final playlist =
        group.featured.isNotEmpty ? group.featured : group.candidates;
    final representative = playlist.first;

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
                    // Figma 1081:5235 — 18/700 lh21.48, 14/500 lh16.7. 폰트
                    // 기본 행간을 두면 배너가 8 늘어난다(2026-09-16 실측).
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 21.48046875 / 18,
                      letterSpacing: 18 * -0.02,
                      color: glass.mediaTitle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 16.70703125 / 14,
                      letterSpacing: 14 * -0.02,
                      color: glass.mediaMeta,
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
                  icon: FigmaIcon.tinted(FigmaIcons.close,
                      size: 24, color: glass.textSecondary),
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

/// day_key 묶음 섹션 — 날짜 헤더(16/600, Figma 1081:5235 y405.3) + 8 + ⭐ 대표
/// 3열 그리드(rank 순, 셀 121.67×113·갭 2·바깥 모서리 r12). 후보는 그리지
/// 않는다(2026-09-11). 순위·움직임·클립 수 배지와 판정 사유는 표시하지
/// 않는다(2026-09-11 사용자 지시) — 데이터는 정렬(rank)에만 쓴다.
class _Section extends StatelessWidget {
  const _Section({required this.group, required this.now});

  final DayHighlightGroup group;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HighlightsScreen._sectionHeader(
            context, HighlightsScreen.periodLabel(group, now)),
        const SizedBox(height: 8),
        ClipGrid<NightlyHighlight>(
          items: group.featured,
          cellBuilder: (h) => _Cell(
              highlight: h,
              playlist: group.featured,
              keyPrefix: 'highlight_featured_'),
        ),
      ],
    );
  }
}

/// 그리드 썸네일 셀(묶음·날짜 필터 공용) — 탭 → 세로 플레이어(재생목록 =
/// 그 묶음 대표 rank 순 / 그 날짜의 대표 시간 내림차순).
class _Cell extends StatelessWidget {
  const _Cell(
      {required this.highlight,
      required this.playlist,
      this.keyPrefix = 'highlight_cell_'});

  final NightlyHighlight highlight;
  final List<NightlyHighlight> playlist;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('$keyPrefix${highlight.clipId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context, highlight.clipId, playlist),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MotionClipThumb(
              clipId: highlight.clipId, cameraId: highlight.cameraId),
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

void _openPlayer(
    BuildContext context, String clipId, List<NightlyHighlight> playlist) {
  // 재생목록과 함께 클립별 서버 재생 시작점(play_from_sec)을 넘긴다 —
  // 값이 없는 클립은 0초부터(기존 동작).
  final selected = playlist.where((h) => h.clipId == clipId).first;
  final publication = selected.publication;
  final scoped = publication == null
      ? playlist
      : playlist
          .where((h) =>
              h.cameraId == selected.cameraId &&
              h.publication?.batchId == publication.batchId)
          .toList();
  context.push(
    '/crecam/player/$clipId',
    extra: ClipPlaylistArgs(
      source: ClipPlaybackSource.highlight,
      cameraId: selected.cameraId,
      highlightBatchId: publication?.availableAt(DateTime.now()) == true
          ? publication?.batchId
          : null,
      playlist: [for (final h in scoped) h.clipId],
      playFromSec: {
        for (final h in scoped)
          if (h.playFromSec != null) h.clipId: h.playFromSec!,
      },
    ),
  );
}

/// 로딩 스켈레톤 — 배너 면 + 헤더 줄 + 그리드 한 줄(shimmer, CPI 금지).
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
          aspectRatio: 369 / 113,
          child: SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 12,
          ),
        ),
      ],
    );
  }
}
