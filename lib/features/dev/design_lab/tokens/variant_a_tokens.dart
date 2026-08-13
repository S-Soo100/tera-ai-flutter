import 'package:flutter/material.dart';

/// A안 — Apple Home (iOS 26, Liquid Glass) 토큰.
///
/// 스펙: 배경 위 유리 타일. 콘텐츠가 바닥이고 UI는 반투명 레이어로 뜬다.
/// `AppTheme`/`AppStyles` 참조 금지 — 랩 격리.
abstract final class VariantATokens {
  // ── 배경 (딥 그라데이션 월페이퍼: 네이비→틸, 비바나트 브랜드 도출) ──
  static const wallpaperTop = Color(0xFF141E45); // brandNavy 근방
  static const wallpaperMid = Color(0xFF1B3A5C);
  static const wallpaperBottom = Color(0xFF0F5E5A); // 틸

  // ── 유리 타일 ──
  static const double blurSigma = 24;
  static const glassOverlay = Color(0x24FFFFFF); // 흰색 ~14%
  static const glassOverlayStrong = Color(0x2EFFFFFF); // ~18%
  static const glassBorder = Color(0x33FFFFFF);
  static const double tileRadius = 26;

  // ── 활성 타일: 불투명 흰색 + 기기색 틴트 ──
  static const activeTile = Color(0xFFF7F7FA);
  static const heaterTint = Color(0xFFFF8F45); // 주황
  static const mistTint = Color(0xFF4AA8FF); // 파랑
  static const ledTint = Color(0xFFFFC93C); // 노랑
  static const fanTint = Color(0xFF4FD8C4); // 민트

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
