import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../home/presentation/widgets/home_header_bar.dart';
import 'my_cage_providers.dart';
import 'clip_feed_controller.dart';
import '../domain/update_day_label.dart';
import 'widgets/clip_feed_slivers.dart';
import 'widgets/camera_live_area.dart';
import '../../../shared/widgets/figma_icon.dart';

/// 카메라 탭 Camera Home — Figma 668:427 (2026-09-04 재설계 T2, 전면 재작성).
///
/// 구 카메라 그리드/리스트/뷰 토글/FAB는 폐기됐다 — 카메라 전환은 라이브
/// PageView([CameraLiveArea])가, 페어링 진입은 헤더 `[+]` 메뉴(카메라 추가)와
/// 빈 상태 카드가 맡는다.
///
/// 세로 단일 스크롤(홈과 같은 마진 12·갭 12 리듬):
/// 헤더([HomeHeaderBar]) → 라이브 → 엔트리 카드 2개(하이라이트/북마크) →
/// 기간 설정 버튼 → 시간대별 클립 그리드.
///
/// 영상 행은 지연 생성하고 라이브 헤더는 keepAlive로 연결을 보존한다.
class CrecamScreen extends ConsumerStatefulWidget {
  const CrecamScreen({super.key});

  static const highlightCardKey = Key('crecam_entry_highlights');
  static const bookmarkCardKey = Key('crecam_entry_bookmarks');
  static const periodButtonKey = Key('crecam_period_button');

  /// Figma 좌우 마진(홈 리듬 동일).
  static const double _margin = 12;

  /// 헤더→라이브·기간설정→그리드 간격(Figma 668:427 실측 12).
  static const double _gap = 12;

  /// 라이브→엔트리 카드·엔트리→기간 설정·시간 그룹 간 간격(실측 16 —
  /// 4536−4520, 4624−4608, 4947.8−4931.8. 12로 두면 전 구간이 1단씩 좁다).
  static const double _sectionGap = 16;

  @override
  ConsumerState<CrecamScreen> createState() => _CrecamScreenState();
}

class _CrecamScreenState extends ConsumerState<CrecamScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 백그라운드에서 Realtime 소켓이 죽으면 이벤트가 다시 오지 않으므로,
  // 복귀 시 provider를 재생성(재구독+재조회)해 stale 상태를 끊는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(camerasProvider);
    }
  }

  Future<void> _refresh() async {
    final query = ref.read(clipFeedQueryProvider);
    if (query != null) {
      await ref.read(clipFeedProvider(query).notifier).refresh();
    }
    if (!mounted) return;
    ref.invalidate(highlightGroupsProvider);
    ref.invalidate(allFavoriteClipsProvider);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter < 600) {
      final query = ref.read(clipFeedQueryProvider);
      if (query != null &&
          ref.read(clipFeedProvider(query)).pageError == null) {
        ref.read(clipFeedProvider(query).notifier).loadMore();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GlassTabShell(
      child: Column(
        children: [
          const Padding(
            // top 0 — Figma 668:427은 헤더가 status bar 바로 아래 선다(홈 동일).
            padding: EdgeInsets.fromLTRB(CrecamScreen._margin, 0,
                CrecamScreen._margin, CrecamScreen._gap),
            child: HomeHeaderBar(),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                onRefresh: _refresh,
                notificationPredicate: (notification) =>
                    notification.depth == 0 &&
                    notification.metrics.axis == Axis.vertical,
                child: CustomScrollView(
                  key: PageStorageKey(ref.watch(clipFeedQueryProvider)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverList(
                        delegate: SliverChildListDelegate([
                      KeepAliveCameraHeader(
                          child: Column(children: const [
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: CrecamScreen._margin),
                            child: CameraLiveArea()),
                        SizedBox(height: CrecamScreen._sectionGap),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: CrecamScreen._margin),
                            child: _EntryCards()),
                        SizedBox(height: CrecamScreen._sectionGap),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: CrecamScreen._margin),
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: _PeriodButton())),
                        SizedBox(height: CrecamScreen._gap),
                      ])),
                    ])),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: CrecamScreen._margin),
                      sliver: ClipFeedSlivers(
                          query: ref.watch(clipFeedQueryProvider)),
                    ),
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: glassDockListPadding(context).bottom)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 엔트리 카드 (하이라이트 / 북마크) ─────────────────────────────────────────

