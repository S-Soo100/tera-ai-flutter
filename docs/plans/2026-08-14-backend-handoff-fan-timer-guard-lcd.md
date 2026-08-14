# 백엔드 핸드오프(2026-08-14) 반영 구현 계획

> **구현 방식 (CAOF):** 이 계획을 task 단위로 구현한다. Part 1·3은 Standard(메인 직접), Part 2는 Critical(사용자 승인 → flutter-dev 투입 가능, 메인 직접도 허용). Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **진행 현황 (2026-08-14):**
> - Part 0 ✅ `a892c74` · Part 1 ✅ v0.57.0 (`0438f52`~`3a645bb`) · Part 2 ✅ v0.58.0 (`94c39a1`~`234531b`, 사용자 승인 후 메인 직접) · Part 3 ✅ v0.59.0
> - 서버 검증: `schedules.guard`(jsonb)·`commands.source/source_id/reason` 컬럼 존재 확인(읽기 전용 SQL, 2026-08-14)
> - **남은 것:** ① 실서버 스모크(guard 왕복·구간 생성 — 실기기에서) ② 펌웨어 플래시 후 팬타이머·LCD 실동작 확인 ③ guard 해제 PATCH `null` 수용 여부 실서버 확인(Task 2-2 Must know)

**Goal:** 백엔드 핸드오프 요약(`docs/backend-handoff-2026-08-14-summary.md`)으로 풀린 계약 4건을 앱에 반영한다 — ① 팬 일회성 타이머, ② 예약 스마트 가드 + 구간 예약, ③ LCD 커스텀 텍스트.

**Architecture:** 명령은 기존 패턴대로 `commands` INSERT(`cage_control_actions.dart` 경유), 예약·LCD는 REST. 팬 타이머의 "진행 중" 상태는 서버에 별도 저장 없이 `commands` 이력(`issued_at + duration_ms`)에서 계산한다(A안). REST 공통부는 `TerraRestClient`로 추출해 예약·LCD가 공유한다.

**Tech Stack:** Flutter + Riverpod + Supabase(commands 직결) + http(REST) + easy_localization.

**선행 확인:**
- 펌웨어 플래시 전에는 팬 타이머·LCD가 실기기에서 안 돈다(핸드오프 §5). 앱 구현·테스트는 가능, 실기기 검증은 플래시 후.
- LED 밝기(§1.4)는 **이번 계획에서 제외** — 현 보드가 릴레이라 물리 반영이 안 되고, 보드 타입 구분 필드가 계약에 없다. 백엔드에 구분 방법 문의 후 별도 건.
- 감사 로그 화면(§4)도 **제외** — 통계 탭 Figma 디자인 대기와 묶여 있다. `source`/`reason` 컬럼은 이미 서버에 있으므로 화면만 후속.

**이 계획이 다루지 않는 것 (건드리지 않는다):**
- `cage_control_actions.dart`의 히터 2단 안전확인 플로우 (구조 불변)
- 홈/통계 공용 차트(`EnvChart`), 밤 띠, 안심존 판정
- BLE 페어링, WebRTC, 크레캠

---

## Part 0 — 문서 반영 (Trivial, 계획 커밋과 함께 즉시)

- [x] 핸드오프 원문을 `docs/backend-handoff-2026-08-14-summary.md`로 스냅샷 (Desktop 원본은 유실될 수 있다)
- [x] `docs/backend-handoff-timer-mist.md` §10.7 대기 목록에 해소 상태 반영
- [x] CLAUDE.md 백엔드 문서 목록에 스냅샷·이 계획서 포인터 추가

---

## Part 1 — 팬 일회성 타이머 (Standard, 메인 직접)

계약: `fan_on` + `payload.duration_ms`(최대 2h=7,200,000) → 펌웨어가 자동 OFF. `fan_off`로 취소. 남은 시간은 **앱이 발행시각+duration으로 계산**(핸드오프 §1.3).

### Task 1-1: FanTimerDuration 도메인

**Context:**
- Depends on: 없음
- Inputs: 핸드오프 §1.3 (duration_ms 최대 2h)
- Outputs: `FanTimerDuration` enum (payload 생성)
- Must know: `MistDuration`(`home/domain/mist_duration.dart`)과 같은 패턴. 분 단위가 아니라 ms로 보낸다.
- Acceptance: `flutter test test/features/home/fan_timer_duration_test.dart` PASS

**Files:**
- Create: `lib/features/home/domain/fan_timer_duration.dart`
- Test: `test/features/home/fan_timer_duration_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/fan_timer_duration.dart';

void main() {
  test('payload는 duration_ms(밀리초)를 담는다', () {
    expect(FanTimerDuration.m10.payload, {'duration_ms': 600000});
    expect(FanTimerDuration.h2.payload, {'duration_ms': 7200000});
  });

  test('계약 상한 2h를 넘는 값이 없다', () {
    for (final d in FanTimerDuration.values) {
      expect(d.payload['duration_ms'], lessThanOrEqualTo(7200000));
    }
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `flutter test test/features/home/fan_timer_duration_test.dart` → Expected: FAIL (파일 없음)

- [ ] **Step 3: 구현**

```dart
/// 팬 일회성 타이머 길이 (PRD §4.2.1).
///
/// `fan_on` + `payload.duration_ms`로 보내면 **펌웨어가 시간 뒤 자동 OFF**한다.
/// 계약 상한 2h(7,200,000ms) — `docs/backend-handoff-2026-08-14-summary.md` §1.3.
/// 취소는 `fan_off`. 히터 타이머는 미지원(보드에 히터 미탑재).
enum FanTimerDuration {
  m10(10),
  m30(30),
  h1(60),
  h2(120);

