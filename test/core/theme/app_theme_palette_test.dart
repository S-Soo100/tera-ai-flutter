import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/core/theme/app_styles.dart';
import 'package:tera_ai/core/theme/app_theme.dart';

/// Figma `Asset` 섹션 팔레트가 코드와 어긋나지 않게 고정한다.
/// 값 출처: `docs/figma-final-design-transcript.md` §4.1
void main() {
  group('Figma 팔레트 원본값', () {
    test('메인컬러는 #192553 — 구 Green 800(#2E7D32)으로 되돌아가면 안 된다', () {
      expect(AppTheme.brandNavy, const Color(0xFF192553));
      expect(AppTheme.brandNavy, isNot(const Color(0xFF2E7D32)));
    });

    test('브랜드컬러 #d61619와 서브 빨강 #f94245는 다른 색이다', () {
      expect(AppTheme.brandRed, const Color(0xFFD61619));
      expect(AppTheme.subRed, const Color(0xFFF94245));
      expect(AppTheme.brandRed, isNot(AppTheme.subRed));
    });

    test('중립·텍스트 토큰', () {
      expect(AppTheme.neutralDisabled, const Color(0xFF9DA3BA));
      expect(AppTheme.neutralCoolGray, const Color(0xFFA9B3BE));
      expect(AppTheme.textTitle, const Color(0xFF1E1E1E));
      expect(AppTheme.textBody, const Color(0xFF3C3C3C));
      expect(AppTheme.textMuted, const Color(0xFF919497));
      expect(AppTheme.lineColor, const Color(0xFFE1E3E4));
      expect(AppTheme.surfaceMuted, const Color(0xFFEAEEF0));
    });

    test('서브컬러 5쌍', () {
      expect(AppTheme.subBlue, const Color(0xFF0069F1));
      expect(AppTheme.subGreen, const Color(0xFF27C37A));
      expect(AppTheme.subPurple, const Color(0xFF996BFF));
      expect(AppTheme.subRed, const Color(0xFFF94245));
      expect(AppTheme.subGray, const Color(0xFF3C3C3C));
    });

    test('차트 지표색', () {
      expect(AppTheme.chartTemperature, const Color(0xFFFF3752));
      expect(AppTheme.chartHumidity, const Color(0xFF8ABCFC));
    });
  });

  group('라이트 스킴', () {
    test('primary = 메인컬러', () {
      expect(AppTheme.light.colorScheme.primary, AppTheme.brandNavy);
    });

    test('outline·onSurfaceVariant가 Figma 토큰을 쓴다', () {
      final s = AppTheme.light.colorScheme;
      expect(s.outline, AppTheme.lineColor);
      expect(s.onSurfaceVariant, AppTheme.textMuted);
      expect(s.onSurface, AppTheme.textTitle);
    });

    test('disabledColor = Figma Disabled 용', () {
      expect(AppTheme.light.disabledColor, AppTheme.neutralDisabled);
    });
  });

  group('다크 스킴 — Figma 미제공, 도출값', () {
    test('primary는 brandNavy가 아니라 밝힌 변형이다', () {
      final p = AppTheme.dark.colorScheme.primary;
      expect(p, AppTheme.brandNavyDark);
      expect(p, isNot(AppTheme.brandNavy));
    });

    test('다크 배경 대비 — 어두운 원본을 그대로 쓰면 안 된다', () {
      // #121212 위에서 읽히려면 원본(명도 21%)보다 확실히 밝아야 한다.
      expect(
        AppTheme.brandNavyDark.computeLuminance(),
        greaterThan(AppTheme.brandNavy.computeLuminance() * 3),
      );
    });
  });

  group('AppStyles가 Figma 서브컬러만 쓴다', () {
    test('개체 이벤트 5종이 서브컬러 5종과 1:1', () {
      expect(AppStyles.feedingColor, AppTheme.subGreen);
      expect(AppStyles.sheddingColor, AppTheme.subPurple);
      expect(AppStyles.weightColor, AppTheme.subBlue);
      expect(AppStyles.healthColor, AppTheme.subRed);
      expect(AppStyles.noteColor, AppTheme.subGray);
    });

    test('태그 색은 전부 서브컬러 팔레트 안에서 나온다', () {
      // Color는 primitive equality가 없어 const Set을 못 만든다.
      final palette = <Color>[
        AppTheme.subBlue,
        AppTheme.subGreen,
        AppTheme.subPurple,
        AppTheme.subRed,
        AppTheme.subGray,
      ];
      for (final tag in ['입문', '인기', '야행성', '수목성', '합법', '상세 정보', '알수없음']) {
        expect(palette, contains(AppStyles.tagColor(tag)),
            reason: '$tag 가 팔레트 밖 색을 쓴다');
      }
    });
  });
}
