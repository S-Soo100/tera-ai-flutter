import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/webrtc_live_view.dart';

/// 라이브 전체화면 — **가로 전용, 영상만 크게** (2026-09-07 사용자 결정).
///
/// 홈·카메라 탭 라이브 면의 확대 버튼이 여기로 온다. 구 목적지였던
/// [CameraDetailScreen]은 활동량·클립 목록까지 딸린 상세 화면이라 "확대"의
/// 기대와 어긋났다. 이 화면은 [WebRtcLiveView] 하나와 닫기 버튼만 둔다.
///
/// WebRTC 피어는 [webrtcLiveControllerProvider] family로 아래 탭의 라이브
/// 면과 공유된다 — 탭 화면이 이 라우트 밑에 살아 있는 동안 재연결 없이
/// 즉시 이어 본다.
///
/// 오리엔테이션·상태바 복원 문법은 [MotionClipPlayerScreen]과 같다:
/// 들어올 때 가로+immersive, 나갈 때 세로+상태바 복원.
class CameraLiveFullscreenScreen extends StatefulWidget {
  const CameraLiveFullscreenScreen({super.key, required this.cameraId});

  final String cameraId;

  static const closeButtonKey = Key('live_fullscreen_close');

  @override
  State<CameraLiveFullscreenScreen> createState() =>
      _CameraLiveFullscreenScreenState();
}

class _CameraLiveFullscreenScreenState
    extends State<CameraLiveFullscreenScreen> {
  /// 나갈 때 되돌릴 상태바 스타일 — 어두운 화면이 상태바를 흰 아이콘으로
  /// 바꾼 채 남기는 문제의 복원(MotionClipPlayerScreen 주석 참조).
  SystemUiOverlayStyle? _restoreOverlayStyle;

  @override
  void initState() {
    super.initState();
    // 좌/우 둘 다 허용 — 어느 쪽으로 눕히든 따라간다.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreOverlayStyle = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }

  @override
  void dispose() {
    // 되돌리지 않으면 이 화면을 닫은 뒤에도 앱 전체가 가로로 남는다.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    if (_restoreOverlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_restoreOverlayStyle!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // contain(기본) — 확대해서 보는 화면이라 프레임 전체를 보여준다.
            // cover면 가로 화면에서 상하가 크롭된다.
            Positioned.fill(
              child: WebRtcLiveView(cameraUuid: widget.cameraId),
            ),
            // 좌상단 닫기 — 노치/펀치홀을 피해 SafeArea 안쪽.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Tooltip(
                  message:
                      MaterialLocalizations.of(context).closeButtonTooltip,
                  child: Material(
                    color: AppTheme.liveScrim,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: CameraLiveFullscreenScreen.closeButtonKey,
                      onTap: () => context.pop(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.close,
                            size: 20, color: AppTheme.liveOnDark),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
