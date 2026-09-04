import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/my_pets/presentation/my_pets_screen.dart';
import '../../features/my_pets/presentation/pet_add_screen.dart';
import '../../features/my_pets/presentation/pet_detail_screen.dart';
import '../../features/my_pets/presentation/pet_edit_screen.dart';
import '../../features/my_cage/presentation/crecam_screen.dart';
import '../../features/my_cage/presentation/smart_cage_screen.dart';
import '../../features/my_cage/presentation/camera_detail_screen.dart';
import '../../features/my_cage/presentation/clip_player_screen.dart';
import '../../features/my_cage/presentation/motion_clip_player_screen.dart';
import '../../features/my_cage/presentation/clip_playlist_player_screen.dart';
import '../../features/my_cage/presentation/bookmarks_screen.dart';
import '../../features/my_cage/presentation/highlights_screen.dart';
import '../../features/my_cage/presentation/device_pairing_screen.dart';
import '../../features/my_cage/presentation/camera_pairing_screen.dart';
import '../../features/my_cage/presentation/enclosure_list_screen.dart';
import '../../features/my_cage/presentation/enclosure_detail_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/community_player_screen.dart';
import '../../features/community/presentation/clip_select_screen.dart';
import '../../features/community/presentation/compose_screen.dart';
import '../../features/community/presentation/blocked_users_screen.dart';
import '../../features/community/presentation/user_posts_screen.dart';
import '../../features/error/presentation/error_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/dev/presentation/chart_lab_screen.dart';
import '../../features/dev/design_lab/design_lab_screen.dart';
import '../../features/dev/design_lab/variant_a_shell.dart';
import '../../features/dev/design_lab/variant_b_shell.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notification/presentation/notification_center_screen.dart';
import '../../features/my_cage/presentation/enclosure_settings_screen.dart';
import '../../features/home/presentation/routine_settings_screen.dart';
import '../../features/home/presentation/env_detail_screen.dart';
import '../../shared/widgets/glass_dock.dart';
import 'tab_branches.dart';

/// 인증 상태 변경 시 redirect만 재평가 (GoRouter 재생성 방지)
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier();
  ref.listen(isAuthenticatedProvider, (_, __) {
    authNotifier.notify();
  });

  return buildAppRouter(
    isAuthenticated: () => ref.read(isAuthenticatedProvider),
    refreshListenable: authNotifier,
  );
});

