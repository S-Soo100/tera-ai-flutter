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
| 3 | **밤새 하이라이트("어젯밤 리포트") API** | (신규 화면, 임시조치 없음) | `GET /clips/highlights` — VLM 판정 하이라이트 목록(서버단 오탐 필터) + 확인→GT | 중간 |

> ℹ️ **요청 1(썸네일)은 3곳 공용**: 앱 상세 그리드 + 관리자 라벨링 웹(label.tera-ai.uk) 큐 + 요청 3 하이라이트 카드가 **모두 같은 `GET /clips/{id}/thumbnail/url`을 재사용**한다. 중복 구현 없이 한 엔드포인트로.

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

## 요청 3 — 밤새 하이라이트("어젯밤 리포트") API

### 배경
mac-mini nightly worker(별도 운영)가 **30분마다 밤(20~06시 KST) 모션 clip을 VLM(Claude Sonnet v4.0)로 샘플 분석**해, 케어행동(hand_feeding·drinking 등) 하이라이트를 `behavior_logs`(`source='vlm'`)에 자동 기록하고 `camera_clips`로 미러한다. **clip_id = motion_clips.id 재사용 → id 정합**(앱 clip 과 그대로 연결). 이걸 앱 "어젯밤 리포트" 화면에서 소비한다. (2026-07-08 auto-register 가동, 첫날밤 hand_feeding 자동 포착 실측.)

### ⚠️ 신뢰도 전제 (설계 핵심 — 실측 기반)
VLM 은 **오탐이 많다**. 실측: 특정 개체(화이트 많은 트라이익스트림 할리퀸 모프)의 흰 체색을 밤 IR 에서 허물로 오인해 **shedding 판정이 100% 오탐**(누적 30+건 전부 육안 moving). 그래서:
- 앱은 하이라이트를 **"AI 추정"으로만** 표시(단정 금지).
- **서버단 필터**: 개체 프로파일 상시오탐(현재: 이 개체 `shedding`)과 저 confidence 는 **하이라이트에서 제외해 내려준다**(앱은 받은 것만 표시).
- 사용자 확인(👍/👎/정정)이 GT 가 되어 정확도를 높이는 **HITL 루프**.

### 요청 계약
```
GET /clips/highlights?since=<ISO8601>&limit=<n>
Authorization: Bearer <JWT>          # 본인 카메라 clip 만(기존 RLS)
```
**200 응답:**
```json
{
  "highlights": [
    {
      "clip_id": "e679f8ad-9011-4bc2-a489-1bb93c54ead8",
      "started_at": "2026-07-07T14:07:00+00:00",
      "thumbnail_key": "terra-clips/clips/.../....jpg",
      "vlm_action": "drinking",
      "confidence": 0.62,
      "care_level": "care",        // "care"(hand_feeding·drinking·탈피 = 건강) | "enrichment"(놀이·활동 = 복지)
      "user_confirmed": null        // null=미확인 | true | false | 정정된 action 문자열
    }
  ]
}
```

### 필터/집계 규칙
- `behavior_logs` where `source='vlm'` AND `action NOT IN (서버 억제셋)` AND `confidence >= 임계`.
- **억제셋은 개체 프로파일 기반**(현재: 이 개체 `shedding`). 하드코딩 말고 설정/테이블 권장 — 실제 탈피 영상이 확보되면 해제 가능해야.
- clip 메타(`started_at`·`thumbnail_key`)는 `motion_clips` join. 썸네일은 요청 1 엔드포인트 재사용.

### 사용자 확인 → GT (HITL)
- 앱 👍/👎/정정 → `POST /clips/{id}/labels`(**기존 라벨 경로, `behavior_labels` 테이블 — 관리자 라벨웹과 동일 계약**).
- `user_confirmed` 는 해당 clip 에 본인 `behavior_labels` 존재 여부/값으로 계산.

### 앱 이관
- 홈에 "🦎 어젯밤 리포트 · 하이라이트 N" 배지 → 이 API 로 하이라이트 카드(썸네일=요청1) + 확인 루프.
- 활동량 그래프(몇 시에 활발)는 **별개**: `motion_clips` 시간대 집계로 앱/서버에서 산출(VLM 0비용, 항상 정확). 하이라이트(행동 종류)와 2층 구성.

---

## 부록 — 별도 핸드오프 (참고: API 개발자 대상 아님)

- 🔗 **녹화 시 워터마크 각인** (캠/펌웨어 개발자): 앱은 재생 화면에만 워터마크를 오버레이한다(저장 파일엔 없음). 원본 파일에 각인하려면 녹화/인코딩 파이프라인에서 처리 필요. (앱에서 ffmpeg 재인코딩은 용량·성능 부담으로 채택 안 함.)

---

## 참고 자료
- 앱 구현 계획서: `docs/plans/2026-07-08-camera-detail-ux.md`
- terra-api 계약(현행): `~/Downloads/APP_INTEGRATION.md` (엔드포인트 표)
- 스키마: `docs/supabase-schema.md`
