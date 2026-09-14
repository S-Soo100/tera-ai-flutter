# 비바나트 Android FCM 알림 설계

> 작성일: 2026-09-15
> 상태: 사용자 승인 / Android 우선
> 선행 완료: Firebase `vivanaut-app`, Android 앱 `com.vivanaut.app`
> 후속 제외: Apple Developer 계정, APNs, iOS Firebase 앱과 iOS 권한

## 1. 목표

비바나트 앱에 계정 단위 원격 알림과 알림 센터를 구축한다. FCM 토큰, 알림 원본, 읽음 상태와 발송 이력은 Supabase를 단일 진실 소스로 삼는다. 앱·petcam-lab·terra-server가 Firebase 자격 증명을 각각 보유하지 않고, 발송은 Supabase Edge Function 한 곳에서 Firebase HTTP v1을 호출한다.

## 2. 사용자 경험

### 2.1 최초 권한 흐름

1. `[홈]` 로그인한 사용자가 평소 화면을 본다.
2. `[안내]` 최초 1회 “하이라이트·사육장 동작·안전 알림을 받아보세요” 설명 시트가 나타난다.
3. `[조작]` 사용자가 `알림 켜기`를 누른다.
4. `[반응]` Android 알림 권한 창이 나타나고, 허용하면 현재 기기의 FCM 토큰이 Supabase 계정에 등록된다.
5. `[감정]` 사용자는 권한을 왜 요구하는지 이해하고, 어떤 알림을 받을지 예측할 수 있다.

`나중에` 또는 OS 권한 거절을 선택해도 앱 사용은 막지 않는다. 알림 센터 상단에 `알림 켜기` 안내를 남겨 다시 시도할 수 있게 한다. 설명 시트 표시 여부는 기기 로컬 설정에 저장하며, 로그아웃으로 초기화하지 않는다.

### 2.2 수신 흐름

- 백그라운드·종료 상태: FCM notification payload를 Android가 표시한다.
- 포그라운드: 앱이 동일 payload를 `flutter_local_notifications`로 한 번만 표시한다.
- 알림 탭: 허용된 내부 route만 해석해 해당 화면으로 이동하고 해당 알림을 읽음 처리한다.
- 알림 센터: 최신순 목록, 카테고리·시각·읽음 상태를 표시한다. 항목 탭 시 읽음 처리 후 목적지로 이동한다.
- 읽지 않은 알림이 있으면 프로필 화면의 알림 진입점에 red dot을 표시한다.

## 3. 알림 종류와 발송 시점

| kind | 표시 범주 | 생산자 | 발송 시점 | 기본 route |
|---|---|---|---|---|
| `highlight.ready` | 하이라이트 | petcam-lab | 검수 확정 스냅샷의 예약 시각 | `/crecam/highlights` |
| `device.action.started` | 사육장 동작 | terra-server | 예약·타이머 명령의 실제 성공 ACK | `/home/routines` |
| `device.action.ended` | 사육장 동작 | terra-server | 종료 명령의 실제 성공 ACK | `/home/routines` |
| `device.action.failed` | 사육장 동작 | terra-server | 예약·타이머 명령 실패 확정 | `/home/routines` |
| `community.comment` | 커뮤니티 | Supabase | 내 게시물에 타인이 댓글 작성 | `/community-player/{post_id}` |
| `community.like_digest` | 커뮤니티 | Supabase | 내 게시물 좋아요를 10분 단위로 묶음 | `/community-player/{post_id}` |
| `notice.published` | 공지 | Supabase 운영자 | 공지 발행 확정 | `/notifications` |
| `maintenance.water_tank` | 관리 | 앱/Supabase | 사용자가 설정한 세척 주기 | `/home/routines` |
| `safety.alert` | 긴급·안전 | terra-server | 임계 조건 지속 판정 후 경고 | `/env-detail` |
| `safety.recovered` | 긴급·안전 | terra-server | 활성 경고가 정상 범위로 복귀 | `/env-detail` |

종류는 문자열 + JSON payload로 확장한다. 앱이 모르는 kind를 받아도 알림 센터에서 일반 알림으로 표시하고 `/notifications`로 이동한다.

