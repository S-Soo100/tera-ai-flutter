import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/viva_shadow.dart';
import '../../../../shared/widgets/arc_spinner.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../../shared/widgets/glass_dock.dart';
import '../../domain/clip_selection.dart';
import '../clip_selection_providers.dart';
import 'clip_selection_flow.dart';

/// 영상 선택 모드 공용 조각 — Figma '영상 선택'(1497:14225).
///
/// 선택 상태는 칸마다 자기 몫만 구독한다(`select`) — 하나를 누를 때 화면의
/// 모든 썸네일이 다시 그려지지 않게.

/// 헤더 선택 진입(priority)·종료(redo) 아이콘 44 — Figma 신규에셋 1497:11825/
/// 11823(44 프레임 export).
class ClipSelectHeaderButton extends StatelessWidget {
  const ClipSelectHeaderButton.enter({super.key, required this.onPressed})
      : _asset = 'priority',
        _tooltip = 'clip_select_enter';
  const ClipSelectHeaderButton.exit({super.key, required this.onPressed})
      : _asset = 'redo',
        _tooltip = 'clip_select_exit';

  final String _asset;
  final String _tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        key: Key('clip_select_header_$_asset'),
        padding: EdgeInsets.zero,
        tooltip: _tooltip.tr(),
        onPressed: onPressed,
        icon: FigmaIcon.tinted('redesign_v2/$_asset',
            size: 44, color: context.glass.textSecondary),
      ),
    );
  }
}

/// 체크박스 글리프 — 24 프레임에 18 상자(Material check_box 400).
class ClipSelectCheckbox extends StatelessWidget {
  const ClipSelectCheckbox({super.key, required this.checked, this.size = 24});
  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) => FigmaIcon.tinted(
      checked
          ? 'redesign_v2/check_box_400'
          : 'redesign_v2/check_box_outline_blank_400',
      size: size,
      color: checked ? context.glass.selectionOn : context.glass.selectionOff);
}

/// 선택 중 영상 보기 버튼 — 32 원(검정 30% + zoom_out_map, 디자이너 export
/// 1497:11090). 썸네일 우하단 안쪽 4에 얹는다.
class ClipSelectExpandButton extends StatelessWidget {
  const ClipSelectExpandButton(
      {super.key, required this.clipId, required this.onTap});
  final String clipId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'clip_select_expand'.tr(),
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('clip_select_expand_$clipId'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const FigmaIcon.metric('redesign_v2/clip_expand_button',
              size: 32),
        ),
      );
}

typedef _ItemState = ({bool active, bool checked});

_ItemState _itemState(ClipSelection s, String id) =>
    (active: s.active, checked: s.contains(id));

/// 그리드 썸네일 칸 — 평소엔 탭 = [onOpen], 선택 모드엔 탭 = 고르기(영상 보기는
/// 확대 버튼), 꾹 누르기 = 선택 시작. 선택 중엔 우상단 체크박스(32 프레임)와
/// 우하단 확대 버튼(Figma 1497:11036)을 [child] 위에 얹는다.
class ClipSelectableThumb extends ConsumerWidget {
  const ClipSelectableThumb({
    super.key,
    required this.scope,
    required this.clipId,
    required this.onOpen,
    required this.child,
  });

  final ClipSelectionScope scope;
  final String clipId;
  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
        clipSelectionProvider(scope).select((s) => _itemState(s, clipId)));
    final flow = ClipSelectionFlow(ref, scope);
    // 꾹 누르기·끌기는 바깥 [ClipDragSelectRegion]이 맡는다 — 칸은 자기 id만
    // 알린다(히트 테스트로 손가락 아래 칸을 찾는다).
    return MetaData(
      metaData: ClipDragCell(clipId),
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.active ? () => flow.toggle(context, clipId) : onOpen,
        child: Stack(fit: StackFit.expand, children: [
          child,
          if (item.active) ...[
            Positioned(
                top: 0,
                right: 0,
                child: SizedBox.square(
                    dimension: 32,
                    child: Center(
                        child: ClipSelectCheckbox(
                            key: ValueKey('clip_select_check_$clipId'),
                            checked: item.checked)))),
            Positioned(
                right: 4,
                bottom: 4,
                child: ClipSelectExpandButton(clipId: clipId, onTap: onOpen)),
          ],
        ]),
      ),
    );
  }
}

