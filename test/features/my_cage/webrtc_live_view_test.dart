// 라이브 뷰 phase별 화면(2026-09-23 기획 §5). EasyLocalization을 띄우지 않아
// `.tr()`은 키를 그대로 돌려준다 — 문구가 아니라 **어느 키를 쓰는지**를 본다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivanaut/features/my_cage/domain/device_add_flow.dart';
import 'package:vivanaut/features/my_cage/domain/live_limit.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/sys_health.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/webrtc_live_view.dart';

const _cam = 'cam-1';

class _Fixed extends WebRtcLiveController {
  _Fixed(super.ref, super.cameraUuid, WebRtcLiveState s) {
    state = s;
  }
  int retries = 0;
  int takeovers = 0;
  int prompts = 0;
  @override
  Future<void> retry() async => retries++;
  @override
  Future<void> takeover() async => takeovers++;
  @override
  bool takeInUsePrompt() => prompts++ == 0;
  void set(WebRtcLiveState s) => state = s;
}

Future<_Fixed> _pump(WidgetTester tester, WebRtcLiveState s) async {
  late _Fixed c;
  await tester.pumpWidget(
    // 반복 호출마다 새 scope — 같은 scope면 provider가 재생성되지 않는다.
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        webrtcLiveControllerProvider(_cam)
            .overrideWith((ref) => c = _Fixed(ref, _cam, s)),
      ],
      child: const MaterialApp(
        home: SizedBox(
            width: 320, height: 180, child: WebRtcLiveView(cameraUuid: _cam)),
      ),
    ),
  );
  // shimmer는 무한 애니메이션 — pumpAndSettle 금지.
  await tester.pump();
  return c;
}

