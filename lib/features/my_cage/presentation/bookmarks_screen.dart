import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/am_pm_time.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/favorite_clip.dart';
import '../domain/player_entry.dart';
import '../domain/recording_item.dart';
import 'live_recording_actions.dart';
import 'live_recording_upload_queue.dart';
import 'recording_library_providers.dart';
import 'widgets/player_entry_thumb.dart';
import 'widgets/recording_badges.dart';
import 'my_cage_providers.dart';
import 'clip_visibility_providers.dart';
import 'clip_memo_providers.dart';
import 'widgets/clip_memo_card.dart';
import 'widgets/crecam_detail_top_bar.dart';
import 'widgets/crecam_states.dart';
import 'widgets/motion_clip_thumb.dart';
import 'clip_selection_providers.dart';
import 'widgets/clip_selection_flow.dart';
import 'widgets/clip_selection_widgets.dart';

const _scope = ClipSelectionScope.bookmarks;

/// 북마크 날짜 필터(클립 startedAt 기준, 자정 경계). null = 전체.
/// autoDispose — 화면 이탈 시 리셋.
final bookmarksDayFilterProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);

/// 북마크 상세 (Figma 668:717, 카메라 탭 재설계 T3).
///
/// 세로 리스트: 카드 = 시각 헤더 + 풀폭 썸네일(369:180). 데이터는
/// [allFavoriteClipsProvider](favoritedAt desc — repository 정렬 그대로),
/// 표시 시각은 클립 startedAt. 카드 탭 → 세로 플레이어(재생목록 = 현재
/// 필터·정렬 순서의 북마크 전체).
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  /// Figma 콘텐츠 좌우 마진.
  static const double _margin = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clipVisibilityEntryRefreshProvider('bookmarks'));
    final glass = context.glass;
    final favoritesAsync = ref.watch(allFavoriteClipsProvider);
    final day = ref.watch(bookmarksDayFilterProvider);
    // 직접 녹화(2026-10-01) — 이 폰 녹화 + 서버 녹화(다른 폰·재설치 전,
    // 2026-10-21 F단계)를 북마크와 같은 목록에 시각순으로.
    final recordings =
        ref.watch(recordingLibraryProvider).valueOrNull ?? const [];
    // 보관함 진입 = 업로드 대기열 깨우기(한도로 멈춘 녹화 재평가 포함).
    ref.watch(liveRecordingBookmarksEntryProvider);
    final selection = ref.watch(clipSelectionProvider(_scope));
    final batch = ref.watch(clipBatchProvider(_scope));
    final flow = ClipSelectionFlow(ref, _scope);
    // 날짜 필터가 바뀌면 안 보이게 된 영상이 골라진 채 남지 않게 비운다.
    ref.listen(bookmarksDayFilterProvider, (_, __) {
      ref.read(clipSelectionProvider(_scope).notifier).clearIds();
    });
    Future<void> leave() async {
      if (await flow.confirmLeave(context) && context.mounted) context.pop();
    }

    final scaffold = Scaffold(
      backgroundColor: glass.wallpaper,
      // Figma 1493:9274 — 선택 모드엔 아래에 선택 동작 바.
      bottomNavigationBar: selection.active
          ? flow.actionBar(context,
              all: () => [
                    for (final o in _order(
                        ref.read(allFavoriteClipsProvider).valueOrNull ??
                            const [],
                        ref.read(recordingLibraryProvider).valueOrNull ??
                            const [],
                        ref.read(bookmarksDayFilterProvider)))
                      if (o.selectable) o.key
                  ])
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Figma Rectangle 113 — status bar까지 surfaceHeader + 헤어라인.
          CrecamDetailHeaderArea(
            child: CrecamDetailTopBar(
              title: selection.active
                  ? 'clip_select_count'
                      .tr(namedArgs: {'count': '${selection.count}'})
                  : 'crecam_bookmarks_title'.tr(),
              onCalendarTap: () => _pickDay(context, ref, day),
              onBack: selection.active ? leave : null,
              trailing: selection.active
                  ? ClipSelectHeaderButton.exit(
                      onPressed: () => ref
                          .read(clipSelectionProvider(_scope).notifier)
                          .exit())
                  : ClipSelectHeaderButton.enter(
                      onPressed: () => ref
                          .read(clipSelectionProvider(_scope).notifier)
                          .enter()),
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
                            .read(bookmarksDayFilterProvider.notifier)
                            .state = null,
                      ),
                    ),
                  Expanded(
                    child: favoritesAsync.when(
                      // 진입 직후 숨김 목록 갱신이 이 목록을 다시 계산한다 — 그동안
                      // 이전 목록을 유지해야 스켈레톤 깜빡임·스크롤 초기화가 없다.
                      skipLoadingOnReload: true,
                      loading: () => const _ListSkeleton(),
                      error: (_, __) => CrecamErrorRetry(
                        onRetry: () {
                          ref.invalidate(
                              clipVisibilityEntryRefreshProvider('bookmarks'));
                          ref.invalidate(allFavoriteClipsProvider);
                        },
                      ),
                      data: (favorites) =>
                          _list(context, favorites, recordings, day),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return ClipSelectionBackGuard(
      scope: _scope,
      onLeave: leave,
      child: Stack(children: [
        scaffold,
        if (batch != null)
          ClipBatchOverlay(
              job: batch,
              onCancel: ref.read(clipBatchProvider(_scope).notifier).cancel),
      ]),
    );
  }

  /// 화면에 보이는 순서(북마크한 최신순 + 날짜 필터).
  static List<FavoriteClip> _visible(
      List<FavoriteClip> favorites, DateTime? day) {
    final sorted = [...favorites]
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
    return day == null
        ? sorted
        : sorted.where((f) {
            final t = f.startedAt.toLocal();
            return t.year == day.year &&
                t.month == day.month &&
                t.day == day.day;
          }).toList();
  }

  Future<void> _pickDay(
      BuildContext context, WidgetRef ref, DateTime? current) async {
    final picked = await showCrecamDayPicker(context, current);
    if (picked == null || !context.mounted) return;
    ref.read(bookmarksDayFilterProvider.notifier).state = picked;
  }

  /// 화면 순서 — 북마크(북마크한 시각)와 직접 녹화(찍은 시각)를 최신순으로
  /// 섞는다. 날짜 필터는 둘 다 찍은 날 기준.
  static List<({DateTime at, Object item, String key, bool selectable})>
      _order(List<FavoriteClip> favorites, List<RecordingItem> recordings,
          DateTime? day) {
    bool sameDay(DateTime t) {
      final l = t.toLocal();
      return day == null ||
          (l.year == day.year && l.month == day.month && l.day == day.day);
    }

    return [
      for (final f in _visible(favorites, day))
        (
          at: f.favoritedAt,
          item: f,
          key: ClipEntry(f.clipId).key,
          selectable: true
        ),
      for (final r in recordings)
        if (sameDay(r.startedAt))
          // 올리는 중인 녹화는 고를 수 없다(2026-10-21 사용자 결정).
          (at: r.startedAt, item: r, key: r.key, selectable: !r.uploading),
    ]..sort((a, b) => b.at.compareTo(a.at));
  }

  Widget _list(BuildContext context, List<FavoriteClip> favorites,
      List<RecordingItem> recordings, DateTime? day) {
    final order = _order(favorites, recordings, day);

    if (order.isEmpty) {
      // 북마크 자체가 없으면 기존 즐겨찾기 빈 문구, 필터 결과만 없으면 날짜 문구.
      return CrecamEmptyMessage(
        message: favorites.isEmpty && recordings.isEmpty
            ? 'clip_favorites_empty'.tr()
            : 'crecam_home_empty_day'.tr(),
      );
    }

    // 재생목록 = 화면과 같은 순서의 항목 키 — 플레이어의 이전/다음·필름스트립이
    // 북마크 영상과 직접 녹화(`rec:<id>`·`rec:srv:<id>`)를 섞어 넘긴다. 올리는
    // 중인 녹화는 열 수 없어 뺀다.
    final playlist = [
      for (final o in order)
        if (o.selectable) o.key
    ];
    final items = [
      for (final o in order)
        switch (o.item) {
          final FavoriteClip f => _BookmarkCard(clip: f, playlist: playlist),
          final RecordingItem r => _RecordingCard(item: r, playlist: playlist),
          _ => throw StateError('unknown bookmark item'),
        }
    ];

    return ListView.separated(
      // top 24 — Figma 668:717 상단바(4238)→첫 카드(4261) 실측 23≈24.
      padding: const EdgeInsets.fromLTRB(_margin, 24, _margin, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, i) => items[i],
    );
  }
}

/// 카드 한 장 — 헤더 "2026. 08. 12 · 오전 12:50" + 8 갭 + 썸네일(369:180, r12).
class _BookmarkCard extends ConsumerWidget {
  const _BookmarkCard({required this.clip, required this.playlist});

  final FavoriteClip clip;
  final List<String> playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final owner = ref.watch(clipMemoAccountProvider);
    final memoKey = (ownerId: clip.ownerId, clipId: clip.clipId);
    final memo = owner == clip.ownerId
        ? ref.watch(clipMemoProvider(memoKey)).valueOrNull
        : null;
    // 이 카드 몫만 구독 — 하나를 고를 때 모든 카드가 다시 그려지지 않게.
    final active =
        ref.watch(clipSelectionProvider(_scope).select((s) => s.active));
    final flow = ClipSelectionFlow(ref, _scope);
    void open() =>
        context.push('/crecam/player/${clip.clipId}', extra: playlist);
    final thumb = MotionClipThumb(
        clipId: clip.clipId, cameraId: clip.cameraId, fallbackIconSize: 28);
    final header = Text(
      _headerLabel(clip.startedAt.toLocal()),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        height: 19.09375 / 16, // Figma 945:4351 Date h19 → 카드 y+27
        fontWeight: FontWeight.w600,
        letterSpacing: 16 * -0.02,
        color: glass.textSecondary,
      ),
    );

    return GestureDetector(
      key: ValueKey('bookmark_card_${clip.clipId}'),
      behavior: HitTestBehavior.opaque,
      // 선택 모드에선 카드 탭 = 고르기, 영상 보기는 확대 버튼(Figma 1493:9274).
      onTap: active ? () => flow.toggle(context, clip.clipId) : open,
      onLongPress: () => flow.longPress(context, clip.clipId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: header),
            ClipSelectItemCheck(scope: _scope, clipId: clip.clipId),
          ]),
          const SizedBox(height: 8),
          SizedBox(
              height: 180,
              child: Row(children: [
                Expanded(
                    child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Stack(fit: StackFit.expand, children: [
                    thumb,
                    if (active)
                      Positioned(
                          right: 4,
                          bottom: 4,
                          child: ClipSelectExpandButton(
                              clipId: clip.clipId, onTap: open)),
                  ]),
                )),
                if (memo != null) ...[
                  const SizedBox(width: 8),
                  ClipMemoCard(memo: memo, memoKey: memoKey),
                ],
              ])),
        ],
      ),
    );
  }

  /// "2026. 08. 12 · 오전 12:50" — 시각은 공용 [formatAmPmTime].
  static String _headerLabel(DateTime t) =>
      '${DateFormat('yyyy. MM. dd').format(t)} · ${formatAmPmTime(t)}';
}

