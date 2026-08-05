import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/wiki/presentation/wiki_screen.dart';
import '../../features/wiki/presentation/wiki_detail_screen.dart';
import '../../features/wiki/presentation/species_compare_screen.dart';
import '../../features/wiki/presentation/morph_calc_screen.dart';
import '../../features/wiki/presentation/morph_guide_screen.dart';
import '../../features/wiki/presentation/graph_detail_screen.dart';
import '../../features/my_pets/presentation/my_pets_screen.dart';
import '../../features/my_pets/presentation/pet_add_screen.dart';
import '../../features/my_pets/presentation/pet_detail_screen.dart';
import '../../features/my_pets/presentation/pet_edit_screen.dart';
import '../../features/my_cage/presentation/crecam_screen.dart';
import '../../features/my_cage/presentation/smart_cage_screen.dart';
import '../../features/my_cage/presentation/camera_detail_screen.dart';
import '../../features/my_cage/presentation/clip_player_screen.dart';
import '../../features/my_cage/presentation/motion_clip_player_screen.dart';
import '../../features/my_cage/presentation/device_pairing_screen.dart';
import '../../features/my_cage/presentation/camera_pairing_screen.dart';
import '../../features/my_cage/presentation/enclosure_list_screen.dart';
import '../../features/my_cage/presentation/enclosure_detail_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/error/presentation/error_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/notification/presentation/notification_center_screen.dart';
import '../../features/my_cage/presentation/enclosure_settings_screen.dart';
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
          // Tab 2: 통계 (Stats)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
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
      // 크레캠 (탭에서 제거 — 홈 탭이 흡수. 화면·딥링크는 보존)
      GoRoute(
        path: '/crecam',
        builder: (context, state) => const CrecamScreen(),
        routes: [
          // 정적 경로 'cameras/pair'를 ':cameraId'보다 먼저 등록 —
          // 'pair'가 cameraId로 오인 매칭되는 것을 방지.
          GoRoute(
            path: 'cameras/pair',
            builder: (context, state) => const CameraPairingScreen(),
          ),
          GoRoute(
            path: 'cameras/:cameraId',
            builder: (context, state) {
              final id = state.pathParameters['cameraId']!;
              return CameraDetailScreen(cameraId: id);
            },
          ),
          GoRoute(
            path: 'clips/:clipId',
            builder: (context, state) {
              final id = state.pathParameters['clipId']!;
              return ClipPlayerScreen(clipId: id);
            },
          ),
          GoRoute(
            path: 'motion-clips/:clipId',
            builder: (context, state) {
              final id = state.pathParameters['clipId']!;
              return MotionClipPlayerScreen(clipId: id);
            },
          ),
        ],
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
      // Wiki (탭에서 제거, 커뮤니티 '사육위키' 카테고리에서 진입)
      GoRoute(
        path: '/wiki',
        builder: (context, state) => const WikiScreen(),
        routes: [
          GoRoute(
            path: 'compare',
            builder: (context, state) => const SpeciesCompareScreen(),
          ),
          GoRoute(
            path: 'graph/:kind/:entityId',
            builder: (context, state) {
              final kind = state.pathParameters['kind'] ?? '';
              final entityId = state.pathParameters['entityId'] ?? '';
              return GraphDetailScreen(
                kind: kind,
                entityId: entityId,
              );
            },
          ),
          GoRoute(
            path: ':speciesId/morph-calc',
            builder: (context, state) {
              final speciesId = state.pathParameters['speciesId'] ?? '';
              return MorphCalcScreen(speciesId: speciesId);
            },
          ),
          GoRoute(
            path: ':speciesId/morph-guide',
            builder: (context, state) {
              final speciesId = state.pathParameters['speciesId'] ?? '';
              return MorphGuideScreen(speciesId: speciesId);
            },
          ),
          GoRoute(
            path: ':speciesId/:category',
            builder: (context, state) {
              final speciesId = state.pathParameters['speciesId'] ?? '';
              final category = state.pathParameters['category'] ?? '';
              return WikiDetailScreen(
                speciesId: speciesId,
                category: category,
              );
            },
          ),
        ],
      ),
      // Search (full screen, outside tabs)
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/new',
        builder: (context, state) {
          final petId = state.uri.queryParameters['petId'];
          final speciesId = state.uri.queryParameters['speciesId'];
          return ChatScreen(petId: petId, speciesId: speciesId);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          return ChatScreen(conversationId: id);
        },
      ),
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
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
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


class _ScaffoldWithBottomNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _ScaffoldWithBottomNav({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: kHomeTabLabelKeys[0].tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: kHomeTabLabelKeys[1].tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.pets_outlined),
            selectedIcon: const Icon(Icons.pets),
            label: kHomeTabLabelKeys[2].tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: kHomeTabLabelKeys[3].tr(),
          ),
        ],
      ),
    );
  }
}
