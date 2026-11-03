-- v4 온습도 스토어 배포 전 테스트 행 (docs/qa/2026-11-03-v4-env-release-test-plan.md §3)
-- 사용: :DEVICE_ID / :USER_ID / :DEVICE_NAME 를 테스트 기기·계정으로 바꿔 MCP execute_sql로 실행.
-- 원칙: 사용자 승인 후에만, 서버 1단계·Stage O 켜기 전에 넣고 지운다. 정리는 v4_test_rows_cleanup.sql.

-- ① 실시간 카드 — 온도 경고 + 습도 범위 이탈 + 습기 사이클(세 줄, Figma A26·A36)
insert into public.alerts (device_id, kind, severity, message, context, triggered_at) values
 (':DEVICE_ID', 'env_temp_low',   'critical', '[저온 경고] 온도가 너무 낮아 개체가 위험할 수 있어요', '{"rule":"v4","level":"danger","qa":true}', now()),
 (':DEVICE_ID', 'env_humid_low',  'warning',  '[건조 주의] 적정 습도보다 -6%p', '{"rule":"v4","level":"caution","qa":true}', now()),
 (':DEVICE_ID', 'env_mist_gap',   'warning',  '[건조 주의] 분무 필요', '{"rule":"v4","level":"caution","qa":true}', now());
-- 확인 뒤: update public.alerts set resolved_at = now() where device_id = ':DEVICE_ID' and context->>'qa' = 'true';  → 카드가 사라지는지

-- ② 푸시 — 안드로이드 수신·탭 이동·수신 끄기(습도 끔이면 outbox 0)
insert into public.notification_events (source, source_event_id, user_id, type, occurred_at, payload) values
 ('external', 'qa-20261103-push-1', ':USER_ID', 'env.alert.triggered', now(),
  jsonb_build_object('kind','env_vent_delay','title','[환기 지연] 분무 후 건기 미도달',
                     'device_id',':DEVICE_ID','device_name',':DEVICE_NAME'));

-- ③ 분석 카드 — 어제 일일, 지난주 주간(서버 문서 카드 JSON 형식)
insert into public.env_daily_reports (device_id, report_date, window_start, window_end, temp_card, humid_card) values
 (':DEVICE_ID', (now() at time zone 'Asia/Seoul')::date - 1,
  (((now() at time zone 'Asia/Seoul')::date - 1) + time '08:00') at time zone 'Asia/Seoul',
  (((now() at time zone 'Asia/Seoul')::date) + time '08:00') at time zone 'Asia/Seoul',
  '{"element":"temp","code":"TEMP_HIGH","status":"caution","title":"높은 온도가 기록됐어요","lines":["14:00~15:00 적정 온도보다 최대 +1.2℃ 이탈"],"data":{}}',
  '{"element":"humid","code":"HUM_DRY","status":"caution","title":"건조를 주의해 주세요","lines":["11/3 02:00~03:00 적정 습도보다 최대 -5% 이탈"],"data":{}}');
insert into public.env_weekly_reports (device_id, week_start, window_start, window_end, temp_card, humid_card, notices) values
 (':DEVICE_ID', date_trunc('week', (now() at time zone 'Asia/Seoul')::date - 7)::date,
  (date_trunc('week', (now() at time zone 'Asia/Seoul')::date - 7)::date + time '08:00') at time zone 'Asia/Seoul',
  (date_trunc('week', (now() at time zone 'Asia/Seoul')::date)::date + time '08:00') at time zone 'Asia/Seoul',
  '{"element":"temp","code":"TEMP_DANGER","status":"danger","title":"주간 중 위험 온도가 감지되었어요","lines":["총 2회 위험 온도 발생. 적정 온도보다 최대 4.1℃ 이탈"],"data":{}}',
  null,
  '[{"code":"ERR_DISCONNECT","metric":"h_a","title":"주간 데이터 수집이 원활하지 않았어요","body":"센서 전원과 Wi-Fi 연결 상태를 확인해 주세요"}]');
