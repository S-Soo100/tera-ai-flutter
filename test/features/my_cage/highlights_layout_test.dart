import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/highlights_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/thumbnail_cache_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/favorite_bookmark_badge.dart';

import 'highlight_fixtures.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String p, Locale l) async =>
      jsonDecode(File('assets/l10n/ko.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// P12 Figma 1081:5235 실측 — 배너 369×263.3 @y118(안쪽 20, 제목 18/700,
/// 날짜 14/500, 썸네일 329×172.3 스택), 섹션 헤더 16/600 @y405.3, 3열 그리드
/// 셀 121.67×113 갭 2 @y432.3, 북마크 32 좌하단, 묶음 간격 20.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });

  Future<void> pump(WidgetTester tester, {String? dismissed}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          highlightGroupsProvider
              .overrideWith((ref) async => figmaHighlightGroups()),
          highlightBannerStoreProvider
              .overrideWith((ref) => FakeHighlightBannerStore(dismissed)),
          motionThumbnailFileProvider.overrideWith((ref, clipId) async => null),
          isFavoriteProvider
              .overrideWith((ref, id) => id == 'g0c1' || id == 'g0c5'),
          currentUserProvider.overrideWith((ref) => null),
        ],
        child: EasyLocalization(
            supportedLocales: const [Locale('ko')],
            startLocale: const Locale('ko'),
            path: 'assets/l10n',
            assetLoader: const _Strings(),
            child: Builder(
                builder: (c) => MaterialApp(
                    theme: AppTheme.light,
                    locale: c.locale,
                    supportedLocales: c.supportedLocales,
                    localizationsDelegates: c.localizationDelegates,
                    builder: (c, child) => MediaQuery(
                        data: MediaQuery.of(c).copyWith(
                            padding:
                                const EdgeInsets.only(top: 62, bottom: 34)),
                        child: child!),
                    home: const HighlightsScreen())))));
    await tester.pumpAndSettle();
  }

  testWidgets('배너 — 369×263.3 @118, 제목 32/138, 날짜 163, 썸네일 스택, 닫기 337/118',
      (tester) async {
    await pump(tester);
    final banner = tester.getRect(find.byKey(HighlightsScreen.bannerKey));
    expect(banner.left, 12);
    expect(banner.top, 118);
    expect(banner.width, 369);
    expect(banner.height, closeTo(263.3, 0.5));
    expect(tester.getRect(find.text('하이라이트가 도착했어요')).topLeft,
        const Offset(32, 138));
    final date = tester.getRect(find.text('2026. 8. 28 - 8. 31').first);
    expect(date.topLeft, const Offset(32, 163));
    expect(tester.getRect(find.byKey(HighlightsScreen.bannerCloseKey)),
        const Rect.fromLTWH(337, 118, 44, 44));
    expect(find.text('하이라이트'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('묶음 — 헤더 405.3, 그리드 432.3 셀 121.67×113 갭 2, 북마크 32, 다음 묶음 680.3',
      (tester) async {
    await pump(tester);
    final headers = find.text('2026. 8. 28 - 8. 31');
    // 배너 날짜 + 묶음 헤더 2.
    expect(headers, findsNWidgets(3));
    expect(tester.getRect(headers.at(1)).topLeft.dx, 12);
    expect(tester.getRect(headers.at(1)).top, closeTo(405.3, 0.5));
    final c1 =
        tester.getRect(find.byKey(const ValueKey('highlight_featured_g0c1')));
    expect(c1.left, 12);
    expect(c1.top, closeTo(432.3, 0.5));
    expect(c1.width, closeTo(121.67, 0.1));
    expect(c1.height, closeTo(113, 0.2));
    final c2 =
        tester.getRect(find.byKey(const ValueKey('highlight_featured_g0c2')));
    expect(c2.left, closeTo(135.67, 0.1));
    final c4 =
        tester.getRect(find.byKey(const ValueKey('highlight_featured_g0c4')));
    expect(c4.top, closeTo(547.3, 0.5));
    // 즐겨찾기한 셀 좌하단 북마크 32.
    final badge = find.descendant(
        of: find.byKey(const ValueKey('highlight_featured_g0c1')),
        matching: find.byType(FavoriteBookmarkBadge));
    final badgeRect = tester.getRect(badge);
    expect(badgeRect.size, const Size(32, 32));
    expect(badgeRect.left, 12);
    expect(badgeRect.bottom, closeTo(c1.bottom, 0.5));
    // 전폭 대표 카드·시각 라벨은 없다.
    expect(find.textContaining(':'), findsNothing);
    expect(tester.getRect(headers.at(2)).top, closeTo(680.3, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('배너 닫힘 — 첫 묶음 헤더가 y130(상단바 106 + 24)', (tester) async {
    await pump(tester, dismissed: 'cam/2026-08-31');
    expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
    expect(tester.getRect(find.text('2026. 8. 28 - 8. 31').first).top, 130);
  });
}
