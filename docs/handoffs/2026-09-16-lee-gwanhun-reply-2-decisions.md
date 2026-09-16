# 이관훈님 전달용 — 9/16 통합 회신에 대한 결정 답신

수신: 이관훈님 / terra-server

작성일: 2026-09-16 (통합 회신 `APP_DELIVERY_2026-09-16.md` 수신 당일)

대상: 비바나트(vivanaut) 앱

관훈님 안녕하세요. 통합 회신 잘 받았습니다. 회신 §7 "저희가 기다리는 답" 7건에 순서대로 답하고, 앱에서 이미 반영한 것을 함께 적습니다.

| # | 회신 §7 항목 | 답 |
|:---:|---|---|
| 1 | 기기 해제 설계 합의 | §1에 앱 제안 확정안. 이대로 진행해 주세요 |
| 2 | `PUSH_EVENT_INGEST_SECRET` | 별도 안전 채널로 전달합니다(이 문서에 넣지 않음) |
| 3 | LED 타이머 | **A안 확정.** 앱에서 칩 제거 완료. 펌웨어 작업 없음 |
| 4 | SQL 초안 5개 | 파일 묶음(`이관훈님_전달_2026-09-16` 폴더)을 함께 보냅니다 |
| 5 | 히터 예약 서버 400 | **막아 주세요.** 앱도 노출 제거 완료 |
| 6 | `no_ack` 30초 | 기본값 그대로 수용 |
| 7 | `device.action.skipped` | §4에 타입 정의. 앱 수신부 준비 뒤 "발송 시작" 신호를 드립니다 |

---

## 1. 기기 해제(소프트 해제) — 앱 제안 확정안

회신 §1.3 "합의 후 진행"에 대한 답입니다. 아래대로 진행해 주시고, 다른 형태가 나으면 경로·필드명만 알려주세요. 앱은 이미 이 계약을 호출하도록 구현돼 있고(0.108.1+266), 미배포 동안은 404/405를 "서버 미지원"으로 표시합니다.

### 1-1. 엔드포인트

```http
POST /devices/{uuid}/unlink
POST /cameras/{uuid}/unlink
Authorization: Bearer <사용자 JWT>
Content-Type: application/json

{ "request_id": "<앱 생성 UUID>" }
```

응답 `200`:

```json
{ "id": "<uuid>", "unlinked_at": "2026-09-16T12:34:56+09:00" }
```

| 상황 | 응답 |
|---|---|
| 정상 | 200 + 위 본문 |
| 같은 `request_id` 재시도 | 200, 최초 응답 그대로(멱등) |
| 이미 해제된 기기에 다른 `request_id` | 200, 기존 `unlinked_at` 그대로(재해제 무해) |
| 소유 아님·없음 | 404 (현행 소유권 위반 규칙과 동일) |

### 1-2. 서버 동작 (한 트랜잭션)

1. 소유권 확인(JWT `auth.uid()` = `owner_id`).
2. `devices`/`cameras` 행에 `unlinked_at = now()`, `enclosure_id = NULL`. **행은 삭제하지 않음.**
3. 해당 기기의 `schedules`는 `enabled = false`로 비활성화(삭제하지 않음). 해제된 기기에 예약이 실행되면 안 됩니다.
4. 개체–카메라 연결 이력 종료 — DB 트리거 방식(회신 §6 동의)이면 2번 UPDATE가 자동으로 태웁니다.
5. MQTT 계정 회수(`registry.unregister_device`). 이후 기기가 접속해도 거부.
6. 멱등 기록 저장.

보존: `devices`/`cameras` 행, `telemetry*`, `commands`, `alerts`, `motion_clips`, `clip_favorites`, R2 원본. 회신 §2.2대로 클립 소유자는 촬영 시점 값이라 재등록 후에도 새 소유자에게 안 보입니다.

### 1-3. 조회

- `GET /devices`·`GET /cameras`는 `unlinked_at IS NULL`만 반환.
- 앱의 Supabase 직결 SELECT는 앱이 `unlinked_at`을 보고 거릅니다(이미 적용). RLS 변경은 요청하지 않습니다.
- `devices`/`cameras` Realtime UPDATE로 앱이 즉시 반영합니다.

### 1-4. 남겨두는 것

- `DELETE /devices|cameras/{id}`(hard delete)는 운영·탈퇴용으로 남기되 앱은 호출하지 않습니다(회신 §2.5-4). 구 카메라 상세의 삭제 버튼은 앱에서 제거했습니다.
- 재등록: 같은 하드웨어가 다시 pair하면 현행대로 새 행이 생기고 옛 행은 `unlinked_at` 상태로 남습니다. 페어링 멱등성(회신 §8)은 하드웨어 ID 펌웨어 과제와 함께 별도로 논의합니다.

