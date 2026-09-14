-- Android FCM notification event store (2026-09-15).
-- All client-visible records are account-scoped. Producers insert events; the
-- event trigger creates exactly one in-app notification and one outbox entry.

CREATE TABLE public.push_devices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  installation_id UUID NOT NULL,
  fcm_token       TEXT NOT NULL,
  platform        TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version     TEXT,
  locale          TEXT,
  enabled         BOOLEAN NOT NULL DEFAULT true,
  last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, installation_id),
  UNIQUE (fcm_token)
);

CREATE TABLE public.app_notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind            TEXT NOT NULL,
  category        TEXT NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  route           TEXT NOT NULL,
  data            JSONB NOT NULL DEFAULT '{}'::jsonb
                    CHECK (jsonb_typeof(data) = 'object'),
  source          TEXT NOT NULL,
  source_event_id TEXT NOT NULL,
  dedupe_key      TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  read_at         TIMESTAMPTZ,
  UNIQUE (user_id, dedupe_key)
);
CREATE INDEX app_notifications_user_created_idx
  ON public.app_notifications (user_id, created_at DESC);

CREATE TABLE public.notification_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source          TEXT NOT NULL CHECK (source IN ('external', 'database')),
  source_event_id TEXT NOT NULL,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN (
                    'highlight.ready',
                    'device.action.started',
                    'device.action.ended',
                    'device.action.failed',
                    'community.comment',
                    'community.like_digest',
                    'notice.published',
                    'maintenance.water_tank',
                    'safety.alert',
                    'safety.recovered'
                  )),
  occurred_at     TIMESTAMPTZ NOT NULL,
  scheduled_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  payload         JSONB NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (source, source_event_id)
);
CREATE INDEX notification_events_user_created_idx
  ON public.notification_events (user_id, created_at DESC);

CREATE TABLE public.notification_outbox (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL REFERENCES public.app_notifications(id)
                    ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  scheduled_at    TIMESTAMPTZ NOT NULL,
  attempts        INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  locked_at       TIMESTAMPTZ,
  lock_token      UUID,
  sent_at         TIMESTAMPTZ,
  last_error      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (notification_id)
);
CREATE INDEX notification_outbox_dispatch_idx
  ON public.notification_outbox (status, scheduled_at)
  WHERE status = 'pending';

-- Delivery state is per installation. A retry can therefore claim only an
-- unfinished installation without duplicating a push to one already sent.
CREATE TABLE public.notification_deliveries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outbox_id       UUID NOT NULL REFERENCES public.notification_outbox(id)
                    ON DELETE CASCADE,
  push_device_id  UUID NOT NULL REFERENCES public.push_devices(id)
                    ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  scheduled_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  attempts        INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  locked_at       TIMESTAMPTZ,
  lock_token      UUID,
  sent_at         TIMESTAMPTZ,
  last_error      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT notification_deliveries_outbox_id_push_device_id_key
    UNIQUE (outbox_id, push_device_id)
);
CREATE INDEX notification_deliveries_dispatch_idx
  ON public.notification_deliveries (outbox_id, status, scheduled_at);

-- The notification center listens for read-state changes. Keep operational
-- tables off Realtime: only the client-visible notification records publish.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'app_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;
  END IF;
END;
$$;

ALTER TABLE public.push_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY push_devices_select_own ON public.push_devices
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY push_devices_insert_own ON public.push_devices
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY push_devices_update_own ON public.push_devices
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY push_devices_delete_own ON public.push_devices
  FOR DELETE TO authenticated USING (user_id = auth.uid());

CREATE POLICY app_notifications_select_own ON public.app_notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY app_notifications_update_own ON public.app_notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

REVOKE ALL ON TABLE public.push_devices, public.app_notifications,
  public.notification_events, public.notification_outbox, public.notification_deliveries
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.push_devices TO authenticated;
GRANT SELECT ON TABLE public.app_notifications TO authenticated;
GRANT UPDATE (read_at) ON TABLE public.app_notifications TO authenticated;

