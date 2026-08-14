import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'wallpaper_background.dart';

/// 4탭 루트(홈/통계/마이크레/커뮤니티) 공통 프레임 — **A안 표면 규칙의 단일
/// 출처**다. 화면마다 수기로 세우면 규칙 주석까지 네 벌이 되고, 한 곳만
/// 고쳐진 채 남는다.
///
/// 규칙(2026-08-13, Liquid Glass):
/// - 바닥은 [WallpaperBackground](월페이퍼) — UI는 그 위에 뜬 유리 레이어다.
///   Scaffold 배경도 월페이퍼 상단색으로 맞춰 오버스크롤에서 흰 바닥이
///   비치지 않게 한다.
/// - 다크 팔레트는 **앱 전역**이 보장한다(`app.dart`의 `themeMode: dark`,
///   2026-08-14) — 화면별 Theme 래핑은 하지 않는다.
/// - `SafeArea(bottom: false)` — 콘텐츠가 플로팅 독 뒤로 스크롤되고,
///   화면 안의 스크롤 뷰가 `MediaQuery.padding.bottom`(독 높이)을 소비한다
///   (`glassDockListPadding` 참조).
class GlassTabShell extends StatelessWidget {
  const GlassTabShell({super.key, required this.child});

  /// SafeArea 안에 앉는 화면 본문(Column·ListView 등).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.glassWallpaperTop,
      body: Stack(
        children: [
          const Positioned.fill(child: WallpaperBackground()),
          SafeArea(bottom: false, child: child),
        ],
      ),
    );
  }
}
