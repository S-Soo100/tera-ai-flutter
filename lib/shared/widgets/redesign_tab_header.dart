import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/glass_palette.dart';
import 'figma_icon.dart';
import 'viva_shadow.dart';

typedef TabHeaderChoice = ({String id, String label});

/// Figma 765:4232: fixed 44px header, 44px actions with a 12px gap.
class RedesignTabHeader extends StatelessWidget {
  const RedesignTabHeader(
      {super.key,
      required this.choices,
      required this.selectedId,
      required this.emptyLabel,
      required this.onSelected,
      this.pillKey,
      this.arrowKey,
      this.managementKey,
      this.accountKey});
  final List<TabHeaderChoice> choices;
  final String? selectedId;
  final String emptyLabel;
  final ValueChanged<String> onSelected;
  final Key? pillKey, arrowKey, managementKey, accountKey;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final selected = choices.any((c) => c.id == selectedId)
        ? selectedId
        : choices.firstOrNull?.id;
    final style = TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 16,
        height: 1.193359375,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.32,
        color: glass.textSecondary);
    return SizedBox(
        height: 44,
        child: Row(children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: choices.isEmpty
                      ? const SizedBox.shrink()
                      : PopupMenuButton<String>(
                          tooltip:
                              choices.firstWhere((c) => c.id == selected).label,
                          offset: const Offset(0, 44),
                          // Figma 1107:10552 Drop shadow X0 Y0 blur20 spread0
                          // #919497 30% — Material elevation(아래로 치우친
                          // 그림자) 대신 테두리가 직접 그린다.
                          elevation: 0,
                          constraints:
                              const BoxConstraints.tightFor(width: 200),
                          menuPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          color: glass.surfaceHeader,
                          surfaceTintColor: glass.surfaceHeader,
                          shape: VivaShadowRoundedBorder(
                              shadow: vivaFloatingShadow(glass),
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: onSelected,
                          itemBuilder: (_) => [
                            for (var i = 0; i < choices.length; i++)
                              PopupMenuItem<String>(
                                  value: choices[i].id,
                                  height: 44,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 44),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                          border: i < choices.length - 1
                                              ? Border(
                                                  bottom: BorderSide(
                                                      color: glass.border))
                                              : null),
                                      child: Row(children: [
                                        Expanded(
                                            child: Text(choices[i].label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: style.copyWith(
                                                    fontSize: 18,
                                                    color: choices[i].id ==
                                                            selected
                                                        ? glass.textPrimary
                                                        : glass.textSecondary,
                                                    letterSpacing: -.36,
                                                    height: 28 / 18,
                                                    fontWeight: choices[i].id ==
                                                            selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500))),
                                        if (choices[i].id == selected) ...[
                                          const SizedBox(width: 8),
                                          ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 80),
                                              child: Text(
                                                  'redesign_selected'.tr(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: style.copyWith(
                                                      fontSize: 18,
                                                      letterSpacing: -.36,
                                                      height: 28 / 18,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          glass.navSelected))),
                                        ],
                                      ]))),
                          ],
                          child: Container(
                              key: pillKey,
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                  color: glass.surfaceTint,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                        child: Text(
                                            choices
                                                .firstWhere(
                                                    (c) => c.id == selected)
                                                .label,
                                            style: style,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 4),
                                    FigmaIcon.tinted(FigmaIcons.dropdown,
                                        key: arrowKey,
                                        color: glass.textSecondary,
                                        size: 24),
                                  ])),
                        ))),
          const SizedBox(width: 12),
          SizedBox(
              key: managementKey,
              width: 44,
              height: 44,
              child: PopupMenuButton<String>(
                  tooltip: 'redesign_manage'.tr(),
                  iconSize: 44,
                  offset: const Offset(0, 44),
                  padding: EdgeInsets.zero,
                  // 1056:3009 SelectList — 세트 드롭다운과 같은 그림자로 본다.
                  // 면·줄은 Figma 1063:7422 SelectList(흰 r12, 안쪽 8·4, 줄 44,
                  // 500/18/28 #3C3C3C, 줄 사이 선) — 전엔 기본 Material 메뉴였다
                  // (2026-10-20 시뮬레이터 대조).
                  elevation: 0,
                  color: glass.surfaceHeader,
                  surfaceTintColor: glass.surfaceHeader,
                  shape: VivaShadowRoundedBorder(
                      shadow: vivaFloatingShadow(glass),
                      borderRadius: BorderRadius.circular(12)),
                  menuPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  constraints: const BoxConstraints(minWidth: 149),
                  onSelected: (route) => context.push(route),
                  itemBuilder: (_) => [
                        for (final (i, (route, key)) in const [
                          ('/devices/add', 'redesign_device_add'),
                          ('/devices/manage', 'redesign_device_manage'),
                          ('/my-pets/manage', 'redesign_pet_manage'),
                        ].indexed)
                          PopupMenuItem(
                              value: route,
                              height: 44,
                              padding: EdgeInsets.zero,
                              child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 44),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: i == 2
                                      ? null
                                      : BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: glass.border))),
                                  child: Text(key.tr(),
                                      maxLines: 1,
                                      softWrap: false,
                                      style: style.copyWith(
                                          fontSize: 18,
                                          letterSpacing: -.36,
                                          height: 28 / 18,
                                          fontWeight: FontWeight.w500,
                                          color: glass.textSecondary)))),
                      ],
                  icon: FigmaIcon.tinted(FigmaIcons.management,
                      color: glass.textSecondary, size: 44))),
          const SizedBox(width: 12),
          SizedBox(
              key: accountKey,
              width: 44,
              height: 44,
              child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'home_account'.tr(),
                  onPressed: () => context.push('/profile'),
                  icon: FigmaIcon.tinted(FigmaIcons.person,
                      color: glass.textSecondary, size: 24))),
        ]));
  }
}