### 1-5. 이름 중복과 해제 기기

해제된 기기는 이름 중복 검사 대상에서 제외해 주세요(앱 팀 RPC 초안 `redesign_rename_item_v1`도 `unlinked_at IS NULL`만 검사하도록 갱신했습니다). 그룹 이름 UNIQUE 인덱스는 `enclosures`만이라 영향 없습니다.

---

## 2. LED 타이머 — A안 확정

- 앱에서 LED 시트의 "작동 시간" 칩과 관련 진행 칩·알림을 제거했습니다(0.108.2+267). `led_on`은 `brightness`만 보냅니다(릴레이 보드는 payload 없음).
- 펌웨어 B안은 진행하지 않습니다. 나중에 LED 타이머가 생기면 `capabilities.led_timer` 같은 플래그로 알려주시면 그때 다시 붙이겠습니다.
- 냉각팬·환기팬 예약의 `duration_ms`(상한 2h)와 예약 `brightness`는 회신대로 그대로 씁니다. 앱 하한 20%는 시트·예약 편집기 모두에서 강제하고 있습니다.

## 3. 히터 — 서버 400 차단 요청

- 요청: `heater_on`/`heater_off`를 예약 생성(`POST/PATCH /schedules`)과 REST 명령 경로에서 400으로 막아 주세요. 나중에 히터 보드가 생기면 `capabilities.heater` 같은 플래그로 다시 여는 방식을 제안합니다.
- 앱: 홈 타일·예약 기기 선택은 이미 숨김이었고, 구 사육장 탭에 남아 있던 히터 타일도 제거했습니다(0.108.4+269).

## 4. `device.action.skipped` 타입 정의 (2차)

가드 스킵(`source='guard'`) 알림 계약입니다. 기존 3종과 같은 봉투를 씁니다.

| 필드 | 값 |
|---|---|
| `type` | `device.action.skipped` |
| `execution_source` | `schedule` (건너뛴 대상이 예약이므로) |
| `execution_phase` | `skipped` |
| `outcome` | `skipped` |
| `result` | `guard_skipped` |
| `schedule_id` | 건너뛴 예약 |
| `action` | 건너뛴 명령(`heater_on` 등) |
| `guard` | 선택. `{ "kind": "<가드 종류>", "threshold": 30, "value": 33.5, "metric": "temperature" }` — 문구에 씁니다 |
| `event_id` | `command:{command_id}:skipped` (가드 감사 행의 id) |

**앱 수신부가 이 타입을 아직 받지 않습니다.** 검증기·알림 문구·앱 종류 목록에 추가한 뒤 "skipped 발송 시작해도 됩니다"를 따로 보내겠습니다. 그 전에 보내시면 422로 거절되니 발송 조건에는 아직 넣지 말아 주세요.

## 5. 앱이 이미 반영한 회신 항목

| 회신 | 앱 |
|---|---|
| §3.1 유효 표본 수 `t_a_count`/`h_a_count` | 컬럼명 반영(0.108.3+268). null 버킷은 `--`. A센서만 사용하므로 B센서 null은 영향 없음. 일 경계는 앱이 로컬(KST) 자정 범위를 UTC로 바꿔 조회합니다 |
| §3.2 그룹 이름 409 | 앱 그룹 저장은 RPC라 UNIQUE 위반을 `23505`로 받아 "이미 사용 중인 이름"으로 표시합니다. REST 409는 앱이 쓰지 않습니다 |
| §3.3 푸시 계약 | 수신 검증기가 확정 계약(`schedule`만, `outcome`/`result`, `device_key`, `no_ack`)과 일치합니다. secret 수령 후 스테이징 3종(started/ended/failed)으로 검증하겠습니다 |
| §4.2 냉각팬 | `telemetry.fan2 != null`로 노출. 이미 적용 |
| §4.3 `busy`/`error` | 같은 문구, 재시도는 항상 새 `msg_id`(앱은 명령마다 새 UUID) |
| §1.1 `telemetry_1m` / §1.2 `DELETE /clips` | 앱 코드에 사용 0건 |
| §5 `pets` | 감사합니다. 앱 팀 소유로 유지 |

## 6. 함께 보내는 것

- SQL 초안 5개 + 검증 스크립트 + 그룹 삭제 계약서 (`이관훈님_전달_2026-09-16` 폴더). 초안 중 `20260915_redesign_groups.sql`은 오늘 `unlinked_at` 규칙(§1-5)을 반영한 최신본입니다.
- `PUSH_EVENT_INGEST_SECRET`은 별도 채널.
