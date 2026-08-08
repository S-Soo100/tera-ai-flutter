import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════════════════════════════
  // Figma `Asset` 섹션 컬러 팔레트
  // 출처: `docs/figma-final-design-transcript.md` §4.1 (라벨된 색상 칩)
  // Figma에 발행된 스타일이 0개라 노드 fill에서 직접 읽어 수동 매핑한 값이다.
  // ══════════════════════════════════════════════════════════════════════════

  /// **메인컬러**. 버튼 Primary·Chip Enabled·Tabs Selected·Toast 아이콘이 전부 이 색.
  /// (2026-08-08 이전 Green 800 `#2E7D32`에서 교체 — PRD 결정 로그 D2)
  static const brandNavy = Color(0xFF192553);

  /// **브랜드컬러**. 원문 주석 "어디에 쓸지 좀고민~" — **용도 미정이라 아직 어디에도
  /// 배정하지 않는다.** 쓸 곳이 정해지면 그때 연결할 것.
  static const brandRed = Color(0xFFD61619);

  /// Primary 계열 Disabled 배경.
  static const neutralDisabled = Color(0xFF9DA3BA);

  /// 쿨그레이 — Outlined 계열 Disabled 전경.
  static const neutralCoolGray = Color(0xFFA9B3BE);

  static const textTitle = Color(0xFF1E1E1E); // 폰트 타이틀
  static const textBody = Color(0xFF3C3C3C); // 폰트 본문
  static const textMuted = Color(0xFF919497); // 중요도 낮은 텍스트
  static const lineColor = Color(0xFFE1E3E4); // 라인컬러
  static const surfaceMuted = Color(0xFFEAEEF0); // Chip Disabled 배경·Tabs 보더

  // ── 서브컬러 (Figma: "여기는 위에있는 컬러 아니고 서브컬러들") ──
  // Tag의 배경/전경 쌍으로만 정의돼 있다. 의미는 지정돼 있지 않다.
  static const subBlueBg = Color(0xFFE5EEFF);
  static const subBlue = Color(0xFF0069F1);
  static const subGreenBg = Color(0xFFDFF9EE);
  static const subGreen = Color(0xFF27C37A);
  static const subPurpleBg = Color(0xFFF4F0FF);
  static const subPurple = Color(0xFF996BFF);
  static const subRedBg = Color(0xFFFFF0F0);
  static const subRed = Color(0xFFF94245);
  static const subGrayBg = Color(0xFFEAEEF0);
  static const subGray = Color(0xFF3C3C3C);

  // ── 의미색 — ⚠️ Figma에 정의가 없어 이 앱이 정한 값 ──

  /// 정상·온라인. Figma 서브컬러 초록을 그대로 쓴다.
  static const success = subGreen;

  /// 경고·주의(히터 안전확인, 잠금 안내 등).
  /// **Figma에 경고색이 없다.** 서브 빨강(`#f94245`)은 "위험"에 더 가깝고
  /// 브랜드 빨강(`#d61619`)은 용도 미정이라, 기존 Amber 800을 그대로 유지했다.
  /// Figma가 경고색을 정하면 **이 한 줄만** 바꾸면 된다.
  static const warning = Color(0xFFFF8F00);

  /// 위험·오류. Figma 서브컬러 빨강.
  static const danger = subRed;

  // ── 차트 지표 색상 (Figma §3.1) ──
  // 온·습도는 앱 전체에서 **같은 색으로 읽혀야** 해서 토큰으로 고정한다.

  /// 온도 지표. Figma `#ff3752`.
  static const chartTemperature = Color(0xFFFF3752);

  /// 습도 지표. Figma `#8abcfc`.
  static const chartHumidity = Color(0xFF8ABCFC);

  // ── 다크 테마 전용 — ⚠️ Figma에 다크 팔레트가 없어 이 앱이 도출한 값 ──

  /// 다크에서의 메인컬러.
  ///
  /// [brandNavy]는 명도 21%의 어두운 남색이라 다크 배경 위에서 대비가 나오지
  /// 않는다. **색상(228°)과 채도(54%)는 그대로 두고 명도만 21% → 65%로 올린**
  /// 값이다. Figma가 다크 팔레트를 주면 교체할 것.
  static const brandNavyDark = Color(0xFF768AD6);

  static const _surfaceDark = Color(0xFF121212);
  static const _surfaceContainerDark = Color(0xFF1E1E1E);
  static const _surfaceContainerHighDark = Color(0xFF2A2A2A);

  static const _pretendard = 'Pretendard';

  static TextTheme _buildTextTheme({required Brightness brightness}) {
    final baseColor = brightness == Brightness.dark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF1A1A1A);
    return TextTheme(
      displayLarge: TextStyle(fontFamily: _pretendard, color: baseColor),
      displayMedium: TextStyle(fontFamily: _pretendard, color: baseColor),
      displaySmall: TextStyle(fontFamily: _pretendard, color: baseColor),
      headlineLarge: TextStyle(fontFamily: _pretendard, color: baseColor),
      headlineMedium: TextStyle(fontFamily: _pretendard, color: baseColor),
      headlineSmall: TextStyle(fontFamily: _pretendard, color: baseColor),
      titleLarge: TextStyle(
        fontFamily: _pretendard,
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(fontFamily: _pretendard, color: baseColor),
      titleSmall: TextStyle(fontFamily: _pretendard, color: baseColor),
      bodyLarge: TextStyle(fontFamily: _pretendard, color: baseColor),
      bodyMedium: TextStyle(fontFamily: _pretendard, color: baseColor),
      bodySmall: TextStyle(fontFamily: _pretendard, color: baseColor),
      labelLarge: TextStyle(fontFamily: _pretendard, color: baseColor),
      labelMedium: TextStyle(fontFamily: _pretendard, color: baseColor),
      labelSmall: TextStyle(fontFamily: _pretendard, color: baseColor),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandNavy,
      brightness: Brightness.light,
    ).copyWith(
      primary: brandNavy,
      onPrimary: Colors.white,
      // secondary는 Figma에 정의가 없다 → seed(brandNavy)에서 파생된 값을 그대로 쓴다.
      surface: const Color(0xFFFAFAFA),
      onSurface: textTitle,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F5F5),
      surfaceContainer: const Color(0xFFEEEEEE),
      surfaceContainerHigh: const Color(0xFFE0E0E0),
      surfaceContainerHighest: const Color(0xFFD6D6D6),
      outline: lineColor,
      outlineVariant: lineColor,
      onSurfaceVariant: textMuted,
    );

    final textTheme = _buildTextTheme(brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      disabledColor: neutralDisabled,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: textTitle),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lineColor),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        indicatorColor: brandNavy.withValues(alpha: 0.15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: neutralDisabled,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEEEEEE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandNavy, width: 2),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: brandNavy,
        labelColor: brandNavy,
        unselectedLabelColor: textMuted,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        collapsedIconColor: textMuted,
        iconColor: textTitle,
      ),
      dividerTheme: const DividerThemeData(color: lineColor),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandNavy,
      brightness: Brightness.dark,
    ).copyWith(
      // 다크는 Figma에 팔레트가 없다 — brandNavyDark 도출값을 쓴다(주석 참조).
      primary: brandNavyDark,
      onPrimary: Colors.black,
      surface: _surfaceDark,
      onSurface: const Color(0xFFE0E0E0),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      surfaceContainerLow: const Color(0xFF161616),
      surfaceContainer: _surfaceContainerDark,
      surfaceContainerHigh: _surfaceContainerHighDark,
      surfaceContainerHighest: const Color(0xFF333333),
      primaryContainer: const Color(0xFF16204A),
      onPrimaryContainer: brandNavyDark,
      errorContainer: const Color(0xFF3B1010),
      onErrorContainer: const Color(0xFFFFB4AB),
      outline: const Color(0xFF444444),
      outlineVariant: const Color(0xFF333333),
      onSurfaceVariant: const Color(0xFF9E9E9E),
    );

    final textTheme = _buildTextTheme(brightness: Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      disabledColor: neutralDisabled,
      scaffoldBackgroundColor: _surfaceDark,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainerDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceContainerHighDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brandNavyDark.withValues(alpha: 0.2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandNavyDark,
          foregroundColor: Colors.black,
          disabledBackgroundColor: neutralDisabled,
          disabledForegroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainerDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF444444)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandNavyDark, width: 2),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: brandNavyDark,
        labelColor: brandNavyDark,
        unselectedLabelColor: Color(0xFF9E9E9E),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        collapsedIconColor: Color(0xFF9E9E9E),
        iconColor: Color(0xFFE0E0E0),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
      ),
    );
  }
}
