# 라이브 직접 녹화 — 서버 요청 (초안, 2026-10-20)

받는 분: 백엔드 (클립 R2 저장·presigned URL을 맡는 쪽)
보내는 쪽: 비바나트 앱
상태: **앱 쪽 결정 확정(2026-10-20, 아래 표 제안값 그대로 사용자 승인). 발송은 보류** — 사용자가 개발 요청 시점을 정한다.

## 배경

카메라 라이브 화면에서 사용자가 버튼을 눌러 **최대 60초**를 직접 녹화하는 기능을 만들고 있습니다.

- 녹화는 앱이 받은 라이브 영상을 폰에서 파일로 저장하는 방식입니다(카메라·펌웨어 변경 없음).
- 파일: H.264 mp4, 소리 없음, 1280×960, 약 2.5Mbps → **60초에 약 19MB**, 썸네일 jpg 1장(수십 KB).
- 앱에서 Android 녹화·재생까지 확인했습니다(2026-10-01). 지금은 폰 안에만 저장됩니다.
- 앱에는 R2 쓰기 권한이 없어서 서버에 올릴 수 없습니다. **이 부분을 요청드립니다.**

직접 녹화는 움직임 영상(`motion_clips`)과 **섞지 않습니다.** 하이라이트 규칙·카메라 탭 전체 영상 목록에는 나오지 않고 앱 보관함(북마크 화면)에만 "직접 녹화" 배지로 보입니다. 그래서 별도 테이블·별도 경로를 제안합니다.

## 사용자 흐름 (앱 쪽)

1. 라이브 가로 전체화면에서 녹화 버튼 → 최대 60초 녹화(일찍 정지 가능, 3초 미만은 버림).
2. 녹화가 끝나면 **폰에 먼저 저장하고 보관함에 바로 보입니다.** 업로드는 뒤에서 합니다.
3. 업로드 실패(망 끊김·앱 종료)면 다음 앱 실행 때 다시 시도합니다. 보관함 카드에 "업로드 대기" 표시.
4. 업로드가 끝나면 다른 폰·재설치 후에도 보관함에서 볼 수 있습니다.
5. 사용자가 보관함에서 지우면 서버에서도 지웁니다.

---

## 요청 1. 녹화 등록 + 업로드 URL 발급

녹화가 끝나 파일 크기를 안 뒤에 호출합니다.

```
POST /recordings
{
  "camera_id": "uuid",
  "client_id": "uuid",          // 앱이 만든 id — 재시도 때 중복 등록 방지(같은 값이면 기존 행을 돌려줌)
  "started_at": "2026-10-20T12:34:56Z",
  "duration_ms": 60000,
  "size_bytes": 19500000,
  "width": 1280, "height": 960,
  "has_thumbnail": true
}
→ 201
{
  "recording_id": "uuid",
  "video_upload_url": "https://...presigned PUT",
  "thumb_upload_url": "https://...presigned PUT",   // has_thumbnail=false면 null
  "expires_at": "..."                               // URL 유효 시간(권장 1시간)
}
```

- 카메라 소유 확인(그 계정의 카메라가 아니면 403).
- 검사: `duration_ms` 3,000~60,000 / `size_bytes` ≤ **30MB**(여유 포함) / content-type `video/mp4`, `image/jpeg`.
- 한도 초과면 409 `recording_quota_exceeded` + 현재 사용량(아래 "정할 것" 1).
- 같은 `client_id` 재호출 → 기존 `recording_id`와 **새 업로드 URL**을 돌려줌(업로드 중 URL 만료 대비).
- 저장 경로 제안: `recordings/{user_id}/{camera_id}/{recording_id}.mp4` (+ `.jpg`). 앱은 경로를 직접 만들거나 파싱하지 않습니다.

## 요청 2. 업로드 완료 확인

```
POST /recordings/{id}/complete
→ 200 { "status": "ready" }
```

