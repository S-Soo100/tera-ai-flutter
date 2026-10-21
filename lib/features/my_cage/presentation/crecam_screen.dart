import 'highlight_read_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'my_cage_providers.dart';
import 'live_recording_controller.dart';
import 'clip_feed_controller.dart';
import 'clip_visibility_providers.dart';
import 'clip_selection_providers.dart';
import 'widgets/clip_selection_flow.dart';
import 'widgets/clip_selection_widgets.dart';
import 'widgets/crecam_detail_top_bar.dart';
import '../domain/update_day_label.dart';
import 'widgets/clip_feed_slivers.dart';
import 'widgets/camera_live_area.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/redesign_tab_header.dart';
import '../../../shared/widgets/redesign_empty_state.dart';
import '../../home/domain/group_display_label.dart';
import '../../notification/domain/push_consent_flow.dart';
import '../../notification/presentation/push_pre_popup.dart';

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
  static const selectButtonKey = Key('crecam_select_button');

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _scope = ClipSelectionScope.feed;
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  final _bodyKey = GlobalKey();

  /// 선택 모드에서 접은 라이브·카드 영역 높이 — 접고 펼 때 스크롤을 그만큼
  /// 옮겨 보던 영상이 제자리에 남게 한다(꾹 누른 영상이 화면 밖으로 튀지 않게).
  double _collapsedHeader = 0;

  /// 꾹 눌러 선택을 시작했는데 스크롤이 맨 위 근처라 접힌 높이를 스크롤로
  /// 다 메우지 못할 때, 그 모자란 만큼 목록 위에 두는 빈자리. 누른 영상이
  /// 손가락 아래 그대로 남아야 이어서 끄는 범위가 맞는다(2026-10-21 — 전엔
  /// 영상이 위로 튀어 손가락 아래 다른 영상부터 골라졌다). 손을 떼면 걷힌다.
  late final _anchor =
      AnimationController(vsync: this, upperBound: double.maxFinite);

  /// 화면에 닿아 있는 손가락 수 — 선택 모드가 꾹 누르기로 켜졌는지(손가락이
  /// 아직 닿아 있음) [영상 선택] 버튼으로 켜졌는지(이미 뗌) 가린다.
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _anchor.dispose();
    super.dispose();
  }

  /// 지금 피드 순서의 영상 id — 전체 선택·드래그 선택 범위.
  List<String> _feedIds() {
    final query = ref.read(clipFeedQueryProvider);
    return query == null
        ? const <String>[]
        : [for (final clip in ref.read(clipFeedProvider(query)).items) clip.id];
  }

  void _onSelectionToggled(bool selecting) {
    final height = selecting
        ? _headerKey.currentContext?.size?.height ?? 0
        : _collapsedHeader;
    if (selecting) _collapsedHeader = height;
    if (height == 0) return;
    // 꾹 눌러 시작했으면 손가락 아래 영상 칸을 붙잡아 두고, 바뀐 화면에서 그
    // 칸이 움직인 만큼을 되돌린다 — 라이브·카드가 접히는 것 말고도 위 막대
    // (카메라 고르기 ↔ "N개 선택됨")와 시간 머리(체크 칸)가 함께 바뀐다.
    final cell = selecting && _pointers > 0 ? _cellAt(_downAt) : null;
    final cellTop = cell == null ? null : _topOf(cell);
    // 접히는(펼쳐지는) 높이 중 빈자리가 대신 맡는 만큼은 스크롤을 옮기지 않는다.
    var pad = 0.0;
    if (selecting) {
      final pixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;
      if (cell != null && pixels < height) pad = height - pixels;
      _anchor.value = pad;
    } else {
      pad = _anchor.value;
      _anchor
        ..stop()
        ..value = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final moved = cell == null || cellTop == null || !cell.attached
          ? null
          : _topOf(cell) - cellTop;
      double target;
      if (moved == null) {
        target = selecting
            ? position.pixels - height + pad
            : position.pixels + height - pad;
      } else if (pad > 0) {
        // 칸이 내려간 만큼 빈자리를 줄이고, 모자라면 스크롤로.
        final next = pad - moved;
        _anchor.value = next < 0 ? 0 : next;
        target = next < 0 ? position.pixels - next : position.pixels;
      } else {
        target = position.pixels + moved;
      }
      _scroll.jumpTo(target.clamp(0, position.maxScrollExtent).toDouble());
    });
  }

  /// [global] 아래 영상 칸(드래그 선택 표지 [ClipDragCell]).
  RenderMetaData? _cellAt(Offset? global) {
    final box = _bodyKey.currentContext?.findRenderObject();
    if (global == null || box is! RenderBox || !box.hasSize) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(global));
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is ClipDragCell) {
        return target;
      }
    }
    return null;
  }

  static double _topOf(RenderBox box) => box.localToGlobal(Offset.zero).dy;

  Offset? _downAt;

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    _downAt = event.position;
  }

  /// 손을 다 떼면 빈자리를 걷는다 — 스크롤로 흡수할 수 있는 만큼은 같은
  /// 프레임에 맞바꿔(화면 변화 없음) 지우고, 남은 만큼만 부드럽게 올린다.
  void _onPointerEnd(PointerEvent _) {
    if (_pointers > 0) _pointers--;
    if (_pointers > 0 || _anchor.value == 0 || _anchor.isAnimating) return;
    final pad = _anchor.value;
    if (_scroll.hasClients) {
      final pixels = _scroll.position.pixels;
      final absorbed = pixels < pad ? pixels : pad;
      if (absorbed > 0) {
        _anchor.value = pad - absorbed;
        _scroll.jumpTo(pixels - absorbed);
      }
    }
    _anchor.animateTo(0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic);
  }

  // 백그라운드에서 Realtime 소켓이 죽으면 이벤트가 다시 오지 않으므로,
  // 복귀 시 provider를 재생성(재구독+재조회)해 stale 상태를 끊는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(camerasProvider);
      ref.invalidate(clipVisibilityEntryRefreshProvider('camera'));
    }
  }

  Future<void> _refresh() async {
    final owner = ref.read(clipVisibilityAccountProvider);
    if (owner != null) {
      await ref.read(clipVisibilityProvider(owner).notifier).refresh();
    }
    if (!mounted) return;
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

  /// Figma 권한 요청(1179:4464) 하이라이트 시점: 카메라 연결 + 영상 1개 이상 +
  /// 카메라 탭이 실제로 보일 때(비활성 탭은 indexedStack이 TickerMode를 끈다,
  /// 위에 다른 화면이 덮여 있으면 isCurrent가 false). 주제별 1회는 흐름이 막는다.
  void _maybeAskHighlightPush(bool hasCamera) {
    final query = ref.watch(clipFeedQueryProvider);
    final hasClip = query != null &&
        ref.watch(
            clipFeedProvider(query).select((state) => state.items.isNotEmpty));
    final visible =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    if (hasCamera && hasClip && visible) {
      schedulePushConsent(context, ref, PushTopic.highlight);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clipVisibilityEntryRefreshProvider('camera'));
    final cameras = ref.watch(camerasProvider);
    final groups = ref.watch(enclosuresProvider).valueOrNull ?? const [];
    final selectedCamera = ref.watch(selectedCrecamCameraProvider);
    final selection = ref.watch(clipSelectionProvider(_scope));
    final batch = ref.watch(clipBatchProvider(_scope));
    final flow = ClipSelectionFlow(ref, _scope);
    ref.listen(clipSelectionProvider(_scope).select((s) => s.active),
        (before, now) {
      if (before != now) _onSelectionToggled(now);
    });
    // 기간이 바뀌면 안 보이게 된 영상이 골라진 채 남지 않게 비운다.
    ref.listen(clipFeedQueryProvider, (before, now) {
      if (before != now) {
        ref.read(clipSelectionProvider(_scope).notifier).clearIds();
      }
    });
    _maybeAskHighlightPush(cameras.valueOrNull?.isNotEmpty ?? false);
    final shell = GlassTabShell(
      // Figma 1497:13355 — 선택 모드 상단바는 상태바까지 #FAFAFA 면 + 아래 선
      // (하이라이트·북마크와 같은 CrecamDetailHeaderArea). 제목 "N개 선택됨",
      // 오른쪽 달력·선택 종료.
      header: selection.active
          ? CrecamDetailHeaderArea(
              child: CrecamDetailTopBar(
                showBack: false,
                title: 'clip_select_count'
                    .tr(namedArgs: {'count': '${selection.count}'}),
                onCalendarTap: () => pickFeedRange(context, ref),
                trailing: ClipSelectHeaderButton.exit(
                    onPressed: () => ref
                        .read(clipSelectionProvider(_scope).notifier)
                        .exit()),
              ),
            )
          : null,
      child: Column(
        children: [
          if (selection.active)
            const SizedBox(height: CrecamScreen._gap)
          else
            Padding(
              // top 0 — Figma 668:427은 헤더가 status bar 바로 아래 선다(홈 동일).
              padding: EdgeInsets.fromLTRB(CrecamScreen._margin, 0,
                  CrecamScreen._margin, CrecamScreen._gap),
              child: RedesignTabHeader(
                choices: [
                  for (final camera in cameras.valueOrNull ?? const [])
                    (
                      id: camera.id,
                      label: groupDisplayLabel(
                          groupId: camera.enclosureId,
                          individualName: camera.name,
                          groups: groups)
                    )
                ],
                selectedId: selectedCamera,
                emptyLabel: 'device_camera_label'.tr(),
                onSelected: (id) {
                  ref.read(selectedCrecamCameraProvider.notifier).state = id;
                  // 홈도 같은 카메라로 — 스와이프와 같은 동기화(2026-09-25).
                  syncHomeSetToCamera(ref, id);
                },
              ),
            ),
          // 키 — 선택 모드에서 위(헤더)·아래(동작 바)가 함께 바뀌어도 목록이
          // 같은 Element로 남아야 진행 중인 꾹 눌러 끌기가 끊기지 않는다.
          Expanded(
              key: const ValueKey('crecam_body'),
              child: cameras.hasValue && cameras.value!.isEmpty
                  ? RedesignEmptyState(
                      image: FigmaImages.emptyCamera,
                      message: 'redesign_empty_camera'.tr(),
                      buttonText: 'redesign_device_add'.tr(),
                      onPressed: () => context.push('/devices/add'),
                      // 카메라를 모두 지워도 북마크는 남아 재생된다 — 가는 길을
                      // 남긴다(전엔 진입 카드와 함께 사라졌다, 2026-09-25).
                      secondaryText: (ref
                                  .watch(allFavoriteClipsProvider)
                                  .valueOrNull
                                  ?.isNotEmpty ??
                              false)
                          ? 'crecam_empty_bookmarks'.tr()
                          : null,
                      onSecondary: () => context.push('/crecam/bookmarks'))
                  : Listener(
                      key: _bodyKey,
                      onPointerDown: _onPointerDown,
                      onPointerUp: _onPointerEnd,
                      onPointerCancel: _onPointerEnd,
                      child: ClipDragSelectRegion(
                        scope: _scope,
                        scrollController: _scroll,
                        orderedIds: _feedIds,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: RefreshIndicator(
                            onRefresh: _refresh,
                            notificationPredicate: (notification) =>
                                !selection.active &&
                                notification.depth == 0 &&
                                notification.metrics.axis == Axis.vertical,
                            child: CustomScrollView(
                              key: PageStorageKey(
                                  ref.watch(clipFeedQueryProvider)),
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverToBoxAdapter(
                                    child: AnimatedBuilder(
                                        animation: _anchor,
                                        builder: (_, __) =>
                                            SizedBox(height: _anchor.value))),
                                SliverList(
                                    delegate: SliverChildListDelegate([
                                  KeepAliveCameraHeader(
                                      // 선택 모드엔 목록만(Figma 1497:13355) — 접어도
                                      // 라이브 상태는 살려 둔다(Offstage).
                                      child: Offstage(
                                          offstage: selection.active,
                                          child: Column(
                                              key: _headerKey,
                                              children: const [
                                                Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal:
                                                                CrecamScreen
                                                                    ._margin),
                                                    child: CameraLiveArea()),
                                                SizedBox(
                                                    height: CrecamScreen
                                                        ._sectionGap),
                                                Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal:
                                                                CrecamScreen
                                                                    ._margin),
                                                    child: _EntryCards()),
                                                // 2px of the 16px visual gap belongs to the
                                                // period button's expanded 44px touch target.
                                                SizedBox(
                                                    height: CrecamScreen
                                                            ._sectionGap -
                                                        2),
                                                Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal:
                                                                CrecamScreen
                                                                    ._margin),
                                                    child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child:
                                                            _PeriodButton())),
                                                SizedBox(
                                                    height:
                                                        CrecamScreen._gap - 2),
                                              ]))),
                                ])),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: CrecamScreen._margin),
                                  sliver: ClipFeedSlivers(
                                      query: ref.watch(clipFeedQueryProvider)),
                                ),
                                SliverToBoxAdapter(
                                    child: SizedBox(
                                        height: selection.active
                                            ? 16
                                            : glassDockListPadding(context)
                                                .bottom)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
          // 탭바 자리(셸이 선택 모드엔 탭바를 숨긴다 — app_router).
          if (selection.active) flow.actionBar(context, all: _feedIds),
        ],
      ),
    );
    return ClipSelectionBackGuard(
      scope: _scope,
      onLeave: () => flow.confirmLeave(context),
      child: Stack(children: [
        shell,
        if (batch != null)
          ClipBatchOverlay(
              job: batch,
              onCancel: ref.read(clipBatchProvider(_scope).notifier).cancel),
      ]),
    );
  }
}

