// 라이브 확대 화면 — 실시간 녹화 Figma(1523:5049 세로 / 1525:5698 가로) 동작.
// `.tr()`은 키를 그대로 돌려준다(EasyLocalization 없이 그린다).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivanaut/features/my_cage/data/live_recording_repository.dart';
import 'package:vivanaut/features/my_cage/domain/live_recording.dart';
import 'package:vivanaut/features/my_cage/domain/sys_health.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/camera_live_fullscreen_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/live_recording_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/clip_toast.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/live_control_rows.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/live_record_controls.dart';

const _id = 'cam-uuid-1';

TerraCamera _camera({bool online = true}) => TerraCamera(
    id: _id,
    cameraId: 'p4cam-1',
    name: '카메라 10',
    firmwareVer: 'fb2-p4 0.2.0-20260928',
    isOnline: online,
    createdAt: DateTime(2026, 9, 8));

class _CameraRepo extends Fake implements CameraRepository {
  final rotateCalls = <bool>[];
  @override
  Future<void> setRotate180(String cameraUuid, bool on) async =>
      rotateCalls.add(on);
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

class _Live extends WebRtcLiveController {
  _Live(super.ref, super.cameraUuid, WebRtcLiveState s) {
    state = s;
  }
  void set(WebRtcLiveState s) => state = s;
}

/// 첫 장면 캡처는 실패시킨다 — 위젯 테스트(가짜 시계)에서 파일을 쓰지 않게.
class _FakeTrack implements MediaStreamTrack {
  @override
  Future<ByteBuffer> captureFrame() async => throw UnsupportedError('test');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Recorder implements LiveVideoRecorder {
  int starts = 0;
  int stops = 0;
  @override
  Future<void> start(String path, MediaStreamTrack track) async => starts++;
  @override
  Future<void> stop() async => stops++;
}

/// 파일·Hive 없이 메모리에만 남기는 보관소.
class _MemRepo extends LiveRecordingRepository {
  final saved = <LiveRecording>[];
  @override
  Future<({String rel, String abs})> newPath(
          String ownerId, String id, String ext) async =>
      (rel: 'mem/$id.$ext', abs: '/mem/$id.$ext');
  @override
  Future<String> resolve(String rel) async => '/mem/$rel';
  @override
  Future<void> save(LiveRecording r) async => saved.add(r);
  @override
  Future<List<LiveRecording>> list(String ownerId) async => saved;
  @override
  Future<void> discardFile(String abs) async {}
}

void main() {
  late _CameraRepo cameraRepo;
  late _MemRepo repo;
  late _Recorder recorder;
  late _Live live;
  late GlobalKey<NavigatorState> nav;

  WebRtcLiveState streaming() => WebRtcLiveState(
      phase: WebRtcLivePhase.streaming,
      renderer: _FakeRenderer()
        ..value = const RTCVideoValue(width: 1280, height: 960));

  setUp(() {
    cameraRepo = _CameraRepo();
    repo = _MemRepo();
    recorder = _Recorder();
    nav = GlobalKey<NavigatorState>();
  });

  tearDown(dismissClipToast);

  Future<void> pump(WidgetTester tester,
      {TerraCamera? camera, WebRtcLiveState? initial}) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cam = camera ?? _camera();
    final start = initial ?? streaming();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(User(
            id: 'u1',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '2026-01-01')),
        camerasProvider.overrideWith((ref) => Stream.value([cam])),
        cameraRepositoryProvider.overrideWithValue(cameraRepo),
        sysHealthProvider(cameraRebootTarget(_id))
            .overrideWith((ref) => const Stream.empty()),
        webrtcLiveControllerProvider
            .overrideWith((ref, id) => live = _Live(ref, id, start)),
        liveRecordingRepositoryProvider.overrideWithValue(repo),
        liveVideoRecorderFactoryProvider.overrideWithValue(() => recorder),
        liveRecordingProbeProvider.overrideWithValue((_) async => null),
        liveRecordingTrackOfProvider.overrideWithValue(
            (s) => s.phase.hasVideo ? _FakeTrack() : null),
      ],
      child: MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('root'))),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const CameraLiveFullscreenScreen(cameraId: _id)));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  Finder pill() => find.byKey(LiveRecordControls.buttonKey);
  VoidCallback? pillTap(WidgetTester tester) =>
      tester.widget<InkWell>(pill()).onTap;
  LiveRecordingPhase recPhase(WidgetTester tester) => ProviderScope.containerOf(
          tester.element(find.byType(CameraLiveFullscreenScreen)))
      .read(liveRecordingControllerProvider(_id))
      .phase;
  Finder modal() => find.byKey(const Key('viva_modal_surface'));
  bool rebootEnabled(WidgetTester tester) => tester
          .widget<FilledButton>(find.descendant(
              of: find.byKey(CameraLiveFullscreenScreen.rebootButtonKey),
              matching: find.byType(FilledButton)))
          .onPressed !=
      null;

  Future<void> startRecording(WidgetTester tester,
      {Duration run = const Duration(seconds: 5)}) async {
    await tester.tap(pill());
    await tester.pump();
    await tester.pump();
    expect(recPhase(tester), LiveRecordingPhase.recording);
    await tester.pump(run);
  }

  test('경과 시간 표기 00:01', () {
    expect(formatLiveRecordElapsed(const Duration(milliseconds: 1999)), '00:01');
    expect(formatLiveRecordElapsed(const Duration(minutes: 2)), '02:00');
  });

  testWidgets('세로 목록 3줄 — 대기 알약·회전 토글·전원, 영상 위 가로 전환', (tester) async {
    await pump(tester);
    expect(find.text('live_record_title'), findsOneWidget);
    expect(find.text('live_record_max'), findsOneWidget);
    expect(find.text('live_rotate_title'), findsOneWidget);
    expect(find.text('live_rotate_off'), findsOneWidget);
    expect(find.text('management_power'), findsOneWidget);
    expect(find.text('management_power_on_label'), findsOneWidget);
    // 대기 알약: 112×40, 누를 수 있음, "녹화 시작".
    expect(tester.getSize(pill()).height, 40);
    expect(tester.getSize(pill()).width, inInclusiveRange(112, 200));
    expect(pillTap(tester), isNotNull);
    expect(find.descendant(of: pill(), matching: find.text('live_record_start')),
        findsOneWidget);
    // 영상은 좌우 12 안쪽(369), 가로 전환은 영상 안 오른쪽 아래.
    final video = tester.getRect(find.byType(ClipRRect).first);
    expect(video.width, 369);
    final toggle = tester
        .getRect(find.byKey(CameraLiveFullscreenScreen.orientationButtonKey));
    expect(toggle.size, const Size(32, 32));
    expect(toggle.right, video.right - 12);
    expect(toggle.bottom, video.bottom - 12);
    // 회전 토글 탭 → PATCH, 적용될 때까지 잠김.
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.rotateButtonKey));
    await tester.pump();
    expect(cameraRepo.rotateCalls, [true]);
    expect(find.text('live_rotate_on'), findsOneWidget);
    expect(
        tester
            .widget<LiveRotateSwitch>(
                find.byKey(CameraLiveFullscreenScreen.rotateButtonKey))
            .onChanged,
        isNull);
    await finish(tester);
  });

  testWidgets('오프라인 — 세 줄 흐림, 알약 비활성(아이콘 없음), 가로 전환 숨김', (tester) async {
    await pump(tester,
        camera: _camera(online: false),
        initial: const WebRtcLiveState(
            phase: WebRtcLivePhase.failed, errorKey: 'test_live_inert'));
    expect(pillTap(tester), isNull);
    expect(find.descendant(of: pill(), matching: find.byType(Image)),
        findsNothing);
    expect(find.byKey(CameraLiveFullscreenScreen.orientationButtonKey),
        findsNothing);
    expect(
        tester
            .widget<LiveRotateSwitch>(
                find.byKey(CameraLiveFullscreenScreen.rotateButtonKey))
            .onChanged,
        isNull);
    for (final row in tester.widgetList<LiveControlRow>(
        find.byType(LiveControlRow))) {
      expect(row.dimmed, isTrue);
    }
    await finish(tester);
  });

  testWidgets('녹화 중 — 검정 [녹화 중단], 회전·재시작 비활성(이유)', (tester) async {
    await pump(tester);
    expect(rebootEnabled(tester), isTrue);
    await startRecording(tester, run: const Duration(seconds: 1));
    expect(find.descendant(of: pill(), matching: find.text('live_record_stop')),
        findsOneWidget);
    expect(find.text('live_record_elapsed'), findsOneWidget);
    expect(
        tester
            .widget<LiveRotateSwitch>(
                find.byKey(CameraLiveFullscreenScreen.rotateButtonKey))
            .onChanged,
        isNull);
    expect(rebootEnabled(tester), isFalse);
    expect(find.text('live_reboot_recording'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('3초 미만 [녹화 중단] → 확인창 없이 멈추고 "짧아 저장 안 함"', (tester) async {
    await pump(tester);
    await startRecording(tester, run: const Duration(seconds: 1));
    await tester.tap(pill());
    await tester.pump();
    await tester.pump();
    expect(modal(), findsNothing);
    expect(recPhase(tester), LiveRecordingPhase.idle);
    expect(find.text('live_record_too_short'), findsOneWidget);
    expect(repo.saved, isEmpty);
    await finish(tester);
  });

  testWidgets('3초 이상 [녹화 중단] → 확인창: [아니요]=계속, [중단하기]=저장 토스트',
      (tester) async {
    await pump(tester);
    await startRecording(tester);
    await tester.tap(pill());
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    expect(find.text('live_record_stop_confirm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(modal(), findsNothing);
    expect(recPhase(tester), LiveRecordingPhase.recording);

    await tester.tap(pill());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveRecordControls.stopConfirmKey));
    await tester.pump();
    await tester.pump();
    expect(recPhase(tester), LiveRecordingPhase.idle);
    expect(repo.saved, hasLength(1));
    expect(find.text('live_record_saved'), findsOneWidget);
    expect(find.descendant(of: pill(), matching: find.text('live_record_start')),
        findsOneWidget);
    await finish(tester);
  });

  testWidgets('확인창이 떠 있는 사이 끊기면 창이 저절로 닫히고 부분 저장 안내',
      (tester) async {
    await pump(tester);
    await startRecording(tester);
    await tester.tap(pill());
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    live.set(const WebRtcLiveState(
        phase: WebRtcLivePhase.failed, errorKey: 'test_live_inert'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(modal(), findsNothing);
    expect(find.text('live_record_saved_partial'), findsOneWidget);
    expect(repo.saved, hasLength(1));
    expect(find.byType(CameraLiveFullscreenScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('확인창이 떠 있는 사이 2분이 되면 창이 닫히고 저장 완료', (tester) async {
    await pump(tester);
    await startRecording(tester);
    await tester.tap(pill());
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    // 5초 찍은 뒤라 1분 55초 더 가면 2분 — 토스트(2초)가 사라지기 전에 본다.
    await tester.pump(kLiveRecordingLength - const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(modal(), findsNothing);
    expect(repo.saved.single.durationMs, kLiveRecordingLength.inMilliseconds);
    expect(find.text('live_record_saved'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('녹화 중 X → 확인창: [아니요]면 남고, [중단하기]면 저장 후 나감',
      (tester) async {
    await pump(tester);
    await startRecording(tester);
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.closeButtonKey));
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(CameraLiveFullscreenScreen), findsOneWidget);
    expect(recPhase(tester), LiveRecordingPhase.recording);

    await tester.tap(find.byKey(CameraLiveFullscreenScreen.closeButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveRecordControls.stopConfirmKey));
    await tester.pumpAndSettle();
    expect(find.byType(CameraLiveFullscreenScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
    expect(repo.saved, hasLength(1));
    expect(find.text('live_record_saved'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('녹화 중 시스템 뒤로 → 같은 확인창, 녹화 아니면 바로 나감', (tester) async {
    await pump(tester);
    await startRecording(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    expect(find.byType(CameraLiveFullscreenScreen), findsOneWidget);
    await tester.tap(find.byKey(LiveRecordControls.stopConfirmKey));
    await tester.pumpAndSettle();
    expect(find.byType(CameraLiveFullscreenScreen), findsNothing);
    expect(repo.saved, hasLength(1));
    await finish(tester);
  });

  testWidgets('녹화 아닐 때 X는 확인 없이 나간다', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.closeButtonKey));
    await tester.pumpAndSettle();
    expect(modal(), findsNothing);
    expect(find.byType(CameraLiveFullscreenScreen), findsNothing);
    await finish(tester);
  });

  testWidgets('세로↔가로 전환해도 녹화가 이어진다(같은 녹화기)', (tester) async {
    await pump(tester);
    await startRecording(tester, run: const Duration(seconds: 2));
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.orientationButtonKey));
    await tester.binding.setSurfaceSize(const Size(852, 393));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(recPhase(tester), LiveRecordingPhase.recording);
    // 가로 알약: 112×48, 검정 + 올라가는 시간.
    expect(tester.getSize(pill()).height, 48);
    expect(find.descendant(of: pill(), matching: find.text('00:05')),
        findsOneWidget);
    expect(find.byKey(CameraLiveFullscreenScreen.rotateButtonKey), findsNothing);
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.orientationButtonKey));
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(recPhase(tester), LiveRecordingPhase.recording);
    expect(recorder.starts, 1);
    expect(recorder.stops, 0);
    await finish(tester);
  });

  testWidgets('가로 조작 버튼은 5초 뒤 사라지고(탭 안 받음) 화면을 누르면 다시 보인다',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.orientationButtonKey));
    await tester.binding.setSurfaceSize(const Size(852, 393));
    await tester.pump();
    await startRecording(tester, run: Duration.zero);
    double opacity() => tester
        .widget<FadeTransition>(
            find.byKey(CameraLiveFullscreenScreen.landscapeControlsKey))
        .opacity
        .value;
    expect(opacity(), 1);
    // 녹화 시작 탭도 터치 — 거기서 5초.
    await tester.pump(const Duration(seconds: 4));
    expect(opacity(), 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    expect(recPhase(tester), LiveRecordingPhase.recording, reason: '녹화는 계속');
    // 숨은 닫기를 눌러도 아무 일 없다(확인창 없음) — 대신 버튼이 다시 나온다.
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.closeButtonKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(modal(), findsNothing);
    expect(opacity(), 1);
    // 다시 5초 뒤 숨고, 빈 곳을 누르면 보인다.
    await tester.pump(kLiveLandscapeControlsHide);
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    await tester.tapAt(const Offset(426, 196));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    // 보이는 동안 누른 닫기는 확인창을 띄운다.
    await tester.tap(find.byKey(CameraLiveFullscreenScreen.closeButtonKey));
    await tester.pumpAndSettle();
    expect(modal(), findsOneWidget);
    await finish(tester);
  });
}
