# v4 온습도 알림·설정·온도 보정 (앱 1단계) Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙 — 새 화면 4개 + 푸시 계약 + Supabase 마이그레이션. 승인 후 task 단위로 flutter-dev에게 넘긴다(GATE 4). Steps use checkbox (`- [ ]`) syntax for tracking.
> 상태: 📝 초안 2026-11-02 — 사용자 승인 대기. 서버가 앱에 보낼 요청 문서(예고됨)를 받으면 §0 "대기" 항목과 Task 2·8을 다시 맞춘다.

**Goal:** 크레스티드 게코 기준 적정 온습도(MIN/MAX)·온도 보정을 앱에서 설정하고, 서버 v4 실시간 판정(`alerts` env_*)을 온습도 상세 화면 카드와 푸시로 보여 준다.

**Architecture:** 설정은 기존 REST(`/devices/{id}/settings`)와 기기 명령(`set_temp_offset`)으로 쓰고, 화면은 Figma `1635:6166`대로 새 라우트 묶음(`/env-detail/settings/...`)에 둔다. 실시간 판정은 서버가 하므로 앱은 `alerts`의 열린 env_* 행을 Realtime으로 읽어 그리기만 한다. 푸시는 `env.alert.triggered`를 기존 notification-ingest → `app_notifications` → outbox 경로에 붙이고, 수신 끔은 서버 DB 설정으로 outbox 단계에서 거른다.

**Tech Stack:** Flutter + Riverpod + GoRouter + easy_localization, Supabase(PostgREST·Realtime·Edge Function, plpgsql 마이그레이션), node:test(`supabase/functions/_shared`)

**Spec:**
- 기획: 노션 "비바나트 앱 (사육장, 캠)" › 사육 위키 › **v4. 최종 정리 중** (2026-11-02 수정본) — 0, 1-1~1-6
- Figma: [`docs/design-audits/2026-11-02-env-alerts-v4/README.md`](../../design-audits/2026-11-02-env-alerts-v4/README.md) (화면 지도·코드 A**/S**), 수치는 같은 폴더 `figma-structure-*.md`
- 서버: terra-server `feat/env-alerts-v4`(`b4cf8ca`) `docs/APP_ENV_ALERT_PUSH_2026-11-02.md`, `specs/stage-n-env-alerts-v4.md`

---

## 0. 범위 — 이번 계획 / 대기

| 구분 | 내용 | 근거 |
|---|---|---|
| **이번 계획 (Task 1~9)** | 온습도 설정 화면, 적정 온도·습도 설정, 보정값 설정, 온습도 상세 범위 바·설정 진입, 실시간 카드(env_* alerts), `env.alert.triggered` 푸시, 수신 끔 서버 설정, 알림 설정 진입 | 서버 Stage N 계약이 확정돼 있음 |
| 대기 — 서버 Stage O | 환기 지연·분무 필요 카드/푸시 (A26 하단, A36 하단) | 서버 "습기 사이클(Stage O)" 미착수 |
| 대기 — 서버 Stage P | 일간 분석 카드 (A14~A18, A27, A28) | 서버 일일 분석 미착수 |
| 대기 — 서버 Stage Q | 주간 분석 카드 + 주간 막대 그래프 재디자인 (A19~A34) | 서버 주간 분석 미착수 |
| 대기 — 서버·펌웨어 | 자동 환기·자동 분무 토글 (S41~S44) | 서버·펌웨어 어디에도 기능 없음(`auto_vent` 등 0건, 2026-11-02 grep) |
| 대기 — 서버 Stage N2 | 서버 쪽 MIN/MAX 범위 검증 | 앱이 범위 밖 값을 안 보낸다는 확인 후 서버 배포 — Task 2가 그 확인 근거 |

대기 항목은 서버 요청 문서를 받은 뒤 별도 계획으로 쓴다.

## Global Constraints

- 대상 종: 크레스티드 게코. 다른 종 기준은 이번 범위 밖(기획 v4 머리말).
- 온도: 디폴트 MIN **18℃**, MAX **26℃**. 설정 범위 **15℃ 이상 29℃ 이하**, **0.5℃** 단위, **MIN < MAX**. 경고 **15℃ 미만 / 29℃ 초과**(15.0·29.0은 경고 아님).
- 습도: 디폴트 MIN **40%**, MAX **80%**. 설정 범위 **35% 이상 85% 이하**, **5%** 단위, **MIN < MAX**.
- 적정 범위 = MIN ≤ 값 ≤ MAX(경계 포함).
- 온도 보정: 크기 **0.1~4.0℃, 0.1 단위**, 방향 빼기/더하기(Figma S24). 기기 명령 허용 범위는 ±10.0(서버 `TEMP_OFFSET_LIMIT_C`).
- 판정·분석은 **보정된 값**(기기가 보정해 보낸 `t_a`) 기준. 보정 변경은 이후 데이터부터, 과거 데이터·분석은 그대로.
- 실시간 판정·푸시 판단은 **서버만** 한다. 앱은 판정 로직을 복제하지 않는다.
- 푸시는 타이틀만(1-5). 문구는 서버 `payload.title` 그대로 쓴다(Task 8 결정).
- 푸시 수신 끔이어도 기록은 남긴다(`app_notifications`는 쌓고 outbox만 건너뜀).
- 설정 쓰기는 REST만(`PATCH /devices/{id}/settings`) — Supabase 직결 UPDATE 금지(기존 규칙). 보정은 기기 명령으로만.
- 로딩은 shimmer, 문자열은 `ko.json`, 색은 `context.glass`/VIVA 역할색, 글자 크기는 Figma 그대로(CLAUDE.md).
- 건드리지 않는 것: 홈 `EnvSummaryCard`·라이브 오버레이 표시 규칙(`envLiveViewProvider`), 온습도 상세 **주간** 탭, 사육장 제어 기록, 펌웨어 발 `alerts`(`temp_high`·`heater_latched` 등), 기존 `safety.*`·`device.action.*` 푸시, 환기팬·분무 시트.

