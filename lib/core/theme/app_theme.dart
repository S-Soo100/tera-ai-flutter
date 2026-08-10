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

  /// **미도래 구간 밴드** — 시간축 차트에서 `지금 ~ 창 끝`을 덮는 회색.
  ///
  /// Figma §3.1 "구간 밴드"(`#e1e3e4` = [lineColor])다. 뜻은 **아직 안 지난
  /// 시간** — 선이 여기서 끊긴 게 고장이 아니라 아직 오지 않았다는 표시다.
  ///
  /// 다크에서 원본 값을 그대로 쓰면 어두운 플롯 위에 밝은 띠가 박혀 정작
  /// 읽어야 할 곡선보다 밴드가 먼저 보인다 — [nightBand]와 같은 이유로 뒤집는다.
  static Color chartFutureBand(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : lineColor;

  /// **"지금" 경계선** — 미도래 밴드가 시작하는 자리.
  ///
  /// 밴드만으로는 [nightBand]와 구분이 안 된다. 둘 다 옅은 채움 블록이라 눈이
  /// 같은 범주로 읽는데, 뜻은 정반대다 — 밤 띠는 *데이터가 있는* 구간에 의미를
  /// 붙인 것이고 미도래 밴드는 *데이터가 없는* 구간이다. 시작점에 선을 그으면
  /// 오른쪽 블록이 "이 선 이후"로 읽혀 성격이 갈린다.
  ///
  /// 겸해서 **현재 시각이 그래프의 어디인지**를 알려준다 — 그전에는 곡선이
  /// 끊긴 자리로 짐작하는 수밖에 없었고, 데이터가 비면 그마저 안 됐다.
  ///
  /// 굵기가 아니라 **색**으로 눈에 띄게 한다. 1px을 유지해야 격자선과 같은
  /// "가는 선" 무리에 남는다 — 두껍게 하면 곡선·스크러버와 무게를 다투고,
  /// 경계 표시는 무거울 이유가 없다.
  ///
  /// 스크러버 선(거의 검정)보다는 확실히 연하다. 둘이 경쟁하면 손가락이
  /// 가리키는 자리가 어디인지 헷갈린다.
  static Color chartNowLine(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.38)
          : textMuted;

  /// **동작 마커 칩** 배경 — 차트 위 분무·팬 아이콘이 앉는 자리.
  ///
  /// Figma §3.1 "동작 마커"(14×14, radius 4, `#eaeef0` = [surfaceMuted]).
  static Color chartMarkerChip(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : surfaceMuted;

  /// **차트 격자선** — Figma `#e1e3e4`([lineColor]).
  ///
  /// `Theme.of(context).dividerColor`를 쓰지 않는다. Material 3에서 그 값은
  /// `colorScheme.outlineVariant`로 풀려 Figma가 정한 색과 다르다 —
  /// `dividerTheme`을 지정해도 `dividerColor`는 따라오지 않는다.
  static Color chartGridLine(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.10)
          : lineColor;

  /// **본문 보조 텍스트** — Figma `#3c3c3c`([textBody]).
  ///
  /// 축 눈금([textMuted] `#919497`)보다 한 단계 진하다. 요약 바의 최고/최저처럼
  /// **읽으라고 둔 값**에 쓴다 — 눈금 색으로 낮추면 배경 정보로 읽힌다.
  static Color bodySecondary(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFC9CDD2) : textBody;

  /// **동작 마커 글리프** — 칩 안의 분무·팬 그림.
  ///
  /// Figma는 메인컬러(`#192553`)로 또렷하게 찍었다. 무채색으로 눌러두면
  /// 장식처럼 보이는데, 이 마커는 **그 시각에 기기가 실제로 돌았다는 기록**이라
  /// 읽히지 않으면 없는 것과 같다.
  ///
  /// 다크에서는 남색이 칩 배경에 묻히므로 밝은 쪽으로 뒤집는다.
  static Color chartMarkerGlyph(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.87)
          : brandNavy;

  /// **라이브 영역 면** — 영상이 놓이는 자리.
  ///
  /// 라이트/다크 무관하게 **항상 어둡다.** 영상 뷰포트를 밝은 회색으로 두면
  /// 연결 전 화면이 죽은 공백처럼 보이고(실기기에서 상단 40%가 그랬다),
  /// 야간 관측소라는 이 앱의 정체성과도 어긋난다. 메인컬러 계열의 남색 블랙.
  static const liveSurface = Color(0xFF0E1424);

  /// **밤 띠** 배경 — 시간축 차트에서 `22:00~06:00`을 깔아주는 색.
  ///
  /// 기획안 §3.1 ②의 활동 집계 창을 시각화한 것이다. 야행성 개체를 다루는
  /// 이 앱에서 밤은 "우리 애가 사는 시간"이고, 활동 수치는 그 창에서만 센다.
  /// 데이터 선을 가리면 안 되므로 **아주 낮은 대비**로 유지한다.
  ///
  /// 라이트에서는 메인컬러(마침 한밤중 하늘색이다)를, 다크에서는 흰색을 얹는다
  /// — 어두운 배경 위에 남색을 더 깔면 아무것도 보이지 않는다.
  ///
  /// **[chartFutureBand]와 같은 차트에 함께 깔린다.** 둘 다 옅은 회색 블록이라
  /// 농도만으로는 구분이 안 됐다(실기기에서 왼쪽 밤 띠와 오른쪽 미도래 밴드가
  /// 같은 띠로 보였다). 그래서 밤 띠는 **남색 기가 남을 만큼**만 진하게 잡는다 —
  /// 중성 회색인 미도래 밴드와 색상으로 갈린다. 곡선을 가리지 않는 선은 지킨다.
  /// 다크도 **흰색이 아니라 남색 계열**로 깐다. 흰색으로 두면 미도래 밴드
  /// (역시 흰색 반투명)와 같은 회색이 되어, 라이트에서 색상으로 갈라놓은 구분이
  /// 다크에서만 사라진다(실기기에서 두 띠가 같은 블록으로 보였다).
  /// 어두운 면 위에서는 [brandNavy]가 묻히므로 밝은 쪽 파생값을 쓴다.
  static Color nightBand(Brightness brightness) => brightness == Brightness.dark
      ? brandNavyDark.withValues(alpha: 0.18)
      : brandNavy.withValues(alpha: 0.10);

  /// 서브컬러 배지의 배경·전경 한 쌍.
  ///
  /// **Figma 팔레트의 `*Bg`(연한 파스텔)는 라이트 전용이다.** 다크에서 그대로
  /// 쓰면 어두운 화면에 흰 알약이 박혀, 주인공이 아닌 배지가 화면에서 제일
  /// 밝아진다(실기기에서 개체 카드의 `수컷` 배지가 그랬다).
  ///
  /// 다크에서는 같은 색을 낮은 투명도로 깔고, 글자는 밝은 쪽으로 올린다 —
  /// 진한 서브컬러(`#0069F1` 등)를 그대로 두면 어두운 면에 묻힌다.
  static ({Color bg, Color fg}) subBadgeTone(
    Color base,
    Color lightBg,
    Brightness brightness,
  ) =>
      brightness == Brightness.dark
          ? (
              bg: base.withValues(alpha: 0.20),
              fg: Color.lerp(base, Colors.white, 0.35)!,
            )
          : (bg: lightBg, fg: base);

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
