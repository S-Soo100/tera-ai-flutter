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
import '../../features/my_cage/presentation/my_cage_screen.dart';
import '../../features/my_cage/presentation/camera_add_screen.dart';
import '../../features/my_cage/presentation/camera_detail_screen.dart';
import '../../features/my_cage/presentation/clip_player_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/error/presentation/error_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// 인증 상태 변경 시 redirect만 재평가 (GoRouter 재생성 방지)
class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier();
  ref.listen(isAuthenticatedProvider, (_, __) {
    authNotifier.notify();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final path = state.uri.path;

      // 스플래시는 앱 시작 시에만 — redirect 간섭 없음
      if (path == '/splash') return null;

      // 인증 필요 없는 공개 경로
      const publicPaths = [
        '/splash',
        '/home',
        '/wiki',
        '/search',
        '/login',
        '/signup',
        '/verify-email',
        '/error',
      ];
      final isPublic = publicPaths.any(
        (p) => path == p || path.startsWith('$p/'),
      );

      if (!isAuthenticated && !isPublic) {
        return '/login';
      }
      if (isAuthenticated &&
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
          // Tab 1: Home (Dashboard)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 2: Wiki
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wiki',
                builder: (context, state) => const WikiScreen(),
                routes: [
                  GoRoute(
                    path: 'compare',
                    builder: (context, state) =>
                        const SpeciesCompareScreen(),
                  ),
                  GoRoute(
                    path: 'graph/:kind/:entityId',
                    builder: (context, state) {
                      final kind = state.pathParameters['kind'] ?? '';
                      final entityId =
                          state.pathParameters['entityId'] ?? '';
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
            ],
          ),
          // Tab 3: My Pets
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
          // Tab 4: My Cage (내 사육장·장비)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-cage',
                builder: (context, state) => const MyCageScreen(),
                routes: [
                  GoRoute(
                    path: 'cameras/add',
                    builder: (context, state) {
                      final petId = state.uri.queryParameters['petId'];
                      return CameraAddScreen(prefilledPetId: petId);
                    },
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
                ],
              ),
            ],
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
    ],
  );
});

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
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '사육 위키',
          ),
          NavigationDestination(
            icon: Opacity(
              opacity: 0.7,
              child: Image.asset('assets/images/logo.png', width: 24, height: 24),
            ),
            selectedIcon: Image.asset('assets/images/logo.png', width: 24, height: 24),
            label: '내 개체',
          ),
          const NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: '내 사육장',
          ),
        ],
      ),
    );
  }
}
