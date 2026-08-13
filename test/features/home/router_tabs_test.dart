import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/core/router/tab_branches.dart';
import 'package:vivnanaut/core/router/app_router.dart';

void main() {
  group('4탭 IA (PRD 목업 바텀 네비)', () {
    test('탭은 홈/통계/마이크레/커뮤니티 4개', () {
      expect(kHomeTabPaths, ['/home', '/stats', '/my-pets', '/community']);
    });

    test('탭 라벨 키가 경로와 1:1', () {
      expect(kHomeTabLabelKeys, hasLength(kHomeTabPaths.length));
      expect(kHomeTabLabelKeys,
          ['tab_home', 'tab_stats', 'tab_my_pets', 'tab_community']);
    });

    test('탭 아이콘 쌍이 경로와 1:1 — 라우터가 이 테이블로 독을 만든다', () {
      expect(kHomeTabIcons, hasLength(kHomeTabPaths.length));
    });

    test('크레캠·사육장은 더 이상 탭이 아니다', () {
      expect(kHomeTabPaths, isNot(contains('/crecam')));
      expect(kHomeTabPaths, isNot(contains('/smart-cage')));
    });

    test('보조 경로로는 살아있다 — 기존 딥링크 보존', () {
      expect(kLegacySecondaryPaths, contains('/crecam'));
      expect(kLegacySecondaryPaths, contains('/smart-cage'));
    });
  });

  group('publicPaths', () {
    test('통계 탭은 공개 경로 — 비로그인이 탭 눌러도 튕기지 않는다', () {
      expect(kPublicPaths, contains('/stats'));
    });
  });

  group('라우터 조립', () {
    test('GoRouter가 4탭 셸로 구성된다', () {
      final router = buildAppRouter(isAuthenticated: () => true);
      expect(router, isA<GoRouter>());
    });
  });
}