/// 드래그 선택 히트 테스트 표지 — [ClipSelectableThumb]가 자기 칸에 단다.
class ClipDragCell {
  const ClipDragCell(this.clipId);
  final String clipId;
}

/// 꾹 눌러 끌기로 여러 영상 고르기(iPhone 사진 앱 방식) — 3열 그리드 목록을
/// 감싼다.
///
/// - 영상을 꾹 누르면 그 영상이 골라지며 선택 모드가 시작되고(이미 선택
///   모드면 그 영상의 반대 상태로), 손을 떼지 않고 끌면 처음 누른 영상부터
///   손가락 아래 영상까지 [orderedIds] 순서의 범위가 함께 바뀐다.
/// - 선택 모드에선 꾹 누르지 않고 **가로로** 끌어도 시작한다. 세로로 쓸면
///   지금처럼 스크롤이다.
/// - 손가락이 위·아래 가장자리 [edge] 안에 있으면 [scrollController]를 그
///   방향으로 흘려 계속 고른다.
/// - 20개에 닿으면 끌기 한 번에 한 번만 안내한다.
class ClipDragSelectRegion extends ConsumerStatefulWidget {
  const ClipDragSelectRegion({
    super.key,
    required this.scope,
    required this.orderedIds,
    this.scrollController,
    required this.child,
  });

  final ClipSelectionScope scope;
  final List<String> Function() orderedIds;

  /// 가장자리 자동 스크롤 대상. null이면 라우트의 [PrimaryScrollController]
  /// (컨트롤러 없이 쓴 세로 ListView가 붙는 것).
  final ScrollController? scrollController;
  final Widget child;

  static const double edge = 72;
  static const double maxAutoScroll = 16; // 한 프레임(16ms)에 움직일 최대 pt

  @override
  ConsumerState<ClipDragSelectRegion> createState() =>
      _ClipDragSelectRegionState();
}

class _ClipDragSelectRegionState extends ConsumerState<ClipDragSelectRegion> {
  String? _anchor;
  String? _last;
  bool _select = true;
  bool _limitShown = false;
  ClipSelection _base = const ClipSelection();
  Offset? _pointer; // 전역 좌표
  Timer? _autoScroll;

  ClipSelectionController get _ctl =>
      ref.read(clipSelectionProvider(widget.scope).notifier);

