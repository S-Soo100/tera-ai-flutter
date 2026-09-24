-- 캠 라이브 시청 세션 기록 (2026-09-25)
-- 기획: docs/superpowers/specs/2026-09-25-live-view-session-logging-design.md
-- ⚠️ 운영 적용은 사용자 확인 후. 앱 배포보다 먼저 적용해야 한다(새 컬럼 없는
--    DB에 새 앱이 INSERT하면 연결 행까지 거부된다).

begin;

-- 1) 연결 행에 view·펌웨어 --------------------------------------------------
alter table public.webrtc_connect_logs
  add column if not exists view_id uuid,
  add column if not exists firmware_ver text;

create index if not exists webrtc_connect_logs_view_id_idx
  on public.webrtc_connect_logs (view_id) where view_id is not null;

-- 2) 시청 세션 요약 ---------------------------------------------------------
create table if not exists public.webrtc_view_logs (
  id              uuid primary key default gen_random_uuid(),
  view_id         uuid not null unique,
  user_id         uuid not null default auth.uid()
                    references auth.users (id) on delete cascade,
  camera_id       uuid not null references public.cameras (id) on delete cascade,
  created_at      timestamptz not null default now(),
  started_at      timestamptz not null,
  app_version     text,
  platform        text,
  network         text,
  firmware_ver    text,
  camera_online   boolean,
  end_reason      text not null check (end_reason in ('closed', 'background')),
  duration_ms     integer not null check (duration_ms >= 0),
  first_video_ms  integer check (first_video_ms >= 0),
  attempts        integer not null default 0,
  ms_connecting   integer not null default 0,
  ms_video        integer not null default 0,
  ms_stalled      integer not null default 0,
  ms_recovering   integer not null default 0,
  ms_failed       integer not null default 0,
  stall_count     integer not null default 0,
  failed_count    integer not null default 0,
  manual_retries  integer not null default 0,
  restarts        jsonb not null default '{}'::jsonb
);

create index if not exists webrtc_view_logs_user_started_idx
  on public.webrtc_view_logs (user_id, started_at desc);
create index if not exists webrtc_view_logs_camera_started_idx
  on public.webrtc_view_logs (camera_id, started_at desc);

alter table public.webrtc_view_logs enable row level security;

-- 본인 INSERT만. SELECT 정책 없음 — 앱은 .select()를 붙이지 않는다.
drop policy if exists "insert own" on public.webrtc_view_logs;
create policy "insert own" on public.webrtc_view_logs
  for insert to authenticated
  with check (user_id = auth.uid());

grant insert on public.webrtc_view_logs to authenticated;

-- 3) 운영자 조회용 view — PostgREST에 노출되지 않는 ops 스키마 ----------------
create schema if not exists ops;
revoke all on schema ops from public;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on schema ops from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on schema ops from authenticated';
  end if;
end $$;

-- 세션 1행. 요약이 없으면(강제 종료 추정) 연결 행으로 보정한다.
create or replace view ops.live_views as
with c as (
  select view_id,
         min(user_id::text)::uuid                          as user_id,
         min(camera_id::text)::uuid                        as camera_id,
         min(created_at)                                   as first_at,
         max(created_at)                                   as last_at,
         count(*)                                          as rows,
         count(*) filter (where outcome = 'streaming')     as streaming_rows,
         max(firmware_ver)                                 as firmware_ver,
         max(app_version)                                  as app_version
  from public.webrtc_connect_logs
  where view_id is not null
  group by view_id
)
select
  coalesce(v.view_id, c.view_id)                          as view_id,
  u.email,
  coalesce(v.user_id, c.user_id)                          as user_id,
  coalesce(v.camera_id, c.camera_id)                      as camera_id,
  cam.name                                                as camera_name,
  coalesce(v.started_at, c.first_at)                      as started_at,
  v.view_id is null                                       as summary_missing,
  v.end_reason,
  round(coalesce(v.duration_ms,
        extract(epoch from (c.last_at - c.first_at)) * 1000) / 1000.0, 1)
                                                          as duration_s,
  -- 요약이 있으면 요약이 기준, 없으면(강제 종료) 연결 행에 성공이 있었는지.
  case when v.view_id is not null then v.first_video_ms is not null
       else c.streaming_rows > 0 end                      as saw_video,
  round(v.first_video_ms / 1000.0, 1)                     as first_video_s,
  coalesce(v.attempts, c.rows::int)                       as attempts,
  round(v.ms_connecting / 1000.0, 1)                      as connecting_s,
  round(v.ms_video / 1000.0, 1)                           as video_s,
  round(v.ms_stalled / 1000.0, 1)                         as stalled_s,
  round(v.ms_recovering / 1000.0, 1)                      as recovering_s,
  round(v.ms_failed / 1000.0, 1)                          as failed_s,
  v.stall_count,
  v.failed_count,
  v.manual_retries,
  v.restarts,
  v.network,
  v.camera_online,
  coalesce(v.firmware_ver, c.firmware_ver)                as firmware_ver,
  coalesce(v.app_version, c.app_version)                  as app_version,
  v.platform,
  coalesce(c.rows, 0)                                     as connect_rows
