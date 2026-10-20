import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/viva_colors.dart';
import '../../../../shared/widgets/arc_spinner.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../clip_selection_providers.dart';

/// 영상 선택 모드 공용 조각 — Figma '영상 선택'(1497:14225).
///
/// 체크박스 색은 썸네일·흰 바닥 어디에 얹혀도 같아야 해서 테마 역할색이 아니라
/// VIVA 원색이다(켬 Main_Dark #C00306, 끔 Fill/Icon #B4AEAE — 1497:11080/11112).
abstract final class ClipSelectionColors {
  static const checked = VivaColors.mainDark;
  static const unchecked = VivaColors.fillIcon;
}

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
      color: checked
          ? ClipSelectionColors.checked
          : ClipSelectionColors.unchecked);
}

/// 썸네일 위 선택 표시 — 우상단 체크박스(32 프레임), 우하단 확대 버튼
/// (32 원, 검정 30%, 안쪽 4 — 1497:11082). 확대 = 선택 중에 영상 확인.
/// 소비처 Stack(fit: expand) 위에 얹는다.
class ClipSelectThumbOverlay extends StatelessWidget {
  const ClipSelectThumbOverlay(
      {super.key,
      required this.clipId,
      required this.checked,
      required this.onExpand});
  final String clipId;
  final bool checked;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Positioned(
          top: 0,
          right: 0,
          child: SizedBox.square(
              dimension: 32,
              child: Center(
                  child: ClipSelectCheckbox(
                      key: ValueKey('clip_select_check_$clipId'),
                      checked: checked)))),
      Positioned(
          right: 4,
          bottom: 4,
          child: Semantics(
            button: true,
            label: 'clip_select_expand'.tr(),
            excludeSemantics: true,
            child: GestureDetector(
              key: ValueKey('clip_select_expand_$clipId'),
              behavior: HitTestBehavior.opaque,
              onTap: onExpand,
              // 디자이너 export 그대로(원 검정 30% + zoom_out_map, 1497:11090).
              child: const FigmaIcon.metric('redesign_v2/clip_expand_button',
                  size: 32),
            ),
          )),
    ]);
  }
}

/// 날짜·시간 묶음 머리 체크박스(24). 왼쪽으로 터치 영역을 넓힌다.
class ClipSelectGroupCheck extends StatelessWidget {
  const ClipSelectGroupCheck(
      {super.key, required this.checked, required this.onTap});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        checked: checked,
        label: 'clip_select_group'.tr(),
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
    final glass = context.glass;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Builder(
        builder: (context) => DecoratedBox(
          key: barKey,
          decoration: BoxDecoration(
              color: glass.tabBar,
              border: Border(top: BorderSide(color: glass.border))),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 26),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28.5, 12, 28.5, 0),
                child: SizedBox(
                  height: 28 +
                      MediaQuery.textScalerOf(context)
                          .scale(14.3203125)
                          .ceilToDouble(),
                  child: Row(children: [
                    // 다운로드는 24 프레임 export, 공유는 36 프레임 export라
                    // 24 자리에 넘치게 그려 글리프를 Figma 크기로 맞춘다.
                    _item(context, 'redesign_v2/download_24',
                        'clip_select_download', 24, (_) => onDownload()),
                    _item(context, 'share', 'clip_select_share', 36,
                        (_) => onShare()),
                    // 44 프레임 export(글리프 20) → Figma 24 프레임 글리프 18.
                    _item(context, 'redesign_v2/delete', 'clip_select_delete',
                        39.6, (_) => onDelete()),
                    _item(context, 'redesign_v2/more_vert', 'clip_select_more',
                        24, onMore),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
                        child: FigmaIcon.tinted(asset,
                            size: frame, color: glass.textSecondary))),
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
          child: Material(
            key: const Key('clip_select_menu'),
            color: glass.surfaceHeader,
            borderRadius: BorderRadius.circular(12),
            elevation: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: glass.menuShadow, blurRadius: 10)
                  ]),
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
/// 저장·공유는 진행 막대(267.6×12, 남은 칸 #B4AEAE·채움 #D61619) + 하단
/// [취소](369×56 r12 #1E1E1E, SafeArea 위 66), 나머지는 원호 스피너 62 + 문구.
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
      ClipBatchKind.bookmarkAdd => 'clip_select_bookmarking'.tr(),
      ClipBatchKind.bookmarkRemove => 'clip_select_unbookmarking'.tr(),
      ClipBatchKind.memoDelete => 'clip_select_memo_deleting'.tr(),
    };
    return Positioned.fill(
      key: overlayKey,
      child: PopScope(
        canPop: false,
        child: Stack(children: [
          // 뒤 화면 입력 차단.
          Positioned.fill(
              child: AbsorbPointer(
                  child: ColoredBox(
                      color: glass.wallpaper.withValues(alpha: 0.8)))),
          Center(
            child: job.cancellable
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
                                const Positioned.fill(
                                    child:
                                        ColoredBox(color: VivaColors.fillIcon)),
                                FractionallySizedBox(
                                    key: const Key('clip_batch_progress'),
                                    widthFactor: progress ?? 0,
                                    heightFactor: 1,
                                    child: const ColoredBox(
                                        color: VivaColors.mainLight)),
                              ]),
                            ),
                          ),
                        ]),
                  )
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    ArcSpinner(size: 62, color: glass.textSecondary),
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
                      foregroundColor: VivaColors.fillBack,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 18,
                          height: 28 / 18,
                          letterSpacing: -0.36,
                          fontWeight: FontWeight.w600)),
                  child: Text((job.kind == ClipBatchKind.share
                          ? 'clip_select_share_cancel'
                          : 'clip_select_download_cancel')
                      .tr()),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