// ── 엔트리 카드 (하이라이트 / 북마크) ─────────────────────────────────────────

class _EntryCards extends ConsumerWidget {
  const _EntryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightAt = ref.watch(latestHighlightAtProvider);
    // 안 본 최신 묶음이 있으면 "새 하이라이트" — 다 보면(재생 진전) 원래대로
    // "업데이트 N일 전". 배너와 같은 읽음 기준이다(2026-09-19 사용자 결정).
    final owner = ref.watch(currentUserProvider.select((u) => u?.id)) ?? '';
    final batch = ref.watch(latestHighlightBatchProvider).valueOrNull;
    final highlightUnread = batch != null &&
        !ref.watch(highlightReadProvider((
          ownerId: owner,
          cameraId: batch.cameraId,
          batchId: batch.batchId,
        )));
    // whenData는 쓰지 않는다 — 로딩 중 이전 값을 버려(riverpod 2.6 common.dart
    // `loading: (l) => AsyncLoading<R>()`) 재조회마다 부제목이 스켈레톤으로 깜빡였다.
    final favoriteAt = ref.watch(
      allFavoriteClipsProvider.select((v) {
        if (v.hasValue) {
          final list = v.requireValue;
          return AsyncData<DateTime?>(
              list.isEmpty ? null : list.first.favoritedAt);
        }
        if (v.hasError) {
          return AsyncError<DateTime?>(
              v.error!, v.stackTrace ?? StackTrace.empty);
        }
        return const AsyncLoading<DateTime?>();
      }),
    );
    // 직접 녹화도 북마크 목록에 들어간다 — 부제는 둘 중 최신으로 센다(전엔
    // 녹화만 있으면 "아직 없어요"). 목록은 최신순.
    final recordingAt = ref.watch(
      liveRecordingsProvider.select((v) {
        if (v.hasValue) {
          final list = v.requireValue;
          return AsyncData<DateTime?>(
              list.isEmpty ? null : list.first.startedAt);
        }
        if (v.hasError) {
          return AsyncError<DateTime?>(
              v.error!, v.stackTrace ?? StackTrace.empty);
        }
        return const AsyncLoading<DateTime?>();
      }),
    );
    final bookmarkAt = latestEntryAt(favoriteAt, recordingAt);
    return Row(
      children: [
        Expanded(
          child: _EntryCard(
            key: CrecamScreen.highlightCardKey,
            iconAsset: FigmaIcons.cardsStar,
            title: 'crecam_home_highlights'.tr(),
            latestAt: highlightAt,
            emptyLabel: 'crecam_update_unknown'.tr(),
            label: highlightUnread ? 'crecam_highlights_new'.tr() : null,
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

/// 엔트리 카드 부제의 최신 시각 — 두 출처(북마크·직접 녹화) 중 늦은 쪽.
/// 한쪽이 아직 처음 불러오는 중이면 로딩(부분 값으로 날짜가 바뀌어 보이지
/// 않게), 한쪽만 실패하면 남은 쪽 값으로 그린다(둘 다 실패면 오류).
AsyncValue<DateTime?> latestEntryAt(
    AsyncValue<DateTime?> a, AsyncValue<DateTime?> b) {
  if (a.hasValue && b.hasValue) {
    final x = a.requireValue, y = b.requireValue;
    if (x == null) return AsyncData(y);
    if (y == null) return AsyncData(x);
    return AsyncData(x.isAfter(y) ? x : y);
  }
  if (a.isLoading && !a.hasValue || b.isLoading && !b.hasValue) {
    return const AsyncLoading<DateTime?>();
  }
  if (a.hasValue) return a;
  if (b.hasValue) return b;
  return a;
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
    this.label,
    required this.onTap,
  });

  /// Figma 원본 SVG 이름(`FigmaIcons`) — Material 근사치는 2026-09-07 교체.
  final String iconAsset;
  final String title;
  final String? emptyLabel;

  /// 날짜 문구 대신 보일 상태 문구(예: 새 하이라이트). null이면 [latestAt] 기준.
  final String? label;

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
    if (label case final text?) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, style: style),
      );
    }
    return latestAt.when(
      // 재조회 중엔 이전 문구 유지 — 탭 진입·앱 복귀마다 숨김 목록 갱신이
      // 하이라이트·북마크 조회를 연쇄로 다시 돌려 부제목이 깜빡였다.
      skipLoadingOnReload: true,
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

/// 하이라이트·북마크 공통 "업데이트 오늘/어제/N일 전". 하이라이트의 [at]은
/// 올라온 날([latestHighlightAtProvider] — 공개 시각 또는 촬영 밤 다음 날).
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
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () =>
                  ref.read(clipFeedRangeProvider.notifier).state = null,
              child: Text('crecam_all_period'.tr()),
            ),
          _PillButton(
              key: CrecamScreen.periodButtonKey,
              visualKey: const Key('crecam_period_visual'),
              label: label,
              icon: FigmaIcon.tinted(FigmaIcons.calendar,
                  color: glass.textSecondary, size: 16),
              onTap: () => pickFeedRange(context, ref)),
          // Figma 1497:12190 — 기간 설정 오른쪽 [영상 선택](1497:14219 95×40).
          _PillButton(
              key: CrecamScreen.selectButtonKey,
              label: 'clip_select_button'.tr(),
              icon: FigmaIcon.tinted('redesign_v2/priority_s',
                  color: glass.textSecondary, size: 16),
              onTap: () => ref
                  .read(clipSelectionProvider(ClipSelectionScope.feed).notifier)
                  .enter()),
        ]);
  }
}

