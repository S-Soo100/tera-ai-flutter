import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_styles.dart';
import '../webrtc_live_controller.dart';

/// WebRTC 라이브 뷰.
///
/// - 연결 중 단계: shimmer 스켈레톤 + 단계 문구 (CircularProgressIndicator 금지)
/// - streaming: RTCVideoView
/// - failed: 아이콘 + 에러 메시지 + "다시 연결" 버튼
class WebRtcLiveView extends ConsumerWidget {
  const WebRtcLiveView({super.key, required this.cameraUuid});

  final String cameraUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(webrtcLiveControllerProvider(cameraUuid));

    return switch (state.phase) {
      WebRtcLivePhase.connectingConfig => _ConnectingView(
          labelKey: 'crecam_live_phase_config',
        ),
      WebRtcLivePhase.offering => _ConnectingView(
          labelKey: 'crecam_live_phase_offering',
        ),
      WebRtcLivePhase.connectingIce => _ConnectingView(
          labelKey: 'crecam_live_phase_ice',
        ),
      WebRtcLivePhase.streaming => _StreamingView(
          renderer: state.renderer!,
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

// ── 연결 중 (shimmer 스켈레톤 + 단계 문구) ────────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Stack(
      fit: StackFit.expand,
      children: [
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(color: baseColor),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppStyles.spacing12,
          child: Center(
            child: Container(
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
            ),
          ),
        ),
      ],
    );
  }
}

// ── 스트리밍 ────────────────────────────────────────────────────────────────

class _StreamingView extends StatelessWidget {
  const _StreamingView({required this.renderer});

  final RTCVideoRenderer renderer;

  @override
  Widget build(BuildContext context) {
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }
}

// ── 에러 ─────────────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  const _FailedView({required this.errorKey, required this.onRetry});

  final String errorKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppStyles.spacing8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                errorKey.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppStyles.spacing12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
