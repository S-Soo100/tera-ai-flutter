// 카메라 재시작·Wi-Fi 약함 안내(petcam 요청서 2026-09-28).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivanaut/features/my_cage/data/device_health_repository.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/domain/sys_health.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/sys_health_controllers.dart';
import 'package:vivanaut/features/my_cage/presentation/device_detail_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/sys_health_widgets.dart';

const _cam = 'cam-1';
const SysTarget _camT = (PairTargetKind.camera, _cam);
const _dev = 'dev-1';
const SysTarget _devT = (PairTargetKind.device, _dev);

class _DeviceRepo implements DeviceHealthRepository {
  Object reboot_ = 'cmd-1'; // 명령 id 또는 던질 예외
  @override
  Future<String> reboot(String deviceUuid) async {
    final r = reboot_;
    if (r is Exception) throw r;
    return r as String;
  }

  @override
  Future<SysHealth> fetchHealth(String deviceUuid) async => SysHealth.empty;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 사육장 보고(3초) — [at]번째 보고.
SysHealth _d(
        {int? uptime,
        String? reset,
        int? rssi,
        int at = 0,
        bool present = true,
        bool online = true}) =>
    SysHealth(
        present: present,
        uptimeSeconds: uptime,
        resetReason: reset,
        rssi: rssi,
        isOnline: online,
        statsAt: DateTime.utc(2026, 9, 28, 12).add(Duration(seconds: 3 * at)));

class _Repo implements CameraRepository {
  Object? rebootResult = true; // bool 또는 던질 예외
  int reboots = 0;
  @override
  Future<bool> reboot(String cameraUuid) async {
    reboots++;
    final r = rebootResult;
    if (r is Exception) throw r;
    return r! as bool;
  }

