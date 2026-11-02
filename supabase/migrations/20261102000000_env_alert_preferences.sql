-- 계정 단위 푸시 수신 설정(v4 온습도 이탈 알림, 2026-11-02 D2). 행이 없으면 모두 켬.
-- 나중에 다른 주제를 옮길 때도 열을 더한다(env_ 접두어).
CREATE TABLE public.notification_preferences (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  env_temp   boolean NOT NULL DEFAULT true,
  env_humid  boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own prefs select" ON public.notification_preferences FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "own prefs insert" ON public.notification_preferences FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "own prefs update" ON public.notification_preferences FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
