# 백엔드 핸드오프 — 커뮤니티 탭 리뉴얼: 크레캠 클립 공유 피드 (2026-08-29)

> **대상**: terra-server 담당자
> **성격**: 이번 문서는 요청서가 아니라 **사전 공유 + 확인 요청**입니다. terra-server 코드·API·펌웨어 변경은 **없습니다**. 신규 테이블·버킷 마이그레이션은 **앱 팀이 직접 실행**합니다(같은 Supabase 프로젝트를 공유하므로 충돌 여부만 확인받으려 합니다).
> **배경**: 커뮤니티 탭이 현재 껍데기(카테고리 칩 + "준비 중")입니다. 텍스트 게시판(QnA/자유) 대신 **크레캠 모션 클립을 공유하는 영상 피드**(인스타그램 스타일)로 리뉴얼합니다.
> **근거**: 앱 코드 정적 분석 + `docs/supabase-schema.md` + `motion_clips` RLS·terra-api 클립 URL 발급 계약(`GET /clips/{id}/url`)
> 관련 문서: 앱 기획서 `docs/prd-vivnanaut-app.md` §4.5(이번 리뉴얼로 갱신 예정)

---

## 0. 요약 (TL;DR)

| # | 항목 | 실행 주체 | 백엔드에 바라는 것 |
|---|---|---|---|
| 1 | `community_*` 테이블 6종 + `public_profiles` 뷰 + `community-media` Storage 버킷 신설 | **앱 팀** | 네임스페이스 충돌·운영상 이슈 없는지 확인 (§5-①) |
| 2 | `user_profiles.is_admin` 컬럼 추가 (운영자 공지·신고 처리용) | **앱 팀** | FYI — 메인 앱 소유 테이블 |
| 3 | 클립 공유 = **스냅샷 복사** (terra-api presigned GET으로 다운로드 → Supabase Storage 업로드) | 앱 | R2 egress 관점에서 문제 없는지 확인 (§5-②) |
| 4 | terra-server API·`motion_clips`·RLS **변경 없음** | — | 없음 |

---

## 1. 신규 기획 요약

### 컨셉

커뮤니티 탭 = **즐겨찾기한 크레캠 클립을 공유하는 영상 피드**.

- 유저는 크레캠에서 북마크(즐겨찾기, `clip_favorites`)한 모션 클립에 캡션을 붙여 게시한다
- 다른 유저는 피드에서 영상을 보고 **좋아요·댓글**로 소통한다
- 사육 위키(백색목록 검색/종 정보/모프 계산기)는 기존 결정대로 커뮤니티 하위 진입 카드로 유지
- 텍스트 게시판(공지/QnA/자유) 중 QnA·자유는 폐기 — 캡션+댓글이 그 역할을 흡수. 공지는 **운영자 전용 배너**로 존치

### 유저 플로우

```
크레캠 클립 즐겨찾기 → [커뮤니티 탭 FAB 또는 클립 상세 "공유"]
  → 즐겨찾기 클립 선택 → 찍힌 크레 자동 연결(카메라→사육장→개체 1:1, 변경 가능)
  → 캡션 작성 → 게시(영상·썸네일·크레 사진 복사 업로드)
  → 피드 노출 (클립 + 크레 이름·종·모프·사진) → 타 유저 좋아요/댓글
```

### 핵심 설계 결정: 왜 "스냅샷 복사"인가

원본 참조 방식(게시물이 `motion_clips.id`만 들고 재생 시 원본을 스트리밍)은 현행 계약에서 불가능합니다:

| 제약 | 현행 |
|---|---|
| `motion_clips` SELECT | RLS `auth.uid() = owner_id` — **본인 것만** |
| 재생·썸네일 URL | terra-api `GET /clips/{id}/url` — **본인 토큰으로만** presigned 발급, TTL 1h |

