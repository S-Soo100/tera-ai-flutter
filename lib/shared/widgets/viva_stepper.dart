import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass_palette.dart';

/// 스테퍼 120×32(Figma Stepper 1635:5116, S27) — `[−] 값 [+]`.
///
/// 버튼 32×32 r12: 기본 `#3C3C3C`(textSecondary), 눌림 `#1E1E1E`(textPrimary),
/// 비활성 `#E3E3E3`(border). 글리프는 `#FAFAFA`(buttonForeground) — 비활성도
/// 같은 색이라 회색 위에서 옅게 보인다(원본 그대로). 값 18/600 행간 21.5
/// `#1E1E1E`, 버튼 사이 56 칸 가운데.
///
/// 콜백이 null이면 그 버튼은 비활성이다(`StepMinus_disabled`/`StepPlus_disabled`).
/// 값의 단위·스텝·한계 판단은 호출부가 한다 — 이 위젯은 그리기만 한다.
class VivaStepper extends StatelessWidget {
  const VivaStepper({
    super.key,
    required this.value,
    this.onDecrease,
    this.onIncrease,
  });

  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  static const decreaseKey = Key('viva_stepper_decrease');
  static const increaseKey = Key('viva_stepper_increase');
  static const valueKey = Key('viva_stepper_value');

  static const double width = 120;
  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SizedBox(
      width: width,
      height: height,
      child: Row(children: [
        _StepButton(
            key: decreaseKey,
            icon: Icons.remove_rounded,
            label: 'viva_stepper_decrease'.tr(),
            onPressed: onDecrease),
        SizedBox(
          width: width - height * 2,
          child: Center(
            // 글자를 키운 휴대폰에서도 56 칸을 넘지 않게 줄여서 맞춘다.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  key: valueKey,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 21.5 / 18,
                      letterSpacing: -0.36,
                      color: glass.textPrimary)),
            ),
          ),
        ),
        _StepButton(
            key: increaseKey,
            icon: Icons.add_rounded,
            label: 'viva_stepper_increase'.tr(),
            onPressed: onIncrease),
      ]),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: VivaStepper.height,
        child: FilledButton(
          onPressed: onPressed,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize:
                const WidgetStatePropertyAll(Size.square(VivaStepper.height)),
            fixedSize:
                const WidgetStatePropertyAll(Size.square(VivaStepper.height)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: const WidgetStatePropertyAll(0),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            // 눌림은 물결이 아니라 면 색 전환(S27 `StepPlus_pressed`).
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return glass.border;
              if (states.contains(WidgetState.pressed)) {
                return glass.textPrimary;
              }
              return glass.textSecondary;
            }),
            foregroundColor: WidgetStatePropertyAll(glass.buttonForeground),
          ),
          child: Icon(icon, size: 20, color: glass.buttonForeground),
        ),
      ),
    );
  }
}
