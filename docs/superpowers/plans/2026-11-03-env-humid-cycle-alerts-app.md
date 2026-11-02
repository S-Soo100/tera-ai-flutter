# v4 환기 지연·분무 필요 실시간 카드 (앱 받는 쪽) Implementation Plan

> **구현 방식 (CAOF):** Standard 트랙(앱 파일 3~4개 + 앱 소유 SQL 함수 1개). 메인이 직접 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.
> 상태: 초안 r1 (2026-11-03) — 사용자 승인 대기. **서버 Stage O는 기획 결정 대기(착수 전)** 라 실데이터는 없다. 이 계획은 서버 pre-plan의 계약을 가정하고 받는 쪽만 만든다.

**Goal:** 서버가 `alerts`에 환기 지연·분무 공백 행을 만들면, 온습도 상세 실시간 카드에 Figma A26·A36의 습도 줄("환기 지연 · 분무 후 건기 미도달", "건조 주의 · 분무 필요")로 보이고, 습도 이탈 알림을 끈 사용자에게는 그 푸시가 나가지 않게 한다.

**Architecture:** 실시간 카드는 이미 `alerts`의 `env_%` 행을 전부 받아 `EnvAlert.fromRow`가 4종만 남긴다. 여기에 2종을 더하고, 습도 "범위 이탈"과 "습기 사이클"을 서로 가리지 않게 칸을 나눈다. 푸시 문구·이동은 서버 payload 그대로라 앱 변경이 없고, 수신 끄기는 앱이 만든 DB 함수(`notification_event_after_insert`)의 kind 분기에 2종을 습도로 더한다.

**Tech Stack:** Flutter, Riverpod, easy_localization, Supabase SQL(로컬 Docker `postgres:15` 검증 → MCP `apply_migration`)

**Spec:**
- 노션 v4 1-3(환기 지연·15시간 건조 주의 판정), 1-4(습도 푸시), **1-5 실시간 안내 문구**(2026-11-03 브라우저로 재확인)
- Figma 온습도 분석 A26(`1610:5848`), A36(`1610:5861`) — `docs/design-audits/2026-11-02-env-alerts-v4/figma-structure-analysis.md`
- 서버 pre-plan `~/terra-server-wt-weekly/specs/stage-o-humid-cycle-v4.md`(O3·r2 "kind 범위", O-e 미정)
- 기존 계획 `docs/superpowers/plans/2026-11-02-env-alerts-v4-app.md` §0 "대기 — 서버 Stage O"

## Global Constraints

- 실시간 문구(노션 1-5, 그대로):
  - 환기 지연: 타이틀 `[환기 지연] 분무 후 건기 미도달` / 설명 `분무 후 6시간이 지났지만 사육장이 충분히 마르지 않았습니다. 환기를 점검해 주세요`
  - 15시간 건조 주의: 타이틀 `[건조 주의] 분무 필요` / 설명 `마지막 분무 후 15시간이 지났지만 다음 분무가 감지되지 않았습니다`
- 칩·제목은 지금처럼 서버 `message`를 `[ ]`로 나눠 쓴다(기존 D4). 설명만 앱 ko.json 고정.
- 칩 색은 습도 강조색(`humidAccent`, Figma A26·A36 칩 `#2E408C`).
- 푸시는 타이틀 문구만(1-5) — 서버 payload `title`. 앱은 문구를 만들지 않는다.
- "푸시 수신 OFF여도 기록은 남긴다"(1-5) — 수신 끄기는 outbox만 건너뛴다(기존 규칙 유지).
- `supabase db push` 금지(이력 불일치). 운영 SQL은 MCP `apply_migration`으로, **사용자 승인 뒤에만**.
- 건드리지 않는 것: 기존 4종(`env_temp_high/low`, `env_humid_high/low`)의 판정·문구·순서, 일일·주간 카드(서버 문구 그대로라 변경 없음), 푸시 표시·이동(`AppNotification`), `humid_cycles` 테이블(Figma에 화면 없음 — 구독 안 함), 자동 환기·분무 토글(S41~S44).

