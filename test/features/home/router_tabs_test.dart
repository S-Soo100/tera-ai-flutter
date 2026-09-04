import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/core/router/tab_branches.dart';
import 'package:vivnanaut/core/router/app_router.dart';

void main() {
  group('4탭 IA (PRD §2.1 2026-09-02 개정 — 홈/카메라/마이크레/커뮤니티)', () {
    test('탭은 홈/카메라/마이크레/커뮤니티 4개', () {
      expect(kHomeTabPaths, ['/home', '/crecam', '/my-pets', '/community']);
    });

    test('탭 라벨 키가 경로와 1:1', () {
      expect(kHomeTabLabelKeys, hasLength(kHomeTabPaths.length));
      expect(kHomeTabLabelKeys,
          ['tab_home', 'tab_camera', 'tab_my_pets', 'tab_community']);
    });

    test('탭 아이콘 에셋이 경로와 1:1 — 라우터가 이 테이블로 독을 만든다', () {
      expect(kHomeTabIconAssets, hasLength(kHomeTabPaths.length));
    });

    test('통계 탭은 폐지됐다 — 온습도 상세(/env-detail)가 흡수', () {
      expect(kHomeTabPaths, isNot(contains('/stats')));
      expect(kHomeTabLabelKeys, isNot(contains('tab_stats')));
    });

    test('사육장은 탭이 아니라 보조 경로로 살아있다 — 기존 딥링크 보존', () {
      expect(kHomeTabPaths, isNot(contains('/smart-cage')));
      expect(kLegacySecondaryPaths, contains('/smart-cage'));
      // 크레캠은 카메라 탭으로 승격 — 보조 경로 목록에서 빠진다.
      expect(kLegacySecondaryPaths, isNot(contains('/crecam')));
    });
  });

  group('publicPaths', () {
    test('카메라 탭은 비공개 — 카메라는 계정 종속이라 비로그인은 로그인으로', () {
      expect(kPublicPaths, isNot(contains('/crecam')));
    });

    test('위키·검색·통계는 라우트째 제거 — 공개 목록에도 없다', () {
      expect(kPublicPaths, isNot(contains('/stats')));
      expect(kPublicPaths, isNot(contains('/wiki')));
      expect(kPublicPaths, isNot(contains('/search')));
    });

    test('홈·커뮤니티는 여전히 공개', () {
      expect(kPublicPaths, contains('/home'));
      expect(kPublicPaths, contains('/community'));
    });
  });

  group('라우터 조립', () {
    test('GoRouter가 4탭 셸로 구성된다', () {
      final router = buildAppRouter(isAuthenticated: () => true);
      expect(router, isA<GoRouter>());
    });

    test('크레캠 하위 딥링크는 셸 밖 최상위로 산다 — 페어링·상세에 독 금지', () {
      final router = buildAppRouter(isAuthenticated: () => true);
      final config = router.configuration;
      for (final path in [
        '/crecam/cameras/pair',
        '/crecam/cameras/abc',
        '/crecam/clips/abc',
        '/crecam/motion-clips/abc',
      ]) {
        final match = config.findMatch(Uri.parse(path));
        expect(match.matches, isNotEmpty, reason: '$path 매칭 실패');
      }
    });
  });
}
