import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../domain/redesign_management.dart';
import '../management_colors.dart';

class ManagementTopBar extends StatelessWidget {
  const ManagementTopBar(
      {super.key,
      required this.title,
      required this.onBack,
      this.close = false,
      this.onClose});
  final String title;
  final VoidCallback onBack;

  /// true면 단일 버튼이 오른쪽 닫기(X)가 된다.
  final bool close;

  /// 왼쪽 뒤로가기와 별도로 오른쪽 닫기를 함께 둔다(Figma 982:3103 TopNav).
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 44,
      child: Stack(alignment: Alignment.center, children: [
        Text(title,
            style: managementStyle(context,
                weight: FontWeight.w700, color: context.glass.textPrimary)),
        Align(
            alignment: close ? Alignment.centerRight : Alignment.centerLeft,
            child: SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                    padding: const EdgeInsets.all(10),
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    onPressed: onBack,
                    tooltip: 'management_back'.tr(),
                    icon: FigmaIcon.tinted(
                        close ? FigmaIcons.close : FigmaIcons.arrowPrevious,
                        size: 24,
                        color: context.glass.textPrimary)))),
        if (!close && onClose != null)
          Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                      key: const Key('management_top_close'),
                      padding: const EdgeInsets.all(10),
                      constraints:
                          const BoxConstraints.tightFor(width: 44, height: 44),
                      onPressed: onClose,
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      icon: FigmaIcon.tinted(FigmaIcons.close,
                          size: 24, color: context.glass.textPrimary)))),
      ]));
}

TextStyle managementStyle(BuildContext context,
        {double size = 16,
        FontWeight weight = FontWeight.w500,
        Color? color}) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -size * .02,
        height: 1.193359375,
        color: color ?? context.glass.textSecondary);

class ManagementLabel extends StatelessWidget {
  const ManagementLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(text,
          style: managementStyle(context, color: context.glass.textTertiary)));
}

class ManagementButton extends StatelessWidget {
  const ManagementButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.red = false,
      this.compact = false,
      this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool red;
  final bool compact;

  /// 글자 앞 24 그림(Figma restart_alt 등) — 간격 4.
  final String? icon;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints:
          BoxConstraints(minWidth: double.infinity, minHeight: compact ? 44 : 56),
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                  horizontal: 24, vertical: compact ? 8 : 14),
              backgroundColor:
                  red ? context.glass.navSelected : context.glass.textPrimary,
              disabledBackgroundColor: context.glass.border,
              foregroundColor: ManagementColors.buttonForeground(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon case final asset?) ...[
              FigmaIcon.tinted(asset,
                  size: 24, color: ManagementColors.buttonForeground(context)),
              const SizedBox(width: 4),
            ],
            Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: managementStyle(context,
                            size: compact ? 16 : 18,
                            weight: FontWeight.w600,
                            color: ManagementColors.buttonForeground(context))
                        .copyWith(height: 28 / (compact ? 16 : 18)))),
          ])));
}

class ManagementNameField extends StatelessWidget {
  const ManagementNameField(
      {super.key,
      required this.initialName,
      required this.onChanged,
      this.errorKey,
      this.enabled = true,
      this.errorBelowField = false});
  final String initialName;
  final ValueChanged<String> onChanged;
  final String? errorKey;
  final bool enabled;
  final bool errorBelowField;
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.glass.border));
    final field = TextFormField(
        initialValue: initialName,
        enabled: enabled,
        onChanged: onChanged,
        maxLength: 10,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        style: managementStyle(context, color: context.glass.textPrimary),
        decoration: InputDecoration(
            filled: true,
            fillColor: ManagementColors.nameField(context),
            contentPadding: const EdgeInsets.fromLTRB(16, 23, 13, 23),
            counterText: '',
            suffixText: '${Characters(initialName).length}/10',
            suffixStyle:
                managementStyle(context, color: context.glass.textTertiary),
            errorText: errorBelowField ? null : errorKey?.tr(),
            enabledBorder: errorBelowField ? border : null,
            focusedBorder: errorBelowField ? border : null,
            border: border));
    if (!errorBelowField) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      field,
      if (errorKey != null)
        Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
            child: Semantics(
                liveRegion: true,
                child: Text(errorKey!.tr(),
                    style: managementStyle(context,
                        size: 12, color: context.glass.navSelected)))),
    ]);
  }
}

class ManagementSymbolBadge extends StatelessWidget {
  const ManagementSymbolBadge(this.icon, {super.key});
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: context.glass.textSecondary, shape: BoxShape.circle),
      child: SizedBox.square(
          dimension: 20,
          child: Center(
              // These exports are cropped to the artwork. Restore their
              // original size inside Figma's 20pt icon frame.
              child: FigmaIcon.tinted(icon,
                  size: switch (icon) {
                    'redesign_v2/power_settings_new' => 17,
                    'redesign_v2/workspaces' => 15,
                    _ => 20,
                  },
                  color: context.glass.surfaceHeader))));
}