  @override
  Future<SysHealth> fetchHealth(String cameraUuid) async => SysHealth.empty;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SysHealth _h({int? uptime, String? reset, int? rssi, int at = 0}) => SysHealth(
    present: true,
    uptimeSeconds: uptime,
    resetReason: reset,
    rssi: rssi,
    statsAt: DateTime.utc(2026, 9, 28, 12).add(Duration(seconds: 15 * at)));

void main() {
  group('펌웨어 판정', () {
    test('0.2.0 이상만 재시작을 안다 — 숫자로 비교', () {
      expect(isRebootCapableFirmware('fb2-p4 0.2.0-20260928'), isTrue);
      expect(isRebootCapableFirmware('fb2-p4 0.10.0'), isTrue);
      expect(isRebootCapableFirmware('fb2-p4 1.0.0'), isTrue);
      expect(isRebootCapableFirmware('fb2-p4 0.1.9'), isFalse);
      expect(isRebootCapableFirmware('fb2-p4 0.1.0'), isFalse);
      expect(isRebootCapableFirmware(null), isFalse);
      expect(isRebootCapableFirmware('unknown'), isFalse);
    });
  });

  group('clip_stats 파싱', () {
    test('구 펌웨어(rssi 없음)·키 없음·null도 던지지 않는다', () {
      final old = SysHealth.fromCameraRow({
        'clip_stats': {
          'sys': {'heap': 1, 'reset': 'PANIC', 'uptime_s': 125958}
        },
        'clip_stats_at': '2026-09-28T04:07:04Z',
      });
      expect(old.uptimeSeconds, 125958);
      expect(old.resetReason, 'PANIC');
      expect(old.rssi, isNull);
      expect(
          SysHealth.fromCameraRow({'clip_stats': null}).uptimeSeconds, isNull);
      expect(
          SysHealth.fromCameraRow({
            'clip_stats': {'sys': 'x'}
          }).rssi,
          isNull);
      expect(
          SysHealth.fromCameraRow({
            'clip_stats': {
              'sys': {'rssi': -80}
            }
          }).rssi,
          -80);
    });

    test('완료 = 가동 시간이 줄고 리셋 사유가 MQTT 재시작', () {
      expect(
          _h(uptime: 20, reset: kMqttRebootReason).rebootedSince(5000), isTrue);
      expect(_h(uptime: 20, reset: 'POWERON').rebootedSince(5000), isFalse);
      expect(_h(uptime: 6000, reset: kMqttRebootReason).rebootedSince(5000),
          isFalse);
      expect(
          _h(uptime: 20, reset: kMqttRebootReason).rebootedSince(null), isFalse,
          reason: '명령 전 값을 모르면 판정하지 않는다(2분 안내로)');
    });
  });

  group('Wi-Fi 약함 연속', () {
    test('−75 이하 서로 다른 heartbeat 4번이면 안내', () {
      final s = WeakSignalStreak(threshold: kWeakRssiStreakCamera);
      expect(s.add(_h(rssi: -80, at: 0)), isFalse);
      expect(s.add(_h(rssi: -75, at: 1)), isFalse);
      expect(s.add(_h(rssi: -90, at: 2)), isFalse);
      expect(s.add(_h(rssi: -76, at: 3)), isTrue);
    });
    // 보충 요청서 §3-1: 3번 연속 뒤 −74가 오면 초기화 — 배너 안 뜸.
    test('3번 연속 뒤 −74면 처음부터 — 그 뒤 3번으론 안 뜬다', () {
      final s = WeakSignalStreak(threshold: kWeakRssiStreakCamera);
      for (var i = 0; i < 3; i++) {
        expect(s.add(_h(rssi: -80, at: i)), isFalse);
      }
      expect(s.add(_h(rssi: -74, at: 3)), isFalse);
      expect(s.count, 0);
      for (var i = 4; i < 7; i++) {
        expect(s.add(_h(rssi: -80, at: i)), isFalse);
      }
      expect(s.add(_h(rssi: -80, at: 7)), isTrue);
    });

    test('같은 heartbeat 중복은 한 번, −74가 끼면 0부터', () {
      final s = WeakSignalStreak(threshold: kWeakRssiStreakCamera);
      s.add(_h(rssi: -80, at: 0));
      s.add(_h(rssi: -80, at: 0));
      s.add(_h(rssi: -80, at: 0));
      expect(s.count, 1);
      s.add(_h(rssi: -74, at: 1));
      expect(s.count, 0);
    });
    test('rssi가 없으면(구 펌웨어) 아무것도 하지 않는다', () {
      final s = WeakSignalStreak(threshold: kWeakRssiStreakCamera);
      s.add(_h(rssi: -80, at: 0));
      s.add(_h(at: 1));
      expect(s.count, 1);
    });
  });

  group('재시작 컨트롤러', () {
    late StreamController<SysHealth> health;
    late _Repo repo;
    late ProviderContainer container;
    setUp(() {
      health = StreamController<SysHealth>.broadcast();
      repo = _Repo();
      container = ProviderContainer(overrides: [
        sysHealthProvider(_camT).overrideWith((ref) => health.stream),
        cameraRepositoryProvider.overrideWithValue(repo),
      ]);
      container.listen(rebootProvider(_camT), (_, __) {});
    });
    tearDown(() {
      container.dispose();
      health.close();
    });
    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('발행되면 재시작 중, 완료 신호가 오면 완료', () async {
      health.add(_h(uptime: 5000, reset: 'POWERON'));
      await tick();
      final c = container.read(rebootProvider(_camT).notifier);
      expect(await c.request(), RebootRequest.published);
      expect(container.read(rebootProvider(_camT)).rebooting, isTrue);
      health.add(_h(uptime: 5015, reset: 'POWERON', at: 1)); // 아직 전
      await tick();
      expect(container.read(rebootProvider(_camT)).rebooting, isTrue);
      health.add(_h(uptime: 12, reset: kMqttRebootReason, at: 2));
      await tick();
      final s = container.read(rebootProvider(_camT));
      expect(s.rebooting, isFalse);
      expect(s.outcome, RebootOutcome.done);
      expect(s.coolingDown(DateTime.now()), isTrue, reason: '60초는 다시 못 누른다');
      expect(await c.request(), RebootRequest.notPublished);
      expect(repo.reboots, 1);
    });

    test('published=false면 바로 다시 누를 수 있다', () async {
      repo.rebootResult = false;
      final c = container.read(rebootProvider(_camT).notifier);
      expect(await c.request(), RebootRequest.notPublished);
      final s = container.read(rebootProvider(_camT));
      expect(
          s.rebooting || s.sending || s.coolingDown(DateTime.now()), isFalse);
    });

    test('404는 찾을 수 없음, 그 밖은 일반 실패', () async {
      final c = container.read(rebootProvider(_camT).notifier);
      repo.rebootResult = const TerraRestException(404, 'not found');
      expect(await c.request(), RebootRequest.notFound);
      repo.rebootResult = const TerraRestException(503, 'down');
      expect(await c.request(), RebootRequest.failed);
    });

    test('2분 동안 완료 신호가 없으면 시간 초과', () {
      fakeAsync((async) {
        final c = container.read(rebootProvider(_camT).notifier);
        c.request();
        async.flushMicrotasks();
        expect(container.read(rebootProvider(_camT)).rebooting, isTrue);
        async.elapse(kRebootTimeout - const Duration(seconds: 1));
        expect(container.read(rebootProvider(_camT)).rebooting, isTrue);
        async.elapse(const Duration(seconds: 1));
        final s = container.read(rebootProvider(_camT));
        expect(s.rebooting, isFalse);
        expect(s.outcome, RebootOutcome.timedOut);
      });
    });
  });

  group('Wi-Fi 약함 배너 컨트롤러', () {
    test('연속 4번이면 켜지고, 좋아져도 유지, 닫으면 이번 방문엔 다시 안 뜬다', () async {
      final health = StreamController<SysHealth>.broadcast();
      final container = ProviderContainer(overrides: [
        sysHealthProvider(_camT).overrideWith((ref) => health.stream),
      ]);
      addTearDown(() {
        container.dispose();
        health.close();
      });
      container.listen(weakWifiBannerProvider(_camT), (_, __) {});
      for (var i = 0; i < 4; i++) {
        health.add(_h(rssi: -80, at: i));
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(weakWifiBannerProvider(_camT)), isTrue);
      health.add(_h(rssi: -50, at: 4));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(weakWifiBannerProvider(_camT)), isTrue);
      container.read(weakWifiBannerProvider(_camT).notifier).dismiss();
      for (var i = 5; i < 10; i++) {
        health.add(_h(rssi: -80, at: i));
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(weakWifiBannerProvider(_camT)), isFalse);
    });
  });

