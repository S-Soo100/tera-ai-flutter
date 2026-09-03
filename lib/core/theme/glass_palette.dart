import 'package:flutter/material.dart';

/// 디자인 시스템 팔레트 — **다크/라이트 2벌**을 `ThemeExtension`으로 든다.
///
/// **2026-08-14 저녁: B안(Flighty 전광판) 프로덕션 채택.** 값은
/// `features/dev/design_lab/tokens/variant_b_tokens.dart`의 미러다 — 랩 토큰은
/// 비교 페이지용으로 그대로 두고, 실앱은 이 파일 하나만 본다. 라이트가 기본
/// (`themeModeProvider`), 다크는 같은 문법에 값만 반전한 벌이다.
///
/// 문법(FIDS 위계): 단색 바닥 + 흰/짙은 카드(radius 16, 그림자 없음, 얇은
/// divider 테두리) + 데이터 라벨은 작은 대문자 자간([labelCaps]) + 수치는 큰
/// tabular Bold([figure]) + 상태 시맨틱 앰버/그린/레드([signalWarn]/[signalOk]/
/// [signalAlert])는 두 모드 공통. **활성 = 앰버**([activeTile]) — 흰 반전 타일
/// (A안)이 아니다.
///
/// 이름의 `glass`는 1차(Liquid Glass, 2026-08-13)의 역사적 명칭이다 — 값은
/// 2차(2026-08-14)부터 불투명 솔리드고, 3차(B안)도 솔리드다.
/// `docs/design-direction.md` §0.
///
/// 색은 전부 **인스턴스 필드**이고 소비처는 `context.glass.overlay`처럼 현재
/// 테마에서 꺼내 쓴다. 정적 상수로 되돌리지 말 것 — 라이트에서 다크 값이 샌다.
/// 밝기별 예외 처리를 소비처에 두지 말고, 필요하면 여기 필드를 하나 늘릴 것.
@immutable
class GlassPalette extends ThemeExtension<GlassPalette> {
  const GlassPalette({
    required this.brightness,
    required this.wallpaper,
    required this.overlay,
    required this.overlayStrong,
    required this.overlayFaint,
    required this.border,
    required this.tabBar,
    required this.activeTile,
    required this.heaterTint,
    required this.mistTint,
    required this.ledTint,
    required this.fanTint,
    required this.signalOk,
    required this.signalWarn,
    required this.signalAlert,
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
    required this.deviceFan,
    required this.deviceFanBg,
    required this.deviceCool,
    required this.deviceCoolBg,
    required this.deviceLed,
    required this.deviceLedBg,
    required this.deviceLedGauge,
    required this.deviceHeat,
    required this.deviceHeatBg,
    required this.deviceMist,
    required this.deviceMistBg,
    required this.deviceGlyph,
    required this.deviceOff,
    required this.tempAccent,
    required this.humidAccent,
    required this.surfaceTint,
    required this.segmentTrack,
    required this.surfaceHeader,
  });

  /// 이 팔레트가 어느 밝기용인지. [badgeTone]처럼 값이 아니라 **공식**이
  /// 갈리는 곳에서 쓴다.
  final Brightness brightness;

  // ── 바닥 (정적 단색) = B `background` ──
  final Color wallpaper;

  // ── 표면 (불투명 솔리드) = B `card` 기준 ──
  final Color overlay; // 기본 표면 = card
  final Color overlayStrong; // 시트 — card보다 한 단계 또렷
  final Color overlayFaint; // 비활성 표면 — card보다 한 단계 가라앉음
  final Color border; // = B `divider` (흰 6% / 검정 8%)

  /// 하단 전광판 탭바 바닥 = B `tabBar`. 다크에선 카드보다 더 어둡고,
  /// 라이트에선 흰색 — 카드가 아니라 **바닥에 붙은 바**다.
  final Color tabBar;