class ManagementItemIcon extends StatelessWidget {
  const ManagementItemIcon(this.kind, {super.key, this.backgroundColor});
  final Color? backgroundColor;
  final ManagementKind kind;
  @override
  Widget build(BuildContext context) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: backgroundColor ?? context.glass.textSecondary,
          shape: BoxShape.circle),
      alignment: Alignment.center,
      child: FigmaIcon.tinted(
          switch (kind) {
            ManagementKind.device => 'nav_home',
            ManagementKind.camera => 'nav_camera',
            ManagementKind.pet => 'nav_mycre',
          },
          size: 20,
          color: context.glass.surfaceHeader));
}

class ManagementItemRow extends StatelessWidget {
  const ManagementItemRow(
      {super.key,
      required this.item,
      this.groupName,
      this.onTap,
      this.selected,
      this.showArrow = true});
  final ManagementItem item;
  final String? groupName;
  final VoidCallback? onTap;
  final bool? selected;
  final bool showArrow;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return InkWell(
        onTap: onTap,
        child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: glass.border, width: .5))),
            child: Row(children: [
              ManagementItemIcon(item.key.kind),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            managementStyle(context, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        item.key.kind == ManagementKind.pet
                            ? item.subtitle ?? '--'
                            : 'management_power_on_label'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: managementStyle(context,
                            size: 14, color: glass.textTertiary)),
                  ])),
              const SizedBox(width: 8),
              if (item.hardwareId != null || groupName != null)
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .46),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.hardwareId != null)
                            Text(item.hardwareId!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context,
                                    weight: FontWeight.w600,
                                    color: glass.textPrimary)),
                          if (groupName != null)
                            Text(groupName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: managementStyle(context,
                                    size: 14, color: glass.textTertiary)),
                        ])),
              if (selected != null)
                Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: FigmaIcon.tinted(
                        selected!
                            ? 'redesign_v2/check_box_400'
                            : 'redesign_v2/check_box_outline_blank_400',
                        color: selected! ? glass.navSelected : glass.deviceOff,
                        size: 24))
              else if (showArrow)
                Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: FigmaIcon.tinted(FigmaIcons.arrowNext,
                        size: 18, color: glass.textSecondary)),
            ])));
  }
}

class ManagementGroupCard extends StatelessWidget {
  const ManagementGroupCard(
      {super.key,
      required this.group,
      required this.members,
      required this.onTap});
  final ManagementGroup group;
  final List<ManagementItem> members;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: context.glass.overlay,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      group.number == null
                          ? 'management_group'.tr()
                          : 'management_group_number'
                              .tr(namedArgs: {'number': '${group.number}'}),
                      style: managementStyle(context,
                          color: context.glass.textTertiary)),
                  const SizedBox(height: 16),
                  Text(group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: managementStyle(context, weight: FontWeight.w600)),
                ])),
            for (final kind in ManagementKind.values
                .where((k) => members.any((i) => i.key.kind == k)))
              Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ManagementItemIcon(kind)),
            const SizedBox(width: 8),
            FigmaIcon.tinted(FigmaIcons.arrowNext,
                size: 18, color: context.glass.textSecondary),
          ])));
}

/// Korean topic particle selection for Hangul and default numeric names.
/// Unknown pronunciations retain the neutral combined form in localization.
bool? managementNameHasFinalConsonant(String name) {
  final value = name.trim();
  if (value.isEmpty) return null;
  final last = value.runes.last;
  if (last >= 0xAC00 && last <= 0xD7A3) return (last - 0xAC00) % 28 != 0;
  if (last >= 0x30 && last <= 0x39) {
    return const {0, 1, 3, 6, 7, 8}.contains(last - 0x30);
  }
  return null;
}

String managementMoveMessage({
  required String item,
  required String sourceGroup,
  String? targetGroup,
}) {
  final topicKey = switch (managementNameHasFinalConsonant(item)) {
    true => 'management_topic_final',
    false => 'management_topic_open',
    null => 'management_topic_unknown',
  };
  return 'management_move_confirm'.tr(namedArgs: {
    'item': topicKey.tr(namedArgs: {'name': item}),
    'group': sourceGroup,
    'target': targetGroup == null
        ? 'management_new_group'.tr()
        : 'management_target_group'.tr(namedArgs: {'name': targetGroup}),
  });
}

Future<bool> managementConfirm(BuildContext context, String message,
        {String? action}) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
            backgroundColor: context.glass.surfaceHeader,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(message,
                      textAlign: TextAlign.center,
                      style: managementStyle(context,
                              size: 18, color: context.glass.textPrimary)
                          .copyWith(height: 28 / 18)),
                  const SizedBox(height: 24),
                  SizedBox(
                      height: 44,
                      child: Row(children: [
                        Expanded(
                            child: ManagementButton(
                                compact: true,
                                label: 'management_cancel'.tr(),
                                onPressed: () =>
                                    Navigator.pop(context, false))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: ManagementButton(
                                compact: true,
                                label: action ?? 'management_confirm'.tr(),
                                red: true,
                                onPressed: () => Navigator.pop(context, true))),
                      ])),
                ])))) ??
    false;