이걸 원본 참조로 풀려면 terra-api에 공유 계약(공유 플래그 + 공개 발급 엔드포인트)을 추가해야 하고, 백엔드 개발 대기가 생깁니다. 대신:

> **글 작성 시 앱이 presigned URL로 영상+썸네일을 내려받아 Supabase Storage `community-media` 버킷에 복사**하고, 게시물은 복사본을 참조한다.

- terra-server **무변경**. `motion_clips` 보존기한·삭제 정책과도 무관해짐(원본이 지워져도 게시물 유지)
- 비용: 저장 중복(모션 클립은 수초~수십초 분량이라 건당 수 MB) + 게시 시 업로드 대기(진행률 표시)

---

## 2. 단계 계획 (스키마는 전부 이번 마이그레이션 한 번에)

| 단계 | 범위 | 비고 |
|---|---|---|
| **1차 (MVP)** | 피드(최신순 페이지네이션) · 글쓰기(즐겨찾기 클립 선택→캡션→복사 업로드) · 전체화면 재생 · 좋아요 · 댓글(바텀시트) · 내 글/댓글 삭제 | 기존 클립 플레이어 재사용 |
| **2차** | 운영자 공지 배너(`community_notices`) · **신고/차단/문의처** · 유저별 글 모아보기 · 피드 내 자동재생 | 신고/차단은 **Apple 심사 가이드라인 1.2**(UGC 앱 필수 요건)라 스토어 제출 전 필수 |

2차 항목까지 포함해 **테이블·정책은 이번 마이그레이션에 전부 만들어 둡니다** (공유 프로덕션 DB를 두 번 건드리지 않기 위해). 화면만 단계를 나눕니다.

---

## 3. 마이그레이션 계획 (앱 팀 실행 — DDL 전문)

네이밍은 `community_` 접두사로 통일해 terra-server 테이블(`enclosures`/`devices`/`cameras`/`commands`/`telemetry*`/`alerts`/`motion_clips`)과 겹치지 않게 합니다.

### 3.1 컬럼 추가 — 운영자 플래그

```sql
-- 메인 앱 소유 테이블. 공지 작성·신고 처리 권한의 근거.
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;
```

### 3.2 테이블 6종

```sql
-- 1) 게시물 — 영상은 community-media 버킷의 복사본을 참조
CREATE TABLE community_posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caption        TEXT,
  video_path     TEXT NOT NULL,          -- community-media 내 경로 {user_id}/posts/{post_id}.mp4
  thumbnail_path TEXT,                   -- 〃 .jpg
  source_clip_id UUID,                   -- 출처 motion_clips.id (참고용. FK 없음 — 원본 삭제와 무관)
  duration_sec   DOUBLE PRECISION,
  action         TEXT,                   -- 행동 분류 라벨 스냅샷 (behavior_logs 대표 라벨)
  -- 찍힌 크레(개체) 스냅샷 — 카메라→사육장→개체 1:1로 게시 시 자동 유도.
  -- pets RLS·pet-media 버킷이 본인 한정이라 참조 대신 굳혀 담는다. 미연결 카메라면 전부 NULL.
  -- 앱 표기: "n살 릴리화이트 여아" (sex: female=여아 / male=남아 / unknown=아가)
  pet_name       TEXT,
  pet_species    TEXT,                   -- 종 표시명 스냅샷 (표기 미사용 — 필터·다종 대비)
  pet_morph      TEXT,
  pet_sex        TEXT,                   -- pets.sex 스냅샷 ('female'/'male'/'unknown')
  pet_birth_date DATE,                   -- pets.birth_date 스냅샷 — 나이 표기용
  pet_photo_path TEXT,                   -- community-media 복사본 {user_id}/posts/{post_id}_pet.jpg
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX community_posts_created_idx ON community_posts (created_at DESC);
CREATE INDEX community_posts_author_idx  ON community_posts (author_id, created_at DESC);

-- 2) 댓글
CREATE TABLE community_comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  author_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX community_comments_post_idx ON community_comments (post_id, created_at);

-- 3) 좋아요
CREATE TABLE community_likes (
  post_id    UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

-- 4) 운영자 공지 (2차 화면 — 테이블은 지금)
CREATE TABLE community_notices (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  UUID NOT NULL REFERENCES auth.users(id),
  title      TEXT NOT NULL,
  body       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5) 신고 (Apple 1.2 — 2차 화면, 테이블은 지금)
CREATE TABLE community_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_kind TEXT NOT NULL CHECK (target_kind IN ('post', 'comment')),
  target_id   UUID NOT NULL,
  reason      TEXT NOT NULL,
  detail      TEXT,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'dismissed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX community_reports_status_idx ON community_reports (status, created_at DESC);

-- 6) 차단 (Apple 1.2 — 피드에서 차단 유저 글 숨김)
CREATE TABLE community_blocks (
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);
```