  const FanTimerDuration(this.minutes);

  final int minutes;

  Map<String, dynamic> get payload => {'duration_ms': minutes * 60000};

  /// 칩 라벨 i18n 키. `home_timer_10m` 식.
  String get labelKey =>
      minutes < 60 ? 'home_timer_${minutes}m' : 'home_timer_${minutes ~/ 60}h';
}
```

- [ ] **Step 4: 통과 확인** — Run: `flutter test test/features/home/fan_timer_duration_test.dart` → Expected: PASS

- [ ] **Step 5: Commit** — `git add lib/features/home/domain/fan_timer_duration.dart test/features/home/fan_timer_duration_test.dart && git commit -m "feat(home): 팬 타이머 길이 도메인 (10분~2h, 계약 상한 검증)"`

### Task 1-2: RunningTimer — commands 이력에서 진행 중 타이머 계산

**Context:**
- Depends on: 없음 (1-1과 독립)
- Inputs: `commands` 행 목록(fan 계열, `issued_at` 내림차순)
- Outputs: `RunningTimer.fanTimerFrom(rows, now)` static — 진행 중이면 인스턴스, 아니면 null
- Must know: **최신 유효 fan 명령이 duration 붙은 `fan_on`일 때만** 타이머다. 그 뒤(더 최신)에 `fan_off`/`fan_toggle`이 오면 취소된 것. `rejected`/`expired` 명령은 없는 셈 친다. 기존 `fromJson`(B안 잔재)은 지우고 이 factory로 교체한다 — 실동작한 적 없는 코드다(§10.5).
- Acceptance: `flutter test test/features/home/running_timer_test.dart` PASS

**Files:**
- Modify: `lib/features/home/domain/running_timer.dart` (fromJson 제거, fanTimerFrom 추가)
- Test: `test/features/home/running_timer_test.dart` (기존 포맷 테스트 유지 + 추가)

- [ ] **Step 1: 실패하는 테스트 추가** (기존 `formatRemaining`·`remaining` 테스트는 그대로 둔다)

```dart
Map<String, dynamic> _cmd(String action, String status, String issuedAt,
        {int? durationMs}) =>
    {
      'id': 'c-$action-$issuedAt',
      'device_id': 'dev-1',
      'action': action,
      'status': status,
      'payload': durationMs == null ? null : {'duration_ms': durationMs},
      'issued_at': issuedAt,
    };

group('fanTimerFrom', () {
  final now = DateTime.parse('2026-08-14T12:00:00Z');

  test('duration 붙은 최신 fan_on → 진행 중 타이머', () {
    final t = RunningTimer.fanTimerFrom(
      [_cmd('fan_on', 'acked', '2026-08-14T11:50:00Z', durationMs: 1800000)],
      now,
    );
    expect(t, isNotNull);
    expect(t!.durationMinutes, 30);
    expect(t.remaining(now), const Duration(minutes: 20));
  });

  test('더 최신 fan_off가 있으면 취소된 것 → null', () {
    final t = RunningTimer.fanTimerFrom([
      _cmd('fan_off', 'acked', '2026-08-14T11:55:00Z'),
      _cmd('fan_on', 'acked', '2026-08-14T11:50:00Z', durationMs: 1800000),
    ], now);
    expect(t, isNull);
  });

  test('rejected 명령은 없는 셈 — 그 아래 fan_on 타이머가 살아있다', () {
    final t = RunningTimer.fanTimerFrom([
      _cmd('fan_off', 'rejected', '2026-08-14T11:55:00Z'),
      _cmd('fan_on', 'acked', '2026-08-14T11:50:00Z', durationMs: 1800000),
    ], now);
    expect(t, isNotNull);
  });

  test('duration 없는 fan_on(그냥 켜기) → null', () {
    final t = RunningTimer.fanTimerFrom(
      [_cmd('fan_on', 'acked', '2026-08-14T11:50:00Z')],
      now,
    );
    expect(t, isNull);
  });

  test('만료된 타이머 → null', () {
    final t = RunningTimer.fanTimerFrom(
      [_cmd('fan_on', 'acked', '2026-08-14T10:00:00Z', durationMs: 600000)],
      now,
    );
    expect(t, isNull);
  });
});
```

- [ ] **Step 2: 실패 확인** — Run: `flutter test test/features/home/running_timer_test.dart` → Expected: FAIL (fanTimerFrom 없음)

- [ ] **Step 3: 구현** — `running_timer.dart`의 `fromJson`·`_labelKey`를 지우고 교체:

```dart
  /// `commands` 이력 → 진행 중 팬 타이머 (A안: `issued_at + duration_ms`).
  ///
  /// [rows]는 fan 계열(`fan_on`/`fan_off`/`fan_toggle`) 명령을 **`issued_at`
  /// 내림차순**으로 담는다. 최신 유효 명령이 duration 붙은 `fan_on`이고 아직 안
  /// 끝났을 때만 타이머다 — 그 뒤에 off/toggle이 왔으면 취소된 것이고,
  /// `rejected`/`expired`는 기기에 닿지 않았으니 없는 셈 친다.
  ///
  /// 서버에 타이머 상태를 따로 두지 않아도 다기기에서 같은 값이 나온다.
  static RunningTimer? fanTimerFrom(
    List<Map<String, dynamic>> rows,
    DateTime now,
  ) {
    for (final r in rows) {
      final status = r['status'] as String?;
      if (status == 'rejected' || status == 'expired') continue;
      if (r['action'] != 'fan_on') return null;
      final payload = r['payload'];
      final ms = payload is Map ? (payload['duration_ms'] as num?) : null;
      if (ms == null) return null;
      final issuedAt = DateTime.tryParse('${r['issued_at']}')?.toLocal();
      if (issuedAt == null) return null;
      final t = RunningTimer(
        id: '${r['id']}',
        deviceId: '${r['device_id']}',
        actuatorLabelKey: 'module_actuator_fan',
        durationMinutes: ms.toInt() ~/ 60000,
        endsAt: issuedAt.add(Duration(milliseconds: ms.toInt())),
      );
      return t.isActive(now) ? t : null;
    }
    return null;
  }
