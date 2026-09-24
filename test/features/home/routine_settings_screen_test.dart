import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/data/schedule_repository.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart';
import 'package:vivanaut/features/home/presentation/schedule_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/schedule_editor_sheet.dart'
    show ScheduleChoiceChip;

/// 네트워크를 타지 않는 대역. 호출 기록을 남겨 "정말 서버에 갔는가"를 본다.
class _FakeRepo implements ScheduleRepository {
  _FakeRepo({
    this.items = const [],
    this.failOnPatch = false,
    this.failPatchIds = const {},
    this.cascadeDelete = true,
    this.echoPairId = true,
    this.failDeleteIds = const {},
  });

  /// 이 id의 DELETE만 실패시킨다 — 다중 삭제 부분 실패 재현.
  final Set<String> failDeleteIds;

  List<Schedule> items;
  final bool failOnPatch;

  /// 이 id의 PATCH만 실패시킨다 — 두 행 중 하나만 실패하는 부분 실패 재현.
  final Set<String> failPatchIds;

  /// 서버가 pair_id 짝을 함께 지우는가(회신 §3). false면 구버전 서버.
  final bool cascadeDelete;

  /// PATCH 응답이 pair_id를 돌려주는가. false면 바뀐 컬럼만 주는 서버.
  final bool echoPairId;
  final List<String> calls = [];

  @override
  Future<List<Schedule>> list(String deviceId) async {
    calls.add('list');
    return items;
  }

  /// 서버처럼 바뀐 값을 **적용해서** 돌려준다 — 화면이 stale 값을 그리면
  /// 테스트가 잡아야 한다.
  @override
  Future<Schedule> patch(String id, Map<String, dynamic> changes) async {
    calls.add('patch:$id:$changes');
    if (failOnPatch || failPatchIds.contains(id)) {
      throw const ScheduleException(500, 'boom');
    }
    final s = items.firstWhere((e) => e.id == id);
    final tod = changes['time_of_day'] as String?;
    final parts = tod?.split(':');
    final updated = Schedule(
      id: s.id,
      deviceId: s.deviceId,
      action: s.action,
      payload:
          (changes['payload'] as Map?)?.cast<String, dynamic>() ?? s.payload,
      kind: changes.containsKey('kind')
          ? ScheduleKind.fromWire(changes['kind'] as String?)
          : s.kind,
      hour: parts == null ? s.hour : int.parse(parts[0]),
      minute: parts == null ? s.minute : int.parse(parts[1]),
      daysOfWeek: changes.containsKey('days_of_week')
          ? ((changes['days_of_week'] as List?)?.cast<int>() ?? const [])
          : s.daysOfWeek,
      enabled: changes['enabled'] as bool? ?? s.enabled,
      guard: changes.containsKey('guard')
          ? ScheduleGuard.fromJson(changes['guard'])
          : s.guard,
      pairId: echoPairId ? s.pairId : null,
      nextRunAt: s.nextRunAt,
      lastRunAt: s.lastRunAt,
    );
    items = [
      for (final e in items)
        if (e.id == id) updated else e
    ];
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (failDeleteIds.contains(id)) throw const ScheduleException(500, 'boom');
    final target = items.where((e) => e.id == id).firstOrNull;
    items = items
        .where((e) =>
            e.id != id &&
            !(cascadeDelete &&
                target?.pairId != null &&
                e.pairId == target!.pairId))
        .toList();
  }

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
    payloads.add(payload);
    return _schedule(id: 'new-${calls.length}', pairId: pairId);
  }

  /// create마다 받은 pair_id(시점 예약이면 null).
  final List<String?> pairIds = [];

  /// create마다 받은 payload.
  final List<Map<String, dynamic>?> payloads = [];
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

