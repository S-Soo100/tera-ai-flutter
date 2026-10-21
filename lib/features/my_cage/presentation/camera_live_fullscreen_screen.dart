import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/figma_icon.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../notification/presentation/push_pre_popup.dart'
    show keepAllWords;
import '../domain/live_recording.dart';
import '../domain/sys_health.dart';
import '../domain/terra_camera.dart';
import 'live_recording_controller.dart';
import 'my_cage_providers.dart';
import 'player_view_providers.dart';
import 'sys_health_controllers.dart';
import 'webrtc_live_controller.dart';
import 'widgets/camera_rotate_tile.dart';
import 'widgets/crecam_detail_top_bar.dart';
import 'widgets/live_control_rows.dart';
import 'widgets/live_record_controls.dart';
import 'widgets/management_widgets.dart';
import 'widgets/sys_health_widgets.dart';
import 'widgets/webrtc_live_view.dart';

/// 라이브 확대 화면 — 세로 기본, 화면 방향은 전용 버튼으로만 전환한다.
///
/// 세로(Figma 1523:5049): 닫기 + 카메라 이름, 영상(오른쪽 아래 가로 전환),
/// 제어 목록(실시간 녹화·카메라 180° 회전·전원), 맨 아래 [카메라 재시작].
/// 가로(Figma 1525:5698): 닫기·녹화 알약·축소 셋만 영상 위에 둔다.
///
/// WebRTC 피어는 [webrtcLiveControllerProvider] family로 아래 탭의 라이브
/// 면과 공유된다 — 탭 화면이 이 라우트 밑에 살아 있는 동안 재연결 없이
/// 즉시 이어 본다. 세로↔가로는 같은 [WebRtcLiveView](GlobalKey)·같은 녹화
/// provider라 녹화도 이어진다.
///
/// 녹화 중 이탈(세로 X·가로 X·안드로이드 뒤로·iOS 스와이프)은 모두
/// [_confirmLeaveIfRecording] 하나로 중단 확인을 거친다.
class CameraLiveFullscreenScreen extends ConsumerStatefulWidget {
  const CameraLiveFullscreenScreen({super.key, required this.cameraId});

  final String cameraId;

  static const closeButtonKey = Key('live_fullscreen_close');
  static const rotateButtonKey = Key('live_fullscreen_rotate');
  static const rotateSubtitleKey = Key('live_fullscreen_rotate_subtitle');
  static const orientationButtonKey = Key('live_fullscreen_orientation');
  static const rebootButtonKey = Key('live_fullscreen_reboot');
  static const rebootReasonKey = Key('live_fullscreen_reboot_reason');

  /// 가로 조작 버튼(닫기·녹화·축소) 묶음의 페이드.
  static const landscapeControlsKey = Key('live_fullscreen_landscape_controls');

  @override
  ConsumerState<CameraLiveFullscreenScreen> createState() =>
      _CameraLiveFullscreenScreenState();
}

/// 가로 조작 버튼이 마지막 터치 뒤 사라지기까지(Figma 1525:5830 메모).
const kLiveLandscapeControlsHide = Duration(seconds: 5);

