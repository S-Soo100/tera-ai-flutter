# terra-server 알림 이벤트 연동 1차 요청

> 수신: 이관훈님
> 발신: 비바나트 앱 팀
> 목적: Android FCM 도입을 위한 terra-server 작업 범위와 1차 계약 확인
> 요청 단계: 1차 — 이벤트 계약 합의 및 구현 착수

안녕하세요. 비바나트 앱에서 Android 푸시 알림과 Supabase 알림 센터를 구현하고 있습니다. Firebase 발송, 사용자 FCM 토큰, 알림 문구·읽음 상태·발송 이력은 앱 팀이 관리합니다. terra-server에는 실제 기기 동작 결과와 향후 안전 판정 결과만 이벤트로 전달해 주시길 요청드립니다.

## 1. 요청드리는 작업

### A. 예약·타이머 동작 결과 이벤트

terra-server가 예약 또는 타이머 명령의 실제 ACK를 확정한 시점에 아래 이벤트를 보내 주세요.

- 동작 시작 성공: `device.action.started`
- 동작 종료 성공: `device.action.ended`
- 실행 실패 확정: `device.action.failed`

앱에서 사용자가 버튼을 누른 시점이나 예약 시간이 된 시점이 아니라, 실제 기기 ACK 기준이어야 합니다. 수동 즉시 제어는 이번 푸시 대상에서 제외하고 `schedule` 또는 `timer`로 실행된 명령만 전달해 주세요.

### B. 안전 이벤트 확장 자리

온도·습도 등의 임계치와 지속 시간은 아직 확정하지 않았으므로 판정 로직을 활성화하지 않습니다. 다만 아래 type을 수용할 수 있도록 이벤트 구조만 준비해 주세요.

- 경고 활성: `safety.alert`
- 정상 복귀: `safety.recovered`

구체 임계 수치와 cooldown은 별도 문서로 확정한 뒤 구현을 요청드리겠습니다.

## 2. 전송 API

앱 팀이 제공할 Supabase Edge Function endpoint로 HTTPS POST합니다.

```http
POST {SUPABASE_FUNCTIONS_URL}/notification-ingest
Authorization: Bearer {PUSH_EVENT_INGEST_SECRET}
Content-Type: application/json
```

`PUSH_EVENT_INGEST_SECRET`은 이미 Supabase Edge Function Secret에 등록하고 앱 팀 Vault에도 보관했습니다. endpoint와 실제 값은 안전한 전달 채널로 별도 전달하겠습니다. Firebase 서비스 계정 JSON도 `FIREBASE_SERVICE_ACCOUNT_JSON` 이름으로 Supabase Edge Function Secret에 등록되어 있으므로 이관훈님이 등록하거나 보관하실 작업은 없습니다. dispatcher용 Supabase secret API key 역시 앱 팀 내부에서 Vault로 관리합니다. Firebase 자격 증명, dispatcher key, Supabase service-role key는 terra-server에 전달하지 않습니다.

## 3. 공통 필드

```json
{
  "schema_version": 1,
  "event_id": "command:5ec3...:started",
  "type": "device.action.started",
  "occurred_at": "2026-09-15T21:00:03+09:00",
  "user_id": "supabase-auth-user-uuid",
  "payload": {}
}
```

| 필드 | 규칙 |
|---|---|
| `schema_version` | 현재 `1` 고정 |
| `event_id` | 이벤트별 전역 unique. 재시도할 때 같은 값 사용 |
| `type` | 위에 정의된 허용 type |
| `occurred_at` | timezone 포함 ISO-8601 |
| `user_id` | 알림을 받을 Supabase Auth user UUID |
| `payload` | type별 객체 |

성공 응답은 신규 처리와 중복 재전송 모두 HTTP 202입니다. 네트워크 오류 또는 5xx는 같은 `event_id`로 재시도하고, 4xx는 payload/인증 문제로 기록한 뒤 자동 무한 재시도하지 않습니다. 권장 timeout은 5초입니다.

## 4. 동작 이벤트 payload