  /// 활성 타일/세그먼트 — **앰버**(전광판 "주의/점등" 시맨틱). A안의 반전
  /// 뉴트럴 타일이 아니다. 위 텍스트는 [textOnActive](두 모드 모두 짙은 색).
  final Color activeTile;

  // ── 기기 틴트 (B 시맨틱으로 재배정: 히터=앰버·분무=블루·팬=그린·LED=밝은 앰버) ──
  final Color heaterTint;
  final Color mistTint;
  final Color ledTint;
  final Color fanTint;

  // ── 상태 시맨틱 (전광판 3색, 두 모드 같은 역할) ──
  final Color signalOk; // 정상 = green
  final Color signalWarn; // 주의/활성 = amber
  final Color signalAlert; // 경보 = red

  // ── 표면 위 텍스트 위계 ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary; // 비활성
  final Color textOnActive; // 활성(앰버) 타일 위
  final Color textOnActiveSecondary;

  /// LIVE 배지 빨강 = [signalAlert]와 같은 값(별 필드로 두는 이유: 소비처가
  /// "라이브"라는 의미로 읽게 — 경보와 섞이지 않게).
  final Color liveRed;

  // ── 홈 온습도 "애플 날씨 행" 문법 (2026-08-17) — B 앰버 옷 ──
  /// 범위 바 채움 왼쪽(최저) → 오른쪽(최고). 애플의 노랑→주황을 B 앰버로 수렴.
  final Color weatherBarWarmStart;
  final Color weatherBarWarmEnd;
  final Color weatherBarTrack; // = B `progressTrack`

  /// 오늘 행의 현재 온도 점 — 흰 채움 + 테두리(다크: 카드색, 라이트: 짙은 색).
  final Color weatherDot;
  final Color weatherDotBorder;
  final Color weatherRowDivider;

  // ── 시간축 차트 (EnvChart 공용) — B 바닥 대비로 재도출 ──
  /// 미도래 구간 밴드 — `지금 ~ 창 끝`.
  final Color chartFutureBand;

  /// "지금" 경계선.
  final Color chartNowLine;

  /// 동작 마커 칩 배경(14×14, radius 4).
  final Color chartMarkerChip;

  /// 차트 격자선. `dividerColor`를 쓰지 않는다 — M3에서 그 값은
  /// `outlineVariant`로 풀려 디자인이 정한 색과 다르다.
  final Color chartGridLine;

  /// 동작 마커 글리프 — 또렷해야 한다.
  final Color chartMarkerGlyph;

  /// 밤 띠(22:00~06:00). 미도래 밴드(중성)와 **색상**으로 갈리도록 블루 기.
  final Color nightBand;

  /// 본문 보조 텍스트 — 축 눈금보다 한 단 진하다.
  final Color bodySecondary;

  // ── shimmer 스켈레톤 ──
  final Color skeletonBase;
  final Color skeletonHighlight;

  // ── 기기 상태색 (Figma Asset 팔레트, 2026-09-02 — PRD 재설계 1단계) ──
  // 켜짐 타일은 `deviceX`(아이콘/글리프) + `deviceXBg`(타일 배경) 한 쌍.
  // 꺼짐은 공통 [deviceOff]. 다크벌은 Figma에 없어 같은 hue의 도출값이다.
  final Color deviceFan; // 환기팬 그린
  final Color deviceFanBg;
  final Color deviceCool; // 냉각팬 블루
  final Color deviceCoolBg;
  final Color deviceLed; // LED 앰버
  final Color deviceLedBg;
  final Color deviceLedGauge; // LED 밝기 게이지 채움
  final Color deviceHeat; // 히터팬 (⚠️ Figma 미정의 — 도출값)
  final Color deviceHeatBg;
  final Color deviceMist; // 분무 = [humidAccent]와 같은 값(의미 분리용 별 필드)
  final Color deviceMistBg; // 분무 잠금(작동 중) 타일 배경 — mistTint(전경)와 역할 분리
  final Color deviceGlyph; // 기기색/deviceOff 원 **안** 글리프 — 하드코딩 white 금지(리뷰 2026-09-03)
  final Color deviceOff; // 꺼짐 상태 아이콘 원 배경

