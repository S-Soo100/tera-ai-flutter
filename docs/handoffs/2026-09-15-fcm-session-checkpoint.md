# Android FCM 작업 재개 체크포인트

> 기록일: 2026-09-15 KST
> 저장소: `S-Soo100/tera-ai-flutter`
> 기준 브랜치: `main`
> 체크포인트 직전 커밋: `9075e1d docs: add FCM partner handoff scripts`
> 목적: 이 Codex 작업 또는 새 작업에서 Android FCM 연동을 안전하게 이어가기 위한 단일 재개 문서

## 1. 현재 한 줄 상태

Android 앱·Supabase 알림 저장소·Firebase 발송 함수·1분 주기 dispatcher까지 production에 반영했다. 실제 Android 기기 수신 E2E와 terra-server/petcam-lab 생산자 연결이 남아 있다. iOS/APNs와 안전 임계 정책은 의도적으로 보류했다.

## 2. 확정된 식별자와 범위

| 항목 | 확정값 |
|---|---|
| 앱 이름 | Vivanaut / 비바나트 |
| Android application ID | `com.vivanaut.app` |
| Firebase project | `vivanaut-app` |
| Supabase 조직 | `terra-ai-dev` |
| Supabase project | `Terra AI` |
| Supabase project ref | `slxjvzzfisxqwnghvrit` |
| ingest endpoint | `https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/notification-ingest` |
| 현재 앱 버전 | `0.103.2+207` |
| 우선 플랫폼 | Android |
| 보류 플랫폼 | iOS/APNs — Apple Developer 계정 준비 후 진행 |

토큰·알림·읽음 상태·발송 이력의 SOT는 Supabase다. 외부 생산자는 FCM을 직접 호출하지 않고 `notification-ingest` 계약만 사용한다.

## 3. 확정된 알림 종류

| 종류 | 생산자 | 발송 기준 |
|---|---|---|
| `highlight.ready` | petcam-lab | 사람이 승인한 고정 하이라이트 스냅샷의 `scheduled_for` |
| `device.action.started` | terra-server | 예약·타이머 명령의 실제 시작 성공 ACK |
| `device.action.ended` | terra-server | 예약·타이머 명령의 실제 종료 성공 ACK |
| `device.action.failed` | terra-server | 예약·타이머 명령 실패 확정 |
| `community.comment` | Supabase DB | 내 게시물에 다른 사용자가 댓글 작성 |
| `community.like_digest` | Supabase DB | 내 게시물 좋아요를 10분 단위로 묶음 |
| `notice.published` | Supabase DB | 공지 발행 확정 |
| `maintenance.water_tank` | 앱/Supabase | 사용자가 지정한 물통 세척 예약 시각 |
| `safety.alert` | terra-server | 향후 확정할 임계 조건 지속 판정 |
| `safety.recovered` | terra-server | 활성 안전 경고가 정상 범위로 복귀 |

수동 즉시 제어는 현재 `device.action.*` 푸시 범위에서 제외한다. 온도·습도 임계치, 지속 시간, cooldown은 아직 결정하지 않았으므로 안전 이벤트를 production에서 생성하지 않는다.

## 4. 하이라이트 시간 정책

- 촬영 구간: KST 기준 D일 20:00 이상, D+1일 08:00 미만.
- D+1일에 사람이 후보를 검수하고 승인 스냅샷을 확정한다.
- 정상 알림 시각: D+2일 08:00 KST.
- 예: 9월 24일 20:00~9월 25일 08:00 촬영 → 9월 25일 검수 → 9월 26일 08:00 알림.
- 승인되지 않았거나 반려된 배치는 이벤트를 보내지 않는다.
- 기본 목표 시각 이후 승인되면 승인 이후 처음 오는 08:00 KST로 예약한다.
- payload는 계속 변하는 후보 목록이 아니라 고정된 `highlight_batch_id`를 가리킨다.

## 5. 저장소 구현 완료 범위

### Flutter Android 앱

- FCM 초기화와 Android 알림 권한 안내·요청·재시도.
- 설치별 token 등록, refresh, 계정 전환과 로그아웃 비활성화.
- foreground 로컬 표시와 background/종료 상태 탭 처리.
- 허용된 내부 route만 여는 딥링크 검증.
- Supabase Realtime 알림 센터, 개별·전체 읽음, 미읽음 red dot.
- 안전 알림용 `vivanaut_safety`, 일반 알림용 `vivanaut_default` Android 채널.

### Supabase 데이터와 생산자

