import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/domain/running_timer.dart';
import 'package:vivanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/home_screen.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/cage_control_grid.dart';
import 'package:vivanaut/features/home/presentation/widgets/env_summary_card.dart';
import 'package:vivanaut/features/home/presentation/widgets/home_header_bar.dart';
import 'package:vivanaut/features/home/presentation/widgets/running_timer_chip.dart';
import 'package:vivanaut/features/home/presentation/widgets/top_fixed_area.dart';
import 'package:vivanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/shared/domain/env_extremes.dart';

const _deviceId = 'd-e1';

/// 캠 없는 세트 — WebRtcLiveView가 실피어 연결을 시도하지 않게 라이브 자리는
/// 접힌 상태(`home_no_camera` 한 줄)로 검증한다.
EnclosureSet _set() => EnclosureSet(
      enclosure:
          Enclosure(id: 'e1', name: '1번 사육장', createdAt: DateTime(2026, 1, 1)),
      device: Device(
        id: _deviceId,
        ownerId: 'u1',
        enclosureId: 'e1',
        name: 'terra-iot',
        isOnline: true,
        lastSeenAt: null,
      ),
      camera: null,
      pet: null,
    );

TelemetryReading _reading() => TelemetryReading(
      deviceId: _deviceId,
      tA: 28.5,
      hA: 62,
      aOk: true,
      tB: null,
      hB: null,
      bOk: false,
      relay: ActuatorState.off,
      fan: ActuatorState.off,
      heaterState: ActuatorState.off,
      heaterLocked: false,
      ts: DateTime(2026, 9, 2, 12),
    );

const _extremes = EnvExtremes(
  tempMin: 21.0,
  tempMax: 33.5,
  humidMin: 48.0,
  humidMax: 71.0,
);

/// 세트 재조립(의존 변경 → 다시 로딩)을 흉내 내는 방아쇠.
final _reloadTick = StateProvider<int>((ref) => 0);

Future<void> _pump(WidgetTester tester, {Completer<void>? reloadGate}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeDeviceSetsProvider.overrideWith((ref) async {
          // 첫 조립은 바로 끝나고, 방아쇠가 당겨진 뒤의 재조립만 gate에서 멈춘다.
          final tick = ref.watch(_reloadTick);
          if (tick > 0 && reloadGate != null) await reloadGate.future;
          return [_set()];
        }),
        currentUserProvider.overrideWithValue(null),
        currentDeviceIdProvider.overrideWith((ref) async => _deviceId),
        telemetryStreamProvider
            .overrideWith((ref, id) => Stream.value(_reading())),
        moduleOnlineProvider(_deviceId).overrideWithValue(true),
        homeTodayExtremesProvider.overrideWith((ref) async => _extremes),
        runningTimersProvider
            .overrideWith((ref) async => const <RunningTimer>[]),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/env-detail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('env-detail-screen'))),
        ),
        GoRoute(
          path: '/home/routines',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('routines-screen'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('profile-screen'))),
        ),
      ],
    );

void main() {
  testWidgets('단일 스크롤 구성 — 헤더/라이브 자리/요약 카드/그리드/기기 예약 설정', (tester) async {
    await _pump(tester);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
    // 캠 없는 세트 → 라이브 자리는 안내 한 줄로 접힌다.
    expect(find.byKey(TopFixedArea.noCameraLineKey), findsNothing);
    expect(find.byKey(EnvSummaryCard.cardKey), findsOneWidget);
    expect(find.byType(CageControlGrid), findsOneWidget);
    expect(find.byKey(CageControlGrid.ventFanKey), findsOneWidget);
    expect(find.byKey(CageControlGrid.ledKey), findsOneWidget);
    expect(find.byKey(HomeScreen.scheduleRowKey), findsOneWidget);
    // 서브탭·타임라인은 폐기됐다.
    expect(find.text('home_subtab_control'), findsNothing);
    expect(find.text('home_subtab_timeline'), findsNothing);
    // 타이머 없음 → 칩 비노출.
    expect(find.byKey(RunningTimerChip.chipKey), findsNothing);
  });

  testWidgets('세트가 다시 조립되는 동안 본문을 스켈레톤으로 갈아 끼우지 않는다', (tester) async {
    // 회귀(2026-09-19 실기기): 카메라 생존 신호(15초)마다 세트가 재조립되며
    // 홈 본문 전체가 한 프레임 회색 스켈레톤으로 바뀌고 라이브·스크롤이 철거됐다.
    final gate = Completer<void>();
    await _pump(tester, reloadGate: gate);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

    container.read(_reloadTick.notifier).state = 1;
    await tester.pump();

    expect(container.read(homeDeviceSetsProvider).isLoading, isTrue);
    expect(find.byKey(EnvSummaryCard.cardKey), findsOneWidget);
    expect(find.byType(CageControlGrid), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(EnvSummaryCard.cardKey), findsOneWidget);
  });

  testWidgets('요약 카드 탭 → /env-detail', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(EnvSummaryCard.cardKey));
    await tester.pumpAndSettle();
    expect(find.text('env-detail-screen'), findsOneWidget);
  });

  testWidgets('fan2 미보고 냉각팬은 제어 명령을 보내지 않는다', (tester) async {
    // 히터팬은 리뷰 2026-09-03에서 handleHeaterTap로 배선됐다 — 미배선
    // 검증은 냉각팬으로 한다(cage_control_grid_test에 히터 다이얼로그 검증).
    await _pump(tester);
    await tester.ensureVisible(find.byKey(CageControlGrid.coolFanKey));
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('home_device_not_ready'), findsNothing);
    expect(find.text('home_fan_duration_title'), findsNothing);
  });

  testWidgets('기기 예약 설정 로우 탭 → /home/routines', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.byKey(HomeScreen.scheduleRowKey));
    await tester.tap(find.byKey(HomeScreen.scheduleRowKey));
    await tester.pumpAndSettle();
    expect(find.text('routines-screen'), findsOneWidget);
  });
}
