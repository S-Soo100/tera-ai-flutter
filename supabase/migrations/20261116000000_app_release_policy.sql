-- 앱 업데이트 안내 기준(2026-11-16, 계획 docs/superpowers/plans/2026-11-16-store-update-and-push-route.md §2.1).
-- 플랫폼마다 한 줄. 앱은 로그인 전에도 읽는다(강제 업데이트는 로그인 화면에서도 걸려야 한다).
-- 비밀 정보가 없어 anon 읽기를 연다. 쓰기 정책·권한은 두지 않는다 — 운영자가 SQL 편집기로만 바꾼다.
-- 값 바꾸는 순서·주의는 docs/ops/app-update-policy.md.
--
-- min_build    : 설치된 빌드 번호가 이보다 작으면 강제(업데이트 화면만 보인다).
-- latest_build : 이보다 작으면 권장(확인 창, [나중에]로 그 빌드는 다시 안 뜬다).
-- latest_version : 표시용("0.181.0"). 비면 버전 없이 안내한다.
-- store_url    : null·빈 값이면 그 플랫폼은 안내하지 않는다.
-- 시드는 0 — 적용해도 아무에게도 안 뜬다.

CREATE TABLE public.app_release_policy (
  platform        TEXT PRIMARY KEY CHECK (platform IN ('android', 'ios')),
  min_build       INTEGER NOT NULL DEFAULT 0,
  latest_build    INTEGER NOT NULL DEFAULT 0,
  latest_version  TEXT NOT NULL DEFAULT '',
  store_url       TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (min_build >= 0 AND min_build <= latest_build)
);

ALTER TABLE public.app_release_policy ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_release_policy_select_all ON public.app_release_policy
  FOR SELECT TO anon, authenticated
  USING (true);

REVOKE ALL ON TABLE public.app_release_policy FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.app_release_policy TO anon, authenticated;

INSERT INTO public.app_release_policy
  (platform, min_build, latest_build, latest_version, store_url)
VALUES
  ('android', 0, 0, '', 'https://play.google.com/store/apps/details?id=com.vivanaut.app'),
  ('ios', 0, 0, '', NULL);
