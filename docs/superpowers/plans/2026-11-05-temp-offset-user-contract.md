# 온도 보정 새 계약(`user_offset_c`·`temp_offset_user_c`) — 앱 구현 계획

> **구현 방식 (CAOF):** Critical 트랙(8개 파일 + 테스트, 서버 배포 순서 의존). 사용자 승인 뒤 task 단위로 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **사용자 결정 (2026-11-05):** 서버 문서를 그대로 믿고 앱만 고친다. D1·D3은 추천안(a). Q1은 보내지 않는다 — A5(배포 때 꺼져 있던 기기의 일시 잠금)는 받아들인 한계다. 스위치는 서버 문서 맨 위가 '배포 완료'로 바뀐 것을 확인한 뒤 켠다.
>
> **r2 (2026-11-05):** 교차 검수(Codex 12건 + Claude 16건)를 반영했다. 결과는 `2026-11-05-temp-offset-user-contract-review-final.md`.

**Goal:** 공장 보정 −1.5℃를 서버가 맡는 새 계약에 맞춰, 앱이 사용자 보정값만 보내고(`user_offset_c`) 읽게(`temp_offset_user_c`) 한다. 서버 배포 전에는 지금 동작(합산값 `offset_c`·`temp_offset_c`)을 그대로 유지한다.

**Architecture:**
- 지금은 `deviceOffsetProvider`가 기기 값(합산, `double?`)을 내보내고, 화면 두 곳과 저장기가 각자 `TempOffset.fromDevice`·`toDeviceValue`로 −1.5를 더하고 뺀다.
- 이것을 **행 → 사용자 보정값으로 바꾸는 순수 함수 하나**(`userOffsetFromRow`)와 **`TempOffset?`를 내보내는 provider 하나**로 모은다. 조회·실시간 행·목록 대체값이 모두 이 함수를 거친다. 그래서 계약에 따라 갈리는 곳은 이 함수와 전송 키 두 곳뿐이다.
- 새 계약은 스위치 `FeatureFlags.tempOffsetUserContract`(기본 false)로 막아 둔 채 main에 합친다. 서버의 "배포 완료" 통보 뒤에 스위치만 켠다(서버 문서 §6). 서버보다 먼저 켜면 조회가 실패하고 명령이 400으로 거절된다.

**Tech Stack:** Flutter, Riverpod, Supabase(PostgREST·Realtime), terra REST

**Spec:** `/Users/baek/terra-server/docs/APP_TEMP_OFFSET_SERVER_BASE_2026-11-05.md`(계약 확정, 서버 배포 전)

## 가정

| # | 가정 | 상태 |
|---|---|---|
| A1 | `deviceOffsetProvider`·`Device.tempOffsetC`·`TempOffset.fromDevice/toDeviceValue/measuredFrom`의 사용처는 다음뿐이다: 보정 화면, 온습도 설정, 저장기, 전송, 조회(`fetchTempOffset`) | **확인**(grep, 검수 2회 재확인) |
| A2 | 화면의 "현재 측정 온도" = 보고 온도 − 사용자 보정 | 확인(`env_thresholds.dart:189`) |
| A3 | 새 거절 `result`(`invalid_payload`·`offset_out_of_range`)는 저장기의 "ok가 아니면 rejected"로 처리된다 | 확인(`temp_offset_providers.dart:161-168`) |
| A4 | 구 펌웨어(사용자값 null)는 지금처럼 잠겨 명령을 보내지 않는다 | 확인(`temp_humid_setting_screen.dart:136`) |
| A5 | 서버는 새 컬럼을 **다음 기기 보고 때부터** 채운다. 배포 시점에 꺼져 있던 기기는 다시 켜져 보고할 때까지 null이라, 스위치를 켠 앱에서 "펌웨어 업데이트 필요"로 잘못 잠긴다 | 서버 문서 §2 — **서버에 migration 때 `temp_offset_user_c = temp_offset_c + 1.5`로 채워 달라고 요청한다**(Q1) |
| A6 | 테스트에 PostgREST 가짜가 없다. 그래서 조회는 쿼리가 아니라 순수 함수(`userOffsetFromRow`)와 컬럼 이름 함수로 검증한다 | 확인(검수, grep 0건) |

