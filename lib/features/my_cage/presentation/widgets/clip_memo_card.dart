import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../domain/clip_memo.dart';
import '../clip_memo_colors.dart';
import '../clip_memo_providers.dart';
import 'clip_memo_editor.dart';

/// Figma765:1255:112×180, radius12, padding12, 24px menu, 16/28 text.
/// Used only by the bookmark list; opening a player never renders memo cards.
class ClipMemoCard extends StatelessWidget {
  const ClipMemoCard({super.key, required this.memo, required this.memoKey});
  final ClipMemo memo;
  final ClipMemoKey memoKey;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 112,
        height: 180,
        decoration: BoxDecoration(
            color: ClipMemoColors.backgrounds[memo.colorIndex],
            borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          Positioned(
              top: 0,
              right: 0,
              width: 48,
              height: 48,
              child: PopupMenuButton<String>(
                tooltip: 'clip_memo_more'.tr(),
                padding: const EdgeInsets.all(12),
                icon: const FigmaIcon.tinted(FigmaIcons.more,
                    size: 24, color: ClipMemoColors.foreground),
                // Figma 945:4351 SelectList — 흰 106×96 r12, 카드 우측 정렬,
                // 아이콘 아래 8, 안쪽 8/4, 행 90×44 하단선, 18/500.
                color: context.glass.surfaceHeader,
                surfaceTintColor: context.glass.surfaceHeader,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                constraints: const BoxConstraints(minWidth: 106, maxWidth: 106),
                menuPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                position: PopupMenuPosition.under,
                // under = 버튼 아래 - padding/2(12) → 36, 원본 44 = +8.
                // 가로는 버튼(카드 우측 48)에 오른쪽 정렬돼 106폭이 카드
                // 오른쪽 끝에 맞는다(원본 x275~381).
                offset: const Offset(0, 8),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit',
                      height: 44,
                      padding: EdgeInsets.zero,
                      child: _MenuRow(
                          label: 'clip_memo_edit'.tr(),
                          color: context.glass.textSecondary,
                          divider: true)),
                  PopupMenuItem(
                      value: 'delete',
                      height: 44,
                      padding: EdgeInsets.zero,
                      child: _MenuRow(
                          label: 'clip_memo_delete'.tr(),
                          color: context.glass.navSelected,
                          divider: false)),
                ],
                onSelected: (action) {
                  if (action == 'edit') {
                    showClipMemoEditor(context, key: memoKey);
                  }
                  if (action == 'delete') {
                    deleteClipMemo(context, memoKey);
                  }
                },
              )),
          Positioned(
              top: 42,
              bottom: 12,
              left: 12,
              right: 12,
              child: ClipRect(
                  child: Text(memo.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 28 / 16,
                          letterSpacing: -.32,
                          color: ClipMemoColors.foreground)))),
        ]));
  }
}

/// 메뉴 한 행 (Figma List 90×44, 좌 12, 18/500/28/-0.36, 하단선 #E3E3E3).
class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.label, required this.color, required this.divider});
  final String label;
  final Color color;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
          border: divider
              ? Border(bottom: BorderSide(color: context.glass.border))
              : null),
      child: Text(label,
          style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              height: 28 / 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.36,
              color: color)),
    );
  }
}
