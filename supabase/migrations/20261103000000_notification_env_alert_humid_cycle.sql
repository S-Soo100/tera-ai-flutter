-- v4 온습도 이탈 수신 끔에 습기 사이클 알림 포함 (2026-11-03)
--
-- 서버 Stage O가 만들 `env_vent_delay`(환기 지연)·`env_mist_gap`(분무 공백)도
-- 계정의 "습도 이탈 알림"(notification_preferences.env_humid)을 따르게 한다.
-- 전에는 env_temp_%·env_humid_%만 보고 나머지는 ELSE true라, 습도 알림을 끈
-- 사용자에게도 이 둘의 푸시가 나갈 뻔했다.
--
-- 바탕: 운영 `notification_event_after_insert` 본문(prosrc md5
-- 9584664ac29955c9e825f1cb85564c98 = 20261102000100 파일과 동일, 2026-11-03 확인).
-- 바뀐 곳은 수신 끄기 CASE의 습도 분기 하나뿐이다.
-- 계획: docs/superpowers/plans/2026-11-03-env-humid-cycle-alerts-app.md Task 3.

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
  v_push_enabled BOOLEAN := true;
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
    WHEN 'env.alert.triggered' THEN
      -- v4 온습도 이탈(기획 1-5 "타이틀만"): 제목은 서버 완성본 그대로, 본문은
      -- 어느 사육장인지 알리는 사육장 이름만. category는 split_part → 'env'.
      -- 제목이 비면(계약 검사를 거치지 않은 적재 등) title NOT NULL 위반으로
      -- 이벤트 적재 전체가 실패하므로 다른 분기처럼 기본 문구로 채운다.
      v_title := COALESCE(NULLIF(NEW.payload ->> 'title', ''), '사육장 온습도를 확인해 주세요');
      v_body := COALESCE(NULLIF(NEW.payload ->> 'device_name', ''), '사육장');
      v_route := '/env-detail';
  END CASE;

  -- data는 아래 `|| NEW.payload`로 합친다. env.alert.triggered는 payload에도
  -- `kind`(env_temp_high 등)가 있어 data.kind가 그 값으로 덮인다 — 앱은 알림
  -- 종류로 컬럼 kind(= NEW.type)를 쓴다.
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

  -- v4 온습도 이탈 수신 끔(계정 단위, 2026-11-02 D2): 기록(app_notifications)은
  -- 위에서 이미 쌓았고 푸시(outbox)만 건너뛴다. 설정 행이 없으면 켬. 끈 뒤 새로
  -- 생기는 알림부터 적용된다(이미 outbox에 든 것은 그대로 나간다).
  IF v_notification_id IS NOT NULL AND NEW.type = 'env.alert.triggered' THEN
    v_push_enabled := CASE
      WHEN NEW.payload ->> 'kind' LIKE 'env\_temp\_%' THEN COALESCE((
        SELECT p.env_temp
        FROM public.notification_preferences AS p
        WHERE p.user_id = NEW.user_id
      ), true)
      -- 습도 범위 이탈 + 습기 사이클(환기 지연·분무 공백, 노션 v4 1-4 습도 푸시).
      -- 사이클 kind 이름은 서버 Stage O pre-plan 기준(2026-11-03, 미확정).
      WHEN NEW.payload ->> 'kind' LIKE 'env\_humid\_%'
        OR NEW.payload ->> 'kind' LIKE 'env\_vent\_%'
        OR NEW.payload ->> 'kind' LIKE 'env\_mist\_%' THEN COALESCE((
        SELECT p.env_humid
        FROM public.notification_preferences AS p
        WHERE p.user_id = NEW.user_id
      ), true)
      ELSE true
    END;
  END IF;

  IF v_notification_id IS NOT NULL AND v_push_enabled THEN
    INSERT INTO public.notification_outbox (notification_id, user_id, scheduled_at)
    VALUES (v_notification_id, NEW.user_id, NEW.scheduled_at);
  END IF;
  RETURN NEW;
END;
$$;
