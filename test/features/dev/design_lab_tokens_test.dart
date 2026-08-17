import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/dev/design_lab/lab_mode_toggle.dart';
import 'package:vivnanaut/features/dev/design_lab/tokens/variant_a_tokens.dart';
import 'package:vivnanaut/features/dev/design_lab/tokens/variant_b_tokens.dart';

/// 랩 토큰 2벌(다크/라이트)이 InheritedWidget으로 내려가고, 셸 밖에서는
/// 시스템 밝기를 따르는지.
void main() {
  Future<T> resolve<T>(
    WidgetTester tester, {
    required Brightness platform,
    Widget Function(Widget child)? wrap,
    required T Function(BuildContext) pick,
  }) async {
    late T got;
    Widget probe = Builder(builder: (context) {
      got = pick(context);
      return const SizedBox();
    });
    if (wrap != null) probe = wrap(probe);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(platformBrightness: platform),
      child: Directionality(textDirection: TextDirection.ltr, child: probe),
    ));
    return got;
  }

  group('VariantATokens', () {
    test('다크/라이트는 서로 다른 값 + 활성 타일 반전', () {
      const d = VariantATokens.dark();
      const l = VariantATokens.light();
      expect(l.wallpaperTop, isNot(d.wallpaperTop));
      expect(l.textPrimary, isNot(d.textPrimary));
      expect(l.activeTile.computeLuminance(),
          lessThan(l.wallpaperTop.computeLuminance()));
      expect(d.activeTile.computeLuminance(),
          greaterThan(d.wallpaperTop.computeLuminance()));
      expect(l.headerTitle.color, l.textPrimary);
    });

    testWidgets('셸 밖 — 시스템 밝기를 따른다', (tester) async {
      final dark = await resolve(tester,
          platform: Brightness.dark, pick: VariantATokens.of);
      expect(dark.brightness, Brightness.dark);
      final light = await resolve(tester,
          platform: Brightness.light, pick: VariantATokens.of);
      expect(light.brightness, Brightness.light);
    });

    testWidgets('ALabTheme이 있으면 시스템 밝기보다 우선', (tester) async {
      final got = await resolve(
        tester,
        platform: Brightness.dark,
        wrap: (c) => ALabTheme(tokens: const VariantATokens.light(), child: c),
        pick: VariantATokens.of,
      );
      expect(got.brightness, Brightness.light);
    });
  });

  group('VariantBTokens', () {
    test('라이트는 흰 바닥·흰 카드, 앰버/그린 시맨틱 유지', () {
      const l = VariantBTokens.light();
      const d = VariantBTokens.dark();
      expect(l.background.computeLuminance(), greaterThan(0.85));
      expect(l.card, Colors.white);
      expect(l.textPrimary, isNot(d.textPrimary));
      expect(l.tabActive, l.amber);
    });

    testWidgets('BLabTheme 우선, 없으면 시스템 밝기', (tester) async {
      final fromScope = await resolve(
        tester,
        platform: Brightness.light,
        wrap: (c) => BLabTheme(tokens: const VariantBTokens.dark(), child: c),
        pick: VariantBTokens.of,
      );
      expect(fromScope.brightness, Brightness.dark);
      final fallback = await resolve(tester,
          platform: Brightness.light, pick: VariantBTokens.of);
      expect(fallback.brightness, Brightness.light);
    });
  });

  testWidgets('LabModeToggle — 지금 모드 아이콘, 탭하면 onToggle', (tester) async {
    var taps = 0;
    IconData? shown;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: LabModeToggle(
        brightness: Brightness.dark,
        onToggle: () => taps++,
        builder: (context, icon) {
          shown = icon;
          return const SizedBox(width: 40, height: 40);
        },
      ),
    ));
    expect(shown, Icons.dark_mode_outlined);
    await tester.tap(find.byType(LabModeToggle));
    expect(taps, 1);
  });
}