## 가정

| # | 가정 | 상태 |
|---|---|---|
| G1 | kind 이름 `env_vent_delay`(환기 지연), `env_mist_gap`(15시간 분무 공백) | **미확정** — 서버 pre-plan O3·r2 명칭. `env_mist_gap`은 O-e(이름·푸시 여부) 결정 대기 |
| G2 | 행은 기존 v4 행처럼 `context.rule = 'v4'`, `message = "[칩] 제목"` | **미확정** — O3에 메시지 `[환기 지연] 분무 후 건기 미도달`만 적혀 있음 |
| G3 | `context.level`은 `caution`이거나 없을 수 있다(서버 severity `warning`) | **미확정** |
| G4 | 두 종류 모두 `alerts` Realtime·RLS 경로가 기존과 같다 | 확인 — 앱 조회가 `kind like 'env\_%'`(`env_alert_repository.dart:39`) |
| G5 | 푸시 payload `kind`가 위 이름이다(수신 끄기 SQL이 이걸 본다) | **미확정** |

미확정 G1~G3·G5는 서버 회신 요청(Task 4)에 넣는다. 이름이 바뀌면 고칠 곳은 `EnvAlert`의 kind 표 한 곳 + SQL 한 줄이다.

## 결정 (D)

| # | 질문 | 결정(추천) | 이유 |
|---|---|---|---|
| D1 | 등급이 없거나 모르는 값이면? | 새 2종만 **주의(caution)로 본다**. 기존 4종은 지금처럼 버린다 | 서버 pre-plan엔 severity만 있고 level 언급이 없다. 버리면 서버 계약이 조금만 달라도 카드가 조용히 사라진다 |
| D2 | 한 카드에 습도 줄이 둘이면? | 습도 **범위 이탈**(건조·과습)과 **습기 사이클**(환기 지연·분무 공백)을 **다른 칸**으로 — 칸마다 최신 1개, 최대 3줄(온도·습도·사이클) | "지금 건조함"과 "15시간째 분무 없음"은 원인·할 일이 달라 하나가 다른 하나를 가리면 안 된다. Figma엔 3줄 예시가 없다 → **사용자가 정할 것 ①** |
| D3 | 줄 순서 | 경고 먼저, 같은 등급이면 온도 → 습도 → 사이클 | 기존 규칙(경고 먼저, 온도 → 습도)의 연장. A26·A36은 온도(위) → 사이클(아래) |
| D4 | 습도 이탈 알림을 끄면 이 둘의 푸시도 끄나? | **끈다** — 수신 끄기 SQL에서 `env_vent_%`·`env_mist_%`를 습도로 본다 | 노션 1-4 습도 푸시 표에 환기 지연이 있다. 지금 SQL은 `env_temp_%`/`env_humid_%`만 보고 나머지는 `ELSE true` → 끈 사용자에게도 나간다(이번에 발견) |
| D5 | 운영 SQL 적용 시점 | 로컬 검증 후 **사용자 승인 받아 바로**(서버 Stage O 전이라 영향 행 0) — 또는 서버 Stage O 배포 직전 | → **사용자가 정할 것 ②** |

## 실패 시나리오

| 상황 | 결과 | 막는 곳 |
|---|---|---|
| 서버가 다른 kind 이름을 씀 | 행이 조용히 빠짐(크래시 없음) | Task 4 회신 요청, 이름은 kind 표 한 곳 |
| 서버가 level 없이 보냄 | 기존 규칙이면 카드 없음 | D1 — Task 1 `missing_level_cycle_kind_is_caution` |
| 건조(MIN 미만)와 분무 공백이 동시에 열림 | 한쪽이 가려짐 | D2 — Task 1 `humid_and_cycle_both_shown` |
| 습도 알림 끈 사용자 | 환기 지연 푸시가 나감 | D4 — Task 3 |
| SQL 함수 통째 교체 중 다른 분기 유실 | 다른 알림 문구·우선순위가 바뀜 | Task 3: 운영 `pg_get_functiondef` 원문을 바탕으로 kind 분기만 바꾸고, 바뀐 줄이 그 분기뿐인지 diff로 확인 |
| 3줄 + 글자 2배 | 카드 넘침 | Task 2 글자 배율 검사 |

