import 'package:flutter/material.dart';

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
  static Color tagColor(String tag) {
    switch (tag) {
      case '입문':
        return const Color(0xFF2E7D32);
      case '인기':
        return const Color(0xFFE65100);
      case '야행성':
        return const Color(0xFF4527A0);
      case '수목성':
        return const Color(0xFF00838F);
      case '합법':
        return const Color(0xFF1565C0);
      case '상세 정보':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF546E7A);
    }
  }

  // ── 상태 색상 ──
  static const feedingColor = Color(0xFF2E7D32);
  static const sheddingColor = Color(0xFFE65100);
  static const weightColor = Color(0xFF1565C0);
  static const healthColor = Color(0xFFC62828);
  static const noteColor = Color(0xFF546E7A);

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