- migration: `supabase/migrations/20260915000000_fcm_notifications.sql`.
- `push_devices`, `app_notifications`, `notification_events`, `notification_outbox`, `notification_deliveries`.
- idempotency, 예약 발송, claim lease와 fencing, retry/backoff, token 비활성화 정책.
- RLS와 역할별 RPC 권한, `app_notifications`만 Realtime publication에 등록.
- 커뮤니티 댓글 즉시 알림, 좋아요 10분 digest, 공지 fan-out DB trigger.
- 물통 세척 예약용 `schedule_water_tank_notification(...)` RPC.
- 물통 세척 주기를 입력하는 앱 설정 UI는 아직 연결하지 않았다.

### Edge Functions

- `notification-ingest`: 외부 생산자 bearer secret 검증, 계약 검증, 중복 수렴.
- `dispatch-push`: outbox claim, Firebase OAuth, HTTP v1 발송, 제한된 retry와 delivery 완료 처리.
- 두 함수 모두 production에서 `ACTIVE`, `verify_jwt=false`다.
- `dispatch-push`는 gateway JWT 대신 이름이 `dispatch_push`인 Supabase secret API key를 `apikey` 헤더와 함수 내부에서 대조한다.

## 6. 운영 배포 완료 상태

- FCM migration `20260915000000`은 production applied history와 local이 일치한다.
- `notification-ingest`와 `dispatch-push`를 production에 배포했다.
- `pg_net`과 `pg_cron`을 활성화했다.
- cron job:
  - 이름: `dispatch-push-every-minute`
  - job id: `4`
  - schedule: `* * * * *`
  - active: `true`
- 수동 dispatcher 호출과 연속 자동 호출이 HTTP 200, `processed=0`, `sends=0`으로 통과했다. 당시 due outbox와 활성 push device가 없어 실제 사용자 알림은 발송되지 않았다.
- ingest secret으로 빈 JSON을 호출했을 때 401이 아니라 계약 검증 오류 400(`schema_version must be 1`)이 반환되어 인증 경로가 동작함을 확인했다. 테스트 이벤트는 생성하지 않았다.

## 7. Secret과 보안 상태

실제 값은 이 문서, Git, Slack 평문, 로그에 기록하지 않는다.

| 용도 | 보관 위치 / 이름 | 상태 |
|---|---|---|
| Firebase Admin JSON | Supabase Edge Function Secret `FIREBASE_SERVICE_ACCOUNT_JSON` | 등록 완료 |
| 외부 ingest bearer | Supabase Edge Function Secret `PUSH_EVENT_INGEST_SECRET` | 등록 완료 |
| 외부 ingest 복구·전달본 | Supabase Vault `notification_ingest_secret` | 등록 완료 |
| dispatcher secret API key | Supabase API key `dispatch_push` | 활성 |
| dispatcher cron 보관본 | Supabase Vault `dispatch_push_api_key` | 등록 완료 |

- Firebase JSON은 OAuth 발급 검증 후 로컬 파일 `/Users/baek/Downloads/vivanaut-app-3d0b778790f9.json`을 영구 삭제했다.
- 최초 `dispatch_push` key가 자동화 도구 출력에 노출된 일이 있어 즉시 API key와 기존 Vault 값을 삭제했다. 현재 값은 새로 발급한 교체 key이며 노출된 이전 key는 사용할 수 없다.
- 이관훈님과 petcam-lab에는 `PUSH_EVENT_INGEST_SECRET`만 구현 착수 시 안전한 별도 채널로 전달한다.
- Firebase 자격 증명, dispatcher key, Supabase service-role key는 외부 생산자에게 전달하지 않는다.

## 8. 완료 검증 기록

- 공유 Node 테스트: 27/27 통과.
- `flutter analyze --no-fatal-infos`: error 0, warning 0, 기존 info 10.
- 이전 전체 앱 검증: focused 56개, 전체 707개 테스트 통과(선택형 1개 제외), Android debug APK 생성, iOS 14 `pod install` 통과.
- production DB에서 FCM 테이블 5개, 핵심 RPC, RLS, 역할별 접근과 Realtime publication을 확인했다.
- anon/authenticated의 운영 테이블 직접 접근은 차단되고 필요한 authenticated RPC와 server 전용 RPC만 열렸다.
- 최근 문서 JSON 예시 파싱과 실제 Secret 패턴 미포함 검사를 통과했다.

## 9. 외부 전달 문서

- 이관훈님 Slack 복사본: `docs/handoffs/2026-09-15-terra-server-slack-script.md`
- 이관훈님 상세 기술 계약: `docs/handoffs/2026-09-15-terra-server-notification-events-request.md`
- petcam-lab Slack 복사본: `docs/handoffs/2026-09-15-petcam-lab-highlight-slack-script.md`
- 배포·운영 체크리스트: `docs/handoffs/2026-09-15-fcm-deployment-checklist.md`
- 전체 업무 분장: `docs/fcm-notification-work-split.md`
- 설계 SOT: `docs/superpowers/specs/2026-09-15-android-fcm-notifications-design.md`

