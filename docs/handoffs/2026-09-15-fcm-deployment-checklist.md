# Android FCM 배포 체크리스트 및 운영 인계

> 작성일: 2026-09-15
> 범위: Android FCM 우선. iOS/APNs, terra-server 및 petcam-lab 생산자 연결은 이 배포의 후속이다.

## 현재 판정

| 항목 | 상태 | 근거 / 다음 조치 |
|---|---|---|
| 저장소 구현 | 준비 완료 (로컬) | FCM DDL `supabase/migrations/20260915000000_fcm_notifications.sql`, `notification-ingest`, `dispatch-push`가 저장소에 있다. 원격에는 아직 적용하지 않았다. |
| Node 공유 테스트 | 통과 | `node --test supabase/functions/_shared/*.test.mjs`: 19/19 통과. |
| Flutter 검증 | 통과 | focused 45개 및 전체 696개 테스트 통과, `flutter analyze` 0 errors, Android debug APK 생성 통과, iOS 14 `pod install` 통과. |
| Supabase CLI 인증/연결 | 미완료 | `supabase projects list`는 access token이 없어 실패했다. 로그인 후 project ref `slxjvzzfisxqwnghvrit`에 링크해야 한다. |
| 마이그레이션 등록 | 원격 미적용 | `supabase migration list --local`에서 `20260915000000`은 Local/file 열에 인식되지만 Remote/applied 열에는 없다. |
| 로컬 DB lint | 스키마 오류 없음 | `supabase db lint --local`은 schema errors 없음을 보고했다. 이는 새 마이그레이션이 실행되었거나 원격에 배포되었다는 증거는 아니다. |
| 기존 커뮤니티 DDL | 이번 push에서 제외 | `2026-08-31_community_clip_feed.sql`은 구 형식 파일명이라 CLI migration 관리 대상에서 건너뛴다. 이 DDL은 과거 Dashboard SQL Editor에서 실행되었다. |
| Edge Functions | 원격 미배포 | 인증/링크가 없어 `notification-ingest`, `dispatch-push`의 원격 배포는 아직 하지 않았다. |
| Firebase 서비스 계정 secret | 미등록·미확인 | `FIREBASE_SERVICE_ACCOUNT_JSON`의 원격 등록은 운영 권한자가 해야 한다. 확인 전에는 발송을 시작하지 않는다. |
| Android 실기기 push | 대기 | Android 13+ 기기에서 허용·거절·재시도·탭 딥링크를 실제 FCM으로 확인해야 한다. |
| terra-server / petcam-lab | 대기 | 실제 ACK 이벤트 및 검수 완료 하이라이트 생산자는 아직 ingest endpoint에 연결하지 않았다. |

## 배포 전제와 원칙

- 대상 Supabase project ref는 `slxjvzzfisxqwnghvrit`이다.
- 비밀값은 Git, 이 문서, Slack 평문, 함수 로그에 넣지 않는다. `PUSH_EVENT_INGEST_SECRET`, Firebase 서비스 계정 JSON, Supabase service-role key는 서로 다른 용도이며 외부 생산자에게 service-role/Firebase 자격 증명을 전달하지 않는다.
- `notification-ingest`만 외부 생산자용 bearer secret을 자체 검증하므로 `verify_jwt = false`다. `dispatch-push`는 기본 JWT 검증과 service-role bearer 대조를 유지한다.
- 아래 원격 변경 명령은 계정 소유자 또는 명시적으로 위임받은 운영자가 실행한다.

## 1. 로그인·링크 및 적용 전 확인

로컬 프로젝트 루트에서 실행한다. 첫 명령은 브라우저 로그인으로 access token을 만들며, 인증 정보와 project link를 준비할 뿐 스키마를 바꾸지 않는다.

```sh
supabase login
supabase projects list
supabase link --project-ref slxjvzzfisxqwnghvrit
supabase migration list
```

`supabase migration list`의 Remote 열에서 FCM 버전 `20260915000000`가 아직 없음을 재확인한다. Local/file 열의 인식은 파일 발견 결과일 뿐 적용 결과가 아니다. 구 파일 `2026-08-31_community_clip_feed.sql`은 이름 형식이 달라 CLI가 관리하지 않으므로, 과거 Dashboard 적용 이력을 다시 push하려 하지 않는다.

로컬 Supabase stack을 사용할 수 있는 환경에서는 다음도 실행한다.

```sh
supabase db lint --local
node --test supabase/functions/_shared/*.test.mjs
```

lint의 성공은 현재 로컬 DB에 대한 오류 검사다. 새 FCM DDL의 원격 적용 여부는 다음 단계 뒤 `supabase migration list`의 Remote 열로 확인한다.

