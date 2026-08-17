import 'package:flutter/material.dart';

/// A안 — Apple Home 문법, **2차 솔리드 다크**(2026-08-14) 토큰.
///
/// 1차는 Liquid Glass(그라데이션 월페이퍼 + blur 유리)였고, 2차에서 유리를
/// 걷어내 솔리드 표면으로 바꿨다. 값은 실앱 `AppTheme` 글래스 블록의 미러다
/// (이름의 glass는 역사적 명칭). `AppTheme`/`AppStyles` 참조 금지 — 랩 격리.
abstract final class VariantATokens {
  // ── 배경 (정적 단색 — 차분한 딥 네이비. 3벌은 호환용, 동일 톤) ──
  static const wallpaperTop = Color(0xFF141A2E);
  static const wallpaperMid = Color(0xFF141A2E);
  static const wallpaperBottom = Color(0xFF141A2E);

  // ── 솔리드 타일 (blur 없음) ──
  static const glassOverlay = Color(0xFF1E2640); // 기본 표면
  static const glassOverlayStrong = Color(0xFF242D4A); // 독·시트
  static const glassBorder = Color(0x14FFFFFF); // 흰 ~8%
  static const double tileRadius = 20;

  // ── 활성 타일: 밝은 뉴트럴 불투명면 + 기기색 틴트(채도·명도 하향) ──
  static const activeTile = Color(0xFFF2F3F7);
  static const heaterTint = Color(0xFFE8823F); // 주황
  static const mistTint = Color(0xFF4A90D9); // 파랑
  static const ledTint = Color(0xFFE0B341); // 노랑
  static const fanTint = Color(0xFF4DBFAE); // 민트

  // ── 텍스트 ──
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0x99FFFFFF); // 60%
  static const textOnActive = Color(0xFF1C1C1E);
  static const textOnActiveSecondary = Color(0x991C1C1E);

  static const headerTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.1,
  );
  static const headerTitleCollapsed = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const tileTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const tileTitleActive = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textOnActive,
  );
  static const tileStatus = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const tileStatusActive = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textOnActiveSecondary,
  );
  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );
  static const chipValue = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── 상태색 ──
  static const liveRed = Color(0xFFFF453A);

  // ── 스페이싱 ──
  static const double screenHPad = 16;
  static const double tileGap = 12;
}
