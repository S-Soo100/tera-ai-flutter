-- 검토용 초안 (운영 DB 미적용, 2026-09-16). 마이페이지 재설계 C4:
-- 알림 설정(Figma PushAlarm 1142:9613) 종류별 on/off + 수신 동의.
-- 앱은 2026-09-16 현재 이 값을 기기 로컬(Hive)에만 저장한다. 이 테이블이 생기고
-- dispatch-push가 발송 전에 조회하면 앱 저장처를 서버로 바꾼다.

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  highlight            boolean NOT NULL DEFAULT true,   -- 하이라이트 영상
  community_comment    boolean NOT NULL DEFAULT true,   -- 커뮤니티 댓글
  community_like       boolean NOT NULL DEFAULT true,   -- 커뮤니티 좋아요
  news                 boolean NOT NULL DEFAULT true,   -- 비바나트 소식(운영 이벤트)
  marketing            boolean NOT NULL DEFAULT false,  -- 마케팅 수신 동의
  marketing_agreed_at  timestamptz,                      -- 광고성 정보 수신 동의 시각(표기 필수)
  updated_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own prefs select" ON public.notification_preferences
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "own prefs upsert" ON public.notification_preferences
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own prefs update" ON public.notification_preferences
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- dispatch-push(서버): 발송 전 user_id의 행을 읽어 종류별 false면 건너뛴다.
-- 행이 없으면 기본값(마케팅만 false)으로 본다.