## 유저 체험 시뮬레이션

1. 홈 온습도 카드 → **온습도 상세**. 왼쪽 위 ✕, 오른쪽 위 설정 아이콘(S03). 오늘 화면 맨 위 줄은 `22.0℃ 15 ━━●━━ 26`: 왼쪽은 현재값, 바 양끝은 오늘 지금까지 최저(15)·최고(26), 바 안의 진한 구간은 적정 18~24다(A04).
2. 오후 2시 온도가 15℃ 아래로 2분 넘게 머문다 → 서버가 판정 → 폰에 푸시 "[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요". 누르면 온습도 상세로 간다.
3. 화면 그래프 아래에 회색 카드가 생긴다: 빨간 칩 **저온 경고** · "온도가 너무 낮아 개체가 위험할 수 있어요" · "즉시 온도를 올려주세요". 습도도 이탈 중이면 같은 카드 안에 줄이 하나 더 생긴다(A10). 적정 범위로 5분 돌아오면 카드 줄이 사라진다.
4. 설정 아이콘 → **온습도 설정**(S04). 온도 보정 꺼짐, 이탈 알림 켜짐, 적정 온도 18℃ ~ 26℃.
5. 적정 온도 행 → **적정 온도 설정**(S08). 최소 −를 한 번 → 17.5. 아래에 "변경 사항 취소"가 나타난다(S10). 최대 +를 눌러 29가 되면 + 버튼이 흐려진다. 저장 → 이전 화면에 "17.5℃ ~ 29℃". 서버는 60초 안에 새 기준으로 판정한다.
6. 온도 보정 토글 켬 → "보정 값 · 설정하기"가 나타나지만 아직 아무것도 바뀌지 않는다(S45). 설정하기 → **보정값 설정**(S14): 현재 측정 26.2℃, 보정 온도 26.1℃, "빼기"가 선택되고 0.1. 더하기로 바꾸고 1.0까지 밀면 보정 온도 27.2℃. 저장 → 온습도 설정에 "측정값 +1℃". 처음 들어와서 바로 취소하면 보정은 꺼진 상태로 돌아간다(S46). 한 번 저장한 뒤 다시 들어와 고치다 취소하면 저장해 둔 값으로 돌아간다(S47).
7. 습도 이탈 알림을 끈다 → 습도 주의 푸시가 더 오지 않는다. 온습도 상세 카드는 계속 보인다.
8. 마이페이지 › 알림 설정 → "온습도 이탈 알림 · 설정하기"(S39) → 같은 온습도 설정 화면.

## 가정

| # | 가정 | 상태 |
|---|---|---|
| G1 | 앱이 `alerts`를 읽을 수 있다 — `own alerts select` RLS + Realtime publication에 `alerts` 포함 | **확인**(운영 DB, 2026-11-02) |
| G2 | `devices.temp_offset_c` = 기기가 지금 적용 중인 보정값, `t_a`는 보정 후 값. 원래 측정값 = `t_a − temp_offset_c` | **확인**(서버 `handlers.py:986`, `docs/MQTT.md:90`) |
| G3 | 펌웨어 빌드 기본 보정이 **−1.5℃**(`CONFIG_APP_TEMP_OFFSET_MDEG`) → 새 기기도 이미 −1.5 적용 중 | **확인**(MQTT.md). 앱 표시 의미는 결정 필요(D1) |
| G4 | 앱이 `POST /devices/{id}/commands` `set_temp_offset`을 써도 된다(현재 "운영 콘솔 대행용"이라 적힘) | **미확인** — 서버 요청 문서에서 확인 |
| G5 | 서버 v4 판정이 `device_settings.target_temp_min/max·target_humid_min/max`를 60초 TTL로 읽는다 | **확인**(stage-n D8) |
| G6 | `notification_preferences` 테이블이 없다 — 앱 팀이 만든다 | **확인**(운영 DB 조회 0행, `notification_preferences_repository.dart` 주석) |
| G7 | "이탈 알림" 토글은 사용자 단위(계정)로 둔다 | **미확인** — D2 |

## 사용자가 정할 것

| # | 질문 | 추천 | 영향 |
|---|---|---|---|
| D1 | 보정 **꺼짐**의 의미: 기기에 `offset_c=0`을 보낼까, 빌드 기본(−1.5)으로 둘까? 그리고 지금 −1.5가 적용된 기기는 처음에 "꺼짐"으로 볼까? | **꺼짐 = 0 전송.** 처음 화면은 `temp_offset_c == 0`일 때만 꺼짐, 그 외는 켜짐 + 그 값 표시 | Task 4. 펌웨어 기본 −1.5를 0으로 바꾸는 건 펌웨어·서버 담당에 확인 필요 |
| D2 | 이탈 알림 토글을 계정 단위로 둘까, 기기 단위로 둘까? | **계정 단위**(온도·습도 2개). 알림 설정 화면의 다른 토글과 같은 층 | Task 7·8 테이블 모양 |
| D3 | 기존 환경설정(`/env-settings`)의 "목표 온습도"(단일 목표값 `target_temp_c`) 타일을 어떻게 할까? | **"온습도 설정" 행으로 바꿔 새 화면으로 연결**, 단일 목표값 시트는 사육장 탭 카드에만 남김 | Task 3 |
| D4 | 실시간 카드 설명 문구에 넣을 수치: 확정 시 차이(`context.diff`)인가, 지금까지 최대 이탈(`context.peak_diff`)인가? | **제목은 서버 `message` 그대로**(푸시와 같은 문구), 설명은 1-5 설명 문구 고정 | Task 6 |

## 선택지와 추천