-- Maps an approved event type to an app-owned title/body/route. The only
-- dynamic route is a UUID-shaped post id; all other routes are constants.
CREATE OR REPLACE FUNCTION public.notification_event_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification_id UUID;
  v_category TEXT;
  v_title TEXT;
  v_body TEXT;
  v_route TEXT;
  v_post_id TEXT;
BEGIN
  v_category := split_part(NEW.type, '.', 1);
  v_route := '/notifications';

  CASE NEW.type
    WHEN 'highlight.ready' THEN
      v_title := '새 하이라이트가 준비됐어요';
      v_body := '어젯밤 활동 하이라이트를 확인해 보세요.';
      v_route := '/crecam/highlights';
    WHEN 'device.action.started' THEN
      v_title := '예약 동작이 시작됐어요';
      v_body := '사육장 예약 또는 타이머 동작이 시작됐습니다.';
      v_route := '/home/routines';
    WHEN 'device.action.ended' THEN
      v_title := '예약 동작이 끝났어요';
      v_body := '사육장 예약 또는 타이머 동작이 완료됐습니다.';
      v_route := '/home/routines';
    WHEN 'device.action.failed' THEN
      v_title := '예약 동작 실행에 실패했어요';
      v_body := '사육장 상태를 확인한 뒤 다시 시도해 주세요.';
      v_route := '/home/routines';
    WHEN 'community.comment' THEN
      v_title := '내 게시물에 새 댓글이 달렸어요';
      v_body := '커뮤니티에서 댓글을 확인해 보세요.';
      v_post_id := NEW.payload ->> 'post_id';
      IF v_post_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_route := '/community-player/' || v_post_id;
      END IF;
    WHEN 'community.like_digest' THEN
      v_title := format('내 게시물에 좋아요 %s개', COALESCE(NEW.payload ->> 'like_count', '0'));
      v_body := format('좋아요 %s개를 받았어요.', COALESCE(NEW.payload ->> 'like_count', '0'));
      v_post_id := NEW.payload ->> 'post_id';
      IF v_post_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_route := '/community-player/' || v_post_id;
      END IF;
    WHEN 'notice.published' THEN
      v_title := COALESCE(NULLIF(NEW.payload ->> 'title', ''), '새 공지');
      v_body := COALESCE(NULLIF(NEW.payload ->> 'body', ''), '새 공지를 확인해 보세요.');
      v_route := '/notifications';
    WHEN 'maintenance.water_tank' THEN
      v_title := '물통 세척 예정일이에요';
      v_body := format('%s 물통을 세척해 주세요.', COALESCE(NULLIF(NEW.payload ->> 'enclosure_name', ''), '사육장'));
      v_route := '/home/routines';
    WHEN 'safety.alert' THEN
      v_title := '사육장 안전 경고가 감지됐어요';
      v_body := '온습도와 사육장 상태를 바로 확인해 주세요.';
      v_route := '/env-detail';
    WHEN 'safety.recovered' THEN
      v_title := '사육장 안전 경고가 해제됐어요';
      v_body := '사육장 환경이 정상 범위로 돌아왔습니다.';
      v_route := '/env-detail';
  END CASE;

  INSERT INTO public.app_notifications (
    user_id, kind, category, title, body, route, data,
    source, source_event_id, dedupe_key, created_at
  ) VALUES (
    NEW.user_id, NEW.type, v_category, v_title, v_body, v_route,
    jsonb_build_object(
      'kind', NEW.type,
      'source', NEW.source,
      'source_event_id', NEW.source_event_id
    ) || NEW.payload,
    NEW.source, NEW.source_event_id,
    NEW.source || ':' || NEW.source_event_id,
    NEW.occurred_at
  ) ON CONFLICT (user_id, dedupe_key) DO NOTHING
  RETURNING id INTO v_notification_id;

  IF v_notification_id IS NOT NULL THEN
    INSERT INTO public.notification_outbox (notification_id, user_id, scheduled_at)
    VALUES (v_notification_id, NEW.user_id, NEW.scheduled_at);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER notification_events_after_insert
