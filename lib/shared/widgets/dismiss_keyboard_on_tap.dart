import 'package:flutter/widgets.dart';

/// 입력칸 바깥을 탭하면 키보드를 닫는다(앱 전체, `app.dart` builder).
///
/// Flutter 기본값은 휴대폰(터치)에서 바깥 탭으로 포커스를 풀지 않는다 — 여러 줄
/// 입력칸은 엔터가 줄바꿈이라 iOS에선 키보드를 닫을 방법이 없었다(2026-11-12).
/// 버튼·입력칸 등 안쪽 탭 인식기가 제스처 경쟁에서 먼저 이기므로, 이 탭은
/// 아무도 받지 않은 빈 곳에서만 불린다.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      );
}