- **판정 위치**: 앱 복제 vs 서버만 → **서버만**. 앱이 같은 규칙을 다시 돌리면 푸시와 화면이 어긋난다. 앱은 `alerts` 열린 행만 그린다.
- **수신 끔 거르기**: 서버(terra-server)에 설정 전달 vs 앱 Supabase에서 거름 → **앱 Supabase에서 거름**. 서버 문서 §3이 "앱 Edge Function에서 걸러 달라"고 했고, outbox 생성 트리거가 이미 앱 마이그레이션에 있다.
- **설정 화면 위치**: `EnvSettingsScreen`에 끼워 넣기 vs 새 라우트 → **새 라우트**. Figma는 온습도 상세·알림 설정 두 곳에서 들어오는 독립 화면이다.

## 실패 시나리오

| 상황 | 결과 | 막는 곳 |
|---|---|---|
| MIN=MAX 또는 범위 밖 저장 | 서버 N2 전이면 저장됨 → 판정이 clamp/디폴트로 조용히 바뀜 | Task 1 `EnvThresholds`가 막고, Task 5 저장 버튼 비활성 |
| 보정 명령이 기기에 안 닿음(오프라인·구 펌웨어) | 화면은 저장됐다고 믿는데 `t_a`는 그대로 | Task 4: 저장 성공 기준 = `devices.temp_offset_c`가 보낸 값으로 바뀜(최대 15초 대기), 아니면 "기기 응답이 늦어요" |
| 서버 스위치 꺼짐(`ALERTS_V4_ENABLED=false`) | env_* 행 없음 → 카드 안 보임 | 정상. 카드는 행이 있을 때만 |
| 같은 푸시 두 번(`started` 재시도) | 중복 알림 | `event_id` 멱등 — ingest가 `source_event_id` 유니크로 202 duplicate |
| 계정 전환 뒤 이전 계정 알림 카드 | 남의 기기 카드 | Task 6 provider가 `currentDeviceIdProvider` + 계정 id watch |
| 구 펌웨어(`temp_offset_c` NULL) | 현재 측정 온도를 못 구함 | Task 4: 보정 행 비활성 + "펌웨어 업데이트 후 사용할 수 있어요" |

## 검증 방법 (구현 전 확정)

- 명령: `flutter analyze`(에러 0), `flutter test test/features/home/env_thresholds_test.dart test/features/home/env_alert_test.dart test/features/home/env_range_bar_test.dart test/features/home/env_alert_card_test.dart test/features/home/temp_humid_setting_screen_test.dart test/features/home/temp_offset_screen_test.dart test/features/home/env_range_setting_screen_test.dart`, `node --test supabase/functions/_shared/`
- 마이그레이션: 격리 DB(supabase branch)에서 적용·롤백 후 운영 적용은 **사용자 승인 뒤**.
- 화면 수치: 페이지별 필수 수치 검수(CLAUDE.md) — 393×852 기준으로 S04·S08·S11·S14·A10 상단을 `figma-structure-*.md` 값과 대조, 결과는 `docs/design-audits/2026-11-02-env-alerts-v4/RESULTS.md`.
- 실기기: 운영 서버 스위치가 꺼져 있으므로 env_* 카드·푸시는 **서버 1·2단계 켠 뒤** 실기기로 확인(사용자·서버 담당 협조). 그 전에는 위젯 테스트 픽스처로만 확인.

## Review Focus

1. **보정 저장 후 범위 바·카드가 옛 값**: 기기 반영 전 `t_a`는 옛 보정 → Task 4 `test_save_waits_for_reported_offset`.
2. **처음 진입 후 취소 시 토글 원복**(S46) vs **수정 중 취소 시 이전 값**(S47) → Task 4 `cancel_on_first_entry_turns_toggle_off`, `cancel_after_saved_restores_previous`.
3. **값이 바 범위 밖**(온도 10℃, 35℃ / 습도 15%) → 원이 바 끝에 고정, 숫자는 실제 값 → Task 5 `out_of_range_value_clamps_marker`.
4. **진행 중 env_* 행이 앱 실행 중 종료**(Realtime UPDATE `resolved_at`) → 카드 줄 사라짐 → Task 6 `resolved_row_disappears`.
5. **수신 끔 사용자에게도 `app_notifications`는 쌓임** → Task 8 SQL 검증 쿼리.

---

### Task 1: 적정 범위·보정 도메인 `EnvThresholds`, `TempOffset`

**Files:**
- Create: `lib/features/home/domain/env_thresholds.dart`
- Test: `test/features/home/env_thresholds_test.dart`

**Context:**
- Depends on: 없음
- Produces:
  - `class EnvRange { final double min; final double max; }` (값 동등성 `==`/`hashCode` — 테스트가 `expect(…, const EnvRange(18, 26))`로 비교) + `static const EnvRange tempDefault = EnvRange(18, 26)`, `humidDefault = EnvRange(40, 80)`
  - `class EnvRangeRule { final double lower, upper, step; }` + `static const temp = EnvRangeRule(15, 29, 0.5)`, `humid = EnvRangeRule(35, 85, 5)`
  - `EnvRange EnvRange.fromSettings(double? min, double? max, EnvRangeRule rule, EnvRange fallback)` — 서버 D8과 같은 규칙: null → 디폴트, 범위 밖 → clamp, `min >= max` → 그 요소 디폴트
  - `bool EnvRangeRule.canDecrease(double v)` / `canIncrease(double v)` / `double decrease(v)` / `increase(v)` — 스텝 이동
  - `bool EnvRange.isValidFor(EnvRangeRule rule)` — 범위 안·스텝 배수·min<max
  - `class TempOffset { final double value; }`: `static const minMagnitude = 0.1, maxMagnitude = 4.0, step = 0.1`, `bool get isOff => value == 0`, `double get magnitude`, `bool get isSubtract`, `factory TempOffset.fromSigned(double)`, `factory TempOffset.of({required bool subtract, required double magnitude})`, `double rawFrom(double reportedTemp, double appliedOffset)` = `reportedTemp - appliedOffset`, `double apply(double raw)` = `raw + value`
