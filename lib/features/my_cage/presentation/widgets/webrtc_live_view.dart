import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../../../../shared/domain/time_ago.dart';
import '../../../../shared/providers/clock_providers.dart';
import '../../../../shared/widgets/viva_modal.dart';
import '../../domain/live_limit.dart';
import '../../domain/device_add_flow.dart';
import '../../domain/pair_target_kind.dart';
import '../live_limit_providers.dart';
import '../my_cage_providers.dart';
import '../webrtc_live_controller.dart';

/// WebRTC 라이브 뷰.
///
/// 고객에게 내부 단계(config/offering/ICE)를 나열하지 않는다(2026-09-23 기획 §5):
/// - 연결 중·자동 복구 중: shimmer 스켈레톤 + 한 줄 문구 (CircularProgressIndicator 금지)
/// - streaming/stalled: RTCVideoView (+ 정지·관측 불가 알약)
/// - failed: 사유 + "다시 연결" — 집중 복구 예산이 끝났거나 카메라/망/인증 문제일 때만
/// - limited: 서버 시청 제한(2026-09-30) — 다른 기기 시청 중(확인 모달 + 면
///   안내)·가져가짐·15분 뒤 쉼(카운트다운)·시도 과다. 자동 재시도 없음
class WebRtcLiveView extends ConsumerStatefulWidget {
  const WebRtcLiveView({
    super.key,
    required this.cameraUuid,
    this.cover = false,
    this.showWifiChange = true,
  });

  final String cameraUuid;

  /// true면 영상이 면을 **꽉 채운다**(가장자리 크롭 허용). 홈 풀블리드 면이
  /// 쓴다. 기본 false(contain) — 카메라 상세는 프레임 전체를 보여준다.
  final bool cover;

  /// 카메라 오프라인 안내에 [Wi-Fi 바꾸기]를 둘지 — 가로 전체화면은 끈다.
  final bool showWifiChange;

  static const retryButtonKey = Key('webrtc_live_retry');
  static const wifiButtonKey = Key('webrtc_live_wifi_change');
  static const pillKey = Key('webrtc_live_pill');
  static const limitActionKey = Key('webrtc_live_limit_action');

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

  /// 다른 기기 시청 중(409)이면 한 번 묻는다 — 보이는 뷰에서만, 제한당 한 번.
  /// 취소하면 면에 같은 안내와 [이 기기로 시청]이 남는다.
  Future<void> _maybePromptTakeover(WebRtcLiveState s) async {
    if (s.phase != WebRtcLivePhase.limited ||
        s.limit?.kind != LiveLimitKind.inUse ||
        !TickerMode.of(context)) {
      return;
    }
    final controller =
        ref.read(webrtcLiveControllerProvider(widget.cameraUuid).notifier);
    if (!controller.takeInUsePrompt()) return;
    final ok = await showVivaModal(
      context,
      message: 'crecam_live_in_use_title'.tr(),
      detail: 'crecam_live_in_use_body'.tr(),
      cancelLabel: 'common_cancel'.tr(),
      confirmLabel: 'crecam_live_in_use_confirm'.tr(),
    );
    if (ok && controller.mounted) unawaited(controller.takeover());
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
    ref.listen<WebRtcLiveState>(webrtcLiveControllerProvider(cameraUuid),
        (_, next) => unawaited(_maybePromptTakeover(next)));
    void retry() =>
        ref.read(webrtcLiveControllerProvider(cameraUuid).notifier).retry();

    // 실패 화면의 저빈도 재시도 중엔 실패 화면을 유지한다(2026-09-25).
    if (state.quietRetry && state.phase.isConnecting) {
      return _FailedView(
          cameraUuid: cameraUuid,
          errorKey: state.errorKey ?? 'crecam_live_error_failed',
          retrying: true,
          showWifiChange: widget.showWifiChange,
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
          liveUntil: state.liveUntil,
        ),
      WebRtcLivePhase.limited => _LimitedView(
          limit: state.limit ??
              const LiveLimit(LiveLimitKind.rateLimited),
          onRetry: retry,
          onTakeover: () => ref
              .read(webrtcLiveControllerProvider(cameraUuid).notifier)
              .takeover(),
        ),
      WebRtcLivePhase.failed => _FailedView(
          cameraUuid: cameraUuid,
          errorKey: state.errorKey ?? 'crecam_live_error_failed',
          showWifiChange: widget.showWifiChange,
          onRetry: retry,
        ),
    };
  }
}

// ── 알약 (연결 중 문구·영상 위 안내 공용) ──────────────────────────────────────

class _LivePill extends StatelessWidget {
  const _LivePill({required this.labelKey, this.args});

