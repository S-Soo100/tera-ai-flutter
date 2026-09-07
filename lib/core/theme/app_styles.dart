import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 디자인 토큰 — 앱 전체에서 일관된 스타일을 유지하기 위한 중앙 정의
class AppStyles {
  AppStyles._();

  // ── 간격 ──
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  static const pagePadding = EdgeInsets.all(spacing16);

  // ── 태그 색상 ──
  // Figma `Asset` 서브컬러 5종에서 고른다(`AppTheme.sub*`).
  // 태그 종류가 6개인데 서브컬러는 5개라 일부는 색을 공유한다 — Figma가 준
  // 팔레트를 벗어나 색을 새로 만들지 않기 위한 선택이다.
  static Color tagColor(String tag) {
    switch (tag) {
      case '입문':
      case '상세 정보':
        return AppTheme.subGreen;
      case '인기':
        return AppTheme.subRed;
      case '야행성':
        return AppTheme.subPurple;
      case '수목성':
      case '합법':
        return AppTheme.subBlue;
      default:
        return AppTheme.subGray;
    }
  }

  // ── 개체 이벤트 색상 ──
  // 5종이 Figma 서브컬러 5종과 1:1로 맞아떨어진다.
  static const feedingColor = AppTheme.subGreen;
  static const sheddingColor = AppTheme.subPurple;
  static const weightColor = AppTheme.subBlue;
  static const healthColor = AppTheme.subRed;
  static const noteColor = AppTheme.subGray;

  // ── 섹션 타이틀 스타일 ──
  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.bold,
        );
  }

  static TextStyle subsectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w600,
        );
  }

  // ── 카드 radius ──
  static const double cardRadius = 16;
  static const double chipRadius = 8;
}
