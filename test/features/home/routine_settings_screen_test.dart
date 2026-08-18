import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/data/schedule_repository.dart';
import 'package:vivnanaut/features/home/domain/schedule.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/routine_settings_screen.dart';
import 'package:vivnanaut/features/home/presentation/schedule_providers.dart';

/// 네트워크를 타지 않는 대역. 호출 기록을 남겨 "정말 서버에 갔는가"를 본다.
class _FakeRepo implements ScheduleRepository {
  _FakeRepo({this.items = const [], this.failOnPatch = false});

  List<Schedule> items;
  final bool failOnPatch;
  final List<String> calls = [];

  @override
  Future<List<Schedule>> list(String deviceId) async {
    calls.add('list');
    return items;
  }

  @override
  Future<Schedule> patch(String id, Map<String, dynamic> changes) async {
    calls.add('patch:$id:$changes');
    if (failOnPatch) throw const ScheduleException(500, 'boom');
    final s = items.firstWhere((e) => e.id == id);
    return s.copyWith(enabled: changes['enabled'] as bool? ?? s.enabled);
  }

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');

  @override
  Future<Schedule> create(String deviceId,
      {required ScheduleAction action,
      required ScheduleKind kind,
      required int hour,
      required int minute,
      required List<int> daysOfWeek,
      Map<String, dynamic>? payload,
      ScheduleGuard? guard,
      String? pairId}) async {
    calls.add('create:${action.wire}:'
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        ':d=${daysOfWeek.join(',')}'
        '${guard == null ? '' : ':guard=${guard.type.wire}>${guard.value}'}');
    pairIds.add(pairId);
    return _schedule(id: 'new-${calls.length}', pairId: pairId);
  }

  /// create마다 받은 pair_id(시점 예약이면 null).
  final List<String?> pairIds = [];
}

Schedule _schedule({
  String id = 's1',
  bool enabled = true,
  ScheduleAction action = ScheduleAction.mist,
  ScheduleKind kind = ScheduleKind.daily,
  List<int> days = const [],
  ScheduleGuard? guard,
  String? pairId,
  int hour = 8,
  int minute = 0,
}) =>
    Schedule(
      id: id,
      deviceId: 'd1',
      action: action,
      payload: const {'duration_ms': 2000},
      kind: kind,
      hour: hour,
      minute: minute,
      daysOfWeek: days,
      enabled: enabled,
      guard: guard,
      pairId: pairId,
      nextRunAt: null,
      lastRunAt: null,
    );

