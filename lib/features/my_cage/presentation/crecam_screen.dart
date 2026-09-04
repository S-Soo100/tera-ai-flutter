import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/time_ago.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../home/presentation/widgets/home_header_bar.dart';
import '../domain/motion_clip.dart';
import 'my_cage_providers.dart';
import 'widgets/camera_live_area.dart';
import 'widgets/clip_grid_radius.dart';

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
/// 스크롤은 SingleChildScrollView — ListView는 스크롤 아웃된 라이브를
/// dispose해 WebRTC 재연결(수초)이 걸린다(홈 선례).
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
    ref.invalidate(camerasProvider);
    // 부모 invalidate는 자식을 재실행시키지 않는다(리뷰 2026-09-04) —
    // 클립 목록 family를 직접 깨워야 새 클립이 온다.
    ref.invalidate(motionClipsProvider);
    ref.invalidate(crecamHourGroupsProvider);
    ref.invalidate(highlightGroupsProvider);
    ref.invalidate(allFavoriteClipsProvider);
    await ref.read(camerasProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    return GlassTabShell(
      child: Column(
        children: [
          const Padding(
            // top 0 — Figma 668:427은 헤더가 status bar 바로 아래 선다(홈 동일).
            padding: EdgeInsets.fromLTRB(
                CrecamScreen._margin, 0, CrecamScreen._margin, CrecamScreen._gap),
            child: HomeHeaderBar(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  // 플로팅 독 높이만큼 비워야 마지막 그리드가 안 가려진다.
                  bottom: glassDockListPadding(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: CrecamScreen._margin),
                      child: CameraLiveArea(),
                    ),
                    SizedBox(height: CrecamScreen._sectionGap),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: CrecamScreen._margin),
                      child: _EntryCards(),
                    ),
                    SizedBox(height: CrecamScreen._sectionGap),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: CrecamScreen._margin),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _PeriodButton(),
                      ),
                    ),
                    SizedBox(height: CrecamScreen._gap),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: CrecamScreen._margin),
                      child: _HourClipSections(),
                    ),
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
        (v) => v.whenData(
            (list) => list.isEmpty ? null : list.first.favoritedAt),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: _EntryCard(
            key: CrecamScreen.highlightCardKey,
            icon: Icons.star,
            title: 'crecam_home_highlights'.tr(),
            latestAt: highlightAt,
            onTap: () => context.push('/crecam/highlights'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _EntryCard(
            key: CrecamScreen.bookmarkCardKey,
            icon: Icons.bookmarks,
            title: 'crecam_home_bookmarks'.tr(),
            latestAt: bookmarkAt,
            onTap: () => context.push('/crecam/bookmarks'),
          ),
        ),
      ],
    );
  }
}