class _CameraLiveFullscreenScreenState
    extends ConsumerState<CameraLiveFullscreenScreen>
    with SingleTickerProviderStateMixin {
  final _orientationKey = Object();
  final _liveKey = GlobalKey();

  /// 나갈 때 되돌릴 상태바 스타일 — 어두운 화면이 상태바를 흰 아이콘으로
  /// 바꾼 채 남기는 문제의 복원(MotionClipPlayerScreen 주석 참조).
  SystemUiOverlayStyle? _restoreOverlayStyle;

  /// 성공한 회전 뒤 토글을 잠가 두는 타이머.
  Timer? _rotateHold;

  /// 이탈 확인 중복 방지(X 연타·뒤로+X).
  bool _leaving = false;

  /// 가로 조작 버튼 페이드(1 = 보임). 마지막 터치 [kLiveLandscapeControlsHide]
  /// 뒤 사라지고, 화면을 누르면 다시 나타난다 — 녹화 중에도 같다.
  late final AnimationController _controlsFade;
  Timer? _controlsHide;

  void _showControls() {
    _controlsHide?.cancel();
    _controlsFade.forward();
    _controlsHide = Timer(kLiveLandscapeControlsHide, () {
      if (mounted) _controlsFade.reverse();
    });
  }

  @override
  void initState() {
    super.initState();
    _controlsFade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200), value: 1);
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
    _rotateHold?.cancel();
    _controlsHide?.cancel();
    _controlsFade.dispose();
    if (_restoreOverlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_restoreOverlayStyle!);
    }
    super.dispose();
  }

  Future<void> _toggleRotate(String cameraUuid, bool next) async {
    final pending = _liveRotatePendingProvider(widget.cameraId);
    ref.read(pending.notifier).state = next;
    final ok =
        await submitRotate180(context, ref, cameraUuid: cameraUuid, next: next);
    if (!mounted) return;
    if (!ok) {
      ref.read(pending.notifier).state = null;
      return;
    }
    // 회전은 카메라 재부팅(약 20초) 뒤에 적용된다. 그동안 화면이 멈춰 실패로
    // 보고 다시 누르면 반대 값이 가서 되돌아가고 재부팅이 한 번 더 난다
    // (2026-09-25 점검) — 적용될 때까지 토글을 잠근다(누른 값으로 보여 준다).
    // 반영은 cameras Realtime → 라이브 재연결로 돌아온다.
    _rotateHold?.cancel();
    _rotateHold = Timer(kRotateRebootHold, () {
      if (mounted) ref.read(pending.notifier).state = null;
    });
  }

  /// 녹화 중이면 중단 확인 → [중단하기]면 저장 후 나간다. 네 이탈 경로 공용.
  Future<void> _confirmLeaveIfRecording() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final ok =
          await stopLiveRecordingWithConfirm(context, ref, widget.cameraId);
      if (!ok || !mounted) return;
      // pop()은 PopScope를 거치지 않는다 — 방금 멈췄어도 canPop이 아직
      // 이전 빌드 값(false)이라 maybePop이면 다시 막힌다.
      Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  void _toggleOrientation() =>
      ref.read(playerOrientationProvider(_orientationKey).notifier).toggle();

  @override
  Widget build(BuildContext context) {
    final cameraId = widget.cameraId;
    final camera = ref
        .watch(camerasProvider)
        .valueOrNull
        ?.where((c) => c.id == cameraId)
        .firstOrNull;
    final landscape = ref.watch(playerOrientationProvider(_orientationKey));
    ref.listen<bool>(playerOrientationProvider(_orientationKey), (_, next) {
      if (next) {
        _showControls();
      } else {
        // 세로엔 자동 숨김이 없다 — 다음 가로 진입은 보이는 채로 시작.
        _controlsHide?.cancel();
        _controlsFade.value = 1;
      }
    });
    final hasVideo = ref.watch(
        webrtcLiveControllerProvider(cameraId).select((s) => s.phase.hasVideo));
    // 녹화·회전·전원·가로 전환은 카메라가 온라인이고 영상이 나올 때만
    // (Figma 오프라인 상태 — 흐리고 누를 수 없음, 가로 전환 버튼 숨김).
    final available = camera != null && camera.isOnline && hasVideo;
    // 녹화는 세로↔가로를 바꿔도 이어진다 — 화면 전체에서 구독해 둔다
    // (autoDispose 유지). 경과 시간은 녹화 줄·알약만 다시 그린다.
    final recPhase = kLiveRecordingEnabled
        ? ref.watch(
            liveRecordingControllerProvider(cameraId).select((s) => s.phase))
        : LiveRecordingPhase.idle;
    final recording = recPhase == LiveRecordingPhase.recording ||
        recPhase == LiveRecordingPhase.starting;
    if (kLiveRecordingEnabled) {
      ref.listen<int>(
          liveRecordingControllerProvider(cameraId).select((s) => s.resultSeq),
          (_, __) {
        final s = ref.read(liveRecordingControllerProvider(cameraId));
        final result = s.result;
        if (result == null) return;
        // 세로 토스트는 맨 아래 [카메라 재시작] 버튼 자리(Figma 저장 완료),
        // 가로는 화면 한가운데(Figma 1525:11177).
        final inLandscape =
            ref.read(playerOrientationProvider(_orientationKey));
        showLiveRecordingResult(context, result, s.resultSeconds,
            bottom: MediaQuery.paddingOf(context).bottom + 66,
            centered: inLandscape);
      });
    }

    final body = landscape
        ? _buildLandscape(context, available: available)
        : _buildPortrait(context,
            camera: camera,
            available: available,
            recording: recPhase != LiveRecordingPhase.idle);
    return _RecordingLeaveGuard(
        recording: recording, onLeave: _confirmLeaveIfRecording, child: body);
  }

  Widget _buildPortrait(BuildContext context,
      {required TerraCamera? camera,
      required bool available,
      required bool recording}) {
    final glass = context.glass;
    final cameraId = widget.cameraId;
    final pending = ref.watch(_liveRotatePendingProvider(cameraId));
    final rotateValue = pending ?? camera?.rotate180 ?? false;
    // 녹화 중엔 회전 금지 — 카메라가 재부팅하며 녹화가 끊긴다.
    final canRotate = available && !recording && pending == null;
    return Scaffold(
      backgroundColor: glass.wallpaper,
      body: Column(children: [
        CrecamDetailHeaderArea(
            child: CrecamDetailTopBar(
          closeButton: true,
          leadingKey: CameraLiveFullscreenScreen.closeButtonKey,
          title: camera?.name ?? 'camera_live'.tr(),
          onBack: _confirmLeaveIfRecording,
        )),
        Expanded(
            child: SafeArea(
                top: false,
                child: Column(children: [
                  Expanded(
                      child: SingleChildScrollView(
                          child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _LiveAspectBox(
                                cameraUuid: cameraId,
                                child: Stack(fit: StackFit.expand, children: [
                                  WebRtcLiveView(
                                      key: _liveKey,
                                      cameraUuid: cameraId,
                                      // 재시작은 맨 아래 버튼 하나로(중복 방지).
                                      showReboot: false),
                                  // 가로 전환 — 영상 오른쪽 아래(안쪽 12) 32 원.
                                  // 영상이 없거나 오프라인이면 숨김(Figma 메모).
                                  if (available)
                                    Positioned(
                                        right: 12,
                                        bottom: 12,
                                        child: _CircleIconButton(
                                            key: CameraLiveFullscreenScreen
                                                .orientationButtonKey,
                                            size: 32,
                                            color: AppTheme.liveScrim,
                                            icon: FigmaIcon.tinted(
                                                'redesign_v2/zoom_out_map',
                                                size: 20,
                                                color: AppTheme.liveOnDark),
                                            tooltip: 'player_landscape'.tr(),
                                            onTap: _toggleOrientation)),
                                ])))),
                    const SizedBox(height: 20),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(children: [
                          if (kLiveRecordingEnabled) ...[
                            LiveRecordRow(
                                cameraId: cameraId, available: available),
                            const SizedBox(height: 24),
                          ],
                          LiveControlRow(
                            dimmed: !available,
                            icon: (c) =>
                                LiveRasterIcon('cameraswitch', color: c),
                            title: 'live_rotate_title'.tr(),
                            subtitleKey:
                                CameraLiveFullscreenScreen.rotateSubtitleKey,
                            subtitle: (rotateValue
                                    ? 'live_rotate_on'
                                    : 'live_rotate_off')
                                .tr(),
                            trailing: LiveRotateSwitch(
                                key: CameraLiveFullscreenScreen.rotateButtonKey,
                                value: rotateValue,
                                onChanged: canRotate && camera != null
                                    ? (v) => _toggleRotate(camera.id, v)
                                    : null),
                          ),
                          const SizedBox(height: 24),
                          LiveControlRow(
                            dimmed: !available,
                            icon: livePowerGlyph,
                            title: 'management_power'.tr(),
                            subtitle: 'management_power_on_label'.tr(),
                            trailing: LivePowerSegment(dimmed: !available),
                          ),
                        ])),
                    const SizedBox(height: 24),
                  ]))),
                  _LiveRebootFooter(camera: camera, recording: recording),
                ]))),
      ]),
    );
  }

  Widget _buildLandscape(BuildContext context, {required bool available}) {
    final glass = context.glass;
    final pad = MediaQuery.paddingOf(context);
    // Figma 852×393: 좌우 48·위아래 24. 노치·홈 표시줄이 더 크면 그만큼.
    final left = math.max(48.0, pad.left);
    final right = math.max(48.0, pad.right);
    final top = math.max(24.0, pad.top);
    final bottom = math.max(24.0, pad.bottom);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        // 어디를 누르든 조작 버튼을 다시 보이고 5초를 새로 잰다.
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _showControls(),
          child: Stack(
            // expand 필수 — 비-positioned 자식만 있으면 Stack이 그 크기로 수축해
            // 영상이 좌상단에 조그맣게 갇힌다(2026-09-07 실제 발생 버그).
            fit: StackFit.expand,
            children: [
              // contain(기본) — 확대해서 보는 화면이라 프레임 전체를 보여준다.
              // 가로에선 [Wi-Fi 바꾸기]를 두지 않는다 — 가로·immersive가 그대로
              // 이어져 기기 목록·비밀번호 입력이 가로로 열린다(2026-09-28).
              WebRtcLiveView(
                  key: _liveKey,
                  cameraUuid: widget.cameraId,
                  showWifiChange: false),
              // 회전 버튼은 가로에서 뺐다(Figma 메모 — 세로 목록 토글로).
              // 숨겨진 동안(사라지는 중 포함)은 탭을 받지 않는다.
              AnimatedBuilder(
                animation: _controlsFade,
                builder: (context, child) => IgnorePointer(
                    ignoring: _controlsFade.value == 0 ||
                        _controlsFade.status == AnimationStatus.reverse,
                    child: child),
                child: FadeTransition(
                  key: CameraLiveFullscreenScreen.landscapeControlsKey,
                  opacity: _controlsFade,
                  child: Stack(fit: StackFit.expand, children: [
                    Positioned(
                        left: left,
                        top: top,
                        child: _CircleIconButton(
                            key: CameraLiveFullscreenScreen.closeButtonKey,
                            size: 44,
                            color: glass.overlay,
                            icon: FigmaIcon.tinted(FigmaIcons.close,
                                size: 24, color: glass.textSecondary),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onTap: _confirmLeaveIfRecording)),
                    if (kLiveRecordingEnabled)
                      Positioned(
                          right: right,
                          top: top,
                          child: LiveRecordPill(
                              cameraId: widget.cameraId,
                              available: available,
                              landscape: true)),
                    Positioned(
                        right: right,
                        bottom: bottom,
                        child: _CircleIconButton(
                            key:
                                CameraLiveFullscreenScreen.orientationButtonKey,
                            size: 40,
                            color: AppTheme.liveScrim,
                            icon: FigmaIcon.tinted(FigmaIcons.zoomInMap,
                                size: 24, color: AppTheme.liveOnDark),
                            tooltip: 'player_portrait'.tr(),
                            onTap: _toggleOrientation)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 녹화 중 이탈 가로채기 — 안드로이드 뒤로·iOS 스와이프를 막고 [onLeave]로
/// 중단 확인을 띄운다(영상 선택 `ClipSelectionBackGuard`와 같은 문법:
/// PopScope + Router 아래면 BackButtonListener).
class _RecordingLeaveGuard extends StatelessWidget {
  const _RecordingLeaveGuard({
    required this.recording,
    required this.onLeave,
    required this.child,
  });

  final bool recording;
  final Future<void> Function() onLeave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = TickerMode.of(context);
    final popScope = PopScope(
      canPop: !recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onLeave();
      },
      child: child,
    );
    if (Router.maybeOf(context) == null) return popScope;
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!recording || !visible) return false;
        await onLeave();
        return true;
      },
      child: popScope,
    );
  }
}

/// 원형 아이콘 버튼 — 세로 가로 전환(32)·가로 닫기(44)·축소(40).
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    super.key,
    required this.size,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final double size;
  final Color color;
  final Widget icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child:
              SizedBox(width: size, height: size, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// 회전 PATCH를 보낸 뒤 적용될 때까지의 목표값(null = 대기 없음).
final _liveRotatePendingProvider =
    StateProvider.autoDispose.family<bool?, String>((ref, id) => null);

/// 영상 실제 비율의 틀(세로 확대 화면) — 좌우 12 안쪽 너비를 다 쓰고 높이는
/// 영상에 맞춘다. 영상이 오기 전·크기를 모르면 카메라 기본 4:3(펌웨어 스트림).
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
/// CTA와 같게 좌우 12·SafeArea 위 66. 녹화 중엔 막는다(재부팅으로 녹화가
/// 끊긴다).
///
/// **오프라인은 Figma처럼 빨간 버튼으로 둔다**(2026-10-21 사용자 결정 A). 꺼진
/// 카메라는 명령을 못 받고 서버도 보관하지 않아, 보내면 2분 기다린 뒤 전원
/// 안내만 뜬다 — 그래서 누르면 명령 대신 전원 안내창을 띄운다(Wi-Fi는 위
/// 오프라인 카드의 [네트워크 변경]을 가리킨다).
class _LiveRebootFooter extends ConsumerWidget {
  const _LiveRebootFooter({required this.camera, required this.recording});
  final TerraCamera? camera;
  final bool recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = camera;
    final reboot = cam == null
        ? const RebootState()
        : ref.watch(rebootProvider(cameraRebootTarget(cam.id)));
    final inProgress = reboot.sending || reboot.rebooting;
    // 재시작 중엔 카메라가 잠깐 꺼져 보인다 — 그땐 "재시작 중…"이 우선이다.
    final offline = !inProgress && cam != null && !recording && !cam.isOnline;
    final String? reason = inProgress || cam == null || offline
        ? null
        : recording
            ? 'live_reboot_recording'
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
              // Figma: 꺼졌을 때만 빨강(복구 안내 버튼). 켜져 있으면 검정.
              red: offline,
              // Figma 원본 비활성(#E3E3E3 위 #FAFAFA)은 글자가 안 보인다 —
              // "재시작 중…"을 읽어야 해서 진한 회색(2026-10-03 사용자 지시).
              disabledForeground: context.glass.bodySecondary,
              onPressed: !enabled
                  ? null
                  : offline
                      ? () => showVivaModal(context,
                          message: 'live_reboot_offline_title'.tr(),
                          detail: keepAllWords('live_reboot_offline_body'.tr()))
                      : () => confirmAndRequestReboot(
                          context, ref, cameraRebootTarget(cam.id))),
        ]));
  }
}
