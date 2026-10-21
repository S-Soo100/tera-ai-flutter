import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/player_entry.dart';
import '../../domain/recording_item.dart';
import '../live_recording_actions.dart';
import '../recording_library_providers.dart';
import 'motion_clip_thumb.dart';

/// 직접 녹화 썸네일(폰 JPEG `thumbPath`). 썸네일이 없거나 못 읽으면 [fallback].
class LiveRecordingThumb extends ConsumerWidget {
  const LiveRecordingThumb({
    super.key,
    required this.thumbPath,
    this.fallback = const ClipThumbFallback(),
  });

  final String? thumbPath;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = thumbPath;
    if (rel == null) return fallback;
    return ref.watch(liveRecordingThumbFileProvider(rel)).when(
          data: (file) => file == null
              ? fallback
              : Image.file(file,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
          loading: () => const SkeletonLoading(
              width: double.infinity, height: double.infinity, borderRadius: 0),
          error: (_, __) => fallback,
        );
  }
}

/// 직접 녹화 한 건의 썸네일 — 이 폰 녹화는 폰 JPEG, 서버에만 있는 녹화는
/// 서버 썸네일(일반 영상과 같은 디스크 캐시). 없으면 [fallback].
class RecordingItemThumb extends ConsumerWidget {
  const RecordingItemThumb({
    super.key,
    required this.item,
    this.fallback = const ClipThumbFallback(),
  });

  final RecordingItem item;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.local case final local?) {
      return LiveRecordingThumb(thumbPath: local.thumbPath, fallback: fallback);
    }
    final server = item.server!;
    if (!server.hasThumbnail) return fallback;
    return ref
        .watch(serverRecordingThumbFileProvider(
            (serverId: server.id, cameraId: server.cameraId ?? '')))
        .when(
          data: (file) => file == null
              ? fallback
              : Image.file(file,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
          loading: () => const SkeletonLoading(
              width: double.infinity, height: double.infinity, borderRadius: 0),
          error: (_, __) => fallback,
        );
  }
}

/// 재생목록 항목 썸네일 — 움직임 영상은 [MotionClipThumb] 그대로, 직접
/// 녹화(폰·서버)는 합친 녹화 목록에서 찾아 [RecordingItemThumb].
class PlayerEntryThumb extends ConsumerWidget {
  const PlayerEntryThumb(
      {super.key, required this.entryKey, this.cameraId = ''});

  final String entryKey;
  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (PlayerEntry.parse(entryKey)) {
      ClipEntry(:final clipId) =>
        MotionClipThumb(clipId: clipId, cameraId: cameraId),
      RecordingEntry() || ServerRecordingEntry() =>
        switch (ref.watch(recordingItemByKeyProvider(entryKey))) {
          final item? => RecordingItemThumb(item: item),
          null => const ClipThumbFallback(),
        },
    };
  }
}
