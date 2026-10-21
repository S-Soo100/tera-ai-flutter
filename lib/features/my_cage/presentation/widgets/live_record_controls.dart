import 'dart:async';

import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/viva_modal.dart';
import '../../domain/live_recording.dart';
import '../live_recording_controller.dart';
import '../webrtc_live_controller.dart';
import 'clip_toast.dart';
import 'live_control_rows.dart';
import 'management_widgets.dart';

/// 라이브 확대 화면의 실시간 녹화 조각(Figma "실시간 녹화" 1525:10834).
///
/// - 세로: 제어 목록 첫 줄 [LiveRecordRow] — 부제 "최대 2분"/"녹화 중 00:01",
///   오른쪽 112×40 알약 [녹화 시작]/[녹화 중단].
/// - 가로: 오른쪽 위 112×48 알약 [LiveRecordPill] (`landscape`).
/// - [녹화 중단]·이탈은 [stopLiveRecordingWithConfirm] 하나로 묻는다.
/// - 결과 안내는 [showLiveRecordingResult](영상 선택과 같은 토스트).
abstract final class LiveRecordControls {
  static const buttonKey = Key('live_record_button');
  static const subtitleKey = Key('live_record_subtitle');
  static const stopConfirmKey = Key('live_record_stop_confirm');
}

/// `00:01` — 올라가는 경과 시간(분:초 두 자리).
String formatLiveRecordElapsed(Duration d) {
  final s = d.inSeconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

bool _isActive(LiveRecordingPhase p) =>
    p == LiveRecordingPhase.recording || p == LiveRecordingPhase.starting;

/// 녹화 중이면 멈출지 묻고 멈춘다(2026-10-21 계획 §9).
///
/// - 3초 미만이면 확인창 없이 바로 멈춘다(어차피 저장되지 않는다 — 창의
///   "저장됩니다"와 모순).
/// - 창이 떠 있는 사이 녹화가 끝나면(2분 도달·끊김) 창은 저절로 닫힌다.
/// - [중단하기]는 멱등 — 이미 끝났으면 아무것도 안 한다.
///
/// 돌려주는 값: 이제 녹화가 돌고 있지 않으면 true(나가도 된다).
Future<bool> stopLiveRecordingWithConfirm(
    BuildContext context, WidgetRef ref, String cameraId) async {
  if (!kLiveRecordingEnabled) return true;
  final provider = liveRecordingControllerProvider(cameraId);
  final notifier = ref.read(provider.notifier);
  final phase = ref.read(provider).phase;
  if (phase == LiveRecordingPhase.starting) {
    await notifier.stop(LiveRecordingEnd.userStopped);
    return true;
  }
  if (phase != LiveRecordingPhase.recording) return true;
  if (notifier.recordedSoFar < kLiveRecordingMinLength) {
    await notifier.stop(LiveRecordingEnd.userStopped);
    return true;
  }
  final ended = Completer<void>();
  final sub = ref.listenManual<LiveRecordingPhase>(
      provider.select((s) => s.phase), (_, next) {
    if (next != LiveRecordingPhase.recording && !ended.isCompleted) {
      ended.complete();
    }
  });
  final bool ok;
  try {
    ok = await showVivaModal(context,
        message: 'live_record_stop_confirm'.tr(),
        cancelLabel: 'live_record_stop_cancel'.tr(),
        confirmLabel: 'live_record_stop_ok'.tr(),
        confirmKey: LiveRecordControls.stopConfirmKey,
        dismissOn: ended.future);
  } finally {
    sub.close();
  }
  if (ended.isCompleted) return true;
  if (!ok) return false;
  if (notifier.mounted) await notifier.stop(LiveRecordingEnd.userStopped);
  return true;
}

/// 끝난 녹화 결과 토스트 — 저장(2분·중단·시청 제한 시각)은 "녹화 영상 저장 완료",
/// 끊김은 "연결이 끊겨 N초까지 저장했어요", 3초 미만·실패는 `!` 아이콘.
/// [bottom]은 세로 화면 하단 거리, [centered]는 가로 라이브 화면의 화면 한가운데
/// (Figma 1525:11177).
void showLiveRecordingResult(
    BuildContext context, LiveRecordingResult result, int seconds,
    {double? bottom, bool centered = false}) {
  final (text, ok) = switch (result) {
    LiveRecordingResult.saved => ('live_record_saved'.tr(), true),
    LiveRecordingResult.savedPartial => (
        'live_record_saved_partial'.tr(namedArgs: {'sec': '$seconds'}),
        true
      ),
    LiveRecordingResult.tooShort => ('live_record_too_short'.tr(), false),
    LiveRecordingResult.failed => ('live_record_failed'.tr(), false),
  };
  showClipToast(context,
      text: text,
      icon: ok ? 'redesign_v2/check' : 'redesign_v2/priority_high',
      duration: Duration(seconds: ok ? 2 : 3),
      bottom: bottom,
      centered: centered);
}

/// 세로 제어 목록 첫 줄 "실시간 녹화". 경과 시간 때문에 250ms마다 다시
/// 그려지므로 화면 전체가 아니라 이 줄만 구독한다.
class LiveRecordRow extends ConsumerWidget {
  const LiveRecordRow(
      {super.key, required this.cameraId, required this.available});

  final String cameraId;

  /// 카메라 온라인 + 영상이 나오는 중.
  final bool available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(liveRecordingControllerProvider(cameraId));
    final active = _isActive(rec.phase);
    return LiveControlRow(
      dimmed: !available && !active,
      icon: (c) => LiveRasterIcon('videocam', color: c),
      title: 'live_record_title'.tr(),
      subtitleKey: LiveRecordControls.subtitleKey,
      subtitle: active
          ? 'live_record_elapsed'
              .tr(namedArgs: {'time': formatLiveRecordElapsed(rec.elapsed)})
          : 'live_record_max'.tr(),
      trailing: LiveRecordPill(cameraId: cameraId, available: available),
    );
  }
}

