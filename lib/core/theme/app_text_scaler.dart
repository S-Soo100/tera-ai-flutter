import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 앱 전역 글자 배율 = 디자인 기준 1.15배 × **휴대폰 글자 크기 설정**(UX-06,
/// 2026-10-01). 최대 2.0배.
///
/// 2026-06-12부터 전역 1.15배를 고정으로 덮어써(`TextScaler.linear(1.15)`)
/// 휴대폰에서 글자를 키워도 앱 글자가 그대로였다. 기본 설정(시스템 1.0)에선
/// 지금과 똑같이 1.15배라 화면이 바뀌지 않고, 사용자가 키운 만큼만 커진다.
/// 안드로이드 14+의 비선형 배율도 그대로 따른다(시스템 결과에 1.15를 곱함).
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system);

  /// 디자인 기준 배율 — 화면 치수·Figma 대조는 이 배율에서 맞췄다.
  static const double base = 1.15;

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
