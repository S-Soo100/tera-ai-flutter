# petcam-lab 전달용 하이라이트 Slack 스크립트

> 용도: 아래 `보낼 내용`을 그대로 복사해 petcam-lab 담당자에게 전달한다.
> 보안: `PUSH_EVENT_INGEST_SECRET` 실제 값은 이 문서나 Slack 평문에 추가하지 않는다.

## 보낼 내용

안녕하세요. 비바나트 Android 푸시 알림 기반이 준비되어 petcam-lab의 검수 완료 하이라이트 연동을 요청드립니다.

이번 요청의 핵심은 **후보 영상을 바로 알리지 않고, 사람이 검수해 승인한 고정 스냅샷만 다음 발송 시각에 알리는 것**입니다. petcam-lab에서는 FCM을 직접 호출하거나 Firebase·Supabase 관리자 자격 증명을 관리하지 않습니다.

### 하이라이트 시간 정책

- 촬영 구간: KST 기준 D일 20:00 이상, D+1일 08:00 미만
- 검수: D+1일 안에 사람이 후보를 확인하고 승인 스냅샷 확정
- 정상 발송 예약: D+2일 08:00 KST
- 예시: 9월 24일 20:00~9월 25일 08:00 촬영 → 9월 25일 검수 → 9월 26일 08:00 알림
- 승인되지 않았거나 반려된 배치는 이벤트를 보내지 않음
- 정상 목표 시각 이후 늦게 승인된 배치는 승인 이후 처음 오는 08:00 KST로 예약

예약 시각 계산은 다음 규칙으로 고정합니다.

1. 촬영 시작일을 D로 잡고 기본 목표를 D+2일 08:00 KST로 계산합니다.
2. 승인 시각이 기본 목표보다 빠르면 기본 목표를 `scheduled_for`로 사용합니다.
3. 승인 시각이 기본 목표와 같거나 늦으면 승인 시각 이후 처음 오는 08:00 KST를 `scheduled_for`로 사용합니다.

### 요청드리는 작업

1. 촬영 구간별 하이라이트 후보 배치를 생성합니다.
2. 사람 검수 상태를 관리하고 승인 순간의 영상 목록을 변경되지 않는 스냅샷으로 확정합니다.
3. 승인된 배치에 안정적인 `highlight_batch_id`를 부여합니다.
4. 승인 완료 뒤 아래 endpoint로 `highlight.ready` 이벤트를 한 번 생성합니다.
5. 네트워크 재시도 시에는 같은 `event_id`와 같은 승인 스냅샷을 사용합니다.

전송 주소는 아래와 같습니다.

```http
POST https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/notification-ingest
Authorization: Bearer {PUSH_EVENT_INGEST_SECRET}
Content-Type: application/json
```

`PUSH_EVENT_INGEST_SECRET` 실제 값은 구현 착수 시 안전한 별도 채널로 전달드리겠습니다. Firebase 서비스 계정, FCM 토큰, Supabase service-role key와 dispatcher key는 전달하지 않으며 petcam-lab에서 필요하지 않습니다.

요청 예시는 다음과 같습니다.

```json
{
  "schema_version": 1,
  "event_id": "highlight:7ad42a90-0000-4000-8000-555555555555:ready",
  "type": "highlight.ready",
  "occurred_at": "2026-09-25T18:30:00+09:00",
  "user_id": "4da7f48b-0000-4000-8000-111111111111",
  "payload": {
    "highlight_batch_id": "7ad42a90-0000-4000-8000-555555555555",
    "scheduled_for": "2026-09-26T08:00:00+09:00",
    "capture_window_started_at": "2026-09-24T20:00:00+09:00",
    "capture_window_ended_at": "2026-09-25T08:00:00+09:00",
    "highlight_count": 5
  }
}
```

필수 필드는 아래와 같습니다.

- 공통: `schema_version=1`, `event_id`, `type=highlight.ready`, timezone이 포함된 `occurred_at`, Supabase Auth UUID인 `user_id`
- payload: 문자열 `highlight_batch_id`, timezone이 포함된 `scheduled_for`
- `capture_window_started_at`, `capture_window_ended_at`, `highlight_count`는 추적을 위한 권장 필드

중복·실패 처리 규칙입니다.

- `event_id` 권장 형식: `highlight:{highlight_batch_id}:ready`
- 신규 처리와 동일 이벤트 재전송의 성공 응답은 모두 HTTP 202
- timeout 권장값은 5초
- 네트워크 오류·5xx는 같은 `event_id`로 재시도
- 4xx는 인증 또는 payload 문제로 기록하고 자동 무한 재시도하지 않음
- 전송 실패가 승인 스냅샷을 삭제하거나 다시 구성하게 만들면 안 됨
- Secret과 전체 요청 본문은 로그에 남기지 않음

우선 아래 항목을 회신 부탁드립니다.

1. 현재 후보 생성과 사람 검수 상태가 저장되는 위치
2. 승인 스냅샷과 `highlight_batch_id`를 고정할 수 있는지
3. 각 배치의 Supabase `user_id`를 확보할 수 있는지
4. 촬영 구간과 KST 08:00 예약 시각을 계산할 코드 위치
5. outbox 또는 동등한 재시도 구조를 둘 위치
6. 승인 완료·미승인·늦은 승인 배치의 공동 스테이징이 가능한 예상 시점

회신을 받으면 ingest secret을 별도로 전달하고 정상 승인, 미승인, 늦은 승인과 중복 재전송까지 같이 검증하겠습니다. 감사합니다.

## 발신 전 확인

- 이 문서에는 실제 Secret이 없어야 한다.
- 승인되지 않은 후보나 계속 변하는 후보 목록을 이벤트로 보내지 않는다.
- terra-server의 예약·타이머 ACK 작업은 이 요청에 추가하지 않는다.
