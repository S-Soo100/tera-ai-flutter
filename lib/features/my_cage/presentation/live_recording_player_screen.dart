import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../data/live_recording_repository.dart';
import '../domain/live_recording.dart';
import 'live_recording_controller.dart';

/// 직접 녹화 재생(기기 안 파일). 탭 = 재생/일시정지, 우상단 = 삭제.
class LiveRecordingPlayerScreen extends ConsumerStatefulWidget {
  const LiveRecordingPlayerScreen({super.key, required this.recordingId});

  final String recordingId;

  static const deleteButtonKey = Key('live_recording_delete');

  @override
  ConsumerState<LiveRecordingPlayerScreen> createState() =>
      _LiveRecordingPlayerScreenState();
}

class _LiveRecordingPlayerScreenState
    extends ConsumerState<LiveRecordingPlayerScreen> {
  VideoPlayerController? _controller;
  LiveRecording? _recording;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(liveRecordingRepositoryProvider);
    final list = await ref.read(liveRecordingsProvider.future);
    final rec = list.where((r) => r.id == widget.recordingId).firstOrNull;
    if (rec == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(File(await repo.resolve(rec.filePath)));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() {
        _recording = rec;
        _controller = c;
      });
    } catch (_) {
      await c?.dispose(); // initialize 실패 시 네이티브 누수 방지
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final rec = _recording;
    if (rec == null) return;
    final ok = await showVivaModal(
      context,
      message: 'live_recording_delete_title'.tr(),
      cancelLabel: 'common_cancel'.tr(),
      confirmLabel: 'live_recording_delete_confirm'.tr(),
      confirmColor: AppTheme.danger,
    );
    if (!ok || !mounted) return;
    await _controller?.pause();
    await ref.read(liveRecordingRepositoryProvider).delete(rec);
    ref.invalidate(liveRecordingsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (c != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
                () => c.value.isPlaying ? c.pause() : c.play()),
            child: Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            ),
          )
        else if (_failed)
          Center(
            child: Text('live_recording_load_failed'.tr(),
                style: const TextStyle(color: AppTheme.liveOnDark)),
          )
        else
          const Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonLoading(
                  width: double.infinity, height: double.infinity),
            ),
          ),
        if (c != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: VideoProgressIndicator(c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16)),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close, color: AppTheme.liveOnDark),
              ),
              const Spacer(),
              if (_recording != null)
                IconButton(
                  key: LiveRecordingPlayerScreen.deleteButtonKey,
                  tooltip: 'live_recording_delete_confirm'.tr(),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.liveOnDark),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