/// 카메라 탭 기간 고르기 — 기간 설정 버튼·선택 모드 헤더 달력 공용.
Future<void> pickFeedRange(BuildContext context, WidgetRef ref) async {
  final range = ref.read(clipFeedRangeProvider);
  final end = range?.endExclusive.subtract(const Duration(microseconds: 1));
  final now = DateTime.now();
  final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange:
          range == null ? null : DateTimeRange(start: range.start, end: end!));
  if (picked == null || !context.mounted) return;
  ref.read(clipFeedRangeProvider.notifier).state = (
    start: DateTime(picked.start.year, picked.start.month, picked.start.day),
    endExclusive:
        DateTime(picked.end.year, picked.end.month, picked.end.day + 1)
  );
}

/// 테두리 알약 버튼(Figma 765:4514 visual 95×40). The 2px vertical halo
/// consumes surrounding spacing, preserving both a 44px hit area and grid y572.
class _PillButton extends StatelessWidget {
  const _PillButton(
      {super.key,
      this.visualKey,
      required this.label,
      required this.icon,
      required this.onTap});
  final Key? visualKey;
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Semantics(
      button: true,
      label: label,
      child: Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: DecoratedBox(
                      key: visualKey,
                      decoration: BoxDecoration(
                          border: Border.all(color: glass.outline),
                          borderRadius: BorderRadius.circular(8)),
                      child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(minWidth: 95, minHeight: 40),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11.5),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    icon,
                                    const SizedBox(width: 4),
                                    Flexible(
                                        child: Text(label,
                                            style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: glass.textSecondary,
                                                fontSize: 14,
                                                height: 17 / 14,
                                                letterSpacing: -.28,
                                                fontWeight: FontWeight.w600))),
                                  ]))))))),
    );
  }
}
