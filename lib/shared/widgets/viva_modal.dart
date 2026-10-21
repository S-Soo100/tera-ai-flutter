import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass_palette.dart';
import '../../features/my_cage/presentation/management_colors.dart';
import '../../features/my_cage/presentation/widgets/management_widgets.dart';
import 'viva_shadow.dart';

/// Figma 확인 모달(1142:8956 Modal / 1107:9697) — 345×144 흰색 r12, 안쪽 24,
/// 문구 18/500/28 가운데, 24 아래 버튼 44 r12. 버튼 하나(297 폭 `#1E1E1E`)
/// 또는 둘(취소 검정 + 확인 [confirmColor], 사이 13). 버튼 모서리는 12 — Figma의
/// 두 버튼 모달 28곳 중 27곳이 12다(2026-10-20 대조, 옛 시안 987:4507만 8).
///
/// [detail]은 문구 아래 보조 설명(Figma 밖, 2026-09-30 시청 기기 전환에서 추가 —
/// 제목만으론 결과를 알 수 없을 때).
///
/// [dismissOn]이 끝나면 창이 아직 떠 있을 때 스스로 닫힌다(false) — 창을 띄운
/// 이유가 사라졌을 때(예: 녹화 중단 확인 중 녹화가 2분에 끝남, 2026-10-21).
///
/// 돌려주는 값: 확인 true, 취소·바깥 탭·자동 닫힘 false.
Future<bool> showVivaModal(
  BuildContext context, {
  required String message,
  String? detail,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmColor,
  Key? confirmKey,
  Future<void>? dismissOn,
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
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: managementStyle(ctx, weight: FontWeight.w600)
                          .copyWith(height: 28 / 16)),
                  child: Text(label)));
      // 그림자는 Figma 떠 있는 면 공통(X0 Y0 Blur20 #919497 30%) — Dialog
      // 기본 elevation(아래로 치우친 검은 그림자) 대신 면에 직접 단다.
      final dialog = Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: DecoratedBox(
              key: const Key('viva_modal_surface'),
              decoration: BoxDecoration(
                  color: glass.surfaceHeader,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [vivaFloatingShadow(glass)]),
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
                            if (detail != null) ...[
                              const SizedBox(height: 8),
                              Text(detail,
                                  key: const Key('viva_modal_detail'),
                                  textAlign: TextAlign.center,
                                  style: managementStyle(ctx,
                                          size: 14, color: glass.bodySecondary)
                                      .copyWith(height: 20 / 14)),
                            ],
                            const SizedBox(height: 24),
                            if (!two)
                              button(
                                  confirmLabel ?? 'common_confirm'.tr(),
                                  confirmColor ?? glass.textPrimary,
                                  true,
                                  confirmKey ?? const Key('viva_modal_confirm'))
                            else
                              Row(children: [
                                Expanded(
                                    child: button(
                                        cancelLabel,
                                        glass.textPrimary,
                                        false,
                                        const Key('viva_modal_cancel'))),
                                const SizedBox(width: 13),
                                Expanded(
                                    child: button(
                                        confirmLabel ?? 'common_confirm'.tr(),
                                        confirmColor ?? glass.navSelected,
                                        true,
                                        confirmKey ??
                                            const Key('viva_modal_confirm'))),
                              ]),
                          ])))));
      return dismissOn == null
          ? dialog
          : _DismissOn(signal: dismissOn, child: dialog);
    },
  );
  return ok == true;
}

/// [signal]이 끝나면 자기 라우트를 걷는다(이미 닫혔으면 아무것도 안 함).
class _DismissOn extends StatefulWidget {
  const _DismissOn({required this.signal, required this.child});
  final Future<void> signal;
  final Widget child;

  @override
  State<_DismissOn> createState() => _DismissOnState();
}

class _DismissOnState extends State<_DismissOn> {
  @override
  void initState() {
    super.initState();
    widget.signal.then((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive) return;
      if (route.isCurrent) {
        Navigator.of(context).pop(false);
      } else {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