from public.webrtc_view_logs v
full outer join c on c.view_id = v.view_id
left join auth.users u on u.id = coalesce(v.user_id, c.user_id)
left join public.cameras cam on cam.id = coalesce(v.camera_id, c.camera_id);

-- 날짜(KST)·앱 버전·펌웨어별 품질.
create or replace view ops.live_daily as
select
  (started_at at time zone 'Asia/Seoul')::date            as day_kst,
  app_version,
  firmware_ver,
  count(*)                                                as views,
  count(distinct user_id)                                 as users,
  round(100.0 * avg(saw_video::int), 1)                   as saw_video_pct,
  percentile_cont(0.5) within group (order by first_video_s)
                                                          as first_video_p50_s,
  percentile_cont(0.9) within group (order by first_video_s)
                                                          as first_video_p90_s,
  round(100.0 * avg((coalesce(failed_count, 0) > 0)::int), 1)
                                                          as saw_failed_screen_pct,
  round(100.0 * avg((coalesce(stall_count, 0) > 0)::int), 1)
                                                          as saw_stall_pct,
  count(*) filter (where summary_missing)                 as summary_missing
from ops.live_views
group by 1, 2, 3;

-- 한 유저의 시간순 기록. 예) where email = '…' and at > now() - interval '1 day'
create or replace view ops.live_timeline as
select u.email, v.user_id, v.started_at as at, 'view-start' as kind,
       v.camera_id, v.view_id,
       jsonb_build_object('network', v.network, 'firmware', v.firmware_ver,
                          'camera_online', v.camera_online,
                          'app', v.app_version) as detail
from public.webrtc_view_logs v
left join auth.users u on u.id = v.user_id
union all
select u.email, v.user_id,
       v.started_at + make_interval(secs => v.duration_ms / 1000.0),
       'view-end', v.camera_id, v.view_id,
       jsonb_build_object('end', v.end_reason,
                          'first_video_s', round(v.first_video_ms / 1000.0, 1),
                          'failed_s', round(v.ms_failed / 1000.0, 1),
                          'stalled_s', round(v.ms_stalled / 1000.0, 1),
                          'manual_retries', v.manual_retries,
                          'restarts', v.restarts)
from public.webrtc_view_logs v
left join auth.users u on u.id = v.user_id
union all
select u.email, l.user_id, l.created_at, 'connect:' || l.outcome,
       l.camera_id, l.view_id,
       jsonb_strip_nulls(jsonb_build_object(
         'fail_phase', l.fail_phase, 'network', l.network,
         'first_frame_ms', l.ms_first_frame, 'streamed_sec', l.streamed_sec,
         'reconnect_attempt', l.reconnect_attempt,
         'offer_attempts', l.offer_attempts, 'cand',
         l.local_cand || '/' || l.remote_cand, 'firmware', l.firmware_ver))
from public.webrtc_connect_logs l
left join auth.users u on u.id = l.user_id;

commit;