/// [녹화 시작]/[녹화 중단] 알약. 세로 112×40 r12, 가로 112×48 r24.
class LiveRecordPill extends ConsumerWidget {
  const LiveRecordPill({
    super.key,
    required this.cameraId,
    required this.available,
    this.landscape = false,
  });

  final String cameraId;
  final bool available;
  final bool landscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final provider = liveRecordingControllerProvider(cameraId);
    final rec = ref.watch(provider);
    final liveProvider = webrtcLiveControllerProvider(cameraId);
    final (streaming, liveUntil) = ref.watch(liveProvider
        .select((s) => (s.phase == WebRtcLivePhase.streaming, s.liveUntil)));
    final active = _isActive(rec.phase);
    final canStart = available &&
        rec.phase == LiveRecordingPhase.idle &&
        canStartLiveRecording(
            streaming: streaming, liveUntil: liveUntil, now: clock.now());
    final VoidCallback? onTap = active
        ? () => stopLiveRecordingWithConfirm(context, ref, cameraId)
        : canStart
            ? () => ref.read(provider.notifier).start(ref.read(liveProvider))
            : null;

    final height = landscape ? 48.0 : 40.0;
    final radius = landscape ? 24.0 : 12.0;
    final enabled = onTap != null;
    // 세로 비활성은 Figma 원본(#E3E3E3 면 + 가운데 #949090 글자, 아이콘 없음),
    // 가로 비활성은 흐리게(영상 위라 회색 면이 안 읽힌다).
    final portraitDisabled = !landscape && !enabled;
    final Color face = active
        ? glass.textPrimary
        : portraitDisabled
            ? glass.border
            : glass.overlay;
    final Color fg = active
        ? glass.buttonForeground
        : portraitDisabled
            ? glass.textTertiary
            : glass.textSecondary;
    final String label = active
        ? landscape
            ? formatLiveRecordElapsed(rec.elapsed)
            : 'live_record_stop'.tr()
        : 'live_record_start'.tr();
    final Widget? icon = portraitDisabled
        ? null
        : active
            ? const LiveRasterIcon('stop_circle_red')
            : LiveRasterIcon('screen_record', color: fg);

    Widget pill = Semantics(
      button: true,
      enabled: enabled,
      label: active ? 'live_record_stop'.tr() : 'live_record_start'.tr(),
      child: Material(
        color: face,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: LiveRecordControls.buttonKey,
          onTap: onTap,
          child: ConstrainedBox(
            // 글자를 키우면 옆으로 늘어난다(2026-10-01 글자 배율) — 제목 자리를
            // 남기게 200에서 멈추고 그 뒤는 말줄임.
            constraints: const BoxConstraints(minWidth: 112, maxWidth: 200),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.only(
                    left: icon == null ? 12 : 13,
                    right: icon == null ? 12 : 10),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[icon, const SizedBox(width: 4)],
                      Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: managementStyle(context, color: fg)
                                  .copyWith(fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]))),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
    if (landscape && !enabled) pill = Opacity(opacity: 0.5, child: pill);
    return pill;
  }
}
