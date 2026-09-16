import 'dart:ui' show SemanticsValidationResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/glass_palette.dart';
import '../../core/theme/viva_colors.dart';

/// Figma `필드 컴포넌트`(1134:6053) 공용 입력 필드.
///
/// 라벨 16/500 `#949090`(왼쪽 12) → 12 → 필드 65h·radius 12·면 `#FAFAFA`·선
/// `#E3E3E3`(오류 `#C00306`) → 오류 문구 12/500(8 아래). 오류 문구는 아래
/// 항목과의 간격([gapBelow], 기본 24)을 파먹어 뒤 항목이 밀리지 않는다
/// (Figma Login 오류 프레임 1134:6617: 8 + 14 + 2 = 24).
///
/// 로그인·개체 폼·그룹 이름 입력이 공유한다(2026-09-16 계획 B1). 값과 검증은
/// 호출자가 갖고, 이 위젯은 그리기만 한다.
class VivaTextField extends StatelessWidget {
  const VivaTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.errorText,
    this.showErrorBelow = true,
    this.obscureText = false,
    this.suffix,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.gapBelow = 24,
    this.fieldKey,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;

  /// null이 아니면 테두리가 빨갛다. [showErrorBelow]가 false면 문구는 호출자가
  /// 다른 자리에 그린다(로그인 비밀번호 규칙은 체크 행 오른쪽).
  final String? errorText;
  final bool showErrorBelow;
  final bool obscureText;

  /// 필드 오른쪽 17 안쪽의 24 위젯(눈 아이콘 등). [maxLength]와 같이 쓰지 않는다.
  final Widget? suffix;

  /// 지정하면 오른쪽에 `n/max` 카운터(Figma 3/10). 입력 자체는 막지 않는다.
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final double gapBelow;
  final Key? fieldKey;

  static const double fieldHeight = 65;
  static const double _errorBlock = 8 + 14;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final invalid = errorText != null;
    final borderColor = invalid ? glass.navSelected : glass.border;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color));
    final errorShown = invalid && showErrorBelow;
    final bottom =
        errorShown ? (gapBelow - _errorBlock).clamp(0.0, gapBelow) : gapBelow;

    Widget? suffixWidget = suffix;
    if (maxLength != null && controller != null) {
      suffixWidget = ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller!,
          builder: (_, value, __) => Text(
              '${value.text.characters.length}/$maxLength',
              style: vivaFieldText(context, color: glass.textTertiary)));
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(label,
                style: vivaFieldText(context, color: glass.textTertiary))),
        Semantics(
          validationResult: invalid
              ? SemanticsValidationResult.invalid
              : SemanticsValidationResult.none,
          child: SizedBox(
            height: fieldHeight,
            child: TextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autofillHints: autofillHints,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              cursorColor: Theme.of(context).brightness == Brightness.light
                  ? VivaColors.mainLight
                  : glass.navSelected,
              style: vivaFieldText(context),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: vivaFieldFill(context),
                hintText: hintText,
                hintStyle: vivaFieldText(context, color: glass.textTertiary),
                // OutlineInputBorder가 좌우 4를 더해 실제 안쪽 여백은 17(Figma 텍스트 x29).
                contentPadding: const EdgeInsets.fromLTRB(13, 23, 13, 23),
                border: border(borderColor),
                enabledBorder: border(borderColor),
                focusedBorder: border(borderColor),
                disabledBorder: border(borderColor),
                suffixIcon: suffixWidget == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 17),
                        child: suffixWidget),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 24 + 17, minHeight: 24),
              ),
            ),
          ),
        ),
        // Figma Alert: 오른쪽 정렬, 오른쪽 12 안쪽(1133:5771 RIGHT, w357/369).
        if (errorShown)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12),
            child: Semantics(
                liveRegion: true,
                child: Text(errorText!,
                    textAlign: TextAlign.right,
                    style: vivaFieldErrorText(context))),
          ),
      ]),
    );
  }
}

/// 필드 본문·라벨·힌트 공용 서체(16/500, 행간 19.09, 자간 -0.32).
TextStyle vivaFieldText(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 16,
    height: 19.09 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.32,
    color: color ?? context.glass.textPrimary);

/// 오류 안내 12/500, 행간 14.32, 자간 -0.24, `#C00306`.
TextStyle vivaFieldErrorText(BuildContext context) => TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    height: 14.32 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.24,
    color: context.glass.navSelected);

/// 필드 면 — 라이트 `#FAFAFA`(Figma Fill/Back), 다크는 한 단계 가라앉은 면.
Color vivaFieldFill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? VivaColors.fillBack
        : context.glass.overlayFaint;
