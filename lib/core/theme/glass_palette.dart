import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 솔리드 디자인 시스템 팔레트 — **다크/라이트 2벌**을 `ThemeExtension`으로 든다.
///
/// 2026-08-14 오전에 `AppTheme.light`를 지우고 전역 다크로 고정했다가, 같은 날
/// 오후 사용자가 다크/라이트 구분을 요구해 되돌렸다. 되돌리되 정적 상수
/// (`AppTheme.glassX`)로 되돌리지 않는다 — 그 방식은 모드가 바뀌어도 값이
/// 그대로라 라이트에서 다크 값이 새어 나온다. 색은 전부 **인스턴스 필드**이고,
/// 소비처는 `context.glass.overlay`처럼 현재 테마에서 꺼내 쓴다.
///
/// 이름의 `glass`는 1차(Liquid Glass, 2026-08-13)의 역사적 명칭이다 — 값은
/// 2차(2026-08-14)부터 불투명 솔리드다. `docs/design-direction.md` §0.
///
/// **두 벌의 문법은 같다** — 단색 바닥 + 불투명 표면 + 저대비 테두리 + 활성
/// 타일은 바닥과 반전된 면. 값만 뒤집는다. 밝기별 예외 처리를 소비처에 두지
/// 말고, 필요하면 여기 필드를 하나 늘릴 것.
@immutable
class GlassPalette extends ThemeExtension<GlassPalette> {
  const GlassPalette({
    required this.brightness,
    required this.wallpaper,
    required this.overlay,
    required this.overlayStrong,
    required this.overlayFaint,
    required this.border,
    required this.activeTile,
    required this.heaterTint,
    required this.mistTint,
    required this.ledTint,
    required this.fanTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnActive,
    required this.textOnActiveSecondary,
    required this.liveRed,
    required this.weatherBarWarmStart,
    required this.weatherBarWarmEnd,
    required this.weatherBarTrack,
    required this.weatherDot,
    required this.weatherDotBorder,
    required this.weatherRowDivider,
    required this.chartFutureBand,
    required this.chartNowLine,
    required this.chartMarkerChip,
    required this.chartGridLine,
    required this.chartMarkerGlyph,
    required this.nightBand,
    required this.bodySecondary,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// 이 팔레트가 어느 밝기용인지. [badgeTone]처럼 값이 아니라 **공식**이
  /// 갈리는 곳에서 쓴다.
  final Brightness brightness;

  // ── 바닥 (정적 단색). 1차의 Top/Mid/Bottom 3벌은 동일 톤이라 하나로 합쳤다. ──
  final Color wallpaper;

  // ── 표면 (불투명 솔리드) ──
  final Color overlay; // 기본 표면
  final Color overlayStrong; // 독·시트 — 또렷한 표면
  final Color overlayFaint; // 비활성 표면
  final Color border; // 아주 낮은 대비 테두리

  /// 활성 타일 — **바닥과 반전된 불투명면**(Apple Home 문법). 다크에선 밝은
  /// 뉴트럴, 라이트에선 딥 네이비. 위 텍스트는 [textOnActive].
  final Color activeTile;

  // ── 기기 틴트 (활성 타일 아이콘·센서 칩) ──
  final Color heaterTint;
  final Color mistTint;
  final Color ledTint;
  final Color fanTint;

  // ── 표면 위 텍스트 위계 ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary; // 비활성
  final Color textOnActive; // 활성 타일 위
  final Color textOnActiveSecondary;

  /// LIVE 배지 빨강 (iOS 시스템 레드 계열). 두 모드 공통.
  final Color liveRed;

  // ── 홈 온습도 "애플 날씨 행" 문법 (2026-08-17) ──
  /// 범위 바 채움 왼쪽(최저 쪽) → 오른쪽(최고 쪽). 애플 온도 색(노랑→주황)은
  /// 밝은 바닥에서도 읽혀 두 모드 공통이다 — 트랙만 바닥에 맞춘다.
  final Color weatherBarWarmStart;
  final Color weatherBarWarmEnd;
  final Color weatherBarTrack;

  /// 오늘 행의 현재 온도 점 — 흰 채움 + 테두리(애플 시그니처). 다크에선
  /// 테두리가 카드색이라 "구멍"처럼 보이고, 라이트에선 검정 테두리로 흰 점이
  /// 흰 카드에 묻히지 않게 한다.
  final Color weatherDot;
  final Color weatherDotBorder;
  final Color weatherRowDivider;

  // ── 시간축 차트 (EnvChart 공용) ──
  /// 미도래 구간 밴드 — `지금 ~ 창 끝`. 아직 안 지난 시간.
  final Color chartFutureBand;

  /// "지금" 경계선. 굵기가 아니라 색으로 눈에 띄고, 스크러버보다는 연하다.
  final Color chartNowLine;

  /// 동작 마커 칩 배경(14×14, radius 4).
  final Color chartMarkerChip;

  /// 차트 격자선. `dividerColor`를 쓰지 않는다 — M3에서 그 값은
  /// `outlineVariant`로 풀려 Figma가 정한 색과 다르다.
  final Color chartGridLine;

  /// 동작 마커 글리프 — 그 시각에 기기가 실제로 돌았다는 기록. 또렷해야 한다.
  final Color chartMarkerGlyph;

  /// 밤 띠(22:00~06:00). 미도래 밴드(중성 회색)와 **색상**으로 갈리도록
  /// 남색 기가 남을 만큼만 진하게 — 곡선은 가리지 않는다.
  final Color nightBand;

  /// 본문 보조 텍스트 — 축 눈금보다 한 단 진하다. 요약 바의 최고/최저처럼
  /// **읽으라고 둔 값**에 쓴다.
  final Color bodySecondary;

  // ── shimmer 스켈레톤 ──
  final Color skeletonBase;
  final Color skeletonHighlight;

  // ── 표면 위 타이포 (Pretendard 명시 — 공용 위젯은 테마 밖에서도 쓰인다) ──
  // 색만 팔레트에서 오고 크기·굵기는 두 모드 공통이다.

  /// 탭 헤더 제목. 22 SemiBold(2026-08-14, 사용자: "제목이 너무 크다").
  TextStyle get headerTitle => _kHeaderTitle.copyWith(color: textPrimary);
  TextStyle get tileTitle => _kTileTitle.copyWith(color: textPrimary);
  TextStyle get tileTitleActive => _kTileTitle.copyWith(color: textOnActive);
  TextStyle get tileStatus => _kTileStatus.copyWith(color: textSecondary);
  TextStyle get tileStatusActive =>
      _kTileStatus.copyWith(color: textOnActiveSecondary);
  TextStyle get sectionLabel => _kSectionLabel.copyWith(color: textSecondary);
  TextStyle get chipValue => _kChipValue.copyWith(color: textPrimary);

  /// 서브컬러 배지의 배경·전경 한 쌍.
  ///
  /// 라이트: Figma의 `*Bg` 파스텔([lightBg])을 그대로 깔고 글자는 원색.
  /// 다크: 그 파스텔을 그대로 깔면 어두운 화면에 흰 알약이 박혀 주인공이 아닌
  /// 배지가 화면에서 제일 밝아진다(실기기에서 개체 카드의 `수컷` 배지가
  /// 그랬다). 같은 색을 낮은 투명도로 깔고, 글자는 밝은 쪽으로 올린다.
  /// [lightBg]가 없으면(Figma 미정의 색) 원색 14%로 대신한다.
  ({Color bg, Color fg}) badgeTone(Color base, {Color? lightBg}) =>
      brightness == Brightness.dark
          ? (
              bg: base.withValues(alpha: 0.20),
              fg: Color.lerp(base, Colors.white, 0.35)!,
            )
          : (bg: lightBg ?? base.withValues(alpha: 0.14), fg: base);

  // ── 다크 (A안 2차 현행값 그대로) ──
  static const dark = GlassPalette(
    brightness: Brightness.dark,
    wallpaper: Color(0xFF141A2E),
    overlay: Color(0xFF1E2640),
    overlayStrong: Color(0xFF242D4A),
    overlayFaint: Color(0xFF1A2138),
    border: Color(0x14FFFFFF), // 흰 ~8%
    activeTile: Color(0xFFF2F3F7),
    heaterTint: Color(0xFFE8823F),
    mistTint: Color(0xFF4A90D9),
    ledTint: Color(0xFFE0B341),
    fanTint: Color(0xFF4DBFAE),
    textPrimary: Colors.white,
    textSecondary: Color(0x99FFFFFF), // 60%
    textTertiary: Color(0x4DFFFFFF), // 30%
    textOnActive: Color(0xFF1C1C1E),
    textOnActiveSecondary: Color(0x991C1C1E),
    liveRed: Color(0xFFFF453A),
    weatherBarWarmStart: Color(0xFFFFD60A),
    weatherBarWarmEnd: Color(0xFFFF9F0A),
    weatherBarTrack: Color(0x2EFFFFFF), // 흰 18%
    weatherDot: Colors.white,
    weatherDotBorder: Color(0xFF1E2640), // = overlay
    weatherRowDivider: Color(0x0FFFFFFF), // 흰 6%
    chartFutureBand: Color(0x0FFFFFFF), // 흰 6%
    chartNowLine: Color(0x61FFFFFF), // 흰 38%
    chartMarkerChip: Color(0x1FFFFFFF), // 흰 12%
    chartGridLine: Color(0x1AFFFFFF), // 흰 10%
    chartMarkerGlyph: Color(0xDEFFFFFF), // 흰 87%
    nightBand: Color(0x2E768AD6), // brandNavyDark 18%
    bodySecondary: Color(0xFFC9CDD2),
    skeletonBase: Color(0xFF424242), // grey 800
    skeletonHighlight: Color(0xFF616161), // grey 700
  );

  // ── 라이트 (2026-08-14 오후 — 차분·솔리드 문법 유지, 값만 반전) ──
  static const light = GlassPalette(
    brightness: Brightness.light,
    wallpaper: Color(0xFFF4F5F9), // 웜 그레이 바닥
    overlay: Color(0xFFFFFFFF),
    overlayStrong: Color(0xFFF7F8FC),
    overlayFaint: Color(0xFFEDEFF5),
    border: Color(0x14000000), // 검정 8%
    activeTile: Color(0xFF1E2640), // 다크 표면색의 반전 배치 — 딥 네이비
    // 밝은 바닥 대비 확보를 위해 채도·명도를 조금 조정
    heaterTint: Color(0xFFD9702A),
    mistTint: Color(0xFF2F7BD1),
    ledTint: Color(0xFFC79A1F),
    fanTint: Color(0xFF2FA894),
    textPrimary: Color(0xFF14181F),
    textSecondary: Color(0x9914181F), // 60%
    textTertiary: Color(0x5914181F), // 35%
    textOnActive: Colors.white,
    textOnActiveSecondary: Color(0x99FFFFFF),
    liveRed: Color(0xFFFF453A),
    weatherBarWarmStart: Color(0xFFFFD60A),
    weatherBarWarmEnd: Color(0xFFFF9F0A),
    weatherBarTrack: Color(0x1A000000), // 검정 10%
    weatherDot: Colors.white,
    weatherDotBorder: Color(0xFF14181F), // 검정 테두리 — 흰 카드 위 가시성
    weatherRowDivider: Color(0x0F000000), // 검정 6%
    // 차트는 Figma 라이트 원본값 (§3.1)
    chartFutureBand: AppTheme.lineColor,
    chartNowLine: AppTheme.textMuted,
    chartMarkerChip: AppTheme.surfaceMuted,
    chartGridLine: AppTheme.lineColor,
    chartMarkerGlyph: AppTheme.brandNavy,
    nightBand: Color(0x1A192553), // brandNavy 10% — 마침 한밤중 하늘색
    bodySecondary: AppTheme.textBody,
    skeletonBase: Color(0xFFE0E0E0), // grey 300
    skeletonHighlight: Color(0xFFF5F5F5), // grey 100
  );

  @override
  GlassPalette copyWith({
    Brightness? brightness,
    Color? wallpaper,
    Color? overlay,
    Color? overlayStrong,
    Color? overlayFaint,
    Color? border,
    Color? activeTile,
    Color? heaterTint,
    Color? mistTint,
    Color? ledTint,
    Color? fanTint,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnActive,
    Color? textOnActiveSecondary,
    Color? liveRed,
    Color? weatherBarWarmStart,
    Color? weatherBarWarmEnd,
    Color? weatherBarTrack,
    Color? weatherDot,
    Color? weatherDotBorder,
    Color? weatherRowDivider,
    Color? chartFutureBand,
    Color? chartNowLine,
    Color? chartMarkerChip,
    Color? chartGridLine,
    Color? chartMarkerGlyph,
    Color? nightBand,
    Color? bodySecondary,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return GlassPalette(
      brightness: brightness ?? this.brightness,
      wallpaper: wallpaper ?? this.wallpaper,
      overlay: overlay ?? this.overlay,
      overlayStrong: overlayStrong ?? this.overlayStrong,
      overlayFaint: overlayFaint ?? this.overlayFaint,
      border: border ?? this.border,
      activeTile: activeTile ?? this.activeTile,
      heaterTint: heaterTint ?? this.heaterTint,
      mistTint: mistTint ?? this.mistTint,
      ledTint: ledTint ?? this.ledTint,
      fanTint: fanTint ?? this.fanTint,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnActive: textOnActive ?? this.textOnActive,
      textOnActiveSecondary:
          textOnActiveSecondary ?? this.textOnActiveSecondary,
      liveRed: liveRed ?? this.liveRed,
      weatherBarWarmStart: weatherBarWarmStart ?? this.weatherBarWarmStart,
      weatherBarWarmEnd: weatherBarWarmEnd ?? this.weatherBarWarmEnd,
      weatherBarTrack: weatherBarTrack ?? this.weatherBarTrack,
      weatherDot: weatherDot ?? this.weatherDot,
      weatherDotBorder: weatherDotBorder ?? this.weatherDotBorder,
      weatherRowDivider: weatherRowDivider ?? this.weatherRowDivider,
      chartFutureBand: chartFutureBand ?? this.chartFutureBand,
      chartNowLine: chartNowLine ?? this.chartNowLine,
      chartMarkerChip: chartMarkerChip ?? this.chartMarkerChip,
      chartGridLine: chartGridLine ?? this.chartGridLine,
      chartMarkerGlyph: chartMarkerGlyph ?? this.chartMarkerGlyph,
      nightBand: nightBand ?? this.nightBand,
      bodySecondary: bodySecondary ?? this.bodySecondary,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  /// 테마 전환 애니메이션용. 색은 전부 선형 보간, [brightness]는 절반에서
  /// 넘어간다(공식이 갈리는 [badgeTone]이 중간값을 만들지 않게).
  @override
  GlassPalette lerp(ThemeExtension<GlassPalette>? other, double t) {
    if (other is! GlassPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GlassPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      wallpaper: c(wallpaper, other.wallpaper),
      overlay: c(overlay, other.overlay),
      overlayStrong: c(overlayStrong, other.overlayStrong),
      overlayFaint: c(overlayFaint, other.overlayFaint),
      border: c(border, other.border),
      activeTile: c(activeTile, other.activeTile),
      heaterTint: c(heaterTint, other.heaterTint),
      mistTint: c(mistTint, other.mistTint),
      ledTint: c(ledTint, other.ledTint),
      fanTint: c(fanTint, other.fanTint),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textOnActive: c(textOnActive, other.textOnActive),
      textOnActiveSecondary:
          c(textOnActiveSecondary, other.textOnActiveSecondary),
      liveRed: c(liveRed, other.liveRed),
      weatherBarWarmStart: c(weatherBarWarmStart, other.weatherBarWarmStart),
      weatherBarWarmEnd: c(weatherBarWarmEnd, other.weatherBarWarmEnd),
      weatherBarTrack: c(weatherBarTrack, other.weatherBarTrack),
      weatherDot: c(weatherDot, other.weatherDot),
      weatherDotBorder: c(weatherDotBorder, other.weatherDotBorder),
      weatherRowDivider: c(weatherRowDivider, other.weatherRowDivider),
      chartFutureBand: c(chartFutureBand, other.chartFutureBand),
      chartNowLine: c(chartNowLine, other.chartNowLine),
      chartMarkerChip: c(chartMarkerChip, other.chartMarkerChip),
      chartGridLine: c(chartGridLine, other.chartGridLine),
      chartMarkerGlyph: c(chartMarkerGlyph, other.chartMarkerGlyph),
      nightBand: c(nightBand, other.nightBand),
      bodySecondary: c(bodySecondary, other.bodySecondary),
      skeletonBase: c(skeletonBase, other.skeletonBase),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
    );
  }

  static const _pretendard = 'Pretendard';
  static const _kHeaderTitle = TextStyle(
    fontFamily: _pretendard,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const _kTileTitle = TextStyle(
    fontFamily: _pretendard,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const _kTileStatus = TextStyle(
    fontFamily: _pretendard,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  static const _kSectionLabel = TextStyle(
    fontFamily: _pretendard,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  static const _kChipValue = TextStyle(
    fontFamily: _pretendard,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// `context.glass.overlay` — 현재 테마의 팔레트.
///
/// `AppTheme.dark`/`AppTheme.light` 둘 다 extension을 넣으므로 앱 안에서는
/// 항상 있다. extension이 없는 테마(맨 `MaterialApp()`을 띄운 위젯 테스트 등)
/// 에서는 **그 테마의 밝기**로 두 벌 중 하나를 고른다 — 무조건 다크로
/// 떨어지지 않는다(그 폴백이 라이트에서 다크 값이 새는 통로가 된다).
extension GlassPaletteX on BuildContext {
  GlassPalette get glass {
    final theme = Theme.of(this);
    return theme.extension<GlassPalette>() ??
        (theme.brightness == Brightness.dark
            ? GlassPalette.dark
            : GlassPalette.light);
  }
}