  // ── 온습도 지표 액센트 (홈 요약·상세 차트 라인) ──
  final Color tempAccent; // 온도 핑크
  final Color humidAccent; // 습도 블루

  // ── 연회색 면 3종 (Figma Asset) ──
  final Color surfaceTint; // 헤더 필·온습도 카드·꺼짐 타일·탭바 top stroke
  final Color segmentTrack; // 세그먼트 트랙
  final Color surfaceHeader; // 상세 상단바·제어기록 섹션 배경

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

  /// 전광판 데이터 라벨 — 11 Medium, 자간 +0.8, 2차 텍스트색. 영문이면
  /// 대문자로 쓴다(`toUpperCase()`는 호출부 책임 — 한글엔 대소문자가 없다).
  TextStyle get labelCaps => _kLabelCaps.copyWith(color: textSecondary);

  /// 전광판 수치 — 28 Bold tabular. 라이브 헤더·오늘 밤 카드의 주인공 숫자.
  TextStyle get figure => _kFigure.copyWith(color: textPrimary);

  /// 전광판 수치(중) — 22 Bold tabular. 카드 안 보조 수치.
  TextStyle get figureMid => _kFigureMid.copyWith(color: textPrimary);

  /// 하단 탭바 라벨 — 12 Medium, 자간 -2%(Figma). 색은 호출부(활성=primary).
  TextStyle get dockLabel => _kDockLabel.copyWith(color: textTertiary);

  /// 서브컬러 배지의 배경·전경 한 쌍.
  ///
  /// 라이트: Figma의 `*Bg` 파스텔([lightBg])을 그대로 깔고 글자는 원색.
  /// 다크: 그 파스텔을 그대로 깔면 어두운 화면에 흰 알약이 박혀 주인공이 아닌
  /// 배지가 화면에서 제일 밝아진다. 같은 색을 낮은 투명도로 깔고, 글자는 밝은
  /// 쪽으로 올린다. [lightBg]가 없으면(Figma 미정의 색) 원색 14%로 대신한다.
  ({Color bg, Color fg}) badgeTone(Color base, {Color? lightBg}) =>
      brightness == Brightness.dark
          ? (
              bg: base.withValues(alpha: 0.20),
              fg: Color.lerp(base, Colors.white, 0.35)!,
            )
          : (bg: lightBg ?? base.withValues(alpha: 0.14), fg: base);

