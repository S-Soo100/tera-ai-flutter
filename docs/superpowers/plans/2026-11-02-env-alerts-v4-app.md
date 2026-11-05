# v4 온습도 알림·설정·온도 보정 (앱 1단계) Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙 — 새 화면 4개 + 푸시 계약 + Supabase 마이그레이션. task 단위로 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.
> 상태: ✅ r2 2026-11-02 — 결정 D1(임시)·D2·D3·D4 반영, 교차 검수 반영([plan-review-final.md](../../design-audits/2026-11-02-env-alerts-v4/plan-review-final.md)). 사용자 "바로 구현 시작"(2026-11-02). 서버 요청 문서(예고됨)를 받으면 §0 "대기"와 Task 2·8을 다시 맞춘다.

**Goal:** 크레스티드 게코 기준 적정 온습도(MIN/MAX)·온도 보정을 앱에서 설정하고, 서버 v4 실시간 판정(`alerts` env_*)을 온습도 상세 화면 카드와 푸시로 보여 준다.

**Architecture:** 설정은 기존 REST(`PATCH /devices/{id}/settings`)와 기기 명령(`POST /devices/{id}/commands` `set_temp_offset`)으로 쓰고, 화면은 Figma `1635:6166`대로 최상위 라우트 `/temp-humid-settings` 묶음에 둔다. 실시간 판정은 서버가 하므로 앱은 `alerts`의 열린 env_* 행을 Realtime으로 읽어 그리기만 한다. 푸시는 `env.alert.triggered`를 기존 notification-ingest → `notification_events` → `app_notifications` → outbox 경로에 붙이고, 수신 끔은 앱 Supabase의 `notification_preferences`로 outbox 단계에서 거른다.

**Tech Stack:** Flutter + Riverpod + GoRouter + easy_localization, Supabase(PostgREST·Realtime·Edge Function, plpgsql 마이그레이션), node:test(`supabase/functions/_shared`)

**Spec:**
- 기획: 노션 "비바나트 앱 (사육장, 캠)" › 사육 위키 › **v4. 최종 정리 중** (2026-11-02 수정본) — 0, 1-1~1-6
- Figma: [`docs/design-audits/2026-11-02-env-alerts-v4/README.md`](../../design-audits/2026-11-02-env-alerts-v4/README.md) (화면 지도·코드 A**/S**), 수치는 같은 폴더 `figma-structure-*.md`
- 서버: terra-server `feat/env-alerts-v4`(`b4cf8ca`) `docs/APP_ENV_ALERT_PUSH_2026-11-02.md`, `specs/stage-n-env-alerts-v4.md`
- 서버 질의: [`docs/handoffs/2026-11-02-env-alerts-v4-server-questions.md`](../../handoffs/2026-11-02-env-alerts-v4-server-questions.md)

---

## 0. 범위 — 이번 계획 / 대기

| 구분 | 내용 | 근거 |
|---|---|---|
| **이번 계획 (Task 1~9)** | 적정 온도·습도 설정, 온습도 설정 화면, 온습도 상세 범위 바·설정 진입, 실시간 카드(env_* alerts), `env.alert.triggered` 푸시, 수신 끔 서버 설정, 알림 설정 진입, 보정값 설정(맨 뒤) | 서버 Stage N 계약이 확정돼 있음 |
| 대기 — 서버 Stage O | 환기 지연·분무 필요 카드/푸시 (A26 하단, A36 하단) | 서버 "습기 사이클(Stage O)" 미착수 → **앱 받는 쪽은 0.168.0에서 준비**([계획](2026-11-03-env-humid-cycle-alerts-app.md)) |
| **다음 계획** — 서버 Stage P | 일간 분석 카드 (A14~A18, A27, A28) | 서버 구현 완료(2026-11-02, `env_daily_reports`, 서버 `feat/weekly-analysis-v4` `docs/APP_DAILY_ANALYSIS_2026-11-02.md`). 앱 계획 별도 작성 |
| **다음 계획** — 서버 Stage Q | 주간 분석 카드 + 주간 막대 그래프 재디자인 (A19~A34) | 서버 구현 완료(`env_weekly_reports`, `docs/APP_WEEKLY_ANALYSIS_2026-11-02.md`). 앱 계획 별도 작성 |
| 대기 — 서버·펌웨어 | 자동 환기·자동 분무 토글 (S41~S44) | 서버·펌웨어에 기능 없음(`auto_vent` 등 0건, 2026-11-02 grep). 질의 Q3 → 11/3 "계획 없음" → 기능 요청 [`2026-11-05-auto-vent-mist-request.md`](../../handoffs/2026-11-05-auto-vent-mist-request.md) |
| 대기 — 서버 Stage N2 | 서버 쪽 MIN/MAX 범위 검증 | 앱이 범위 밖 값을 안 보낸다는 근거 = Task 1(검증)·Task 5(화면) |

**구현 순서:** Task 1 → 2 → 7 → 5 → 3 → 6 → 8 → 9 → 4. 보정(Task 4와 Task 3의 보정 섹션 동작)은 D1·Q1이 미결이라 맨 뒤에 둔다.

## Global Constraints

- 대상 종: 크레스티드 게코. 다른 종 기준은 이번 범위 밖(기획 v4 머리말).
- 온도: 디폴트 MIN **18℃**, MAX **26℃**. 설정 범위 **15℃ 이상 29℃ 이하**, **0.5℃** 단위, **MIN < MAX**. 경고 **15℃ 미만 / 29℃ 초과**(15.0·29.0은 경고 아님).
- 습도: 디폴트 MIN **40%**, MAX **80%**. 설정 범위 **35% 이상 85% 이하**, **5%** 단위, **MIN < MAX**.
- 적정 범위 = MIN ≤ 값 ≤ MAX(경계 포함).
- 온도 보정: 크기 **0.1~4.0℃, 0.1 단위**, 방향 빼기/더하기(Figma S24). 기기 명령 허용 범위는 ±10.0(서버 `TEMP_OFFSET_LIMIT_C`).
- 판정·분석은 **보정된 값**(기기가 보정해 보낸 `t_a`) 기준. 보정 변경은 이후 데이터부터, 과거 데이터·분석은 그대로.
- 실시간 판정·푸시 판단은 **서버만** 한다. 앱은 판정 로직을 복제하지 않는다.
- 푸시 제목은 서버 `payload.title` 그대로(1-5 "타이틀만"). 알림 본문은 **사육장 이름만**(어느 사육장인지 알리기 위한 최소 정보, 문장 추가 없음).
- 푸시는 **Android만** 온다(iOS FCM 미지원 `push_messaging_service.dart:55`). iOS는 알림함·화면 카드로만 보인다.
- 푸시 수신 끔이어도 기록은 남긴다(`app_notifications`는 쌓고 outbox만 건너뜀). 끈 뒤 새로 생기는 알림부터 적용.
- 설정 쓰기는 REST만(`PATCH /devices/{id}/settings`) — Supabase 직결 UPDATE 금지. 보정은 REST 기기 명령으로만.
- 로딩은 shimmer, 문자열은 `ko.json`, 색은 `context.glass`/VIVA 역할색, 글자 크기는 Figma 그대로(CLAUDE.md).
- lib 변경이 있는 커밋마다 `pubspec.yaml` 버전과 `CHANGELOG.md`를 같은 커밋에 올린다(CLAUDE.md 커밋 규칙).
- 건드리지 않는 것: 환경설정 `/env-settings`(진입점 없는 옛 화면, D3)와 단일 목표값 `target_temp_c`, 홈 `EnvSummaryCard`·라이브 오버레이 표시 규칙(`envLiveViewProvider`), 온습도 상세 **주간** 탭, 사육장 제어 기록, 펌웨어 발 `alerts`(`temp_high`·`heater_latched` 등), 기존 `safety.*`·`device.action.*` 푸시 동작, 환기팬·분무 시트.

