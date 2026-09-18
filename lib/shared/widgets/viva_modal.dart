import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../core/theme/glass_palette.dart';
import '../../features/my_cage/presentation/management_colors.dart';
import '../../features/my_cage/presentation/widgets/management_widgets.dart';

/// Figma 확인 모달(1142:8956 Modal / 1107:9697) — 345×144 흰색 r12, 안쪽 24,
/// 문구 18/500/28 가운데, 24 아래 버튼 44 r12. 버튼 하나(297 폭 `#1E1E1E`)
/// 또는 둘(취소 검정 + 확인 [confirmColor], 사이 13, r8).
///
/// 돌려주는 값: 확인 true, 취소·바깥 탭 false.
Future<bool> showVivaModal(
  BuildContext context, {
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmColor,
  Key? confirmKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    useSafeArea: false,
    builder: (ctx) {
      final glass = ctx.glass;
      final two = cancelLabel != null;
      Widget button(String label, Color color, bool value, Key? key) =>
          SizedBox(
              height: 44,
              child: FilledButton(
                  key: key,
                  onPressed: () => Navigator.pop(ctx, value),
                  style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: ManagementColors.buttonForeground(ctx),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(two ? 8 : 12)),
                      textStyle:
                          managementStyle(ctx, weight: FontWeight.w600)
                              .copyWith(height: 28 / 16)),
                  child: Text(label)));
      return Dialog(
          backgroundColor: glass.surfaceHeader,
          surfaceTintColor: glass.surfaceHeader,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 345),
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(message,
                            key: const Key('viva_modal_message'),
                            textAlign: TextAlign.center,
                            style: managementStyle(ctx,
                                    size: 18, color: glass.textPrimary)
                                .copyWith(height: 28 / 18)),
                        const SizedBox(height: 24),
                        if (!two)
                          button(confirmLabel ?? 'common_confirm'.tr(),
                              confirmColor ?? glass.textPrimary, true,
                              confirmKey ?? const Key('viva_modal_confirm'))
                        else
                          Row(children: [
                            Expanded(
                                child: button(cancelLabel, glass.textPrimary,
                                    false, const Key('viva_modal_cancel'))),
                            const SizedBox(width: 13),
                            Expanded(
                                child: button(
                                    confirmLabel ?? 'common_confirm'.tr(),
                                    confirmColor ?? glass.navSelected,
                                    true,
                                    confirmKey ??
                                        const Key('viva_modal_confirm'))),
                          ]),
                      ]))));
    },
  );
  return ok == true;
}
