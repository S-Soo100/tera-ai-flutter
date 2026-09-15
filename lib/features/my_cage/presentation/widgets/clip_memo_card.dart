import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit', child: Text('clip_memo_edit'.tr())),
                  PopupMenuItem(
                      value: 'delete', child: Text('clip_memo_delete'.tr())),
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