  // ── 다크 (B 다크 토큰 미러) ──
  static const dark = GlassPalette(
    brightness: Brightness.dark,
    wallpaper: Color(0xFF0B0F1A), // B background
    overlay: Color(0xFF161B2C), // B card
    overlayStrong: Color(0xFF1C2236), // card +1
    overlayFaint: Color(0xFF111624), // card -1
    border: Color(0x0FFFFFFF), // B divider — 흰 6%
    tabBar: Color(0xFF0E1322), // B tabBar
    activeTile: Color(0xFFFFB300), // B amber
    heaterTint: Color(0xFFFFB300), // amber
    mistTint: Color(0xFF4A90D9), // B 블루(신규)
    ledTint: Color(0xFFFFD54F), // 밝은 앰버
    fanTint: Color(0xFF34C759), // B green
    signalOk: Color(0xFF34C759),
    signalWarn: Color(0xFFFFB300),
    signalAlert: Color(0xFFFF453A),
    textPrimary: Colors.white,
    textSecondary: Color(0x99FFFFFF), // 60%
    textTertiary: Color(0x5CFFFFFF), // 36%
    textOnActive: Color(0xFF12151C),
    textOnActiveSecondary: Color(0x9912151C),
    liveRed: Color(0xFFFF453A), // B red
    weatherBarWarmStart: Color(0xFFFFD54F),
    weatherBarWarmEnd: Color(0xFFFFB300), // amber
    weatherBarTrack: Color(0x1FFFFFFF), // B progressTrack — 흰 12%
    weatherDot: Colors.white,
    weatherDotBorder: Color(0xFF161B2C), // = overlay
    weatherRowDivider: Color(0x0FFFFFFF), // 흰 6%
    chartFutureBand: Color(0x0FFFFFFF), // 흰 6%
    chartNowLine: Color(0x61FFFFFF), // 흰 38%
    chartMarkerChip: Color(0x1FFFFFFF), // 흰 12%
    chartGridLine: Color(0x14FFFFFF), // 흰 8% — 더 어두운 바닥이라 A(10%)보다 연하게
    chartMarkerGlyph: Color(0xDEFFFFFF), // 흰 87%
    nightBand: Color(0x2E4A90D9), // B 블루 18%
    bodySecondary: Color(0xFFC9CDD2),
    skeletonBase: Color(0xFF1E2438),
    skeletonHighlight: Color(0xFF2A3148),
    // 기기 상태색 — 라이트와 같은 hue. Bg는 카드(#161B2C) 위 20% 블렌드 도출값.
    deviceFan: Color(0xFF00B591),
    deviceFanBg: Color(0xFF123A40),
    deviceCool: Color(0xFF6B7FFF),
    deviceCoolBg: Color(0xFF272F56),
    deviceLed: Color(0xFFF5A800),
    deviceLedBg: Color(0xFF433723),
    deviceLedGauge: Color(0xFF644C1D),
    deviceHeat: Color(0xFFFF6B57),
    deviceHeatBg: Color(0xFF452B35),
    deviceMist: Color(0xFF00B2F3),
    deviceMistBg: Color(0xFF10333D), // 다크 카드 위 humidAccent 저명도 도출
    deviceGlyph: Color(0xFFFFFFFF),
    deviceOff: Color(0xFF3A4152),
    tempAccent: Color(0xFFF85478),
    humidAccent: Color(0xFF00B2F3),
    surfaceTint: Color(0xFF1A2032),
    segmentTrack: Color(0xFF1E2438),
    surfaceHeader: Color(0xFF0E1322),
  );