## 유저 체험 시뮬레이션

1. 홈 온습도 카드 → **온습도 상세**. 왼쪽 위 ✕, 오른쪽 위 설정 아이콘(S03). 오늘 화면 맨 위 두 줄은 `22.0℃ 15 ━━●━━ 26`처럼 생겼다(A04): 맨 왼쪽은 현재값, 바 왼쪽 숫자는 오늘 최저(15), 오른쪽 숫자는 오늘 최고(26). 바 자체는 온도 12~30(습도 20~100) 고정 눈금이고, 바 안 진한 구간이 적정 범위(디폴트면 18~26), 원이 현재값 위치다.
2. 오후 2시 온도가 15℃ 아래로 2분 넘게 머문다 → 서버가 판정 → Android 폰에 푸시. 제목 "[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요", 본문 "거실 사육장". 누르면 그 사육장으로 바뀐 온습도 상세가 열린다.
3. 화면 그래프 아래에 회색 카드가 생긴다: 빨간 칩 **저온 경고** · "온도가 너무 낮아 개체가 위험할 수 있어요" · "즉시 온도를 올려주세요". 습도도 이탈 중이면 같은 카드 안에 줄이 하나 더 생긴다(A10). 적정 범위로 5분 돌아오면 그 줄이 사라진다.
4. 설정 아이콘 → **온습도 설정**(S04/S05). 머리에 사육장 이름. 펌웨어 기본 보정(−1.5℃)이 걸린 기기라면 온도 보정은 **켜짐 · "측정값 −1.5℃"**로 보인다(D1 임시 규칙: 0일 때만 꺼짐). 이탈 알림 켜짐, 적정 온도 18℃ ~ 26℃.
5. 적정 온도 행 → **적정 온도 설정**(S08). 최소 −를 한 번 → 17.5. 아래에 "변경 사항 취소"가 나타난다(S10). 최대 +를 눌러 29가 되면 + 버튼이 흐려진다. 저장 → 이전 화면에 "17.5℃ ~ 29℃". 서버는 60초 안에 새 기준으로 판정한다.
6. 습도 이탈 알림을 끈다 → 바로 서버에 저장되고, 이후 새로 생기는 습도 주의 푸시는 오지 않는다. 온습도 상세 카드와 알림함 기록은 계속 남는다. 저장이 실패하면 토글이 원래대로 돌아가고 안내가 뜬다.
7. 마이페이지 › 알림 설정 → "온습도 이탈 알림 · 설정하기"(S39) → 같은 온습도 설정 화면. 뒤로 가면 알림 설정으로 돌아온다.
8. (보정, 맨 뒤 구현) 보정값 행 → **보정값 설정**(S16). 현재 측정 온도 = 기기가 보낸 값에서 지금 보정을 뺀 값, 보정 온도 = 측정값 ± 선택값. 저장 → 기기가 명령을 받았다고 답하면(`commands.result == ok`) 이전 화면에 "측정값 +1℃". 기기가 오프라인이면 저장 버튼이 막혀 있다. 처음 켠 직후 들어와서 취소하면 보정 토글이 다시 꺼진다(S46), 저장해 둔 값을 고치다 취소하면 저장값 그대로(S47).

## 가정

| # | 가정 | 상태 |
|---|---|---|
| G1 | 앱이 `alerts`를 읽을 수 있다 — `own alerts select` RLS + Realtime publication에 `alerts` 포함 | **확인**(운영 DB, 2026-11-02) |
| G2 | `devices.temp_offset_c` = 기기가 지금 적용 중인 보정값, `t_a`는 보정 후 값. 원래 측정값 = `t_a − temp_offset_c` | **확인**(서버 `handlers.py:986`, `docs/MQTT.md:90`) |
| G3 | 펌웨어 빌드 기본 보정이 **−1.5℃** → 새 기기도 이미 −1.5 적용 중 | **확인**(MQTT.md). 의미는 질의 Q1 |
| G4 | 앱이 `POST /devices/{id}/commands` `set_temp_offset`을 쓴다 | **사용 결정**(2026-11-02 사용자). 제약은 질의 Q2 |
| G5 | 서버 v4 판정이 `device_settings.target_*_min/max`를 60초 TTL로 읽는다 | **확인**(stage-n D8) |
| G6 | `public.notification_preferences` 테이블이 없다 | **확인 필요** — Task 7 Step 1에서 `select to_regclass('public.notification_preferences')`로 재확인(null이어야 함) |
| G7 | 이탈 알림 토글은 계정 단위 | **확정** — D2 |
| G8 | 같은 지표는 열린 env_* 행이 최대 1개 — 주의→경고 전환은 기존 행 종료 + 새 행(시각 같음) | **확인**(서버 문서 §1). 그래도 앱은 지표별 최신 1개만 그린다 |
| G9 | `set_temp_offset` 명령도 `commands` 행이 생기고 `result`가 채워진다(사육장 재시작과 같은 흐름) | **확인**(서버 회신 §2 — `acked`·`result = ok`, 보고는 보통 5초 안). 실기기 실측은 아직 |

## 결정 (D)

> 서버 질의는 [`docs/handoffs/2026-11-02-env-alerts-v4-server-questions.md`](../../handoffs/2026-11-02-env-alerts-v4-server-questions.md)에 모았다.

