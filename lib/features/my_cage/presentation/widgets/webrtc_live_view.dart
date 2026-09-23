import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../webrtc_live_controller.dart';

/// WebRTC 라이브 뷰.
///
/// 고객에게 내부 단계(config/offering/ICE)를 나열하지 않는다(2026-09-23 기획 §5):
/// - 연결 중·자동 복구 중: shimmer 스켈레톤 + 한 줄 문구 (CircularProgressIndicator 금지)
/// - streaming/stalled: RTCVideoView (+ 정지·관측 불가 알약)
/// - failed: 사유 + "다시 연결" — 집중 복구 예산이 끝났거나 카메라/망/인증 문제일 때만
class WebRtcLiveView extends ConsumerWidget {
  const WebRtcLiveView({
    super.key,
    required this.cameraUuid,
    this.cover = false,
  });

  final String cameraUuid;

  /// true면 영상이 면을 **꽉 채운다**(가장자리 크롭 허용). 홈 풀블리드 면이
  /// 쓴다. 기본 false(contain) — 카메라 상세는 프레임 전체를 보여준다.
  final bool cover;

  static const retryButtonKey = Key('webrtc_live_retry');
  static const pillKey = Key('webrtc_live_pill');

  /// 영상 위에 얹을 알약 문구 키. 정지가 관측 불가보다 우선한다.
  static String? pillKeyFor(WebRtcLiveState s) {
    if (s.phase == WebRtcLivePhase.stalled) return 'crecam_live_stalled';
    if (s.statsUnknown) return 'crecam_live_stats_unknown';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(webrtcLiveControllerProvider(cameraUuid));

    return switch (state.phase) {
      WebRtcLivePhase.connectingConfig ||
      WebRtcLivePhase.offering ||
      WebRtcLivePhase.connectingIce =>
        const _ConnectingView(labelKey: 'crecam_live_connecting'),
      WebRtcLivePhase.waitingVideo =>
        const _ConnectingView(labelKey: 'crecam_live_loading_video'),
      WebRtcLivePhase.recovering =>
        const _ConnectingView(labelKey: 'crecam_live_recovering'),
      WebRtcLivePhase.streaming || WebRtcLivePhase.stalled => _StreamingView(
          renderer: state.renderer!,
          cover: cover,
          pillLabelKey: pillKeyFor(state),
        ),
      WebRtcLivePhase.failed => _FailedView(
          errorKey: state.errorKey ?? 'crecam_live_error_failed',
          onRetry: () => ref
              .read(webrtcLiveControllerProvider(cameraUuid).notifier)
              .retry(),
        ),
    };
  }
}

// ── 알약 (연결 중 문구·영상 위 안내 공용) ──────────────────────────────────────

class _LivePill extends StatelessWidget {
  const _LivePill({required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: WebRtcLiveView.pillKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing12,
        vertical: AppStyles.spacing4,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppStyles.chipRadius),
      ),
      child: Text(
        labelKey.tr(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── 연결 중 (shimmer 스켈레톤 + 한 줄 문구) ───────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    // 영상 뷰포트는 테마와 무관하게 어둡다. 밝은 회색 스켈레톤을 쓰면
    // 연결 전 화면이 죽은 공백으로 보인다(AppTheme.liveSurface 주석 참조).
    const baseColor = AppTheme.liveSurface;
    final highlightColor = Colors.white.withValues(alpha: 0.06);

    return Stack(
      fit: StackFit.expand,
      children: [
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(color: baseColor),
        ),
        // 하단이 아니라 **가운데**에 둔다. 하단은 페이지 인디케이터 자리라
        // 겹친다(실기기에서 알약과 점이 포개졌다).
        Center(child: _LivePill(labelKey: labelKey)),
      ],
    );
  }
}

// ── 스트리밍 (+ 정지·관측 불가 알약) ─────────────────────────────────────────

class _StreamingView extends StatelessWidget {
  const _StreamingView({
    required this.renderer,
    required this.cover,
    this.pillLabelKey,
  });

  final RTCVideoRenderer renderer;
  final bool cover;
  final String? pillLabelKey;

  @override
  Widget build(BuildContext context) {
    final video = RTCVideoView(
      renderer,
      objectFit: cover
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
    final key = pillLabelKey;
    if (key == null) return video;
    // 영상은 가리지 않는다 — 마지막 장면이 남아 있는 편이 멈춤을 이해하기 쉽다.
    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        Center(child: _LivePill(labelKey: key)),
      ],
    );
  }
}

// ── 실패 ─────────────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  const _FailedView({required this.errorKey, required this.onRetry});

  final String errorKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 영상 면은 실패해도 어둡다. 여기서 테마 surface를 쓰면 밝은 회색이 되어
    // 위아래 어두운 덩어리가 깨진다(실기기에서 제어 바만 검게 떠 있었다).
    return ColoredBox(
      color: AppTheme.liveSurface,
      child: LiveSurfaceNotice(
        key: WebRtcLiveView.retryButtonKey,
        title: errorKey.tr(),
        actionLabel: 'crecam_live_retry'.tr(),
        onAction: onRetry,
      ),
    );
  }
}
