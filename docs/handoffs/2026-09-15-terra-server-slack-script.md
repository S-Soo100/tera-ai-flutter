# 이관훈님 전달용 Slack 스크립트

> 용도: 아래 `보낼 내용`을 그대로 복사해 이관훈님께 전달한다.
> 보안: `PUSH_EVENT_INGEST_SECRET` 실제 값은 이 문서나 Slack 평문에 추가하지 않는다.

## 보낼 내용

안녕하세요, 관훈님. 비바나트 Android 푸시 알림의 앱·Supabase 쪽 기반 작업이 준비되어 terra-server 연동을 요청드립니다.

앱 팀에서 이미 처리한 범위는 다음과 같습니다.

- Firebase Android 연결 및 FCM 토큰 등록·갱신·로그아웃 해제
- Supabase 알림 저장소, 중복 방지, 발송 outbox와 1분 주기 dispatcher
- `notification-ingest`, `dispatch-push` Edge Function 운영 배포
- Firebase 서비스 계정과 ingest secret의 Supabase Secret 등록
- 앱 내 알림 센터, 읽음 처리, 미읽음 표시와 딥링크

Firebase 서비스 계정, FCM 토큰, Supabase service-role key 또는 dispatcher key는 terra-server에서 등록하거나 보관하실 필요가 없습니다.

### 요청드리는 작업

예약 또는 타이머로 실행된 명령의 **실제 기기 ACK가 확정된 시점**에 아래 이벤트를 전송해 주세요.

- 시작 성공: `device.action.started`
- 종료 성공: `device.action.ended`
- 실행 실패 확정: `device.action.failed`

사용자가 앱에서 버튼을 누른 시점이나 예약 시각이 된 것만으로는 보내지 않고, 실제 기기 결과를 확인한 뒤 보내는 것이 기준입니다. 이번 범위에서 수동 즉시 제어는 제외합니다.

전송 주소는 아래와 같습니다.

```http
POST https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/notification-ingest
Authorization: Bearer {PUSH_EVENT_INGEST_SECRET}
Content-Type: application/json
```

`PUSH_EVENT_INGEST_SECRET` 실제 값은 구현 착수 시 안전한 별도 채널로 전달드리겠습니다.

요청 예시는 다음과 같습니다.

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
    "schedule_id": "6f7df1a2-0000-4000-8000-444444444444",
    "execution_source": "schedule",
    "execution_phase": "started",
    "action": "fan_on",
    "result": "succeeded",
    "device_name": "크랑이 사육장"
  }
}
```

필수 규칙입니다.

- `execution_source`: `schedule` 또는 `timer`
- `execution_phase`: `started`, `ended`, `failed` 중 type과 일치하는 값
- `result`: started/ended는 `succeeded`, failed는 `failed`
- 재시도할 때는 최초 요청과 동일한 `event_id` 사용
- 신규 처리와 중복 요청의 성공 응답은 모두 HTTP 202
- 네트워크 오류·5xx는 같은 `event_id`로 재시도
- 4xx는 인증 또는 payload 문제로 기록하고 무한 재시도하지 않음
- 명령 처리 DB commit 이후 outbox 또는 동등한 비동기 재시도 구조 사용 권장
- Secret과 전체 요청 본문은 로그에 남기지 않음

온도·습도 안전 알림은 구조만 `safety.alert`, `safety.recovered`로 열어두고, 임계치·지속 시간·cooldown을 별도로 합의하기 전에는 전송하지 말아 주세요.

우선 아래 다섯 가지를 회신 부탁드립니다.

1. 성공·실패 ACK가 최종 확정되는 terra-server 코드 위치
2. 이벤트 생성 시 `user_id`, `command_id`, `device_id`, `schedule_id` 확보 가능 여부
3. outbox 또는 재시도 처리를 둘 위치
4. 위 payload 필드와 기존 terra-server 용어의 충돌 여부
5. 구현 및 started/ended/failed 공동 스테이징이 가능한 예상 시점

회신을 받으면 ingest secret을 별도로 전달하고 샘플 3종과 중복 재전송까지 같이 검증하겠습니다. 감사합니다.

## 발신 전 확인

- 이 문서에는 실제 Secret이 없어야 한다.
- `PUSH_EVENT_INGEST_SECRET`은 이관훈님이 구현 착수할 때만 안전한 채널로 별도 전달한다.
- 하이라이트 검수 작업은 petcam-lab 담당이므로 이 요청에 추가하지 않는다.
