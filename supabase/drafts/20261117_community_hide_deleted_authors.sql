-- 운영 적용됨(2026-11-17, 백승수가 SQL Editor에서 직접 실행 — migrations 이력 없음).
-- 이 파일은 검토용 원본이라 ROLLBACK으로 끝난다. 다시 실행해도 바뀌는 것 없음(멱등).
--
-- 탈퇴(소프트 삭제) 사용자의 커뮤니티 글·댓글·좋아요를 다른 사용자 조회에서 숨긴다.
-- 근거: terra-server 회신 BACKEND_REPLY_DELETE_ACCOUNT_2026-11-17 §3 "남는 것"
--   (탈퇴는 auth.users.deleted_at만 찍고 행은 남김 → 커뮤니티는 앱이 RLS로 처리),
--   사용자 결정 2026-11-17 "③ DB에서 숨기기",
--   docs/references/2026-11-17-delete-account-reply-accept.md §2(a).
--
-- 운영 확인(2026-11-17, 읽기만):
--   - posts_select / comments_select / likes_select 는 모두 `USING (true)`, TO authenticated
--     (마이그레이션 2026-08-31_community_clip_feed.sql 과 같음)
--   - 소프트 삭제 계정 31개, 그들의 글 0 · 댓글 0 · 좋아요 0 → 적용 즉시 사라지는 행 없음
--
-- 하지 않는 것:
--   - 관리자 예외 없음: 앱에 신고 검토 화면이 없다(community_reports는 insert만).
--     관리자도 탈퇴자 글을 못 본다 — 검토는 SQL 콘솔(service role)로.
--   - 행 삭제 없음: 실제 삭제는 서버 30일 하드 삭제 작업 몫.
--   - public_profiles 뷰·community-media 버킷·알림 트리거는 손대지 않음(수용 문서 참고).
--
-- 되돌리기(rollback):
--   DROP POLICY posts_select ON public.community_posts;
--   CREATE POLICY posts_select ON public.community_posts FOR SELECT TO authenticated USING (true);
--   DROP POLICY comments_select ON public.community_comments;
--   CREATE POLICY comments_select ON public.community_comments FOR SELECT TO authenticated USING (true);
--   DROP POLICY likes_select ON public.community_likes;
--   CREATE POLICY likes_select ON public.community_likes FOR SELECT TO authenticated USING (true);
--   DROP FUNCTION public.community_author_active(uuid);
BEGIN;

-- 작성자가 탈퇴하지 않았는가. auth.users는 authenticated가 못 읽으므로
-- SECURITY DEFINER로 deleted_at만 본다. 없는 uid(하드 삭제 뒤)는 true —
-- 그 경우 글은 FK CASCADE로 이미 사라진다.
CREATE OR REPLACE FUNCTION public.community_author_active(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_user_id AND u.deleted_at IS NOT NULL
  )
$$;
REVOKE EXECUTE ON FUNCTION public.community_author_active(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.community_author_active(uuid) TO authenticated;

DROP POLICY IF EXISTS posts_select ON public.community_posts;
CREATE POLICY posts_select ON public.community_posts
  FOR SELECT TO authenticated
  USING (public.community_author_active(author_id));

-- 앱의 댓글 수(`community_comments(count)` 임베드)도 이 정책을 따라 같이 줄어든다.
DROP POLICY IF EXISTS comments_select ON public.community_comments;
CREATE POLICY comments_select ON public.community_comments
  FOR SELECT TO authenticated
  USING (public.community_author_active(author_id));

-- 좋아요 수(`community_likes(count)` 임베드)에서 탈퇴자 좋아요를 뺀다 — 30일 뒤
-- 하드 삭제 때 숫자가 갑자기 줄지 않게 지금부터 맞춘다.
DROP POLICY IF EXISTS likes_select ON public.community_likes;
CREATE POLICY likes_select ON public.community_likes
  FOR SELECT TO authenticated
  USING (public.community_author_active(user_id));

-- 검토용이라 되돌린다. 운영 적용 시 승인된 SQL에서만 COMMIT으로 바꾼다.
ROLLBACK;
