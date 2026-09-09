import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'my_cage_providers.dart';
import 'widgets/camera_rotate_tile.dart';
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
class CameraLiveFullscreenScreen extends ConsumerStatefulWidget {
  const CameraLiveFullscreenScreen({super.key, required this.cameraId});

  final String cameraId;

  static const closeButtonKey = Key('live_fullscreen_close');
  static const rotateButtonKey = Key('live_fullscreen_rotate');

  @override
  ConsumerState<CameraLiveFullscreenScreen> createState() =>
      _CameraLiveFullscreenScreenState();
}

class _CameraLiveFullscreenScreenState
    extends ConsumerState<CameraLiveFullscreenScreen> {
  bool _rotateBusy = false;
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

  Future<void> _toggleRotate(String cameraUuid, bool next) async {
    setState(() => _rotateBusy = true);
    await submitRotate180(context, ref, cameraUuid: cameraUuid, next: next);
    // 성공/실패 무관 버튼만 해제 — 표시 상태는 없고(아이콘 버튼), 반영은
    // cameras Realtime → 라이브 재부팅 재연결로 돌아온다.
    if (mounted) setState(() => _rotateBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    // 회전 버튼 게이팅 — capabilities 보고 카메라만(환경설정 타일과 동일
    // 문법). camerasProvider는 Realtime이라 rotate_180 현재값도 따라온다.
    final camera = ref
        .watch(camerasProvider)
        .valueOrNull
        ?.where((c) => c.id == widget.cameraId)
        .firstOrNull;
    final rotatable = camera != null && camera.rotate180Capable;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        // expand 필수 — 비-positioned 자식(닫기 버튼)만 있으면 Stack이 그
        // 크기로 수축해 Positioned.fill 영상이 좌상단에 조그맣게 갇힌다
        // (2026-09-07 실제 발생 버그).
        body: Stack(
          fit: StackFit.expand,
          children: [
            // contain(기본) — 확대해서 보는 화면이라 프레임 전체를 보여준다.
            // cover면 가로 화면에서 상하가 크롭된다.
            WebRtcLiveView(cameraUuid: widget.cameraId),
            // 좌상단 닫기 — 노치/펀치홀을 피해 SafeArea 안쪽. expand된
            // Stack에서 버튼이 늘어나지 않게 Align으로 좌상단 고정.
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _ScrimCircleButton(
                    key: CameraLiveFullscreenScreen.closeButtonKey,
                    icon: Icons.close,
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onTap: () => context.pop(),
                  ),
                ),
              ),
            ),
            // 우상단 화면 뒤집기(180°) — 닫기의 반대편(2026-09-09 사용자
            // 지시: 거꾸로 보이는 걸 알아채는 곳이 바로 이 화면이다).
            // capabilities 미보고 카메라는 숨김(환경설정 타일과 동일 계약).
            // 탭 → PATCH + 재부팅 예고 스낵바, 라이브는 끊겼다 자동 재연결.
            if (rotatable)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _ScrimCircleButton(
                      key: CameraLiveFullscreenScreen.rotateButtonKey,
                      icon: Icons.flip_camera_android_outlined,
                      tooltip: 'camera_rotate_title'.tr(),
                      onTap: _rotateBusy
                          ? null
                          : () =>
                              _toggleRotate(camera.id, !camera.rotate180),
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

/// 검은 영상 위 원형 반투명 버튼 — 닫기·화면 뒤집기 공용(36pt, liveScrim).
class _ScrimCircleButton extends StatelessWidget {
  const _ScrimCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.liveScrim,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon,
                size: 20,
                color: onTap == null
                    ? AppTheme.liveOnDark.withValues(alpha: 0.4)
                    : AppTheme.liveOnDark),
          ),
        ),
      ),
    );
  }
}
