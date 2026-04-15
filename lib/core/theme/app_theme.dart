import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // 레퍼런스 디자인 색상 팔레트
  static const _amber = Color(0xFFFF8F00); // Amber 800 — 메인 액센트
  static const _amberLight = Color(0xFFFFB300); // Amber 600 — 밝은 변형
  static const _surface = Color(0xFF121212); // 메인 배경
  static const _surfaceContainer = Color(0xFF1E1E1E); // 카드/컨테이너
  static const _surfaceContainerHigh = Color(0xFF2A2A2A); // 상위 컨테이너

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _amber,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.notoSansTextTheme(),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _amber,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _amberLight,
      onPrimary: Colors.black,
      secondary: _amber,
      surface: _surface,
      onSurface: const Color(0xFFE0E0E0),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      surfaceContainerLow: const Color(0xFF161616),
      surfaceContainer: _surfaceContainer,
      surfaceContainerHigh: _surfaceContainerHigh,
      surfaceContainerHighest: const Color(0xFF333333),
      primaryContainer: const Color(0xFF3A2800),
      onPrimaryContainer: _amberLight,
      secondaryContainer: const Color(0xFF2E2000),
      onSecondaryContainer: const Color(0xFFFFDEA6),
      errorContainer: const Color(0xFF3B1010),
      onErrorContainer: const Color(0xFFFFB4AB),
      outline: const Color(0xFF444444),
      outlineVariant: const Color(0xFF333333),
      onSurfaceVariant: const Color(0xFF9E9E9E),
    );

    final baseTextTheme = GoogleFonts.notoSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surface,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: const Color(0xFFE0E0E0),
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _amber.withValues(alpha: 0.2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF444444)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _amber, width: 2),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: _amber,
        labelColor: _amberLight,
        unselectedLabelColor: const Color(0xFF9E9E9E),
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