- 서버가 R2에 객체가 있고 크기가 등록값과 맞는지 확인한 뒤 `ready`로 바꿉니다. 없으면 409 `upload_missing`.
- `pending`인 채 **24시간** 넘은 행과 객체는 서버가 정리해 주세요(앱이 중간에 지워졌을 때).

## 요청 3. 목록

```
GET /recordings?camera_id=&cursor=&limit=30
→ { "items": [ { id, camera_id, started_at, duration_ms, size_bytes, status, has_thumbnail, created_at } ], "next_cursor": "..." }
```

- `ready`만, `started_at` 최신순, cursor 페이지.
- `camera_id` 없으면 그 계정 전체. 카메라를 unlink해도 녹화는 사용자 것이라 목록에 남깁니다(카메라 이름 대신 "삭제된 카메라"로 표시 예정) — 맞는지 확인 부탁드립니다.
- Supabase 직결 SELECT(RLS `user_id = auth.uid()`)로 주셔도 괜찮습니다. 편한 쪽을 알려 주세요.

## 요청 4. 재생·썸네일 URL

기존 클립(`GET /clips/{id}/url`)과 같은 방식입니다.

```
GET /recordings/{id}/url            → { "url": "presigned GET", "expires_at": "..." }
GET /recordings/{id}/thumbnail/url  → 같음 (썸네일 없으면 404)
```

## 요청 5. 삭제

```
DELETE /recordings/{id}   → 204
```

- 행과 R2 객체(영상·썸네일)를 함께 지웁니다. 남의 녹화면 404.
- **회원 탈퇴 시 그 계정의 녹화 전부 삭제**를 탈퇴 처리에 넣어 주세요.

## 요청 6. 테이블 (제안)

```sql
create table public.live_recordings (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  camera_id     uuid references public.cameras(id) on delete set null,
  client_id     uuid not null,
  status        text not null default 'pending',   -- pending / ready
  started_at    timestamptz not null,
  duration_ms   int not null,
  size_bytes    bigint not null,
  width         int, height int,
  r2_key        text not null,
  thumbnail_key text,
  created_at    timestamptz not null default now(),
  unique (user_id, client_id)
);
alter table public.live_recordings enable row level security;
create policy "select own" on public.live_recordings
  for select to authenticated using (user_id = auth.uid());
-- INSERT/UPDATE/DELETE는 서버만(앱은 REST 경유).
create index on public.live_recordings (user_id, started_at desc);
```

---

## 앱 쪽 결정 (2026-10-20 확정)

| # | 질문 | 결정 |
|---|---|---|
| 1 | 계정당 한도 | 개수 **50개**(≈1GB). 넘으면 새 녹화 업로드를 막고 "오래된 녹화를 지워 주세요" 안내. 자동 삭제는 하지 않음 |
| 2 | 보관 기간 | 사용자가 지울 때까지(한도로 비용 통제) |
| 3 | 셀룰러 업로드 | 기본은 Wi-Fi에서만, 설정에서 셀룰러 허용 |
| 4 | 업로드 후 폰 파일 | 업로드 7일 뒤 폰에서 지우고 서버 URL로 재생(썸네일은 유지) |
| 5 | 커뮤니티 공유 | 이번 범위 밖. 나중에 서버 복사(`community-media`)로 따로 요청 |
| 6 | 워터마크 | 이번 범위 밖(로고가 아직 구 브랜드) |

## 앱 쪽 진행 (참고)

- 녹화 화질: flutter_webrtc가 녹화 비트레이트를 6Mbps로 고정해 두어(Android `VideoFileRenderer.java`, iOS `FlutterRTCMediaRecorder.m`) 1분 33MB가 나왔습니다. 패키지를 레포 안에 복사해 **2.5Mbps로 고쳐** 1분 약 19MB로 맞춥니다(서버 작업과 무관).
- 실제 iPhone 녹화 확인 전. iOS가 안 되면 Android만 먼저 엽니다.
- 업로드 대기열·재시도·보관함 표시는 앱이 맡습니다.
- 앱 기획서: 브랜치 `feat/live-recording`의 `docs/superpowers/specs/2026-10-01-live-recording-design.md`.