class _EntryCards extends ConsumerWidget {
  const _EntryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightAt = ref.watch(latestHighlightAtProvider);
    final bookmarkAt = ref.watch(
      allFavoriteClipsProvider.select(
        (v) =>
            v.whenData((list) => list.isEmpty ? null : list.first.favoritedAt),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: _EntryCard(
            key: CrecamScreen.highlightCardKey,
            iconAsset: FigmaIcons.cardsStar,
            title: 'crecam_home_highlights'.tr(),
            latestAt: highlightAt,
            emptyLabel: 'crecam_update_unknown'.tr(),
            onTap: () => context.push('/crecam/highlights'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _EntryCard(
            key: CrecamScreen.bookmarkCardKey,
            iconAsset: FigmaIcons.bookmarkCheck,
            title: 'crecam_home_bookmarks'.tr(),
            latestAt: bookmarkAt,
            onTap: () => context.push('/crecam/bookmarks'),
          ),
        ),
      ],
    );
  }
}

/// Figma 945:4171/4179: 최소 높이 72, 40px 진회색 아이콘 배경.
/// 긴 업데이트 문구는 가용 폭에 맞춰 축소해 한 줄로 전부 표시한다.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.latestAt,
    this.emptyLabel,
    required this.onTap,
  });

  /// Figma 원본 SVG 이름(`FigmaIcons`) — Material 근사치는 2026-09-07 교체.
  final String iconAsset;
  final String title;
  final String? emptyLabel;

  /// 최신 항목 시각. data(null) = 항목 없음("아직 없어요").
  final AsyncValue<DateTime?> latestAt;
  final VoidCallback onTap;

  /// 서브타이틀 앞에 병기할 부가 정보(예: 어젯밤 활동). null = 없음.

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Material(
      color: glass.surfaceTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: glass.textSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: FigmaIcon.tinted(iconAsset,
                        size: 24, color: glass.deviceGlyph),
                  ),
                ),
                // Figma 실측 갭 8(668:450 — 아이콘 x+40 → 텍스트 x, 906.89-898.89).
                // 12로 두면 "업데이트 4일 전"이 말줄임된다(시뮬 실측).
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
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
                      // Figma 668:457 실측 4 (제목끝 4571 → 서브 4575).
                      const SizedBox(height: 4),
                      _subtitle(glass),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subtitle(GlassPalette glass) {
    final style = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 14 * -0.02,
      color: glass.textTertiary,
    );
    return latestAt.when(
      loading: () => const SkeletonLoading(width: 72, height: 14),
      // "없음"과 구분되는 문구 — 오프라인/서버 장애를 "아직 없어요"로
      // 단정하면 상세 화면(에러+재시도)과 모순된다(리뷰 2026-09-04).
      error: (_, __) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('crecam_home_load_failed'.tr(), style: style),
      ),
      data: (at) {
        final base = at == null
            ? emptyLabel ?? 'crecam_home_no_updates'.tr()
            : _updateLabel(at);
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(base, maxLines: 1, style: style),
        );
      },
    );
  }
}

String _updateLabel(DateTime at) {
  final days = calendarDaysAgo(at, DateTime.now());
  return days <= 0
      ? 'crecam_updated_today'.tr()
      : days == 1
          ? 'crecam_updated_yesterday'.tr()
          : 'crecam_updated_days'.tr(args: ['$days']);
}

// ── 명시 기간 설정 ──
class _PeriodButton extends ConsumerWidget {
  const _PeriodButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final range = ref.watch(clipFeedRangeProvider);
    final format = DateFormat('yyyy. M. d');
    final end = range?.endExclusive.subtract(const Duration(microseconds: 1));
    final label = range == null
        ? 'crecam_home_period'.tr()
        : format.format(range.start) == format.format(end!)
            ? format.format(range.start)
            : '${format.format(range.start)} – ${format.format(end)}';
    return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (range != null)
            TextButton(
              key: const Key('crecam_clear_period'),
              onPressed: () =>
                  ref.read(clipFeedRangeProvider.notifier).state = null,
              child: Text('crecam_all_period'.tr()),
            ),
          OutlinedButton.icon(
            key: CrecamScreen.periodButtonKey,
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: glass.outline),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            icon: FigmaIcon.tinted(FigmaIcons.calendar,
                color: glass.textSecondary, size: 16),
            label: Text(label,
                style: TextStyle(
                    color: glass.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year, now.month, now.day),
                  initialDateRange: range == null
                      ? null
                      : DateTimeRange(start: range.start, end: end!));
              if (picked == null || !context.mounted) return;
              ref.read(clipFeedRangeProvider.notifier).state = (
                start: DateTime(
                    picked.start.year, picked.start.month, picked.start.day),
                endExclusive: DateTime(
                    picked.end.year, picked.end.month, picked.end.day + 1)
              );
            },
          ),
        ]);
  }
}
