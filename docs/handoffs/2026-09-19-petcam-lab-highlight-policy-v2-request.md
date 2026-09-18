# petcam-lab 요청서 — 하이라이트 정책 v2 (2026-09-19)

> 대상: petcam-lab(petcam-api·GME 파이프라인) 담당. 배경·전체 정책은 [`기획 확정서`](../superpowers/specs/2026-09-19-highlight-policy-v2-design.md).
> **이 문서는 [`2026-09-15 하이라이트 FCM 요청`](2026-09-15-petcam-lab-highlight-slack-script.md)을 대체한다.** 그 문서의 "사람 검수 승인 스냅샷·불변 `highlight_batch_id` 확정 뒤 발송"은 **철회**한다.

## 0. 무엇이 바뀌었나 (세 줄)

- 앱의 **전체 영상 목록 = `/highlights`가 주는 집합(규칙 O + 사람 확정 O)** 으로 바뀐다. 미통과 영상은 앱에서 안 보인다.
- **하이라이트(대표)는 밤 구간(D 20:00~D+1 08:00 KST)만, D+2일 08:00 KST에 공개.** 사람 검수가 덜 끝났어도 그 시각의 계산 결과 그대로 공개한다 → 승인 스냅샷이 필요 없어졌다.
- 공개 게이트는 앱이 시간으로 건다. petcam-lab에 필요한 건 아래 3건뿐이다.

앱 1단계는 아래 3건 없이도 동작한다(앱이 같은 필터를 한 번 더 건다). 배포되는 순서대로 앱 수정 없이 효과가 난다.

## 1. 요청 ① — 매일 08:00 KST `highlight.ready` 발행 (우선순위 1)

**왜 petcam-lab인가:** 대표 계산에는 활성 GME 계약값(`GME_ACTIVE_*`)이 필요하고 그 값은 petcam-api 환경에만 있다. 앱 쪽 Supabase 예약 작업에 복사해 두면 계약이 바뀔 때 조용히 어긋난다.

**동작:** 매일 08:00 KST에 한 번, 각 (소유자, 카메라)에 대해

1. 대상 밤 = **그저께 20:00 ~ 어제 08:00 KST** (예: 9/26 08:00 실행 → 9/24 20:00~9/25 08:00).
2. 그 구간의 **대표(tier=featured) 개수**를 `/highlights/featured`와 같은 함수·같은 파라미터로 센다. 구간 밖 대표는 세지 않는다.
3. **1건 이상이면** 아래 이벤트 1건을 넣는다. **0건이면 아무것도 보내지 않는다.**

```http
POST https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/notification-ingest
Authorization: Bearer {PUSH_EVENT_INGEST_SECRET}
Content-Type: application/json
```

```json
{
  "schema_version": 1,
  "event_id": "highlight:{camera_id}:{day_key}:ready",
  "type": "highlight.ready",
  "occurred_at": "2026-09-26T08:00:03+09:00",
  "user_id": "{cameras.owner_id}",
  "payload": {
    "highlight_batch_id": "night:{camera_id}:{day_key}",
    "scheduled_for": "2026-09-26T08:00:00+09:00",
    "capture_window_started_at": "2026-09-24T20:00:00+09:00",
    "capture_window_ended_at": "2026-09-25T08:00:00+09:00",
    "highlight_count": 5,
    "camera_id": "{camera_id}"
  }
}
```

- `day_key` = 밤이 시작한 날짜(`2026-09-24`) — `/highlights/featured`의 `day_key`와 같은 값.
- `highlight_batch_id`는 이제 저장된 배치가 아니라 **결정적 문자열**이다(ingest 계약은 "비어 있지 않은 문자열"만 요구하므로 그대로 통과).
- 같은 `event_id` 재전송은 202로 멱등 — 작업이 두 번 돌아도 알림은 한 건.
- 08:00을 놓쳤으면(장애) 같은 `event_id`로 그날 안에 늦게 보내도 된다. `scheduled_for`는 원래 08:00 그대로.
- 네트워크 오류·5xx는 같은 `event_id`로 재시도, 4xx는 기록만(무한 재시도 금지). Secret·본문은 로그에 남기지 않는다.
- 카메라를 여러 대 가진 유저는 카메라마다 1건이 간다(합치는 건 후속 논의).

`PUSH_EVENT_INGEST_SECRET` 실제 값은 안전한 별도 경로로 전달한다(평문 Slack·Git 금지).

## 2. 요청 ② — `GET /highlights`에 `until` 추가 (우선순위 2, 작음)

앱 전체 목록의 **기간 필터**가 이 엔드포인트를 쓴다. 지금은 `since`(하한)만 있어 과거 구간을 보려면 최신부터 전부 넘겨야 한다.

- `until`: ISO8601, **미포함 상한**(`started_at < until`). 생략 = 상한 없음(현행).
- keyset 순회 시작점을 `until`로 당기면 된다(커서가 없을 때 `(until, 최대 uuid)`에서 시작하는 것과 같은 효과).
- 앱은 1단계부터 `until`을 보낸다. 미배포 서버는 모르는 쿼리를 무시하고, 앱이 상한을 한 번 더 거르므로 결과는 같고 속도만 다르다.

## 3. 요청 ③ — `GET /highlights/featured` 밤 구간 옵션 (우선순위 3)

지금 대표 선정(시간대당 3·하루 15)은 20:00~다음 날 20:00 하루 전체에서 계산된다. 앱은 1단계에서 08:00 이후 촬영된 대표를 그냥 뺀다 → 드물게 낮 영상이 하루 상한 15를 먹어 밤 대표가 덜 뽑힐 수 있다.

- 제안: `window=night` (기본 `day`=현행). `night`이면 하루의 앞 12시간(20:00~08:00)만으로 에피소드·순위·상한을 계산.
- 요청 ①의 개수 계산도 이 옵션과 같은 결과여야 한다.

## 4. 앱이 하는 것 (참고)

- 전체 목록: `GET /highlights?camera_id&since&until&limit=60&cursor` → `clip_id`들을 Supabase `motion_clips`로 조회해 그린다. `504`는 1회 재시도.
- 하이라이트: `GET /highlights/featured?tier=featured` 결과에서 밤 구간만 남기고, `day_key + 2일 08:00 KST` 이전 묶음은 숨긴다. 응답에 `publication`이 오면 그 값을 우선한다(현행 파서 유지).
- 알림 탭 → `/crecam/highlights` (이미 구현).

## 5. 회신 부탁

1. 요청 ①의 08:00 작업을 어디서 돌릴지(fly 스케줄·워커 등)와 가능 시점
2. 9/15 요청(승인 스냅샷·배치)에 이미 착수한 부분이 있는지 — 있으면 버리지 말고 알려 주세요
3. ②③ 수용 여부
