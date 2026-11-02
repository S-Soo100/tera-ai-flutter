# v4 알림 마이그레이션 — 로컬 Postgres 검증 (2026-11-02)

계획 Task 7 Step 6·Task 8 Step 5(branch DB 검증)를 운영 DB를 건드리지 않고 **로컬 Docker `postgres:15`**에서 대신 했다. 운영 적용 전 한 번 더 Supabase branch에서 확인하는 것을 권장한다(실제 Supabase의 auth·Realtime·권한 구성은 아래 스텁과 다르다).

## 준비

- 스텁: `auth.users(id)`, `auth.uid()`(= `request.jwt.claim.sub`), 역할 `authenticated`·`anon`·`service_role`.
- 바탕: `20260915000000_fcm_notifications.sql` 1~112행(알림 테이블 5개) + 같은 파일의 `claim_notification_outbox` → `20260916000000…` → `20261001000000…` → 트리거 생성 → **`20261102000000_env_alert_preferences.sql` → `20261102000100_notification_env_alert.sql`**. 8개 모두 오류 없이 적용.
- 운영과 같은지: 운영 `notification_events_type_check`는 11종으로 파일과 같다. 운영 `notification_event_after_insert`·`claim_notification_outbox` 본문의 고유 분기(9/23 하이라이트 날짜, `device_offline`·`unknown_device`, 액션 라벨, 물통·안전 문구, ON CONFLICT, 우선순위 CASE)가 새 마이그레이션에 모두 남아 있다(`pg_get_functiondef` 대조, 2026-11-02).

## 결과

| # | 시나리오 | 기대 | 결과 |
|---|---|---|---|
| a | 습도 끔 사용자에게 `env_humid_low` | `app_notifications` 1 · outbox 0 | ✅ 1 · 0 |
| a′ | 같은 사용자에게 `env_temp_high`(온도 켬) | 1 · 1 | ✅ 1 · 1 |
| b | 설정 행 없는 사용자에게 `env_humid_low` | 1 · 1 | ✅ 1 · 1 |
| c | 같은 `source_event_id` 다시 INSERT | 1행 유지(유니크 위반) | ✅ `unique_violation` → ingest가 202 duplicate로 응답 |
| — | 저장 내용 | kind `env.alert.triggered`, category `env`, 제목 = payload.title, 본문 = 사육장 이름, route `/env-detail`, data.device_id | ✅ (data.kind는 payload의 `env_humid_low`로 덮임 — 주석대로, 앱은 컬럼 kind 사용) |
| — | 기존 종류(`safety.alert`, `highlight.ready`) | outbox 1, 문구 그대로 | ✅ |
| — | 모르는 타입(`env.alert.bogus`) | CHECK 위반 | ✅ `check_violation` |
| — | `claim_notification_outbox` 순서 | env·safety가 먼저 | ✅ env, env, safety, highlight |
| — | RLS: 본인 행 upsert | 성공, 보낸 열만 바뀜 | ✅ env_temp만 false, env_humid true 유지 |
| — | RLS: 남의 행 upsert | 거부 | ✅ `violates row-level security policy` |

## 확인 못 한 것

- 실제 Supabase(branch·운영)에서의 적용, `notification-ingest`·`dispatch-push` 재배포 후 HTTP 202·FCM 발송.
- 앱 PostgREST upsert 요청이 위 SQL과 같은 결과를 내는지(로컬엔 PostgREST 없음).

## 습기 사이클 kind 수신 끄기 — `20261103000000_notification_env_alert_humid_cycle.sql` (2026-11-03)

계획 `docs/superpowers/plans/2026-11-03-env-humid-cycle-alerts-app.md` Task 3. 같은 바탕(위 준비 + 20261102 두 파일) 위에 새 마이그레이션을 얹었다. 바탕 함수의 `md5(prosrc)` = `9584664ac29955c9e825f1cb85564c98` — **운영과 같다**(같은 날 운영 조회). 새 파일과 바탕의 차이는 수신 끄기 CASE의 습도 분기 하나(diff 확인).

| # | 시나리오 | 기대 | 결과 |
|---|---|---|---|
| a | 습도 끔 사용자에게 `env_vent_delay` | 기록 1 · outbox 0 | ✅ 1 · 0 |
| b | 습도 끔 사용자에게 `env_mist_gap` | 1 · 0 | ✅ 1 · 0 |
| c | 설정 행 없는 사용자에게 `env_vent_delay` | 1 · 1 | ✅ 1 · 1 |
| d | 습도 끔·온도 켬 사용자에게 `env_temp_high` | 1 · 1 | ✅ 1 · 1 |
| e1 | 습도 끔 사용자에게 `env_humid_low`(회귀) | 1 · 0 | ✅ 1 · 0 |
| e2 | `safety.alert`(회귀) | 1 · 1 | ✅ 1 · 1 |
| f | 운영 원문 대비 diff | 습도 분기만 | ✅ |
