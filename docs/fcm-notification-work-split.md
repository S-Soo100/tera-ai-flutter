# 비바나트 FCM 단계별 업무 분장

> 작성일: 2026-09-15
> 범위: Android 우선, iOS/APNs 보류
> 설계 SOT: `docs/superpowers/specs/2026-09-15-android-fcm-notifications-design.md`
> 재개 체크포인트: `docs/handoffs/2026-09-15-fcm-session-checkpoint.md`

## 배포 상태 (2026-09-15)

| 범위 | 상태 | 남은 운영 조치 |
|---|---|---|
| 저장소 구현·Node 테스트 | 준비 완료 (27/27 통과) | 운영과 동일한 dispatcher secret API key 인증을 포함해 검증했다. |
| Flutter·빌드 검증 | 통과 | focused 56개·전체 707개 테스트(선택형 1개 제외), analyze 오류·경고 0(기존 info 10개), Android APK, iOS 14 pod install까지 확인했다. |
| Supabase schema/functions | 운영 배포 완료 | FCM migration과 두 Edge Function을 production에 반영하고 RLS/RPC/Realtime 접근을 확인했다. |
| Firebase secret | 등록 완료 | `FIREBASE_SERVICE_ACCOUNT_JSON`은 Supabase Edge Function Secret에 등록됐다. 이관훈님에게 전달하지 않는다. |
| dispatcher scheduler | 가동 중 | `dispatch_push` secret API key를 Vault에 보관하고 1분 주기 cron을 활성화했다. 수동 호출은 HTTP 200으로 통과했다. |
| ingest secret | 등록·인증 확인 완료 | `PUSH_EVENT_INGEST_SECRET`은 Supabase Secret에 등록하고 Vault에도 보관했다. 이관훈님에게 실제 값을 보낼 안전한 전달만 남았다. |
| Android 실기기 FCM | 대기 | Android 13+ 권한·수신·탭 이동을 실제 push로 확인한다. |
| terra-server·petcam-lab | 대기 | ACK/하이라이트 생산자를 ingest 계약에 연결하고 공동 스테이징한다. |

상세한 안전 배포 명령과 scheduler 인증 방식은
[`2026-09-15-fcm-deployment-checklist.md`](handoffs/2026-09-15-fcm-deployment-checklist.md)를 따른다. 2026-09-15에 project ref `slxjvzzfisxqwnghvrit`의 production 적용과 함수 호출을 확인했다. `supabase migration list --local`은 filesystem과 선택된 로컬 DB history만 비교하므로 production 상태 근거로 사용하지 않는다.

## 책임 구분

| 담당 | 해야 할 일 | 하지 않는 일 |
|---|---|---|
| 비바나트 앱 팀(우리) | Firebase Android 연결, Flutter 수신·권한·딥링크, Supabase token/알림/outbox/RLS, Edge Function 발송, 알림 센터, 커뮤니티·공지·관리 알림 | terra-server의 기기 ACK 판정, petcam-lab의 하이라이트 검수 |
| petcam-lab | 하이라이트 후보 생성, 사람 검수, 승인 스냅샷 확정, `highlight.ready` 이벤트 전송 | terra-server 동작 이벤트, FCM 직접 발송 |
| 이관훈님/terra-server | 예약·타이머 실제 ACK 후 시작·종료·실패 이벤트 전송, 향후 안전 조건 판정·회복 이벤트 | FCM token·Firebase 키·알림 문구·알림 DB 관리 |
| 계정 소유자(백성찬) | Firebase/Supabase 운영 권한, 비밀값 등록과 실기기 최종 확인 | Apple Developer 관련 작업은 계정 준비 전까지 보류 |

## 단계별 진행

### 0단계 — 기반 확인

- **우리**: Firebase 프로젝트 `vivanaut-app`, Android 앱 `com.vivanaut.app`, `google-services.json` 연결을 확인한다.
- **완료 기준**: Android debug 빌드가 Firebase 설정을 포함해 성공한다.
- **외부 요청**: 없음.

### 1단계 — 공통 계약과 저장소