/// 직접 녹화 카드 — 북마크 카드와 같은 틀 + "직접 녹화 · 0:42" 배지. 메모가
/// 있으면 북마크 카드처럼 오른쪽에 메모 카드(키 = 항목 키).
///
/// 이 폰 녹화와 서버에만 있는 녹화(다른 폰·재설치 전, 2026-10-21 F단계)가
/// 같은 카드다. 선택 모드에서도 북마크 카드처럼 고를 수 있다(탭 = 고르기,
/// 꾹 누르기 = 선택 시작, 2026-10-21 사용자 결정 — 전엔 선택 중 감췄고 "업로드
/// 실패" 카드만 꾹 눌러 지웠다. 이제 지우기는 선택 모드 [삭제]). **올리는 중인
/// 녹화는 흐리게, 누를 수 없음**(업로드가 끝나면 원래대로).
class _RecordingCard extends ConsumerWidget {
  const _RecordingCard({required this.item, required this.playlist});

  final RecordingItem item;
  final List<String> playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final owner = ref.watch(clipMemoAccountProvider);
    final key = item.key;
    // 위젯 키는 이 폰 녹화면 로컬 id, 서버 녹화면 항목 키(`rec:srv:<id>`).
    final tag = item.local?.id ?? key;
    final memoKey = (ownerId: owner ?? '', clipId: key);
    final memo =
        owner == null ? null : ref.watch(clipMemoProvider(memoKey)).valueOrNull;
    final active =
        ref.watch(clipSelectionProvider(_scope).select((s) => s.active));
    final flow = ClipSelectionFlow(ref, _scope);
    final enabled = !item.uploading;
    void open() => context.push(recordingOpenPath(item), extra: playlist);
    final uploadLabel = recordingUploadLabelKey(item.uploadBadge);
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              _BookmarkCard._headerLabel(item.startedAt.toLocal()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                height: 19.09375 / 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 16 * -0.02,
                color: glass.textSecondary,
              ),
            ),
          ),
          if (enabled) ClipSelectItemCheck(scope: _scope, clipId: key),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: Row(children: [
            Expanded(
                child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: glass.surfaceTint),
                RecordingItemThumb(
                    item: item, fallback: const SizedBox.shrink()),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: RecordingChip(recordingLengthLabel(item.duration)),
                ),
                // 업로드 상태(2026-10-21) — 올라간 녹화는 표시 없음. 선택 모드엔
                // 오른쪽 아래가 확대 버튼 자리라 오른쪽 위로 올린다.
                if (uploadLabel != null)
                  Positioned(
                    right: 8,
                    top: active ? 8 : null,
                    bottom: active ? null : 8,
                    child: RecordingChip(uploadLabel.tr(),
                        key: ValueKey('live_recording_upload_$tag')),
                  ),
                if (active && enabled)
                  Positioned(
                      right: 4,
                      bottom: 4,
                      child: ClipSelectExpandButton(clipId: key, onTap: open)),
              ]),
            )),
            if (memo != null) ...[
              const SizedBox(width: 8),
              ClipMemoCard(memo: memo, memoKey: memoKey),
            ],
          ]),
        ),
      ],
    );
    if (!enabled) {
      return IgnorePointer(
        key: ValueKey('live_recording_card_$tag'),
        child: Opacity(opacity: kRecordingUploadingOpacity, child: card),
      );
    }
    return GestureDetector(
      key: ValueKey('live_recording_card_$tag'),
      behavior: HitTestBehavior.opaque,
      onTap: active ? () => flow.toggle(context, key) : open,
      onLongPress: () => flow.longPress(context, key),
      child: card,
    );
  }
}

/// 로딩 스켈레톤 — 카드 2장(헤더 줄 + 썸네일 면, shimmer, CPI 금지).
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          BookmarksScreen._margin, 24, BookmarksScreen._margin, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoading(width: 180, height: 16),
          SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 369 / 180,
            child: SkeletonLoading(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
        ],
      ),
    );
  }
}
