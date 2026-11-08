import 'package:flutter/widgets.dart';

/// 스크롤 뷰포트 아래를 덮는 플로팅 CTA의 높이(뷰포트 바닥 → 버튼 윗변).
///
/// Flutter는 포커스한 입력칸을 뷰포트 끝 20 위까지만 끌어올린다(`scrollPadding`
/// 기본값). 뷰포트 아래를 버튼이 덮고 있으면 칸이 버튼 뒤에 멈춘다 — 작은 폰에서
/// 키보드가 뜨면 입력칸이 안 보이던 원인(2026-11-08). 이 높이를 입력칸의
/// `scrollPadding` 아래 값에 더한다. 개체 정보 입력(`pet_form_screen`)이 먼저 쓴
/// 방식을 공용으로 뺀 것이다.
///
/// 플로팅 CTA를 그리는 화면이 스크롤 뷰를 감싸면 [VivaTextField]가 알아서 읽는다.
/// 이 위젯 밖에서 만든 입력칸은 [scrollPadding]으로 직접 넘긴다.
class FloatingCtaInset extends InheritedWidget {
  const FloatingCtaInset(
      {super.key, required this.bottom, required super.child});

  final double bottom;

  /// 입력칸 `scrollPadding`. Flutter가 올리는 기준은 칸이 아니라 **글자 줄**이라
  /// [gap]은 글자 줄 아래부터 잰다 — 기본 48 = 65 칸의 글자 아래 여백(약 24) +
  /// 버튼과 띄울 24. 칸 아래 안내 문구까지 보이려면 그 높이를 더한다.
  static EdgeInsets scrollPadding(double bottom, {double gap = 48}) =>
      EdgeInsets.fromLTRB(20, 20, 20, bottom + gap);

  /// 감싼 화면이 없으면 Flutter 기본값(20).
  static EdgeInsets scrollPaddingOf(BuildContext context) {
    final inset =
        context.dependOnInheritedWidgetOfExactType<FloatingCtaInset>();
    return inset == null
        ? const EdgeInsets.all(20)
        : scrollPadding(inset.bottom);
  }

  @override
  bool updateShouldNotify(FloatingCtaInset oldWidget) =>
      oldWidget.bottom != bottom;
}