  final String labelKey;
  final List<String>? args;

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
        labelKey.tr(args: args),
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
    this.liveUntil,
  });

  final RTCVideoRenderer renderer;
  final bool cover;
  final String? pillLabelKey;

  /// 서버가 라이브를 끝낼 시각 — 마지막 [kLiveEndingSoon]만 알약으로 알린다.
  final DateTime? liveUntil;

  @override
  Widget build(BuildContext context) {
    final video = RTCVideoView(
      renderer,
      objectFit: cover
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
    final key = pillLabelKey;
    final until = liveUntil;
    if (key == null && until == null) return video;
    // 영상은 가리지 않는다 — 마지막 장면이 남아 있는 편이 멈춤을 이해하기 쉽다.
    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        if (key != null)
          Center(child: _LivePill(labelKey: key))
        else
          Consumer(builder: (context, ref, _) {
            final left = ref.watch(liveEndingSoonProvider(until!)).valueOrNull;
            if (left == null) return const SizedBox.shrink();
            // 0이 돼도 서버 스윕(15초 주기)까지 영상이 조금 더 나온다 — 알약을
            // 거두지 않고 "곧"으로 둔다.
            return Center(
                child: left > Duration.zero
                    ? _LivePill(
                        labelKey: 'crecam_live_ending_soon',
                        args: [formatCountdown(left)])
                    : const _LivePill(labelKey: 'crecam_live_ending_now'));
          }),
      ],
    );
  }
}

/// `1:05`·`0:09` — 올림(남은 0.3초도 1초로 보인다, 0이 되는 순간 버튼이 열린다).
@visibleForTesting
String formatCountdown(Duration d) {
  final secs = (d.inMilliseconds / 1000).ceil().clamp(0, 99 * 60);
  return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
}

// ── 시청 제한 (2026-09-30) ────────────────────────────────────────────────────

class _LimitedView extends ConsumerWidget {
  const _LimitedView({
    required this.limit,
    required this.onRetry,
    required this.onTakeover,
  });

  final LiveLimit limit;
  final VoidCallback onRetry;
  final VoidCallback onTakeover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body = switch (limit.kind) {
      LiveLimitKind.inUse => LiveSurfaceNotice(
          title: 'crecam_live_in_use_surface'.tr(),
          detail: 'crecam_live_in_use_surface_detail'.tr(),
          actionLabel: 'crecam_live_in_use_confirm'.tr(),
          onAction: onTakeover,
        ),
      LiveLimitKind.takenOver => LiveSurfaceNotice(
          title: 'crecam_live_taken_over'.tr(),
          actionLabel: 'crecam_live_watch_again'.tr(),
          onAction: onRetry,
        ),
      LiveLimitKind.cooldown || LiveLimitKind.rateLimited => Builder(
          builder: (context) {
            // 기다리는 동안만 1초씩 다시 그린다.
            final now =
                ref.watch(secondTickProvider).valueOrNull ?? DateTime.now();
            final cooldown = limit.kind == LiveLimitKind.cooldown;
            final left = limit.remaining(now);
            final waiting = left > Duration.zero;
            return LiveSurfaceNotice(
              title: (cooldown
                      ? 'crecam_live_cooldown_title'
                      : 'crecam_live_rate_limited_title')
                  .tr(),
              detail: waiting
                  ? (cooldown
                          ? 'crecam_live_cooldown_wait'
                          : 'crecam_live_rate_limited_wait')
                      .tr(args: [formatCountdown(left)])
                  : null,
              // 기다리는 동안은 버튼이 없다 — 눌러도 서버가 같은 이유로 거절한다.
              actionLabel: waiting
                  ? null
                  : (cooldown ? 'crecam_live_watch_again' : 'crecam_live_retry')
                      .tr(),
              onAction: waiting ? null : onRetry,
            );
          },
        ),
    };
    return ColoredBox(
      color: AppTheme.liveSurface,
      child: KeyedSubtree(key: WebRtcLiveView.limitActionKey, child: body),
    );
  }
}

// ── 실패 ─────────────────────────────────────────────────────────────────────

class _FailedView extends ConsumerWidget {
  const _FailedView(
      {required this.cameraUuid,
      required this.errorKey,
      required this.onRetry,
      this.retrying = false,
      this.showWifiChange = true});
  final bool showWifiChange;

  final String cameraUuid;
  final String errorKey;
  final VoidCallback onRetry;

  /// 뒤에서 자동으로 다시 확인하는 중.
  final bool retrying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintKey = WebRtcLiveView.hintKeyFor(errorKey);
    String? hint = hintKey?.tr();
    final offline = errorKey == 'crecam_live_error_camera_offline';
    final camera = offline
        ? ref
            .watch(camerasProvider)
            .valueOrNull
            ?.where((c) => c.id == cameraUuid)
            .firstOrNull
        : null;
    if (offline) {
      // 언제부터 꺼져 있었는지 — 방금인지 며칠째인지에 따라 할 일이 다르다.
      final seen = camera?.lastSeenAt;
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
        // 공유기를 바꿨다면 지우지 말고 Wi-Fi만 바꾼다(2026-09-28, 흐름 점검 A1).
        secondaryLabel: camera == null || !showWifiChange
            ? null
            : 'device_wifi_action'.tr(),
        secondaryKey: WebRtcLiveView.wifiButtonKey,
        onSecondary: camera == null || !showWifiChange
            ? null
            : () => context.push('/devices/wifi',
                extra: WifiChangeTarget(
                    kind: PairTargetKind.camera,
                    id: camera.id,
                    name: camera.name)),
      ),
    );
  }
}