- Must know: 부동소수 비교는 0.1 단위로 반올림해서 한다(`(v*10).round()`). 0.5·5 배수 검사도 같은 방식. 경고 경계(15/29)는 판정용이 아니라 **설정 가능 범위**와 숫자가 같을 뿐이다 — 이 파일은 판정을 하지 않는다.
- Acceptance: 아래 테스트 PASS.

- [ ] **Step 1: 실패 테스트**

```dart
test('null 설정은 디폴트', () => expect(EnvRange.fromSettings(null, null, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(18, 26)));
test('범위 밖은 clamp', () => expect(EnvRange.fromSettings(10, 35, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(15, 29)));
test('min>=max면 디폴트', () => expect(EnvRange.fromSettings(24, 24, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(18, 26)));
test('온도 0.5 스텝·상한', () { expect(EnvRangeRule.temp.decrease(18), 17.5); expect(EnvRangeRule.temp.canIncrease(29), isFalse); });
test('습도 5 스텝·하한', () { expect(EnvRangeRule.humid.decrease(40), 35); expect(EnvRangeRule.humid.canDecrease(35), isFalse); });
test('스텝 배수 아님은 무효', () => expect(const EnvRange(18.3, 26).isValidFor(EnvRangeRule.temp), isFalse));
test('보정 −1.0 적용', () { final o = TempOffset.of(subtract: true, magnitude: 1.0); expect(o.value, -1.0); expect(o.apply(26.2), closeTo(25.2, 1e-9)); });
test('원래 측정값 복원', () => expect(TempOffset.rawFrom(24.7, -1.5), closeTo(26.2, 1e-9)));
test('보정 크기 0.1~4.0', () { expect(() => TempOffset.of(subtract: false, magnitude: 4.1), throwsArgumentError); expect(() => TempOffset.of(subtract: false, magnitude: 0), throwsArgumentError); });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/home/env_thresholds_test.dart` → FAIL(파일 없음)
- [ ] **Step 3: 구현** — Produces 시그니처대로. `rawFrom`은 static.
- [ ] **Step 4: PASS 확인** — 같은 명령 → PASS
- [ ] **Step 5: 커밋** `feat(env): 적정 온습도 범위·온도 보정 도메인(v4 1-1·1-2)`

---

### Task 2: 설정 쓰기 — MIN/MAX PATCH, 보정 명령, `Device.tempOffsetC`

**Files:**
- Modify: `lib/features/my_cage/data/device_settings_repository.dart` (`patch`에 named 4개 추가)
- Modify: `lib/features/my_cage/domain/device_settings.dart` (`patchBody`에 4개 + `EnvRange tempRange`/`humidRange` getter — Task 1 `fromSettings` 사용)
- Modify: `lib/features/my_cage/domain/device.dart` (`final double? tempOffsetC` — `temp_offset_c` 파싱, ±10 밖은 null)
- Create: `lib/features/my_cage/data/temp_offset_repository.dart`
- Test: `test/features/my_cage/device_settings_range_test.dart`, `test/features/my_cage/temp_offset_repository_test.dart`

**Context:**
- Depends on: Task 1
- Produces:
  - `DeviceSettingsRepository.patch(String deviceId, {double? targetTempC, double? targetHumidityPct, double? targetTempMin, double? targetTempMax, double? targetHumidMin, double? targetHumidMax})`
  - `DeviceSettings.tempRange` / `humidRange` (`EnvRange`)
  - `Device.tempOffsetC` (`double?`)
  - `class TempOffsetRepository { Future<void> send(String deviceId, TempOffset offset); }` — REST `POST /devices/{id}/commands` body `{"action":"set_temp_offset","payload":{"offset_c": <value>}}` (`TerraRestClient` 사용). provider `tempOffsetRepositoryProvider`
- Must know:
  - `patchBody`는 **보낸 필드만** 넣는다(기존 규칙). MIN/MAX는 두 값을 함께 보낸다 — 한쪽만 보내면 서버 병합 검사에서 순서에 따라 400이 날 수 있다.
  - G4 미확인: 서버가 이 엔드포인트를 앱에 열지 않으면 대안은 Supabase `commands` 직결 INSERT(`SupabaseModuleControlRepository.sendCommand` 경로) — 이 경우 `CommandAction`에 `setTempOffset`('set_temp_offset')을 추가하고 **`actuator_marker.dart`의 `_kindByAction`은 건드리지 않는다**(차트 마커 대상이 아님, LCD와 같은 처리). 서버 회신 전까지 REST로 구현하고 이 문단을 계획서에 남긴다.
  - `Device`는 `camerasProvider`처럼 생존 신호만 바뀐 갱신을 버리는 비교가 있으면 `tempOffsetC`를 비교 키에 넣는다(안 넣으면 보정 반영이 화면에 안 온다).
- Acceptance: 테스트 PASS + `flutter analyze` 0.

- [ ] **Step 1: 실패 테스트**

```dart
test('MIN/MAX 패치 본문', () => expect(DeviceSettings.patchBody(targetTempMin: 17.5, targetTempMax: 29), {'target_temp_min': 17.5, 'target_temp_max': 29.0}));
test('tempRange 디폴트', () => expect(DeviceSettings(deviceId: 'd').tempRange, EnvRange.tempDefault));
test('temp_offset_c 파싱', () { expect(Device.fromJson({...base, 'temp_offset_c': -1.5}).tempOffsetC, -1.5); expect(Device.fromJson({...base, 'temp_offset_c': 12}).tempOffsetC, isNull); });
test('보정 명령 본문', () async { /* fake TerraRestClient */ await repo.send('d1', TempOffset.fromSigned(1.0)); expect(fake.lastPost, ('/devices/d1/commands', {'action': 'set_temp_offset', 'payload': {'offset_c': 1.0}})); });
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/my_cage/device_settings_range_test.dart test/features/my_cage/temp_offset_repository_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 적정 MIN/MAX 저장·온도 보정 명령 데이터 계층`

---

