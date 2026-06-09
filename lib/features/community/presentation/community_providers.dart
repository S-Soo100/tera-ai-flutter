import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_repository.dart';
import '../domain/community_post.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(),
);

final selectedCommunityCategoryProvider =
    StateProvider<CommunityCategory>((ref) => CommunityCategory.all);

final communityPostsProvider = Provider<List<CommunityPost>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  final category = ref.watch(selectedCommunityCategoryProvider);
  return repo.getPosts(category: category);
});
