import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/my_pets/presentation/my_pets_screen.dart';
import '../../features/my_cage/presentation/nightly_report_view.dart';
import '../../features/my_pets/presentation/pet_form_route.dart';
import '../../features/my_pets/presentation/pet_detail_screen.dart';
import '../../features/my_cage/presentation/device_management_screen.dart';
import '../../features/my_cage/presentation/device_add_flow_route.dart';
import '../../features/my_cage/presentation/device_detail_screen.dart';
import '../../features/my_cage/presentation/group_editor_screen.dart';
import '../../features/my_cage/presentation/pairing_pet_selection_screen.dart';
import '../../features/my_cage/domain/redesign_management.dart';
import '../../features/my_cage/presentation/crecam_screen.dart';
import '../../features/my_cage/presentation/smart_cage_screen.dart';
import '../../features/my_cage/presentation/camera_detail_screen.dart';
import '../../features/my_cage/presentation/camera_live_fullscreen_screen.dart';
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
import '../../features/profile/presentation/account_screen.dart';
import '../../features/profile/presentation/community_profile_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/password_change_screen.dart';
import '../../features/profile/presentation/withdraw_screen.dart';
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
import '../../features/my_cage/presentation/env_settings_screen.dart';
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
          (path == '/login' || path == '/signup' || path == '/verify-email')) {
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
                    path: 'manage',
                    builder: (context, state) => const PetManagementRoute(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => Scaffold(
                        appBar: AppBar(title: Text('my_pets_tab_report'.tr())),
                        body: const NightlyReportView()),
                  ),
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const PetFormRoute(),
                  ),
                  // 리포트 카드 → 클립 재생은 셸 밖 `/crecam/motion-clips/:clipId`를
                  // 쓴다 — 셸 안에 두면 가로 전체화면 위에 탭바가 옆으로 그려져
                  // 영상을 잠식한다(2026-09-08 시뮬 실측, 구 'clips/:clipId' 삭제).
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
                          return PetFormRoute(petId: petId);
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
      // 라이브 전체화면(가로, 영상만) — 홈·카메라 탭 확대 버튼의 목적지.
      GoRoute(
        path: '/crecam/cameras/:cameraId/live',
        builder: (context, state) {
          final id = state.pathParameters['cameraId']!;
          return CameraLiveFullscreenScreen(cameraId: id);
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
          // extra = 재생 시작점(초, 하이라이트 play_from_sec). 없으면 0초부터.
          final extra = state.extra;
          return MotionClipPlayerScreen(
            clipId: id,
            playFromSec: extra is num ? extra.toDouble() : null,
          );
        },
      ),
      // 세로 재생목록 플레이어 (카메라 탭 재설계 T1) — extra = 재생목록 clip id
      // (List<String>) 또는 [ClipPlaylistArgs](재생목록 + 클립별 재생 시작점).
      // 딥링크는 extra가 없으니 단일 재생으로 열린다.
      GoRoute(
        path: '/crecam/player/:clipId',
        builder: (context, state) {
          final id = state.pathParameters['clipId']!;
          final extra = state.extra;
          if (extra is ClipPlaylistArgs) {
            return ClipPlaylistPlayerScreen(
              clipId: id,
              playlist: extra.playlist,
              playFromSec: extra.playFromSec,
              source: extra.source,
              cameraId: extra.cameraId,
              rangeStart: extra.rangeStart,
              rangeEndExclusive: extra.rangeEndExclusive,
              nextCursor: extra.nextCursor,
              hasMore: extra.hasMore,
              highlightBatchId: extra.highlightBatchId,
            );
          }
          // 호출부가 List<String>을 넘기지만 dynamic 리스트로 와도 안전하게 거른다.
          final playlist =
              extra is List ? extra.whereType<String>().toList() : null;
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
      // lib/features/wiki/는 화면·출처 인프라를 지우고(2026-09-07 A6) 개체
      // 등록이 쓰는 데이터 계층(care_info·morph_genetics)만 남았다.
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
          path: '/devices/add',
          builder: (context, state) => const DeviceAddFlowRoute()),
      GoRoute(
          path: '/devices/manage',
          builder: (context, state) => const DeviceManagementScreen()),
      GoRoute(
          path: '/devices/:kind/:id',
          builder: (context, state) {
            final kind = ManagementKind.values
                .where((k) =>
                    k.name == state.pathParameters['kind'] &&
                    k != ManagementKind.pet)
                .firstOrNull;
            if (kind == null) return const ErrorScreen();
            return DeviceDetailScreen(
                kind: kind, itemId: state.pathParameters['id']!);
          }),
      GoRoute(
          path: '/device-groups/connect-camera',
          builder: (context, state) {
            final target = state.extra;
            return GroupEditorScreen(
                selectMembers: true,
                groupId: target is ({String? groupId, ManagementKey member})
                    ? target.groupId
                    : null,
                initialMember:
                    target is ({String? groupId, ManagementKey member})
                        ? target.member
                        : null);
          }),
      GoRoute(
          path: '/groups/new',
          builder: (context, state) => GroupEditorScreen(
              initialMember: state.extra is ManagementKey
                  ? state.extra as ManagementKey
                  : null)),
      GoRoute(
          path: '/groups/:id',
          builder: (context, state) =>
              GroupEditorScreen(groupId: state.pathParameters['id'])),
      GoRoute(
          path: '/groups/:groupId/choose-pet',
          builder: (context, state) => PairingPetSelectionScreen(
              groupId: state.pathParameters['groupId']!)),
      GoRoute(
        path: '/pet-add',
        builder: (context, state) => PetFormRoute(
            initialGroupId:
                state.extra is String ? state.extra as String : null),
      ),
      // 셸 밖 개체 상세·수정. 루트 화면(기기 관리·그룹 편집기)에서 셸 안
      // `/my-pets/:id`를 push하면 go_router가 셸 페이지를 한 번 더 만들어
      // `!keyReservation.contains(key)` 단언이 터지고, 그 예외가 내비게이터를
      // 잠가(`_debugLocked`) 이후 모든 뒤로가기가 죽는다(2026-09-16 시뮬 실측).
      // 탭 안에서는 계속 `/my-pets/...`, 루트에서는 이 경로를 쓴다.
      GoRoute(
        path: '/pets/:petId',
        builder: (context, state) =>
            PetDetailScreen(petId: state.pathParameters['petId'] ?? ''),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                PetFormRoute(petId: state.pathParameters['petId'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          // 마이 페이지 하위(Figma 1142:8859, 2026-09-16).
          GoRoute(
            path: 'community',
            builder: (context, state) => const CommunityProfileScreen(),
          ),
          // 커뮤니티 차단 관리 (Task 12)
          GoRoute(
            path: 'blocked',
            builder: (context, state) => const BlockedUsersScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountScreen(),
            routes: [
              GoRoute(
                path: 'password',
                builder: (context, state) => const PasswordChangeScreen(),
              ),
              GoRoute(
                path: 'withdraw',
                builder: (context, state) => const WithdrawScreen(),
              ),
            ],
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
      // 환경설정(기기·카메라 설정) — 사육장 연동에서 분리(2026-09-08).
      GoRoute(
        path: '/env-settings',
        builder: (context, state) => const EnvSettingsScreen(),
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
