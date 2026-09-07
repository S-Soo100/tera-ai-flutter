import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_palette.dart';

/// 상태 알약. 디자인 시스템 `Components / StatusBadge`.
///
/// **환경 상태**(안심·주의·위험)와 **연결 상태**(LIVE·오프라인·연결 중)를 같은
/// 형태로 쓴다. 배경/전경은 Figma 서브컬러 쌍을 그대로 쓴다.
///
/// ⚠️ **한 번에 하나의 진실만 보여준다.** 이전 홈 화면은 `OFFLINE` 배지(DB
/// presence)와 "카메라 호출 중"(스트림 상태)을 동시에 띄워 서로 모순됐다.
/// 스트림 상태를 알면 그것만 쓰고, 모를 때만 DB presence로 내려간다.
enum StatusTone {
  /// 적정 구간 안. 개체가 편한 상태.
  safe,

  /// 적정을 살짝 벗어남. 지켜봐야 한다.
  caution,

  /// 적정을 크게 벗어남. **개체 폐사로 이어질 수 있다.**
  danger,

  /// 실시간 송출 중.
  live,

  /// 정보 없음·연결 없음. 판단을 유보하는 톤.
  neutral,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.onDark = false,
    this.showDot = true,
  });

  final String label;
  final StatusTone tone;

  /// 어두운 라이브 면 위에 놓이는가. 테마 색 대신 흰색 계열을 쓴다.
  final bool onDark;

  /// 점을 그릴지. `연결 중`처럼 상태가 미정일 때는 끈다.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context);

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.24,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _colors(BuildContext context) {
    if (onDark) {
      // 어두운 면 위에서는 서브컬러 배경이 안 보인다. 흰색 계열로 올린다.
      return switch (tone) {
        StatusTone.live => (
            AppTheme.subRed.withValues(alpha: 0.18),
            const Color(0xFFFF8A8C),
          ),
        StatusTone.danger => (
            AppTheme.subRed.withValues(alpha: 0.22),
            const Color(0xFFFF8A8C),
          ),
        StatusTone.caution => (
            AppTheme.warning.withValues(alpha: 0.20),
            const Color(0xFFFFC46B),
          ),
        StatusTone.safe => (
            AppTheme.subGreen.withValues(alpha: 0.20),
            const Color(0xFF7FE0B4),
          ),
        StatusTone.neutral => (
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.75),
          ),
      };
    }
    // Figma의 `*Bg`는 **라이트 전용 파스텔**이라 다크에서 그대로 쓰면
    // 어두운 화면에 흰 알약이 박힌다. 팔레트가 밝기별로 쌍을 만든다.
    final (base, lightBg) = switch (tone) {
      StatusTone.safe => (AppTheme.subGreen, AppTheme.subGreenBg),
      // ⚠️ 주의 배경은 Figma 미정의 — 앱 도출값(전경 #ff8f00도 마찬가지).
      StatusTone.caution => (AppTheme.warning, const Color(0xFFFFF4E5)),
      StatusTone.danger => (AppTheme.subRed, AppTheme.subRedBg),
      StatusTone.live => (AppTheme.subRed, AppTheme.subRedBg),
      StatusTone.neutral => (AppTheme.textMuted, AppTheme.subGrayBg),
    };
    final t = context.glass.badgeTone(base, lightBg: lightBg);
    return (t.bg, t.fg);
  }
}