/// EasyLocalization을 세우지 않는다 — 이 레포의 다른 위젯 테스트와 같은 방식으로,
/// `.tr()`이 키를 그대로 돌려주는 상태에서 구조만 본다. 번역 로드는 프레임을
/// 더 먹어서 여러 테스트가 같은 프로세스에서 돌 때 트리가 비어버린다.
Future<void> _pump(WidgetTester tester, _FakeRepo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(repo),
        currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
      ],
      child: const MaterialApp(home: RoutineSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {

  testWidgets('예약 목록을 보여준다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'a'),
      _schedule(id: 'b', action: ScheduleAction.fanToggle),
    ]);
    await _pump(tester, repo);

    expect(find.byKey(const Key('schedule_a')), findsOneWidget);
    expect(find.byKey(const Key('schedule_b')), findsOneWidget);
    expect(repo.calls, contains('list'));
  });

  testWidgets('예약이 없으면 비어 있다고 밝힌다 — 빈 화면은 고장으로 읽힌다',
      (tester) async {
    await _pump(tester, _FakeRepo());
    expect(find.text('routine_schedule_empty'.tr()), findsOneWidget);
  });

  testWidgets('펌웨어 대기(정지형 가드·히터 타이머)는 각주로 이유를 밝힌다',
      (tester) async {
    await _pump(tester, _FakeRepo());
    expect(
        find.byKey(RoutineSettingsScreen.pendingFootnoteKey), findsOneWidget);
  });

  testWidgets('가드를 걸어 저장하면 서버 요청에 실린다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
        find.byKey(const Key('routine_guard_skip_when_humidity_above')));
    await tester.tap(
        find.byKey(const Key('routine_guard_skip_when_humidity_above')));
    await tester.pumpAndSettle();
    // 종류를 고르면 유효한 출발값(70)이 채워져 저장이 열려야 한다.
    await tester.ensureVisible(find.byKey(const Key('routine_save')));
    await tester.tap(find.byKey(const Key('routine_save')));
    await tester.pumpAndSettle();

    expect(
      repo.calls.any(
          (c) => c.startsWith('create:mist') && c.contains('guard=skip_when_humidity_above>70')),
      isTrue,
      reason: '실제 호출: ${repo.calls}',
    );
  });

  testWidgets('구간 저장은 on/off 예약 2건을 만든다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);

    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('routine_mode_span'.tr()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('routine_save')));
    await tester.tap(find.byKey(const Key('routine_save')));
    await tester.pumpAndSettle();

    final creates = repo.calls.where((c) => c.startsWith('create:')).toList();
    expect(creates, hasLength(2), reason: '실제 호출: ${repo.calls}');
    expect(creates[0], startsWith('create:fan_on:08:00'));
    expect(creates[1], startsWith('create:fan_off:22:00'));
    // 2026-08-18 회신 §3 — 두 행이 같은 pair_id를 갖는다.
    expect(repo.pairIds, hasLength(2));
    expect(repo.pairIds[0], isNotNull);
    expect(repo.pairIds[0], repo.pairIds[1]);
  });

  testWidgets('시점 예약은 pair_id를 싣지 않는다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('routine_save')));
    await tester.tap(find.byKey(const Key('routine_save')));
    await tester.pumpAndSettle();
    expect(repo.pairIds, [null]);
  });

  testWidgets('같은 pair_id의 on/off는 목록에 한 줄로 묶인다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.heaterOn, hour: 20, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.heaterOff, hour: 6, pairId: 'p1'),
      _schedule(id: 'solo'),
    ]);
    await _pump(tester, repo);
    expect(find.byKey(const Key('schedule_pair_p1')), findsOneWidget);
    expect(find.byKey(const Key('schedule_on')), findsNothing);
    expect(find.byKey(const Key('schedule_off')), findsNothing);
    expect(find.byKey(const Key('schedule_solo')), findsOneWidget);
    expect(find.textContaining('20:00 → 06:00'), findsOneWidget);
  });

  testWidgets('구간 삭제는 한 건만 DELETE — 서버가 짝을 같이 지운다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_delete_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_delete_pair_body')), findsOneWidget);
    await tester.tap(find.text('routine_delete_confirm'.tr()));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('delete:')), ['delete:on']);
    expect(find.byKey(const Key('schedule_pair_p1')), findsNothing);
  });

  testWidgets('구간 토글은 두 행을 같이 바꾼다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_toggle_p1')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('patch:')).toList(), [
      'patch:on:{enabled: false}',
      'patch:off:{enabled: false}',
    ]);
  });

  testWidgets('구간 편집은 시작·종료를 다 고치고 두 행을 PATCH한다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, hour: 8, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, hour: 20, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_p1')));
    await tester.pumpAndSettle();
    // 편집 모드: 구간 UI가 그대로 뜨고 종료 시각 행이 있다.
    expect(find.byKey(const Key('routine_pick_end_time')), findsOneWidget);
    expect(find.text('routine_mode_span'.tr()), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('routine_save')));
    await tester.tap(find.byKey(const Key('routine_save')));
    await tester.pumpAndSettle();
    final patches = repo.calls.where((c) => c.startsWith('patch:')).toList();
    expect(patches, hasLength(2), reason: '실제 호출: ${repo.calls}');
    expect(patches[0], startsWith('patch:on:'));
    expect(patches[0], contains('time_of_day: 08:00'));
    expect(patches[1], startsWith('patch:off:'));
    expect(patches[1], contains('time_of_day: 20:00'));
  });

  testWidgets('구간에서 히터를 고르면 무인 가동 경고를 보여준다', (tester) async {
    await _pump(tester, _FakeRepo());

    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('routine_mode_span'.tr()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routine_span_heater_warn')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('routine_span_heater')));
    await tester.tap(find.byKey(const Key('routine_span_heater')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_span_heater_warn')), findsOneWidget);
  });

  testWidgets('수정에서는 구간 탭이 없다 — 서버가 action 수정을 안 받고 쌍 개념도 없다',
      (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a')]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();

    expect(find.text('routine_mode_span'.tr()), findsNothing);
  });

  test('addSpan: weekly + 자정 넘김이면 off 요일이 하루 밀린다', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      scheduleRepositoryProvider.overrideWithValue(repo),
      currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(schedulesProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(schedulesProvider.future);

    await container.read(schedulesProvider.notifier).addSpan(
          onAction: ScheduleAction.heaterOn,
          offAction: ScheduleAction.heaterOff,
          kind: ScheduleKind.weekly,
          startHour: 22,
          startMinute: 0,
          endHour: 6,
          endMinute: 0,
          daysOfWeek: const [1, 7],
        );

    final creates = repo.calls.where((c) => c.startsWith('create:')).toList();
    expect(creates, hasLength(2));
    expect(creates[0], contains('heater_on:22:00:d=1,7'));
    // off는 다음날 새벽 — 월→화, 일→월.
    expect(creates[1], contains('heater_off:06:00:d=1,2'));
  });

  test('addSpan: 자정을 안 넘으면 off 요일 그대로', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(overrides: [
      scheduleRepositoryProvider.overrideWithValue(repo),
      currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(schedulesProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(schedulesProvider.future);

    await container.read(schedulesProvider.notifier).addSpan(
          onAction: ScheduleAction.fanOn,
          offAction: ScheduleAction.fanOff,
          kind: ScheduleKind.weekly,
          startHour: 8,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
          daysOfWeek: const [3],
        );

    final creates = repo.calls.where((c) => c.startsWith('create:')).toList();
    expect(creates[1], contains('fan_off:20:00:d=3'));
  });

  testWidgets('끄기 예약 삭제 시 켜기 짝이 남으면 경고를 바꾼다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on1', action: ScheduleAction.heaterOn),
      _schedule(id: 'off1', action: ScheduleAction.heaterOff),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_delete_off1')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('routine_delete_off_warning')), findsOneWidget);
  });

  testWidgets('켜기 예약 삭제는 평범한 확인 문구다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on1', action: ScheduleAction.heaterOn),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_delete_on1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routine_delete_off_warning')), findsNothing);
    expect(find.text('routine_delete_body'.tr()), findsOneWidget);
  });

  testWidgets('끄기 예약 수정에는 가드 섹션이 없다 — off는 무조건 꺼져야 안전',
      (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'off1', action: ScheduleAction.heaterOff),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_off1')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('routine_guard_not_for_off')), findsOneWidget);
    expect(find.byKey(const Key('routine_guard_off')), findsNothing);
  });

  testWidgets('가드를 안 건드린 수정은 PATCH에 guard를 싣지 않는다 — enabled:false 보존',
      (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(
        id: 'a',
        guard: const ScheduleGuard(
            type: GuardType.humidityAbove, value: 70, enabled: false),
      ),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('routine_save')));
    await tester.tap(find.byKey(const Key('routine_save')));
    await tester.pumpAndSettle();

    final patch = repo.calls.firstWhere((c) => c.startsWith('patch:a'));
    expect(patch.contains('guard'), isFalse,
        reason: '안 건드렸으면 키 생략 — 서버의 enabled:false가 유지돼야 한다: $patch');
  });

  testWidgets('가드 단위를 바꾸면 기준값이 새 기본값으로 리셋된다 — 70%가 70°C로 남지 않게',
      (tester) async {
    await _pump(tester, _FakeRepo());

    await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
        find.byKey(const Key('routine_guard_skip_when_humidity_above')));
    await tester.tap(
        find.byKey(const Key('routine_guard_skip_when_humidity_above')));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const Key('routine_guard_skip_when_temp_above')));
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byKey(const Key('routine_guard_value')));
    expect(field.controller!.text, '30');
  });

  testWidgets('레거시 toggle 예약도 수정 시트에 잠긴 칩으로 보인다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'a', action: ScheduleAction.fanToggle),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('routine_action_fan_toggle')));
    expect(chip.selected, isTrue);
    expect(chip.onSelected, isNull, reason: '수정 중엔 잠긴다');
  });

  testWidgets('토글은 서버에 반영한다', (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a', enabled: true)]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_toggle_a')));
    await tester.pumpAndSettle();

    expect(repo.calls.any((c) => c.startsWith('patch:a')), isTrue);
  });

  testWidgets('토글이 실패하면 켜진 것처럼 두지 않는다 — 안 도는 예약을 믿게 하면 안 된다',
      (tester) async {
    final repo = _FakeRepo(
      items: [_schedule(id: 'a', enabled: false)],
      failOnPatch: true,
    );
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_toggle_a')));
    await tester.pumpAndSettle();

    final sw = tester.widget<Switch>(find.byKey(const Key('schedule_toggle_a')));
    expect(sw.value, isFalse, reason: '실패했으므로 꺼진 채여야 한다');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('삭제는 확인을 받는다 — 되돌릴 수 없다', (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a')]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_delete_a')));
    await tester.pumpAndSettle();
    expect(find.text('routine_delete_title'.tr()), findsOneWidget);

    // 취소하면 아무 일도 없어야 한다.
    await tester.tap(find.text('common_cancel'.tr()));
    await tester.pumpAndSettle();
    expect(repo.calls.any((c) => c.startsWith('delete')), isFalse);
  });
}
