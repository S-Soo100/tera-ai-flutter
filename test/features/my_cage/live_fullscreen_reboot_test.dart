// 라이브 세로 확대 화면 — 영상 좌우 꽉 채움·맨 아래 [카메라 재시작]
// (2026-10-03 사용자 지시). `.tr()`은 키를 그대로 돌려준다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivanaut/features/my_cage/domain/sys_health.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/camera_live_fullscreen_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/webrtc_live_view.dart';

const _id = 'cam-uuid-1';
const _newFw = 'fb2-p4 0.2.0-20260928';

TerraCamera _camera({bool online = true, String? fw = _newFw}) => TerraCamera(
    id: _id,
    cameraId: 'p4cam-1',
    name: '카메라 3',
    firmwareVer: fw,
    isOnline: online,
    createdAt: DateTime(2026, 9, 8));

class _Repo extends Fake implements CameraRepository {
  int reboots = 0;
  @override
  Future<bool> reboot(String cameraUuid) async {
    reboots++;
    return true;
  }

  @override
  Future<SysHealth> fetchHealth(String cameraUuid) async => SysHealth.empty;
}

class _FakeRenderer extends RTCVideoRenderer {
  @override
  Future<void> initialize() async {}
  @override
  set srcObject(MediaStream? stream) {}
  @override
  // ignore: must_call_super
  Future<void> dispose() async {}
}

class _Fixed extends WebRtcLiveController {
  _Fixed(super.ref, super.cameraUuid, WebRtcLiveState s) {
    state = s;
  }
}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());

  Future<void> pump(WidgetTester tester,
      {TerraCamera? camera,
      WebRtcLiveState live = const WebRtcLiveState(
          phase: WebRtcLivePhase.failed, errorKey: 'test_live_inert')}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cam = camera ?? _camera();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        camerasProvider.overrideWith((ref) => Stream.value([cam])),
        cameraRepositoryProvider.overrideWithValue(repo),
        sysHealthProvider(cameraRebootTarget(_id))
            .overrideWith((ref) => const Stream.empty()),
        webrtcLiveControllerProvider
            .overrideWith((ref, id) => _Fixed(ref, id, live)),
      ],
      child: const MaterialApp(
          home: Scaffold(body: CameraLiveFullscreenScreen(cameraId: _id))),
    ));
    await tester.pump();
    await tester.pump();
  }

  Size liveBox(WidgetTester tester) => tester.getSize(find.byType(WebRtcLiveView));

  testWidgets('영상 오기 전엔 4:3 틀로 화면 좌우 끝까지', (tester) async {
    await pump(tester);
    final size = liveBox(tester);
    expect(size.width, 393);
    expect(size.height, closeTo(393 * 3 / 4, 0.5));
  });

  testWidgets('영상이 오면 실제 비율로 좌우 끝까지', (tester) async {
    final renderer = _FakeRenderer()
      ..value = const RTCVideoValue(width: 640, height: 360);
    await pump(tester,
        live: WebRtcLiveState(
            phase: WebRtcLivePhase.streaming, renderer: renderer));
    final size = liveBox(tester);
    expect(size.width, 393);
    expect(size.height, closeTo(393 * 9 / 16, 0.5));
  });

  testWidgets('재시작할 수 있으면 맨 아래 버튼 — 확인 뒤 한 번 보내고 "재시작 중…"',
      (tester) async {
    await pump(tester);
    final button = find.byKey(CameraLiveFullscreenScreen.rebootButtonKey);
    expect(button, findsOneWidget);
    expect(find.byKey(CameraLiveFullscreenScreen.rebootReasonKey), findsNothing);
    expect(
        tester.getBottomLeft(button).dy, greaterThan(852 / 2),
        reason: '맨 아래');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.reboots, 0, reason: '확인 전엔 보내지 않는다');
    await tester.tap(find.byKey(const Key('reboot_ok')));
    await tester.pump();
    await tester.pump();
    expect(repo.reboots, 1);
    expect(find.text('reboot_progress'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.descendant(
            of: button, matching: find.byType(FilledButton)))
        .onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(kRebootTimeout);
  });

  for (final (label, camera, reason) in [
    ('오프라인', _camera(online: false), 'live_reboot_offline'),
    ('구 펌웨어', _camera(fw: 'fb2-p4 0.1.0'), 'live_reboot_old_firmware'),
    ('버전 모름', _camera(fw: null), 'live_reboot_old_firmware'),
  ]) {
    testWidgets('$label이면 숨기지 않고 비활성 + 이유', (tester) async {
      await pump(tester, camera: camera);
      final button = find.byKey(CameraLiveFullscreenScreen.rebootButtonKey);
      expect(button, findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.descendant(of: button, matching: find.byType(FilledButton)))
              .onPressed,
          isNull);
      expect(find.text(reason), findsOneWidget);
    });
  }

  testWidgets('라이브가 실패해도 재시작 버튼은 맨 아래 하나 — 안내는 재시작 권유',
      (tester) async {
    await pump(tester,
        live: const WebRtcLiveState(
            phase: WebRtcLivePhase.failed,
            errorKey: 'crecam_live_error_unresponsive'));
    expect(find.byKey(WebRtcLiveView.rebootButtonKey), findsNothing);
    expect(find.byKey(CameraLiveFullscreenScreen.rebootButtonKey), findsOneWidget);
    expect(find.textContaining('crecam_live_hint_reboot'), findsOneWidget);
  });

  testWidgets('가로 모드엔 맨 아래 재시작 버튼이 없다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('live_fullscreen_orientation')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(CameraLiveFullscreenScreen.rebootButtonKey), findsNothing);
  });
}
