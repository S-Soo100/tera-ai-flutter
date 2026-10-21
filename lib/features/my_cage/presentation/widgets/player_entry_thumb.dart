import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/player_entry.dart';
import '../live_recording_actions.dart';
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

/// 재생목록 항목 썸네일 — 움직임 영상은 [MotionClipThumb] 그대로, 직접
/// 녹화는 보관함의 녹화 행에서 썸네일을 찾는다.
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
      RecordingEntry(:final recordingId) => LiveRecordingThumb(
          thumbPath:
              ref.watch(liveRecordingByIdProvider(recordingId))?.thumbPath),
    };
  }
}
