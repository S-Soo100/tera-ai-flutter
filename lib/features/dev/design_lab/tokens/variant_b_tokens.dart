import 'package:flutter/material.dart';

/// B안 — Flighty (공항 전광판 데이터 밀도) 토큰. **다크/라이트 2벌.**
///
/// 스펙: 전광판(FIDS) 위계 — 데이터 라벨은 대문자+자간, 수치는 큰 tabular
/// Bold. 상태 시맨틱(앰버/그린/레드) 엄격 — 두 모드 공통. 라이트는 Flighty
/// 라이트(거의 흰 바닥·흰 카드·텍스트 반전, 전광판 앰버·그린 유지).
/// `AppTheme`/`AppStyles` 참조 금지 — 랩 격리. 정적 상수였던 것을 2026-08-14
/// 오후 다크/라이트 결정으로 **인스턴스 2벌**로 바꿨다. `VariantBTokens.of(context).x`.
class VariantBTokens {
  const VariantBTokens.dark()
      : brightness = Brightness.dark,
        background = const Color(0xFF0B0F1A),
        card = const Color(0xFF161B2C),
        divider = const Color(0x0FFFFFFF),
        textPrimary = Colors.white,
        textSecondary = const Color(0x99FFFFFF),
        textTertiary = const Color(0x5CFFFFFF),
        progressTrack = const Color(0x1FFFFFFF),
        tabBar = const Color(0xFF0E1322),
        amber = const Color(0xFFFFB300),
        green = const Color(0xFF34C759),
        red = const Color(0xFFFF453A);

  const VariantBTokens.light()
      : brightness = Brightness.light,
        background = const Color(0xFFF5F6F8),
        card = Colors.white,
        divider = const Color(0x14000000),
        textPrimary = const Color(0xFF12151C),
        textSecondary = const Color(0x9912151C),
        textTertiary = const Color(0x5C12151C),
        progressTrack = const Color(0x1F000000),
        tabBar = Colors.white,
        // 전광판 시맨틱은 유지하되 흰 바닥 대비를 위해 앰버·그린을 살짝 눌렀다.
        amber = const Color(0xFFE09A00),
        green = const Color(0xFF1FA84A),
        red = const Color(0xFFE5382E);

  /// 셸이 내려보낸 토큰. 셸 밖(선택 화면 등)에서는 시스템 밝기를 따른다.
  static VariantBTokens of(BuildContext context) => BLabTheme.of(context);

  final Brightness brightness;

  // ── 배경/카드 ──
  final Color background;
  final Color card;
  final Color divider;
  static const double cardRadius = 16;

  // ── 상태 시맨틱 ──
  final Color amber; // 주의
  final Color green; // 정상
  final Color red; // 경보

  // ── 텍스트 ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// 전광판 데이터 라벨: 11 Medium 대문자 자간 +0.8.
  TextStyle get dataLabel => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
        color: textSecondary,
      );
  TextStyle get bigNumber => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      );
  TextStyle get midNumber => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      );
  TextStyle get body => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );
  TextStyle get bodySecondary => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  /// 색 없음 — 호출부가 상태색을 입힌다.
  static const badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  // ── 진행 바 (비행 진행 바 문법) ──
  final Color progressTrack;
  static const double progressHeight = 6;

  // ── 스페이싱 ──
  static const double screenHPad = 16;
  static const double cardGap = 12;

  // ── 하단 탭바 (미니멀 전광판 톤) ──
  final Color tabBar;
  Color get tabActive => amber;
  Color get tabInactive => textTertiary;
  static const tabLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );
}

/// B안 셸이 토큰 한 벌을 트리 아래로 내려보내는 InheritedWidget(랩 전용).
class BLabTheme extends InheritedWidget {
  const BLabTheme({super.key, required this.tokens, required super.child});

  final VariantBTokens tokens;

  static VariantBTokens of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<BLabTheme>();
    if (inherited != null) return inherited.tokens;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? const VariantBTokens.dark()
        : const VariantBTokens.light();
  }

  @override
  bool updateShouldNotify(BLabTheme old) => old.tokens != tokens;
}