## 사용자가 정할 것

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| D1 | 지금 할지 | (a) 지금 스위치를 꺼 둔 두 경로를 만들어 두고, 서버 배포 뒤 스위치만 켬 (b) 서버 배포를 기다렸다가 새 계약만 구현(옛 경로 삭제까지 한 번에) | **(a)** — 계약이 갈리는 곳을 함수 하나로 모으면 두 경로 비용이 작다. 서버 배포 뒤 남는 일이 "한 줄 + 실기 확인"이라 배포 직후 바로 대응할 수 있다. (b)는 코드가 적지만, 서버 배포 통보 때 다시 Critical 작업을 해야 한다 |
| D2 | 옛 경로(`offset_c`·`factoryDeviceValue`) 제거 시점 | 스위치를 켜고 실기 확인한 뒤 정리 커밋 | 추천대로 |
| D3 | 새 계약에서 "명령 ack ok인데 15초 안에 보고값이 안 맞음"을 어떻게 볼지 | (a) 지금처럼 성공 (b) 실패("응답이 없어요") | **(a)** — 서버 §3은 "보고값 일치 = 완료"이지만, ack ok는 기기가 적용했다는 뜻이다. 보고만 늦은 경우를 실패로 보이면 사용자가 다시 누른다. 지금 옛 계약과 같은 동작이다 |

## 서버에 물을 것

- **Q1:** migration 때 기존 행의 `temp_offset_user_c`를 `temp_offset_c + 1.5`(공장 보정 서버 설정)로 채워 줄 수 있는가(A5). 안 되면 앱은 "오프라인이던 기기는 다시 연결될 때까지 보정 잠김"을 받아들인다.

## 유저 체험 시뮬레이션 (스위치를 켠 뒤, 서버 배포 완료 상태)

1. 온습도 설정의 "온도 보정" 토글은 사용자값이 0이면 꺼짐, 아니면 켜짐과 "보정 값 −2.0℃"로 보인다. 지금과 화면이 같다.
2. 보정값 설정에서 "빼기 2.0"을 저장하면 `{"user_offset_c": -2.0}`이 나간다. 약 3~5초 뒤 기기 보고로 사용자값이 −2.0이 되면 "저장됨"으로 화면이 닫힌다.
3. 보정을 끄면 `{"user_offset_c": 0}`이 나간다. 기기에는 서버가 −1.5를 건다.
4. 구 펌웨어 기기(사용자값 null)는 지금처럼 "펌웨어 업데이트 후 사용할 수 있어요"가 나오고 토글이 잠긴다.
5. 스위치가 꺼진 지금 빌드에서는 1~4가 모두 지금과 똑같이 동작한다(합산값 경로). 생존 신호로 기기 행이 3초마다 바뀌어도 화면이 다시 그려지지 않는다.

## Global Constraints

- **스위치:** `FeatureFlags.tempOffsetUserContract = false`(`lib/core/config/feature_flags.dart`)와 테스트용 `tempOffsetUserContractProvider = Provider<bool>`. 읽는 곳은 `deviceOffsetProvider`(조회·실시간), `userOffsetOf(Device)` 호출(목록 대체값), `tempOffsetRepositoryProvider`(전송) 셋이다. 실제 분기 로직은 `userOffsetFromRow`·`tempOffsetColumn`·`TempOffsetRepository.send` 안에만 둔다.
- **허용 범위:** 새 계약의 읽기는 **−8.5 ~ +11.5**(서버 §2)다. 이 숫자는 공장 보정 −1.5와 기기 허용 ±10에서 나왔다는 출처를 상수 주석에 남긴다. 범위 밖이면 null로 둔다.
- **숫자 파싱:** 기존 `parseDouble`(숫자 문자열 허용)을 그대로 쓴다. `Device.parseTempOffset`과 같은 규칙이다.
- **반올림:** 비교와 전송은 0.1 단위로 맞춘다. `TempOffset`의 const 생성자는 단위를 보장하지 않으므로 보낼 때 `_tenths(value)/10`으로 한 번 맞춘다.
- **키 혼용 금지:** 한 명령에 `offset_c`와 `user_offset_c`를 같이 보내지 않는다(서버가 400으로 거절).
- **커밋:** 스위치가 꺼진 동안의 작업은 커밋 두 개(Task 1, Task 2)다. 각 커밋은 `flutter analyze` 0 + 관련 테스트 통과, 버전 patch + CHANGELOG "변경(내부)".
- **건드리지 않는 것:**
  - 보정 화면 UI·문구·Figma 수치
  - 저장 15초 대기와 명령 행 감시 흐름(D3-a)
  - 온습도 실시간 표시(`t_a`)
  - `Device.tempOffsetC` 필드(옛 경로용, D2에서 정리)

