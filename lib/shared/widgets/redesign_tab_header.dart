import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/glass_palette.dart';
import 'figma_icon.dart';

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
                          elevation: 6,
                          shadowColor: glass.textPrimary.withValues(alpha: .12),
                          constraints:
                              const BoxConstraints.tightFor(width: 200),
                          menuPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          color: glass.surfaceHeader,
                          surfaceTintColor: glass.surfaceHeader,
                          shape: RoundedRectangleBorder(
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
                  elevation: 0,
                  onSelected: (route) => context.push(route),
                  itemBuilder: (_) => [
                        PopupMenuItem(
                            value: '/devices/add',
                            child: Text('redesign_device_add'.tr())),
                        PopupMenuItem(
                            value: '/devices/manage',
                            child: Text('redesign_device_manage'.tr())),
                        PopupMenuItem(
                            value: '/my-pets/manage',
                            child: Text('redesign_pet_manage'.tr())),
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