### Task 3: 온습도 설정 화면 + 라우트 (S04·S05·S06)

**Files:**
- Create: `lib/features/home/presentation/temp_humid_setting_screen.dart` (`TempHumidSettingScreen`)
- Create: `lib/features/home/presentation/temp_humid_setting_providers.dart`
- Modify: `lib/core/router/app_router.dart` — `/env-detail` 아래 `settings`(+ 자식 `temp`, `humid`, `offset`)
- Modify: `lib/features/my_cage/presentation/env_settings_screen.dart` — D3 결정대로 `SetpointSettingTile` 자리에 "온습도 설정" 행
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/temp_humid_setting_screen_test.dart`

**Context:**
- Depends on: Task 2
- Produces:
  - 라우트 상수 `kTempHumidSettingPath = '/env-detail/settings'`, `kTempRangePath = '/env-detail/settings/temp'`, `kHumidRangePath = '/env-detail/settings/humid'`, `kTempOffsetPath = '/env-detail/settings/offset'` (`app_router.dart`에 선언)
  - `tempHumidSettingTargetProvider` — 대상 기기 = 홈 세트의 기기(`currentDeviceIdProvider`), 계정 id select-watch
  - `envAlertPrefsProvider`(Task 7 Produces)를 읽어 토글 2개를 그림
- Must know:
  - 구성(Figma S05): 섹션 라벨 "온도 보정" → 카드[온도 보정 토글 / (켜짐이면) 보정 값 행] → 각주 "사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다". "온도" → 카드[이탈 알림 토글 / 적정 온도 `18℃ ~ 26℃` >] → 각주 "`{min}`℃ 미만이거나 `{max}`℃ 초과인 경우 이탈 안내를 합니다". "습도"도 같은 모양. 수치·색·간격은 `figma-structure-setting.md` S04~S06.
  - 보정 토글 켜기는 **화면 상태만** 바꾼다(S45). 보정 값 행 오른쪽 문구: 미저장 = "설정하기", 저장됨 = "측정값 −2℃"/"측정값 +1℃"(`formatCompact`).
  - 보정 토글 끄기 = D1 결정대로 `offset_c=0` 전송(확인 모달 없이, 실패 시 토글 원복 + `ControlFeedback`가 아닌 화면 스낵바 — 이 화면은 시트가 아니다).
  - 대상 기기가 없으면(세트에 사육장 없음) 빈 상태 + 이유 문구, 오프라인이면 `DeviceOfflineNotice` 재사용.
  - 기존 `SetpointSettingTile`·`showSetpointSheet`는 지우지 않는다(사육장 탭 카드가 씀).
- Acceptance: 위젯 테스트 — (1) 설정 없음 → "18℃ ~ 26℃", "40% ~ 80%" (2) 보정 토글 켬 → "설정하기" 행 등장, repository 호출 0회 (3) 저장된 보정 −2 → "측정값 -2℃" (4) 적정 온도 행 탭 → `kTempRangePath` push.

- [ ] **Step 1: 실패 테스트** — Acceptance 4개를 `testWidgets`로(가짜 `DeviceSettingsRepository`·`Device` override)
- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/temp_humid_setting_screen_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 온습도 설정 화면·라우트(Figma 1623:8553)`

---

### Task 4: 보정값 설정 화면 (S14·S16·S33~S37)

**Files:**
- Create: `lib/features/home/presentation/temp_offset_screen.dart` (`TempOffsetScreen`)
- Create: `lib/features/home/presentation/widgets/offset_direction_toggle.dart`, `offset_slider.dart`
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/temp_offset_screen_test.dart`

**Context:**
- Depends on: Task 2, 3
- Consumes: `Device.tempOffsetC`, `envLiveViewProvider(deviceId).temperature`(보정 후 현재값), `TempOffsetRepository.send`
- Produces: `TempOffsetScreen({required bool firstEntry})` — 결과로 저장한 `TempOffset?`을 `pop`
- Must know:
  - 현재 측정 온도 = `TempOffset.rawFrom(live.temperature, device.tempOffsetC)`; 보정 온도 = `raw + 선택값`(빨강, Figma S16 `#C80000`류 — 덤프 색을 역할색으로 매핑, 새 역할색이면 GlassPalette 6곳 규칙).
  - 첫 진입 기본값: 빼기 + 0.1(S45). 슬라이더 0.1~4.0, 0.1 단위(39칸).
  - 저장: 명령 전송 → `devices.temp_offset_c`가 보낸 값과 같아질 때까지 Realtime으로 최대 **15초** 기다림 → 같아지면 pop, 시간 초과면 "기기 응답이 늦어요. 잠시 뒤 다시 확인해 주세요" 안내 후 pop(값은 보낸 것으로 표시).
  - 취소: `firstEntry`면 이전 화면의 보정 토글을 끈다(S46), 아니면 저장값 유지(S47). 시스템 뒤로가기도 취소와 같다.
  - 구 펌웨어(`tempOffsetC == null`): 이 화면에 들어오지 않게 Task 3에서 행을 비활성 + 이유 문구.
  - 문구는 Figma 그대로: "현재 측정 온도", "보정 온도", "실시간 온도와 주간 그래프에 보정 온도로 반영됩니다", "아래 값을", "− 빼기", "+ 더하기", "온도차 보정 가이드" + 본문 3문단, "저장", "취소".
- Acceptance: 테스트 4개 PASS.

- [ ] **Step 1: 실패 테스트**

```dart
testWidgets('첫 진입 기본 빼기 0.1, 보정 온도 26.1', ...);        // raw 26.2 (t_a 24.7, offset -1.5)
testWidgets('더하기 1.0 → 보정 온도 27.2', ...);
testWidgets('test_save_waits_for_reported_offset', ...);          // send 후 temp_offset_c 1.0 UPDATE 도착 시에만 pop
testWidgets('cancel_on_first_entry_turns_toggle_off', ...);       // pop 결과 null + firstEntry → 상위가 토글 끔
testWidgets('cancel_after_saved_restores_previous', ...);         // 저장값 -2 상태에서 +3 고르고 취소 → -2 유지, send 0회
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/temp_offset_screen_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 보정값 설정 화면(Figma 1635:5551)`

