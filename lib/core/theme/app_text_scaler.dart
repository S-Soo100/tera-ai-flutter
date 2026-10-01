import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 앱 전역 글자 배율 = **Figma 크기 그대로(1.0)** × 휴대폰 글자 크기 설정
/// (UX-06, 2026-10-01). 최대 2.0배.
///
/// 2026-06-12~10-01은 디자인 기준을 1.15배로 덮어써 Figma 16이 18.4로 보였다.
/// 2026-10-01 사용자 결정으로 모든 글자를 Figma 크기로 되돌렸다 — 기본
/// 설정(시스템 1.0)에선 코드에 적힌 크기 그대로, 사용자가 키운 만큼만 커진다.
/// 안드로이드 14+의 비선형 배율도 그대로 따른다.
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system);

  /// 디자인 기준 배율 — 1.0 = Figma 글자 크기 그대로. 다시 키우지 말 것.
  static const double base = 1.0;

  /// 상한. 이보다 크면 고정 높이 행·버튼이 대부분 깨진다.
  static const double maxFactor = 2.0;

  final TextScaler system;

  @override
  double scale(double fontSize) =>
      math.min(system.scale(fontSize) * base, fontSize * maxFactor);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor =>
      // ignore: deprecated_member_use
      math.min(system.textScaleFactor * base, maxFactor);

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.system == system;

  @override
  int get hashCode => Object.hash(AppTextScaler, system);

  @override
  String toString() => 'AppTextScaler($system × $base, max $maxFactor)';
}