  String? _cellAt(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(global));
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && target.metaData is ClipDragCell) {
        return (target.metaData as ClipDragCell).clipId;
      }
    }
    return null;
  }

  /// [startMode] null이면 꾹 누르기(모드 밖에서도 시작), 아니면 가로 끌기.
  bool _begin(Offset global, {required bool fromLongPress}) {
    final id = _cellAt(global);
    if (id == null) return false;
    final current = ref.read(clipSelectionProvider(widget.scope));
    if (!current.active && !fromLongPress) return false;
    HapticFeedback.mediumImpact();
    _base = current.active ? current : const ClipSelection(active: true);
    _select = !_base.contains(id);
    _anchor = id;
    _last = null;
    _limitShown = false;
    _pointer = global;
    _apply(id);
    return true;
  }

  void _apply(String id) {
    if (id == _last || _anchor == null) return;
    _last = id;
    final change = dragSelection(
        base: _base,
        ordered: widget.orderedIds(),
        anchor: _anchor!,
        current: id,
        select: _select);
    _ctl.replace(change.selection);
    if (change.limited && !_limitShown) {
      _limitShown = true;
      ClipSelectionFlow.showLimit(context);
    }
  }

  void _move(Offset global) {
    if (_anchor == null) return;
    _pointer = global;
    final id = _cellAt(global);
    if (id != null) _apply(id);
    _updateAutoScroll();
  }

  void _updateAutoScroll() {
    final box = context.findRenderObject() as RenderBox?;
    final p = _pointer;
    if (box == null || p == null) return;
    final y = box.globalToLocal(p).dy;
    final h = box.size.height;
    final e = ClipDragSelectRegion.edge;
    double speed = 0;
    if (y < e) speed = -(e - y) / e;
    if (y > h - e) speed = (y - (h - e)) / e;
    if (speed == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??=
        Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    _speed = speed.clamp(-1.0, 1.0);
  }

  double _speed = 0;

  void _tick() {
    final c =
        widget.scrollController ?? PrimaryScrollController.maybeOf(context);
    if (!mounted || _anchor == null || c == null || !c.hasClients) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    final pos = c.position;
    final next = (pos.pixels + _speed * ClipDragSelectRegion.maxAutoScroll)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if (next == pos.pixels) return;
    c.jumpTo(next);
    // 목록이 흘러 손가락 아래 칸이 바뀐다 — 다음 프레임에 다시 찾는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = _pointer;
      if (!mounted || p == null || _anchor == null) return;
      final id = _cellAt(p);
      if (id != null) _apply(id);
    });
  }

  void _end() {
    _anchor = null;
    _pointer = null;
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        ref.watch(clipSelectionProvider(widget.scope).select((s) => s.active));
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(debugOwner: this), (r) {
          r.onLongPressStart = (d) {
            if (!_begin(d.globalPosition, fromLongPress: true)) _end();
          };
          r.onLongPressMoveUpdate = (d) => _move(d.globalPosition);
          r.onLongPressEnd = (_) => _end();
          r.onLongPressCancel = _end;
        }),
        // 선택 모드에선 가로로 끌어도 시작(세로는 스크롤) — 모드 밖에선 라이브
        // PageView 등 가로 쓸기를 가로채지 않게 등록하지 않는다.
        if (active)
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                  HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(debugOwner: this), (r) {
            r.dragStartBehavior = DragStartBehavior.down;
            r.onStart = (d) {
              if (!_begin(d.globalPosition, fromLongPress: false)) _end();
            };
            r.onUpdate = (d) => _move(d.globalPosition);
            r.onEnd = (_) => _end();
            r.onCancel = _end;
          }),
      },
      child: widget.child,
    );
  }
}

/// 날짜·시간 묶음 머리 체크박스(24) — 묶음 전체 고르기/빼기. 선택 모드가
/// 아니면 아무것도 그리지 않는다. 왼쪽으로 터치 영역을 넓힌다.
class ClipSelectGroupCheck extends ConsumerWidget {
  const ClipSelectGroupCheck(
      {super.key, required this.scope, required this.ids});
  final ClipSelectionScope scope;
  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clipSelectionProvider(scope)
        .select((s) => (active: s.active, all: groupFullySelected(s, ids))));
    if (!state.active) return const SizedBox.shrink();
    return _CheckTap(
        checked: state.all,
        label: 'clip_select_group'.tr(),
        onTap: () => ClipSelectionFlow(ref, scope).toggleGroup(context, ids));
  }
}

/// 영상 한 개 체크박스(24) — 북마크 카드 머리(Figma 1493:9274). 선택 모드가
/// 아니면 아무것도 그리지 않는다.
class ClipSelectItemCheck extends ConsumerWidget {
  const ClipSelectItemCheck(
      {super.key, required this.scope, required this.clipId});
  final ClipSelectionScope scope;
  final String clipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
        clipSelectionProvider(scope).select((s) => _itemState(s, clipId)));
    if (!item.active) return const SizedBox.shrink();
    return _CheckTap(
        key: ValueKey('clip_select_check_$clipId'),
        checked: item.checked,
        label: 'clip_select_item'.tr(),
        onTap: () => ClipSelectionFlow(ref, scope).toggle(context, clipId));
  }
}

class _CheckTap extends StatelessWidget {
  const _CheckTap(
      {super.key,
      required this.checked,
      required this.label,
      required this.onTap});
  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        checked: checked,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: ClipSelectCheckbox(checked: checked)),
        ),
      );
}

