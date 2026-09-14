import 'package:flutter/material.dart';

/// Figma `vivnanaut` → `VIVA` 컬렉션의 원본 컬러 토큰.
///
/// 출처: Figma `Final Design` 페이지의 VIVA 컬렉션 17개 변수.
/// 화면에서는 이 상수 대신 Theme.of(context) / context.glass의 역할색을
/// 사용한다. Main/Sub의 Dark/Light는 색 변형 이름이며 테마 모드가 아니다.
abstract final class VivaColors {
  // Labels
  static const labelPrimary = Color(0xFF1E1E1E);
  static const labelSecondary = Color(0xFF3C3C3C);
  static const labelTertiary = Color(0xFF626262);
  static const labelQuaternary = Color(0xFF949090);

  // Fill
  static const fillIcon = Color(0xFFB4AEAE);
  static const fillLine = Color(0xFFE3E3E3);
  static const fillButton = Color(0xFFF4F4F4);
  static const fillBack = Color(0xFFFAFAFA);

  // Color
  static const mainDark = Color(0xFFC00306);
  static const mainLight = Color(0xFFD61619);
  static const subDark = Color(0xFF192553);
  static const subLight = Color(0xFF2E408C);
  static const pink = Color(0xFFDA4A6A);
  static const yellow = Color(0xFFE89E00);
  static const green = Color(0xFF228C73);
  static const blue = Color(0xFF2A97DB);
  static const purple = Color(0xFF636DDB);
}
