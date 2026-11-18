import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass_palette.dart';
import '../../features/my_cage/presentation/management_colors.dart';
import '../../features/my_cage/presentation/widgets/management_widgets.dart';
import 'viva_shadow.dart';
import 'word_joiner_span.dart';

/// Figma 확인 모달(1142:8956 Modal / 1107:9697) — 345×144 흰색 r12, 안쪽 24,
/// 문구 18/500/28 가운데, 24 아래 버튼 44 r12. 버튼 하나(297 폭 `#1E1E1E`)
/// 또는 둘(취소 검정 + 확인 [confirmColor], 사이 13). 버튼 모서리는 12 — Figma의
/// 두 버튼 모달 28곳 중 27곳이 12다(2026-10-20 대조, 옛 시안 987:4507만 8).
///
/// [detail]은 문구 아래 보조 설명(Figma 밖, 2026-09-30 시청 기기 전환에서 추가 —
/// 제목만으론 결과를 알 수 없을 때).
///
/// [dismissOn]이 끝나면 창이 아직 떠 있을 때 스스로 닫힌다(false·dismissed) — 창을 띄운
/// 이유가 사라졌을 때(예: 녹화 중단 확인 중 녹화가 2분에 끝남, 2026-10-21).
///
/// 돌려주는 값: 확인 true, 취소·바깥 탭·자동 닫힘 false. 취소 버튼을 직접
/// 눌렀는지 구분해야 하면 [showVivaModalChoice]를 쓴다.
///
/// 뒤 덮개는 다른 대화상자와 같은 테마 값([GlassPalette.modalBarrier] →
/// `DialogThemeData.barrierColor`)을 따른다 — 라이트는 덮지 않는다(Figma).
Future<bool> showVivaModal(
  BuildContext context, {
  required String message,
  String? detail,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmColor,
  Key? confirmKey,
  Future<void>? dismissOn,
}) async =>
    await showVivaModalChoice(context,
        message: message,
        detail: detail,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: confirmColor,
        confirmKey: confirmKey,
        dismissOn: dismissOn) ==
    VivaModalResult.confirm;

/// [showVivaModalChoice]의 결과.
enum VivaModalResult {
  /// 확인 버튼.
  confirm,

  /// 취소 버튼을 **직접** 눌렀다.
  cancel,

  /// 바깥 탭·뒤로 가기·[dismissOn] 자동 닫힘·화면 전환으로 닫혔다.
  dismissed,
}

/// [showVivaModal]과 같은 창이고, 취소 버튼 직접 탭([VivaModalResult.cancel])과
/// 그 밖의 닫힘([VivaModalResult.dismissed])을 구분해 돌려준다(2026-11-16 —
/// 권장 업데이트 창은 [나중에]를 직접 눌렀을 때만 기억한다).
Future<VivaModalResult> showVivaModalChoice(
  BuildContext context, {
  required String message,
  String? detail,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmColor,
  Key? confirmKey,
  Future<void>? dismissOn,
}) async {
  final result = await showDialog<VivaModalResult>(
    context: context,
    useSafeArea: false,
    builder: (ctx) {
      final glass = ctx.glass;
      final two = cancelLabel != null;
      Widget button(
              String label, Color color, VivaModalResult value, Key? key) =>
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
                            Text.rich(wordJoinerSpan(message),
                                key: const Key('viva_modal_message'),
                                textAlign: TextAlign.center,
                                style: managementStyle(ctx,
                                        size: 18, color: glass.textPrimary)
                                    .copyWith(height: 28 / 18)),
                            if (detail != null) ...[
                              const SizedBox(height: 8),
                              Text.rich(wordJoinerSpan(detail),
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
                                  VivaModalResult.confirm,
                                  confirmKey ?? const Key('viva_modal_confirm'))
                            else
                              Row(children: [
                                Expanded(
                                    child: button(
                                        cancelLabel,
                                        glass.textPrimary,
                                        VivaModalResult.cancel,
                                        const Key('viva_modal_cancel'))),
                                const SizedBox(width: 13),
                                Expanded(
                                    child: button(
                                        confirmLabel ?? 'common_confirm'.tr(),
                                        confirmColor ?? glass.navSelected,
                                        VivaModalResult.confirm,
                                        confirmKey ??
                                            const Key('viva_modal_confirm'))),
                              ]),
                          ])))));
      return dismissOn == null
          ? dialog
          : _DismissOn(signal: dismissOn, child: dialog);
    },
  );
  return result ?? VivaModalResult.dismissed;
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
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
