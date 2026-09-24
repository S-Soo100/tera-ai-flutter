# 캠 라이브 시청 세션 기록 — 기획 (2026-09-25)

> 사용자 승인 범위: **A. 시청 세션 묶기 + C. 확인용 view**. 신고 버튼(B)·카메라 온라인 이력(D)은 범위 밖.
> 원칙: **UX 변화 0** — 화면·문구·버튼·흐름을 바꾸지 않는다. 기록은 fire-and-forget이며 실패해도 라이브에 영향이 없다.

## 1. 왜

`webrtc_connect_logs`(2026-09-23~)는 **연결 1회(세대)** 단위다. 이틀 637행·8명이 쌓였지만 다음을 답할 수 없다.

1. 유저가 화면을 열어 **결국 영상을 봤나**, 보기까지 **몇 초** 기다렸나(재시도 포함).
2. 실패·정지·복구 안내를 **얼마 동안** 봤나.
3. **당시 펌웨어**는 무엇이었나(`cameras.firmware_ver`는 현재값뿐, 순차 플래시 중).
4. 재연결은 **왜** 일어났나(사유는 폰 메모리 진단 버퍼에만 있음).

## 2. 시청 세션(view)의 정의

- **시작:** 라이브 컨트롤러가 연결을 시작할 때(`startConnection`) 또는 백그라운드에서 **복귀**할 때.
- **끝:** 컨트롤러가 사라질 때(`closed` — 화면 이탈) 또는 **백그라운드 진입**(`background`).
- 한 view = 앱 전경에서 한 카메라 라이브를 연속으로 띄워 둔 구간. 탭 화면과 확대 화면은 같은 컨트롤러를 공유하므로 같은 view다.
- `view_id`는 앱이 만든 UUID. 그 view 안의 모든 연결 행에 같은 값을 붙인다.

## 3. 기록 내용

### 3.1 `webrtc_connect_logs`에 컬럼 추가 (nullable, 기존 행 영향 없음)

| 컬럼 | 뜻 |
|---|---|
| `view_id uuid` | 소속 view |
| `firmware_ver text` | 시도 시점의 `cameras.firmware_ver` |

### 3.2 새 테이블 `webrtc_view_logs` — view 종료 시 1행

| 컬럼 | 뜻 |
|---|---|
| `view_id` | 연결 행과 잇는 키(unique) |
| `camera_id`, `user_id`(기본 auth.uid()), `app_version`, `platform` | |
| `started_at` | view 시작(클라이언트 시각) |
| `network`, `firmware_ver`, `camera_online` | 시작 시점 환경 |
| `end_reason` | `closed` / `background` |
| `duration_ms` | view 전체 길이 |
| `first_video_ms` | 시작→첫 영상. **null = 끝내 못 봄** |
| `attempts` | 연결 시도(세대) 수 |
| `ms_connecting` / `ms_video` / `ms_stalled` / `ms_recovering` / `ms_failed` | 화면 상태별 머문 시간(합 = duration) |
| `stall_count` | "잠시 멈췄어요" 진입 횟수 |
| `failed_count` | 실패 화면(다시 연결 버튼) 진입 횟수 |
| `manual_retries` | 유저가 "다시 연결"을 누른 횟수 |
| `restarts jsonb` | 재연결 사유별 횟수 `{"network":2,"timer":1,…}` |

RLS: 본인 INSERT만. SELECT 정책 없음(운영자만 조회) — `webrtc_connect_logs`와 동일. **앱은 `.select()`를 붙이지 않는다**(RETURNING이 RLS 위반).

### 3.3 한계 (명시)

- **강제 종료·OS 강제 정리**면 view 요약 행이 없다. 연결 행은 남으므로 확인용 view가 `summary_missing`으로 표시하고 연결 행에서 "영상을 봤는지"를 추정한다.
- 과거 637행은 `view_id`가 없어 묶이지 않는다. 새 버전 사용자부터.
- 카메라 온라인 이력은 여전히 없다(서버 과제 D).

## 4. 확인용 view (C)

PostgREST에 노출되지 않는 **`ops` 스키마**에 둔다(public에 두면 view 소유자 권한으로 RLS를 우회해 로그인 사용자 누구나 전체 로그를 읽을 수 있다). `anon`/`authenticated`에 권한을 주지 않는다. 운영자는 SQL 편집기·MCP로 조회한다.

| view | 용도 |
|---|---|
| `ops.live_views` | view 1행 = 세션 1개. 이메일·카메라·펌웨어·봤는지·첫 영상 초·상태별 시간·재연결 사유. 요약 없으면 연결 행으로 보정 + `summary_missing` |
| `ops.live_daily` | 날짜(KST)·앱 버전·펌웨어별 세션 수, **본 비율**, 첫 영상 p50/p90, 실패 화면 노출 비율 |
| `ops.live_timeline` | 이메일로 거르면 그 유저의 view 시작/끝·연결 결과가 시간순 한 표 |

예) `select * from ops.live_timeline where email = '…' and at > now() - interval '1 day';`

## 5. 앱 변경 (UX 0)

- `LiveViewSession`(순수 Dart, 시계 주입) — 상태 변화·재시작 사유·시도·수동 재시도를 누적해 요약 행을 만든다.
- `WebRtcLiveController`가 state 리스너로 상태 시간을 재고, `startConnection`/`_resume`에서 view를 열고 `_suspend`/`dispose`에서 닫는다. 연결 행에 `view_id`·`firmware_ver`를 붙인다.
- 기록 실패는 삼킨다(기존 저장소와 동일).

## 6. 적용 순서

> **상태(2026-09-25):** 운영 DB 적용 완료(migration `webrtc_view_logs`) → 앱 0.135.0 main 병합. 운영에서 authenticated INSERT 성공(롤백 확인), `ops` 스키마 anon/authenticated 접근 불가 확인. 서버 담당 공유는 미완.

1. SQL 초안 `supabase/drafts/20260925_webrtc_view_logs.sql` — 로컬 임시 Postgres에서 RLS·view 검증.
2. 앱 구현·테스트. **새 컬럼·테이블이 없는 동안에도 안전해야 한다** — 운영 DB 적용 전 배포되면 INSERT가 실패(컬럼 없음)해 연결 행까지 잃는다. 그래서 **운영 DB 적용 → 앱 배포** 순서를 지킨다.
3. 운영 DB 적용은 사용자 확인 후. `webrtc_connect_logs`는 terra-server 쪽이 만든 테이블이라 컬럼 추가를 서버 담당에게 공유한다.