/// 삭제 모드 진입 → 항목 체크 → 빨간 CTA → 확인창.
Future<void> _deleteVia(WidgetTester tester, Key check,
    {bool confirm = true}) async {
  await tester.tap(find.byKey(RoutineSettingsScreen.deleteModeKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(check));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(RoutineSettingsScreen.deleteSelectedKey));
  await tester.pumpAndSettle();
  await tester.tap(
      find.byKey(Key(confirm ? 'routine_delete_ok' : 'routine_delete_cancel')));
  await tester.pumpAndSettle();
}

/// 기기 선택 → 편집기.
Future<void> _openEditor(WidgetTester tester, String device) async {
  await tester.tap(find.byKey(RoutineSettingsScreen.addKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('routine_device_$device')));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('routine_save')));
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

  testWidgets('예약이 없으면 흰 상자로 밝히고 휴지통은 잠긴다', (tester) async {
    await _pump(tester, _FakeRepo());
    expect(find.text('routine_schedule_empty'.tr()), findsOneWidget);
    expect(find.byKey(RoutineSettingsScreen.emptyKey), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(RoutineSettingsScreen.deleteModeKey))
            .onPressed,
        isNull);
    // 펌웨어 대기 각주는 원본에 없어 문서로 옮겼다.
    expect(find.textContaining('routine_pending_footnote'), findsNothing);
  });

  testWidgets('목록은 시작 시각 순이다', (tester) async {
    await _pump(
        tester,
        _FakeRepo(items: [
          _schedule(id: 'late', hour: 20),
          _schedule(
              id: 'on', action: ScheduleAction.fanOn, hour: 12, pairId: 'p1'),
          _schedule(
              id: 'off', action: ScheduleAction.fanOff, hour: 13, pairId: 'p1'),
          _schedule(id: 'early', hour: 8),
        ]));
    final early = tester.getTopLeft(find.byKey(const Key('schedule_early')));
    final pair = tester.getTopLeft(find.byKey(const Key('schedule_pair_p1')));
    final late = tester.getTopLeft(find.byKey(const Key('schedule_late')));
    expect(early.dy < pair.dy && pair.dy < late.dy, isTrue);
    expect(find.textContaining('12:00~13:00'), findsOneWidget);
  });

  testWidgets('분무 예약 추가 — 기기 선택 → 시작만 → 시점 1건, pair_id 없음', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'mist');
    expect(find.text('routine_end'), findsNothing);
    await _save(tester);
    expect(repo.calls.where((c) => c.startsWith('create:')).toList(),
        ['create:mist:12:00:d=']);
    expect(repo.pairIds, [null]);
    // 새 분무 예약은 기본 3초.
    expect(repo.payloads, [
      {'duration_ms': 3000}
    ]);
  });

  testWidgets('분무 예약 — 6·9초는 서버 지원 전이라 못 고르고 3초로 저장된다',
      (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'mist');
    expect(find.text('home_mist_duration_label'), findsOneWidget);
    expect(find.text('home_mist_schedule_only_three'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine_mist_9')));
    await tester.pump();
    await _save(tester);
    expect(repo.payloads, [
      {'duration_ms': 3000}
    ]);
  });

  testWidgets('환기팬 예약 추가 — 시작/종료가 같은 pair_id의 on/off 2건이 된다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'fan');
    await _save(tester);
    final creates = repo.calls.where((c) => c.startsWith('create:')).toList();
    expect(creates, hasLength(2), reason: '실제 호출: ${repo.calls}');
    expect(creates[0], startsWith('create:fan_on:12:00'));
    expect(creates[1], startsWith('create:fan_off:14:00'));
    expect(repo.pairIds, hasLength(2));
    expect(repo.pairIds[0], isNotNull);
    expect(repo.pairIds[0], repo.pairIds[1]);
  });

  testWidgets('시각 조작 — 오전/오후·시·분 화살표가 24시간제로 변환된다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'led');
    // 오후 12 → 시 +1 = 오후 1시(13:00), 분 -1 = 50분(10분 단위, 2026-09-16).
    await tester.tap(find.byKey(const Key('routine_start_hour_up')));
    await tester.tap(find.byKey(const Key('routine_start_minute_down')));
    await tester.pump();
    expect(find.text('1'), findsWidgets);
    expect(find.text('50'), findsOneWidget);
    // 오전으로 바꾸면 01:50. 종료는 오전 11시 → 11:00.
    await tester.tap(find.byKey(const Key('routine_start_am')));
    await tester.tap(find.byKey(const Key('routine_end_am')));
    await tester.tap(find.byKey(const Key('routine_end_hour_down')));
    await tester.tap(find.byKey(const Key('routine_end_hour_down')));
    await tester.tap(find.byKey(const Key('routine_end_hour_down')));
    await tester.pump();
    await _save(tester);
    final creates = repo.calls.where((c) => c.startsWith('create:')).toList();
    expect(creates[0], startsWith('create:led_on:01:50'));
    expect(creates[1], startsWith('create:led_off:11:00'));
  });

  testWidgets('시 화살표는 12→1, 1→12로 돈다', (tester) async {
    await _pump(tester, _FakeRepo());
    await _openEditor(tester, 'mist');
    await tester.tap(find.byKey(const Key('routine_start_hour_up')));
    await tester.pump();
    expect(
        tester.widget<Text>(find.byKey(const Key('routine_start_hour'))).data,
        '1');
    await tester.tap(find.byKey(const Key('routine_start_hour_down')));
    await tester.pump();
    expect(
        tester.widget<Text>(find.byKey(const Key('routine_start_hour'))).data,
        '12');
  });

  testWidgets('냉각팬 예약 — fan2_on 한 건 + payload.duration_ms(기본 30분, 2시간 선택)',
      (tester) async {
    // 2026-09-16 사용자 결정: pair 대신 duration payload(서버 지원은 요청 문서).
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'cool');
    await _save(tester);
    expect(repo.calls.where((c) => c.startsWith('create:')).toList(),
        ['create:fan2_on:12:00:d=']);
    expect(repo.payloads, [
      {'duration_ms': 1800000}
    ]);
    expect(repo.pairIds, [null]);

    await _openEditor(tester, 'cool');
    await tester.tap(find.byKey(const Key('routine_start_hour_down')));
    await tester.tap(find.byKey(const Key('routine_after_120')));
    await tester.pump();
    await _save(tester);
    expect(repo.calls.last, 'create:fan2_on:23:00:d=');
    expect(repo.payloads.last, {'duration_ms': 7200000});
  });

  testWidgets('냉각팬 duration 예약 목록·수정 — 12:00~13:00, 칩 복원, PATCH에 duration',
      (tester) async {
    final repo = _FakeRepo(items: [
      Schedule(
        id: 'c',
        deviceId: 'd1',
        action: ScheduleAction.fan2On,
        payload: const {'duration_ms': 3600000},
        kind: ScheduleKind.daily,
        hour: 12,
        minute: 0,
        daysOfWeek: const [],
        enabled: true,
        guard: null,
        pairId: null,
        nextRunAt: null,
        lastRunAt: null,
      ),
    ]);
    await _pump(tester, repo);
    expect(find.textContaining('12:00~13:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('schedule_c')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_after_60')), findsOneWidget);
    expect(find.byKey(const Key('routine_end_hour')), findsNothing);
    await tester.tap(find.byKey(const Key('routine_after_30')));
    await tester.pump();
    await _save(tester);
    final patch = repo.calls.firstWhere((c) => c.startsWith('patch:c'));
    expect(patch, contains('duration_ms: 1800000'));
  });

  testWidgets('LED 예약 추가 — brightness 50이 켜기 행 payload에만 실린다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'led');
    expect(find.byKey(const Key('routine_brightness_row')), findsOneWidget);
    final slider = tester
        .widget<Slider>(find.byKey(const Key('routine_brightness_slider')));
    expect(slider.value, 50);
    slider.onChanged!(80);
    await tester.pump();
    await _save(tester);
    expect(repo.calls.where((c) => c.startsWith('create:')).toList(),
        ['create:led_on:12:00:d=', 'create:led_off:14:00:d=']);
    expect(repo.payloads, [
      {'brightness': 80},
      null
    ]);
  });

  testWidgets('LED 구간 수정 — 저장된 밝기를 복원하고 on PATCH에만 brightness', (tester) async {
    final repo = _FakeRepo(items: [
      Schedule(
        id: 'on',
        deviceId: 'd1',
        action: ScheduleAction.ledOn,
        payload: const {'brightness': 70},
        kind: ScheduleKind.daily,
        hour: 8,
        minute: 0,
        daysOfWeek: const [],
        enabled: true,
        guard: null,
        pairId: 'p1',
        nextRunAt: null,
        lastRunAt: null,
      ),
      _schedule(
          id: 'off', action: ScheduleAction.ledOff, hour: 20, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_p1')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Slider>(find.byKey(const Key('routine_brightness_slider')))
            .value,
        70);
    await _save(tester);
    final patches = repo.calls.where((c) => c.startsWith('patch:')).toList();
    expect(patches[0], startsWith('patch:on:'));
    expect(patches[0], contains('brightness: 70'));
    expect(patches[1], startsWith('patch:off:'));
    expect(patches[1].contains('brightness'), isFalse);
  });

  testWidgets('환기팬 예약은 payload 없이 만든다', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'fan');
    expect(find.byKey(const Key('routine_brightness_row')), findsNothing);
    await _save(tester);
    expect(repo.payloads, [null, null]);
  });

  testWidgets('요일 칩을 고르면 weekly, 안 고르면 daily', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _openEditor(tester, 'mist');
    await tester.tap(find.byKey(const Key('routine_day_7')));
    await tester.tap(find.byKey(const Key('routine_day_6')));
    await tester.pump();
    await _save(tester);
    expect(repo.calls.last, 'create:mist:12:00:d=6,7');
    await _openEditor(tester, 'mist');
    await _save(tester);
    expect(repo.calls.last, 'create:mist:12:00:d=');
  });

  testWidgets('같은 pair_id의 on/off는 목록에 한 줄로 묶인다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(
          id: 'on', action: ScheduleAction.heaterOn, hour: 20, pairId: 'p1'),
      _schedule(
          id: 'off', action: ScheduleAction.heaterOff, hour: 6, pairId: 'p1'),
      _schedule(id: 'solo'),
    ]);
    await _pump(tester, repo);
    expect(find.byKey(const Key('schedule_pair_p1')), findsOneWidget);
    expect(find.byKey(const Key('schedule_on')), findsNothing);
    expect(find.byKey(const Key('schedule_off')), findsNothing);
    expect(find.byKey(const Key('schedule_solo')), findsOneWidget);
    expect(find.textContaining('20:00~06:00'), findsOneWidget);
  });

  testWidgets('구간 삭제는 한 건만 DELETE — 서버가 짝을 같이 지운다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await _deleteVia(tester, const Key('schedule_pair_check_p1'));
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
      _schedule(
          id: 'off', action: ScheduleAction.fanOff, hour: 20, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_p1')));
    await tester.pumpAndSettle();
    // 편집 모드: 종료 행이 있고 하단에 예약 삭제가 있다.
    expect(find.text('routine_end'), findsOneWidget);
    expect(find.byKey(const Key('routine_delete')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('routine_start_hour'))).data,
        '8');
    expect(tester.widget<Text>(find.byKey(const Key('routine_end_hour'))).data,
        '8');
    await tester.tap(find.byKey(const Key('routine_end_minute_up')));
    await tester.pump();
    await _save(tester);
    final patches = repo.calls.where((c) => c.startsWith('patch:')).toList();
    expect(patches, hasLength(2), reason: '실제 호출: ${repo.calls}');
    expect(patches[0], startsWith('patch:on:'));
    expect(patches[0], contains('time_of_day: 08:00'));
    expect(patches[1], startsWith('patch:off:'));
    expect(patches[1], contains('time_of_day: 20:10'));
  });

  testWidgets('냉각팬 구간 편집 — 30/60/120분이 아니면 칩을 고르기 전엔 저장이 잠긴다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.fan2On, hour: 8, pairId: 'p1'),
      _schedule(
          id: 'off',
          action: ScheduleAction.fan2Off,
          hour: 8,
          minute: 45,
          pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_after_30')), findsOneWidget);
    expect(find.byKey(const Key('routine_end_hour')), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: find.byKey(const Key('routine_save')),
                matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const Key('routine_after_60')));
    await tester.pump();
    await _save(tester);
    final patches = repo.calls.where((c) => c.startsWith('patch:')).toList();
    expect(patches[1], contains('time_of_day: 09:00'));
  });

  testWidgets('시점 수정에는 종료 행이 없고 동작은 그대로다', (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a', hour: 8)]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();
    expect(find.text('routine_end'), findsNothing);
    await tester.tap(find.byKey(const Key('routine_start_hour_up')));
    await tester.pump();
    await _save(tester);
    final patch = repo.calls.firstWhere((c) => c.startsWith('patch:a'));
    expect(patch, contains('time_of_day: 09:00'));
    expect(patch.contains('action'), isFalse);
    // 기존 분사 시간(payload)은 그대로 실린다.
    expect(patch, contains('duration_ms: 2000'));
  });

  testWidgets('옛 2초 분무 예약 — 칩 미선택으로 열리고, 3초를 고르면 3000으로 바뀐다',
      (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a', hour: 8)]);
    await _pump(tester, repo);
    // 목록은 저장된 초를 그대로 보여 준다.
    expect(find.text('08:00 home_mist_seconds'), findsOneWidget);
    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();
    for (final sec in [3, 6, 9]) {
      expect(
          tester
              .widget<ScheduleChoiceChip>(find.byKey(Key('routine_mist_$sec')))
              .selected,
          isFalse,
          reason: '$sec초');
    }
    await tester.tap(find.byKey(const Key('routine_mist_3')));
    await tester.pump();
    await _save(tester);
    final patch = repo.calls.firstWhere((c) => c.startsWith('patch:a'));
    expect(patch, contains('duration_ms: 3000'));
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
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteModeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule_check_off1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteSelectedKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_delete_off_warning')), findsOneWidget);
  });

  testWidgets('켜기 예약 삭제는 평범한 확인 문구다 — 켜기·끄기를 같이 지워도', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on1', action: ScheduleAction.heaterOn),
      _schedule(id: 'off1', action: ScheduleAction.heaterOff),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteModeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule_check_off1')));
    await tester.tap(find.byKey(const Key('schedule_check_on1')));
    await tester.pumpAndSettle();
    expect(find.text('routine_delete_count'), findsOneWidget);
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteSelectedKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_delete_off_warning')), findsNothing);
    expect(find.byKey(const Key('routine_delete_question')), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine_delete_ok')));
    await tester.pumpAndSettle();
    // 선택 순서가 아니라 목록(시작 시각) 순으로 지운다.
    expect(repo.calls.where((c) => c.startsWith('delete:')).toList(),
        ['delete:on1', 'delete:off1']);
    expect(find.byKey(const Key('schedule_off1')), findsNothing);
    expect(find.byKey(const Key('schedule_check_on1')), findsNothing,
        reason: '삭제 후엔 삭제 모드를 나간다');
  });

  testWidgets('다중 삭제 부분 실패 — 실패에서 멈추고 목록을 다시 읽는다', (tester) async {
    final repo = _FakeRepo(failDeleteIds: {
      'b'
    }, items: [
      _schedule(id: 'a', hour: 8),
      _schedule(id: 'b', hour: 9),
      _schedule(id: 'c', hour: 10),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteModeKey));
    await tester.pumpAndSettle();
    for (final id in ['a', 'b', 'c']) {
      await tester.tap(find.byKey(Key('schedule_check_$id')));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteSelectedKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine_delete_ok')));
    await tester.pumpAndSettle();
    final deletes = repo.calls.where((c) => c.startsWith('delete:')).toList();
    expect(deletes, ['delete:a', 'delete:b'], reason: 'b에서 멈춘다: ${repo.calls}');
    expect(repo.calls.where((c) => c == 'list').length, 2,
        reason: '실패 후 서버 목록을 다시 읽는다');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('schedule_a')), findsNothing);
    expect(find.byKey(const Key('schedule_b')), findsOneWidget);
    expect(find.byKey(const Key('schedule_c')), findsOneWidget);
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
    await _save(tester);

    final patch = repo.calls.firstWhere((c) => c.startsWith('patch:a'));
    expect(patch.contains('guard'), isFalse,
        reason: '안 건드렸으면 키 생략 — 서버의 enabled:false가 유지돼야 한다: $patch');
  });

  testWidgets('켜진 가드는 목록 부제에 보인다', (tester) async {
    await _pump(
        tester,
        _FakeRepo(items: [
          _schedule(
            id: 'a',
            guard: const ScheduleGuard(
                type: GuardType.humidityAbove, value: 70, enabled: true),
          ),
        ]));
    expect(find.textContaining('routine_guard_chip_humidity_above'),
        findsOneWidget);
  });

  testWidgets('레거시 toggle 예약도 시점 편집기로 열리고 동작은 그대로 PATCH된다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'a', action: ScheduleAction.fanToggle),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();
    expect(find.text('routine_start'), findsOneWidget);
    expect(find.text('routine_end'), findsNothing);
    await _save(tester);
    expect(repo.calls.any((c) => c.startsWith('patch:a')), isTrue);
  });

  testWidgets('토글은 서버에 반영한다', (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a', enabled: true)]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_toggle_a')));
    await tester.pumpAndSettle();

    expect(repo.calls.any((c) => c.startsWith('patch:a')), isTrue);
  });

  testWidgets('토글이 실패하면 켜진 것처럼 두지 않는다 — 안 도는 예약을 믿게 하면 안 된다', (tester) async {
    final repo = _FakeRepo(
      items: [_schedule(id: 'a', enabled: false)],
      failOnPatch: true,
    );
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('schedule_toggle_a')));
    await tester.pumpAndSettle();

    final sw = tester
        .widget<ScheduleSwitch>(find.byKey(const Key('schedule_toggle_a')));
    expect(sw.value, isFalse, reason: '실패했으므로 꺼진 채여야 한다');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('삭제는 확인을 받는다 — 취소하면 아무 일도 없다', (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a')]);
    await _pump(tester, repo);
    await _deleteVia(tester, const Key('schedule_check_a'), confirm: false);
    expect(repo.calls.any((c) => c.startsWith('delete')), isFalse);
    expect(find.byKey(const Key('schedule_a')), findsOneWidget);
  });

  testWidgets('삭제 모드 — 뒤로가기는 화면을 닫지 않고 모드만 끈다', (tester) async {
    await _pump(tester, _FakeRepo(items: [_schedule(id: 'a')]));
    await tester.tap(find.byKey(RoutineSettingsScreen.deleteModeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule_check_a')), findsOneWidget);
    expect(find.byKey(RoutineSettingsScreen.deleteSelectedKey), findsNothing,
        reason: '고른 게 없으면 삭제 CTA가 없다');
    expect(find.byKey(RoutineSettingsScreen.addKey), findsNothing);
    await tester.tap(find.byTooltip('management_back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule_check_a')), findsNothing);
    expect(find.byKey(RoutineSettingsScreen.addKey), findsOneWidget);
    expect(find.byType(RoutineSettingsScreen), findsOneWidget);
  });

  testWidgets('편집기 하단 "예약 삭제"도 같은 확인창을 거친다', (tester) async {
    final repo = _FakeRepo(items: [_schedule(id: 'a')]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine_delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine_delete_question')), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine_delete_ok')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('delete:')), ['delete:a']);
    expect(find.byKey(const Key('schedule_a')), findsNothing);
  });

  testWidgets('구간 삭제: 서버가 짝을 안 지우면(구버전) off 낱개가 그대로 보인다', (tester) async {
    final repo = _FakeRepo(cascadeDelete: false, items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await _deleteVia(tester, const Key('schedule_pair_check_p1'));
    // 지웠다고 믿지 않고 다시 읽는다 — 남은 off는 지울 수 있게 보여야 한다.
    expect(find.byKey(const Key('schedule_pair_p1')), findsNothing);
    expect(find.byKey(const Key('schedule_off')), findsOneWidget);
  });

  testWidgets('구간 편집: off PATCH 실패 시 on을 원래 타이밍으로 되돌린다', (tester) async {
    final repo = _FakeRepo(failPatchIds: {
      'off'
    }, items: [
      _schedule(
          id: 'on', action: ScheduleAction.heaterOn, hour: 8, pairId: 'p1'),
      _schedule(
          id: 'off', action: ScheduleAction.heaterOff, hour: 20, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine_start_hour_up')));
    await tester.pump();
    await _save(tester);
    final patches = repo.calls.where((c) => c.startsWith('patch:')).toList();
    // on 수정 → off 실패 → on 복구
    expect(patches, hasLength(3), reason: '실제 호출: ${repo.calls}');
    expect(patches[0], startsWith('patch:on:'));
    expect(patches[0], contains('time_of_day: 09:00'));
    expect(patches[1], startsWith('patch:off:'));
    expect(patches[2], startsWith('patch:on:'));
    expect(patches[2], contains('time_of_day: 08:00'));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('구간 토글: off PATCH 실패 시 on을 원래 값으로 되돌린다', (tester) async {
    final repo = _FakeRepo(failPatchIds: {
      'off'
    }, items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_toggle_p1')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('patch:')).toList(), [
      'patch:on:{enabled: false}',
      'patch:off:{enabled: false}',
      'patch:on:{enabled: true}',
    ]);
    // 화면도 되돌아온다.
    final sw = tester.widget<ScheduleSwitch>(
        find.byKey(const Key('schedule_pair_toggle_p1')));
    expect(sw.value, isTrue);
  });

  testWidgets('반쪽 켜짐(on만 enabled)은 OFF로 숨기지 않고 켜짐+경고로 보인다', (tester) async {
    final repo = _FakeRepo(items: [
      _schedule(id: 'on', action: ScheduleAction.heaterOn, pairId: 'p1'),
      _schedule(
          id: 'off',
          action: ScheduleAction.heaterOff,
          pairId: 'p1',
          enabled: false),
    ]);
    await _pump(tester, repo);
    final sw = tester.widget<ScheduleSwitch>(
        find.byKey(const Key('schedule_pair_toggle_p1')));
    expect(sw.value, isTrue);
    expect(find.textContaining('routine_pair_skewed'), findsOneWidget);
  });

  testWidgets('PATCH 응답에 pair_id가 없어도 구간 한 줄이 쪼개지지 않는다', (tester) async {
    final repo = _FakeRepo(echoPairId: false, items: [
      _schedule(id: 'on', action: ScheduleAction.fanOn, pairId: 'p1'),
      _schedule(id: 'off', action: ScheduleAction.fanOff, pairId: 'p1'),
    ]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('schedule_pair_toggle_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule_pair_p1')), findsOneWidget);
    expect(find.byKey(const Key('schedule_on')), findsNothing);
  });
}
