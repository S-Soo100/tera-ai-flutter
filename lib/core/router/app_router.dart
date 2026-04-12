import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/wiki/presentation/wiki_screen.dart';
import '../../features/wiki/presentation/wiki_detail_screen.dart';
import '../../features/wiki/presentation/species_compare_screen.dart';
import '../../features/wiki/presentation/morph_calc_screen.dart';
import '../../features/wiki/presentation/graph_detail_screen.dart';
import '../../features/my_pets/presentation/my_pets_screen.dart';
import '../../features/my_pets/presentation/pet_add_screen.dart';
import '../../features/my_pets/presentation/pet_detail_screen.dart';
import '../../features/my_pets/presentation/pet_edit_screen.dart';
import '../../features/guide/presentation/guide_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/error/presentation/error_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
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
          // Tab 4: Guide
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/guide',
                builder: (context, state) => const GuideScreen(),
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
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '사육 위키',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: '내 개체',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel),
            label: '자진신고',
          ),
        ],
      ),
    );
  }
}
