-- 2026-10-01: device.action.failed + result='device_offline'(terra-server#16) 문구.
-- 예약 시각에 기기가 오프라인이면 서버가 명령 없이 실패 이벤트를 보낸다.
-- 원 요청 docs/references/2026-10-01-schedule-device-offline.md, 백엔드 답신
-- (2026-10-01): 푸시 제목·본문은 이 트리거가 만든다.
-- 본문은 운영 함수(2026-10-01 조회, 9/23 하이라이트 날짜 문구 포함)를 기준으로
-- device_offline 분기만 더했다. 액션 라벨은 기존 푸시와 같은 트리거 라벨을 쓴다.
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
  v_raw_device_name TEXT;
  v_action_label TEXT;
  v_known_action_label TEXT;
  v_result TEXT;
BEGIN
  v_category := split_part(NEW.type, '.', 1);
  v_route := '/notifications';
  v_raw_device_name := NULLIF(NEW.payload ->> 'device_name', '');
  v_device_name := COALESCE(v_raw_device_name, '사육장');
  v_result := NEW.payload ->> 'result';
  v_known_action_label := CASE NEW.payload ->> 'action'
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
    ELSE NULL
  END;
  v_action_label := COALESCE(v_known_action_label,
                             NULLIF(NEW.payload ->> 'action', ''), '기기');

  CASE NEW.type
    WHEN 'highlight.ready' THEN
      v_title := '새 하이라이트가 준비됐어요';
      -- 2026-09-23 앱팀 요청: 어느 밤인지 알 수 있게 날짜 명시. day_key 없거나 형식이 다르면 옛 문구로 폴백.
      v_body := CASE
        WHEN NEW.payload ->> 'day_key' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
          format('%s월 %s일 활동 하이라이트를 확인해 보세요',
                 ltrim(split_part(NEW.payload ->> 'day_key', '-', 2), '0'),
                 ltrim(split_part(NEW.payload ->> 'day_key', '-', 3), '0'))
        ELSE '어젯밤 활동 하이라이트를 확인해 보세요.'
      END;
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
      IF v_result = 'device_offline' THEN
        -- 이름이 없으면 '사육장'으로 채우지 않고 이름 없는 제목을 쓴다.
        v_title := CASE WHEN v_raw_device_name IS NULL
          THEN '예약이 실행되지 않았어요'
          ELSE format('%s 예약이 실행되지 않았어요', v_raw_device_name) END;
        -- 모르는 action이면 라벨 부분을 뺀다.
        v_body := CASE WHEN v_known_action_label IS NULL
          THEN '기기가 꺼져 있거나 연결이 끊겨 예약을 실행하지 못했어요. 전원과 Wi-Fi를 확인해 주세요.'
          ELSE format('기기가 꺼져 있거나 연결이 끊겨 %s 예약을 실행하지 못했어요. 전원과 Wi-Fi를 확인해 주세요.', v_known_action_label) END;
      ELSIF v_result IN ('no_ack', 'expired', 'lost', 'sent', 'unknown_device') THEN
        v_body := format('%s에 %s 예약 명령이 닿지 않았어요. 기기 연결 상태를 확인해 주세요.', v_device_name, v_action_label);
      ELSIF v_result = 'busy' THEN
        v_body := format('%s이(가) 다른 동작 중이라 %s 예약을 실행하지 못했어요.', v_device_name, v_action_label);
      ELSE
        v_body := format('%s의 %s 예약을 실행하지 못했어요. 사육장 상태를 확인해 주세요.', v_device_name, v_action_label);
      END IF;
      v_route := '/home/routines';
    WHEN 'device.action.skipped' THEN
      v_title := '예약 동작을 건너뛰었어요';
      v_body := CASE
        WHEN NEW.payload -> 'guard' ->> 'metric' = 'temperature' THEN
          format('%s의 %s 예약이 온도 조건(%s℃)에 걸려 실행되지 않았어요.', v_device_name, v_action_label,
                 COALESCE(NEW.payload -> 'guard' ->> 'value', '-'))
        WHEN NEW.payload -> 'guard' ->> 'metric' = 'humidity' THEN
          format('%s의 %s 예약이 습도 조건(%s%%)에 걸려 실행되지 않았어요.', v_device_name, v_action_label,
                 COALESCE(NEW.payload -> 'guard' ->> 'value', '-'))
        ELSE format('%s의 %s 예약이 스마트 가드 조건에 걸려 실행되지 않았어요.', v_device_name, v_action_label)
      END;
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
