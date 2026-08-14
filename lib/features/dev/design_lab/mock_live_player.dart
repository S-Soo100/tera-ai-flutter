import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_a_tokens.dart';

/// 랩 공용 mock 라이브 플레이어 — 번들 클립을 무한 루프로 돌려 "라이브"처럼
/// 보여준다(무음·컨트롤 없음). 실 WebRTC·서버는 건드리지 않는다(랩 격리).
///
/// 초기화 실패(에셋 누락 등) 시 [fallback](기존 그라데이션 플레이스홀더)으로
/// 조용히 내려앉는다 — 디자인 체험이 영상 하나 때문에 죽으면 안 된다.
/// 로딩 중에도 [fallback]이 그대로 보인다(스피너 금지 규칙).
class MockLivePlayer extends StatefulWidget {
  const MockLivePlayer({
    super.key,
    required this.fallback,
    this.showBadge = true,
  });

  /// 영상이 준비되기 전/실패 시 보여줄 바닥 레이어.
  /// 호스트 화면의 기존 플레이스홀더를 그대로 넘긴다.
  final Widget fallback;

  /// LIVE 배지 + 타임스탬프 오버레이(A안 유리 배지 문법).
  /// B안처럼 화면이 자기 오버레이를 갖고 있으면 끈다.
  final bool showBadge;

  @override
  State<MockLivePlayer> createState() => _MockLivePlayerState();
}

class _MockLivePlayerState extends State<MockLivePlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // 컨트롤러를 먼저 필드에 올려 둔다(hoist) — initialize 도중 위젯이
    // dispose되어도 State.dispose가 정리할 수 있게.
    final controller =
        VideoPlayerController.asset('assets/videos/mock_live.mp4');
    _controller = controller;
    controller.initialize().then((_) async {
      if (!mounted) return; // dispose()가 컨트롤러를 정리한다.
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    }).catchError((Object _) {
      // 실패 시 폴백 유지. mounted면 여기서 native 리소스를 즉시 정리하고,
      // 아니면 이미 State.dispose가 정리했으니 이중 dispose를 피한다.
      if (!mounted) return;
      _controller?.dispose();
      setState(() => _controller = null);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.fallback,
        if (_ready && controller != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (widget.showBadge) ...[
          Positioned(
            left: 12,
            bottom: 12,
            child: _BadgeGlass(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: VariantATokens.liveRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: VariantATokens.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _BadgeGlass(
              child: Text(labHm(kLabNow), style: VariantATokens.tileStatus),
            ),
          ),
        ],
      ],
    );
  }
}

/// A안 카메라 카드의 유리 배지 문법(blur + 흰 오버레이 + 얇은 테두리).
class _BadgeGlass extends StatelessWidget {
  const _BadgeGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: VariantATokens.blurSigma,
          sigmaY: VariantATokens.blurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VariantATokens.glassOverlay,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VariantATokens.glassBorder, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
