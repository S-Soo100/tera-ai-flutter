# Android FCM 배포 체크리스트 및 운영 인계

> 작성일: 2026-09-15
> 범위: Android FCM 우선. iOS/APNs, terra-server 및 petcam-lab 생산자 연결은 이 배포의 후속이다.

## 현재 판정

| 항목 | 상태 | 근거 / 다음 조치 |
|---|---|---|
| 저장소 구현 | 준비 완료 | FCM DDL `supabase/migrations/20260915000000_fcm_notifications.sql`, `notification-ingest`, `dispatch-push`가 저장소와 운영 환경에 반영됐다. |
| Node 공유 테스트 | 통과 | `node --test supabase/functions/_shared/*.test.mjs`: 27/27 통과. |
| Flutter 검증 | 통과 | focused 56개 및 전체 707개 테스트 통과(선택형 1개 제외), `flutter analyze --no-fatal-infos` 오류·경고 0(기존 info 10개), Android debug APK 생성 통과, iOS 14 `pod install` 통과. |
| Supabase CLI 인증/연결 | 완료 | `terra-ai-dev` 조직의 `Terra AI` project ref `slxjvzzfisxqwnghvrit`에 로그인·링크했다. |
| 운영 migration 상태 | 적용 완료 | `20260915000000_fcm_notifications.sql`을 production에 적용하고 테이블·RPC·RLS·Realtime 및 역할별 접근을 확인했다. |
| 로컬 DB lint | 2026-09-15 증거: schema errors 없음 | controller가 로컬 네트워크 권한으로 실행해 `No schema errors found`를 받았다. 이는 `127.0.0.1:54322`에서 당시 실행 중이던 스키마만 검사했으며 FCM migration을 실행하거나 검증하지 않았다. |
| 기존 커뮤니티 DDL | 이번 push에서 제외 | `2026-08-31_community_clip_feed.sql`은 구 형식 파일명이라 CLI migration 관리 대상에서 건너뛴다. 이 DDL은 과거 Dashboard SQL Editor에서 실행되었다. |
| Edge Functions | 배포 완료 | `notification-ingest`, `dispatch-push`가 production에 배포됐다. dispatcher는 이름이 `dispatch_push`인 Supabase secret API key만 `apikey` 헤더로 받는다. |
| Firebase 서비스 계정 secret | 등록 완료 | `FIREBASE_SERVICE_ACCOUNT_JSON`을 Supabase Edge Function Secret에 등록하고 이름을 확인했다. Firebase OAuth 발급까지 검증한 뒤 로컬 JSON 원본은 영구 삭제했다. 값은 문서·Git·로그에 남기지 않았다. |
| dispatcher scheduler | 가동 중 | 교체 발급한 `dispatch_push` secret API key를 Vault의 `dispatch_push_api_key`로 보관하고, `pg_net` + `pg_cron` 1분 주기 job `dispatch-push-every-minute`(`jobid=4`, active)을 등록했다. 수동 호출과 연속 자동 실행 모두 HTTP 200, `processed=0`, `sends=0`으로 통과했다. |
| ingest secret | 등록 완료 | `PUSH_EVENT_INGEST_SECRET`을 Edge Function Secret에 등록하고 Vault의 `notification_ingest_secret`에 보관했다. 빈 payload 호출이 401이 아닌 계약 오류 400을 반환해 인증 통과를 확인했으며, 실제 값은 이관훈님에게 안전한 채널로 별도 전달한다. |
| Android 실기기 push | 대기 | Android 13+ 기기에서 허용·거절·재시도·탭 딥링크를 실제 FCM으로 확인해야 한다. |
| terra-server / petcam-lab | 대기 | 실제 ACK 이벤트 및 검수 완료 하이라이트 생산자는 아직 ingest endpoint에 연결하지 않았다. |

## 배포 전제와 원칙