---

### Task 5: 적정 온도·습도 설정 화면 + 스테퍼 (S08·S10·S11·S13·S27)

**Files:**
- Create: `lib/features/home/presentation/env_range_setting_screen.dart` (`EnvRangeSettingScreen`)
- Create: `lib/shared/widgets/viva_stepper.dart` (`VivaStepper`)
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/env_range_setting_screen_test.dart`

**Context:**
- Depends on: Task 1, 2, 3
- Produces: `EnvRangeSettingScreen({required EnvRangeKind kind})` (`enum EnvRangeKind { temp, humid }`), `VivaStepper({required String value, VoidCallback? onDecrease, VoidCallback? onIncrease})` — null 콜백 = 비활성(S27 `StepMinus_disabled`)
- Must know:
  - 헤더 행 "적정 온도"·현재 저장값 `18℃ ~ 26℃`(빨강) / 최소·최대 행에 스테퍼. 최소의 +는 `min + step < max`일 때만, 최대의 −는 `max − step > min`일 때만 활성.
  - 값이 저장값과 다르면 하단에 "변경 사항 취소"(빨강 텍스트 버튼) 표시 — 누르면 저장값으로 되돌림(S10). 저장 버튼은 하단 고정 플로팅(Figma 위치 대로, CLAUDE.md "공통 하단 CTA" 확인 대상).
  - 저장: Task 2 `patch`로 min/max **둘 다** 전송 → 성공 시 pop. 실패 시 값 유지 + 안내.
  - 가이드 문구(S08/S11)는 Figma 그대로. 습도 가이드의 3번째 문단 "최저 습도 미만으로 떨어지면 즉시 알림을…"은 서버 실제 규칙(2분)과 다르다 → 문구 확정 전까지 Figma 그대로 두고 RESULTS에 차이로 기록.
- Acceptance: (1) 최대 29에서 + 비활성 (2) 최소 17.5로 바꾸면 "변경 사항 취소" 등장, 누르면 18 복귀 (3) 저장 시 `patch(targetTempMin: 17.5, targetTempMax: 26)` 1회 (4) 습도 최소 35에서 − 비활성.

- [ ] **Step 1: 실패 테스트** — Acceptance 4개
- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/env_range_setting_screen_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 적정 온도·습도 설정 화면과 스테퍼(Figma 1635:5123·1635:5165)`

---

### Task 6: 온습도 상세 — 범위 바·설정 진입·실시간 카드 (A04·A06·A08·A10·A12·A13·S03)

**Files:**
- Create: `lib/features/home/domain/env_alert.dart` (`EnvAlert`, `EnvAlertKind`, `EnvAlertLevel`)
- Create: `lib/features/home/data/env_alert_repository.dart`
- Create: `lib/features/home/presentation/env_alert_providers.dart`
- Create: `lib/features/home/presentation/widgets/env_range_bar.dart` (`EnvRangeBar`)
- Create: `lib/features/home/presentation/widgets/env_alert_card.dart` (`EnvAlertCard`)
- Modify: `lib/features/home/presentation/env_detail_screen.dart` (`_topBar`: 왼쪽 ✕·오른쪽 설정 아이콘 / `_valueBar` → `EnvRangeBar` 2줄 / 오늘이면 차트 아래 `EnvAlertCard`)
- Test: `test/features/home/env_alert_test.dart`, `test/features/home/env_range_bar_test.dart`, `test/features/home/env_alert_card_test.dart`, 기존 `test/features/home/env_detail_screen_test.dart` 수정

**Context:**
- Depends on: Task 1, 2
- Produces:
  - `EnvAlert.fromRow(Map)` — `kind ∈ {env_temp_high, env_temp_low, env_humid_low, env_humid_high}` + `context.rule == 'v4'`만 통과(그 외 null). 필드: `id, kind, level(caution|danger ← context.level), chip(String — message의 [ ] 안), title(String — message의 ] 뒤), triggeredAt, resolvedAt, value, threshold, peakValue`
  - `EnvAlertRepository.watchOpen(String deviceId) -> Stream<List<EnvAlert>>` — 처음 `select ... resolved_at is null` + Realtime `alerts` INSERT/UPDATE(필터 `device_id=eq.<id>`) 반영
  - `openEnvAlertsProvider` (autoDispose, 계정 id + `currentDeviceIdProvider` watch)
  - `EnvRangeBar({required EnvBarKind kind, required double? value, required double? low, required double? high, required EnvRange range})` — `kind`가 전체 바(온도 12~30, 습도 20~100)를 정함
- Must know:
  - 범위 바 규칙(A04): 전체 바 길이는 화면 폭에 따름. 적정 구간은 전체 바에서 같은 비율 위치. 값이 전체 바 밖이면 원은 끝에 고정. 숫자: 현재값 NN.N(소수 0이어도 표시), 최저·최고 NN(**버림**), 적정 구간 눈금 NN.N/NN(소수 0이면 정수).
  - 오늘 = 현재값(`envLiveViewProvider`) + 오늘 최저·최고(`envDayExtremesProvider`) + 적정 구간(Task 2 `tempRange`). 지난 날 = 하루 평균(`envDailyAverageProvider`) + 그날 최저·최고. 신선도 흐림 규칙(`EnvFreshness`)은 현재값 숫자에 그대로.
  - 카드 줄 순서: 경고(danger) 먼저, 같은 등급이면 온도→습도. 칩 색: 경고 = 빨강 계열, 주의 온도 = 빨강 테두리, 주의 습도 = 남색(A10·A12 덤프에서 역할색 매핑). 설명 문구는 1-5 설명 열을 `kind+level`로 고정 매핑(ko.json): 저온 경고 "즉시 온도를 올려주세요" / 고온 경고·고온 주의 "환기팬 또는 냉각팬 사용을 추천드려요" / 저온 주의 "난방 장치 사용을 추천드려요" / 건조 주의 "사육장에 수분을 보충해 주세요" / 과습 주의 "환기 상태를 점검해 주세요".
  - 카드는 **오늘 화면에서만**, 열린 행이 있을 때만. 지난 날은 Stage P(대기) 자리라 아무것도 그리지 않는다.
  - `alerts`를 `camerasProvider`·`devicesProvider` 같은 공용 목록 provider에 넣지 않는다(재조회 깜빡임 교훈).
  - 설정 아이콘 키 `EnvDetailScreen.settingsKey`, 탭 → `kTempHumidSettingPath`.
  - 그래프 터치 말풍선(A05 "오전 11:23 / 35.2℃ / 59%")은 기존 `EnvDayChart` 스크러버로 이미 있다 — 새로 만들지 않고 Task 9 수치 검수에서 모양만 대조한다.
