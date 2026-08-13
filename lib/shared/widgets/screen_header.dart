import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 헤더 액션 아이콘. 미읽음 등 알림 점을 붙일 수 있다.
///
/// 구 `ScreenHeader`(56pt 고정 헤더)는 모든 탭이 [GlassTabHeader]로 넘어가며
/// 참조가 0이 되어 삭제했다 — 이 파일에는 액션 아이콘만 남는다.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showDot = false,
    this.dotKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// 주의를 끌 일이 있는가(미읽음 알림 등).
  final bool showDot;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (showDot)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              key: dotKey,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                // 시스템 색을 쓴다. 예전엔 Colors.red 하드코딩이었다.
                color: AppTheme.subRed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