### 3.3 RLS

```sql
ALTER TABLE community_posts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_likes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_notices  ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_reports  ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_blocks   ENABLE ROW LEVEL SECURITY;

-- 운영자 판정 헬퍼 (정책 안에서 반복되는 EXISTS 절 축약)
CREATE OR REPLACE FUNCTION community_is_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT COALESCE((SELECT is_admin FROM user_profiles WHERE id = auth.uid()), false) $$;

-- 게시물: 읽기 = 로그인 유저 전체 / 쓰기 = 본인 / 삭제 = 본인 또는 운영자(신고 처리)
CREATE POLICY posts_select ON community_posts FOR SELECT TO authenticated USING (true);
CREATE POLICY posts_insert ON community_posts FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());
CREATE POLICY posts_update ON community_posts FOR UPDATE TO authenticated
  USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());  -- 캡션 수정
CREATE POLICY posts_delete ON community_posts FOR DELETE TO authenticated
  USING (author_id = auth.uid() OR community_is_admin());

-- 댓글: 게시물과 같은 규칙
CREATE POLICY comments_select ON community_comments FOR SELECT TO authenticated USING (true);
CREATE POLICY comments_insert ON community_comments FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());
CREATE POLICY comments_delete ON community_comments FOR DELETE TO authenticated
  USING (author_id = auth.uid() OR community_is_admin());

-- 좋아요: 본인 행만
CREATE POLICY likes_select ON community_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY likes_insert ON community_likes FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY likes_delete ON community_likes FOR DELETE TO authenticated USING (user_id = auth.uid());

-- 공지: 읽기 전체 / 쓰기·수정·삭제 = 운영자만
CREATE POLICY notices_select ON community_notices FOR SELECT TO authenticated USING (true);
CREATE POLICY notices_write  ON community_notices FOR ALL TO authenticated
  USING (community_is_admin()) WITH CHECK (community_is_admin() AND author_id = auth.uid());

-- 신고: 접수 = 본인 / 열람 = 본인 신고건 또는 운영자 / 상태 변경 = 운영자
CREATE POLICY reports_insert ON community_reports FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());
CREATE POLICY reports_select ON community_reports FOR SELECT TO authenticated
  USING (reporter_id = auth.uid() OR community_is_admin());
CREATE POLICY reports_update ON community_reports FOR UPDATE TO authenticated
  USING (community_is_admin()) WITH CHECK (community_is_admin());

-- 차단: 본인 행만
CREATE POLICY blocks_all ON community_blocks FOR ALL TO authenticated
  USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());
```

> 차단 유저 글 숨김은 1차에서 **앱 필터**(내 차단 목록을 받아 클라에서 제외)로 갑니다. RLS로 피드 자체에서 빼는 방식(`posts_select`에 `NOT EXISTS(... community_blocks ...)`)은 피드 쿼리 전수에 서브쿼리가 붙어 2차에서 성능 보고 판단.

### 3.4 작성자 표시용 뷰