## Review Focus

1. **계약 혼선** — 스위치 꺼짐 빌드가 새 컬럼을 읽거나, 켠 빌드가 `offset_c`를 보내면 안 된다. → Task 1·2 테스트: 스위치 두 값 × 컬럼 이름·행 해석·전송 키.
2. **같은 값 재방출** — `TempOffset`에 값 비교가 없으면, 생존 신호 UPDATE마다 새 객체가 나와 화면이 계속 다시 그려진다. → Task 1: `==`/`hashCode`(0.1 단위). Task 2: 같은 값의 행 두 번 → 방출 한 번.
3. **키가 없는 실시간 행** — 새 계약인데 `newRecord`에 `temp_offset_user_c` 키가 없으면 무시한다(null로 덮어 "미지원"으로 바뀌지 않게). → Task 1 `userOffsetFromRow`가 "모름(무시)"과 "null(구 펌웨어)"을 구분한다.
4. **목록 대체값 이중 변환** — 온습도 설정이 조회 실패 시 쓰는 `device.tempOffsetC`가 남은 유일한 `double` 경로다. → Task 2: `userOffsetOf(Device)`를 거치게 하고, 두 계약 테스트를 둔다.
5. **오프라인이던 기기**(A5) — 서버 Q1 회신 전까지는 받아들인 한계로 둔다. Task 3 실기 확인 항목에 넣는다.

---

### Task 1: 도메인 — 사용자값 해석·값 비교·스위치

**Files:**
- Modify: `lib/core/config/feature_flags.dart`
- Modify: `lib/shared/domain/env_thresholds.dart`(`TempOffset`)
- Modify: `lib/features/my_cage/domain/device.dart`
- Test: `test/shared/domain/env_thresholds_test.dart`, `test/features/my_cage/device_settings_range_test.dart`

**Context:**
- Depends on: 없음
- Produces:
  - `FeatureFlags.tempOffsetUserContract`(const false), `tempOffsetUserContractProvider`
  - `TempOffset`의 `operator ==`·`hashCode`(0.1 단위 정수 기준)
  - `static const double TempOffset.userMin = -8.5, userMax = 11.5`(주석: 공장 −1.5 + 기기 ±10, 서버 §1·§2)
  - `static TempOffset? TempOffset.parseUser(Object? raw)` — `parseDouble` → 범위 안이면 0.1 단위로 맞춘 값, 아니면 null
  - `static double TempOffset.measuredFromUser(double reported, TempOffset user)` = `reported − user.value`. 기존 `measuredFrom`은 이것을 거친다.
  - `String tempOffsetColumn({required bool userContract})` → `'temp_offset_user_c'` / `'temp_offset_c'`
  - `({bool known, TempOffset? offset}) userOffsetFromRow(Map<String, dynamic> row, {required bool userContract})`
    - 해당 컬럼 키가 행에 없으면 `known: false`(호출부는 무시한다)
    - 있으면 `known: true`. 새 계약은 `parseUser`, 옛 계약은 `Device.parseTempOffset` → `fromDevice`
  - `TempOffset? userOffsetOf(Device d, {required bool userContract})` — 새 계약은 `d.tempOffsetUserC`, 옛 계약은 `d.tempOffsetC`를 `fromDevice`로
  - `Device.tempOffsetUserC`(`TempOffset?`, `parseUser`)
  - 위 함수들은 `env_thresholds.dart`(순수) 또는 `device.dart`에 둔다. `userOffsetOf`는 `Device`를 알아야 하므로 `device.dart`.
- Acceptance: 아래 테스트 PASS, analyze 0.

- [ ] **Step 1: 실패하는 테스트**