  group('카메라 상세', () {
    Future<void> pump(WidgetTester tester, TerraCamera camera,
        {Stream<SysHealth>? health}) async {
      await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [
            managementInventoryProvider.overrideWith(
                (ref) async => ManagementInventory(groups: [], items: [
                      ManagementItem(
                          key: const ManagementKey(
                              kind: ManagementKind.camera, id: _cam),
                          name: camera.name)
                    ])),
            redesignGroupRepositoryProvider.overrideWith((ref) =>
                RedesignGroupRepository(
                    loadRows: (_) async => [], rpc: (_, __) async => null)),
            camerasProvider.overrideWith((ref) => Stream.value([camera])),
            sysHealthProvider(_camT)
                .overrideWith((ref) => health ?? Stream.value(SysHealth.empty)),
            cameraRepositoryProvider.overrideWithValue(_Repo()),
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              home: const DeviceDetailScreen(
                  kind: ManagementKind.camera, itemId: _cam))));
      await tester.pumpAndSettle();
    }

    TerraCamera cam({String? fw, bool online = true}) => TerraCamera(
        id: _cam,
        cameraId: 'p4cam',
        name: '카메라',
        firmwareVer: fw,
        isOnline: online,
        createdAt: DateTime(2026, 9, 28));

    testWidgets('구 펌웨어·오프라인·버전 모름이면 재시작 줄을 숨긴다', (tester) async {
      for (final c in [
        cam(fw: 'fb2-p4 0.1.0'),
        cam(fw: 'fb2-p4 0.2.0', online: false),
        cam(),
      ]) {
        await pump(tester, c);
        expect(find.byKey(RebootRow.rowKey), findsNothing);
        expect(find.byKey(WeakWifiBannerView.bannerKey), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('켜져 있는 0.2.0+이면 보이고, 누르면 먼저 확인한다', (tester) async {
      await pump(tester, cam(fw: 'fb2-p4 0.2.0-20260928'));
      final row = find.byKey(RebootRow.rowKey);
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reboot_ok')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reboot_ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reboot_progress')), findsOneWidget);
      // 2분 시간 초과 타이머가 남지 않게 정리한다.
      await tester.pumpWidget(const SizedBox());
    });

    // 보충 요청서 §3: 2분 안내는 정상 카메라로 재현이 안 돼 가짜 데이터로 본다.
    testWidgets('2분 동안 완료 신호가 없으면 전원 재연결 안내', (tester) async {
      final health = StreamController<SysHealth>.broadcast();
      addTearDown(health.close);
      await pump(tester, cam(fw: 'fb2-p4 0.2.0-20260928'),
          health: health.stream);
      health.add(_h(uptime: 5000, reset: 'POWERON'));
      await tester.pump();
      final row = find.byKey(RebootRow.rowKey);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reboot_ok')));
      await tester.pump();
      expect(find.byKey(const Key('reboot_progress')), findsOneWidget);
      // 재시작 전 값만 계속 온다(완료 신호 없음).
      health.add(_h(uptime: 5015, reset: 'POWERON', at: 1));
      await tester.pump(kRebootTimeout);
      await tester.pumpAndSettle();
      expect(find.text('camera_reboot_timeout'), findsOneWidget);
      expect(find.byKey(const Key('reboot_progress')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(kRebootCooldown);
    });

    testWidgets('완료 신호가 오면 "재시작 완료", 60초 동안 다시 못 누른다', (tester) async {
      final health = StreamController<SysHealth>.broadcast();
      addTearDown(health.close);
      await pump(tester, cam(fw: 'fb2-p4 0.2.0-20260928'),
          health: health.stream);
      health.add(_h(uptime: 5000, reset: 'POWERON'));
      await tester.pump();
      final row = find.byKey(RebootRow.rowKey);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reboot_ok')));
      await tester.pump();
      health.add(_h(uptime: 14, reset: kMqttRebootReason, at: 2));
      await tester.pump();
      await tester.pump();
      expect(find.text('reboot_done'), findsOneWidget);
      expect(tester.widget<InkWell>(row).onTap, isNull, reason: '60초 쿨다운');
      await tester.pump(kRebootCooldown);
      expect(tester.widget<InkWell>(row).onTap, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(kRebootTimeout);
    });

    testWidgets('약한 신호가 이어지면 상단 배너, 닫으면 사라진다', (tester) async {
      final health = StreamController<SysHealth>.broadcast();
      addTearDown(health.close);
      await pump(tester, cam(fw: 'fb2-p4 0.2.0'), health: health.stream);
      for (var i = 0; i < 4; i++) {
        health.add(_h(rssi: -82, at: i));
        await tester.pump();
      }
      expect(find.byKey(WeakWifiBannerView.bannerKey), findsOneWidget);
      await tester.tap(find.byKey(WeakWifiBannerView.closeKey));
      await tester.pump();
      expect(find.byKey(WeakWifiBannerView.bannerKey), findsNothing);
    });
  });

  // ── 사육장 기기(요청서 2026-09-28 device-reboot-rssi) ─────────────────────
  group('사육장 sys_state', () {
    test('sys_state null이면 없음(구 펌웨어), 있으면 값·is_online', () {
      final old = SysHealth.fromDeviceRow(
          {'sys_state': null, 'last_seen_at': '2026-09-28T04:00:00Z'});
      expect(old.present, isFalse);
      final now = SysHealth.fromDeviceRow({
        'sys_state': {
          'uptime_s': 42,
          'reset': 'POWERON',
          'rssi': -61,
          'heap': 1
        },
        'last_seen_at': '2026-09-28T04:00:03Z',
        'is_online': true,
      });
      expect(now.present, isTrue);
      expect(now.uptimeSeconds, 42);
      expect(now.rssi, -61);
      expect(now.isOnline, isTrue);
      expect(now.statsAt, DateTime.utc(2026, 9, 28, 4, 0, 3));
    });

    test('약함 20번 연속(약 1분)이면 안내 — 19번으론 안 뜬다', () {
      final s = WeakSignalStreak.forKind(PairTargetKind.device);
      for (var i = 0; i < 19; i++) {
        expect(s.add(_d(rssi: -80, at: i)), isFalse);
      }
      expect(s.add(_d(rssi: -80, at: 19)), isTrue);
    });

    test('중간에 −74·rssi 없는 보고가 오면 0부터, 같은 last_seen_at은 한 번', () {
      final s = WeakSignalStreak.forKind(PairTargetKind.device);
      for (var i = 0; i < 19; i++) {
        s.add(_d(rssi: -80, at: i));
      }
      s.add(_d(rssi: -74, at: 19));
      expect(s.count, 0);
      for (var i = 20; i < 30; i++) {
        s.add(_d(rssi: -80, at: i));
      }
      s.add(_d(at: 30)); // sys_state는 있는데 rssi만 없다
      expect(s.count, 0);
      s.add(_d(rssi: -80, at: 31));
      s.add(_d(rssi: -80, at: 31));
      s.add(_d(rssi: -80, at: 31));
      expect(s.count, 1);
      s.add(_d(present: false, at: 32)); // sys_state null — 아무것도 안 함
      expect(s.count, 1);
    });
  });

  group('사육장 재시작 컨트롤러', () {
    late StreamController<SysHealth> health;
    late StreamController<RebootCommandState?> command;
    late _DeviceRepo repo;
    late ProviderContainer container;
    setUp(() {
      health = StreamController<SysHealth>.broadcast();
      command = StreamController<RebootCommandState?>.broadcast();
      repo = _DeviceRepo();
      container = ProviderContainer(overrides: [
        sysHealthProvider(_devT).overrideWith((ref) => health.stream),
        rebootCommandProvider('cmd-1').overrideWith((ref) => command.stream),
        deviceHealthRepositoryProvider.overrideWithValue(repo),
      ]);
      container.listen(rebootProvider(_devT), (_, __) {});
    });
    tearDown(() {
      container.dispose();
      health.close();
      command.close();
    });
    Future<void> tick() => Future<void>.delayed(Duration.zero);
    RebootState state() => container.read(rebootProvider(_devT));
    Future<void> start() async {
      health.add(_d(uptime: 900, reset: 'POWERON'));
      await tick();
      expect(await container.read(rebootProvider(_devT).notifier).request(),
          RebootRequest.published);
      expect(state().rebooting, isTrue);
    }

    test('acked+ok는 재부팅 직전 — 계속 기다리고, 가동 시간이 줄면 완료', () async {
      await start();
      command.add((status: 'acked', result: 'ok'));
      await tick();
      expect(state().rebooting, isTrue, reason: 'ack는 재부팅 직전에 온다');
      health.add(_d(uptime: 5, reset: kMqttRebootReason, at: 1));
      await tick();
      expect(state().outcome, RebootOutcome.done);
      expect(state().rebooting, isFalse);
    });

    test('no_ack면 응답 없음', () async {
      await start();
      command.add((status: 'no_ack', result: null));
      await tick();
      expect(state().outcome, RebootOutcome.noAck);
    });

    test('acked여도 result가 unknown_action이면 펌웨어 업데이트 필요', () async {
      await start();
      command.add((status: 'acked', result: 'unknown_action'));
      await tick();
      expect(state().outcome, RebootOutcome.unsupported);
    });

    test('acked여도 그 밖의 result면 실패', () async {
      await start();
      command.add((status: 'acked', result: 'error'));
      await tick();
      expect(state().outcome, RebootOutcome.failed);
    });

    test('404는 찾을 수 없음', () async {
      repo.reboot_ = const TerraRestException(404, 'not found');
      expect(await container.read(rebootProvider(_devT).notifier).request(),
          RebootRequest.notFound);
      expect(state().rebooting, isFalse);
    });

    test('2분 동안 완료 신호가 없으면 시간 초과', () {
      fakeAsync((async) {
        container.read(rebootProvider(_devT).notifier).request();
        async.flushMicrotasks();
        command.add((status: 'acked', result: 'ok'));
        async.flushMicrotasks();
        async.elapse(kRebootTimeout);
        expect(state().outcome, RebootOutcome.timedOut);
      });
    });
  });

  group('사육장 기기 상세', () {
    Future<void> pump(WidgetTester tester, SysHealth health) async {
      await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [
            managementInventoryProvider.overrideWith((ref) async =>
                ManagementInventory(groups: [], items: [
                  const ManagementItem(
                      key: ManagementKey(kind: ManagementKind.device, id: _dev),
                      name: '사육장 1')
                ])),
            redesignGroupRepositoryProvider.overrideWith((ref) =>
                RedesignGroupRepository(
                    loadRows: (_) async => [], rpc: (_, __) async => null)),
            sysHealthProvider(_devT)
                .overrideWith((ref) => Stream.value(health)),
            deviceHealthRepositoryProvider.overrideWithValue(_DeviceRepo()),
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              home: const DeviceDetailScreen(
                  kind: ManagementKind.device, itemId: _dev))));
      await tester.pumpAndSettle();
    }

    testWidgets('sys_state가 없거나 오프라인이면 재시작 줄을 숨긴다', (tester) async {
      for (final h in [
        SysHealth.empty,
        _d(uptime: 10, online: false),
      ]) {
        await pump(tester, h);
        expect(find.byKey(RebootRow.rowKey), findsNothing);
        expect(find.byKey(WeakWifiBannerView.bannerKey), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('신 펌웨어·온라인이면 보이고, 확인창에 꺼짐·예약 안내가 붙는다', (tester) async {
      await pump(tester, _d(uptime: 10));
      final row = find.byKey(RebootRow.rowKey);
      expect(row, findsOneWidget);
      expect(find.text('device_reboot'), findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.textContaining('device_reboot_confirm'), findsOneWidget);
      expect(find.textContaining('device_reboot_schedule_note'),
          kDeviceRebootScheduleNote ? findsOneWidget : findsNothing);
    });
  });
}