/// 선택 모드 하단 바 — 탭바 자리(Figma 1497:12437, 탭바와 같은 80 틀·간격).
/// [다운로드][공유][삭제][더보기]. 더보기는 자기 위치를 넘겨 메뉴를 띄운다.
class ClipSelectionActionBar extends StatelessWidget {
  const ClipSelectionActionBar({
    super.key,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
    required this.onMore,
  });

  final VoidCallback onDownload, onShare, onDelete;
  final void Function(Rect anchor) onMore;

  static const barKey = Key('clip_selection_action_bar');

  @override
  Widget build(BuildContext context) {
    return GlassDockFrame(key: barKey, children: [
      // 하단 바 아이콘은 모두 Figma 24 프레임 export(1497:12439·12443·12447).
      _item(context, 'redesign_v2/download_24', 'clip_select_download', 24,
          (_) => onDownload()),
      _item(context, 'redesign_v2/share_24', 'clip_select_share', 24,
          (_) => onShare()),
      _item(context, 'redesign_v2/delete_24', 'clip_select_delete', 24,
          (_) => onDelete()),
      _item(context, 'redesign_v2/more_vert', 'clip_select_more', 24, onMore),
    ]);
  }

  Widget _item(BuildContext context, String asset, String label, double frame,
      void Function(Rect anchor) onTap) {
    final glass = context.glass;
    return Expanded(
      child: Builder(builder: (itemContext) {
        void tap() {
          final box = itemContext.findRenderObject() as RenderBox?;
          final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
          onTap(origin & (box?.size ?? Size.zero));
        }

        return Semantics(
          button: true,
          label: label.tr(),
          onTap: tap,
          excludeSemantics: true,
          child: InkWell(
            key: Key('clip_select_action_$label'),
            onTap: tap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                    dimension: 24,
                    child: OverflowBox(
                        maxWidth: frame,
                        maxHeight: frame,
                        // Figma 1497:12437 — 아이콘 #1E1E1E, 라벨 #3C3C3C(픽셀 실측).
                        child: FigmaIcon.tinted(asset,
                            size: frame, color: glass.textPrimary))),
                const SizedBox(height: 4),
                Text(label.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: glass.dockLabel.copyWith(
                        color: glass.textSecondary, height: 1.193359375)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// 더보기 메뉴 한 줄.
class ClipSelectMenuItem<T> {
  const ClipSelectMenuItem(this.value, this.label, {this.destructive = false});
  final T value;
  final String label;
  final bool destructive;
}

/// 더보기 메뉴(Figma SelectList 1497:10535) — 흰 r12, 안쪽 8·4, 줄 44(18/500,
/// 아래 선), 화면 오른쪽 12·하단 바 위 4. 바깥을 누르면 null.
Future<T?> showClipSelectMenu<T>(BuildContext context,
    {required Rect anchor, required List<ClipSelectMenuItem<T>> items}) {
  final screen = MediaQuery.sizeOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) {
      final glass = ctx.glass;
      return Stack(children: [
        Positioned(
          right: 12,
          // 하단 바 윗변(더보기 칸 위 12) 위로 4.
          bottom: screen.height - (anchor.top - 12) + 4,
          // 흰 면이 그림자 위에 와야 한다 — 그림자를 흰 Material 안쪽
          // DecoratedBox에 두면 면 전체가 그림자색(#DEDFE0)으로 덮였다
          // (2026-10-20 시뮬레이터 대조).
          child: DecoratedBox(
            key: const Key('clip_select_menu'),
            decoration: BoxDecoration(
                color: glass.surfaceHeader,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [vivaFloatingShadow(glass)]),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        InkWell(
                          key: Key('clip_select_menu_${items[i].value}'),
                          onTap: () => Navigator.pop(ctx, items[i].value),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: i == items.length - 1
                                ? null
                                : BoxDecoration(
                                    border: Border(
                                        bottom:
                                            BorderSide(color: glass.border))),
                            child: Text(items[i].label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 18,
                                    height: 28 / 18,
                                    letterSpacing: -0.36,
                                    fontWeight: FontWeight.w500,
                                    color: items[i].destructive
                                        ? glass.navSelected
                                        : glass.textSecondary)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    },
  );
}

/// 일괄 작업 중 화면 — 흰 dim(80%)이 입력을 막는다(Figma 1497:11207·1497:11926).
/// 진행률이 있는 작업(저장·공유·북마크)은 진행 막대(267.6×12, 남은 칸 #B4AEAE·
/// 채움 #D61619) + 하단 [취소](369×56 r12 #1E1E1E, SafeArea 위 66), 나머지(삭제·
/// 메모 삭제 — 짧다)는 원호 스피너 62 + 문구.
class ClipBatchOverlay extends StatelessWidget {
  const ClipBatchOverlay(
      {super.key, required this.job, required this.onCancel});
  final ClipBatchState job;
  final VoidCallback onCancel;

  static const overlayKey = Key('clip_batch_overlay');

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final labelStyle = TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.36,
        color: glass.textSecondary);
    final progress = job.progress;
    final percent = ((progress ?? 0) * 100).floor().toString();
    final label = switch (job.kind) {
      ClipBatchKind.save =>
        'clip_select_downloading'.tr(namedArgs: {'percent': percent}),
      ClipBatchKind.share =>
        'clip_select_share_preparing'.tr(namedArgs: {'percent': percent}),
      ClipBatchKind.delete => 'clip_select_deleting'.tr(),
      ClipBatchKind.bookmarkAdd =>
        'clip_select_bookmarking'.tr(namedArgs: {'percent': percent}),
      ClipBatchKind.bookmarkRemove =>
        'clip_select_unbookmarking'.tr(namedArgs: {'percent': percent}),
      ClipBatchKind.memoDelete => 'clip_select_memo_deleting'.tr(),
    };
    return Positioned.fill(
      key: overlayKey,
      child: PopScope(
        canPop: false,
        // 하이라이트·북마크에선 이 오버레이가 Scaffold 밖(Stack 형제)에 놓여
        // Material 조상이 없다 — 없으면 글자가 노란 이중 밑줄(디버그 기본
        // 스타일)로 그려졌다(2026-10-20 시뮬레이터).
        child: Material(
          type: MaterialType.transparency,
          child: Stack(children: [
            // 뒤 화면 입력 차단.
            Positioned.fill(
                child: AbsorbPointer(
                    child: ColoredBox(
                        color: glass.wallpaper.withValues(alpha: 0.8)))),
            Center(
              child: progress != null
                  ? SizedBox(
                      width: 267.6,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(label,
                                textAlign: TextAlign.center, style: labelStyle),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 12,
                                child: Stack(children: [
                                  Positioned.fill(
                                      child: ColoredBox(
                                          color: glass.progressTrack)),
                                  FractionallySizedBox(
                                      key: const Key('clip_batch_progress'),
                                      widthFactor: progress,
                                      heightFactor: 1,
                                      child: ColoredBox(
                                          color: glass.progressFill)),
                                ]),
                              ),
                            ),
                          ]),
                    )
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      // Figma 1497:11376 원호 색 #B4AEAE(픽셀 실측, 2026-10-20).
                      ArcSpinner(size: 62, color: glass.progressTrack),
                      const SizedBox(height: 12),
                      Text(label, style: labelStyle),
                    ]),
            ),
            if (job.cancellable)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 66,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    key: const Key('clip_batch_cancel'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onCancel();
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: glass.textPrimary,
                        foregroundColor: glass.buttonForeground,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 18,
                            height: 28 / 18,
                            letterSpacing: -0.36,
                            fontWeight: FontWeight.w600)),
                    child: Text(switch (job.kind) {
                      ClipBatchKind.save => 'clip_select_download_cancel',
                      ClipBatchKind.share => 'clip_select_share_cancel',
                      _ => 'clip_select_job_cancel',
                    }
                        .tr()),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