| # | 질문 | 결정 | 영향 |
|---|---|---|---|
| D1 | 보정 **꺼짐**의 의미와 펌웨어 기본 −1.5℃의 관계 | **확정(서버 회신 2026-11-02, 앱 반영 2026-11-03): −1.5는 공장 보정 — 끔 = `offset_c: −1.5`, 사용자 보정은 −1.5에 더해 보낸다, `temp_offset_c == −1.5`가 꺼짐. 끔 확인 모달은 두지 않는다(온도가 튀지 않음).** ~~임시 결정(2026-11-02 사용자): 끔 = `offset_c: 0` 전송, 사용자 보정 = 그 값 그대로.** 첫 화면은 `temp_offset_c == 0`일 때만 꺼짐. **서버 회신 대기**(질의 Q1). 회신이 "공장값에 더해서"면 바뀌는 곳은 `TempOffset` 한 파일 안 4곳: 기기 값 ↔ 사용자 값 변환(`toDeviceValue`/`fromDevice`), 꺼짐 판정(`isOff`), 표시 문자열, 반영 비교. ⚠️ 끔 = 0은 −1.5 기기의 모든 온도를 +1.5℃ 올린다(검수 최대 리스크) — 끌 때 확인 모달을 둔다~~ | Task 1·3·4 |
| D2 | 이탈 알림 토글을 계정 단위로 둘까, 기기 단위로 둘까? | **확정: 계정 단위**(온도·습도 2개) | Task 7·8 |
| D3 | 기존 환경설정(`/env-settings`) "목표 온습도" 타일 | **확정: 건드리지 않는다.** 진입점 없는 화면(`push` 0건, 2026-09-18 RESULTS #8). Figma 진입점은 온습도 상세 아이콘(S03→S04)·알림 설정(S39→S40) 둘뿐 | Task 3에서 제외 |
| D4 | 실시간 카드 제목의 숫자 | **확정: 서버 `message` 그대로**(확정 시점 차이로 고정). 설명은 1-5 설명 문구 고정. 습도는 서버 규칙대로 정수 올림·`%p` — Figma "−5.2%"와 다름, RESULTS에 기록 | Task 6 |

## 실패 시나리오

| 상황 | 결과 | 막는 곳 |
|---|---|---|
| MIN=MAX·범위 밖·스텝 불일치 저장 | 서버 N2 전이면 저장됨 → 판정이 clamp/디폴트로 조용히 바뀜 | Task 1 `isValidFor` + Task 5 저장 버튼 비활성. 읽을 때 스텝에 맞춤 |
| 보정 명령이 기기에 안 닿음(오프라인·구 펌웨어) | 저장됐다고 믿는데 `t_a`는 그대로 | Task 4: 오프라인이면 저장 막음, `commands.result != ok`·시간 초과면 저장 실패로 안내하고 이전 값 유지 |
| 보정 끔 = 0 전송 | −1.5 기기 온도 +1.5℃ | Task 3: 확인 모달 |
| 서버 스위치 꺼짐(`ALERTS_V4_ENABLED=false`) | env_* 행 없음 → 카드 안 보임 | 정상 |
| Realtime 끊김·앱 복귀 중 행 종료 | 사라져야 할 카드가 남음 | Task 6: `bindResilientChannel` `onRejoined`에서 재조회 |
| 같은 푸시 두 번(`started` 재시도) | 중복 알림 | ingest의 `source_event_id` 유니크 → 202 duplicate |
| 푸시 탭 시 홈 세트가 다른 사육장 | 카드 없는 화면 | Task 8: `device_id`로 `selectedHomeDeviceIdProvider` 전환 |
| 편집 중 홈 세트·계정 변경 | 다른 기기에 저장 | Task 3·4·5: 진입 시 기기 id 고정(라우트 인자) |
| 구 펌웨어(`temp_offset_c` NULL) | 측정 온도 계산 불가 | Task 3: 보정 행 비활성 + "펌웨어 업데이트 후 사용할 수 있어요" |
| 기존 보정값 ±4 초과(콘솔 입력) | 편집기 범위 밖 | Task 1 `fromDevice`는 throw 없이 `outOfEditorRange`, Task 4는 4.0으로 맞춰 시작 |
| `notification_events_type_check` 미갱신 | ingest INSERT 실패(500) | Task 8 마이그레이션이 DROP/ADD |

## 검증 방법 (구현 전 확정)

- 명령: `flutter analyze`(에러 0). `flutter test test/shared/domain/env_thresholds_test.dart test/features/my_cage/device_settings_range_test.dart test/features/my_cage/temp_offset_repository_test.dart test/features/home/env_alert_prefs_repository_test.dart test/features/home/env_range_setting_screen_test.dart test/features/home/temp_humid_setting_screen_test.dart test/features/home/env_alert_test.dart test/features/home/env_alert_repository_test.dart test/features/home/env_range_bar_test.dart test/features/home/env_alert_card_test.dart test/features/home/env_detail_screen_test.dart test/features/notification/ test/features/profile/notification_settings_screen_test.dart test/features/home/temp_offset_screen_test.dart test/design/text_scale_overflow_test.dart`, 마지막에 `flutter test` 전체. `node --test supabase/functions/_shared/`.
- 마이그레이션: Supabase branch에 적용해 검증. **운영 적용·ingest 운영 재배포는 사용자 승인 뒤**.
- 화면 수치: 페이지별 필수 수치 검수(CLAUDE.md) — 393×852 기준으로 S05·S08·S11·S16·A10 상단을 `figma-structure-*.md` 값과 대조, 결과는 `docs/design-audits/2026-11-02-env-alerts-v4/RESULTS.md`.
- 실기기: 보정 명령 실측(G9)은 Task 4 착수 전, 사용자 승인 후 실기기 1대. env_* 카드·푸시는 서버 1·2단계를 켠 뒤(서버 담당 협조). 그 전에는 위젯·저장소 테스트 픽스처로 확인.

## Review Focus

1. **Realtime 재연결 중 종료된 행** → 카드 줄이 사라져야 함 → Task 6 `rejoin_refetches_and_drops_resolved`.
2. **첫 진입 후 취소 시 토글 원복**(S46) vs **수정 중 취소 시 이전 값**(S47) → Task 4 `cancel_on_first_entry_turns_toggle_off`, `cancel_after_saved_restores_previous`.
3. **값이 바 범위 밖**(온도 10·35℃ / 습도 15%) → 원은 바 끝에 고정, 숫자는 실제 값 → Task 6 `out_of_range_value_clamps_marker`.
4. **이탈 알림 토글 저장 실패** → 원복 + 안내 → Task 3 `toggle_failure_reverts`.
5. **수신 끔 사용자에게도 `app_notifications`는 쌓임** → Task 8 branch SQL 검증 (a).

---

### Task 1: 적정 범위·보정 도메인 `EnvRange`, `EnvRangeRule`, `TempOffset`

**Files:**
- Create: `lib/shared/domain/env_thresholds.dart`
- Test: `test/shared/domain/env_thresholds_test.dart`

**Context:**
- Depends on: 없음
- Produces:
  - `class EnvRange { final double min; final double max; }` (값 동등성 `==`/`hashCode`) + `static const EnvRange tempDefault = EnvRange(18, 26)`, `humidDefault = EnvRange(40, 80)`, `bool isValidFor(EnvRangeRule rule)` — 범위 안·스텝 배수·min<max
  - `class EnvRangeRule { final double lower, upper, step; }` + `static const temp = EnvRangeRule(15, 29, 0.5)`, `humid = EnvRangeRule(35, 85, 5)`, `double snap(double v)`(가장 가까운 스텝 + clamp), `bool canDecrease(double v)`, `bool canIncrease(double v)`, `double decrease(double v)`, `double increase(double v)`
  - `static EnvRange EnvRange.fromSettings(double? min, double? max, EnvRangeRule rule, EnvRange fallback)` — 순서: ① min·max 각각 null이면 fallback의 같은 쪽 ② `rule.snap` ③ `min >= max`면 **둘 다** fallback
  - `class TempOffset { final double value; }` — `value`는 **사용자 보정값**(측정값에 더하는 수, 끔=0): `static const maxMagnitude = 4.0, step = 0.1`, `bool get isOff => value == 0`, `bool get isSubtract => value < 0`, `double get magnitude => value.abs()`, `bool get outOfEditorRange => magnitude > maxMagnitude`, `factory TempOffset.of({required bool subtract, required double magnitude})`(0.1~4.0 밖이면 `ArgumentError`), `static TempOffset fromDevice(double deviceValue)`(throw 없음), `double toDeviceValue()`, `static double rawFrom(double reportedTemp, double deviceOffset)` = `reportedTemp - deviceOffset`, `double apply(double raw)` = `raw + value`
- Must know: 부동소수 비교·스텝 계산은 0.1 단위 정수로(`(v*10).round()`). **D1 임시 규칙**: `fromDevice(x) = TempOffset(x)`, `toDeviceValue() = value` — 회신에 따라 이 두 개와 `isOff`만 바뀌도록 다른 곳은 `value`를 직접 기기 값으로 쓰지 않는다. 15/29는 **설정 가능 범위**일 뿐 이 파일은 판정을 하지 않는다. `home`이 아니라 `shared/domain`에 두는 이유: `my_cage/domain/device_settings.dart`가 import한다.
- Acceptance: 아래 테스트 PASS.

- [ ] **Step 1: 실패 테스트**

```dart
test('null 설정은 디폴트', () => expect(EnvRange.fromSettings(null, null, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(18, 26)));
test('한쪽 null은 그쪽만 디폴트', () => expect(EnvRange.fromSettings(20, null, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(20, 26)));
test('범위 밖은 clamp', () => expect(EnvRange.fromSettings(10, 35, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(15, 29)));
test('스텝 불일치는 맞춤', () => expect(EnvRange.fromSettings(18.3, 26, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(18.5, 26)));
test('min>=max면 둘 다 디폴트', () => expect(EnvRange.fromSettings(24, 24, EnvRangeRule.temp, EnvRange.tempDefault), const EnvRange(18, 26)));
test('온도 0.5 스텝·상한', () { expect(EnvRangeRule.temp.decrease(18), 17.5); expect(EnvRangeRule.temp.canIncrease(29), isFalse); });
test('습도 5 스텝·하한', () { expect(EnvRangeRule.humid.decrease(40), 35); expect(EnvRangeRule.humid.canDecrease(35), isFalse); });
test('스텝 배수 아님은 무효', () => expect(const EnvRange(18.3, 26).isValidFor(EnvRangeRule.temp), isFalse));
test('보정 빼기 1.0', () { final o = TempOffset.of(subtract: true, magnitude: 1.0); expect(o.value, -1.0); expect(o.apply(26.2), closeTo(25.2, 1e-9)); });
test('원래 측정값 복원', () => expect(TempOffset.rawFrom(24.7, -1.5), closeTo(26.2, 1e-9)));
test('편집기 범위 0.1~4.0', () { expect(() => TempOffset.of(subtract: false, magnitude: 4.1), throwsArgumentError); expect(() => TempOffset.of(subtract: false, magnitude: 0), throwsArgumentError); });
test('기기 값 ±4 초과도 throw 없음', () { final o = TempOffset.fromDevice(-6); expect(o.outOfEditorRange, isTrue); expect(o.isOff, isFalse); });
test('D1 임시: 끔은 0', () { expect(TempOffset.fromDevice(0).isOff, isTrue); expect(const TempOffset(0).toDeviceValue(), 0); });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/shared/domain/env_thresholds_test.dart` → FAIL(파일 없음)
- [ ] **Step 3: 구현** — Produces 시그니처대로
- [ ] **Step 4: PASS 확인** — 같은 명령 → PASS
- [ ] **Step 5: 커밋** `feat(env): 적정 온습도 범위·온도 보정 도메인(v4 1-1·1-2)` (버전 minor + CHANGELOG "추가")

---

### Task 2: 설정 쓰기 — MIN/MAX PATCH, 보정 명령 저장소, `Device.tempOffsetC`

**Files:**
- Modify: `lib/features/my_cage/data/device_settings_repository.dart` (`patch`에 named 4개)
- Modify: `lib/features/my_cage/domain/device_settings.dart` (`patchBody` 4개 + `EnvRange get tempRange`/`humidRange` — `EnvRange.fromSettings` 사용)
- Modify: `lib/features/my_cage/domain/device.dart` (`final double? tempOffsetC` — `temp_offset_c` 파싱, ±10 밖·숫자 아님은 null)
- Create: `lib/features/my_cage/data/temp_offset_repository.dart`
- Test: `test/features/my_cage/device_settings_range_test.dart`, `test/features/my_cage/temp_offset_repository_test.dart`

**Context:**
- Depends on: Task 1
- Produces:
  - `DeviceSettingsRepository.patch(String deviceId, {double? targetTempC, double? targetHumidityPct, double? targetTempMin, double? targetTempMax, double? targetHumidMin, double? targetHumidMax})`
  - `DeviceSettings.tempRange` / `humidRange` (`EnvRange`)
  - `Device.tempOffsetC` (`double?`)
  - `class TempOffsetRepository { Future<String?> send(String deviceId, TempOffset offset); }` — REST `POST /devices/{id}/commands` body `{"action":"set_temp_offset","payload":{"offset_c": offset.toDeviceValue()}}`, 응답의 `id`(commands 행 id)를 돌려준다(없으면 null). `TerraRestClient.post` 사용. provider `tempOffsetRepositoryProvider`
- Must know:
  - `patchBody`는 **보낸 필드만** 넣는다(기존 규칙). MIN/MAX는 한 화면에서 두 값을 **함께** 보낸다.
  - Supabase `commands` 직결 INSERT로 보내지 않는다(G4). `CommandAction`·`actuator_marker.dart`는 건드리지 않는다.
  - `Device`는 `deviceListProvider`(1회 조회)에서 온다 — 저장 후 갱신은 Task 4가 맡는다(여기서는 파싱만).
- Acceptance: 테스트 PASS + `flutter analyze` 0.

- [ ] **Step 1: 실패 테스트**

```dart
test('MIN/MAX 패치 본문', () => expect(DeviceSettings.patchBody(targetTempMin: 17.5, targetTempMax: 29), {'target_temp_min': 17.5, 'target_temp_max': 29.0}));
test('tempRange 디폴트', () => expect(const DeviceSettings(deviceId: 'd').tempRange, EnvRange.tempDefault));
test('humidRange 저장값', () => expect(const DeviceSettings(deviceId: 'd', targetHumidMin: 35, targetHumidMax: 85).humidRange, const EnvRange(35, 85)));
test('temp_offset_c 파싱', () { expect(Device.fromJson({...base, 'temp_offset_c': -1.5}).tempOffsetC, -1.5); expect(Device.fromJson({...base, 'temp_offset_c': 12}).tempOffsetC, isNull); });
test('보정 명령 본문·id 반환', () async { /* fake TerraRestClient: post → {'id': 'c1'} */ expect(await repo.send('d1', const TempOffset(1.0)), 'c1'); expect(fake.lastPost, ('/devices/d1/commands', {'action': 'set_temp_offset', 'payload': {'offset_c': 1.0}})); });
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/my_cage/device_settings_range_test.dart test/features/my_cage/temp_offset_repository_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 적정 MIN/MAX 저장·온도 보정 명령 데이터 계층` (버전 patch + CHANGELOG)

---

### Task 7: 이탈 알림 수신 설정 — 서버 테이블 + 앱 저장소

**Files:**
- Create: `supabase/migrations/20261102000000_env_alert_preferences.sql`
- Create: `lib/features/home/data/env_alert_prefs_repository.dart`
- Create: `lib/features/home/presentation/env_alert_prefs_providers.dart`
- Test: `test/features/home/env_alert_prefs_repository_test.dart`

**Context:**
- Depends on: 없음 (D2 확정: 계정 단위)
- Produces:
  - 테이블 `public.notification_preferences`(아래 SQL)
  - `class EnvAlertPrefs { final bool temp; final bool humid; }`, `EnvAlertPrefsRepository { Future<EnvAlertPrefs> load(); Future<void> setTemp(bool on); Future<void> setHumid(bool on); }`
  - `envAlertPrefsProvider` — `AsyncNotifierProvider.autoDispose`, 계정 id select-watch, 행 없으면 둘 다 true. `Future<void> setTemp(bool)`/`setHumid(bool)`: 낙관적으로 state를 바꾸고 저장 실패 시 이전 값으로 되돌린 뒤 예외를 다시 던진다
- Must know: 마이그레이션 전문(결정을 담은 선언):

```sql
-- 계정 단위 푸시 수신 설정(v4 온습도 이탈 알림, 2026-11-02 D2). 행이 없으면 모두 켬.
-- 나중에 다른 주제를 옮길 때도 열을 더한다(env_ 접두어).
CREATE TABLE public.notification_preferences (
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

  - `IF NOT EXISTS`를 쓰지 않는다 — 테이블이 이미 있으면 실패해야 정책 충돌을 숨기지 않는다(G6 재확인이 먼저).
  - 쓰기는 **필드 하나씩** `upsert({'user_id', 'env_temp' 또는 'env_humid', 'updated_at': now UTC}, onConflict: 'user_id')`, `.select()` 없이. 두 값을 통째로 보내지 않는다(빠른 연속 토글이 서로 덮어쓰지 않게).
  - 기존 Hive `NotificationPrefs`(하이라이트·댓글 등)는 이번에 옮기지 않는다. `notification_preferences_repository.dart` 상단 주석의 "서버 테이블은 앱 팀 마이그레이션 뒤" 문단에 "env_temp·env_humid만 서버에 있음(2026-11-02)" 한 줄을 더한다.
- Acceptance: 테스트(가짜 클라이언트) PASS + branch DB에서 다른 계정 행 SELECT 0건.

- [ ] **Step 1: G6 재확인** — `select to_regclass('public.notification_preferences')` → null
- [ ] **Step 2: 실패 테스트** — `행 없으면 둘 다 true`, `setHumid(false) → upsert 본문에 env_humid만`, `저장 실패 시 state 원복`
- [ ] **Step 3: 실패 확인** → **Step 4: 구현** → **Step 5: PASS** (`flutter test test/features/home/env_alert_prefs_repository_test.dart`)
- [ ] **Step 6: branch DB 검증** — 마이그레이션 적용 후 두 계정으로 select → 자기 행만
- [ ] **Step 7: 커밋** `feat(env): 온습도 이탈 알림 수신 설정 테이블·저장소` (버전 patch + CHANGELOG)

---

### Task 5: 적정 온도·습도 설정 화면 + 스테퍼 (S08·S10·S11·S13·S27)

**Files:**
- Create: `lib/features/home/presentation/env_range_setting_screen.dart` (`EnvRangeSettingScreen`)
- Create: `lib/shared/widgets/viva_stepper.dart` (`VivaStepper`)
- Modify: `lib/core/router/app_router.dart` — 최상위 `/temp-humid-settings/:deviceId/temp`, `/temp-humid-settings/:deviceId/humid` (Task 3이 부모 경로를 만든다 — 이 Task에서 부모까지 함께 등록해도 된다)
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/env_range_setting_screen_test.dart`

**Context:**
- Depends on: Task 1, 2
- Produces: `EnvRangeSettingScreen({required String deviceId, required EnvRangeKind kind})` (`enum EnvRangeKind { temp, humid }`), `VivaStepper({required String value, VoidCallback? onDecrease, VoidCallback? onIncrease})` — null 콜백 = 비활성(S27 `StepMinus_disabled`). 라우트 상수 `kTempHumidSettingPath = '/temp-humid-settings'` + `String tempHumidRangePath(String deviceId, EnvRangeKind kind)` (`app_router.dart`)
- Must know:
  - 대상 기기는 **라우트의 `deviceId`로 고정**한다(편집 중 홈 세트가 바뀌어도 그 기기에 저장).
  - 헤더 행 "적정 온도" + 현재 **저장값** `18℃ ~ 26℃`(빨강) / 최소·최대 행에 스테퍼. 최소의 +는 `min + step < max`일 때만, 최대의 −는 `max − step > min`일 때만, 그 밖은 `EnvRangeRule.canIncrease/canDecrease`.
  - 편집값이 저장값과 다르면 하단에 "변경 사항 취소"(빨강 텍스트 버튼) — 누르면 저장값으로(S10). 저장 버튼은 하단 고정(Figma 좌표 그대로, CLAUDE.md "공통 하단 CTA" 대조).
  - 저장: `isValidFor` 통과 시에만 활성 → `patch(min, max 둘 다)` → 성공 시 `ref.invalidate(deviceSettingsProvider(deviceId))` 후 pop. 실패 시 값 유지 + 안내.
  - 가이드 문구(S08/S11)는 Figma 그대로. 습도 가이드 "최저 습도 미만으로 떨어지면 즉시 알림…"은 실제(2분 유지)와 다르다 → Figma 그대로 두고 RESULTS에 기획 질의 항목으로 기록.
- Acceptance: (1) 최대 29에서 + 비활성 (2) 최소 17.5로 바꾸면 "변경 사항 취소" 등장, 누르면 18 복귀 (3) 저장 시 `patch(targetTempMin: 17.5, targetTempMax: 26)` 1회 + invalidate (4) 습도 최소 35에서 − 비활성 (5) 저장값 18.3(콘솔 입력) → 18.5로 보이고 저장 가능.

- [ ] **Step 1: 실패 테스트** — Acceptance 5개
- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/env_range_setting_screen_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 적정 온도·습도 설정 화면과 스테퍼(Figma 1635:5123·1635:5165)` (버전 minor + CHANGELOG)

---

### Task 3: 온습도 설정 화면 (S04·S05·S06)

**Files:**
- Create: `lib/features/home/presentation/temp_humid_setting_screen.dart` (`TempHumidSettingScreen`)
- Modify: `lib/core/router/app_router.dart` — 최상위 `/temp-humid-settings/:deviceId` (+ Task 5 자식, Task 4의 `offset` 자식 자리)
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/temp_humid_setting_screen_test.dart`

**Context:**
- Depends on: Task 2, 5, 7
- Consumes: `deviceSettingsProvider(deviceId)`, `envAlertPrefsProvider`, `deviceListProvider`(이름·`tempOffsetC`), `moduleOnlineProvider(deviceId)`
- Produces: `TempHumidSettingScreen({required String deviceId})`, `String tempHumidSettingPath(String deviceId)`
- Must know:
  - 최상위 라우트로 둔다(온습도 상세의 자식이 아님) — 알림 설정에서 들어와도 뒤로 가기가 알림 설정으로 간다.
  - 머리(AppBar 제목 아래 또는 첫 섹션 위)에 사육장 이름을 보여 준다 — 기기별 MIN/MAX와 계정 단위 토글이 한 화면에 있어서 어느 사육장인지 알려야 한다. Figma에 없는 요소라 RESULTS에 "추가"로 기록.
  - 구성(Figma S05): "온도 보정" 카드[토글 / (켜짐이면) 보정 값 행] + 각주 "사육장 상하 온도차로 하단 온도보다 높게 측정될 수 있습니다". "온도" 카드[이탈 알림 토글 / 적정 온도 `18℃ ~ 26℃` >] + 각주 "`{min}`℃ 미만이거나 `{max}`℃ 초과인 경우 이탈 안내를 합니다". "습도"도 같은 모양. 수치·색·간격은 `figma-structure-setting.md` S04~S06.
  - 이탈 알림 토글: `envAlertPrefsProvider.setTemp/setHumid` — 실패하면 provider가 원복, 화면은 스낵바 안내(이 화면은 시트가 아니므로 `ControlFeedback`이 아니라 일반 스낵바).
  - **보정 섹션은 Task 4 전까지 표시만**: 토글·행을 그리되 `tempOffsetC`로 상태만 보여 주고(0이면 꺼짐, 아니면 켜짐 + "측정값 −1.5℃"), 탭 동작은 Task 4에서 붙인다. 구 펌웨어(`tempOffsetC == null`)면 토글 비활성 + "펌웨어 업데이트 후 사용할 수 있어요".
  - 기기 없음(라우트 id가 내 목록에 없음)이면 이유 문구, 오프라인이면 `DeviceOfflineNotice`.
  - `/env-settings`·`SetpointSettingTile`·`showSetpointSheet`는 건드리지 않는다(D3).
- Acceptance: 위젯 테스트 — (1) 설정 없음 → "18℃ ~ 26℃", "40% ~ 80%" (2) `tempOffsetC = -1.5` → 보정 토글 켜짐 + "측정값 -1.5℃", 0 → 꺼짐 (3) 사육장 이름 표시 (4) 적정 온도 행 탭 → `tempHumidRangePath(id, temp)` push (5) `toggle_failure_reverts` — 습도 토글 끔 + 저장 실패 → 켜짐으로 복귀 + 스낵바.

- [ ] **Step 1: 실패 테스트** — Acceptance 5개
- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/temp_humid_setting_screen_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 온습도 설정 화면(Figma 1623:8671)` (버전 minor + CHANGELOG)

---

### Task 6: 온습도 상세 — 범위 바·설정 진입·실시간 카드 (A04·A06·A08·A10·A12·A13·S03)

**Files:**
- Create: `lib/features/home/domain/env_alert.dart` (`EnvAlert`, `EnvAlertMetric { temp, humid }`, `EnvAlertLevel { caution, danger }`)
- Create: `lib/features/home/data/env_alert_repository.dart`
- Create: `lib/features/home/presentation/env_alert_providers.dart`
- Create: `lib/features/home/presentation/widgets/env_range_bar.dart` (`EnvRangeBar`)
- Create: `lib/features/home/presentation/widgets/env_alert_card.dart` (`EnvAlertCard`)
- Modify: `lib/features/home/presentation/env_detail_screen.dart` (`_topBar`: 왼쪽 ✕·오른쪽 설정 아이콘 / `_valueBar` → `EnvRangeBar` 2줄 / 오늘이면 차트 아래 `EnvAlertCard`)
- Test: `test/features/home/env_alert_test.dart`, `test/features/home/env_alert_repository_test.dart`, `test/features/home/env_range_bar_test.dart`, `test/features/home/env_alert_card_test.dart`, 기존 `test/features/home/env_detail_screen_test.dart` 수정

**Context:**
- Depends on: Task 1, 2, 3(설정 경로)
- Produces:
  - `EnvAlert.fromRow(Map<String, dynamic>) -> EnvAlert?` — `kind ∈ {env_temp_high, env_temp_low, env_humid_low, env_humid_high}` + `context.rule == 'v4'`만 통과. 필드: `id, kind, metric, level(context.level), chip(message의 [ ] 안, 없으면 null), title(] 뒤 trim, [ ] 형식이 아니면 message 전체), triggeredAt, resolvedAt`
  - `EnvAlertRepository.watchOpen(String deviceId) -> Stream<List<EnvAlert>>` — 처음 `select('*').eq('device_id', id).isFilter('resolved_at', null).like('kind', 'env\_%')`(결과는 `fromRow`로 다시 거름) + `bindResilientChannel`(`lib/core/supabase/realtime_binding.dart`)로 `alerts` INSERT/UPDATE(`device_id=eq.<id>`) 반영, `onRejoined`에서 처음 조회를 다시 해 목록을 통째로 바꾼다. 지표별 열린 행은 `triggeredAt` 최신 1개만 남긴다(G8)
  - `openEnvAlertsProvider` (`StreamProvider.autoDispose`, 계정 id select-watch + `currentDeviceIdProvider`)
  - `EnvRangeBar({required EnvBarKind kind, required double? value, required double? low, required double? high, required EnvRange range, double dim = 1})` — `EnvBarKind.temp` 전체 바 12~30, `humid` 20~100
- Must know:
  - 범위 바 규칙(A04): 전체 바 길이는 화면 폭에 따름. 적정 구간은 전체 바에서 같은 비율 위치. 값이 바 밖이면 원은 끝에 고정. 숫자: 현재값 NN.N(소수 0이어도 표시), 바 양옆 최저·최고 NN(**버림**), 적정 구간 눈금 `formatCompact`.
  - 오늘 = 현재값(`envLiveViewProvider`, 신선도 흐림 `dim` 그대로) + 오늘 최저·최고(`envDayExtremesProvider`) + 적정 구간(`deviceSettingsProvider` → `tempRange`). 지난 날 = 하루 평균(`envDailyAverageProvider`) + 그날 최저·최고 + **현재** 적정 구간(Figma A14와 같음, RESULTS에 "현재 기준" 기록).
  - 카드 줄 순서: 경고 먼저, 같은 등급이면 온도→습도. 칩 색은 A10·A12 덤프에서 역할색으로 매핑(새 역할색이면 GlassPalette 6곳 규칙). 설명 문구는 1-5 설명 열을 `kind+level`로 고정 매핑(ko.json): 저온 경고 "즉시 온도를 올려주세요" / 고온 경고·고온 주의 "환기팬 또는 냉각팬 사용을 추천드려요" / 저온 주의 "난방 장치 사용을 추천드려요" / 건조 주의 "사육장에 수분을 보충해 주세요" / 과습 주의 "환기 상태를 점검해 주세요".
  - 칩·제목은 `message`를 나눠 쓰기만 한다(D4). 숫자를 다시 계산하거나 `%p`를 `%`로 바꾸지 않는다.
  - 카드는 **오늘 화면에서만**, 열린 행이 있을 때만. 지난 날은 Stage P 자리라 그리지 않는다.
  - `alerts`를 `deviceListProvider`·`camerasProvider` 같은 공용 목록 provider에 넣지 않는다(재조회 깜빡임 교훈).
  - 설정 아이콘 키 `EnvDetailScreen.settingsKey`, 탭 → `tempHumidSettingPath(currentDeviceId)`. 기기가 없으면 아이콘을 숨긴다.
  - 그래프 터치 말풍선(A05)은 기존 `EnvDayChart` 스크러버로 이미 있다 — 새로 만들지 않고 Task 9 수치 검수에서 대조만.
- Acceptance: 테스트 PASS + 기존 env_detail 테스트 수정 후 PASS.

- [ ] **Step 1: 실패 테스트**

```dart
test('env_* 아닌 kind는 제외', () => expect(EnvAlert.fromRow({...row, 'kind': 'temp_high'}), isNull));
test('rule v4 아니면 제외', () => expect(EnvAlert.fromRow({...row, 'context': {'rule': 'legacy'}}), isNull));
test('message 분리', () { final a = EnvAlert.fromRow(row)!; expect(a.chip, '고온 주의'); expect(a.title, '적정 온도보다 +0.3℃'); });
test('지표별 최신 1개', ...);                              // 같은 metric 열린 행 2개 → 최신만
test('rejoin_refetches_and_drops_resolved', ...);        // 가짜 채널 rejoin → 재조회 결과로 교체
testWidgets('out_of_range_value_clamps_marker', ...);    // 온도 35 → 원 x == 바 오른쪽 끝, 숫자 "35.0℃"
testWidgets('최저 15.9 → "15" (버림)', ...);
testWidgets('경고가 주의보다 위', ...);
testWidgets('열린 행 0개면 카드 없음', ...);
testWidgets('설정 아이콘 → 온습도 설정', ...);
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/env_alert_test.dart test/features/home/env_alert_repository_test.dart test/features/home/env_range_bar_test.dart test/features/home/env_alert_card_test.dart test/features/home/env_detail_screen_test.dart`)
- [ ] **Step 5: 커밋** 두 개 — `feat(env): 온습도 상세 범위 바·설정 진입(Figma 1610:6588)` / `feat(env): v4 실시간 이탈 카드(alerts env_*)` (각각 버전 + CHANGELOG)

---

### Task 8: `env.alert.triggered` 푸시 수신 — 계약·문구·수신 끔·탭 이동

**Files:**
- Modify: `supabase/functions/_shared/notification-contract.mjs` (+ `.test.mjs`)
- Modify: `supabase/functions/_shared/firebase-message.mjs` (+ `.test.mjs`) — `env.alert.triggered`도 `vivanaut_safety` 채널
- Create: `supabase/migrations/20261102000100_notification_env_alert.sql`
- Modify: `supabase/functions/_shared/notification-migration.test.mjs` — 새 마이그레이션 문자열 검사
- Modify: `lib/features/notification/domain/app_notification.dart` (`knownNotificationKinds`에 `'env.alert.triggered'`)
- Modify: `lib/features/notification/presentation/notification_center_screen.dart` (`_category`에 `'env'`) + `ko.json` `notifications_category_env`
- Modify: `lib/features/notification/domain/push_lifecycle_controller.dart` — env 알림을 열 때 `data.device_id`로 `selectedHomeDeviceIdProvider` 전환 후 이동(알림함 탭도 같은 경로를 쓰는지 확인하고 아니면 같은 처리)
- Test: 위 `.test.mjs`, `test/features/notification/` (app_notification·push_lifecycle)

**Context:**
- Depends on: Task 7
- Consumes: 서버 문서 §2 봉투(`schema_version 1`, `event_id`, `type`, `occurred_at`, `user_id`, `payload{alert_id, device_id, device_key?, device_name, enclosure_id, kind, level, phase, title, value, threshold}`)
- Produces: 계약 검사 — 필수 `alert_id, device_id, kind(4종), level(caution|danger), phase(started|reminder), title(비어 있지 않음)`, `device_key`·`device_name`·`enclosure_id`는 있으면 문자열
- Must know:
  - **CHECK 제약:** `notification_events_type_check`(최신 정의 `20260916000000_notification_device_action_copy.sql:11-13`)를 같은 방식으로 DROP/ADD하고 기존 타입 목록에 `'env.alert.triggered'`를 더한다.
  - **트리거 함수 `notification_event_after_insert`**: 최신 정의는 `20261001000000_notification_device_offline_copy.sql`. 그 본문 전체를 복사해 `CREATE OR REPLACE`하고 `WHEN 'env.alert.triggered'` 분기만 더한다(다른 분기 유실 금지, CASE에 ELSE 없음 주의):
    - `v_title := NEW.payload ->> 'title'`, `v_body := COALESCE(NULLIF(NEW.payload ->> 'device_name',''), '사육장')`, `v_route := '/env-detail'`. category = `split_part(type,'.',1)` = `env`.
    - outbox INSERT 직전: `kind`가 `env.alert.triggered`이면 `payload.kind LIKE 'env_temp_%'` → `env_temp`, `'env_humid_%'` → `env_humid` 값을 `COALESCE((SELECT … FROM notification_preferences WHERE user_id = NEW.user_id), true)`로 읽어 false면 outbox만 건너뛴다.
    - 주석: `|| NEW.payload`가 `data.kind`를 payload의 `env_*`로 덮는다 — 앱은 컬럼 `kind`를 쓴다.
  - **우선순위 함수 `claim_notification_outbox`**(`20260915000000_fcm_notifications.sql`): 최신 정의를 복사해 `CREATE OR REPLACE`, `WHEN n.kind = 'env.alert.triggered' THEN 0`을 `safety.%`와 같은 등급으로 추가.
  - **배포 순서(고정):** branch에 마이그레이션 → branch 검증 → (사용자 승인) 운영 마이그레이션 → `notification-ingest`·`dispatch-push` 운영 재배포(계약·채널 파일이 바뀌므로) → 서버에 "2단계 켜도 됨" 회신.
  - 탭 이동 대상 `/env-detail`은 `notification_route.dart` 허용 목록에 이미 있다.
- Acceptance: node 테스트 PASS + branch DB에서 (a) 끔 사용자 이벤트 → `app_notifications` 1행·outbox 0행 (b) 켬(행 없음) 사용자 → 1행·1행 (c) 같은 `event_id` 두 번 INSERT → `notification_events` 1행(유니크). ingest 202 duplicate는 재배포 후 함수 호출로 확인.

- [ ] **Step 1: 실패 테스트** (`notification-contract.test.mjs`)

```js
test('env alert started 통과', () => assert.equal(validateNotificationEvent(envEvent()).ok, true));
test('env alert reminder 통과', () => assert.equal(validateNotificationEvent(envEvent({ phase: 'reminder' })).ok, true));
test('env alert level 오타 거절', () => assert.equal(validateNotificationEvent(envEvent({ level: 'warning' })).ok, false));
test('env alert title 빈 값 거절', () => assert.equal(validateNotificationEvent(envEvent({ title: '' })).ok, false));
test('device_key 없어도 통과', () => assert.equal(validateNotificationEvent(envEvent({ device_key: undefined })).ok, true));
```

- [ ] **Step 2: 실패 확인** — `node --test supabase/functions/_shared/` → FAIL
- [ ] **Step 3: 구현** — 계약 + 채널 + 마이그레이션 + 앱 3파일
- [ ] **Step 4: PASS** — 같은 명령 + `flutter test test/features/notification/`
- [ ] **Step 5: branch DB 검증** — Acceptance (a)(b)(c)
- [ ] **Step 6: 커밋** `feat(push): v4 온습도 이탈 푸시 수신(env.alert.triggered)·수신 끔 거르기` (버전 minor + CHANGELOG)

---

### Task 9: 알림 설정 진입 + 수치 검수

**Files:**
- Modify: `lib/features/profile/presentation/notification_settings_screen.dart` — "기능 설정"에 "온습도 이탈 알림 / 적정 온습도에서 이탈했을 때 받는 알림 / 설정하기 >" 이동 행(하이라이트 영상 아래, S39 순서)
- Create: `test/features/profile/notification_settings_screen_test.dart` (없으면 생성, 있으면 수정)
- Modify: `test/design/text_scale_overflow_test.dart` — 새 화면 3개(온습도 설정·적정 범위·보정값) 추가
- Create: `docs/design-audits/2026-11-02-env-alerts-v4/RESULTS.md`

**Context:**
- Depends on: Task 3~8
- Must know: 이 행은 토글이 아니라 이동 행이다(S39). 대상 기기 = 홈 세트의 기기(`currentDeviceIdProvider`), 없으면 행 비활성 + 이유. 시스템 알림 권한이 꺼져 있으면 다른 기능 토글처럼 흐리게(기존 규칙) — 이동은 막지 않는다.
- Acceptance: `flutter analyze` 0, `flutter test` 전체 PASS, RESULTS.md에 S05·S08·S11·A10 수치 대조표(원본/앱/차이)와 캡처. Figma 밖 추가(사육장 이름)와 의도된 차이(습도 `%p`·정수, 지난 날 현재 기준 적정 구간, 습도 가이드 "즉시" 문구) 기록.

- [ ] **Step 1~4:** 테스트 → 구현 → PASS
- [ ] **Step 5: 수치 검수** — 시뮬레이터 393×852에서 캡처, 덤프와 대조, 차이는 RESULTS에 남기고 보고
- [ ] **Step 6: 커밋** `feat(env): 알림 설정에서 온습도 설정 진입·수치 검수` (버전 patch + CHANGELOG)

---

### Task 4: 보정값 설정 화면 + 보정 토글 동작 (S14·S16·S33~S37, S45~S47) — 맨 뒤

**Files:**
- Create: `lib/features/home/presentation/temp_offset_screen.dart` (`TempOffsetScreen`)
- Create: `lib/features/home/presentation/widgets/offset_direction_toggle.dart`, `offset_slider.dart`
- Create: `lib/features/home/presentation/temp_offset_providers.dart` — `deviceOffsetProvider(deviceId)`(devices 행 UPDATE 구독, `temp_offset_c`만), `tempOffsetSaveProvider`
- Modify: `lib/features/home/presentation/temp_humid_setting_screen.dart` (보정 토글·행 동작), `lib/core/router/app_router.dart` (`/temp-humid-settings/:deviceId/offset`), `assets/l10n/ko.json`
- Test: `test/features/home/temp_offset_screen_test.dart`, `test/features/home/temp_humid_setting_screen_test.dart` 추가

**Context:**
- Depends on: Task 2, 3. **착수 조건:** G9 실측(사용자 승인 후 실기기 1대) 또는 서버 회신 Q1·Q2 중 하나. 둘 다 없으면 사용자에게 진행 여부를 묻는다.
- Consumes: `deviceOffsetProvider`, `envLiveViewProvider(deviceId)`, `TempOffsetRepository.send`
- Produces: `TempOffsetScreen({required String deviceId})` — 결과로 저장한 `TempOffset?`을 pop
- Must know:
  - **첫 진입 판정은 저장 상태로 계산**한다(라우트 extra 금지): `deviceOffsetProvider`가 0(꺼짐)인데 토글이 켜진 상태로 들어오면 첫 진입. 첫 진입 기본값 = 빼기 + 0.1(S45). 아니면 저장값의 방향·크기로 시작(4.0 초과면 4.0).
  - 현재 측정 온도 = `TempOffset.rawFrom(t_a, deviceOffset)`. **같은 텔레메트리 샘플 기준**으로 계산하고, 저장 직후처럼 오프셋만 바뀐 경우에는 새 텔레메트리가 올 때까지 이전 계산값을 유지한다. 신선도가 aging/offline이면 흐리게.
  - 보정 온도 = `raw + 선택값`(빨강 — 덤프 색을 역할색으로 매핑).
  - 슬라이더 0.1~4.0, 0.1 단위(39칸).
  - **저장 흐름:** 오프라인(`moduleOnlineProvider == false`)이면 저장 버튼 비활성 + 이유. 저장 → `send` → 응답 commands id의 행을 구독해 `result == ok`면 성공(1차), `deviceOffsetProvider`가 보낸 값과 같아져도 성공(보조). **15초** 안에 둘 다 없거나 `result`가 ok가 아니면 실패 안내 + 화면 유지(값을 저장됐다고 표시하지 않음). 이미 같은 값이면 보내지 않고 pop. 저장 중 중복 탭 막음. 성공 시 `ref.invalidate(deviceListProvider)`.
  - **취소:** 첫 진입이면 상위 화면의 보정 토글을 끈 상태로 되돌린다(S46, 명령 없음). 아니면 저장값 유지(S47). 시스템 뒤로가기도 취소와 같다.
  - **보정 토글 끄기:** 확인 모달("보정을 끄면 측정값이 그대로 표시돼요" 류 — 문구는 ko.json, D1 위험 안내) → `send(TempOffset(0))` → 저장 흐름과 같은 확인. 실패하면 토글 원복.
  - **보정 토글 켜기:** 화면 상태만 바뀐다(S45). "보정 값 · 설정하기" 행이 나타난다.
  - 문구는 Figma 그대로: "현재 측정 온도", "보정 온도", "실시간 온도와 주간 그래프에 보정 온도로 반영됩니다", "아래 값을", "− 빼기", "+ 더하기", "온도차 보정 가이드" + 본문 3문단, "저장", "취소".
- Acceptance: 테스트 PASS.

- [ ] **Step 1: 실패 테스트**

```dart
testWidgets('첫 진입 기본 빼기 0.1, 측정 26.2 → 보정 26.1', ...);   // t_a 24.7, device offset -1.5, 토글만 켠 상태
testWidgets('더하기 1.0 → 보정 온도 27.2', ...);
testWidgets('저장: commands result ok 오면 pop', ...);
testWidgets('저장: 15초 무응답이면 실패 안내·화면 유지', ...);
testWidgets('오프라인이면 저장 비활성', ...);
testWidgets('cancel_on_first_entry_turns_toggle_off', ...);    // 명령 0회
testWidgets('cancel_after_saved_restores_previous', ...);      // 저장값 -2에서 +3 고르고 취소 → -2 유지, send 0회
testWidgets('토글 끄기는 확인 모달 후 offset 0 전송', ...);
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현** → **Step 4: PASS** (`flutter test test/features/home/temp_offset_screen_test.dart test/features/home/temp_humid_setting_screen_test.dart`)
- [ ] **Step 5: 커밋** `feat(env): 온도 보정 설정(Figma 1635:5551)` (버전 minor + CHANGELOG)

---

## 서버에 회신할 것 (구현과 함께)

질문과 지금 보낼 회신은 [`docs/handoffs/2026-11-02-env-alerts-v4-server-questions.md`](../../handoffs/2026-11-02-env-alerts-v4-server-questions.md)에 있다. 구현 뒤에 보낼 것:

| 서버 문서 항목 | 회신 내용 | 시점 |
|---|---|---|
| §4 1단계 | Task 6 배포 후 "`ALERTS_V4_ENABLED` 켜도 됨" | Task 6 뒤 |
| §4 2단계 | Task 8 운영 반영(마이그레이션·함수 재배포) 후 "`PUSH_ENV_ALERTS_ENABLED` 켜도 됨" | Task 8 뒤 |
| N2 | 앱 범위 밖 값 미전송 확인 → N2 배포 가능 | Task 5 뒤 |