```dart
test('parseUser — 범위·단위·숫자 문자열', () {
  expect(TempOffset.parseUser(1.0), const TempOffset(1.0));
  expect(TempOffset.parseUser('1.0'), const TempOffset(1.0));
  expect(TempOffset.parseUser(11.5), const TempOffset(11.5));
  expect(TempOffset.parseUser(-8.6), isNull);
  expect(TempOffset.parseUser(null), isNull);
  expect(TempOffset.parseUser(-2.04), const TempOffset(-2.0));
});
test('값 비교는 0.1 단위', () {
  expect(const TempOffset(1.0) == const TempOffset(1.0), isTrue);
  expect(const TempOffset(1.0).hashCode, const TempOffset(1.0).hashCode);
  expect(const TempOffset(1.0) == const TempOffset(1.1), isFalse);
});
test('행 해석 — 계약별 컬럼, 키 없음은 모름', () {
  final row = {'temp_offset_c': -3.5, 'temp_offset_user_c': -2.0};
  expect(userOffsetFromRow(row, userContract: true).offset, const TempOffset(-2.0));
  expect(userOffsetFromRow(row, userContract: false).offset, const TempOffset(-2.0));
  expect(userOffsetFromRow({'temp_offset_c': -3.5}, userContract: true).known, isFalse);
  expect(userOffsetFromRow({'temp_offset_user_c': null}, userContract: true),
      (known: true, offset: null));
  expect(tempOffsetColumn(userContract: true), 'temp_offset_user_c');
});
test('측정값 = 보고 − 사용자 보정', () =>
    expect(TempOffset.measuredFromUser(25.0, const TempOffset(1.0)), 24.0));
test('Device.temp_offset_user_c·userOffsetOf', () {
  final d = Device.fromJson({...base, 'temp_offset_c': -3.5, 'temp_offset_user_c': -2.0});
  expect(d.tempOffsetUserC, const TempOffset(-2.0));
  expect(userOffsetOf(d, userContract: false), const TempOffset(-2.0));
  expect(userOffsetOf(Device.fromJson(base), userContract: true), isNull);
});
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS·analyze 0**
- [ ] **Step 5: 커밋** `feat(temp-offset): 사용자 보정값 해석·값 비교·새 계약 스위치(꺼짐)` — patch + CHANGELOG "변경(내부)"

### Task 2: 조회·실시간·전송·화면을 사용자값 기준으로 (한 커밋)

컴파일이 한꺼번에 바뀌므로 나누지 않는다(검수 지적).

**Files:**
- Modify: `lib/features/my_cage/data/supabase_module_control_repository.dart`(`fetchTempOffset` → `Future<TempOffset?> fetchUserTempOffset(String deviceId, {required bool userContract})`)
- Modify: `lib/features/my_cage/data/temp_offset_repository.dart`(`TempOffsetRepository(this._rest, {this.userContract = false})`, `send`)
- Modify: `lib/features/home/presentation/temp_offset_providers.dart`(`deviceOffsetProvider` → `StreamProvider.autoDispose.family<TempOffset?, String>`, 저장기)
- Modify: `lib/features/home/presentation/temp_offset_screen.dart`, `lib/features/home/presentation/temp_humid_setting_screen.dart`
- Test:
  - `test/features/my_cage/temp_offset_repository_test.dart`
  - `test/features/home/temp_offset_screen_test.dart`(`_Device` 스트림·`report()`·`deviceOffset:` 23곳을 `TempOffset`으로, `_OffsetRepo`에 `userContract`)
  - `test/features/home/temp_humid_setting_screen_test.dart`(107-111행 override)
  - `test/features/home/env_v4_screen_fixtures.dart`(`tempOffsetC: -3.5` → provider override 값 `TempOffset(-2.0)`)

**Context:**
- Depends on: Task 1
- Consumes: `userOffsetFromRow`, `tempOffsetColumn`, `userOffsetOf`, `TempOffset.==`, `tempOffsetUserContractProvider`
- Produces: `deviceOffsetProvider(deviceId)`가 사용자 보정값(`TempOffset?`, null = 구 펌웨어)을 내보낸다.
- Must know:
  - **조회:** `select(tempOffsetColumn(...))` → `userOffsetFromRow(row, ...)`. 행이 없으면 null.
  - **실시간:** `newRecord`를 `userOffsetFromRow`로 해석하고, `known == false`면 무시한다. 같은 값은 `==`로 걸러 방출하지 않는다.
  - **전송:** 새 계약이면 `{'user_offset_c': _tenths(value)/10}`, 옛 계약이면 `{'offset_c': toDeviceValue()}`.
  - **저장기:** "이미 그 값"과 완료 판정 모두 `TempOffset ==`로 비교한다. ack ok 뒤 15초 대기는 그대로 둔다(D3-a).
  - **화면:** `fromDevice`를 부르지 않는다. 측정값은 `measuredFromUser(reported, saved)`. 온습도 설정의 목록 대체값은 `userOffsetOf(device, userContract: ...)`.
- Acceptance: 아래 테스트 PASS. 기존 보정 화면·온습도 설정·상세 테스트의 **화면 기대값은 바뀌지 않는다**(측정 26.2 등).

- [ ] **Step 1: 실패하는 테스트**

```dart
// temp_offset_repository_test.dart (기존처럼 경로와 본문을 따로 단언)
test('새 계약 — user_offset_c만, 0.1 단위', () async {
  await TempOffsetRepository(fake, userContract: true).send('d1', const TempOffset(-2.04));
  expect(fake.lastPath, '/devices/d1/commands');
  expect(fake.lastBody?['payload'], {'user_offset_c': -2.0});
});
test('옛 계약 — offset_c 합산(끔 = −1.5)', () async {
  await TempOffsetRepository(fake).send('d1', const TempOffset(0));
  expect(fake.lastBody?['payload'], {'offset_c': -1.5});
});
// 저장기 — 두 계약 모두 사용자값으로 완료(provider가 TempOffset(-2.0)을 내면 saved)
// 화면 — 기존 기대값(측정·보정 온도·"−2") 그대로
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS·analyze 0**
- [ ] **Step 5: 시뮬레이터 확인** — 스위치 꺼짐 빌드로 보정 화면과 온습도 설정이 지금과 같은지 본다(현재 보정값, 측정 온도, 보정 온도). Claude가 직접 확인한다.
- [ ] **Step 6: 커밋** `refactor(temp-offset): 보정을 사용자값 하나로 모으고 계약별 조회·전송(새 계약 꺼짐)` — patch + CHANGELOG "변경(내부)"

