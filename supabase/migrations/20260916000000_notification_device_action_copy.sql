-- 2026-09-16: device.action.* 알림 문구에 기기 이름·동작 라벨을 넣고, 무응답
-- (no_ack/expired/lost)·busy 실패를 구분한다. 9/15 푸시 회신 §4·§5.3에 대한
-- 답신(docs/handoffs/2026-09-16-lee-gwanhun-reply-groups-and-push.md §3)의
-- payload(outcome/result 분리, device_name)를 전제로 한다. 트리거는 그대로
-- 두고 함수 본문만 교체한다. 다른 type의 문구는 20260915 마이그레이션과 같다.
-- 운영 적용은 서버 푸시 구현 착수와 함께 한다(미적용 상태로 커밋됨).

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
  v_device_name TEXT;
  v_action_label TEXT;
  v_result TEXT;
BEGIN
  v_category := split_part(NEW.type, '.', 1);
  v_route := '/notifications';
  v_device_name := COALESCE(NULLIF(NEW.payload ->> 'device_name', ''), '사육장');
  v_result := NEW.payload ->> 'result';
  v_action_label := CASE NEW.payload ->> 'action'
    WHEN 'fan_on' THEN '환기팬 켜기'
    WHEN 'fan_off' THEN '환기팬 끄기'
    WHEN 'fan2_on' THEN '냉각팬 켜기'
    WHEN 'fan2_off' THEN '냉각팬 끄기'
    WHEN 'led_on' THEN 'LED 켜기'
    WHEN 'led_off' THEN 'LED 끄기'
    WHEN 'heater_on' THEN '히터 켜기'
    WHEN 'heater_off' THEN '히터 끄기'
    WHEN 'mist' THEN '분무'
    WHEN 'relay_on' THEN '워터펌프 켜기'
    WHEN 'relay_off' THEN '워터펌프 끄기'
    ELSE COALESCE(NULLIF(NEW.payload ->> 'action', ''), '기기')
  END;

  CASE NEW.type
    WHEN 'highlight.ready' THEN
      v_title := '새 하이라이트가 준비됐어요';
      v_body := '어젯밤 활동 하이라이트를 확인해 보세요.';
      v_route := '/crecam/highlights';
    WHEN 'device.action.started' THEN
      v_title := '예약 동작이 시작됐어요';
      v_body := format('%s의 %s 예약이 시작됐습니다.', v_device_name, v_action_label);
      v_route := '/home/routines';
    WHEN 'device.action.ended' THEN
      v_title := '예약 동작이 끝났어요';
      v_body := format('%s의 %s 예약이 끝났습니다.', v_device_name, v_action_label);
      v_route := '/home/routines';
    WHEN 'device.action.failed' THEN
      v_title := '예약 동작을 실행하지 못했어요';
      -- result = 펌웨어 원문(ok/busy/...) 또는 서버 판정(no_ack/expired/lost).
      -- 무응답은 "다시 시도"가 아니라 기기 연결 확인이 맞다(회신 2026-09-15 §4.4).
      IF v_result IN ('no_ack', 'expired', 'lost', 'sent', 'unknown_device') THEN
        v_body := format('%s에 %s 예약 명령이 닿지 않았어요. 기기 연결 상태를 확인해 주세요.', v_device_name, v_action_label);
      ELSIF v_result = 'busy' THEN
        v_body := format('%s이(가) 다른 동작 중이라 %s 예약을 실행하지 못했어요.', v_device_name, v_action_label);
      ELSE
        v_body := format('%s의 %s 예약을 실행하지 못했어요. 사육장 상태를 확인해 주세요.', v_device_name, v_action_label);
      END IF;
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