AFTER INSERT ON public.notification_events
FOR EACH ROW EXECUTE FUNCTION public.notification_event_after_insert();

-- Registering through this RPC atomically removes a token from any older
-- installation/account before associating it with the authenticated account.
CREATE OR REPLACE FUNCTION public.register_push_device(
  p_installation_id UUID,
  p_fcm_token TEXT,
  p_platform TEXT,
  p_app_version TEXT,
  p_locale TEXT
)
RETURNS public.push_devices
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_device public.push_devices;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_installation_id IS NULL OR p_fcm_token IS NULL OR btrim(p_fcm_token) = '' THEN
    RAISE EXCEPTION 'installation_id and fcm_token are required' USING ERRCODE = '22023';
  END IF;
  IF p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'unsupported push platform' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.push_devices
  WHERE (fcm_token = p_fcm_token OR installation_id = p_installation_id)
    AND (user_id, installation_id) IS DISTINCT FROM (v_user_id, p_installation_id);

  INSERT INTO public.push_devices (
    user_id, installation_id, fcm_token, platform, app_version, locale,
    enabled, last_seen_at, updated_at
  ) VALUES (
    v_user_id, p_installation_id, p_fcm_token, p_platform, p_app_version, p_locale,
    true, now(), now()
  ) ON CONFLICT (user_id, installation_id) DO UPDATE SET
    fcm_token = EXCLUDED.fcm_token,
    platform = EXCLUDED.platform,
    app_version = EXCLUDED.app_version,
    locale = EXCLUDED.locale,
    enabled = true,
    last_seen_at = now(),
    updated_at = now()
  RETURNING * INTO v_device;

  RETURN v_device;
END;
$$;