### 3.1 하이라이트 시간 정책

- KST 촬영 창: D일 20:00 이상 D+1일 08:00 미만.
- 사람이 D+1일 안에 후보를 검수하고 승인 스냅샷을 확정한다.
- 알림: D+2일 08:00 KST.
- 예: 9월 24일 20:00~9월 25일 08:00 촬영 → 9월 25일 검수 → 9월 26일 08:00 알림.
- 마감 전 승인되지 않은 배치는 보내지 않는다. 늦게 승인되면 승인 이후 처음 오는 08:00 KST로 예약한다.
- 알림 payload는 가변 후보가 아니라 검수 확정 `highlight_batch_id`를 가리킨다.

## 4. 시스템 경계

### 4.1 앱 팀 소유

- Firebase Android 연결과 Flutter FCM 수신
- 알림 권한 UX, 토큰 등록·refresh·로그아웃 비활성화
- Supabase 알림 테이블, RLS, RPC, outbox, Edge Functions, cron
- 알림 센터, 읽음 처리, 미읽음 red dot, 딥링크 allowlist
- 커뮤니티 댓글·좋아요 묶음, 공지, 물통 세척 알림 생산
- 외부 생산자용 이벤트 수신 계약과 운영 문서

### 4.2 petcam-lab 소유

- 촬영 창별 후보 생성
- 사람 검수 상태와 승인된 고정 스냅샷
- 승인 완료 후 `highlight.ready` 이벤트 전달

이 작업은 이관훈님 terra-server 요청에 섞지 않는다.

### 4.3 이관훈님/terra-server 소유

- 예약·타이머 명령의 실제 실행 결과와 ACK 판정
- 시작·종료·실패 이벤트를 승인된 수신 API로 전달
- 향후 확정될 온습도 임계치·지속 시간·회복 조건 평가
- 안전 경고 lifecycle(`alert`/`recovered`) 이벤트 전달과 중복 억제

terra-server는 FCM 토큰, Firebase 서비스 계정, 알림 문구와 알림 DB를 직접 관리하지 않는다.

## 5. Supabase 데이터 모델

### 5.1 `push_devices`

- `id uuid` PK
- `user_id uuid` → `auth.users`, cascade delete
- `installation_id uuid`: 기기 설치 단위 안정 식별자
- `fcm_token text`: 현재 토큰, 전체 unique
- `platform text`: `android` 또는 향후 `ios`
- `app_version text`, `locale text`
- `enabled boolean`, `last_seen_at`, `created_at`, `updated_at`
- unique `(user_id, installation_id)`

인증 사용자는 자기 행만 조회·등록·갱신·삭제한다. 새 계정이 같은 설치를 등록하면 RPC가 이전 계정 연결을 원자적으로 해제해 계정 간 알림 누출을 막는다.

### 5.2 `app_notifications`

- `id uuid` PK, `user_id uuid`
- `kind text`, `category text`
- `title text`, `body text`
- `route text`, `data jsonb`
- `source text`, `source_event_id text`
- `dedupe_key text`, `created_at`, `read_at`
- unique `(user_id, dedupe_key)`

클라이언트는 자기 알림 SELECT와 자기 `read_at` UPDATE만 가능하다. INSERT/DELETE는 service-role 경로만 가능하다.

### 5.3 `notification_events`와 `notification_outbox`

외부·내부 생산 이벤트는 `notification_events`에 idempotent하게 수집한다. 정규화 함수가 사용자별 `app_notifications`와 `notification_outbox`를 함께 생성한다. outbox는 `pending / processing / sent / failed / cancelled` 상태, 예약 시각, 시도 횟수, 오류 요약을 보존한다.

동일 `source + source_event_id`는 한 번만 처리한다. 같은 알림의 앱 내 기록과 push 발송은 분리하지 않는다.

## 6. 외부 이벤트 수신 계약

외부 서버는 `notification-ingest` Edge Function을 HTTPS POST로 호출한다.