`user_profiles`의 RLS가 `auth.uid() = id`(본인만)라 타 유저의 이름·아바타를 읽을 수 없습니다. 정책을 넓히는 대신 **노출 컬럼을 3개로 못박은 뷰**를 만듭니다:

```sql
-- postgres 소유 뷰(security_invoker=off) → 기반 테이블 RLS 우회. 노출은 이 3컬럼이 전부.
CREATE VIEW public_profiles AS
  SELECT id, display_name, avatar_url FROM user_profiles;
GRANT SELECT ON public_profiles TO authenticated;
```

> Supabase advisor가 SECURITY DEFINER 뷰를 lint로 띄울 수 있습니다 — 의도된 설계입니다(민감 컬럼 없음: 이름·아바타 URL뿐).

### 3.5 Storage 버킷

```sql
INSERT INTO storage.buckets (id, name, public) VALUES ('community-media', 'community-media', false);

-- 읽기 = 로그인 유저 전체 (피드 재생) / 쓰기·삭제 = 본인 폴더만
CREATE POLICY "community-media read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'community-media');
CREATE POLICY "community-media insert own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'community-media' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "community-media delete own" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'community-media' AND (storage.foldername(name))[1] = auth.uid()::text);
```

경로 규약: `{user_id}/posts/{post_id}.mp4`(영상) + `{user_id}/posts/{post_id}.jpg`(썸네일) + `{user_id}/posts/{post_id}_pet.jpg`(크레 사진 스냅샷)

### 3.6 카운트 조회

좋아요·댓글 수는 트리거 없이 PostgREST embedded count로 읽습니다 (`select=*,community_likes(count),community_comments(count)`). 규모가 커져 count 집계가 느려지면 그때 카운터 컬럼+트리거를 검토합니다.

---

## 4. terra-server 영향

**코드·API·스키마 변경 없음.** 트래픽 관점만:

- 글 작성 1건당 terra-api `GET /clips/{id}/url` + `GET /clips/{id}/thumbnail/url` 각 1회 → presigned GET 다운로드(영상 수 MB + 썸네일). 기존 앱 내 재생과 같은 경로·같은 규모이며, 호출 주체도 클립 소유자 본인입니다.
- 이후 피드 재생 트래픽은 전부 Supabase Storage(복사본)로 빠집니다 — R2에는 안 갑니다.

---

## 5. 확인 요청 (회신 주시면 마이그레이션 실행)

| # | 질문 | 배경 |
|---|---|---|
| ① | `community_*` 테이블 6종 + `public_profiles` 뷰 + `community-media` 버킷 — **이름 충돌이나 운영상 우려 없나요?** terra-server 쪽 마이그레이션 도구가 public 스키마 전체를 관리한다면 특히. | 같은 Supabase 프로젝트 공유 |
| ② | 글 작성 시 클립을 presigned GET으로 내려받아 복사하는 방식 — **R2 egress 비용/정책상 괜찮나요?** | §1 스냅샷 복사 |
| ③ | `motion_clips`(R2 원본)에 **보존기한/자동 삭제 정책이 있나요?** 복사 방식이라 게시물엔 영향 없지만, "즐겨찾기 클립 선택" 화면에서 만료 클립 처리를 알아야 합니다. | 글쓰기 플로우 |
| ④ | 프로필 아바타(`user_profiles.avatar_url`)가 가리키는 버킷이 **타 유저에게도 읽히나요?** 안 되면 앱은 이니셜 폴백으로 시작하고 아바타 버킷 정책은 후속으로. | 피드 작성자 표시 |

---

## 6. 진행 순서

1. 이 문서 회신 (§5 4건)
2. 앱 팀이 마이그레이션 실행 (§3 전문)
3. 앱 1차(MVP) 구현 → 2차(공지·신고/차단·모아보기·자동재생)
4. 스토어 제출 전 신고/차단 필수 확인 (Apple 1.2)