- Acceptance: 테스트 PASS + 기존 env_detail 테스트 수정 후 PASS.

- [ ] **Step 1: 실패 테스트**

```dart
test('env_* 아닌 kind는 제외', () => expect(EnvAlert.fromRow({...row, 'kind': 'temp_high'}), isNull));
test('message 분리', () { final a = EnvAlert.fromRow(row)!; expect(a.chip, '고온 주의'); expect(a.title, '적정 온도보다 +0.3℃'); });
testWidgets('out_of_range_value_clamps_marker', ...);   // 온도 35 → 원 x == 바 오른쪽 끝, 숫자 "35.0℃"
testWidgets('최저 15.9 → "15" (버림)', ...);
testWidgets('경고가 주의보다 위', ...);
testWidgets('resolved_row_disappears', ...);            // 스트림에 resolved_at 채운 행 → 줄 0개, 카드 사라짐
testWidgets('설정 아이콘 → 온습도 설정', ...);
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/env_alert_test.dart test/features/home/env_range_bar_test.dart test/features/home/env_alert_card_test.dart test/features/home/env_detail_screen_test.dart`)
- [ ] **Step 5: 커밋** 두 개로 나눈다 — `feat(env): 온습도 상세 범위 바·설정 진입(Figma 1610:6588)` / `feat(env): v4 실시간 이탈 카드(alerts env_*)`

---

### Task 7: 이탈 알림 수신 설정 — 서버 테이블 + 앱 저장소

**Files:**
- Create: `supabase/migrations/20261102000000_env_alert_preferences.sql`
- Create: `lib/features/home/data/env_alert_prefs_repository.dart`
- Test: `test/features/home/env_alert_prefs_repository_test.dart`

**Context:**
- Depends on: 없음 (D2 결정 필요 — 아래는 추천안 "계정 단위")
- Produces:
  - 테이블 `public.notification_preferences(user_id uuid pk references auth.users on delete cascade, env_temp boolean not null default true, env_humid boolean not null default true, updated_at timestamptz not null default now())`
  - `EnvAlertPrefs { final bool temp; final bool humid; }`, `EnvAlertPrefsRepository.load() / save(EnvAlertPrefs)`, `envAlertPrefsProvider`(Notifier, 계정 id watch, 행 없으면 둘 다 true)
- Must know: 마이그레이션 전문(결정을 담은 선언):

```sql
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  env_temp   boolean NOT NULL DEFAULT true,
  env_humid  boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own prefs select" ON public.notification_preferences FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "own prefs insert" ON public.notification_preferences FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "own prefs update" ON public.notification_preferences FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

  - 앱 쓰기는 `upsert(onConflict: 'user_id')` **`.select()` 없이**(RETURNING이 SELECT 정책을 타는 함정은 없지만 `webrtc_connect_logs` 교훈대로 필요 없는 RETURNING은 빼둔다).
  - 기존 Hive `NotificationPrefs`(하이라이트·댓글 등)는 이번에 옮기지 않는다. 컬럼 이름에 `env_` 접두어를 둬 나중에 같은 표에 열을 더할 수 있게 했다.
  - 운영 적용은 사용자 승인 후. 먼저 Supabase branch에 적용해 RLS를 두 계정으로 확인.
- Acceptance: 테스트(가짜 클라이언트) PASS + branch DB에서 다른 계정 행 SELECT 0건.

- [ ] **Step 1: 실패 테스트** — `행 없으면 둘 다 true`, `save → upsert 본문 {user_id, env_temp, env_humid}`
- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/env_alert_prefs_repository_test.dart`)
- [ ] **Step 5: branch DB 검증** — `apply_migration`(branch) 후 두 계정 JWT로 select → 자기 행만
- [ ] **Step 6: 커밋** `feat(env): 온습도 이탈 알림 수신 설정 테이블·저장소`

---

### Task 8: `env.alert.triggered` 푸시 수신 — 계약·문구·수신 끔 거르기

**Files:**
- Modify: `supabase/functions/_shared/notification-contract.mjs` (+ `.test.mjs`)
- Create: `supabase/migrations/20261102000100_notification_env_alert.sql`
- Modify: `lib/features/notification/domain/app_notification.dart` (`knownNotificationKinds`에 `'env.alert.triggered'`)
- Test: `supabase/functions/_shared/notification-contract.test.mjs`, `test/features/notification/app_notification_test.dart`