## 검증 방법 (구현 전 확정)

- `flutter analyze` 에러 0, `flutter test` 전체 통과.
- SQL: 로컬 Docker `postgres:15`에서 `db-local-verification.md`와 같은 바탕 위에 새 마이그레이션 적용 → 시나리오 표(Task 3) 전부 기대값.
- 화면: 커밋하지 않는 미리보기 진입점으로 mini13에 A26(온도 + 환기 지연)·A36(온도 + 분무 필요)·3줄 상태를 띄워 Figma 수치 대조, 캡처를 `docs/design-audits/2026-11-02-env-alerts-v4/app/`에 저장.
- 실데이터·실푸시: **서버 Stage O 배포 뒤에만 가능** — 이번엔 확인 못 함으로 남긴다.

## 유저 체험 시뮬레이션

1. 아침 8시에 분무했는데 사육장이 잘 안 마른다. 14시가 되면 휴대폰에 "[환기 지연] 분무 후 건기 미도달"(서버 타이틀) 푸시가 온다. 습도 이탈 알림을 꺼 둔 사람은 받지 않는다.
2. 푸시를 누르면 온습도 상세 오늘 화면. 그래프 아래 회색 카드에 남색 칩 **환기 지연** · "분무 후 건기 미도달" · "분무 후 6시간이 지났지만 사육장이 충분히 마르지 않았습니다. 환기를 점검해 주세요". 온도도 벗어나 있으면 온도 줄이 위에 있다(A26).
3. 사육장이 마르면(건기 목표 도달) 서버가 행을 닫고 그 줄이 사라진다.
4. 하루 종일 분무를 안 했다. 마지막 분무 15시간 뒤 **건조 주의** · "분무 필요" · "마지막 분무 후 15시간이 지났지만 다음 분무가 감지되지 않았습니다"(A36). 그때 습도도 MIN 아래라면 **건조 주의 · 적정 습도보다 −N%p** 줄도 함께 보인다(D2 — 두 줄 모두 "건조 주의" 칩).
5. 분무하면(새 습기 이벤트) 분무 필요 줄이 사라진다.

## Review Focus

1. **모르는 level의 새 kind** → 주의로 그려진다(기존 4종은 여전히 버림) → Task 1 `missing_level_cycle_kind_is_caution`, `unknown_level_legacy_kind_dropped`.
2. **건조 + 분무 공백 동시** → 두 줄, 순서 습도 → 사이클 → Task 1 `humid_and_cycle_both_shown`.
3. **습도 끔 + `env_vent_delay`** → 기록 1·outbox 0 → Task 3 시나리오 a.
4. **3줄 + 글자 2.0배** → 넘침 없음 → Task 2 text_scale 케이스.
5. **기존 4종 회귀** → 기존 `env_alert_test`·`env_alert_card_test` 그대로 통과.

---

### Task 1: 도메인 — 새 kind 2종, 등급 기본값, 사이클 칸, 설명 문구

**Files:**
- Modify: `lib/features/home/domain/env_alert.dart` (`_metricByKind`, `fromRow` 등급 처리, `openLatestPerMetric`, `hintKey`)
- Modify: `assets/l10n/ko.json` (`env_alert_hint_vent_delay`, `env_alert_hint_mist_gap`)
- Test: `test/features/home/env_alert_test.dart`

**Context:**
- Depends on: 없음
- Produces: `EnvAlert.isHumidCycle`(bool getter — kind가 `env_vent_delay`/`env_mist_gap`), `openLatestPerMetric`가 칸 = (metric, isHumidCycle)별 최신 1개를 돌려줌. 이름은 그대로 둔다(호출처 2곳·주석 유지).
- Must know: 지금 테스트에 `'env_mist_needed'`는 제외되어야 한다는 기대가 있다 — 이름이 다른 kind는 계속 제외(G1 이름만 받는다). 칩 색은 `EnvAlertCard`가 `metric`으로 고르므로 metric은 `humid`.
- Acceptance: `flutter test test/features/home/env_alert_test.dart` 통과.