/// 엔트리 카드 한 장 — 홈 제어 타일(_DeviceTile)과 같은 문법: h72, bg
/// surfaceTint radius 12, 패딩 16, 좌 40 원(deviceOff) 안 아이콘 24.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.latestAt,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// 최신 항목 시각. data(null) = 항목 없음("아직 없어요").
  final AsyncValue<DateTime?> latestAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Material(
      color: glass.surfaceTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: glass.deviceOff,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 24, color: glass.deviceGlyph),
                ),
                // Figma 실측 갭 8(668:450 — 아이콘 x+40 → 텍스트 x, 906.89-898.89).
                // 12로 두면 "업데이트 4일 전"이 말줄임된다(시뮬 실측).
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 2),
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
      error: (_, __) => Text('crecam_home_load_failed'.tr(),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      data: (at) => Text(
        at == null
            ? 'crecam_home_no_updates'.tr()
            : 'crecam_home_updated'.tr(args: [timeAgo(at)]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

// ── 기간 설정 ──────────────────────────────────────────────────────────────────

class _PeriodButton extends ConsumerWidget {
  const _PeriodButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final day = ref.watch(crecamDayProvider);
    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    final label = isToday
        ? 'crecam_home_period'.tr()
        : DateFormat('yyyy. M. d').format(day);

    return Material(
      // 라이트=흰 바닥 위 흰 버튼(스트로크로만 선다), 다크=바닥색 + 스트로크.
      color: glass.wallpaper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: glass.outline),
      ),
      child: InkWell(
        key: CrecamScreen.periodButtonKey,
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pick(context, ref, day),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: glass.textSecondary),
                // Figma 실측 갭 4 (958.39 − 954.39).
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 14 * -0.02,
                    color: glass.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(
      BuildContext context, WidgetRef ref, DateTime current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
    );
    if (picked == null || !context.mounted) return;
    ref.read(crecamDayProvider.notifier).state =
        DateTime(picked.year, picked.month, picked.day); // 자정 정규화
  }
}

// ── 시간대별 클립 그리드 ───────────────────────────────────────────────────────

class _HourClipSections extends ConsumerWidget {
  const _HourClipSections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final groupsAsync = ref.watch(crecamHourGroupsProvider);
    final day = ref.watch(crecamDayProvider);

    return groupsAsync.when(
      loading: () => const _SectionsSkeleton(),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
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
            OutlinedButton(
              onPressed: () {
                // 하위 클립 family까지 — 부모만 깨우면 캐시가 그대로다.
                ref.invalidate(motionClipsProvider);
                ref.invalidate(crecamHourGroupsProvider);
              },
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'crecam_home_empty_day'.tr(),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 14 * -0.02,
                  color: glass.textTertiary,
                ),
              ),
            ),
          );
        }
        // 재생목록 = 그 날짜 전체 클립(시간 내림차순 — 그룹·그룹 내 정렬 그대로).
        final playlist = [
          for (final g in groups)
            for (final c in g.clips) c.id,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: CrecamScreen._sectionGap),
              _HourSection(
                group: groups[i],
                // 날짜는 첫 그룹만(Figma) — 아래로는 같은 날짜의 반복이다.
                dateLabel:
                    i == 0 ? DateFormat('yyyy. M. d').format(day) : null,
                playlist: playlist,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HourSection extends StatelessWidget {
  const _HourSection({
    required this.group,
    required this.dateLabel,
    required this.playlist,
  });

  final CrecamHourGroup group;
  final String? dateLabel;
  final List<String> playlist;

  /// Figma 셀 실측 121.67×113.
  static const double _cellAspect = 121.67 / 113;
  static const double _cellGap = 2;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final rows = <List<MotionClip?>>[];
    for (var i = 0; i < group.clips.length; i += 3) {
      final row = <MotionClip?>[
        for (var j = i; j < i + 3; j++)
          j < group.clips.length ? group.clips[j] : null,
      ];
      rows.add(row);
    }
    final rowCounts = [
      for (final row in rows) row.whereType<MotionClip>().length,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _hourLabel(group.hour),
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
            ),
            if (dateLabel != null)
              Text(
                dateLabel!,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 14 * -0.02,
                  color: glass.textTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 그룹 전체 ClipRRect 대신 **셀별 노출 모서리 라운드** — 마지막 행이
        // 부분만 차거나 클립이 1개뿐일 때도 바깥 모서리가 전부 둥글다
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
                                child: _ClipCell(
                                  clip: rows[r][c]!,
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

  /// "오전 8:00" — intl ko 로케일 미초기화라 오전/오후는 l10n 키로 직접 조합
  /// (T1 _timeLabel과 같은 이유).
  static String _hourLabel(DateTime hour) {
    final period =
        hour.hour < 12 ? 'crecam_player_am'.tr() : 'crecam_player_pm'.tr();
    var h = hour.hour % 12;
    if (h == 0) h = 12;
    return '$period $h:00';
  }
}

/// 썸네일 셀 — terra-api presigned 썸네일(없으면 회색 폴백). 탭 → 세로
/// 플레이어(재생목록 = 그 날짜 전체, 시간 내림차순).
class _ClipCell extends ConsumerWidget {
  const _ClipCell({required this.clip, required this.playlist});

  final MotionClip clip;
  final List<String> playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final thumbAsync = ref.watch(motionThumbnailProvider(clip.id));

    final fallback = ColoredBox(
      color: glass.overlayFaint,
      child: Center(
        child: Icon(Icons.videocam_rounded,
            size: 20, color: glass.textTertiary),
      ),
    );

    final thumb = thumbAsync.when(
      data: (url) => url != null
          ? CachedNetworkImage(
              imageUrl: url,
              // presign 서명이 매번 달라도 디스크 캐시가 맞도록(리뷰 2026-09-04)
              cacheKey: 'thumb_${clip.id}',
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

    return GestureDetector(
      key: ValueKey('crecam_clip_${clip.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.push('/crecam/player/${clip.id}', extra: playlist),
      child: thumb,
    );
  }
}

/// 로딩 스켈레톤 — 헤더 줄 + 3열 셀 한 그룹(shimmer, CPI 금지).
class _SectionsSkeleton extends StatelessWidget {
  const _SectionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLoading(width: 96, height: 16),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var c = 0; c < 3; c++) ...[
              if (c > 0) const SizedBox(width: 2),
              const Expanded(
                child: AspectRatio(
                  aspectRatio: _HourSection._cellAspect,
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