## 2. 스키마와 Edge Function 배포

검토가 끝난 뒤에만 다음 명령을 순서대로 실행한다. `db push`는 원격 스키마를 변경한다.

```sh
supabase db push
supabase migration list
supabase functions deploy notification-ingest
supabase functions deploy dispatch-push
```

성공 조건은 `20260915000000`가 migration list의 Remote 열에 나타나고, 두 함수 배포 명령이 성공하는 것이다. 오류가 나면 부분 성공을 배포 완료로 표시하지 말고, 어떤 단계까지 완료됐는지 운영 기록에 남긴다.

## 3. 비밀값 등록

로컬에서만 보관되고 Git이 무시하는 `.env.fcm-deploy` 파일을 만들고 권한을 제한한다. 실제 값은 운영자가 편집기에서 입력한다. 아래 예시의 꺾쇠 표시는 입력 지시일 뿐 값이 아니다.

```sh
umask 077
${EDITOR:-vi} .env.fcm-deploy
chmod 600 .env.fcm-deploy
git check-ignore -q .env.fcm-deploy
supabase secrets set --env-file .env.fcm-deploy
```

로컬 파일에는 아래 두 줄만 넣되, 실제 비밀값은 이 문서에 복사하지 않는다.

```dotenv
PUSH_EVENT_INGEST_SECRET=<새로 생성한 고엔트로피 ingest secret>
FIREBASE_SERVICE_ACCOUNT_JSON=<Firebase 서비스 계정 JSON 한 줄>
```

등록 뒤에는 Dashboard의 Edge Function secrets 화면에서 **이름만** 확인한다. `PUSH_EVENT_INGEST_SECRET`과 `FIREBASE_SERVICE_ACCOUNT_JSON`이 있어야 하며, 값의 표시·채팅 전송·로그 출력은 금지한다.

## 4. service-role 인증 scheduler

`dispatch-push`는 공개 호출이나 일반 사용자 JWT 호출을 받지 않는다. scheduler도 service-role bearer로 호출해야 한다.

1. Supabase Dashboard의 Vault에서 운영자가 service-role key를 직접 입력하여 이름 `dispatch_push_service_role_key`로 저장한다. 값은 SQL, shell history, 이 문서에 넣지 않는다.
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
        'Authorization', 'Bearer ' || (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'dispatch_push_service_role_key'
          limit 1
        )
      ),
      body := '{}'::jsonb
    );
  $job$
);
```

3. 동일 이름의 schedule이 이미 있으면 새로 만들기 전에 Dashboard/`cron.job`에서 기존 job을 확인하고, 중복 실행을 피하도록 해당 job만 해제 또는 수정한다. `cron`, `pg_net`, Vault를 사용할 수 없는 project tier/설정이면 임의의 무인증 webhook으로 대체하지 말고, service-role을 안전하게 주입하는 동등한 운영 scheduler를 별도 승인받는다.

## 5. 배포 후 인증·실기기 확인

먼저 service-role credential을 운영자 셸에서 비표시 입력으로만 주입해 함수 접근 제어를 확인한다. 실제 키를 명령행, 파일, 채팅에 쓰지 않는다.

```sh
read -r -s SUPABASE_SERVICE_ROLE_KEY
export SUPABASE_SERVICE_ROLE_KEY
printf '\n'
curl --fail-with-body --silent --show-error \
  -X POST 'https://slxjvzzfisxqwnghvrit.supabase.co/functions/v1/dispatch-push' \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H 'Content-Type: application/json' \
  --data '{}'
unset SUPABASE_SERVICE_ROLE_KEY
```

그 다음 Android 13+ 실기기에서 다음을 하나의 추적 가능한 테스트 사용자·설치 ID로 끝까지 확인한다.

- 알림 권한 허용, 거절, 이후 재요청과 token refresh/로그아웃 비활성화.
- 테스트 이벤트로 `app_notifications`, outbox, delivery가 생성되고 scheduler가 FCM을 발송하는지.
- foreground 표시와 background/종료 상태 탭이 allowlisted route로 이동하는지.
- 중복 `event_id` 재전송이 알림 하나로 수렴하고, 읽음 처리와 프로필 red dot이 일치하는지.

이 실기기 확인 전에는 “Android FCM 배포 완료”가 아니라 “저장소 준비 및 원격 배포 대기”로만 보고한다. 마지막으로 terra-server의 ACK 세 이벤트와 petcam-lab의 검수 완료 `highlight.ready`를 보안 채널로 endpoint/ingest secret 전달 후 공동 스테이징한다.