- 대상 Supabase project ref는 `slxjvzzfisxqwnghvrit`이다.
- 비밀값은 Git, 이 문서, Slack 평문, 함수 로그에 넣지 않는다. `PUSH_EVENT_INGEST_SECRET`, Firebase 서비스 계정 JSON, dispatcher용 Supabase secret API key는 서로 다른 용도이며 외부 생산자에게 Firebase 자격 증명이나 dispatcher key를 전달하지 않는다.
- 두 함수 모두 gateway의 legacy JWT 검증은 끈다. `notification-ingest`는 외부 생산자용 bearer secret을 함수 내부에서 검증하고, `dispatch-push`는 이름이 `dispatch_push`인 Supabase secret API key를 함수 내부에서 `apikey` 헤더와 정확히 대조한다.
- 아래 원격 변경 명령은 계정 소유자 또는 명시적으로 위임받은 운영자가 실행한다.

## 1. 로그인·링크 및 적용 전 확인

로컬 프로젝트 루트에서 실행한다. 첫 명령은 브라우저 로그인으로 access token을 만들며, 인증 정보와 project link를 준비할 뿐 스키마를 바꾸지 않는다.

```sh
supabase login
supabase projects list
supabase link --project-ref slxjvzzfisxqwnghvrit
supabase migration list
```

이 일반 `supabase migration list`가 link된 **production** project의 applied history를 확인하는 기준이다. 2026-09-15에 `20260915000000` 적용을 확인했다. 반면 `supabase migration list --local`의 Local/Remote 열은 filesystem과 선택된 로컬 DB의 applied history를 비교하는 것이며 production 상태가 아니다. 구 파일 `2026-08-31_community_clip_feed.sql`은 이름 형식이 달라 CLI migration 관리 대상에서 건너뛴다. 과거 Dashboard 적용 이력을 다시 push하려 하지 않는다.

2026-09-15에 controller는 로컬 네트워크 권한이 있는 환경에서 다음을 실행하여 `No schema errors found`를 받았다.

```sh
supabase db lint --local
node --test supabase/functions/_shared/*.test.mjs
```

이 lint는 당시 `127.0.0.1:54322`에서 실행 중이던 어떤 스키마에 오류가 없음을 검사한 결과다. 새 FCM migration을 실행하지도, 해당 migration이 적용됐는지도 검증하지 않는다. production 적용 여부는 link 뒤 일반 `supabase migration list`로 확인한다.

## 2. 스키마와 Edge Function 배포

먼저 link된 production history를 검사한다. 이미 `20260915000000`가 있으면 `db push`를 실행하지 말고, migration 파일·Dashboard 변경 이력·원격 schema를 조사해 상태 차이를 해결한다.

```sh
supabase migration list
```

FCM version이 production history에 없는 것이 확인된 경우에만 아래 변경 명령을 실행한다. `db push`는 원격 schema를 변경한다.

```sh
supabase db push
supabase migration list
supabase functions deploy notification-ingest
supabase functions deploy dispatch-push
```

성공 조건은 일반 `supabase migration list`에서 `20260915000000`가 production applied history에 나타나고, 두 함수 배포 명령이 성공하는 것이다. 오류가 나면 부분 성공을 배포 완료로 표시하지 말고, 어떤 단계까지 완료됐는지 운영 기록에 남긴다.

## 3. 비밀값 등록

로컬에서만 보관되고 Git이 무시하는 `.env.fcm-deploy` 파일을 만들고 권한을 제한한다. 실제 값은 운영자가 편집기에서 입력한다. 아래 예시의 꺾쇠 표시는 입력 지시일 뿐 값이 아니다.

```sh
umask 077
${EDITOR:-vi} .env.fcm-deploy
chmod 600 .env.fcm-deploy
git check-ignore -q .env.fcm-deploy
supabase secrets set --env-file .env.fcm-deploy
```

필요한 값은 아래 두 가지지만, 실제 비밀값은 이 문서에 복사하지 않는다.