- **우리**: Supabase에 `push_devices`, `app_notifications`, `notification_events`, `notification_outbox`와 RLS/RPC를 만든다.
- **우리**: 외부 생산자용 `notification-ingest`와 FCM 발송용 `dispatch-push` 계약을 구현한다.
- **계정 소유자**: Firebase 서비스 계정과 ingest secret은 Supabase Secret 등록을 완료했다. ingest secret 실제 값은 안전한 전달 경로로만 공유한다. 비밀값은 Git·Slack 평문에 남기지 않는다.
- **이관훈님에게 요청**: 1차 요청서를 보내 ACK 코드 위치, 식별자 확보 가능 여부, outbox 위치, payload 용어, 스테이징 가능 시점을 회신받는다.
- **완료 기준**: 같은 `event_id`를 여러 번 보내도 알림 한 건만 생성된다.

### 2단계 — Android 앱 공사

- **우리**: FCM 초기화, 최초 권한 설명, OS 권한 요청, token 등록·refresh·로그아웃 비활성화를 구현한다.
- **우리**: 포그라운드 표시, 백그라운드·종료 상태 탭, route allowlist를 구현한다.
- **우리**: Supabase 기반 알림 센터, 읽음 처리, 프로필 red dot을 구현한다.
- **완료 기준**: 단위·위젯 테스트, `flutter analyze`, 전체 `flutter test`, Android debug 빌드가 통과한다.
- **외부 요청**: 없음. 이관훈님 이벤트가 아직 없어도 샘플 event로 검증 가능해야 한다.

### 3단계 — 생산자 연결

- **petcam-lab에 요청**: 검수 확정 `highlight_batch_id`를 기준으로 `highlight.ready` 이벤트를 보낸다. 촬영 D 20:00~D+1 08:00, 검수 D+1, 알림 D+2 08:00 KST 정책을 적용한다.
- **이관훈님에게 요청**: 실제 ACK가 확정된 예약·타이머 명령만 `device.action.started`, `device.action.ended`, `device.action.failed`로 보낸다.
- **우리**: 커뮤니티 댓글 즉시, 좋아요 10분 묶음, 공지 발행, 물통 세척 알림 생산을 연결한다.
- **완료 기준**: 각 생산자가 FCM 자격 증명 없이 동일 ingest 계약으로 알림을 생성한다.

### 4단계 — 공동 스테이징 검증

- **우리 + 이관훈님**: started/ended/failed 샘플 각 1건과 중복 재전송, 5xx 재시도, 잘못된 4xx payload를 검증한다.
- **우리 + petcam-lab**: 승인 완료·미승인·늦은 승인 하이라이트의 예약 시각을 검증한다.
- **계정 소유자**: Android 13+ 실기기에서 허용·거절·재시도·탭 이동을 확인한다.
- **완료 기준**: 앱 내 기록, push 수신, 읽음 처리, 중복 억제, 실패 추적이 모두 확인된다.

### 5단계 — 후속 확장

- **우리 + 이관훈님**: 온도·습도 임계치, 지속 시간, cooldown, 회복 조건을 별도 승인한다.
- **이관훈님**: 승인된 정책으로 `safety.alert`와 `safety.recovered`를 활성화한다.
- **계정 소유자**: Apple Developer 계정 준비 후 APNs key와 iOS Firebase 앱을 구성한다.
- **우리**: iOS 권한과 수신 경로를 추가한다.

## 외부 전달 문서 (2026-09-23 정리)

- 이관훈님 Slack 복사본은 상세 계약과 중복돼 삭제했다. 최신 회신 반영은 [9/16 결정 답신](handoffs/2026-09-16-lee-gwanhun-reply-2-decisions.md)을 확인한다.
- 이관훈님 상세 계약: `docs/handoffs/2026-09-15-terra-server-notification-events-request.md`
- petcam-lab: [하이라이트 정책 v2 요청](handoffs/2026-09-19-petcam-lab-highlight-policy-v2-request.md). 기존 승인 스냅샷 전달문을 대체한다.
- 두 생산자에게 실제 `PUSH_EVENT_INGEST_SECRET`을 문서나 Slack 평문으로 보내지 않고 안전한 채널로 별도 전달한다.