```

클래스 상단 doc comment도 갱신 — "아직 채울 데이터가 없다"를 "A안 실계약(2026-08-14)으로 `commands`에서 계산한다"로.

- [ ] **Step 4: 통과 확인** — Run: `flutter test test/features/home/running_timer_test.dart` → Expected: PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(home): commands 이력에서 진행 중 팬 타이머 계산 (A안)"`

### Task 1-3: runningTimersProvider 실배선 + 팬 시트 UI

**Context:**
- Depends on: 1-1, 1-2
- Inputs: `RunningTimer.fanTimerFrom`, `FanTimerDuration`, `supabaseClientProvider`·`currentDeviceIdProvider`(`home_control_providers.dart`)
- Outputs: 칩 실동작 + 팬 탭 → 시트(계속 켜기/타이머 4종), 켜져 있으면 즉시 `fan_off`
- Must know: ① 명령 발행은 반드시 `cage_control_actions.dart` 경유(CLAUDE.md 안전 규칙). ② 칩의 "목록 먼저, tick은 있을 때만" 순서 유지 — 뒤집으면 홈이 매초 리빌드된다. ③ 타이머 발행 직후 `ref.invalidate(runningTimersProvider)`로 칩을 깨운다. ④ 조회 실패는 빈 목록으로 흡수(칩 때문에 제어 탭을 깨지 않는다).
- Acceptance: `flutter analyze` 에러 0 + `flutter test test/features/home/` PASS

**Files:**
- Modify: `lib/features/home/presentation/widgets/running_timer_chip.dart` (provider 몸통 교체)
- Modify: `lib/features/home/presentation/cage_control_actions.dart` (`handleFanTap` 교체)
- Modify: `assets/l10n/ko.json`

- [ ] **Step 1: ko.json 키 추가** (`home_mist_pick_title` 근처에)

```json
"home_fan_pick_title": "환기",
"home_fan_steady_on": "계속 켜기",
"home_timer_10m": "10분",
"home_timer_30m": "30분",
"home_timer_1h": "1시간",
"home_timer_2h": "2시간",
```

`home_timer_running` 키가 이미 있는지 확인하고(칩이 쓴다), 없으면: `"home_timer_running": "{} {}분 타이머 가동 중 · {} 남음"`

- [ ] **Step 2: runningTimersProvider 교체** (`running_timer_chip.dart`)

```dart
import '../home_control_providers.dart';

/// 현재 세트 제어기의 진행 중 팬 타이머 (A안 — `commands`에서 계산).
///
/// `issued_at + duration_ms`로 종료 시각을 만든다. 조회 실패는 빈 목록으로
/// 흡수한다 — 칩 하나 때문에 제어 탭 전체를 에러 화면으로 만들지 않는다.
final runningTimersProvider =
    FutureProvider.autoDispose<List<RunningTimer>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  try {
    final rows = await client
        .from('commands')
        .select('id, device_id, action, status, payload, issued_at')
        .eq('device_id', deviceId)
        .inFilter('action', ['fan_on', 'fan_off', 'fan_toggle'])
        .order('issued_at', ascending: false)
        .limit(10);
    final t = RunningTimer.fanTimerFrom(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      DateTime.now(),
    );
    return t == null ? const [] : [t];
  } catch (_) {
    return const [];
  }
});
```

(`home_set_providers.dart` import는 더 안 쓰면 제거)

- [ ] **Step 3: handleFanTap 교체** (`cage_control_actions.dart`)

```dart
import '../domain/fan_timer_duration.dart';
import 'widgets/running_timer_chip.dart';

/// 팬 제어 — 꺼져 있으면 시트(계속/타이머), 켜져 있으면 바로 끈다.
///
/// 끄기에 시트를 안 두는 이유: 끄기는 망설일 게 없고, **타이머 취소도
/// `fan_off`다**(핸드오프 §1.3). 히터와 달리 안전 확인은 없지만 명령은
/// 똑같이 절대 상태로 보낸다.
Future<void> handleFanTap(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
  TelemetryReading? telemetry,
) async {
  final isOn = telemetry?.fan == ActuatorState.on;
  if (isOn) {
    await sendCageCommand(context, ref, deviceId, CommandAction.fanOff);
    ref.invalidate(runningTimersProvider);
    return;
  }

  // (FanTimerDuration?,) — null이면 '계속 켜기', 값이 있으면 일회성 타이머.
  final picked = await showModalBottomSheet<(FanTimerDuration?,)>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('home_fan_pick_title'.tr(),
                style: AppStyles.subsectionTitle(ctx)),
            const SizedBox(height: AppStyles.spacing12),
            OutlinedButton(
              key: const Key('fan_steady_on'),
              onPressed: () => Navigator.of(ctx).pop((null,)),
              child: Text('home_fan_steady_on'.tr()),
            ),
            const SizedBox(height: AppStyles.spacing8),
            Row(
              children: [
                for (final d in FanTimerDuration.values) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: Key('fan_timer_${d.minutes}'),
                      onPressed: () => Navigator.of(ctx).pop((d,)),
                      child: Text(d.labelKey.tr()),
                    ),
                  ),
                  if (d != FanTimerDuration.values.last)
                    const SizedBox(width: AppStyles.spacing8),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final duration = picked.$1;
  await sendCageCommand(
    context,
    ref,
    deviceId,
    CommandAction.fanOn,
    payload: duration?.payload,
  );
  if (duration != null) ref.invalidate(runningTimersProvider);
}
```

