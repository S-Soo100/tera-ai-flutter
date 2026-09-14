import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/thumbnail_cache_repository.dart';
import 'my_cage_providers.dart';

typedef ThumbnailRequest = ({String clipId, String cameraId, String version});

final thumbnailCacheRepositoryProvider =
    FutureProvider<ThumbnailCacheRepository>((ref) async {
  final client = http.Client();
  ref.onDispose(client.close);
  final root = await getApplicationCacheDirectory();
  final box = Hive.isBoxOpen('thumbnail_cache')
      ? Hive.box<dynamic>('thumbnail_cache')
      : await Hive.openBox<dynamic>('thumbnail_cache');
  return ThumbnailCacheRepository(
      directory: Directory('${root.path}/motion_thumbnails'),
      metadata: box,
      client: client);
});

/// Keep the cache across routes, clear account data when its session changes.
final _thumbnailSessionProvider = Provider<void>((ref) {
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final cache = ref.watch(thumbnailCacheRepositoryProvider).valueOrNull;
  if (owner != null && cache != null) {
    ref.onDispose(() => unawaited(cache.clearOwner(owner)));
  }
});

final motionThumbnailFileProvider = FutureProvider.autoDispose
    .family<File?, ThumbnailRequest>((ref, request) async {
  ref.watch(_thumbnailSessionProvider);
  final owner = ref.watch(currentUserProvider.select((user) => user?.id));
  final repository = ref.watch(motionClipRepositoryProvider);
  final cacheFuture = ref.watch(thumbnailCacheRepositoryProvider.future);
  if (owner == null) return null;
  var active = true;
  ref.onDispose(() => active = false);
  final cache = await cacheFuture;
  if (!active) return null;
  return cache.getFile((
    ownerId: owner,
    cameraId: request.cameraId,
    clipId: request.clipId,
    version: request.version
  ), resolveUrl: () async {
    if (!active) return null;
    final url = await repository.getThumbnailUrl(request.clipId);
    return url == null ? null : Uri.parse(url);
  });
});
