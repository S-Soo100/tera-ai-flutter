import 'package:flutter/material.dart';

/// C안 — Copilot Money (프리미엄 데이터 시각화) 토큰.
///
/// 스펙: 웜 화이트 배경 + 채도 높은 그라데이션 차트 + 큰 라운드 수치.
/// `AppTheme`/`AppStyles` 참조 금지 — 랩 격리.
abstract final class VariantCTokens {
  // ── 배경/카드 ──
  static const background = Color(0xFFFAF9F7); // 웜 화이트
  static const card = Colors.white;
  static const cardShadow = BoxShadow(
    color: Color(0x14000000), // 8%
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static const double cardRadius = 20;
  static const double buttonRadius = 14;

  // ── 차트 그라데이션 ──
  static const tempGradStart = Color(0xFFFF7A6B); // 코럴
  static const tempGradEnd = Color(0xFF8B5CF6); // 퍼플
  static const humidGradStart = Color(0xFF3B82F6); // 블루
  static const humidGradEnd = Color(0xFF22D3EE); // 시안
  static const double chartLineWidth = 3;

  // ── 카테고리 파스텔 (Copilot 카테고리 문법) ──
  static const heaterPastel = Color(0xFFFFE3D3); // 피치
  static const heaterOn = Color(0xFFE8663C);
  static const mistPastel = Color(0xFFD8ECFF); // 스카이
  static const mistOn = Color(0xFF3B82F6);
  static const ledPastel = Color(0xFFFFF6C9); // 레몬
  static const ledOn = Color(0xFFD9A400);
  static const fanPastel = Color(0xFFD5F5EC); // 민트
  static const fanOn = Color(0xFF13A084);

  // ── 시맨틱 ──
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);

  // ── 텍스트 ──
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8E);

  /// 대형 수치 40 Bold.
  static const heroNumber = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.05,
  );

  /// 대형 수치의 소수점 이하: 20 Medium 60%.
  static const heroNumberMinor = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: Color(0x991A1A1A),
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );
  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const value = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── 스페이싱 ──
  static const double screenHPad = 16;
  static const double cardGap = 12;

  // ── 하단 탭바 (라이트 라운드 파스텔) ──
  static const tabBar = Colors.white;
  static const tabActiveBg = Color(0xFFEDEBFF); // 라벤더 파스텔
  static const tabActive = Color(0xFF8B5CF6);
  static const tabInactive = Color(0xFFB6B6BC);
  static const double tabBarRadius = 26;
  static const tabLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
}