- [ ] **Step 4: 검증** — Run: `flutter analyze` → 에러 0. Run: `flutter test test/features/home/` → PASS (제어 탭 골든·레이아웃 테스트가 시트 변경에 걸리면 해당 테스트의 팬 탭 시나리오를 시트 선택 포함으로 갱신)

- [ ] **Step 5: pending 카드에서 타이머 행 제거** — `routine_settings_screen.dart` `_TimerPendingCard._items`에서 `('routine_timer_section', 'routine_timer_pending')` 행 삭제 + 파일 상단 표의 §4.2.1 상태를 `✅ 팬 (히터는 보드 미탑재)`로. ko.json `routine_timer_pending` 키는 아직 지우지 않는다(§4.2.1 히터 몫 설명이 남을 수 있음 — 구현 시 판단).

- [ ] **Step 6: 최종 검증 + Commit** — `flutter analyze` 0, `flutter test` PASS, `pubspec.yaml` minor bump(+build), `git commit -m "feat(home): 팬 일회성 타이머 — 시트·진행 칩 실배선 (fan_on+duration_ms)"` 후 push

---

## Part 2 — 예약 스마트 가드 + 구간 예약 (Critical — 승인 후 착수)

계약: `schedules`에 `guard`(skip 4종) 지원 + action 화이트리스트에 `*_on/off` 포함(핸드오프 §2). 구간 예약(시작~종료)은 **on/off 예약 2건**으로 구성한다(§1.1) — 서버에 "쌍" 개념은 없다.

**Critical인 이유:** 파일 6개+에 걸치고, 예약은 무인 실행이라 잘못 만들면 사용자가 모르는 채 기기가 오동작한다(되돌리기 비용 높음). 특히 히터 구간 예약이 열린다.

**설계 결정 (승인 대상):**
1. **구간 예약 = 생성 헬퍼**: 편집 시트에 [시점|구간] 선택을 추가하고, 구간 저장 시 `X_on`(시작)·`X_off`(종료) 예약 2건을 만든다. **목록에는 낱개로 표시**한다 — 서버에 쌍 메타데이터가 없어 앱이 쌍을 "기억"하면 다른 기기·웹 콘솔과 어긋난다. 정직하게 낱개.
2. **off 생성 실패 시 on 롤백**: on만 만들어지고 off가 실패하면 기기가 켜진 채 방치된다(히터면 위험). 2건 생성은 on→off 순서로 하되, off 실패 시 on을 지우고 에러를 올린다.
3. **자정 넘김 허용**: daily 예약 2건이라 "22:00 켜기 / 06:00 끄기"가 자연스럽게 동작한다. 시작>종료 검증으로 막지 않는다.
4. **히터 구간 예약 허용 + 경고 문구**: 무인 가동 경고를 편집기에 표시. (수동 제어의 2단 확인과 등가 장치)
5. **`selectable` 확장**: `[mist, fanOn, fanOff, heaterOn, heaterOff, ledOn, ledOff]`. 기존 `fanToggle`/`heaterToggle`은 뺀다 — toggle 예약은 상태가 어긋나면 반대로 동작한다(§1.1). 기존 toggle 예약 데이터는 enum에 남아 있어 목록 표시엔 문제없다.
6. **가드는 스킵 4종만**: `skip_when_{humidity,temp}_{above,below}`. 정지형은 펌웨어 미구현(후속).

### Task 2-1: ScheduleGuard 도메인 + Schedule.guard

**Context:**
- Depends on: 없음
- Inputs: 핸드오프 §2.1·§2.3 guard JSON `{type, value, enabled}`
- Outputs: `GuardType` enum + `ScheduleGuard` class + `Schedule.guard` 필드 + `createBody(guard:)` + fromJson 파싱
- Must know: 모르는 guard type은 **인스턴스를 버리지 말고 raw 보존이 아니라 null**로 — 단, PATCH에서 guard를 안 건드리면(키 생략) 서버 값이 유지되므로 유실은 없다. `createBody` 원칙대로 없는 값은 키째 뺀다.
- Acceptance: `flutter test test/features/home/schedule_test.dart` PASS

**Files:**
- Modify: `lib/features/home/domain/schedule.dart`
- Test: `test/features/home/schedule_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가**

```dart
group('ScheduleGuard', () {
  test('fromJson/toJson 왕복', () {
    final g = ScheduleGuard.fromJson(
        {'type': 'skip_when_humidity_above', 'value': 70, 'enabled': true});
    expect(g, isNotNull);
    expect(g!.type, GuardType.humidityAbove);
    expect(g.toJson(),
        {'type': 'skip_when_humidity_above', 'value': 70.0, 'enabled': true});
  });

  test('모르는 type은 null — 화면이 뭉개지지 않게', () {
    expect(
        ScheduleGuard.fromJson({'type': 'stop_when_temp_above', 'value': 30}),
        isNull);
  });

  test('createBody는 guard가 있을 때만 키를 싣는다', () {
    final without = Schedule.createBody(
        action: ScheduleAction.mist, kind: ScheduleKind.daily,
        hour: 8, minute: 0, daysOfWeek: const []);
    expect(without.containsKey('guard'), isFalse);

    final with_ = Schedule.createBody(
        action: ScheduleAction.mist, kind: ScheduleKind.daily,
        hour: 8, minute: 0, daysOfWeek: const [],
        guard: const ScheduleGuard(
            type: GuardType.humidityAbove, value: 70, enabled: true));
    expect(with_['guard'],
        {'type': 'skip_when_humidity_above', 'value': 70.0, 'enabled': true});
  });
});
```

- [ ] **Step 2: 실패 확인** — Run: `flutter test test/features/home/schedule_test.dart` → FAIL

- [ ] **Step 3: 구현** (`schedule.dart`에 추가)

```dart
/// 스마트 가드 조건 종류 — 서버가 예약 발행 직전 평가해 **스킵**한다(§2.3).
///
/// 정지형(가동 중 정지)은 펌웨어 담당 미구현이라 여기 없다. 값이 추가되면
/// [ScheduleGuard.fromJson]의 null 반환 경로도 같이 보라.
enum GuardType {
  humidityAbove('skip_when_humidity_above'),
  humidityBelow('skip_when_humidity_below'),
  tempAbove('skip_when_temp_above'),
  tempBelow('skip_when_temp_below');

