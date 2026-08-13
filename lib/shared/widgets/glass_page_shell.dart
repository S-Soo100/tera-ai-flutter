import 'package:flutter/material.dart';

import 'wallpaper_background.dart';

/// 보조 라우트 경량 유리 래퍼. 디자인 시스템 `Components / GlassPageShell`.
///
/// 탭 밖 화면(위키·검색·설정·CRUD 등)을 **배경+표면 톤만** A안으로 맞춘다 —
/// 깊은 재디자인 없이 [WallpaperBackground] 위에 다크 테마 표면이 놓이게 해
/// 탭 화면과의 위화감을 없앤다. Scaffold·AppBar·폼 로직은 각 화면 그대로.
///
/// 다크 팔레트는 앱 전역이 보장하므로(`app.dart`의 `themeMode: dark`,
/// 2026-08-14) 여기서는 **투명 오버라이드만** 얹는다 — Scaffold·AppBar 배경을
/// 투명으로 만들어 월페이퍼가 비치게 한다. 화면에서 띄우는 시트·다이얼로그도
/// 같은 다크 테마를 이어받는다(탭과 같은 의도된 동작).
class GlassPageShell extends StatelessWidget {
  const GlassPageShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: WallpaperBackground()),
          child,
        ],
      ),
    );
  }
}
