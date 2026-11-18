-- 탈퇴자 커뮤니티 숨김 초안(20261117_community_hide_deleted_authors.sql) 검증.
-- 사용자: A=일반 작성자, D=탈퇴할 작성자, V=보는 사람, M=관리자. 전부 ROLLBACK된다.
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.community_posts, public.community_comments, public.community_likes,
  public.community_reports TO authenticated;

INSERT INTO auth.users(id) VALUES
  ('00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-00000000000d'),
  ('00000000-0000-0000-0000-00000000000e'),
  ('00000000-0000-0000-0000-00000000000f');
INSERT INTO public.user_profiles(id, is_admin) VALUES
  ('00000000-0000-0000-0000-00000000000a', false),
  ('00000000-0000-0000-0000-00000000000d', false),
  ('00000000-0000-0000-0000-00000000000e', false),
  ('00000000-0000-0000-0000-00000000000f', true);
-- A 글 1, D 글 1
INSERT INTO public.community_posts(id, author_id, video_path) VALUES
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', 'a.mp4'),
  ('10000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000d', 'd.mp4');
-- A 글에 A·D 댓글, D 글에 V 댓글
INSERT INTO public.community_comments(post_id, author_id, body) VALUES
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', 'a'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000d', 'd'),
  ('10000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000e', 'v');
-- A 글에 A·D·V 좋아요
INSERT INTO public.community_likes(post_id, user_id) VALUES
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000d'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');
-- V가 D 글 신고
INSERT INTO public.community_reports(reporter_id, target_kind, target_id, reason) VALUES
  ('00000000-0000-0000-0000-00000000000e', 'post', '10000000-0000-0000-0000-00000000000d', 'spam');

-- 앱의 피드 쿼리와 같은 모양: posts + 임베드 count
CREATE FUNCTION pg_temp.feed() RETURNS TABLE(post uuid, likes bigint, comments bigint)
LANGUAGE sql AS $$
  SELECT p.id,
         (SELECT count(*) FROM public.community_likes l WHERE l.post_id = p.id),
         (SELECT count(*) FROM public.community_comments c WHERE c.post_id = p.id)
  FROM public.community_posts p ORDER BY p.id
$$;
CREATE FUNCTION pg_temp.check(ok boolean, what text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT ok THEN RAISE EXCEPTION 'FAIL: %', what; END IF;
  RAISE NOTICE 'ok: %', what;
END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

-- 1) D가 탈퇴하기 전: 전부 보인다(일반 글 영향 없음의 기준선)
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000e';
SELECT pg_temp.check((SELECT count(*) FROM pg_temp.feed()) = 2, '탈퇴 전 글 2개');
SELECT pg_temp.check((SELECT likes FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 3, '탈퇴 전 A 글 좋아요 3');
SELECT pg_temp.check((SELECT comments FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 2, '탈퇴 전 A 글 댓글 2');
RESET ROLE;

-- 2) D 소프트 삭제(서버 POST /account/delete와 같은 효과)
UPDATE auth.users SET deleted_at = now() WHERE id = '00000000-0000-0000-0000-00000000000d';

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000e';
SELECT pg_temp.check((SELECT array_agg(post) FROM pg_temp.feed()) = ARRAY['10000000-0000-0000-0000-00000000000a'::uuid], '탈퇴 후 피드에 A 글만');
SELECT pg_temp.check((SELECT count(*) FROM public.community_posts WHERE id = '10000000-0000-0000-0000-00000000000d') = 0, 'D 글 단건 조회도 0');
SELECT pg_temp.check((SELECT count(*) FROM public.community_posts WHERE author_id = '00000000-0000-0000-0000-00000000000d') = 0, 'D 작성자 화면 글 0');
SELECT pg_temp.check((SELECT comments FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 1, 'A 글 댓글 수 2→1(D 댓글 제외)');
SELECT pg_temp.check((SELECT likes FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 2, 'A 글 좋아요 수 3→2(D 좋아요 제외)');
SELECT pg_temp.check((SELECT count(*) FROM public.community_comments WHERE author_id = '00000000-0000-0000-0000-00000000000d') = 0, 'D 댓글 0');
-- 숨긴 D 글에 V가 단 댓글은 행은 보이지만 글이 없어 앱에 나올 경로가 없다
SELECT pg_temp.check((SELECT count(*) FROM public.community_comments WHERE post_id = '10000000-0000-0000-0000-00000000000d') = 1, '숨긴 글에 단 V 댓글 행은 남음(글이 없어 앱 경로 없음)');
-- 신고: V는 자기 신고 행을 계속 본다(대상 글만 안 보임)
SELECT pg_temp.check((SELECT count(*) FROM public.community_reports) = 1, 'V 자기 신고 1건 유지');
-- 일반 쓰기는 그대로
INSERT INTO public.community_comments(post_id, author_id, body)
  VALUES ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e', 'v2');
SELECT pg_temp.check((SELECT comments FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 2, 'V 새 댓글 작성·조회 정상');
DELETE FROM public.community_likes
  WHERE post_id = '10000000-0000-0000-0000-00000000000a' AND user_id = '00000000-0000-0000-0000-00000000000e';
SELECT pg_temp.check((SELECT likes FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 1, 'V 좋아요 취소 반영(2→1)');
INSERT INTO public.community_likes(post_id, user_id)
  VALUES ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e');
SELECT pg_temp.check((SELECT likes FROM pg_temp.feed() WHERE post = '10000000-0000-0000-0000-00000000000a') = 2, 'V 좋아요 다시 누름 반영(1→2)');
RESET ROLE;

-- 3) 관리자도 예외 없음
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000f';
SELECT pg_temp.check((SELECT count(*) FROM public.community_posts) = 1, '관리자에게도 D 글 숨김');
SELECT pg_temp.check((SELECT count(*) FROM public.community_reports) = 1, '관리자는 신고 행은 봄');
RESET ROLE;

-- 4) 함수 권한·경계
SELECT pg_temp.check(NOT has_function_privilege('anon', 'public.community_author_active(uuid)', 'EXECUTE'), 'anon 실행 불가');
SELECT pg_temp.check(has_function_privilege('authenticated', 'public.community_author_active(uuid)', 'EXECUTE'), 'authenticated 실행 가능');
SELECT pg_temp.check(public.community_author_active('99999999-0000-0000-0000-000000000000'), '없는 uid는 true(하드 삭제 뒤엔 CASCADE)');
SELECT pg_temp.check((SELECT prosecdef FROM pg_proc WHERE oid = 'public.community_author_active(uuid)'::regprocedure), 'SECURITY DEFINER');

-- 5) 되돌리면 다시 보인다(초안 머리말의 rollback 그대로)
DROP POLICY posts_select ON public.community_posts;
CREATE POLICY posts_select ON public.community_posts FOR SELECT TO authenticated USING (true);
DROP POLICY comments_select ON public.community_comments;
CREATE POLICY comments_select ON public.community_comments FOR SELECT TO authenticated USING (true);
DROP POLICY likes_select ON public.community_likes;
CREATE POLICY likes_select ON public.community_likes FOR SELECT TO authenticated USING (true);
DROP FUNCTION public.community_author_active(uuid);
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000e';
SELECT pg_temp.check((SELECT count(*) FROM pg_temp.feed()) = 2, '되돌리기 후 D 글 다시 보임');
RESET ROLE;