- [ ] **Step 1: 실패 테스트**
  - `vent_delay_parsed`: `_row(kind: 'env_vent_delay', message: '[환기 지연] 분무 후 건기 미도달')` → metric `humid`, chip `환기 지연`, title `분무 후 건기 미도달`, `isHumidCycle` true, `hintKey == 'env_alert_hint_vent_delay'`
  - `mist_gap_parsed`: `env_mist_gap`, `[건조 주의] 분무 필요` → chip `건조 주의`, `hintKey == 'env_alert_hint_mist_gap'`
  - `missing_level_cycle_kind_is_caution`: `context: {'rule': 'v4'}`·`{'rule':'v4','level':'warning'}` + `env_vent_delay` → level `caution`
  - `unknown_level_legacy_kind_dropped`: 같은 context + `env_humid_low` → null
  - `humid_and_cycle_both_shown`: 열린 `env_humid_low`(caution) + `env_mist_gap`(caution) + `env_temp_high`(caution) → id 순서 [온도, 습도, 사이클]
  - `cycle_latest_only`: 열린 `env_vent_delay`(이전) + `env_mist_gap`(나중) → 사이클 칸은 나중 것 1개
  - `danger_first_across_slots`: 사이클 caution + 습도 danger → 습도 먼저
- [ ] **Step 2: 실행해 실패 확인** — `flutter test test/features/home/env_alert_test.dart`
- [ ] **Step 3: 구현** — 위 Produces대로. 등급: 새 2종이면 `level ?? caution`. 정렬 키: 등급 내림 → (온도 0, 습도 1, 사이클 2).
- [ ] **Step 4: ko.json** — Global Constraints 설명 2개 그대로.
- [ ] **Step 5: 통과 확인** — 같은 명령 PASS.

### Task 2: 카드 — 3줄·2줄 설명 렌더 검사

**Files:**
- Test: `test/features/home/env_alert_card_test.dart`, `test/design/text_scale_overflow_test.dart`
- Modify(필요할 때만): `lib/features/home/presentation/widgets/env_alert_card.dart`

**Context:**
- Depends on: Task 1
- Consumes: `EnvAlert.openLatestPerMetric`, `EnvAlertCard(alerts:)`
- Must know: 카드 코드는 칩 색을 `metric`으로만 고르므로 수정이 필요 없을 가능성이 크다. Figma A26 사이클 줄: 위 줄과 구분선, 칩 `#2E408C`, 제목 16/600 lh22.1, 설명 14/500 lh19.3 두 줄(278 폭에서 줄바꿈), 줄 높이 64.
- Acceptance: 새 위젯 테스트 + 글자 배율(1.0/1.3/2.0) PASS.

- [ ] **Step 1: 테스트** — `cycle_row_uses_humid_chip_and_fixed_hint`(칩 색 `humidAccent`, 설명 = ko 문구), `three_rows_in_order`(온도·습도·사이클 키 순서), 글자 배율 케이스 "실시간 카드 3줄".
- [ ] **Step 2: 실행** — 실패하면 카드 수정, 통과하면 그대로.

### Task 3: 수신 끄기 SQL — 새 kind를 습도 토글로

**Files:**
- Create: `supabase/migrations/20261103000000_notification_env_alert_humid_cycle.sql`
- Modify: `docs/design-audits/2026-11-02-env-alerts-v4/db-local-verification.md`(결과 표 추가)

**Context:**
- Depends on: 없음
- Must know: `notification_event_after_insert`는 다른 알림 문구·분기를 다 가진 큰 함수다. **운영 `pg_get_functiondef` 원문**을 바탕으로 `CREATE OR REPLACE`하고, 바뀌는 곳은 수신 끄기 CASE 하나뿐이어야 한다. 운영 적용은 D5(사용자 승인).
- 바꿀 CASE(내용이 곧 결정):