  // ── 라이트 (Figma `Asset` 팔레트 미러 — 기본 모드, 2026-09-02 교체) ──
  // 값 출처: docs/plans/2026-09-02-prd-redesign-phase1-home.md §A.1
  static const light = GlassPalette(
    brightness: Brightness.light,
    wallpaper: Color(0xFFFFFFFF), // 페이지 바닥 흰색
    overlay: Color(0xFFFFFFFF), // 카드 흰색(테두리로 구분)
    overlayStrong: Color(0xFFFAFBFD), // = surfaceHeader
    overlayFaint: Color(0xFFEAEEF0), // surfaceSubtle — 비활성 칩 배경
    border: Color(0xFFE1E3E4), // 칩 테두리·상단바 하단선
    tabBar: Color(0xFFFFFFFF),
    activeTile: Color(0xFFE09A00), // (교체 목록 외 — B 앰버 유지)
    heaterTint: Color(0xFFE09A00), // 전경(글리프) — 배경은 deviceHeatBg (리뷰 2026-09-03 역할 통일)
    mistTint: Color(0xFF2F7BD1), // 전경(글리프) — 배경은 deviceMistBg
    ledTint: Color(0xFFE8B33A), // 전경(글리프) — 배경은 deviceLedBg
    fanTint: Color(0xFF1FA84A), // 전경(글리프) — 배경은 deviceFanBg
    signalOk: Color(0xFF00B591),
    signalWarn: Color(0xFFF5A800),
    signalAlert: Color(0xFFD61619), // 브랜드 레드 — 위험 상태 예약
    textPrimary: Color(0xFF1E1E1E), // textStrong
    textSecondary: Color(0xFF3C3C3C), // textBody
    textTertiary: Color(0xFF919497), // textMuted
    textOnActive: Color(0xFF12151C),
    textOnActiveSecondary: Color(0x9912151C),
    liveRed: Color(0xFFE5382E),
    weatherBarWarmStart: Color(0xFFFFD54F),
    weatherBarWarmEnd: Color(0xFFF5A800), // 신 앰버로 근사 조정
    weatherBarTrack: Color(0xFFEAEEF0), // surfaceSubtle
    weatherDot: Colors.white,
    weatherDotBorder: Color(0xFF1E1E1E), // 짙은 테두리 — 흰 카드 위 가시성
    weatherRowDivider: Color(0x0F000000), // 검정 6%
    chartFutureBand: Color(0x0A000000), // 검정 4%
    chartNowLine: Color(0x611E1E1E), // 38%
    chartMarkerChip: Color(0xFFEAEEF0), // surfaceSubtle
    chartGridLine: Color(0x14000000), // 검정 8%
    chartMarkerGlyph: Color(0xFF3C3C3C), // textBody
    nightBand: Color(0x1A00B2F3), // 신 습도 블루 10%
    bodySecondary: Color(0xFF626262), // textMid
    skeletonBase: Color(0xFFE0E0E0), // grey 300
    skeletonHighlight: Color(0xFFF5F5F5), // grey 100
    // 기기 상태색 (Figma A.1)
    deviceFan: Color(0xFF00B591),
    deviceFanBg: Color(0xFFDCF5E9),
    deviceCool: Color(0xFF6B7FFF),
    deviceCoolBg: Color(0xFFE0E5FF),
    deviceLed: Color(0xFFF5A800),
    deviceLedBg: Color(0xFFFFF4D9),
    deviceLedGauge: Color(0xFFFFE2A3),
    deviceHeat: Color(0xFFFF6B57), // 도출값
    deviceHeatBg: Color(0xFFFFE9E4), // 도출값
    deviceMist: Color(0xFF00B2F3),
    deviceMistBg: Color(0xFFE0F6FE), // 분무 잠금 타일 Bg — humidAccent 12% 도출(Figma 미정의)
    deviceGlyph: Color(0xFFFFFFFF),
    deviceOff: Color(0xFFA9B3BE),
    tempAccent: Color(0xFFF85478),
    humidAccent: Color(0xFF00B2F3),
    surfaceTint: Color(0xFFF0F4F9),
    segmentTrack: Color(0xFFEFF2F5),
    surfaceHeader: Color(0xFFFAFBFD),
  );

