-- 검토용 초안 (운영 DB 미적용, 2026-09-16). 마이페이지 재설계 C2:
-- 커뮤니티 프로필 "커뮤니티에 내 사육 경험 비공개"(Figma Commu_Profile 1142:9369).
-- 앱은 user_profiles 응답에 experience_hidden 키가 있을 때만 값을 읽고 저장한다
-- (UserProfile.experienceHiddenSupported) — 적용 전에는 체크가 저장되지 않는다.
--
-- public_profiles 뷰가 experience를 노출한다면 hidden이면 NULL로 가리는 것도
-- 같이 검토(현재 뷰는 3컬럼: id, display_name, avatar_url — 노출 안 함).

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS experience_hidden boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.user_profiles.experience_hidden IS
  '커뮤니티에 사육 경험 비공개(마이페이지 > 커뮤니티 프로필, 2026-09-16)';
