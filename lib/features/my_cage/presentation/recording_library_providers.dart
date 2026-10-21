import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/live_recording_server_repository.dart';
import '../domain/live_recording.dart';
import '../domain/player_entry.dart';
import '../domain/recording_item.dart';
import 'live_recording_controller.dart';
import 'live_recording_upload_queue.dart';
import 'thumbnail_cache_providers.dart';

/// 서버에 올라간(`ready`) 이 계정의 녹화 — 다른 폰·재설치 후에도 보이게.
/// 계정 id만 감시하고, 업로드 완료·서버 삭제 뒤([LiveRecordingUploadQueueState.serverRevision])
/// 다시 읽는다. 결과에 계정을 붙여 계정 전환 중 이전 계정 목록을 쓰지 않게 한다.
final serverLiveRecordingsProvider =
    FutureProvider.autoDispose<ServerRecordingList?>((ref) async {
  final uid = ref.watch(currentUserProvider.select((u) => u?.id));
  if (uid == null || !kLiveRecordingEnabled) return null;
  ref.watch(liveRecordingUploadQueueProvider.select((s) => s.serverRevision));
  final items =
      await ref.watch(liveRecordingServerRepositoryProvider).listReady();
  return (ownerId: uid, items: items);
});

/// 이 폰 녹화 + 서버 녹화(중복은 로컬 우선) — 보관함·카메라 탭 공용.
///
/// 이 폰 목록이 오면 바로 그린다. 서버 목록은 오는 대로 합치고, 실패하면
/// 이 폰 것만(로그) — 서버 장애로 폰에 있는 녹화까지 숨기지 않는다.
/// 계정이 바뀌면 이전 계정의 서버 목록은 쓰지 않는다(빈 목록).
final recordingLibraryProvider =
    Provider.autoDispose<AsyncValue<List<RecordingItem>>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u?.id));
  final local = ref.watch(liveRecordingsProvider);
  final server = ref.watch(serverLiveRecordingsProvider);
  // 지웠는데 서버 목록에 아직 남은 녹화(이 폰 `deleting` 행·서버 전용 삭제) —
  // 대기열이 모은다. 서버 목록에서 되살아나지 않게 뺀다.
  final removed = ref.watch(
      liveRecordingUploadQueueProvider.select((s) => s.removedServerIds));
  if (!local.hasValue) {
    if (local.hasError) {
      return AsyncError(local.error!, local.stackTrace ?? StackTrace.empty);
    }
    return const AsyncLoading();
  }
  if (server.hasError && !server.isLoading) {
    debugPrint('[rec-feed] server list failed: ${server.error.runtimeType}');
  }
  final srv = server.valueOrNull;
  final items = srv != null && srv.ownerId == uid
      ? srv.items
      : const <ServerLiveRecording>[];
  return AsyncData(mergeRecordings(
    local: local.requireValue,
    server: items,
    deletingServerIds: removed,
  ));
});

/// 키(`rec:<id>`·`rec:srv:<id>`)로 녹화 한 건. 없으면(삭제·다른 계정) null.
final recordingItemByKeyProvider = Provider.autoDispose
    .family<RecordingItem?, String>((ref, key) => ref
        .watch(recordingLibraryProvider)
        .valueOrNull
        ?.where((r) => r.key == key)
        .firstOrNull);

/// 서버 녹화 재생 URL(TTL 1시간 — 호출부가 50분 넘으면 버린다).
final serverRecordingUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, serverId) =>
        ref.watch(liveRecordingServerRepositoryProvider).playbackUrl(serverId));

/// 서버 녹화 썸네일 파일 — 일반 영상 썸네일 디스크 캐시(계정별, 로그아웃 시
/// 정리)를 그대로 쓴다. 캐시 키의 clipId 자리는 `rec:srv:<id>`라 영상과 겹치지 않는다.
final serverRecordingThumbFileProvider = FutureProvider.autoDispose
    .family<File?, ({String serverId, String cameraId})>((ref, req) async {
  final owner = ref.watch(currentUserProvider.select((u) => u?.id));
  if (owner == null) return null;
  final repository = ref.watch(liveRecordingServerRepositoryProvider);
  final cacheFuture = ref.watch(thumbnailCacheRepositoryProvider.future);
  var active = true;
  ref.onDispose(() => active = false);
  final cache = await cacheFuture;
  if (!active) return null;
  return cache.getFile((
    ownerId: owner,
    cameraId: req.cameraId,
    clipId: ServerRecordingEntry(req.serverId).key,
    version: 'recording',
  ), resolveUrl: () async {
    if (!active) return null;
    final url = await repository.thumbnailUrl(req.serverId);
    return url == null ? null : Uri.parse(url);
  });
});
