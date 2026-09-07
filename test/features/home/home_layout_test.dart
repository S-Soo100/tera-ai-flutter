import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/home/domain/enclosure_set.dart';
import 'package:vivnanaut/features/home/domain/running_timer.dart';
import 'package:vivnanaut/features/home/presentation/env_detail_providers.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/home_screen.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/cage_control_grid.dart';
import 'package:vivnanaut/features/home/presentation/widgets/env_summary_card.dart';
import 'package:vivnanaut/features/home/presentation/widgets/home_header_bar.dart';
import 'package:vivnanaut/features/home/presentation/widgets/running_timer_chip.dart';
import 'package:vivnanaut/features/home/presentation/widgets/top_fixed_area.dart';
import 'package:vivnanaut/features/my_cage/domain/actuator_state.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivnanaut/features/my_cage/domain/telemetry_reading.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivnanaut/shared/domain/env_extremes.dart';

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

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        enclosureSetsProvider.overrideWith((ref) async => [_set()]),
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
  testWidgets('단일 스크롤 구성 — 헤더/라이브 자리/요약 카드/그리드/일정 설정',
      (tester) async {
    await _pump(tester);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
    // 캠 없는 세트 → 라이브 자리는 안내 한 줄로 접힌다.
    expect(find.byKey(TopFixedArea.noCameraLineKey), findsOneWidget);
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

  testWidgets('요약 카드 탭 → /env-detail', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(EnvSummaryCard.cardKey));
    await tester.pumpAndSettle();
    expect(find.text('env-detail-screen'), findsOneWidget);
  });

  testWidgets('미배선 타일(냉각팬) 탭 → SnackBar 안내', (tester) async {
    // 히터팬은 리뷰 2026-09-03에서 handleHeaterTap로 배선됐다 — 미배선
    // 검증은 냉각팬으로 한다(cage_control_grid_test에 히터 다이얼로그 검증).
    await _pump(tester);
    await tester.ensureVisible(find.byKey(CageControlGrid.coolFanKey));
    await tester.tap(find.byKey(CageControlGrid.coolFanKey));
    await tester.pump();
    expect(find.text('home_device_not_ready'), findsOneWidget);
  });

  testWidgets('일정 설정 로우 탭 → /home/routines', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.byKey(HomeScreen.scheduleRowKey));
    await tester.tap(find.byKey(HomeScreen.scheduleRowKey));
    await tester.pumpAndSettle();
    expect(find.text('routines-screen'), findsOneWidget);
  });
}