```json
{
  "schema_version": 1,
  "event_id": "command:5ec3b4d1:started",
  "type": "device.action.started",
  "occurred_at": "2026-09-15T21:00:03+09:00",
  "user_id": "4da7f48b-0000-4000-8000-111111111111",
  "payload": {
    "command_id": "5ec3b4d1-0000-4000-8000-222222222222",
    "device_id": "terra-device-id",
    "enclosure_id": "49b2d944-0000-4000-8000-333333333333",
    "schedule_id": "optional-schedule-uuid",
    "execution_source": "schedule",
    "execution_phase": "started",
    "action": "fan_on",
    "result": "succeeded",
    "device_name": "크랑이 사육장"
  }
}
```

필수 payload:

- `command_id`, `device_id`
- `execution_source`: `schedule` 또는 `timer`
- `execution_phase`: `started`, `ended`, `failed`
- `action`: terra-server의 기존 command action 문자열
- `result`: `succeeded` 또는 `failed`

선택 payload:

- `enclosure_id`, `schedule_id`, `device_name`
- 실패 이벤트의 `error_code`: 사용자에게 원문 오류를 노출하지 않는 안정된 코드

type/phase/result 조합은 서로 일치해야 합니다. 예를 들어 `device.action.ended`는 `execution_phase=ended`, `result=succeeded`입니다.

## 5. 안전 이벤트 payload 자리

```json
{
  "schema_version": 1,
  "event_id": "safety:alert-uuid:activated",
  "type": "safety.alert",
  "occurred_at": "2026-09-15T21:10:00+09:00",
  "user_id": "4da7f48b-0000-4000-8000-111111111111",
  "payload": {
    "alert_id": "stable-alert-lifecycle-id",
    "device_id": "terra-device-id",
    "enclosure_id": "optional-enclosure-uuid",
    "metric": "temperature",
    "severity": "critical",
    "value": 35.2,
    "threshold": 33.0,
    "duration_seconds": 600,
    "state": "active"
  }
}
```

회복 이벤트는 같은 `alert_id`를 쓰고 `type=safety.recovered`, `state=recovered`로 보냅니다. 이 항목은 임계 정책 확정 전에는 전송하지 않습니다.

## 6. 중복·순서·실패 처리

- outbox 패턴으로 terra-server DB commit 이후 비동기 전송을 권장합니다.
- `event_id`는 재시도 내내 동일해야 합니다. 앱 팀 수신부가 idempotency를 보장합니다.
- 시작과 종료 이벤트는 각각 고유 `event_id`를 가집니다.
- 종료가 시작보다 먼저 수신돼도 삭제하지 않고 각 이벤트를 독립 처리합니다.
- 전송 실패가 실제 기기 명령 결과를 실패로 바꾸거나 명령 처리를 rollback해서는 안 됩니다.
- bearer secret과 전체 요청 본문을 로그에 남기지 않습니다. `event_id`, HTTP status, 재시도 횟수만 기록합니다.
- `PUSH_EVENT_INGEST_SECRET` 외의 Firebase·Supabase 자격 증명을 요청하거나 저장하지 않습니다.

## 7. 앱 팀이 담당하는 부분

- 이벤트 수신 endpoint와 secret 제공
- 이벤트 idempotency, 알림 문구 생성, 알림 DB 저장
- FCM token·Firebase 발송·실패 token 정리
- 알림 센터·읽음 상태·딥링크
- 커뮤니티/공지/하이라이트 알림

## 8. 1차 회신 요청

아래 항목을 확인 부탁드립니다.

1. 기존 command 처리 흐름에서 성공·실패 ACK가 최종 확정되는 코드 위치
2. `user_id`, `command_id`, `device_id`, `schedule_id`를 이벤트 생성 시 함께 확보 가능한지
3. 서버 outbox 또는 동등한 재시도 구조를 어디에 둘지
4. 위 payload에서 기존 terra-server 용어와 충돌하는 필드가 있는지
5. 예상 개발·스테이징 검증 가능 시점

회신 후 endpoint/secret을 전달하고 샘플 이벤트 3종(started/ended/failed)으로 연동 검증하겠습니다.
