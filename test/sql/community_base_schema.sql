-- 격리 검증용 기반(운영 아님). supabase/postgres 이미지의 auth.users에는 GoTrue가
-- 나중에 붙이는 deleted_at이 없어서 여기서 붙인다(운영에는 있다).
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  avatar_url text
);
