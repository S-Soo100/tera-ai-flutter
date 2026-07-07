# 백엔드/API 개발자 핸드오프 — 카메라 상세 UX 개편 (2026-07-08)

> 대상: terra-server / terra-api 개발자
> 배경: Flutter 앱의 크레캠(펫캠) 상세 화면 UX 개편을 완료하며, **앱에서 임시(stopgap)로 처리한 2가지를 백엔드 정공법으로 이관**하기 위한 요청입니다.
> 관련 앱 계획서: `docs/plans/2026-07-08-camera-detail-ux.md`

---

## 요약 (TL;DR)

| # | 요청 | 현재 앱 임시조치 | 백엔드 작업 | 우선순위 |
|---|------|----------------|-----------|---------|
| 1 | **모션 클립 썸네일 presigned 엔드포인트** | 클라이언트가 영상 첫 프레임을 추출해 캐시 (느리고 클립당 API 호출 발생) | `GET /clips/{id}/thumbnail/url` 추가 (재생 URL과 동일 로직) | 높음 (소규모) |
| 2 | **클라우드 즐겨찾기 + R2 보존** | 로컬(Hive) 즐겨찾기 + 기기에 mp4 영구저장 (재설치·기기변경 시 소실) | `clip_favorites` 테이블 + RLS, 즐겨찾기 클립 R2 만료삭제 제외 | 중간 |

---

## 요청 1 — 모션 클립 썸네일 presigned 엔드포인트

### 문제
앱 크레캠 상세의 "비디오 기록" 그리드는 각 클립의 썸네일을 보여줘야 하는데, terra-api엔 **재생용 `GET /clips/{id}/url`만 있고 썸네일 발급 통로가 없다.** 그래서 앱이 **임시로** presigned 영상 URL의 첫 프레임을 `video_thumbnail`로 추출해 캐시하고 있다. 이 방식은:
- 그리드 진입 시 **클립마다 `GET /clips/{id}/url` 호출 1회 + 영상 일부 다운로드**가 발생(첫 로딩 느림·트래픽↑).
- R2에 이미 저장된 **실제 썸네일을 낭비**한다.

### 확인된 사실 (실 DB 조회, 2026-07-08)
- `motion_clips` **3,776행 전부(100%)** `thumbnail_key`와 `r2_key`가 채워져 있음.
- 썸네일 키 = 영상 키에서 **확장자만 `.mp4` → `.jpg`**:
  - 영상: `terra-clips/clips/p4cam-79b5d844/20260707-174915_f1443736-829f-4d7b-acf1-b8558d25c787.mp4`
  - 썸네일: `terra-clips/clips/p4cam-79b5d844/20260707-174915_f1443736-829f-4d7b-acf1-b8558d25c787.jpg`
- 즉 썸네일은 **R2에 실재**하며 DB 컬럼도 완비. presigned 발급 통로만 없다.

### 요청 계약
기존 `GET /clips/{id}/url`이 `r2_key`를 presign하는 것과 **동일한 로직으로 `thumbnail_key`를 presign**하는 엔드포인트:

```
GET /clips/{id}/thumbnail/url
Authorization: Bearer <JWT>          # 재생 URL과 동일 인증/RLS(본인 카메라 클립만)
```

**200 응답 (재생 URL 응답과 동일 형태 권장):**
```json
{
  "url": "https://<r2-host>/terra-clips/clips/.../20260707-174915_....jpg?<signature>",
  "ttl": 3600
}
```

**에러:**
- `thumbnail_key`가 없으면 `404`(앱은 아이콘 폴백).
- 권한 없으면 `403`/`404`(재생 URL과 동일 정책).

### 구현 힌트
- 재생 엔드포인트 핸들러를 복사해 presign 대상만 `r2_key` → `thumbnail_key`로 교체하면 됨(~5줄).
- TTL은 재생과 동일(현행 1시간)이면 충분.

### 앱 이관(스왑) 방식
엔드포인트가 준비되면 앱은 **`motionThumbnailProvider` 한 곳만** 교체한다(클라 추출 → 이 presigned URL을 `CachedNetworkImage`로 표시). 카드/그리드 코드는 그대로. → 클립당 프레임 추출 비용 제거, R2 실제 썸네일 사용.

---

## 요청 2 — 클라우드 즐겨찾기 + R2 보존

### 문제
앱에 "영상 즐겨찾기"가 추가됐다. 지금은 **로컬 전용**이다:
- 즐겨찾기 메타 → 기기 Hive.
- 즐겨찾기하면 **영상 mp4를 기기 문서 디렉토리에 영구 저장**(presigned URL 만료·R2 삭제와 무관하게 오프라인 재생 목적).
- 한계: **앱 재설치·기기 변경 시 즐겨찾기와 저장 영상이 모두 소실**된다. 계정 간 동기화도 없다.

### 요청 A — 즐겨찾기 동기화 테이블
```sql
create table clip_favorites (
  owner_id   uuid        not null references auth.users(id) on delete cascade,
  clip_id    uuid        not null,   -- motion_clips.id 참조(느슨한 참조 허용)
  created_at timestamptz not null default now(),
  primary key (owner_id, clip_id)
);

alter table clip_favorites enable row level security;

create policy "own favorites: select" on clip_favorites
  for select using (owner_id = auth.uid());
create policy "own favorites: insert" on clip_favorites
  for insert with check (owner_id = auth.uid());
create policy "own favorites: delete" on clip_favorites
  for delete using (owner_id = auth.uid());
```
- CRUD는 **Supabase 직결(RLS)로 충분** — 별도 terra-api 엔드포인트 불필요.
- 앱은 로컬 즐겨찾기를 이 테이블과 동기화(첫 도입 시 로컬 → 클라우드 업로드, 이후 양방향).

### 요청 B — 즐겨찾기 클립 R2 보존 (중요)
모션 클립에 **R2 보존정책(오래된 클립 만료삭제)이 있다면**, 사용자가 즐겨찾기한 클립은 **삭제 대상에서 제외**해야 한다. 그렇지 않으면:
- 사용자가 아껴둔 영상이 서버에서 지워지고,
- 향후 클라우드 재동기화(기기 변경 등) 시 영상을 되살릴 수 없다.

**제안:** 보존 정리 배치가 `clip_favorites`에 존재하는 `clip_id`(또는 `motion_clips`에 `is_favorited`/`retain_until` 플래그)를 확인해 스킵. 스키마/배치 구현은 백엔드 재량.

### 앱 이관 방식
클라우드 즐겨찾기가 준비되면 앱은 로컬 Hive 저장소를 이 테이블과 동기화하도록 확장한다(로컬 mp4 캐시는 오프라인 재생용으로 유지). 현재 로컬 전용 구현은 그 전까지의 stopgap.

---

## 부록 — 별도 핸드오프 (참고: API 개발자 대상 아님)

- 🔗 **녹화 시 워터마크 각인** (캠/펌웨어 개발자): 앱은 재생 화면에만 워터마크를 오버레이한다(저장 파일엔 없음). 원본 파일에 각인하려면 녹화/인코딩 파이프라인에서 처리 필요. (앱에서 ffmpeg 재인코딩은 용량·성능 부담으로 채택 안 함.)

---

## 참고 자료
- 앱 구현 계획서: `docs/plans/2026-07-08-camera-detail-ux.md`
- terra-api 계약(현행): `~/Downloads/APP_INTEGRATION.md` (엔드포인트 표)
- 스키마: `docs/supabase-schema.md`