```dotenv
PUSH_EVENT_INGEST_SECRET=<새로 생성한 고엔트로피 ingest secret>
FIREBASE_SERVICE_ACCOUNT_JSON=<Firebase 서비스 계정 JSON 한 줄>
```

2026-09-15 현재 `FIREBASE_SERVICE_ACCOUNT_JSON`과 `PUSH_EVENT_INGEST_SECRET` 모두 등록 완료했다. ingest secret은 Vault의 `notification_ingest_secret`에도 보관해 이후 안전한 전달에 사용한다. Dashboard의 Edge Function secrets 화면에서는 **이름만** 확인하며, 값의 표시·채팅 전송·로그 출력은 금지한다.

## 4. secret API key 인증 scheduler

`dispatch-push`는 공개 호출이나 일반 사용자 JWT 호출을 받지 않는다. Supabase의 이름 있는 secret API key `dispatch_push`를 만들고, scheduler는 이 값을 `apikey` 헤더로만 전달한다. 함수는 `SUPABASE_SECRET_KEYS` 환경 map에서 같은 이름의 값을 읽어 정확히 대조한 뒤 admin DB 작업을 시작한다.

1. Supabase Dashboard에서 생성한 `dispatch_push` secret API key를 Vault에 `dispatch_push_api_key` 이름으로 저장한다. 값은 SQL, shell history, 이 문서에 넣지 않는다.
2. Dashboard SQL Editor에서 아래 SQL을 실행한다. Vault secret 이름이 정확히 일치해야 한다.

```sql
select cron.schedule(
  'dispatch-push-every-minute',
  '* * * * *',
  $job$
    select net.http_post(
      url := 'https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/dispatch-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'dispatch_push_api_key'
        )
      ),
      body := '{}'::jsonb
    );
  $job$
);
```

3. 동일 이름의 schedule이 이미 있으면 새로 만들기 전에 Dashboard/`cron.job`에서 기존 job을 확인하고, 중복 실행을 피하도록 해당 job만 해제 또는 수정한다. 현재 운영에는 `jobid=4` 한 건만 활성화되어 있다. `cron`, `pg_net`, Vault를 사용할 수 없는 project tier/설정이면 임의의 무인증 webhook으로 대체하지 말고, secret API key를 안전하게 주입하는 동등한 운영 scheduler를 별도 승인받는다.

## 5. 배포 후 인증·실기기 확인

먼저 dispatcher secret API key를 운영자 셸에서 비표시 입력으로만 주입해 함수 접근 제어를 확인한다. 실제 키를 명령행, 파일, 채팅에 쓰지 않는다.

```sh
read -r -s DISPATCH_PUSH_API_KEY
export DISPATCH_PUSH_API_KEY
printf '\n'
curl --fail-with-body --silent --show-error \
  -X POST 'https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/dispatch-push' \
  -H "apikey: $DISPATCH_PUSH_API_KEY" \
  -H 'Content-Type: application/json' \
  --data '{}'
unset DISPATCH_PUSH_API_KEY
```

그 다음 Android 13+ 실기기에서 다음을 하나의 추적 가능한 테스트 사용자·설치 ID로 끝까지 확인한다.

- 알림 권한 허용, 거절, 이후 재요청과 token refresh/로그아웃 비활성화.
- 테스트 이벤트로 `app_notifications`, outbox, delivery가 생성되고 scheduler가 FCM을 발송하는지.
- foreground 표시와 background/종료 상태 탭이 allowlisted route로 이동하는지.
- 중복 `event_id` 재전송이 알림 하나로 수렴하고, 읽음 처리와 프로필 red dot이 일치하는지.

현재 서버 발송 기반은 운영 배포됐지만, 이 실기기 확인 전에는 “Android FCM 전체 완료”가 아니라 “서버 발송 기반 가동, Android 실기기 E2E 대기”로 보고한다. 마지막으로 terra-server의 ACK 세 이벤트와 petcam-lab의 검수 완료 `highlight.ready`를 보안 채널로 endpoint/ingest secret 전달 후 공동 스테이징한다.