```sql
    v_push_enabled := CASE
      WHEN NEW.payload ->> 'kind' LIKE 'env\_temp\_%' THEN COALESCE((
        SELECT p.env_temp FROM public.notification_preferences AS p
        WHERE p.user_id = NEW.user_id), true)
      -- 습도 범위 이탈 + 습기 사이클(환기 지연·분무 공백, 노션 v4 1-4 습도 푸시)
      WHEN NEW.payload ->> 'kind' LIKE 'env\_humid\_%'
        OR NEW.payload ->> 'kind' LIKE 'env\_vent\_%'
        OR NEW.payload ->> 'kind' LIKE 'env\_mist\_%' THEN COALESCE((
        SELECT p.env_humid FROM public.notification_preferences AS p
        WHERE p.user_id = NEW.user_id), true)
      ELSE true
    END;
```

- Acceptance(로컬 Docker `postgres:15`, 기존 검증 문서와 같은 바탕):

| # | 시나리오 | 기대 |
|---|---|---|
| a | 습도 끔 사용자에게 `env_vent_delay` | app_notifications 1 · outbox 0 |
| b | 습도 끔 사용자에게 `env_mist_gap` | 1 · 0 |
| c | 습도 켬(행 없음) 사용자에게 `env_vent_delay` | 1 · 1 |
| d | 습도 끔 사용자에게 `env_temp_high`(온도 켬) | 1 · 1 |
| e | 기존 시나리오(`env_humid_low` 끔, `safety.alert`) | 기존과 같음 |
| f | 운영 원문 대비 diff | 바뀐 줄이 위 CASE뿐 |

- [ ] **Step 1:** 운영 함수 원문 조회(MCP `execute_sql`, 읽기) → 마이그레이션 파일 작성
- [ ] **Step 2:** 로컬 검증 표 a~f 실행·기록
- [ ] **Step 3:** (D5 승인 후) MCP `apply_migration` → 운영 `pg_get_functiondef`로 반영 확인

### Task 4: 서버 회신 요청·버전·화면 대조

**Files:**
- Modify: `docs/handoffs/2026-11-02-env-alerts-v4-server-questions.md`(§8 신설)
- Modify: `pubspec.yaml`(0.167.2+460 → **0.168.0+461**, feat), `CHANGELOG.md`(추가), `docs/design-audits/2026-11-02-env-alerts-v4/RESULTS.md`, 기존 계획 §0 "대기 — 서버 Stage O" 줄에 이 계획 링크

**Context:**
- Depends on: Task 1~3
- §8에 적을 것: 앱이 받는 kind 이름(G1), `context.rule='v4'`·`message` 형식(G2), level 값(G3 — 없으면 앱은 주의로 그림), 푸시 payload `kind`(G5), `env_mist_gap` 푸시 여부(O-e)가 정해지면 알려 달라, 습도 토글이 두 kind의 푸시를 끈다(D4)는 것.
- Acceptance: mini13 미리보기 캡처 3장(A26·A36·3줄) + RESULTS 표, 버전·CHANGELOG 같은 커밋, `tools/worktree.sh finish`.

- [ ] **Step 1:** 미리보기 진입점(커밋 안 함)으로 mini13 캡처·Figma A26·A36 수치 대조
- [ ] **Step 2:** 문서·버전·CHANGELOG → 커밋 → 병합·push

## 사용자가 정할 것

1. **D2 — 습도 줄 둘을 다 보일지:** 추천은 "범위 이탈"과 "습기 사이클"을 따로 보여 최대 3줄. 대안은 지금처럼 습도 1줄(최신만).
2. **D5 — 수신 끄기 SQL 운영 적용 시점:** 추천은 로컬 검증 뒤 바로(지금은 해당 행 0건이라 영향 없음). 대안은 서버 Stage O 배포 직전.
