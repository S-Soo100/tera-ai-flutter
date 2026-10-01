import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/live_recording.dart';
import '../live_recording_controller.dart';
import '../webrtc_live_controller.dart';

/// 가로 전체화면 라이브의 녹화 버튼 + `● REC 0:42` 표시 + 결과 안내
/// (2026-10-01, Figma 밖 — 기획 `docs/superpowers/specs/2026-10-01-live-recording-design.md`).
///
/// 전체화면 Stack에 그대로 얹는다(오른쪽 가운데 버튼, 위 가운데 표시).
class LiveRecordControls extends ConsumerWidget {
  const LiveRecordControls({super.key, required this.cameraId});

  final String cameraId;

  static const buttonKey = Key('live_record_button');
  static const indicatorKey = Key('live_record_indicator');
  static const resultKey = Key('live_record_result');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = liveRecordingControllerProvider(cameraId);
    final rec = ref.watch(provider);
    final live = ref.watch(webrtcLiveControllerProvider(cameraId));
    final canStart = canStartLiveRecording(
      streaming: live.phase == WebRtcLivePhase.streaming,
      liveUntil: live.liveUntil,
      now: DateTime.now(),
    );
    final recording = rec.phase == LiveRecordingPhase.recording;

    final VoidCallback? onTap = switch (rec.phase) {
      LiveRecordingPhase.recording => () => ref
          .read(provider.notifier)
          .stop(LiveRecordingEnd.userStopped),
      LiveRecordingPhase.idle when canStart => () =>
          ref.read(provider.notifier).start(live),
      _ => null,
    };

    return Stack(fit: StackFit.expand, children: [
      SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _RecordButton(
              recording: recording,
              progress: recording
                  ? rec.elapsed.inMilliseconds /
                      kLiveRecordingLength.inMilliseconds
                  : 0,
              onTap: onTap,
            ),
          ),
        ),
      ),
      if (recording || rec.phase == LiveRecordingPhase.saving || rec.result != null)
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: recording
                  ? _Pill(
                      key: LiveRecordControls.indicatorKey,
                      dot: true,
                      text: 'live_record_rec'.tr(
                          namedArgs: {'left': _mmss(rec.remaining)}),
                    )
                  : rec.phase == LiveRecordingPhase.saving
                      ? _Pill(text: 'live_record_saving'.tr())
                      : _Pill(
                          key: LiveRecordControls.resultKey,
                          text: _resultText(rec.result!, rec.resultSeconds),
                          action: _isSaved(rec.result!)
                              ? 'live_record_view'.tr()
                              : null,
                          onTap: _isSaved(rec.result!)
                              ? () => context.push('/crecam/bookmarks')
                              : null,
                        ),
            ),
          ),
        ),
    ]);
  }

  static bool _isSaved(LiveRecordingResult r) =>
      r == LiveRecordingResult.saved || r == LiveRecordingResult.savedPartial;

  static String _resultText(LiveRecordingResult r, int seconds) =>
      switch (r) {
        LiveRecordingResult.saved => 'live_record_saved'.tr(),
        LiveRecordingResult.savedPartial => 'live_record_saved_partial'
            .tr(namedArgs: {'sec': '$seconds'}),
        LiveRecordingResult.tooShort => 'live_record_too_short'.tr(),
        LiveRecordingResult.failed => 'live_record_failed'.tr(),
      };

  static String _mmss(Duration d) {
    final s = (d.inMilliseconds / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// 원형 녹화 버튼 — 대기: 빨간 원 / 녹화 중: 빨간 네모 + 진행 링.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.progress,
    required this.onTap,
  });

  final bool recording;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: (recording ? 'live_record_stop' : 'live_record_start').tr(),
      child: Material(
        color: AppTheme.liveScrim,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: LiveRecordControls.buttonKey,
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(alignment: Alignment.center, children: [
              if (recording)
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CustomPaint(
                    painter: _RingPainter(progress.clamp(0.0, 1.0)),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: recording ? 20 : 28,
                height: recording ? 20 : 28,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppTheme.danger
                      : AppTheme.liveOnDark.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(recording ? 4 : 14),
                  border: recording
                      ? null
                      : Border.all(color: AppTheme.liveOnDark, width: 2),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.liveOnDarkFaint;
    canvas.drawArc(rect.deflate(1.5), 0, 6.2832, false, base);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.liveOnDark;
    canvas.drawArc(rect.deflate(1.5), -1.5708, 6.2832 * progress, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.text,
    this.dot = false,
    this.action,
    this.onTap,
  });

  final String text;
  final bool dot;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppTheme.liveOnDark,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.liveScrim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppTheme.danger, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(text, style: style)),
          if (action != null) ...[
            const SizedBox(width: 10),
            Text(action!,
                style: style.copyWith(decoration: TextDecoration.underline)),
          ],
        ]),
      ),
    );
  }
}