/// 라우터 조립. `isAuthenticated`를 주입받아 ProviderContainer 없이도
/// 테스트에서 구성 가능하게 한다.
GoRouter buildAppRouter({
  required bool Function() isAuthenticated,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;

      // 스플래시는 앱 시작 시에만 — redirect 간섭 없음
      if (path == '/splash') return null;

      final isPublic = kPublicPaths.any(
        (p) => path == p || path.startsWith('$p/'),
      );

      if (!isAuthenticated() && !isPublic) {
        return '/login';
      }
      if (isAuthenticated() &&
          (path == '/login' ||
              path == '/signup' ||
              path == '/verify-email')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithBottomNav(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 2: 카메라 (기존 CrecamScreen 승격 — 2026-09-02 PRD §2.1)
          // 하위 경로(cameras/clips)는 셸 밖 최상위 라우트다 — 페어링·상세에
          // 독이 뜨면 안 된다(/home/routines 선례).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/crecam',
                builder: (context, state) => const CrecamScreen(),
              ),
            ],
          ),
          // Tab 3: 마이 크레 (My Pets)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-pets',
                builder: (context, state) => const MyPetsScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const PetAddScreen(),
                  ),
                  // 정적 경로 'clips/:clipId'를 ':petId'보다 먼저 등록 —
                  // 'clips'가 petId로 오인 매칭되는 것을 방지 (리포트 카드 → 재생).
                  GoRoute(
                    path: 'clips/:clipId',
                    builder: (context, state) => MotionClipPlayerScreen(
                        clipId: state.pathParameters['clipId']!),
                  ),
                  GoRoute(
                    path: ':petId',
                    builder: (context, state) {
                      final petId = state.pathParameters['petId'] ?? '';
                      return PetDetailScreen(petId: petId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final petId = state.pathParameters['petId'] ?? '';
                          return PetEditScreen(petId: petId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: 커뮤니티 (Community)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
        ],
      ),
      // 커뮤니티 전체화면 플로우 (독 없는 최상위 — shell 탈출, /crecam 선례)
      GoRoute(
        path: '/community-share',
        builder: (context, state) => const ClipSelectScreen(),
        routes: [
          GoRoute(
            path: 'caption',
            builder: (context, state) {
              // extra 없이 진입(웹 새로고침·상태복원·향후 딥링크)하면 캡션
              // 화면이 성립하지 않는다 — 클립 선택 1단계로 되돌린다.
              final draft = state.extra;
              return draft is ComposeDraft
                  ? ComposeScreen(draft: draft)
                  : const ClipSelectScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/community-player/:postId',
        builder: (context, state) =>
            CommunityPlayerScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/community-user/:userId',
        builder: (context, state) =>
            UserPostsScreen(userId: state.pathParameters['userId']!),
      ),
      // 크레캠 하위 경로 — 루트(/crecam)는 카메라 탭 브랜치로 승격됐고,
      // 하위는 독 없는 최상위로 남긴다(딥링크 보존 + 페어링·상세 풀스크린).
      // 정적 경로 'cameras/pair'를 ':cameraId'보다 먼저 등록 —
      // 'pair'가 cameraId로 오인 매칭되는 것을 방지.
      GoRoute(
        path: '/crecam/cameras/pair',
        builder: (context, state) => const CameraPairingScreen(),
      ),
      GoRoute(
        path: '/crecam/cameras/:cameraId',
        builder: (context, state) {
          final id = state.pathParameters['cameraId']!;
          return CameraDetailScreen(cameraId: id);
        },
      ),
      GoRoute(
        path: '/crecam/clips/:clipId',
        builder: (context, state) {
          final id = state.pathParameters['clipId']!;
          return ClipPlayerScreen(clipId: id);
        },
      ),
      GoRoute(
        path: '/crecam/motion-clips/:clipId',
        builder: (context, state) {
          final id = state.pathParameters['clipId']!;
          return MotionClipPlayerScreen(clipId: id);
        },
      ),
      // 세로 재생목록 플레이어 (카메라 탭 재설계 T1) — extra = 재생목록 clip id.
      // 딥링크는 extra가 없으니 단일 재생으로 열린다.
      GoRoute(
        path: '/crecam/player/:clipId',
        builder: (context, state) {
          final id = state.pathParameters['clipId']!;
          final extra = state.extra;
          // 호출부가 List<String>을 넘기지만 dynamic 리스트로 와도 안전하게 거른다.
          final playlist = extra is List
              ? extra.whereType<String>().toList()
              : null;
          return ClipPlaylistPlayerScreen(clipId: id, playlist: playlist);
        },
      ),
      // 카메라 탭 엔트리 카드 목적지 (재설계 T3·T4).
      GoRoute(
        path: '/crecam/highlights',
        builder: (context, state) => const HighlightsScreen(),
      ),
      GoRoute(
        path: '/crecam/bookmarks',
        builder: (context, state) => const BookmarksScreen(),
      ),
      // 사육장 (탭에서 제거 — 홈 탭이 흡수. 화면·딥링크는 보존)
      GoRoute(
        path: '/smart-cage',
        builder: (context, state) => const SmartCageScreen(),
        routes: [
          GoRoute(
            path: 'devices/pair',
            builder: (context, state) => const DevicePairingScreen(),
          ),
          GoRoute(
            path: 'enclosures',
            builder: (context, state) => const EnclosureListScreen(),
            routes: [
              GoRoute(
                path: ':enclosureId',
                builder: (context, state) {
                  final id = state.pathParameters['enclosureId']!;
                  return EnclosureDetailScreen(enclosureId: id);
                },
              ),
            ],
          ),
        ],
      ),
      // 위키·검색 라우트는 2026-09-02 PRD 재설계로 제거(진입점 폐지).
      // lib/features/{wiki,search}/ 파일 삭제는 후속 정리 커밋.
      GoRoute(
        path: '/error',
        builder: (context, state) => const ErrorScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return EmailVerificationScreen(email: email);
        },
      ),
      // 홈 헤더 [+] '개체 추가' 전용 최상위 라우트 — 브랜치 하위
      // `/my-pets/add`를 홈에서 push하면 셸 인덱스가 탭3으로 점프하고
      // 뒤로가기가 홈이 아닌 마이크레로 떨어진다(리뷰 2026-09-03).
      GoRoute(
        path: '/pet-add',
        builder: (context, state) => const PetAddScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          // 커뮤니티 차단 관리 (Task 12)
          GoRoute(
            path: 'blocked',
            builder: (context, state) => const BlockedUsersScreen(),
          ),
        ],
      ),
      // 온습도 그래프 디자인 검토용. 실데이터로는 볼 수 없는 상태(마커 유무,
      // 밴드 폭, 좁은/넓은 구간)를 만들어 보는 자리다.
      GoRoute(
        path: '/dev/chart-lab',
        builder: (context, state) => const ChartLabScreen(),
      ),
      // UIUX 벤치마크 체험 랩 — 스펙: docs/design-lab-benchmark-specs.md
      // 테스트 유저 공개(비로그인, kPublicPaths): docs/design-test-rollout-plan.md
      // 구 경로 /dev/design-lab을 이 공개 경로로 교체(2026-08-14).
      GoRoute(
        path: '/design-test',
        builder: (context, state) => const DesignLabScreen(),
        routes: [
          GoRoute(
            path: 'a',
            builder: (context, state) => const VariantAShell(),
          ),
          GoRoute(
            path: 'b',
            builder: (context, state) => const VariantBShell(),
          ),
        ],
      ),
      // PRD §3.4 자동 루틴 & 타이머 설정 — 풀스크린(탭 셸 밖) 모달
      GoRoute(
        path: '/home/routines',
        builder: (context, state) => const RoutineSettingsScreen(),
      ),
      // 온습도 상세 (Figma §A.5·§A.6) — 홈 요약 카드 진입, 풀스크린 다이얼로그.
      // 비공개(kPublicPaths 미등록) — 온습도는 계정 종속 데이터다.
      GoRoute(
        path: '/env-detail',
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: EnvDetailScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/enclosure-settings',
        builder: (context, state) => const EnclosureSettingsScreen(),
      ),
    ],
  );
}