  const GuardType(this.wire);

  final String wire;

  bool get isHumidity =>
      this == GuardType.humidityAbove || this == GuardType.humidityBelow;

  static GuardType? fromWire(String? v) {
    for (final t in GuardType.values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// 예약의 스마트 조건. 서버 JSON `{type, value, enabled}` 그대로.
class ScheduleGuard {
  final GuardType type;
  final double value;
  final bool enabled;

  const ScheduleGuard({
    required this.type,
    required this.value,
    required this.enabled,
  });

  Map<String, dynamic> toJson() =>
      {'type': type.wire, 'value': value, 'enabled': enabled};

  /// 모르는 type이면 null — 한 예약의 가드 때문에 목록이 통째로 비지 않게.
  /// (PATCH에서 guard 키를 생략하면 서버 값이 유지되므로 유실은 없다.)
  static ScheduleGuard? fromJson(Object? j) {
    if (j is! Map) return null;
    final type = GuardType.fromWire(j['type'] as String?);
    final value = (j['value'] as num?)?.toDouble();
    if (type == null || value == null) return null;
    return ScheduleGuard(
      type: type,
      value: value,
      enabled: j['enabled'] as bool? ?? true,
    );
  }
}
```

`Schedule`에: `final ScheduleGuard? guard;` 필드 + 생성자 + `fromJson`에 `guard: ScheduleGuard.fromJson(j['guard'])` + `copyWith` + `createBody`에 `ScheduleGuard? guard` 파라미터·`if (guard != null) 'guard': guard.toJson()`.

- [ ] **Step 4: 통과 확인** — Run: `flutter test test/features/home/schedule_test.dart` → PASS

- [ ] **Step 5: Commit** — `git commit -m "feat(home): 예약 스마트 가드 도메인 (skip 4종)"`

### Task 2-2: selectable 확장 + repository/notifier guard 배선

**Context:**
- Depends on: 2-1
- Inputs: `ScheduleGuard`, 기존 `ScheduleRepository.create`/`SchedulesNotifier.add`
- Outputs: on/off 액션 선택 가능 + 생성·수정 시 guard 전달 + `addSpan`(2건 생성, off 실패 시 on 롤백)
- Must know: `schedule.dart`의 fanOn~relayOff enum 위 "화이트리스트에 아직 없어 400" 주석은 이제 거짓 — 삭제. `relayOn/Off`는 selectable에 **넣지 않는다**(분무는 `mist`가 정공법). PATCH로 guard 수정: `{'guard': g.toJson()}`, 해제: `{'guard': null}` — 서버가 null 해제를 받는지 400이면 `{'guard': {'enabled': false}}` 폴백(구현 시 실서버 확인, 결과를 코드 주석에 남길 것).
- Acceptance: `flutter analyze` 0 + `flutter test test/features/home/` PASS

**Files:**
- Modify: `lib/features/home/domain/schedule.dart` (selectable, 주석)
- Modify: `lib/features/home/data/schedule_repository.dart` (create에 guard 전달)
- Modify: `lib/features/home/presentation/schedule_providers.dart` (add/updateTiming guard, addSpan)

- [ ] **Step 1: selectable 교체**

```dart
  /// 사용자가 고를 수 있는 것만. toggle 계열은 뺀다 — 예약은 무인 실행이라
  /// 상태가 한 번 어긋나면 반대로 동작한다(§1.1). [relayToggle]·[relayOn]·
  /// [relayOff]도 뺀다 — 분무는 [mist]가 정공법.
  static const selectable = [
    mist, fanOn, fanOff, heaterOn, heaterOff, ledOn, ledOff,
  ];
```

- [ ] **Step 2: repository·notifier에 guard 파라미터 관통** — `ScheduleRepository.create(..., ScheduleGuard? guard)` → `Schedule.createBody(guard: guard)`. `SchedulesNotifier.add(..., ScheduleGuard? guard)`·`updateTiming(..., {ScheduleGuard? guard, bool clearGuard = false})` → patch body에 `if (clearGuard) 'guard': null else if (guard != null) 'guard': guard.toJson()`.

- [ ] **Step 3: addSpan 구현** (`schedule_providers.dart`)

```dart
  /// 구간 예약 — on(시작)·off(종료) 2건 생성.
  ///
  /// **off 실패 시 on을 지우고 다시 던진다.** on만 남으면 기기가 켜진 채
  /// 방치된다 — 히터면 과열이다. 롤백 삭제까지 실패하면 그 사실을 담아
  /// 던져서 화면이 "직접 확인하라"고 말할 수 있게 한다.
  Future<void> addSpan({
    required ScheduleAction onAction,
    required ScheduleAction offAction,
    required ScheduleKind kind,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required List<int> daysOfWeek,
    ScheduleGuard? guard,
  }) async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    final repo = ref.read(scheduleRepositoryProvider);
    final on = await repo.create(deviceId,
        action: onAction, kind: kind,
        hour: startHour, minute: startMinute,
        daysOfWeek: daysOfWeek, guard: guard);
    late final Schedule off;
    try {
      off = await repo.create(deviceId,
          action: offAction, kind: kind,
          hour: endHour, minute: endMinute,
          daysOfWeek: daysOfWeek);
    } catch (e) {
      try {
        await repo.delete(on.id);
      } catch (_) {
        throw ScheduleException(0,
            '종료 예약 생성 실패 + 시작 예약 롤백 실패 — 예약 목록을 확인하세요: $e');
      }
      rethrow;
    }
    state = AsyncData([off, on, ...state.valueOrNull ?? const []]);
  }
```

(가드는 on쪽에만 건다 — "습도 높으면 켜지 마라"가 자연스럽고, off는 조건 없이 꺼져야 안전하다. 코드 주석으로 명시.)

- [ ] **Step 4: 검증 + Commit** — `flutter analyze` 0, `git commit -m "feat(home): 예약 on/off 확장 + 구간 예약 생성(롤백 포함) + guard 배선"`

### Task 2-3: 편집 시트 — [시점|구간] + 가드 섹션

**Context:**
- Depends on: 2-1, 2-2
- Inputs: `ScheduleDraft`(확장), `showScheduleEditor`
- Outputs: 시점/구간 선택, 구간이면 액추에이터(환기/히터/조명)+시작/종료 시각, 가드 옵션 섹션, 히터 경고 문구
- Must know: 수정 모드(`initial != null`)에서는 **구간 탭을 숨긴다**(서버가 action 수정을 안 받고, 쌍 개념도 없다) — 가드·타이밍만 수정. `ScheduleDraft`에 `guard`·`span` 정보를 실어 화면(`routine_settings_screen.dart`)이 `add`/`addSpan`을 분기한다.
- Acceptance: `flutter test test/features/home/routine_settings_screen_test.dart` PASS (가드 저장·구간 저장 시나리오 추가)

**Files:**
- Modify: `lib/features/home/presentation/widgets/schedule_editor_sheet.dart`
- Modify: `lib/features/home/presentation/routine_settings_screen.dart` (`_add`에서 draft.span 분기, pending 카드에서 구간·가드 행 제거 → 카드 자체를 한 줄 각주로 축소: "정지형 가드·히터 타이머는 펌웨어 후속")
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/routine_settings_screen_test.dart`

- [ ] **Step 1: ko.json 키 추가**

```json
"routine_mode_point": "시점",
"routine_mode_span": "구간",
"routine_span_actuator": "기기",
"routine_span_start": "시작",
"routine_span_end": "종료",
"routine_span_heater_warn": "히터 구간 예약은 무인 가동입니다. 안전잠금(50°C)이 있지만 온도 가드를 함께 걸어두세요.",
"routine_guard_section": "스마트 조건",
"routine_guard_off": "사용 안 함",
"routine_guard_humidity_above": "습도가 높으면 건너뛰기",
"routine_guard_humidity_below": "습도가 낮으면 건너뛰기",
"routine_guard_temp_above": "온도가 높으면 건너뛰기",
"routine_guard_temp_below": "온도가 낮으면 건너뛰기",
"routine_guard_value_humidity": "기준 습도 (%)",
"routine_guard_value_temp": "기준 온도 (°C)",
"routine_pending_footnote": "가동 중 자동 정지(정지형 가드)·히터 타이머는 펌웨어 후속 대기입니다."
```

- [ ] **Step 2: ScheduleDraft 확장**

```dart
class ScheduleDraft {
  final ScheduleAction action;      // span이면 onAction
  final ScheduleAction? offAction;  // span일 때만
  final ScheduleKind kind;
  final int hour;                   // span이면 시작
  final int minute;
  final int? endHour;               // span일 때만
  final int? endMinute;
  final List<int> daysOfWeek;
  final Map<String, dynamic>? payload;
  final ScheduleGuard? guard;
  final bool clearGuard;            // 수정에서 가드 해제

  bool get isSpan => offAction != null;
  // 생성자는 기존 필드 + 신규 필드 optional(기본 null/false)
}
```

- [ ] **Step 3: 편집기 UI** — 추가 모드 상단에 `SegmentedButton` [시점|구간]. 구간 선택 시: 액추에이터 ChoiceChip(환기=`fanOn/fanOff`·히터=`heaterOn/heaterOff`·조명=`ledOn/ledOff`), 시작/종료 `ListTile` 시각 2개(자정 넘김 허용 — 검증 없음), 히터 선택 시 경고 문구. 가드 섹션(시점·구간 공통): `routine_guard_off` 포함 5개 ChoiceChip + 기준값 `TextField`(`keyboardType: TextInputType.number`, 습도 0~100 클램프). 저장 시 draft에 담는다.

- [ ] **Step 4: 화면 분기** — `routine_settings_screen.dart` `_add`: `draft.isSpan`이면 `addSpan(...)`, 아니면 기존 `add(..., guard: draft.guard)`. `_edit`: `updateTiming(..., guard: draft.guard, clearGuard: draft.clearGuard)`. `_ScheduleTile` subtitle에 가드 표시(예: `습도>70% 건너뜀`) — 키 재활용.

- [ ] **Step 5: 테스트 추가** — 기존 `routine_settings_screen_test.dart` 패턴을 따라: ① 가드 선택 후 저장 → notifier에 guard 전달 확인 ② 구간 저장 → addSpan 호출 확인 ③ 수정 모드에서 구간 탭 미노출.

- [ ] **Step 6: 검증 + Commit** — `flutter analyze` 0, `flutter test` PASS, pubspec minor bump, `git commit -m "feat(home): 예약 편집기 구간·스마트 가드 지원"` 후 push. **실서버 스모크**: 실기기/시뮬레이터에서 guard 붙은 예약 1건 생성 → GET으로 guard 왕복 확인 + `next_run_at` 표시 확인.

---

## Part 3 — LCD 커스텀 텍스트 (Standard, 메인 직접)

계약: `POST /devices/{id}/lcd {text}` / `POST /devices/{id}/lcd/clear`. 하드 상한 64자, 권장 한글 ~8자/영문 ~12자(한글 1자≈영문 2자). 상태는 `commands-rt`로 추적(핸드오프 §3).

### Task 3-1: TerraRestClient 추출

**Context:**
- Depends on: 없음
- Inputs: `schedule_repository.dart`의 `_send`/`_headers`/`_check`/`_detail`/`ScheduleException`
- Outputs: `lib/core/network/terra_rest_client.dart` — 예약·LCD가 공유하는 REST 공통부. `ScheduleRepository`는 이 클라이언트를 쓰도록 리팩토링(공개 API 불변).
- Must know: `ScheduleException`은 `TerraRestException`으로 개명하고 `schedule_repository.dart`에 `typedef ScheduleException = TerraRestException;`을 남긴다 — 사용처(`routine_settings_screen.dart` 등)와 테스트가 안 깨진다. 401 → 전역 signOut 규칙 유지.
- Acceptance: `flutter test test/features/home/` PASS (기존 예약 테스트 그대로 통과)

**Files:**
- Create: `lib/core/network/terra_rest_client.dart`
- Modify: `lib/features/home/data/schedule_repository.dart`

- [ ] **Step 1: 클라이언트 작성**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// terra-api REST 실패. 화면이 사유를 보여줄 수 있게 상태 코드를 들고 있는다.
class TerraRestException implements Exception {
  final int statusCode;
  final String detail;

  const TerraRestException(this.statusCode, this.detail);

  /// 요청이 잘못된 경우(400) — 앱이 못 만들 값을 보냈다는 뜻이다.
  bool get isBadRequest => statusCode == 400;

  @override
  String toString() => 'TerraRestException($statusCode): $detail';
}

/// terra-api(`https://api.terra-server.uk`) 공통 REST 통로.
///
/// 예약(`ScheduleRepository`)·LCD(`LcdRepository`)가 공유한다. 규칙은 하나다 —
/// Bearer 토큰, 15초 타임아웃, **401이면 전역 로그아웃**, 2xx 밖은
/// [TerraRestException].
class TerraRestClient {
  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final SupabaseClient _supabase;

  TerraRestClient({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    required SupabaseClient supabase,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _supabase = supabase;

  Future<Object?> get(String path) async =>
      _run(() async => http.get(_uri(path), headers: await _headers()));

  Future<Object?> post(String path, [Map<String, dynamic>? body]) async =>
      _run(() async => http.post(
            _uri(path),
            headers: await _headers(withJson: body != null),
            body: body == null ? null : jsonEncode(body),
          ));

  Future<Object?> patch(String path, Map<String, dynamic> body) async =>
      _run(() async => http.patch(
            _uri(path),
            headers: await _headers(withJson: true),
            body: jsonEncode(body),
          ));

  Future<void> delete(String path) async =>
      _run(() async => http.delete(_uri(path), headers: await _headers()));

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Object?> _run(Future<http.Response> Function() send) async {
    final resp = await send().timeout(const Duration(seconds: 15));
    if (resp.statusCode == 401) {
      await _supabase.auth.signOut();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw TerraRestException(resp.statusCode, _detail(resp.body));
    }
    if (resp.body.isEmpty) return null;
    try {
      return jsonDecode(resp.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _headers({bool withJson = false}) async {
    final token = await _tokenProvider();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (withJson) 'Content-Type': 'application/json',
    };
  }

  String _detail(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {
      // 본문이 JSON이 아니면 그대로 쓴다.
    }
    return body;
  }
}
```

- [ ] **Step 2: ScheduleRepository 리팩토링** — 내부 `_send`/`_headers`/`_check`/`_detail` 삭제, 생성자를 `ScheduleRepository(TerraRestClient client)`로. `schedule_providers.dart`의 `scheduleRepositoryProvider`가 클라이언트를 만들어 주입. `typedef ScheduleException = TerraRestException;` 유지.

- [ ] **Step 3: 검증 + Commit** — `flutter analyze` 0, `flutter test test/features/home/` PASS, `git commit -m "refactor(core): terra-api REST 공통부 TerraRestClient 추출"`

### Task 3-2: LcdRepository + 설정 UI

**Context:**
- Depends on: 3-1
- Inputs: `TerraRestClient`, `enclosure_settings_screen.dart`
- Outputs: LCD 텍스트 입력 진입점(사육장 설정 화면 타일 → 시트) + `LcdRepository.setText/clear`
- Must know: ① 빈 문자열 → 서버가 clear 처리하지만 앱은 명시적으로 `/lcd/clear`를 부른다(의도가 분명). ② `maxLength: 64` + 권장 한도 힌트(한글~8/영문~12) — 초과 시 서버가 자동 축소하므로 하드 차단은 64만. ③ 응답 action `lcd_bitmap`/`lcd_clear`가 `commands` 목록에 흐르므로 `CommandAction`에 추가하되 **`_kindByAction`(actuator_marker.dart)에는 넣지 않는다** — LCD는 액추에이터 동작이 아니라 차트 마커가 아니다. 다만 그 파일 주석에 "lcd_*는 의도적으로 제외"를 남겨 "새 명령 추가 시 같이 고칠 것" 규칙과 충돌하지 않게 한다.
- Acceptance: `flutter analyze` 0 + 위젯 테스트 PASS

**Files:**
- Create: `lib/features/my_cage/data/lcd_repository.dart`
- Modify: `lib/features/my_cage/domain/device_command.dart` (lcdBitmap/lcdClear)
- Modify: `lib/shared/domain/actuator_marker.dart` (주석만)
- Modify: `lib/features/my_cage/presentation/enclosure_settings_screen.dart`
- Modify: `assets/l10n/ko.json`
- Test: `test/features/my_cage/lcd_sheet_test.dart`

- [ ] **Step 1: ko.json 키**

```json
"lcd_tile_title": "LCD 문구",
"lcd_tile_subtitle": "사육장 화면 상단에 표시할 텍스트",
"lcd_sheet_title": "LCD 문구 설정",
"lcd_hint": "예: 밥 6시",
"lcd_length_hint": "권장 한글 8자 · 영문 12자 (최대 64자, 넘으면 자동 축소)",
"lcd_apply": "적용",
"lcd_reset": "기본값 복원",
"lcd_sent": "LCD에 전송했습니다",
"lcd_failed": "LCD 전송 실패: {}"
```

- [ ] **Step 2: LcdRepository**

```dart
import '../../../core/network/terra_rest_client.dart';

/// 디바이스 LCD 상단 커스텀 텍스트 (핸드오프 §3).
///
/// 서버가 비트맵으로 렌더해 전송하고 디바이스에 저장된다(재부팅 유지).
/// 상태 추적이 필요하면 응답의 command id로 `commands-rt`를 보면 되지만,
/// 지금 UI는 발행 성공/실패 토스트까지만 한다.
class LcdRepository {
  final TerraRestClient _client;

  LcdRepository(this._client);

  Future<void> setText(String deviceId, String text) =>
      _client.post('/devices/$deviceId/lcd', {'text': text}).then((_) {});

  Future<void> clear(String deviceId) =>
      _client.post('/devices/$deviceId/lcd/clear').then((_) {});
}
```

Provider(`enclosure_settings` 쪽 presentation): `lcdRepositoryProvider` = `Provider((ref) => LcdRepository(ref.watch(terraRestClientProvider)))` — `terraRestClientProvider`는 3-1 리팩토링 때 `schedule_providers.dart`에서 만든 것을 `core` 쪽으로 옮겨 공유(`lib/shared/providers/` 관례 확인 후 배치).

- [ ] **Step 3: CommandAction 추가** — `device_command.dart` enum에 `lcdBitmap`·`lcdClear` + `toWire`(`'lcd_bitmap'`/`'lcd_clear'`) + `fromWire` case. `actuator_marker.dart` `_kindByAction` 위 주석에 한 줄: `// lcd_bitmap/lcd_clear는 의도적으로 없다 — 화면 표시는 기기 동작 마커가 아니다.`

- [ ] **Step 4: 설정 화면 타일 + 시트** — `enclosure_settings_screen.dart`에 `ListTile(title: lcd_tile_title, subtitle: lcd_tile_subtitle)` → `showModalBottomSheet`: `TextField(maxLength: 64, hint: lcd_hint)` + `lcd_length_hint` 캡션 + `[기본값 복원][적용]` 버튼 행. 적용 → `setText`, 복원 → `clear`, 성공/실패 스낵바(`lcd_sent`/`lcd_failed`). 기기 오프라인이면 기존 `DeviceOfflineNotice` 관례대로 사유 표시.

- [ ] **Step 5: 위젯 테스트** — 시트 렌더 + 적용 탭 시 repository 호출(mock) + 64자 초과 입력이 잘리는지.

- [ ] **Step 6: 검증 + Commit** — `flutter analyze` 0, `flutter test` PASS, pubspec minor bump, `git commit -m "feat(my_cage): LCD 커스텀 텍스트 설정 (REST)"` 후 push

---

## 마무리 Task: 문서 정합

- [ ] `RoutineSettingsScreen` 상단 doc comment 표를 현행화 (§4.2.1 ✅ 팬 / §4.2.2 구간·가드 ✅)
- [ ] CLAUDE.md "핵심 feature" 예약 항목에 guard·구간·LCD 반영, 미구현 목록에서 해소분 제거
- [ ] `docs/prd-implementation-gap.md` §4.2 타이머&일정 상태 갱신
- [ ] 핸드오프 체크리스트(§6) 대조: 밝기 슬라이더(보드 구분 대기)·감사 로그(디자인 대기)만 미완으로 남는지 확인

## Self-Review 결과

- **Spec coverage:** 핸드오프 §6 체크리스트 8항 중 — 분무·on/off·result 처리는 기구현, 팬 타이머=Part 1, 예약 CRUD+가드=Part 2, LCD=Part 3. LED 밝기·감사 로그는 명시적 제외(사유 기록). 커버리지 공백 없음.
- **Placeholder scan:** "구현 시 판단" 2곳(2-2 guard null 해제 폴백, 1-3 Step 5 ko.json 키 삭제)은 실서버/실코드 확인이 필요한 지점이라 판단 기준까지 명시해 남겼다. 그 외 코드 없는 코드 스텝 없음.
- **Type consistency:** `fanTimerFrom`(1-2 정의 ↔ 1-3 사용), `ScheduleGuard`/`GuardType`(2-1 정의 ↔ 2-2·2-3 사용), `TerraRestClient`/`TerraRestException`(3-1 정의 ↔ 3-2 사용) 일치 확인.
