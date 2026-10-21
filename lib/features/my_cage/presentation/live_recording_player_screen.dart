import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/domain/am_pm_time.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/keep_screen_on.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/video_seek_bar.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/live_recording_repository.dart';
import '../domain/live_recording.dart';
import 'live_recording_upload_queue.dart';
import 'widgets/crecam_detail_top_bar.dart';

/// 재생 중인 직접 녹화 — 녹화 행과 준비된 컨트롤러.
typedef LiveRecordingPlayback = ({
  LiveRecording recording,
  VideoPlayerController controller,
});

/// 직접 녹화 한 건을 기기 파일로 연다. 화면을 나가면(autoDispose) 컨트롤러를
/// 놓는다. 보관함 목록(`liveRecordingsProvider`)은 업로드 상태가 바뀔 때마다
/// 다시 읽혀서 그걸 watch하면 재생이 처음으로 돌아간다 — 보관소에서 직접 찾는다.
final liveRecordingPlaybackProvider = FutureProvider.autoDispose
    .family<LiveRecordingPlayback, String>((ref, id) async {
  final uid = ref.watch(currentUserProvider.select((u) => u?.id));
  final repo = ref.watch(liveRecordingRepositoryProvider);
  if (uid == null) throw StateError('signed out');
  final rec = (await repo.list(uid)).where((r) => r.id == id).firstOrNull;
  if (rec == null) throw StateError('recording not found');
  final c = VideoPlayerController.file(File(await repo.resolve(rec.filePath)));
  var released = false;
  void release() {
    if (released) return;
    released = true;
    unawaited(c.dispose());
  }

  ref.onDispose(release);
  try {
    await c.initialize();
  } catch (_) {
    release(); // initialize 실패 시 네이티브 누수 방지
    rethrow;
  }
  await c.setLooping(true);
  await c.play();
  return (recording: rec, controller: c);
});

/// 직접 녹화 재생(기기 안 파일). 직접 녹화 전용 Figma가 없어 클립 세로
/// 플레이어(Figma 668:743 · 941:1834, `ClipPlaylistPlayerScreen`)와 같은 틀을
/// 쓴다: 공용 상단바(닫기·날짜/시각·오른쪽 휴지통) → 영상 → 시크바(조작 중에만
/// 썸) → 재생/일시정지 + 시간. 클립 전용(북마크·메모·공유·재생목록)은 없다.
class LiveRecordingPlayerScreen extends ConsumerWidget {
  const LiveRecordingPlayerScreen({super.key, required this.recordingId});

  final String recordingId;

  static const deleteButtonKey = Key('live_recording_delete');
  static const playPauseKey = Key('live_recording_play_pause');
  static const videoKey = Key('live_recording_video');

  Future<void> _delete(BuildContext context, WidgetRef ref,
      LiveRecordingPlayback playback) async {
    final ok = await showVivaModal(
      context,
      message: 'live_recording_delete_title'.tr(),
      cancelLabel: 'common_cancel'.tr(),
      confirmLabel: 'live_recording_delete_confirm'.tr(),
      confirmColor: AppTheme.danger,
    );
    if (!ok || !context.mounted) return;
    await playback.controller.pause();
    // 서버 등록분은 DELETE까지 대기열이 맡는다 — 목록에서는 바로 빠지고
    // (deleting), 실패하면 다음 기회에 다시 지운다. 기다리지 않는다.
    unawaited(ref
        .read(liveRecordingUploadQueueProvider.notifier)
        .delete(playback.recording));
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final playback = ref.watch(liveRecordingPlaybackProvider(recordingId));
    final ready = playback.valueOrNull;
    final controller = ready?.controller;
    return Scaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CrecamDetailHeaderArea(
            child: CrecamDetailTopBar(
          closeButton: true,
          // 휴지통 자리는 클립 플레이어의 숨기기와 같다(44 프레임 export).
          trailing: SizedBox.square(
              dimension: 44,
              child: ready == null
                  ? null
                  : IconButton(
                      key: deleteButtonKey,
                      padding: EdgeInsets.zero,
                      tooltip: 'live_recording_delete_confirm'.tr(),
                      onPressed: () => _delete(context, ref, ready),
                      icon: FigmaIcon.tinted(FigmaIcons.trash,
                          size: 44, color: glass.textPrimary))),
          titleWidget: ready == null
              ? null
              : _DateTitle(startedAt: ready.recording.startedAt),
        )),
        Expanded(
            child: SafeArea(
                top: false,
                child: LayoutBuilder(
                    builder: (context, outer) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 클립 플레이어와 같은 위 여백(본문 712 기준 84).
                              SizedBox(
                                  height: math.min(84, outer.maxHeight * 0.13)),
                              _VideoArea(playback: playback, outer: outer),
                              SizedBox(
                                  height: 16,
                                  child: VideoSeekBar(
                                      controller: controller,
                                      onSeek: (p) async =>
                                          controller?.seekTo(p))),
                              if (controller != null)
                                _ControlRow(controller: controller),
                              const Spacer(),
                            ])))),
      ]),
    );
  }
}

