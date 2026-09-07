import 'package:flutter/material.dart';

/// 랩 셸 공용 ☀️/🌙 토글 — 시안(A/B)이 각자 문법의 버튼 껍데기([builder])를
/// 대고, 여기서는 의미(어느 모드로 갈지)·접근성만 맡는다.
///
/// 아이콘은 **누르면 될 모드**가 아니라 **지금 모드**를 보여준다 — 지금
/// 다크면 🌙. 상태 표시가 먼저고 전환은 탭이 말한다.
class LabModeToggle extends StatelessWidget {
  const LabModeToggle({
    super.key,
    required this.brightness,
    required this.onToggle,
    required this.builder,
  });

  final Brightness brightness;
  final VoidCallback onToggle;
  final Widget Function(BuildContext context, IconData icon) builder;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: dark ? '라이트 모드로' : '다크 모드로',
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: builder(context,
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      ),
    );
  }
}

/// 셸 안 Material 기본값(잉크·DefaultTextStyle·스크롤바 등)을 시안 밝기에
/// 맞춘다. 실앱 `AppTheme`은 참조하지 않는다 — 랩 격리. 폰트만 바깥 테마의
/// 것을 이어받아 글꼴이 바뀌지 않게 한다.
class LabThemeScope extends StatelessWidget {
  const LabThemeScope({
    super.key,
    required this.brightness,
    required this.child,
  });

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outer = Theme.of(context);
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        fontFamily: outer.textTheme.bodyMedium?.fontFamily,
      ),
      child: child,
    );
  }
}
