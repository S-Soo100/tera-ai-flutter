-- v4_test_rows.sql 정리 — 실행 후 마지막 조회가 전부 0이어야 한다.
delete from public.alerts where device_id = ':DEVICE_ID' and context->>'qa' = 'true';
delete from public.app_notifications where source_event_id like 'qa-20261103-%';
delete from public.notification_events where source_event_id like 'qa-20261103-%';
delete from public.env_daily_reports where device_id = ':DEVICE_ID' and report_date = (now() at time zone 'Asia/Seoul')::date - 1 and generated_at >= now() - interval '7 days';
delete from public.env_weekly_reports where device_id = ':DEVICE_ID' and week_start = date_trunc('week', (now() at time zone 'Asia/Seoul')::date - 7)::date;
select
  (select count(*) from public.alerts where context->>'qa' = 'true') as alerts,
  (select count(*) from public.notification_events where source_event_id like 'qa-20261103-%') as events,
  (select count(*) from public.app_notifications where source_event_id like 'qa-20261103-%') as notifs;
