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
      ScheduleGuard? guard}) async {
    calls.add('create:${action.wire}:'
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        '${guard == null ? '' : ':guard=${guard.type.wire}>${guard.value}'}');
    return _schedule(id: 'new-${calls.length}');
  }
}

Schedule _schedule({
  String id = 's1',
  bool enabled = true,
  ScheduleAction action = ScheduleAction.mist,
  ScheduleKind kind = ScheduleKind.daily,
  List<int> days = const [],
}) =>
    Schedule(
      id: id,
      deviceId: 'd1',
      action: action,
      payload: const {'duration_ms': 2000},
      kind: kind,
      hour: 8,
      minute: 0,
      daysOfWeek: days,
      enabled: enabled,
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

  testWidgets('백엔드가 없는 타이머는 이유를 밝힌다 — 안 만든 게 아니라 못 만든 것',
      (tester) async {
    await _pump(tester, _FakeRepo());
    expect(find.byKey(RoutineSettingsScreen.pendingTimerKey), findsOneWidget);
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
