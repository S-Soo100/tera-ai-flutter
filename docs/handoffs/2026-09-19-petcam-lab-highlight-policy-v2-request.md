# petcam-lab 요청서 — 하이라이트 정책 v2 (2026-09-19)

> 대상: petcam-lab(petcam-api·GME 파이프라인) 담당. 배경·전체 정책은 [`기획 확정서`](../superpowers/specs/2026-09-19-highlight-policy-v2-design.md).
> **이 문서는 [2026-09-15 하이라이트 FCM 요청(과거 이력)](https://github.com/S-Soo100/tera-ai-flutter/blob/ba747f1606eacffdec8d14ee7da5266e2c913714/docs/handoffs/2026-09-15-petcam-lab-highlight-slack-script.md)을 대체한다.** 그 문서의 "사람 검수 승인 스냅샷·불변 `highlight_batch_id` 확정 뒤 발송"은 **철회**한다. 구 전달문은 2026-09-23 정리로 삭제하고 git 이력에 보존했다.

## ⚠️ 선결 과제 — 운영 GME 기준이 9/14에서 멈춤 (2026-09-19 앱 실측)

앱 0.115.0+292부터 전체 영상 목록이 `/highlights` 통과분이라, 이 문제가 **모든 유저의 카메라 탭에서 9/15 이후 영상이 안 보이는 현상**으로 드러난다(하이라이트는 이전부터 9/15 이후가 비어 있었다).

운영 DB `gme_runs` 실측:

| detector_identity | 분석 기간(created_at) | 분석된 클립 범위 |
|---|---|---|
| `deccfc8315d3…` (gme-motion-v1) | 9/3 ~ **9/14 14:22 UTC 이후 없음** | 7/14 ~ 9/14 |
| `44dd382cba74…` (gme-motion-v1) | **9/14 14:05 UTC ~ 현재** | 7/14 ~ 현재 (12,426클립) |

추정: `GME_ACTIVE_DETECTOR_IDENTITY`가 아직 `deccfc…`이고, 9/14 이후 신규 클립은 `44dd…`로만 분석된다 → 신규 클립은 `fn_highlight_current`에서 판정 없음 → `/highlights`·`/highlights/featured`에서 전부 빠진다. 앱 화면(카메라 `P4 Cam (dev)` 최신 통과분 9/14 06:26, 실제로는 9/15에 움직임 ≥10초 17건·9/19에 3건)이 이 추정과 일치한다.

요청:
1. 운영 기준을 `44dd…`로 전환(시험용 detector라면 승인 절차를 거치거나, 운영 기준 detector로 신규 클립 분석을 재개).
2. **전환 전에 `deccfc…`로만 분석된 1,332클립(7/14~9/14)을 `44dd…`로 소급 분석.** 안 하면 전환 순간 이 영상들이 목록·하이라이트에서 사라진다.
3. 사람 확정 판정(`motion_clip_highlight_verdicts`, `gme_run_id` 보유)이 detector 전환 뒤에도 유지되는지 확인.
4. 앞으로 detector를 바꿀 때 "운영 기준 전환 + 소급 분석"을 한 절차로 묶어 이 공백이 다시 안 생기게.

앱은 조회할 때마다 계산하므로 **이 수정만으로 앱 변경 없이 바로 반영된다.**

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

## 추가 — 배포 후 확인 기록 (2026-09-19, 앱 실측)

| 시각(KST) | petcam 상태 | 앱 실측 | 결과 |
|---|---|---|---|
| 02:38 | ②③ 배포, detector 미전환 | 테스트 카메라 그리드 최신 9/14 | ✗ 선결 과제 미처리 |
| 02:49 | detector `44dd…` 전환(fly·Vercel) | iOS·Android 그리드에 9/19 01:00 영상, 플레이어 넘김 통과분만, 하이라이트 카드 "3일 전"(9/14 밤, DB 일치) | ✓ |
| 02:50 | 〃 | `/highlights/featured` 504 ×2(Android 카드 "불러오기 실패"), `/highlights` 첫 로드 504(iOS) | ✗ 조회 시 계산량 |
| 03:12 | v15 (featured 7일 분할 · `since` DB 하한) | 테스트01(`f6599924…`, 마지막 O 8/4): 하이라이트 카드 ~30초, **그리드 ~45초 후 오류** | ✗ `since` 없는 호출 미해결 |
| 03:19 | v16 (504 대응 3건) · DB 디스크 I/O 예산 소진 상태 | 테스트01 그리드(8/4·8/2)·하이라이트 카드 모두 **10초 안에 표시, 504 로그 없음** | ✓ (I/O 회복 후 재측정) |

**남은 요청 (v15 이후):** 앱 기본 그리드는 "전체 기간"이라 `since` 없이 `GET /highlights?camera_id&limit=60[&cursor]`를 호출한다. O가 드문 카메라에서는 60개를 채우려고 이력 전체를 훑는다. 한 요청의 스캔량에 상한을 두고, 상한에 닿으면 채운 만큼(0개 가능) + `next_cursor` + `has_more=true`를 돌려 달라. 앱 `PassedClipFeedSource`는 빈 페이지+`has_more`면 같은 요청 안에서 최대 20페이지까지 이어 받는다 — 상한은 20페이지 안에 과거 O에 닿을 만큼 넉넉히. 소급 분석 완료(오후 2시 전후) 후 7/14~9/14 과거 영상 복귀도 재확인한다.
