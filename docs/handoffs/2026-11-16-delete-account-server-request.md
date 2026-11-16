# 회원 탈퇴(계정 삭제) 서버 구현 요청 (2026-11-16)

> 받는 사람: 이관훈님(서버) · 보내는 사람: 백승수
> 관련: [2026-09-16 마이페이지 서버 요청 C6](2026-09-16-mypage-server-requests.md) · [Google Play 출시 SOT](../ops/google-play-account.md)

## 1. 왜 지금 필요한가

- **Google Play 출시 필수.** 계정을 만들 수 있는 앱은 ① 앱 안에서 찾기 쉬운 삭제 시작 경로와 ② 앱 밖 웹 삭제 요청 경로를 둘 다 둬야 한다. 일시 비활성화는 삭제로 인정되지 않는다([정책](https://support.google.com/googleplay/android-developer/answer/13327111)).
- **App Store도 같다.** 계정 생성을 지원하는 앱은 앱 안에서 계정 삭제를 시작할 수 있어야 한다(심사 지침 5.1.1(v)).
- 2026-11-16에 Play 조직 개발자 계정을 만들었고, 첫 업로드를 준비하고 있다.
- 현재 앱의 [회원 탈퇴] 버튼은 Edge Function `delete-account`를 부른다. 이 함수가 운영에 없다(11-16 함수 목록: `notification-ingest`, `dispatch-push`뿐). 그래서 누르면 "회원 탈퇴 처리가 아직 준비되지 않았습니다"가 뜬다.

## 2. 앱이 부르는 방식 (현재 코드, 바꿀 수 있음)

```dart
await _client.functions.invoke('delete-account'); // POST, 본문 없음, 로그인 사용자 JWT
```

- 2xx → 앱이 푸시 기기를 정리하고 로그아웃한 뒤 로그인 화면으로 간다.
- 2xx가 아닌 모든 응답 → 지금은 "아직 준비되지 않았습니다". 함수가 배포되면 앱이 아래 응답 코드별로 문구를 나눈다.
- 탈퇴 전 확인 화면은 앱에 이미 있다(Figma `MyAcc_withdraw`).

**제안 응답 계약** (다르게 정해도 되고, 정해진 값을 알려 주면 앱이 맞춘다)

| 상태 | 본문 | 의미 |
|---|---|---|
| 200 | `{ "deleted": true }` | 삭제 완료 |
| 401 | — | JWT 없음·만료 |
| 409 | `{ "code": "<사유>" }` | 정책상 앱에서 지울 수 없는 계정(예: 라벨러·관리자) |
| 500 | `{ "code": "<사유>" }` | 처리 중 실패. 다시 시도해도 안전해야 한다(멱등) |

## 3. 그대로 `auth.admin.deleteUser`만 하면 실패한다 (운영 DB 실측)

`auth.users`를 참조하는 외래키 가운데 **NO ACTION·RESTRICT**가 있어, 해당 행이 있으면 삭제가 막힌다(11-16 `pg_constraint` 조회).

**일반 사용자도 걸리는 것 (NO ACTION)**

| 테이블.컬럼 | 운영 행 수(11-16) | 비고 |
|---|---|---|
| `user_profiles.id` | 80 | **모든 사용자에게 있다** → 지금은 누구도 못 지운다 |
| `commands.issued_by` | 10,534 (값 있는 행) | 제어를 한 번이라도 한 사용자 |
| `camera_clips.user_id` | 1,358 | |
| `behavior_logs.created_by` | 237 | |
| `conversations.user_id` | 0 | 구 챗 기능 |
| `community_notices.author_id`, `camera_activity_filter_settings.updated_by` | — | 운영자 쪽 |

**라벨링·리뷰 도구 쪽 (주로 RESTRICT, 일부 NO ACTION)**
- `motion_clip_labeling_*`, `gme_negative_audit_*`, `lick_review_*`, `gpa_review_*`, `labeling_review_*`, `highlight_rule_*`, `labeler_camera_assignments` 등. 라벨러·운영자 계정에 해당한다.

**결정이 필요한 것**
- 각 테이블에서 행을 **지울지**, 아니면 **사용자 칸만 비울지(익명화)** 정해 주세요.
  - 앱 쪽 제안: `user_profiles`는 삭제한다. `commands.issued_by`처럼 기기 기록에 붙은 값은 NULL로 비우고, 기록은 기기와 함께 처리한다.
- 라벨러·운영자 계정을 앱 탈퇴로 지울지, 409로 막고 따로 처리할지 정해 주세요.

## 4. CASCADE로 같이 지워지는 것 — DB 밖 정리가 필요하다

`devices`·`cameras`·`enclosures`·`motion_clips`·`live_recordings`·`pets`·`schedules`·`community_*`(글·댓글·좋아요·신고·차단)·`push_devices`·알림 테이블·`webrtc_*_logs` 등은 `ON DELETE CASCADE`다. DB 행은 자동으로 사라지지만 아래는 남는다.

1. **사육장 기기·카메라의 연결** — MQTT 자격, 서버 쪽 등록. 지금의 기기 `unlink` 흐름을 먼저 태워야 기기가 다른 계정으로 다시 등록될 수 있다.
2. **R2 영상** — `motion_clips` 원본·썸네일, 라이브 녹화(`live_recordings`). 경로 형식이 여러 가지라 DB에서 경로를 읽어 지워야 한다.
3. **Supabase Storage** — `pet-media`, `user-avatars`, `community-media`(11-16 기준 세 버킷 합계 28개). 행이 지워져도 파일은 남는다.
4. **함께 쓰는 사육장 그룹** — 다른 사용자와 공유한 기기나 그룹이 있으면 남은 사람 쪽 처리 방식을 정해야 한다.

## 5. 제안 처리 순서

1. JWT로 사용자를 확인한다(service role 클라이언트는 함수 안에서만 쓴다).
2. 라벨러·운영자 계정이면 409를 돌려준다(3절 결정에 따름).
3. 소유한 사육장 기기·카메라를 `unlink`한다(terra-server·petcam).
4. R2 객체와 Storage 파일을 삭제한다.
5. NO ACTION 참조를 정리한다(삭제 또는 NULL).
6. `auth.admin.deleteUser(uid)`를 실행한다. 나머지는 CASCADE로 지워진다.
7. 200을 돌려준다.

- 중간에 실패해도 다시 부르면 이어서 끝나도록 만들어 주세요. 이미 지운 것은 건너뛴다.

## 6. 웹 삭제 요청 경로 (앱 밖)

- Play 요건 때문에 회사 사이트에 계정 삭제 요청 페이지를 둔다. 페이지는 백승수가 만든다.
- 요청은 메일로 받는다. 들어온 요청은 **같은 삭제 절차를 운영자가 실행**한다. 운영자용 실행 방법(관리 함수나 스크립트)을 같이 만들어 주세요.
- **법적으로 보관해야 하는 데이터**가 있으면 항목과 기간을 알려 주세요. 웹페이지와 개인정보처리방침에 그대로 적는다. 앱 쪽에서는 결제가 없어 현재 해당 항목을 모른다.

## 7. 확인 방법

- 테스트 계정 둘을 준비한다.
  - (a) 기기가 없는 계정
  - (b) 사육장·카메라가 연결되고, 영상·커뮤니티 글이 있는 계정
- 각각 앱에서 탈퇴한 뒤 아래를 확인한다.
  - 같은 메일로 로그인할 수 없다
  - `auth.users`와 위 테이블에 그 uid 행이 0개다
  - Storage·R2 파일이 0개다
  - 기기를 다른 계정에 다시 등록할 수 있다
- 함수를 두 번 연속 불러도 오류 없이 끝난다.

## 회신 부탁

1. 3절의 테이블별 처리 방식(삭제 또는 익명화)과 라벨러·운영자 계정 처리
2. 응답 계약(2절)을 확정하거나 수정
3. 배포 예정일 — Play 첫 출시 일정이 여기에 묶여 있다
4. 법적 보관 데이터와 기간(6절)