/// 4탭 셸 — B안(Flighty 전광판) 하단 고정 탭바(2026-08-14 저녁, A안 플로팅
/// 독 교체).
///
/// `extendBody: true`는 유지한다 — Scaffold가 body의 `MediaQuery.padding.bottom`
/// 에 탭바 높이(홈 인디케이터 포함)를 더해주고, 각 탭 스크롤 뷰는
/// `glassDockListPadding`으로 그 패딩을 소비해 마지막 항목이 바에 가려지지
/// 않는다(padding을 안 준 ListView는 자동, CustomScrollView는 직접). 바는
/// 불투명이라 뒤로 비치는 건 없지만, 인셋 계약을 한 곳(`GlassDock`)이 소유하게
/// 두는 편이 안전하다.
///
/// 네비게이션 로직(goBranch·initialLocation)은 NavigationBar 시절 그대로다 —
/// 표면만 [GlassDock]으로 바뀌었다.
class _ScaffoldWithBottomNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _ScaffoldWithBottomNav({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      // 바 자체가 SafeArea(bottom)를 안고 있다 — 여기서 또 감싸면 인셋이 두 번 든다.
      bottomNavigationBar: GlassDock(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        // 독 항목은 탭 테이블(tab_branches.dart)에서 파생한다 —
        // 여기 인라인으로 나열하면 경로·라벨과 3중 병렬이 된다.
        items: [
          for (var i = 0; i < kHomeTabPaths.length; i++)
            GlassDockItem(
              iconAsset: kHomeTabIconAssets[i],
              label: kHomeTabLabelKeys[i].tr(),
            ),
        ],
      ),
    );
  }
}
