import 'package:flutter/material.dart';

/// A안 — Apple Home 문법, **2차 솔리드**(2026-08-14) 토큰. **다크/라이트 2벌.**
///
/// 1차는 Liquid Glass(그라데이션 월페이퍼 + blur 유리)였고, 2차에서 유리를
/// 걷어내 솔리드 표면으로 바꿨다. 값은 실앱 `GlassPalette`(다크/라이트)의
/// 미러다(이름의 glass는 역사적 명칭). `AppTheme`/`AppStyles`/`GlassPalette`
/// 참조 금지 — 랩 격리. 정적 상수였던 것을 2026-08-14 오후 다크/라이트 결정으로
/// **인스턴스 2벌**로 바꿨다. 소비처는 `VariantATokens.of(context).x`.
class VariantATokens {
  const VariantATokens.dark()
      : brightness = Brightness.dark,
        wallpaperTop = const Color(0xFF141A2E),
        wallpaperMid = const Color(0xFF141A2E),
        wallpaperBottom = const Color(0xFF141A2E),
        glassOverlay = const Color(0xFF1E2640),
        glassOverlayStrong = const Color(0xFF242D4A),
        glassBorder = const Color(0x14FFFFFF),
        activeTile = const Color(0xFFF2F3F7),
        heaterTint = const Color(0xFFE8823F),
        mistTint = const Color(0xFF4A90D9),
        ledTint = const Color(0xFFE0B341),
        fanTint = const Color(0xFF4DBFAE),
        textPrimary = Colors.white,
        textSecondary = const Color(0x99FFFFFF),
        textTertiary = const Color(0x4DFFFFFF),
        textOnActive = const Color(0xFF1C1C1E),
        textOnActiveSecondary = const Color(0x991C1C1E),
        rowDivider = const Color(0x0FFFFFFF),
        barTrack = const Color(0x2EFFFFFF),
        dotBorder = const Color(0xFF1E2640),
        liveRed = const Color(0xFFFF453A);

  /// 실앱 `GlassPalette.light` 미러 — 웜 그레이 바닥·흰 표면·딥 네이비 활성 타일.
  const VariantATokens.light()
      : brightness = Brightness.light,
        wallpaperTop = const Color(0xFFF4F5F9),
        wallpaperMid = const Color(0xFFF4F5F9),
        wallpaperBottom = const Color(0xFFF4F5F9),
        glassOverlay = const Color(0xFFFFFFFF),
        glassOverlayStrong = const Color(0xFFF7F8FC),
        glassBorder = const Color(0x14000000),
        activeTile = const Color(0xFF1E2640),
        heaterTint = const Color(0xFFD9702A),
        mistTint = const Color(0xFF2F7BD1),
        ledTint = const Color(0xFFC79A1F),
        fanTint = const Color(0xFF2FA894),
        textPrimary = const Color(0xFF14181F),
        textSecondary = const Color(0x9914181F),
        textTertiary = const Color(0x5914181F),
        textOnActive = Colors.white,
        textOnActiveSecondary = const Color(0x99FFFFFF),
        rowDivider = const Color(0x0F000000),
        barTrack = const Color(0x1A000000),
        dotBorder = const Color(0xFF14181F),
        liveRed = const Color(0xFFFF453A);

  /// 셸이 내려보낸 토큰. 셸 밖(선택 화면 등)에서는 시스템 밝기를 따른다.
  static VariantATokens of(BuildContext context) => ALabTheme.of(context);

  final Brightness brightness;

  // ── 배경 (정적 단색. 3벌은 호환용, 동일 톤) ──
  final Color wallpaperTop;
  final Color wallpaperMid;
  final Color wallpaperBottom;

  // ── 솔리드 타일 (blur 없음) ──
  final Color glassOverlay; // 기본 표면
  final Color glassOverlayStrong; // 독·시트
  final Color glassBorder;
  static const double tileRadius = 20;

  // ── 활성 타일: 바닥과 반전된 불투명면 + 기기색 틴트 ──
  final Color activeTile;
  final Color heaterTint;
  final Color mistTint;
  final Color ledTint;
  final Color fanTint;

  // ── 텍스트 ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnActive;
  final Color textOnActiveSecondary;

  // ── 애플 날씨 행 문법 보조 ──
  final Color rowDivider;
  final Color barTrack;
  final Color dotBorder;

  TextStyle get headerTitle => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.1,
      );
  TextStyle get headerTitleCollapsed => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );
  TextStyle get tileTitle => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );
  TextStyle get tileTitleActive => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textOnActive,
      );
  TextStyle get tileStatus => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );
  TextStyle get tileStatusActive => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textOnActiveSecondary,
      );
  TextStyle get sectionLabel => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      );
  TextStyle get chipValue => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── 상태색 ──
  final Color liveRed;

  // ── 스페이싱 ──
  static const double screenHPad = 16;
  static const double tileGap = 12;
}

/// A안 셸이 토큰 한 벌을 트리 아래로 내려보내는 InheritedWidget(랩 전용).
class ALabTheme extends InheritedWidget {
  const ALabTheme({super.key, required this.tokens, required super.child});

  final VariantATokens tokens;

  static VariantATokens of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<ALabTheme>();
    if (inherited != null) return inherited.tokens;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? const VariantATokens.dark()
        : const VariantATokens.light();
  }

  @override
  bool updateShouldNotify(ALabTheme old) => old.tokens != tokens;
}
