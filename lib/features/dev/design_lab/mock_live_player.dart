import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_a_tokens.dart';
import 'variant_a_widgets.dart';

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
    this.visible = true,
  });

  /// 영상이 준비되기 전/실패 시 보여줄 바닥 레이어.
  /// 호스트 화면의 기존 플레이스홀더를 그대로 넘긴다.
  final Widget fallback;

  /// LIVE 배지 + 타임스탬프 오버레이(A안 유리 배지 문법).
  /// B안처럼 화면이 자기 오버레이를 갖고 있으면 끈다.
  final bool showBadge;

  /// 지금 화면에 실제로 보이는가. IndexedStack 셸은 탭 이탈 시 false를
  /// 내려보낸다 — 안 보이는 탭 뒤에서도 디코딩이 계속 돌면 랩 전체가
  /// 무거워진다. false면 pause, 복귀하면 play.
  final bool visible;

  @override
  State<MockLivePlayer> createState() => _MockLivePlayerState();
}

class _MockLivePlayerState extends State<MockLivePlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;

  /// 앱이 전면(resumed)인가 — [MockLivePlayer.visible]과 AND로 재생을 정한다.
  /// 백그라운드(inactive/paused)에서도 디코딩을 돌릴 이유가 없다.
  bool _appResumed = true;

  bool get _shouldPlay => widget.visible && _appResumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 컨트롤러를 먼저 필드에 올려 둔다(hoist) — initialize 도중 위젯이
    // dispose되어도 State.dispose가 정리할 수 있게.
    final controller =
        VideoPlayerController.asset('assets/videos/mock_live.mp4');
    _controller = controller;
    controller.initialize().then((_) async {
      if (!mounted) return; // dispose()가 컨트롤러를 정리한다.
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (_shouldPlay) await controller.play();
      if (mounted) setState(() => _ready = true);
    }).catchError((Object e) {
      // 실패 시 폴백 유지 — 단, 이유는 남긴다. 조용한 폴백만 있으면
      // 에셋 누락을 디자인 문제로 오인한 채 지나간다.
      debugPrint('[mock-live] init failed: $e');
      // mounted면 여기서 native 리소스를 즉시 정리하고,
      // 아니면 이미 State.dispose가 정리했으니 이중 dispose를 피한다.
      if (!mounted) return;
      _controller?.dispose();
      setState(() => _controller = null);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant MockLivePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _syncPlayback();
  }

  /// 재생 상태를 [_shouldPlay]에 맞춘다. 준비 전이면 initialize 후속(play
  /// 직전의 [_shouldPlay] 확인)이 알아서 처리한다.
  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (_shouldPlay) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        // 배지는 공용 [AGlass](blur 기본 false) — 비디오 위 BackdropFilter는
        // **프레임마다** 재실행돼 배지 두 개 값이 아니다. 판독성은 진한
        // 오버레이(overlayStrong)가 대신 진다.
        if (widget.showBadge) ...[
          Positioned(
            left: 12,
            bottom: 12,
            child: _badgeGlass(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: VariantATokens.of(context).liveRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: VariantATokens.of(context).textPrimary,
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
            child: _badgeGlass(
              child: Text(labHm(kLabNow),
                  style: VariantATokens.of(context).tileStatus),
            ),
          ),
        ],
      ],
    );
  }

  /// 배지 공통 마감 — 공용 [AGlass]에 배지 규격(radius 8·강한 오버레이)만 입힌다.
  Widget _badgeGlass({required Widget child}) => AGlass(
        radius: 8,
        overlay: VariantATokens.of(context).glassOverlayStrong,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      );
}
