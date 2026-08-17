import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/core/theme/app_styles.dart';
import 'package:vivnanaut/core/theme/app_theme.dart';
import 'package:vivnanaut/core/theme/glass_palette.dart';
import 'package:vivnanaut/shared/widgets/glass_card.dart';

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

  group('라이트 스킴 — Figma 라이트 팔레트', () {
    test('primary는 메인컬러 원본', () {
      expect(AppTheme.light.colorScheme.primary, AppTheme.brandNavy);
      expect(AppTheme.light.brightness, Brightness.light);
    });

    test('바닥은 라이트 팔레트 wallpaper와 같다', () {
      expect(
          AppTheme.light.scaffoldBackgroundColor, GlassPalette.light.wallpaper);
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

    test('disabledColor = Figma Disabled 용', () {
      expect(AppTheme.dark.disabledColor, AppTheme.neutralDisabled);
    });
  });

  group('GlassPalette 다크/라이트 2벌', () {
    /// WCAG 대비비 근사 — (L1+0.05)/(L2+0.05).
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('테마에 extension으로 들어 있다', () {
      expect(AppTheme.dark.extension<GlassPalette>(), GlassPalette.dark);
      expect(AppTheme.light.extension<GlassPalette>(), GlassPalette.light);
      expect(GlassPalette.dark.brightness, Brightness.dark);
      expect(GlassPalette.light.brightness, Brightness.light);
    });

    test('1차 텍스트 vs 바닥·표면 대비 ≥ 4.5:1 (두 모드)', () {
      for (final p in [GlassPalette.dark, GlassPalette.light]) {
        expect(contrast(p.textPrimary, p.wallpaper), greaterThanOrEqualTo(4.5),
            reason: '${p.brightness} 바닥');
        expect(contrast(p.textPrimary, p.overlay), greaterThanOrEqualTo(4.5),
            reason: '${p.brightness} 표면');
        expect(
            contrast(p.textOnActive, p.activeTile), greaterThanOrEqualTo(4.5),
            reason: '${p.brightness} 활성 타일');
      }
    });

    test('활성 타일은 바닥과 반전이다 — 다크는 밝게, 라이트는 어둡게', () {
      expect(GlassPalette.dark.activeTile.computeLuminance(),
          greaterThan(GlassPalette.dark.wallpaper.computeLuminance()));
      expect(GlassPalette.light.activeTile.computeLuminance(),
          lessThan(GlassPalette.light.wallpaper.computeLuminance()));
    });

    test('라이트 값은 다크를 그대로 베끼지 않았다', () {
      final d = GlassPalette.dark;
      final l = GlassPalette.light;
      expect(l.wallpaper, isNot(d.wallpaper));
      expect(l.overlay, isNot(d.overlay));
      expect(l.textPrimary, isNot(d.textPrimary));
      expect(l.chartGridLine, isNot(d.chartGridLine));
      expect(l.nightBand, isNot(d.nightBand));
      // 밝은 바닥 위 기기 틴트는 대비 확보를 위해 다크와 다르다.
      expect(l.heaterTint, isNot(d.heaterTint));
    });

    test('lerp 양 끝은 원본, 가운데는 중간값', () {
      final d = GlassPalette.dark;
      final l = GlassPalette.light;
      expect(d.lerp(l, 0).overlay, d.overlay);
      expect(d.lerp(l, 1).overlay, l.overlay);
      final mid = d.lerp(l, 0.5);
      expect(mid.overlay, isNot(d.overlay));
      expect(mid.overlay, isNot(l.overlay));
      expect(d.lerp(l, 0.25).brightness, Brightness.dark);
      expect(d.lerp(l, 0.75).brightness, Brightness.light);
    });

    test('badgeTone — 라이트는 파스텔 배경+원색, 다크는 투명 배경+밝힌 전경', () {
      final light = GlassPalette.light
          .badgeTone(AppTheme.subBlue, lightBg: AppTheme.subBlueBg);
      expect(light.bg, AppTheme.subBlueBg);
      expect(light.fg, AppTheme.subBlue);
      final dark = GlassPalette.dark
          .badgeTone(AppTheme.subBlue, lightBg: AppTheme.subBlueBg);
      expect(dark.bg, isNot(AppTheme.subBlueBg));
      expect(dark.fg.computeLuminance(),
          greaterThan(AppTheme.subBlue.computeLuminance()));
    });

    testWidgets('GlassCard는 라이트 테마 아래서 라이트 표면색을 칠한다', (tester) async {
      Future<Color> surfaceUnder(ThemeData theme) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Theme(
            data: theme,
            child: const Scaffold(
              body: GlassCard(child: SizedBox(width: 40, height: 40)),
            ),
          ),
        ));
        final box = tester.widget<Container>(find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(Container),
        ));
        return (box.decoration! as BoxDecoration).color!;
      }

      expect(await surfaceUnder(AppTheme.light), GlassPalette.light.overlay);
      expect(await surfaceUnder(AppTheme.dark), GlassPalette.dark.overlay);
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
