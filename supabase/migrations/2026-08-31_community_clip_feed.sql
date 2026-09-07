-- 커뮤니티 클립 공유 피드 — 앱 팀 소유 객체 (2026-08-31 실행)
-- 출처: docs/backend-handoff-2026-08-29-community-clip-feed.md §3
-- 백엔드 회신: docs/backend-reply-2026-08-31-community-clip-feed.md (충돌 없음 확인)
-- 앱 팀 소유: community_posts/comments/likes/notices/reports/blocks,
--            public_profiles(뷰), community_is_admin(), community-media(버킷),
--            user_profiles.is_admin(컬럼)

-- ── §3.1 운영자 플래그 ─────────────────────────────────────────────
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

-- ── §3.2 테이블 6종 ───────────────────────────────────────────────
CREATE TABLE community_posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caption        TEXT,
  video_path     TEXT NOT NULL,
  thumbnail_path TEXT,
  source_clip_id UUID,
  duration_sec   DOUBLE PRECISION,
  action         TEXT,
  pet_name       TEXT,
  pet_species    TEXT,
  pet_morph      TEXT,
  pet_sex        TEXT,
  pet_birth_date DATE,
  pet_photo_path TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX community_posts_created_idx ON community_posts (created_at DESC);
CREATE INDEX community_posts_author_idx  ON community_posts (author_id, created_at DESC);

CREATE TABLE community_comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  author_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX community_comments_post_idx ON community_comments (post_id, created_at);

CREATE TABLE community_likes (
  post_id    UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE community_notices (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  UUID NOT NULL REFERENCES auth.users(id),
  title      TEXT NOT NULL,
  body       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

CREATE TABLE community_blocks (
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

-- ── §3.3 RLS ─────────────────────────────────────────────────────
ALTER TABLE community_posts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_likes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_notices  ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_reports  ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_blocks   ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION community_is_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT COALESCE((SELECT is_admin FROM user_profiles WHERE id = auth.uid()), false) $$;

CREATE POLICY posts_select ON community_posts FOR SELECT TO authenticated USING (true);
CREATE POLICY posts_insert ON community_posts FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());
CREATE POLICY posts_update ON community_posts FOR UPDATE TO authenticated
  USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
CREATE POLICY posts_delete ON community_posts FOR DELETE TO authenticated
  USING (author_id = auth.uid() OR community_is_admin());

CREATE POLICY comments_select ON community_comments FOR SELECT TO authenticated USING (true);
CREATE POLICY comments_insert ON community_comments FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());
CREATE POLICY comments_delete ON community_comments FOR DELETE TO authenticated
  USING (author_id = auth.uid() OR community_is_admin());

CREATE POLICY likes_select ON community_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY likes_insert ON community_likes FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY likes_delete ON community_likes FOR DELETE TO authenticated USING (user_id = auth.uid());

CREATE POLICY notices_select ON community_notices FOR SELECT TO authenticated USING (true);
CREATE POLICY notices_write  ON community_notices FOR ALL TO authenticated
  USING (community_is_admin()) WITH CHECK (community_is_admin() AND author_id = auth.uid());

CREATE POLICY reports_insert ON community_reports FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());
CREATE POLICY reports_select ON community_reports FOR SELECT TO authenticated
  USING (reporter_id = auth.uid() OR community_is_admin());
CREATE POLICY reports_update ON community_reports FOR UPDATE TO authenticated
  USING (community_is_admin()) WITH CHECK (community_is_admin());

CREATE POLICY blocks_all ON community_blocks FOR ALL TO authenticated
  USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());

-- ── §3.4 작성자 표시용 뷰 (SECURITY DEFINER — 의도적, 노출 3컬럼뿐) ──
CREATE VIEW public_profiles AS
  SELECT id, display_name, avatar_url FROM user_profiles;
GRANT SELECT ON public_profiles TO authenticated;

-- ── §3.5 Storage 버킷 ─────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public) VALUES ('community-media', 'community-media', false);

CREATE POLICY "community-media read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'community-media');
CREATE POLICY "community-media insert own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'community-media' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "community-media delete own" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'community-media' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ── 후속 (같은 날 2차 migration: community_is_admin_revoke_anon) ────
-- advisor 'anon_security_definer_function_executable' 대응 — authenticated RLS 전용 함수
REVOKE EXECUTE ON FUNCTION community_is_admin() FROM anon, public;
