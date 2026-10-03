import 'dart:async';

import 'dart:math' as math;
import '../../../core/theme/glass_palette.dart';
import 'widgets/crecam_detail_top_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/sys_health.dart';
import '../domain/terra_camera.dart';
import 'my_cage_providers.dart';
import 'sys_health_controllers.dart';
import 'webrtc_live_controller.dart';
import 'widgets/management_widgets.dart';
import 'widgets/sys_health_widgets.dart';
import 'player_view_providers.dart';
import '../../../shared/widgets/figma_icon.dart';
import 'widgets/camera_rotate_tile.dart';
import 'widgets/webrtc_live_view.dart';

/// 라이브 전체화면 — 세로 기본, 화면 방향은 전용 버튼으로만 전환한다.
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
  static const rebootButtonKey = Key('live_fullscreen_reboot');
  static const rebootReasonKey = Key('live_fullscreen_reboot_reason');

  @override
  ConsumerState<CameraLiveFullscreenScreen> createState() =>
      _CameraLiveFullscreenScreenState();
}

class _CameraLiveFullscreenScreenState
    extends ConsumerState<CameraLiveFullscreenScreen> {
  final _orientationKey = Object();
  final _liveKey = GlobalKey();

  /// 나갈 때 되돌릴 상태바 스타일 — 어두운 화면이 상태바를 흰 아이콘으로
  /// 바꾼 채 남기는 문제의 복원(MotionClipPlayerScreen 주석 참조).
  SystemUiOverlayStyle? _restoreOverlayStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreOverlayStyle = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }

  @override
  void dispose() {
    _rotateHold?.cancel();
    if (_restoreOverlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_restoreOverlayStyle!);
    }
    super.dispose();
  }

  /// 성공한 회전 뒤 버튼을 잠가 두는 타이머.
  Timer? _rotateHold;

  Future<void> _toggleRotate(String cameraUuid, bool next) async {
    ref.read(_liveRotateBusyProvider(widget.cameraId).notifier).state = true;
    final ok = await submitRotate180(context, ref,
        cameraUuid: cameraUuid, next: next);
    if (!mounted) return;
    if (!ok) {
      ref.read(_liveRotateBusyProvider(widget.cameraId).notifier).state = false;
      return;
    }
    // 회전은 카메라 재부팅(약 20초) 뒤에 적용된다. 그동안 화면이 멈춰 실패로
    // 보고 다시 누르면 반대 값이 가서 되돌아가고 재부팅이 한 번 더 난다
    // (2026-09-25 점검) — 적용될 때까지 버튼을 잠근다. 반영은 cameras
    // Realtime → 라이브 재연결로 돌아온다.
    _rotateHold?.cancel();
    _rotateHold = Timer(kRotateRebootHold, () {
      if (mounted) {
        ref.read(_liveRotateBusyProvider(widget.cameraId).notifier).state =
            false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 회전 버튼은 세로·가로 어느 쪽이든 **항상 표시**한다(2026-09-23 사용자
    // 지시 — capabilities 미보고 구 펌웨어·카메라 목록 로딩 중에도 숨기지
    // 않는다). 환경설정 타일의 capabilities 게이팅과는 의도적으로 다르다.
    // 카메라 행을 아직 못 읽었으면 현재값을 몰라 비활성으로만 둔다.
    // camerasProvider는 Realtime이라 rotate_180 현재값도 따라온다.
    final camera = ref
        .watch(camerasProvider)
        .valueOrNull
        ?.where((c) => c.id == widget.cameraId)
        .firstOrNull;
    final landscape = ref.watch(playerOrientationProvider(_orientationKey));
    final rotateBusy = ref.watch(_liveRotateBusyProvider(widget.cameraId));

    if (!landscape) {
      final glass = context.glass;
      return Scaffold(
        backgroundColor: glass.wallpaper,
        body: Column(children: [
          CrecamDetailHeaderArea(
              child: CrecamDetailTopBar(
            closeButton: true,
            leadingKey: CameraLiveFullscreenScreen.closeButtonKey,
            title: camera?.name ?? 'camera_live'.tr(),
            trailing: IconButton(
              key: CameraLiveFullscreenScreen.rotateButtonKey,
              tooltip: 'camera_rotate_title'.tr(),
              onPressed: rotateBusy || camera == null
                  ? null
                  : () => _toggleRotate(camera.id, !camera.rotate180),
              icon: Icon(Icons.flip_camera_android_outlined,
                  color: glass.textPrimary),
            ),
          )),
          Expanded(
              child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                      builder: (context, size) => Column(children: [
                            SizedBox(
                                height: math.min(84, size.maxHeight * 0.13)),
                            // 좌우 끝까지(2026-10-03 사용자 지시) — 틀을 영상
                            // 비율에 맞춰 contain이어도 옆이 비지 않는다.
                            _LiveAspectBox(
                                cameraUuid: widget.cameraId,
                                child: WebRtcLiveView(
                                    key: _liveKey,
                                    cameraUuid: widget.cameraId,
                                    // 재시작은 맨 아래 버튼 하나로(중복 방지).
                                    showReboot: false)),
                            Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: IconButton(
                                      key: const Key(
                                          'live_fullscreen_orientation'),
                                      tooltip: 'player_landscape'.tr(),
                                      onPressed: () => ref
                                          .read(playerOrientationProvider(
                                                  _orientationKey)
                                              .notifier)
                                          .toggle(),
                                      icon: FigmaIcon.tinted(FigmaIcons.expand,
                                          color: glass.textPrimary, size: 36),
                                    ))),
                            const Spacer(),
                            _LiveRebootFooter(camera: camera),
                          ])))),
        ]),
      );
    }

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
            // 가로 전체화면에선 [Wi-Fi 바꾸기]를 두지 않는다 — 가로·immersive가
            // 그대로 이어져 기기 목록·비밀번호 입력이 가로로 열린다(2026-09-28).
            WebRtcLiveView(
                key: _liveKey,
                cameraUuid: widget.cameraId,
                showWifiChange: false),
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
                    asset: FigmaIcons.close,
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onTap: () => context.pop(),
                  ),
                ),
              ),
            ),
            SafeArea(
                child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _ScrimCircleButton(
                    key: const Key('live_fullscreen_orientation'),
                    icon: Icons.fullscreen,
                    asset: FigmaIcons.expand,
                    tooltip:
                        (landscape ? 'player_portrait' : 'player_landscape')
                            .tr(),
                    onTap: () => ref
                        .read(
                            playerOrientationProvider(_orientationKey).notifier)
                        .toggle(),
                  )),
            )),
            // 우상단 화면 뒤집기(180°) — 닫기의 반대편(2026-09-09 사용자
            // 지시: 거꾸로 보이는 걸 알아채는 곳이 바로 이 화면이다).
            // 항상 표시(2026-09-23 사용자 지시 — 위 build 주석 참조).
            // 탭 → PATCH + 재부팅 예고 스낵바, 라이브는 끊겼다 자동 재연결.
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _ScrimCircleButton(
                    key: CameraLiveFullscreenScreen.rotateButtonKey,
                    icon: Icons.flip_camera_android_outlined,
                    tooltip: 'camera_rotate_title'.tr(),
                    onTap: rotateBusy || camera == null
                        ? null
                        : () => _toggleRotate(camera.id, !camera.rotate180),
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
    this.asset,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String? asset;
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
            width: 44,
            height: 44,
            child: asset != null
                ? FigmaIcon.tinted(asset!, color: Colors.white, size: 24)
                : Icon(icon,
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

final _liveRotateBusyProvider =
    StateProvider.autoDispose.family<bool, String>((ref, id) => false);

/// 영상 실제 비율의 틀(세로 확대 화면) — 화면 너비를 다 쓰고 높이는 영상에
/// 맞춘다. 영상이 오기 전·크기를 모르면 카메라 기본 4:3(펌웨어 스트림).
class _LiveAspectBox extends ConsumerWidget {
  const _LiveAspectBox({required this.cameraUuid, required this.child});
  final String cameraUuid;
  final Widget child;

  static const double _fallback = 4 / 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderer = ref.watch(webrtcLiveControllerProvider(cameraUuid)
        .select((s) => s.phase.hasVideo ? s.renderer : null));
    if (renderer == null) {
      return AspectRatio(aspectRatio: _fallback, child: child);
    }
    return ValueListenableBuilder(
        valueListenable: renderer,
        child: child,
        builder: (context, value, child) {
          final ratio = value.width > 0 && value.height > 0
              ? value.aspectRatio
              : _fallback;
          return AspectRatio(aspectRatio: ratio, child: child);
        });
  }
}

/// 세로 확대 화면 맨 아래 [카메라 재시작](2026-10-03 사용자 지시, Figma 밖 —
/// 버튼은 Figma 971:1837 '다시 스캔' 컴포넌트 그대로). 재시작할 수 없으면
/// 숨기지 않고 비활성 + 이유를 위에 둔다(사용자 결정). 위치는 Figma 공통 하단
/// CTA와 같게 좌우 12·SafeArea 위 66.
class _LiveRebootFooter extends ConsumerWidget {
  const _LiveRebootFooter({required this.camera});
  final TerraCamera? camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = camera;
    final reboot = cam == null
        ? const RebootState()
        : ref.watch(rebootProvider(cameraRebootTarget(cam.id)));
    final inProgress = reboot.sending || reboot.rebooting;
    final String? reason = inProgress || cam == null
        ? null
        : !cam.isOnline
            ? 'live_reboot_offline'
            : !isRebootCapableFirmware(cam.firmwareVer)
                ? 'live_reboot_old_firmware'
                : reboot.coolingDown(DateTime.now())
                    ? 'live_reboot_wait'
                    : null;
    final enabled = cam != null && !inProgress && reason == null;
    return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 66),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (reason != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(reason.tr(),
                    key: CameraLiveFullscreenScreen.rebootReasonKey,
                    textAlign: TextAlign.center,
                    style: managementStyle(context,
                        size: 14, color: context.glass.bodySecondary))),
          ManagementButton(
              key: CameraLiveFullscreenScreen.rebootButtonKey,
              label: (inProgress ? 'reboot_progress' : 'camera_reboot').tr(),
              icon: 'redesign_v2/restart_alt',
              // Figma 원본 비활성(#E3E3E3 위 #FAFAFA)은 글자가 안 보인다 —
              // "재시작 중…"을 읽어야 해서 진한 회색(2026-10-03 사용자 지시).
              disabledForeground: context.glass.bodySecondary,
              onPressed: enabled
                  ? () => confirmAndRequestReboot(
                      context, ref, cameraRebootTarget(cam.id))
                  : null),
        ]));
  }
}
