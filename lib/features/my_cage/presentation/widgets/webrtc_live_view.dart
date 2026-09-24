import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/domain/time_ago.dart';
import '../my_cage_providers.dart';
import '../webrtc_live_controller.dart';

/// WebRTC 라이브 뷰.
///
/// 고객에게 내부 단계(config/offering/ICE)를 나열하지 않는다(2026-09-23 기획 §5):
/// - 연결 중·자동 복구 중: shimmer 스켈레톤 + 한 줄 문구 (CircularProgressIndicator 금지)
/// - streaming/stalled: RTCVideoView (+ 정지·관측 불가 알약)
/// - failed: 사유 + "다시 연결" — 집중 복구 예산이 끝났거나 카메라/망/인증 문제일 때만
class WebRtcLiveView extends ConsumerStatefulWidget {
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

  /// 실패 사유별 "유저가 할 일" 문구 키(2026-09-25) — 전엔 원인이 달라도
  /// "라이브에 연결하지 못했어요"만 반복돼 무엇을 해야 할지 몰랐다.
  static String? hintKeyFor(String errorKey) => switch (errorKey) {
        'crecam_live_error_no_video' ||
        'crecam_live_error_unresponsive' =>
          'crecam_live_hint_power_cycle',
        'crecam_live_error_stalled' => 'crecam_live_hint_stalled',
        'crecam_live_error_ice' => 'crecam_live_hint_network',
        'crecam_live_error_camera_offline' => 'crecam_live_hint_offline',
        'crecam_live_error_failed' => 'crecam_live_hint_generic',
        _ => null,
      };

  @override
  ConsumerState<WebRtcLiveView> createState() => _WebRtcLiveViewState();
}

class _WebRtcLiveViewState extends ConsumerState<WebRtcLiveView> {
  WebRtcLiveController? _controller;
  bool? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _report();
  }

  @override
  void didUpdateWidget(WebRtcLiveView old) {
    super.didUpdateWidget(old);
    if (old.cameraUuid != widget.cameraUuid) _report();
  }

  /// 이 뷰가 화면에 보이는지 컨트롤러에 알린다. 다른 탭(indexedStack)이거나
  /// 불투명한 화면이 위를 덮으면 TickerMode가 꺼진다(2026-09-25).
  void _report() {
    final visible = TickerMode.of(context);
    final controller =
        ref.read(webrtcLiveControllerProvider(widget.cameraUuid).notifier);
    if (identical(controller, _controller) && visible == _visible) return;
    if (!identical(controller, _controller)) _detach();
    _controller = controller;
    _visible = visible;
    // 빌드 중에 컨트롤러 상태를 건드리지 않도록 프레임 뒤에 알린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_controller, controller) && controller.mounted) {
        controller.setViewerVisible(this, visible);
      }
    });
  }

  void _detach() {
    final c = _controller;
    _controller = null;
    _visible = null;
    if (c != null && c.mounted) c.removeViewer(this);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraUuid = widget.cameraUuid;
    final state = ref.watch(webrtcLiveControllerProvider(cameraUuid));
    void retry() =>
        ref.read(webrtcLiveControllerProvider(cameraUuid).notifier).retry();

    // 실패 화면의 저빈도 재시도 중엔 실패 화면을 유지한다(2026-09-25).
    if (state.quietRetry && state.phase.isConnecting) {
      return _FailedView(
          cameraUuid: cameraUuid,
          errorKey: state.errorKey ?? 'crecam_live_error_failed',
          retrying: true,
          onRetry: retry);
    }
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
          cover: widget.cover,
          pillLabelKey: WebRtcLiveView.pillKeyFor(state),
        ),
      WebRtcLivePhase.failed => _FailedView(
          cameraUuid: cameraUuid,
          errorKey: state.errorKey ?? 'crecam_live_error_failed',
          onRetry: retry,
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

class _FailedView extends ConsumerWidget {
  const _FailedView(
      {required this.cameraUuid,
      required this.errorKey,
      required this.onRetry,
      this.retrying = false});

  final String cameraUuid;
  final String errorKey;
  final VoidCallback onRetry;

  /// 뒤에서 자동으로 다시 확인하는 중.
  final bool retrying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintKey = WebRtcLiveView.hintKeyFor(errorKey);
    String? hint = hintKey?.tr();
    if (errorKey == 'crecam_live_error_camera_offline') {
      // 언제부터 꺼져 있었는지 — 방금인지 며칠째인지에 따라 할 일이 다르다.
      final seen = ref
          .watch(camerasProvider)
          .valueOrNull
          ?.where((c) => c.id == cameraUuid)
          .firstOrNull
          ?.lastSeenAt;
      if (seen != null) {
        hint = 'crecam_live_hint_offline_seen'.tr(args: [timeAgo(seen)]);
      }
    }
    final detail = [
      if (hint != null) hint,
      if (retrying) 'crecam_live_quiet_retry'.tr(),
    ].join('\n');
    // 영상 면은 실패해도 어둡다. 여기서 테마 surface를 쓰면 밝은 회색이 되어
    // 위아래 어두운 덩어리가 깨진다(실기기에서 제어 바만 검게 떠 있었다).
    return ColoredBox(
      color: AppTheme.liveSurface,
      child: LiveSurfaceNotice(
        key: WebRtcLiveView.retryButtonKey,
        title: errorKey.tr(),
        detail: detail.isEmpty ? null : detail,
        actionLabel: 'crecam_live_retry'.tr(),
        onAction: onRetry,
      ),
    );
  }
}