## 10. 남은 작업과 권장 순서

### 1단계 — 외부 요청 발송

1. 두 Slack 스크립트의 `보낼 내용`을 각각 전달한다.
2. 담당자가 구현 착수를 회신하면 endpoint와 ingest secret을 안전한 채널로 전달한다.
3. Secret은 Slack 문서나 일반 코드 블록에 추가하지 않는다.

### 2단계 — 우리 Android 실기기 E2E

1. Android 13+ 실제 기기로 로그인한다.
2. 권한 허용·거절·재시도, token 등록·refresh·로그아웃을 확인한다.
3. 추적 가능한 테스트 사용자로 안전한 테스트 이벤트를 만든다.
4. foreground, background, 앱 종료 상태에서 수신과 탭 딥링크를 확인한다.
5. 알림 센터 읽음 상태와 프로필 red dot을 확인한다.
6. 같은 `event_id` 재전송이 알림 하나로 수렴하는지 확인한다.

### 3단계 — 내부 생산자 운영 E2E

1. 다른 테스트 사용자의 댓글로 `community.comment`를 확인한다.
2. 같은 게시물의 좋아요 여러 건이 10분 digest 하나로 묶이는지 확인한다.
3. 테스트 공지 발행의 fan-out을 제한된 테스트 계정으로 검증한다.
4. 물통 세척 UI를 구현할 범위를 확정하고 기존 RPC에 연결한다.

### 4단계 — 이관훈님 공동 스테이징

1. started/ended/failed 각 1건을 전송한다.
2. 동일 `event_id` 재전송, 네트워크·5xx 재시도, 잘못된 payload 4xx 처리를 확인한다.
3. 실제 기기 ACK 이전에는 이벤트가 생성되지 않는지 확인한다.

### 5단계 — petcam-lab 공동 스테이징

1. 정상 승인, 미승인·반려, 늦은 승인 배치를 준비한다.
2. 고정 `highlight_batch_id`와 KST `scheduled_for` 계산을 확인한다.
3. 중복 재전송이 같은 알림으로 수렴하는지 확인한다.

### 6단계 — 후속 범위

- 온도·습도 임계치, 지속 시간, cooldown, 회복 조건 합의 후 `safety.*` 활성화.
- Apple Developer 계정 준비 후 APNs key, Firebase iOS 앱, iOS 권한·수신 경로 구현.
- 운영 필요성이 확인되면 terra-server와 petcam-lab의 ingest key를 생산자별로 분리.

## 11. 재개할 때 첫 확인

다음 작업을 시작할 때 아래 순서로 현재 상태를 다시 확인한다.

```sh
git status --short --branch
git fetch origin --prune
git log -5 --oneline
supabase functions list --project-ref slxjvzzfisxqwnghvrit
supabase secrets list --project-ref slxjvzzfisxqwnghvrit
supabase migration list
```

Secret 목록에서는 이름만 확인하고 값을 출력하지 않는다. 다른 Codex 작업이 같은 checkout을 사용 중이면 변경 파일을 먼저 식별하고 해당 변경을 revert하거나 덮어쓰지 않는다.

재개 시 사용자에게 먼저 확인할 것은 다음 두 가지다.

1. 이관훈님과 petcam-lab에 문서를 보냈는지, 어떤 회신을 받았는지.
2. Android 실기기를 USB 또는 무선 디버깅으로 사용할 수 있는지.

회신이 아직 없어도 Android 실기기 E2E와 내부 커뮤니티·공지 생산자 테스트는 독립적으로 진행할 수 있다.

## 12. 주요 커밋 이력

| 커밋 | 내용 |
|---|---|
| `e66f2ad` | 앱 identity를 Vivanaut으로 정정 |
| `dac9f07` | Android 앱을 Firebase에 연결 |
| `4ec3786` | Android FCM 설계 확정 |
| `136e266` | Supabase 알림 이벤트 저장소 추가 |
| `c3bd1a1` | FCM outbox dispatcher 추가 |
| `25ec16d` | Android FCM 수신과 알림 센터 구현 |
| `ea49fb7` | dispatcher 보안과 실행 상한 보강 |
| `e40d2ed` | 계정 전환 시 token 회전 보강 |
| `f9995b5` | production dispatcher를 secret API key 방식으로 전환 |
| `9075e1d` | 이관훈님·petcam-lab 전달 스크립트 추가 |

이 문서 이후 변경은 `CHANGELOG.md`에 한글로 기록하고, 완료 전 최신 검증 증거를 다시 만든다.