  @override
  GlassPalette copyWith({
    Brightness? brightness,
    Color? wallpaper,
    Color? overlay,
    Color? overlayStrong,
    Color? overlayFaint,
    Color? border,
    Color? tabBar,
    Color? activeTile,
    Color? heaterTint,
    Color? mistTint,
    Color? ledTint,
    Color? fanTint,
    Color? signalOk,
    Color? signalWarn,
    Color? signalAlert,
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
    Color? deviceFan,
    Color? deviceFanBg,
    Color? deviceCool,
    Color? deviceCoolBg,
    Color? deviceLed,
    Color? deviceLedBg,
    Color? deviceLedGauge,
    Color? deviceHeat,
    Color? deviceHeatBg,
    Color? deviceMist,
    Color? deviceMistBg,
    Color? deviceGlyph,
    Color? deviceOff,
    Color? tempAccent,
    Color? humidAccent,
    Color? surfaceTint,
    Color? segmentTrack,
    Color? surfaceHeader,
  }) {
    return GlassPalette(
      brightness: brightness ?? this.brightness,
      wallpaper: wallpaper ?? this.wallpaper,
      overlay: overlay ?? this.overlay,
      overlayStrong: overlayStrong ?? this.overlayStrong,
      overlayFaint: overlayFaint ?? this.overlayFaint,
      border: border ?? this.border,
      tabBar: tabBar ?? this.tabBar,
      activeTile: activeTile ?? this.activeTile,
      heaterTint: heaterTint ?? this.heaterTint,
      mistTint: mistTint ?? this.mistTint,
      ledTint: ledTint ?? this.ledTint,
      fanTint: fanTint ?? this.fanTint,
      signalOk: signalOk ?? this.signalOk,
      signalWarn: signalWarn ?? this.signalWarn,
      signalAlert: signalAlert ?? this.signalAlert,
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
      deviceFan: deviceFan ?? this.deviceFan,
      deviceFanBg: deviceFanBg ?? this.deviceFanBg,
      deviceCool: deviceCool ?? this.deviceCool,
      deviceCoolBg: deviceCoolBg ?? this.deviceCoolBg,
      deviceLed: deviceLed ?? this.deviceLed,
      deviceLedBg: deviceLedBg ?? this.deviceLedBg,
      deviceLedGauge: deviceLedGauge ?? this.deviceLedGauge,
      deviceHeat: deviceHeat ?? this.deviceHeat,
      deviceHeatBg: deviceHeatBg ?? this.deviceHeatBg,
      deviceMist: deviceMist ?? this.deviceMist,
      deviceMistBg: deviceMistBg ?? this.deviceMistBg,
      deviceGlyph: deviceGlyph ?? this.deviceGlyph,
      deviceOff: deviceOff ?? this.deviceOff,
      tempAccent: tempAccent ?? this.tempAccent,
      humidAccent: humidAccent ?? this.humidAccent,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      segmentTrack: segmentTrack ?? this.segmentTrack,
      surfaceHeader: surfaceHeader ?? this.surfaceHeader,
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
      tabBar: c(tabBar, other.tabBar),
      activeTile: c(activeTile, other.activeTile),
      heaterTint: c(heaterTint, other.heaterTint),
      mistTint: c(mistTint, other.mistTint),
      ledTint: c(ledTint, other.ledTint),
      fanTint: c(fanTint, other.fanTint),
      signalOk: c(signalOk, other.signalOk),
      signalWarn: c(signalWarn, other.signalWarn),
      signalAlert: c(signalAlert, other.signalAlert),
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
      deviceFan: c(deviceFan, other.deviceFan),
      deviceFanBg: c(deviceFanBg, other.deviceFanBg),
      deviceCool: c(deviceCool, other.deviceCool),
      deviceCoolBg: c(deviceCoolBg, other.deviceCoolBg),
      deviceLed: c(deviceLed, other.deviceLed),
      deviceLedBg: c(deviceLedBg, other.deviceLedBg),
      deviceLedGauge: c(deviceLedGauge, other.deviceLedGauge),
      deviceHeat: c(deviceHeat, other.deviceHeat),
      deviceHeatBg: c(deviceHeatBg, other.deviceHeatBg),
      deviceMist: c(deviceMist, other.deviceMist),
      deviceMistBg: c(deviceMistBg, other.deviceMistBg),
      deviceGlyph: c(deviceGlyph, other.deviceGlyph),
      deviceOff: c(deviceOff, other.deviceOff),
      tempAccent: c(tempAccent, other.tempAccent),
      humidAccent: c(humidAccent, other.humidAccent),
      surfaceTint: c(surfaceTint, other.surfaceTint),
      segmentTrack: c(segmentTrack, other.segmentTrack),
      surfaceHeader: c(surfaceHeader, other.surfaceHeader),
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
  static const _kLabelCaps = TextStyle(
    fontFamily: _pretendard,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );
  static const _kFigure = TextStyle(
    fontFamily: _pretendard,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _kFigureMid = TextStyle(
    fontFamily: _pretendard,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _kDockLabel = TextStyle(
    fontFamily: _pretendard,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.24, // 12 × -2% (Figma)
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