### Task 3: 스위치 켜기 (서버 "배포 완료" 통보 뒤 — 지금은 하지 않음)

- [ ] 서버 문서 맨 위가 `배포 완료 2026-11-XX`이고 커밋 링크를 받았는지 확인한다. Q1(기존 행 채움) 회신을 확인한다.
- [ ] `FeatureFlags.tempOffsetUserContract = true`, `flutter test` 전체 PASS.
- [ ] 실기 확인(사용자 또는 QA 세션)
  - 보정 켬 −2.0 저장 → `temp_offset_user_c = -2.0`, 화면 "−2"
  - 끔 → 0
  - 구 펌웨어 기기 → 잠김
  - 서버 배포 때 꺼져 있던 기기 → 다시 연결된 뒤 잠금이 풀림
- [ ] 커밋 `feat(temp-offset): 새 보정 계약 켜기` — minor + CHANGELOG "변경". CLAUDE.md에는 보정 문단이 없으므로 "온도 보정" 한 문단을 새로 쓴다(계약 위치, 사용자값 기준, 스위치).
- [ ] (D2) 실기 확인 뒤 `fromDevice`·`toDeviceValue`·`factoryDeviceValue`·옛 분기를 지우는 정리 커밋.

## 검증 방법

- **명령:** `flutter analyze`(에러 0), 아래 테스트, 마지막에 `flutter test` 전체.

  ```bash
  flutter test test/shared/domain/env_thresholds_test.dart test/features/my_cage/ test/features/home/temp_offset_screen_test.dart test/features/home/temp_humid_setting_screen_test.dart test/features/home/env_detail_screen_test.dart test/features/home/ test/design/text_scale_overflow_test.dart
  ```

- **스위치 꺼짐 회귀:** Task 2 Step 5 시뮬레이터 확인.
- **새 계약 실동작:** Task 3 — **사용자 또는 QA 세션만 확인 가능**(서버 배포 필요).

## 실패 시나리오

| 상황 | 결과 | 대응 |
|---|---|---|
| 스위치를 서버 배포 전에 켬 | 조회 실패 → 보정 화면 "불러오지 못함", 명령 400 | Task 3 첫 단계에서 통보 확인 |
| 서버 배포 때 꺼져 있던 기기 | 스위치를 켠 앱에서 다시 보고할 때까지 보정 잠김 | 서버 Q1(기존 행 채움). 안 되면 받아들인 한계로 둔다 |
| 생존 신호마다 재방출 | 보정 화면이 3초마다 다시 그려짐 | Task 1 `==`, Task 2 재방출 테스트 |
| 목록 대체값에 옛 변환이 남음 | 조회 실패 시 1.5℃ 틀린 값 | `userOffsetOf` 한 곳만 쓰게 한다 |