void main() {
  testWidgets('연결 단계 셋은 모두 "라이브 연결 중" 하나로 보인다', (tester) async {
    for (final p in [
      WebRtcLivePhase.connectingConfig,
      WebRtcLivePhase.offering,
      WebRtcLivePhase.connectingIce,
    ]) {
      await _pump(tester, WebRtcLiveState(phase: p));
      expect(find.text('crecam_live_connecting'), findsOneWidget,
          reason: p.name);
      expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
    }
  });

  testWidgets('첫 프레임 대기는 "영상을 불러오고 있어요"', (tester) async {
    await _pump(
        tester, const WebRtcLiveState(phase: WebRtcLivePhase.waitingVideo));
    expect(find.text('crecam_live_loading_video'), findsOneWidget);
  });

  testWidgets('recovering은 자동 복구 문구만, 버튼 없음', (tester) async {
    await _pump(
        tester, const WebRtcLiveState(phase: WebRtcLivePhase.recovering));
    expect(find.text('crecam_live_recovering'), findsOneWidget);
    expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
  });

  testWidgets('failed는 사유 + 다시 연결 버튼, 누르면 retry 한 번', (tester) async {
    final c = await _pump(
        tester,
        const WebRtcLiveState(
            phase: WebRtcLivePhase.failed,
            errorKey: 'crecam_live_error_camera_offline'));
    expect(find.text('crecam_live_error_camera_offline'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(WebRtcLiveView.retryButtonKey),
        matching: find.byType(OutlinedButton)));
    await tester.pump();
    expect(c.retries, 1);
  });

  test('영상 위 알약 — stalled 우선, 그다음 statsUnknown, 정상은 없음', () {
    expect(
        WebRtcLiveView.pillKeyFor(const WebRtcLiveState(
            phase: WebRtcLivePhase.stalled, statsUnknown: true)),
        'crecam_live_stalled');
    expect(
        WebRtcLiveView.pillKeyFor(const WebRtcLiveState(
            phase: WebRtcLivePhase.streaming, statsUnknown: true)),
        'crecam_live_stats_unknown');
    expect(
        WebRtcLiveView.pillKeyFor(
            const WebRtcLiveState(phase: WebRtcLivePhase.streaming)),
        isNull);
  });

  // 공유기를 바꿔 꺼진 카메라 — 지우지 않고 Wi-Fi만 바꾸는 길을 준다(2026-09-28).
  testWidgets('오프라인이면 [Wi-Fi 바꾸기]가 그 카메라를 대상으로 연다', (tester) async {
    Object? pushed;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: SizedBox(
                  width: 320,
                  height: 180,
                  child: WebRtcLiveView(cameraUuid: _cam)))),
      GoRoute(
          path: '/devices/wifi',
          builder: (_, state) {
            pushed = state.extra;
            return const SizedBox();
          }),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        webrtcLiveControllerProvider(_cam).overrideWith((ref) => _Fixed(
            ref,
            _cam,
            const WebRtcLiveState(
                phase: WebRtcLivePhase.failed,
                errorKey: 'crecam_live_error_camera_offline'))),
        camerasProvider.overrideWith((ref) => Stream.value([
              TerraCamera(
                  id: _cam,
                  cameraId: 'p4cam',
                  name: '카메라 2',
                  isOnline: false,
                  createdAt: DateTime(2026, 9, 8)),
            ])),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(WebRtcLiveView.wifiButtonKey));
    await tester.pumpAndSettle();
    expect(pushed, isA<WifiChangeTarget>());
    final target = pushed! as WifiChangeTarget;
    expect(target.kind, PairTargetKind.camera);
    expect(target.id, _cam);
    expect(target.name, '카메라 2');
  });

  testWidgets('오프라인이 아닌 실패엔 [Wi-Fi 바꾸기]가 없다', (tester) async {
    await _pump(
        tester,
        const WebRtcLiveState(
            phase: WebRtcLivePhase.failed,
            errorKey: 'crecam_live_error_no_video'));
    expect(find.byKey(WebRtcLiveView.wifiButtonKey), findsNothing);
  });

  // 리뷰(2026-09-28): 가로 전체화면에서 열면 Wi-Fi 바꾸기가 가로로 열린다.
  testWidgets('showWifiChange=false면 오프라인이어도 [Wi-Fi 바꾸기]가 없다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        webrtcLiveControllerProvider(_cam).overrideWith((ref) => _Fixed(
            ref,
            _cam,
            const WebRtcLiveState(
                phase: WebRtcLivePhase.failed,
                errorKey: 'crecam_live_error_camera_offline'))),
        camerasProvider.overrideWith((ref) => Stream.value([
              TerraCamera(
                  id: _cam,
                  cameraId: 'p4cam',
                  name: '카메라 2',
                  isOnline: false,
                  createdAt: DateTime(2026, 9, 8)),
            ])),
      ],
      child: const MaterialApp(
          home: SizedBox(
              width: 320,
              height: 180,
              child: WebRtcLiveView(cameraUuid: _cam, showWifiChange: false))),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(WebRtcLiveView.retryButtonKey), findsOneWidget);
    expect(find.byKey(WebRtcLiveView.wifiButtonKey), findsNothing);
  });

  // ── 시청 제한 (2026-09-30) ─────────────────────────────────────────────────

  Finder limitButton() => find.descendant(
      of: find.byKey(WebRtcLiveView.limitActionKey),
      matching: find.byType(OutlinedButton));

  testWidgets('다른 기기 시청 중 — 면 안내의 [이 기기로 시청]은 가져오기', (tester) async {
    final c = await _pump(
        tester,
        const WebRtcLiveState(
            phase: WebRtcLivePhase.limited,
            limit: LiveLimit(LiveLimitKind.inUse)));
    expect(find.text('crecam_live_in_use_surface'), findsOneWidget);
    expect(find.text('crecam_live_in_use_surface_detail'), findsOneWidget);
    await tester.tap(limitButton());
    await tester.pump();
    expect(c.takeovers, 1);
    expect(c.retries, 0);
  });

  testWidgets('409가 오면 확인 모달 — 이 기기로 시청이면 가져오기', (tester) async {
    final c = await _pump(
        tester, const WebRtcLiveState(phase: WebRtcLivePhase.offering));
    c.set(const WebRtcLiveState(
        phase: WebRtcLivePhase.limited,
        limit: LiveLimit(LiveLimitKind.inUse)));
    await tester.pump();
    await tester.pump();
    expect(find.text('crecam_live_in_use_title'), findsOneWidget);
    expect(find.text('crecam_live_in_use_body'), findsOneWidget);
    await tester.tap(find.byKey(const Key('viva_modal_confirm')));
    await tester.pump();
    expect(c.takeovers, 1);
  });

  testWidgets('확인 모달에서 취소하면 요청 없이 면 안내만 남는다', (tester) async {
    final c = await _pump(
        tester, const WebRtcLiveState(phase: WebRtcLivePhase.offering));
    c.set(const WebRtcLiveState(
        phase: WebRtcLivePhase.limited,
        limit: LiveLimit(LiveLimitKind.inUse)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('viva_modal_cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.takeovers, 0);
    expect(c.retries, 0);
    expect(find.text('crecam_live_in_use_title'), findsNothing);
    expect(find.text('crecam_live_in_use_surface'), findsOneWidget);
  });

  testWidgets('가져가짐 — 누가 가져갔는지 + 다시 보기(일반 요청)', (tester) async {
    final c = await _pump(
        tester,
        const WebRtcLiveState(
            phase: WebRtcLivePhase.limited,
            limit: LiveLimit(LiveLimitKind.takenOver)));
    expect(find.text('crecam_live_taken_over'), findsOneWidget);
    await tester.tap(limitButton());
    await tester.pump();
    expect(c.retries, 1);
    expect(c.takeovers, 0);
  });

  testWidgets('쉼 — 카운트다운 동안 버튼 없음, 끝나면 다시 보기', (tester) async {
    final c = await _pump(
        tester,
        WebRtcLiveState(
            phase: WebRtcLivePhase.limited,
            limit: LiveLimit(LiveLimitKind.cooldown,
                until: DateTime.now().add(const Duration(seconds: 3)))));
    expect(find.text('crecam_live_cooldown_title'), findsOneWidget);
    expect(find.text('crecam_live_cooldown_wait'), findsOneWidget);
    expect(limitButton(), findsNothing);
    // 가짜 시계는 DateTime.now()를 옮기지 않는다 — 실제 시간을 흘린다.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3100)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('crecam_live_watch_again'), findsOneWidget);
    await tester.tap(limitButton());
    await tester.pump();
    expect(c.retries, 1);
  });

  test('카운트다운 표기는 m:ss, 남은 조각 초는 올림', () {
    expect(formatCountdown(const Duration(seconds: 240)), '4:00');
    expect(formatCountdown(const Duration(milliseconds: 59100)), '1:00');
    expect(formatCountdown(const Duration(milliseconds: 8200)), '0:09');
    expect(formatCountdown(Duration.zero), '0:00');
  });

  // ── 카메라 재시작 (2026-10-03) ─────────────────────────────────────────────

  group('카메라 재시작', () {
    const newFw = 'fb2-p4 0.2.0-20260928';
    late _RebootRepo repo;
    setUp(() => repo = _RebootRepo());

    Future<void> pumpFailed(WidgetTester tester, String errorKey,
        {String? fw = newFw,
        bool online = true,
        bool showWifiChange = true}) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          webrtcLiveControllerProvider(_cam).overrideWith((ref) => _Fixed(
              ref,
              _cam,
              WebRtcLiveState(
                  phase: WebRtcLivePhase.failed, errorKey: errorKey))),
          camerasProvider.overrideWith((ref) => Stream.value([
                TerraCamera(
                    id: _cam,
                    cameraId: 'p4cam',
                    name: '카메라 2',
                    firmwareVer: fw,
                    isOnline: online,
                    createdAt: DateTime(2026, 9, 8)),
              ])),
          cameraRepositoryProvider.overrideWithValue(repo),
          sysHealthProvider(cameraRebootTarget(_cam))
              .overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SizedBox(
                    width: 360,
                    height: 220,
                    child: WebRtcLiveView(
                        cameraUuid: _cam, showWifiChange: showWifiChange)))),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('카메라 쪽이 멈춘 실패 3종 — 재시작할 수 있으면 버튼과 재시작 권유',
        (tester) async {
      for (final key in WebRtcLiveView.rebootErrorKeys) {
        await pumpFailed(tester, key);
        expect(find.byKey(WebRtcLiveView.rebootButtonKey), findsOneWidget,
            reason: key);
        expect(find.textContaining('crecam_live_hint_reboot'), findsOneWidget,
            reason: key);
        expect(find.byKey(WebRtcLiveView.retryButtonKey), findsOneWidget);
      }
    });

    testWidgets('가로 전체화면(Wi-Fi 버튼 끔)에서도 재시작 버튼은 있다', (tester) async {
      await pumpFailed(tester, 'crecam_live_error_unresponsive',
          showWifiChange: false);
      expect(find.byKey(WebRtcLiveView.rebootButtonKey), findsOneWidget);
    });

    testWidgets('구 펌웨어·버전 모름·오프라인 판정·망 실패엔 재시작 버튼이 없다', (tester) async {
      for (final (fw, online, key) in [
        ('fb2-p4 0.1.0', true, 'crecam_live_error_unresponsive'),
        (null, true, 'crecam_live_error_no_video'),
        (newFw, false, 'crecam_live_error_stalled'),
        (newFw, true, 'crecam_live_error_ice'),
        (newFw, false, 'crecam_live_error_camera_offline'),
      ]) {
        await pumpFailed(tester, key, fw: fw, online: online);
        expect(find.byKey(WebRtcLiveView.rebootButtonKey), findsNothing,
            reason: '$fw $online $key');
        expect(find.textContaining('crecam_live_hint_reboot'), findsNothing);
      }
    });

    testWidgets('누르면 먼저 확인하고, 확인하면 재시작을 한 번 보낸다', (tester) async {
      await pumpFailed(tester, 'crecam_live_error_unresponsive');
      await tester.tap(find.byKey(WebRtcLiveView.rebootButtonKey));
      await tester.pumpAndSettle();
      expect(repo.reboots, 0, reason: '확인 전엔 보내지 않는다');
      await tester.tap(find.byKey(const Key('reboot_ok')));
      await tester.pump();
      await tester.pump();
      expect(repo.reboots, 1);
      // 완료 대기 타이머(2분)를 흘려 정리한다.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(kRebootTimeout);
    });

    testWidgets('재시작 중엔 버튼 없이 안내만, 60초가 넘으면 "늦어지고 있어요"',
        (tester) async {
      for (final (slow, label) in [
        (false, 'crecam_live_rebooting'),
        (true, 'crecam_live_rebooting_slow'),
      ]) {
        await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [
            webrtcLiveControllerProvider(_cam).overrideWith((ref) => _Fixed(
                ref,
                _cam,
                const WebRtcLiveState(phase: WebRtcLivePhase.rebooting))),
            rebootProvider.overrideWith(() => _Rebooting(slow)),
          ],
          child: const MaterialApp(
              home: SizedBox(
                  width: 320,
                  height: 180,
                  child: WebRtcLiveView(cameraUuid: _cam))),
        ));
        await tester.pump();
        expect(find.text(label), findsOneWidget);
        expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
        expect(find.byKey(WebRtcLiveView.rebootButtonKey), findsNothing);
      }
    });
  });
}

class _RebootRepo extends Fake implements CameraRepository {
  int reboots = 0;
  @override
  Future<bool> reboot(String cameraUuid) async {
    reboots++;
    return true;
  }

  @override
  Future<SysHealth> fetchHealth(String cameraUuid) async => SysHealth.empty;
}

class _Rebooting extends RebootController {
  _Rebooting(this.slow);
  final bool slow;
  @override
  RebootState build(SysTarget target) =>
      RebootState(rebooting: true, slow: slow);
}