/// 상단 가운데 2줄 — 날짜 16/700 · 시각 14/600 (클립 플레이어 상단바와 같은
/// 값, 44 바를 넘지 않게 글자 배율 1.2로 묶음).
class _DateTitle extends StatelessWidget {
  const _DateTitle({required this.startedAt});
  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final local = startedAt.toLocal();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(DateFormat('yyyy. MM. dd').format(local),
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.32,
                height: 19 / 16,
                color: glass.textPrimary)),
        Text(formatAmPmTime(local),
            style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.28,
                height: 17 / 14,
                color: glass.bodySecondary)),
      ]),
    );
  }
}

/// 영상 면 — 높이는 클립 플레이어와 같은 규칙(영상 비율, 아래 조작 줄 자리
/// 260을 남김). 탭 = 재생/일시정지.
class _VideoArea extends StatelessWidget {
  const _VideoArea({required this.playback, required this.outer});
  final AsyncValue<LiveRecordingPlayback> playback;
  final BoxConstraints outer;

  @override
  Widget build(BuildContext context) {
    final c = playback.valueOrNull?.controller;
    final ar = c?.value.aspectRatio ?? 16 / 9;
    final ratio = ar.isFinite && ar > 0 ? ar : 16 / 9;
    final height =
        math.min(outer.maxWidth / ratio, math.max(80.0, outer.maxHeight - 260));
    final Widget body;
    if (c != null) {
      final size = c.value.size;
      final video =
          KeepScreenOnWhilePlaying(controller: c, child: VideoPlayer(c));
      body = GestureDetector(
        key: LiveRecordingPlayerScreen.videoKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => c.value.isPlaying ? c.pause() : c.play(),
        child: size.width <= 0 || size.height <= 0
            ? video
            : FittedBox(
                fit: BoxFit.contain,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                    width: size.width, height: size.height, child: video)),
      );
    } else if (playback.hasError) {
      body = Center(
          child: Text('live_recording_load_failed'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: context.glass.textSecondary)));
    } else {
      body = const SkeletonLoading(
          width: double.infinity, height: double.infinity, borderRadius: 0);
    }
    return SizedBox(height: height, child: body);
  }
}

/// Figma 941:1834 Frame 144 — 높이 36, 좌우 12: 재생 36 + 8 + 시각 14/500.
/// 컨트롤러를 직접 들어 아이콘·시간만 다시 그린다.
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.controller});
  final VideoPlayerController controller;

  static String _time(Duration v) =>
      '${v.inMinutes}:${(v.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 36,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => Row(children: [
            SizedBox.square(
              key: LiveRecordingPlayerScreen.playPauseKey,
              dimension: 36,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
                child: Center(
                    child: FigmaIcon.tinted(
                        value.isPlaying ? FigmaIcons.pause : FigmaIcons.play,
                        size: 36,
                        color: glass.textPrimary)),
              ),
            ),
            const SizedBox(width: 8),
            Text('${_time(value.position)} / ${_time(value.duration)}',
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    height: 16.70703125 / 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.28,
                    color: glass.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