CREATE OR REPLACE FUNCTION public.deactivate_push_device(p_installation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000';
  END IF;
  UPDATE public.push_devices
  SET enabled = false, updated_at = now(), last_seen_at = now()
  WHERE user_id = v_user_id AND installation_id = p_installation_id;
END;
$$;

-- A dispatcher claims rows before talking to FCM so concurrent invocations
-- cannot send the same notification at the same time. This function remains
-- service-role-only: clients cannot inspect or advance outbox work.
CREATE OR REPLACE FUNCTION public.claim_notification_outbox(p_limit INTEGER)
RETURNS TABLE (
  id UUID,
  notification_id UUID,
  user_id UUID,
  attempts INTEGER,
  lock_token UUID,
  kind TEXT,
  title TEXT,
  body TEXT,
  route TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_limit IS NULL OR p_limit <= 0 THEN
    RAISE EXCEPTION 'p_limit must be positive' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  WITH due AS (
    SELECT o.id
    FROM public.notification_outbox AS o
    WHERE (o.status = 'pending' AND o.scheduled_at <= now())
      OR (o.status = 'processing'
          AND o.locked_at < now() - interval '10 minutes')
    ORDER BY o.scheduled_at, o.created_at
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  ), claimed AS (
    UPDATE public.notification_outbox AS o
    SET status = 'processing',
        attempts = o.attempts + 1,
        locked_at = now(),
        lock_token = gen_random_uuid(),
        updated_at = now()
    FROM due
    WHERE o.id = due.id
    RETURNING o.id, o.notification_id, o.user_id, o.attempts, o.lock_token
  )
  SELECT
    c.id,
    c.notification_id,
    c.user_id,
    c.attempts,
    c.lock_token,
    n.kind,
    n.title,
    n.body,
    n.route
  FROM claimed AS c
  JOIN public.app_notifications AS n ON n.id = c.notification_id;
END;
$$;

-- The outbox fence is checked before any delivery claim. Both leases are ten
-- minutes; dispatch network calls time out after fifteen seconds, leaving room
-- for a bounded batch without a second worker taking over a live claim.
CREATE OR REPLACE FUNCTION public.claim_notification_deliveries(
  p_outbox_id UUID,
  p_lock_token UUID,
  p_limit INTEGER
)
RETURNS TABLE (
  id UUID,
  push_device_id UUID,
  fcm_token TEXT,
  attempts INTEGER,
  lock_token UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_outbox_id IS NULL OR p_lock_token IS NULL OR p_limit IS NULL OR p_limit <= 0 THEN
    RAISE EXCEPTION 'outbox id, lock token, and positive limit are required' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.notification_outbox AS o
    WHERE o.id = p_outbox_id
      AND o.status = 'processing'
      AND o.lock_token = p_lock_token
  ) THEN
    RAISE EXCEPTION 'outbox lease is no longer held' USING ERRCODE = '55000';
  END IF;

  INSERT INTO public.notification_deliveries (outbox_id, push_device_id, scheduled_at)
  SELECT p_outbox_id, d.id, now()
  FROM public.push_devices AS d
  WHERE d.enabled = true
    AND d.user_id = (SELECT o.user_id FROM public.notification_outbox AS o WHERE o.id = p_outbox_id)
  ON CONFLICT ON CONSTRAINT notification_deliveries_outbox_id_push_device_id_key DO NOTHING;

  RETURN QUERY
  WITH due AS (
    SELECT d.id
    FROM public.notification_deliveries AS d
    JOIN public.push_devices AS p ON p.id = d.push_device_id AND p.enabled = true
    WHERE d.outbox_id = p_outbox_id
      AND ((d.status = 'pending' AND d.scheduled_at <= now())
        OR (d.status = 'processing'
            AND d.locked_at < now() - interval '10 minutes'))
    ORDER BY d.scheduled_at, d.created_at
    LIMIT p_limit
    FOR UPDATE OF d SKIP LOCKED
  ), claimed AS (
    UPDATE public.notification_deliveries AS d
    SET status = 'processing',
        attempts = d.attempts + 1,
        locked_at = now(),
        lock_token = gen_random_uuid(),
        updated_at = now()
    FROM due
    WHERE d.id = due.id
    RETURNING d.id, d.push_device_id, d.attempts, d.lock_token
  )
  SELECT c.id, c.push_device_id, p.fcm_token, c.attempts, c.lock_token
  FROM claimed AS c
  JOIN public.push_devices AS p ON p.id = c.push_device_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_notification_delivery(
  p_delivery_id UUID,
  p_lock_token UUID,
  p_status TEXT,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
  p_last_error TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('pending', 'sent', 'failed', 'cancelled') THEN
    RAISE EXCEPTION 'invalid delivery status' USING ERRCODE = '22023';
  END IF;
  IF p_status = 'pending' AND p_scheduled_at IS NULL THEN
    RAISE EXCEPTION 'pending delivery needs scheduled_at' USING ERRCODE = '22023';
  END IF;

  UPDATE public.notification_deliveries AS d
  SET status = p_status,
      scheduled_at = COALESCE(p_scheduled_at, d.scheduled_at),
      locked_at = NULL,
      lock_token = NULL,
      sent_at = CASE WHEN p_status = 'sent' THEN now() ELSE d.sent_at END,
      last_error = p_last_error,
      updated_at = now()
  WHERE d.id = p_delivery_id
    AND d.status = 'processing'
    AND d.lock_token = p_lock_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery lease is no longer held' USING ERRCODE = '55000';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_notification_outbox(
  p_outbox_id UUID,
  p_lock_token UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_scheduled_at TIMESTAMPTZ;
  v_has_unfinished BOOLEAN;
  v_has_active_failed BOOLEAN;
  v_error TEXT;
  v_status TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notification_outbox AS o
    WHERE o.id = p_outbox_id
      AND o.status = 'processing'
      AND o.lock_token = p_lock_token
  ) THEN
    RAISE EXCEPTION 'outbox lease is no longer held' USING ERRCODE = '55000';
  END IF;

  UPDATE public.notification_deliveries AS d
  SET status = 'cancelled', locked_at = NULL, lock_token = NULL, updated_at = now()
  FROM public.push_devices AS p
  WHERE d.outbox_id = p_outbox_id
    AND d.push_device_id = p.id
    AND p.enabled = false
    AND d.status IN ('pending', 'processing');

  SELECT
    COALESCE(bool_or(d.status IN ('pending', 'processing') AND p.enabled), false),
    COALESCE(bool_or(d.status = 'failed' AND p.enabled), false),
    min(CASE
      WHEN d.status = 'pending' THEN d.scheduled_at
      WHEN d.status = 'processing' THEN d.locked_at + interval '10 minutes'
    END) FILTER (WHERE d.status IN ('pending', 'processing') AND p.enabled),
    max(d.last_error) FILTER (WHERE d.status = 'failed' AND p.enabled)
  INTO v_has_unfinished, v_has_active_failed, v_next_scheduled_at, v_error
  FROM public.notification_deliveries AS d
  JOIN public.push_devices AS p ON p.id = d.push_device_id
  WHERE d.outbox_id = p_outbox_id;

  IF v_has_unfinished THEN
    v_status := 'pending';
  ELSIF v_has_active_failed THEN
    v_status := 'failed';
  ELSE
    v_status := 'sent';
  END IF;

  UPDATE public.notification_outbox AS o
  SET status = v_status,
      scheduled_at = CASE WHEN v_status = 'pending' THEN v_next_scheduled_at ELSE o.scheduled_at END,
      locked_at = NULL,
      lock_token = NULL,
      sent_at = CASE WHEN v_status = 'sent' THEN now() ELSE o.sent_at END,
      last_error = CASE WHEN v_status = 'failed' THEN v_error ELSE NULL END,
      updated_at = now()
  WHERE o.id = p_outbox_id
    AND o.status = 'processing'
    AND o.lock_token = p_lock_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'outbox lease is no longer held' USING ERRCODE = '55000';
  END IF;
  RETURN v_status;
END;
$$;

-- Community producers are database-owned, so a client never writes an
-- app_notification/event/outbox record directly.
CREATE OR REPLACE FUNCTION public.notify_community_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID;
BEGIN
  SELECT author_id INTO v_owner_id FROM public.community_posts WHERE id = NEW.post_id;
  IF v_owner_id IS NULL OR v_owner_id = NEW.author_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notification_events (
    source, source_event_id, user_id, type, occurred_at, payload
  ) VALUES (
    'database', 'community-comment:' || NEW.id::text, v_owner_id,
    'community.comment', NEW.created_at,
    jsonb_build_object('post_id', NEW.post_id, 'comment_id', NEW.id)
  ) ON CONFLICT (source, source_event_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER community_comments_notification
AFTER INSERT ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.notify_community_comment();

CREATE OR REPLACE FUNCTION public.notify_community_like_digest()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID;
  v_bucket_epoch BIGINT;
  v_source_event_id TEXT;
  v_payload JSONB;
  v_like_count INTEGER;
BEGIN
  SELECT author_id INTO v_owner_id FROM public.community_posts WHERE id = NEW.post_id;
  IF v_owner_id IS NULL OR v_owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Epoch bucketing is timezone-independent; no KST conversion is involved.
  v_bucket_epoch := floor(extract(epoch FROM NEW.created_at) / 600)::BIGINT;
  v_source_event_id := 'community-like:' || NEW.post_id::text || ':' || v_bucket_epoch::text;

  INSERT INTO public.notification_events (
    source, source_event_id, user_id, type, occurred_at, scheduled_at, payload
  ) VALUES (
    'database', v_source_event_id, v_owner_id, 'community.like_digest', NEW.created_at,
    to_timestamp((v_bucket_epoch + 1) * 600),
    jsonb_build_object('post_id', NEW.post_id, 'like_count', 1, 'bucket_epoch', v_bucket_epoch)
  ) ON CONFLICT (source, source_event_id) DO UPDATE SET
    payload = jsonb_set(
      public.notification_events.payload,
      '{like_count}',
      to_jsonb(COALESCE((public.notification_events.payload ->> 'like_count')::INTEGER, 0) + 1),
      true
    ),
    occurred_at = EXCLUDED.occurred_at
  WHERE EXISTS (
    SELECT 1
    FROM public.app_notifications AS n
    JOIN public.notification_outbox AS o ON o.notification_id = n.id
    WHERE n.user_id = EXCLUDED.user_id
      AND n.dedupe_key = EXCLUDED.source || ':' || EXCLUDED.source_event_id
      AND o.status = 'pending'
  )
  RETURNING payload INTO v_payload;

  IF v_payload IS NOT NULL THEN
    v_like_count := (v_payload ->> 'like_count')::INTEGER;
    UPDATE public.app_notifications AS n
    SET title = format('내 게시물에 좋아요 %s개', v_like_count),
        body = format('좋아요 %s개를 받았어요.', v_like_count),
        data = n.data || v_payload
    WHERE n.user_id = v_owner_id
      AND n.dedupe_key = 'database:' || v_source_event_id
      AND EXISTS (
        SELECT 1 FROM public.notification_outbox AS o
        WHERE o.notification_id = n.id AND o.status = 'pending'
      );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER community_likes_notification
AFTER INSERT ON public.community_likes
FOR EACH ROW EXECUTE FUNCTION public.notify_community_like_digest();

CREATE OR REPLACE FUNCTION public.notify_community_notice()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_events (
    source, source_event_id, user_id, type, occurred_at, payload
  )
  SELECT
    'database',
    'community-notice:' || NEW.id::text || ':' || u.id::text,
    u.id,
    'notice.published',
    NEW.created_at,
    jsonb_build_object('notice_id', NEW.id, 'title', NEW.title, 'body', COALESCE(NEW.body, ''))
  FROM auth.users AS u
  ON CONFLICT (source, source_event_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER community_notices_notification
AFTER INSERT ON public.community_notices
FOR EACH ROW EXECUTE FUNCTION public.notify_community_notice();

CREATE OR REPLACE FUNCTION public.schedule_water_tank_notification(
  p_due_at TIMESTAMPTZ,
  p_enclosure_id UUID,
  p_enclosure_name TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_due_at IS NULL OR p_enclosure_id IS NULL OR p_enclosure_name IS NULL OR btrim(p_enclosure_name) = '' THEN
    RAISE EXCEPTION 'due_at, enclosure_id, and enclosure_name are required' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.enclosures
    WHERE id = p_enclosure_id AND owner_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'enclosure is not owned by the current user' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.notification_events (
    source, source_event_id, user_id, type, occurred_at, scheduled_at, payload
  ) VALUES (
    'database',
    'water-tank:' || v_user_id::text || ':' || p_enclosure_id::text || ':' || floor(extract(epoch FROM p_due_at))::BIGINT,
    v_user_id,
    'maintenance.water_tank',
    now(),
    p_due_at,
    jsonb_build_object('enclosure_id', p_enclosure_id, 'enclosure_name', btrim(p_enclosure_name))
  ) ON CONFLICT (source, source_event_id) DO NOTHING;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notification_event_after_insert() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.register_push_device(UUID, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.deactivate_push_device(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_notification_outbox(INTEGER) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_notification_deliveries(UUID, UUID, INTEGER) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.complete_notification_delivery(UUID, UUID, TEXT, TIMESTAMPTZ, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.finalize_notification_outbox(UUID, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_community_comment() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_community_like_digest() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_community_notice() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.schedule_water_tank_notification(TIMESTAMPTZ, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_push_device(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deactivate_push_device(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_water_tank_notification(TIMESTAMPTZ, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_outbox(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.claim_notification_deliveries(UUID, UUID, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_notification_delivery(UUID, UUID, TEXT, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_notification_outbox(UUID, UUID) TO service_role;
