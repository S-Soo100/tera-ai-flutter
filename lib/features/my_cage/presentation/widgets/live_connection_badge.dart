import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/status_badge.dart';
import '../webrtc_live_controller.dart';

/// 라이브 면 좌상단 연결 상태 배지 — **한 번에 하나의 진실만 말한다.**
///
/// 홈 `TopFixedArea`의 `_ConnectionStatus`를 공용화(2026-09-07, 리뷰 잔여
/// A3 — 카메라 탭이 구 그리드의 온라인 표시를 잃었었다). 판정은 DB
/// `cameras.is_online`(stale 가능)이 아니라 **WebRTC 스트림 phase**다:
/// - streaming → `LIVE`
/// - failed → `연결 끊김`
/// - 연결 중 → 배지 없음(가운데 단계 문구가 이미 말한다 — 중복 금지)
class LiveConnectionBadge extends ConsumerWidget {
  const LiveConnectionBadge({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(webrtcLiveControllerProvider(cameraId)).phase;
    return switch (phase) {
      WebRtcLivePhase.streaming => const StatusBadge(
          label: 'LIVE',
          tone: StatusTone.live,
          onDark: true,
        ),
      WebRtcLivePhase.failed => StatusBadge(
          label: 'home_live_offline'.tr(),
          tone: StatusTone.neutral,
          onDark: true,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
