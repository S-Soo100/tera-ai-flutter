import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // 공통 색상
  static const _green = Color(0xFF2E7D32); // Green 800 — 메인 액센트
  static const _greenLight = Color(0xFF4CAF50); // Green 500 — 밝은 변형

  // 다크 전용 색상
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
      seedColor: _green,
      brightness: Brightness.light,
    ).copyWith(
      primary: _green,
      onPrimary: Colors.white,
      secondary: _greenLight,
      surface: const Color(0xFFFAFAFA),
      onSurface: const Color(0xFF1A1A1A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F5F5),
      surfaceContainer: const Color(0xFFEEEEEE),
      surfaceContainerHigh: const Color(0xFFE0E0E0),
      surfaceContainerHighest: const Color(0xFFD6D6D6),
      primaryContainer: const Color(0xFFC8E6C9),
      onPrimaryContainer: const Color(0xFF1B5E20),
      outline: const Color(0xFFBBBBBB),
      outlineVariant: const Color(0xFFDDDDDD),
      onSurfaceVariant: const Color(0xFF616161),
    );

    final textTheme = _buildTextTheme(brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE0E0E0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        indicatorColor: _green.withValues(alpha: 0.15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
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
          borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 2),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: _green,
        labelColor: _green,
        unselectedLabelColor: const Color(0xFF757575),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        collapsedIconColor: Color(0xFF757575),
        iconColor: Color(0xFF1A1A1A),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEEE),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _greenLight,
      onPrimary: Colors.black,
      secondary: _green,
      surface: _surfaceDark,
      onSurface: const Color(0xFFE0E0E0),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      surfaceContainerLow: const Color(0xFF161616),
      surfaceContainer: _surfaceContainerDark,
      surfaceContainerHigh: _surfaceContainerHighDark,
      surfaceContainerHighest: const Color(0xFF333333),
      primaryContainer: const Color(0xFF003A00),
      onPrimaryContainer: _greenLight,
      secondaryContainer: const Color(0xFF002E00),
      onSecondaryContainer: const Color(0xFFA6F5A6),
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
        indicatorColor: _green.withValues(alpha: 0.2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
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
          borderSide: const BorderSide(color: _green, width: 2),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: _green,
        labelColor: _greenLight,
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