**Context:**
- Depends on: Task 7
- Consumes: 서버 문서 §2 봉투(`schema_version 1`, `event_id`, `type`, `occurred_at`, `user_id`, `payload{alert_id, device_id, device_key?, device_name, enclosure_id, kind, level, phase, title, value, threshold}`)
- Produces: 계약 검사 `validateEnvAlertEvent(payload)` — 필수 `alert_id, device_id, kind(4종), level(caution|danger), phase(started|reminder), title(비어 있지 않음)`, `device_key`는 있으면 문자열
- Must know:
  - **트리거 함수는 최신 정의를 기준으로 고친다**: `app_notifications` 생성 함수의 가장 최근 `CREATE OR REPLACE`는 `20261001000000_notification_device_offline_copy.sql`. 그 본문을 복사해 `WHEN 'env.alert.triggered'` 분기만 더한다(이전 분기 유실 금지).
    - `v_title := NEW.payload ->> 'title'`, `v_body := COALESCE(NULLIF(NEW.payload ->> 'device_name',''), '사육장') || ' 온습도를 확인해 주세요.'`, `v_route := '/env-detail'`. category는 기존 규칙대로 `split_part(type,'.',1)` = `env`.
  - 수신 끔: outbox INSERT 지점(같은 함수 또는 outbox 트리거)에서 `kind = 'env.alert.triggered'`이고 `payload.kind`가 `env_temp_*`이면 `env_temp`, `env_humid_*`이면 `env_humid`가 false인 사용자는 **outbox만 건너뛴다**. `app_notifications`는 그대로 쌓는다(1-5).
  - outbox 우선순위 `CASE`에 `WHEN n.kind = 'env.alert.triggered' THEN 0`을 `safety.%`와 같은 등급으로 추가.
  - 앱 수신 탭: `route='/env-detail'`은 이미 `safeRoute` 허용 경로인지 확인하고 아니면 추가.
  - 서버 스위치 2단계(`PUSH_ENV_ALERTS_ENABLED`) 전에는 이벤트가 안 오므로, 배포 순서는 이 마이그레이션 → 서버에 "§2 수신부 준비 완료" 회신.
- Acceptance: node 테스트 PASS + branch DB에서 (a) 끔 사용자 이벤트 → `app_notifications` 1행·outbox 0행 (b) 켬 사용자 → 1행·1행 (c) 같은 `event_id` 두 번 → 202 duplicate.

- [ ] **Step 1: 실패 테스트** (`notification-contract.test.mjs`)

```js
test('env alert started 통과', () => assert.equal(validateNotificationEvent(envEvent()).ok, true));
test('env alert level 오타 거절', () => assert.equal(validateNotificationEvent(envEvent({ level: 'warning' })).ok, false));
test('env alert title 빈 값 거절', () => assert.equal(validateNotificationEvent(envEvent({ title: '' })).ok, false));
test('device_key 없어도 통과', () => assert.equal(validateNotificationEvent(envEvent({ device_key: undefined })).ok, true));
```

- [ ] **Step 2: 실패 확인** — `node --test supabase/functions/_shared/` → FAIL
- [ ] **Step 3: 구현** — 계약 + 마이그레이션 + `knownNotificationKinds`
- [ ] **Step 4: PASS** — 같은 명령 + `flutter test test/features/notification/`
- [ ] **Step 5: branch DB 검증** — Acceptance (a)(b)(c) SQL
- [ ] **Step 6: 커밋** `feat(push): v4 온습도 이탈 푸시 수신(env.alert.triggered)·수신 끔 거르기`

---

### Task 9: 알림 설정 진입 + 마무리 (S39, 버전·패치노트·수치 검수)

**Files:**
- Modify: `lib/features/profile/presentation/notification_settings_screen.dart` — "기능 설정"에 "온습도 이탈 알림 / 적정 온습도에서 이탈했을 때 받는 알림 / 설정하기 >" 행(하이라이트 영상 아래, S39 순서)
- Modify: `pubspec.yaml`(minor), `CHANGELOG.md`
- Create: `docs/design-audits/2026-11-02-env-alerts-v4/RESULTS.md`
- Test: `test/features/profile/notification_settings_screen_test.dart`(행 탭 → `kTempHumidSettingPath`), `test/design/text_scale_overflow_test.dart`에 새 화면 4개 추가

**Context:**
- Depends on: Task 3~8
- Must know: 이 행은 토글이 아니라 이동 행이다(S39). 시스템 알림 권한이 꺼져 있으면 다른 기능 토글처럼 흐리게(기존 규칙) — 이동은 막지 않는다. 버전은 Task별 커밋에서 이미 올렸으면 여기서 더 올리지 않는다(작업 브랜치 병합 직전 main보다 한 칸 위, CLAUDE.md 병렬 규칙).
- Acceptance: `flutter analyze` 0, `flutter test` 전체 PASS, RESULTS.md에 S04·S08·S11·S14·A10 수치 대조표(원본/앱/차이)와 수정 전후 캡처.

- [ ] **Step 1~4:** 테스트 → 구현 → PASS
- [ ] **Step 5: 수치 검수** — 시뮬레이터 393×852에서 5화면 캡처, 덤프와 대조, 차이는 RESULTS에 남기고 보고
- [ ] **Step 6: 커밋** `feat(env): 알림 설정에서 온습도 설정 진입·패치노트`

---

## 서버에 회신할 것 (구현과 함께)

| 서버 문서 항목 | 회신 내용 | 시점 |
|---|---|---|
| §1 표시 준비 | Task 6 병합 후 "1단계(`ALERTS_V4_ENABLED`) 켜도 됨" | Task 6 뒤 |
| §2 수신부 | Task 8 마이그레이션 운영 적용 후 "2단계 켜도 됨" | Task 8 뒤 |
| §2.2 문구 | `payload.title` 그대로 사용 | 지금 |
| §3 수신 끔 | 앱 Supabase에서 거름(서버에 설정 불필요) | 지금 |
| G4 | `POST /devices/{id}/commands` `set_temp_offset`을 앱이 써도 되는지 | 지금 |
| D1 | 보정 꺼짐 = 0 전송 시 펌웨어 기본 −1.5와의 관계 | 지금 |
| N2 | 앱은 15~29(0.5)·35~85(5)·MIN<MAX 밖 값을 보내지 않음 → N2 배포 가능 | Task 5 뒤 |
| 자동 환기·분무 | Figma S41~S44 기능의 서버·펌웨어 계획 문의 | 지금 |