- 인증: 전용 `PUSH_EVENT_INGEST_SECRET` bearer secret. Supabase service-role key와 Firebase 키는 공유하지 않는다.
- `Content-Type: application/json`
- 모든 이벤트에 `schema_version`, `event_id`, `type`, `occurred_at`, `user_id` 필수.
- 성공: idempotent 재전송을 포함해 HTTP 202.
- 형식 오류 400, 인증 실패 401, 지원하지 않는 type 422.
- 호출 타임아웃은 5초, 네트워크/5xx는 동일 `event_id`로 지수 backoff 재시도한다.

정확한 terra-server payload는 별도 1차 요청 문서에 고정한다.

## 7. 발송기

`dispatch-push` Edge Function이 예약 시각이 지난 outbox를 claim하고 `push_devices.enabled = true` 토큰으로 Firebase HTTP v1을 호출한다.

- Firebase 서비스 계정 JSON은 repository/DB에 저장하지 않고 Supabase secret으로만 보관한다.
- 한 알림을 사용자의 활성 설치 전체에 발송한다.
- FCM의 unregistered/invalid token 응답은 해당 `push_devices`를 비활성화한다.
- 일시 오류는 제한 횟수까지 backoff하고, 영구 실패는 오류 코드를 남긴다.
- payload는 `notification(title/body)` + 문자열 값만 가진 `data(notification_id/kind/route/...)`를 사용한다.
- Android channel은 `vivanaut_default`와 높은 우선순위 `vivanaut_safety`로 분리한다.

## 8. 앱 구성

- `PushDeviceRepository`: installation ID 보관, token upsert/deactivate.
- `PushMessagingService`: Firebase 초기화 이후 권한, token refresh, foreground 수신, tap stream 처리.
- `PushLifecycleObserver`: 인증 사용자 변화와 앱 lifecycle을 연결한다.
- `NotificationRepository`: 목록·미읽음 수·읽음 처리.
- Riverpod provider는 `currentUserProvider.select((u) => u?.id)`를 감시해 계정을 격리한다.
- 딥링크 allowlist는 정적 경로와 안전한 UUID path parameter만 허용한다. 외부 URL과 임의 route 문자열은 실행하지 않는다.

로그아웃은 원격 token 연결을 먼저 비활성화한 뒤 Supabase Auth 세션을 종료한다. 비활성화 실패가 로그아웃을 막지는 않지만 오류를 기록하고, 다음 로그인 등록 RPC가 이전 연결을 교체한다.

## 9. 오류와 관측성

- 토큰 획득·저장은 재시도 가능하며 앱 시작을 막지 않는다.
- 알림 목록 실패는 재시도 UI를 표시하고 기존 데이터가 있으면 유지한다.
- 개인정보·토큰·service key를 로그나 패치노트에 출력하지 않는다.
- outbox에는 민감하지 않은 FCM 오류 코드와 attempts만 남긴다.
- 발송 성공률, 영구 실패 수, 활성 토큰 수를 운영 점검 기준으로 삼는다.

## 10. 테스트 및 완료 기준

- migration 정책 검사: 타 계정 token/notification 접근 불가, 자기 읽음 처리만 가능.
- Dart unit/widget: payload 파싱, route allowlist, token refresh/upsert, logout deactivate, 알림 목록/빈 상태/에러/읽음/red dot.
- 앱 통합: foreground 1회 표시, background/cold-start tap route.
- Android 실기기: Android 13+ 허용·거절·재시도, 토큰 refresh, 실제 test push.
- `flutter analyze` 오류 0, `flutter test` 통과, `flutter build apk --debug` 성공.
- Firebase 서비스 계정과 ingest secret이 Git history에 없음.

## 11. 배포 순서

1. Supabase migration과 RLS/RPC 배포.
2. Edge Functions 배포 후 secrets 설정.
3. 앱 Android FCM 기능 배포.
4. 앱 로그인 계정으로 token 등록 확인.
5. 내부 test event → 알림 센터 → FCM 실기기 수신 확인.
6. community/notice 생산 활성화.
7. petcam-lab 연동.
8. terra-server 연동.
9. 임계치가 별도 승인된 뒤 safety 생산 활성화.

## 12. 범위 밖

- iOS/APNs
- 안전 임계 수치의 임의 결정
- petcam-lab 후보 생성·검수 UI 자체
- terra-server 명령 실행·센서 판정 코드
- 마케팅 캠페인 도구
