// 카메라 재시작·Wi-Fi 약함 안내(petcam 요청서 2026-09-28).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/my_cage/data/camera_repository.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_cage/domain/camera_health.dart';
import 'package:vivanaut/features/my_cage/domain/redesign_management.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivanaut/features/my_cage/presentation/camera_health_controllers.dart';
import 'package:vivanaut/features/my_cage/presentation/device_detail_screen.dart';
import 'package:vivanaut/features/my_cage/presentation/device_management_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/camera_health_widgets.dart';

const _cam = 'cam-1';

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
  Future<CameraHealth> fetchHealth(String cameraUuid) async =>
      CameraHealth.empty;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CameraHealth _h({int? uptime, String? reset, int? rssi, int at = 0}) =>
    CameraHealth(
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
      final old = CameraHealth.fromRow({
        'clip_stats': {
          'sys': {'heap': 1, 'reset': 'PANIC', 'uptime_s': 125958}
        },
        'clip_stats_at': '2026-09-28T04:07:04Z',
      });
      expect(old.uptimeSeconds, 125958);
      expect(old.resetReason, 'PANIC');
      expect(old.rssi, isNull);
      expect(CameraHealth.fromRow({'clip_stats': null}).uptimeSeconds, isNull);
      expect(
          CameraHealth.fromRow({
            'clip_stats': {'sys': 'x'}
          }).rssi,
          isNull);
      expect(
          CameraHealth.fromRow({
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
      final s = WeakSignalStreak();
      expect(s.add(_h(rssi: -80, at: 0)), isFalse);
      expect(s.add(_h(rssi: -75, at: 1)), isFalse);
      expect(s.add(_h(rssi: -90, at: 2)), isFalse);
      expect(s.add(_h(rssi: -76, at: 3)), isTrue);
    });
    // 보충 요청서 §3-1: 3번 연속 뒤 −74가 오면 초기화 — 배너 안 뜸.
    test('3번 연속 뒤 −74면 처음부터 — 그 뒤 3번으론 안 뜬다', () {
      final s = WeakSignalStreak();
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
      final s = WeakSignalStreak();
      s.add(_h(rssi: -80, at: 0));
      s.add(_h(rssi: -80, at: 0));
      s.add(_h(rssi: -80, at: 0));
      expect(s.count, 1);
      s.add(_h(rssi: -74, at: 1));
      expect(s.count, 0);
    });
    test('rssi가 없으면(구 펌웨어) 아무것도 하지 않는다', () {
      final s = WeakSignalStreak();
      s.add(_h(rssi: -80, at: 0));
      s.add(_h(at: 1));
      expect(s.count, 1);
    });
  });

  group('재시작 컨트롤러', () {
    late StreamController<CameraHealth> health;
    late _Repo repo;
    late ProviderContainer container;
    setUp(() {
      health = StreamController<CameraHealth>.broadcast();
      repo = _Repo();
      container = ProviderContainer(overrides: [
        cameraHealthProvider(_cam).overrideWith((ref) => health.stream),
        cameraRepositoryProvider.overrideWithValue(repo),
      ]);
      container.listen(cameraRebootProvider(_cam), (_, __) {});
    });
    tearDown(() {
      container.dispose();
      health.close();
    });
    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('발행되면 재시작 중, 완료 신호가 오면 완료', () async {
      health.add(_h(uptime: 5000, reset: 'POWERON'));
      await tick();
      final c = container.read(cameraRebootProvider(_cam).notifier);
      expect(await c.request(), CameraRebootRequest.published);
      expect(container.read(cameraRebootProvider(_cam)).rebooting, isTrue);
      health.add(_h(uptime: 5015, reset: 'POWERON', at: 1)); // 아직 전
      await tick();
      expect(container.read(cameraRebootProvider(_cam)).rebooting, isTrue);
      health.add(_h(uptime: 12, reset: kMqttRebootReason, at: 2));
      await tick();
      final s = container.read(cameraRebootProvider(_cam));
      expect(s.rebooting, isFalse);
      expect(s.outcome, CameraRebootOutcome.done);
      expect(s.coolingDown(DateTime.now()), isTrue, reason: '60초는 다시 못 누른다');
      expect(await c.request(), CameraRebootRequest.notPublished);
      expect(repo.reboots, 1);
    });

    test('published=false면 바로 다시 누를 수 있다', () async {
      repo.rebootResult = false;
      final c = container.read(cameraRebootProvider(_cam).notifier);
      expect(await c.request(), CameraRebootRequest.notPublished);
      final s = container.read(cameraRebootProvider(_cam));
      expect(
          s.rebooting || s.sending || s.coolingDown(DateTime.now()), isFalse);
    });

    test('404는 찾을 수 없음, 그 밖은 일반 실패', () async {
      final c = container.read(cameraRebootProvider(_cam).notifier);
      repo.rebootResult = const TerraRestException(404, 'not found');
      expect(await c.request(), CameraRebootRequest.notFound);
      repo.rebootResult = const TerraRestException(503, 'down');
      expect(await c.request(), CameraRebootRequest.failed);
    });

    test('2분 동안 완료 신호가 없으면 시간 초과', () {
      fakeAsync((async) {
        final c = container.read(cameraRebootProvider(_cam).notifier);
        c.request();
        async.flushMicrotasks();
        expect(container.read(cameraRebootProvider(_cam)).rebooting, isTrue);
        async.elapse(kRebootTimeout - const Duration(seconds: 1));
        expect(container.read(cameraRebootProvider(_cam)).rebooting, isTrue);
        async.elapse(const Duration(seconds: 1));
        final s = container.read(cameraRebootProvider(_cam));
        expect(s.rebooting, isFalse);
        expect(s.outcome, CameraRebootOutcome.timedOut);
      });
    });
  });

  group('Wi-Fi 약함 배너 컨트롤러', () {
    test('연속 4번이면 켜지고, 좋아져도 유지, 닫으면 이번 방문엔 다시 안 뜬다', () async {
      final health = StreamController<CameraHealth>.broadcast();
      final container = ProviderContainer(overrides: [
        cameraHealthProvider(_cam).overrideWith((ref) => health.stream),
      ]);
      addTearDown(() {
        container.dispose();
        health.close();
      });
      container.listen(weakWifiBannerProvider(_cam), (_, __) {});
      for (var i = 0; i < 4; i++) {
        health.add(_h(rssi: -80, at: i));
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(weakWifiBannerProvider(_cam)), isTrue);
      health.add(_h(rssi: -50, at: 4));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(weakWifiBannerProvider(_cam)), isTrue);
      container.read(weakWifiBannerProvider(_cam).notifier).dismiss();
      for (var i = 5; i < 10; i++) {
        health.add(_h(rssi: -80, at: i));
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(weakWifiBannerProvider(_cam)), isFalse);
    });
  });

  group('카메라 상세', () {
    Future<void> pump(WidgetTester tester, TerraCamera camera,
        {Stream<CameraHealth>? health}) async {
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
            cameraHealthProvider(_cam).overrideWith(
                (ref) => health ?? Stream.value(CameraHealth.empty)),
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
        expect(find.byKey(CameraRebootRow.rowKey), findsNothing);
        expect(find.byKey(WeakWifiBannerView.bannerKey), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('켜져 있는 0.2.0+이면 보이고, 누르면 먼저 확인한다', (tester) async {
      await pump(tester, cam(fw: 'fb2-p4 0.2.0-20260928'));
      final row = find.byKey(CameraRebootRow.rowKey);
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('camera_reboot_ok')), findsOneWidget);
      await tester.tap(find.byKey(const Key('camera_reboot_ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('camera_reboot_progress')), findsOneWidget);
      // 2분 시간 초과 타이머가 남지 않게 정리한다.
      await tester.pumpWidget(const SizedBox());
    });

    // 보충 요청서 §3: 2분 안내는 정상 카메라로 재현이 안 돼 가짜 데이터로 본다.
    testWidgets('2분 동안 완료 신호가 없으면 전원 재연결 안내', (tester) async {
      final health = StreamController<CameraHealth>.broadcast();
      addTearDown(health.close);
      await pump(tester, cam(fw: 'fb2-p4 0.2.0-20260928'),
          health: health.stream);
      health.add(_h(uptime: 5000, reset: 'POWERON'));
      await tester.pump();
      final row = find.byKey(CameraRebootRow.rowKey);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('camera_reboot_ok')));
      await tester.pump();
      expect(find.byKey(const Key('camera_reboot_progress')), findsOneWidget);
      // 재시작 전 값만 계속 온다(완료 신호 없음).
      health.add(_h(uptime: 5015, reset: 'POWERON', at: 1));
      await tester.pump(kRebootTimeout);
      await tester.pumpAndSettle();
      expect(find.text('camera_reboot_timeout'), findsOneWidget);
      expect(find.byKey(const Key('camera_reboot_progress')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(kRebootCooldown);
    });

    testWidgets('완료 신호가 오면 "재시작 완료", 60초 동안 다시 못 누른다', (tester) async {
      final health = StreamController<CameraHealth>.broadcast();
      addTearDown(health.close);
      await pump(tester, cam(fw: 'fb2-p4 0.2.0-20260928'),
          health: health.stream);
      health.add(_h(uptime: 5000, reset: 'POWERON'));
      await tester.pump();
      final row = find.byKey(CameraRebootRow.rowKey);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('camera_reboot_ok')));
      await tester.pump();
      health.add(_h(uptime: 14, reset: kMqttRebootReason, at: 2));
      await tester.pump();
      await tester.pump();
      expect(find.text('camera_reboot_done'), findsOneWidget);
      expect(tester.widget<InkWell>(row).onTap, isNull, reason: '60초 쿨다운');
      await tester.pump(kRebootCooldown);
      expect(tester.widget<InkWell>(row).onTap, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(kRebootTimeout);
    });

    testWidgets('약한 신호가 이어지면 상단 배너, 닫으면 사라진다', (tester) async {
      final health = StreamController<CameraHealth>.broadcast();
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
}
