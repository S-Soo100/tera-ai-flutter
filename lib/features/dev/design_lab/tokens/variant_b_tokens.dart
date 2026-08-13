import 'package:flutter/material.dart';

/// B안 — Flighty (공항 전광판 데이터 밀도) 토큰.
///
/// 스펙: 다크 고정. 전광판(FIDS) 위계 — 데이터 라벨은 대문자+자간,
/// 수치는 큰 tabular Bold. 상태 시맨틱(앰버/그린/레드) 엄격.
/// `AppTheme`/`AppStyles` 참조 금지 — 랩 격리.
abstract final class VariantBTokens {
  // ── 배경/카드 ──
  static const background = Color(0xFF0B0F1A); // 거의 검정 네이비
  static const card = Color(0xFF161B2C);
  static const divider = Color(0x0FFFFFFF); // 흰 6%
  static const double cardRadius = 16;

  // ── 상태 시맨틱 ──
  static const amber = Color(0xFFFFB300); // 주의
  static const green = Color(0xFF34C759); // 정상
  static const red = Color(0xFFFF453A); // 경보

  // ── 텍스트 ──
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0x99FFFFFF);
  static const textTertiary = Color(0x5CFFFFFF);

  /// 전광판 데이터 라벨: 11 Medium 대문자 자간 +0.8.
  static const dataLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: textSecondary,
  );
  static const bigNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.1,
  );
  static const midNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.1,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  static const bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  static const badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  // ── 진행 바 (비행 진행 바 문법) ──
  static const progressTrack = Color(0x1FFFFFFF);
  static const double progressHeight = 6;

  // ── 스페이싱 ──
  static const double screenHPad = 16;
  static const double cardGap = 12;

  // ── 하단 탭바 (다크 미니멀 전광판 톤) ──
  static const tabBar = Color(0xFF0E1322);
  static const tabActive = amber;
  static const tabInactive = textTertiary;
  static const tabLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );
}
