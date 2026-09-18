-- Existing synthetic fixtures remain; restore the soft-deleted test pet only
-- inside this isolated transaction and establish an open assignment interval.
reset role;
update public.pets set deleted_at=null, enclosure_id=(select id from public.enclosures limit 1)
where id='30000000-0000-0000-0000-000000000001';
update public.motion_clips set enclosure_id=(select id from public.enclosures limit 1);
select public.redesign_reconcile_assignments('11111111-1111-1111-1111-111111111111',clock_timestamp());
select set_config('test.group_id',(select id::text from public.enclosures limit 1),true);
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin
 begin
  perform public.redesign_delete_group_v1(current_setting('test.group_id')::uuid,'50000000-0000-0000-0000-000000000010');
  raise exception 'Foreign group deletion allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
-- A late failure after all members have been detached must roll back everything.
create function public.test_reject_group_delete() returns trigger language plpgsql as $$ begin raise exception 'injected failure'; end $$;
create trigger test_reject_group_delete before delete on public.enclosures for each row execute function public.test_reject_group_delete();
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ begin
 begin
  perform public.redesign_delete_group_v1(current_setting('test.group_id')::uuid,'50000000-0000-0000-0000-000000000010');
  raise exception 'Expected injected failure';
 exception when raise_exception then
  if sqlerrm <> 'injected failure' then raise; end if;
 end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.enclosures)<>1
 or (select count(*) from public.devices where enclosure_id is not null)<>1
 or (select count(*) from public.cameras where enclosure_id is not null)<>1
 or (select count(*) from public.pets where enclosure_id is not null)<>1 then
  raise exception 'Failure partially detached members'; end if;
 if (select count(*) from public.pet_camera_assignments where end_at is null)<>1 then raise exception 'Failure closed activity history'; end if;
 if exists(select 1 from public.redesign_group_requests where operation='delete-group') then raise exception 'Failure recorded success'; end if;
end $$;
drop trigger test_reject_group_delete on public.enclosures;
drop function public.test_reject_group_delete();
set local role authenticated;
do $$ declare result jsonb; begin
 result := public.redesign_delete_group_v1(current_setting('test.group_id')::uuid,'50000000-0000-0000-0000-000000000010');
 if result <> public.redesign_delete_group_v1(current_setting('test.group_id')::uuid,'50000000-0000-0000-0000-000000000010') then raise exception 'Delete retry not idempotent'; end if;
 begin
  perform public.redesign_delete_group_v1('00000000-0000-0000-0000-000000000000','50000000-0000-0000-0000-000000000010');
  raise exception 'Request accepted with changed payload';
 exception when invalid_parameter_value then null; end;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.enclosures) then raise exception 'Group not removed'; end if;
 if (select count(*) from public.devices where enclosure_id is null and owner_id='11111111-1111-1111-1111-111111111111')<>1
 or (select count(*) from public.cameras where enclosure_id is null and owner_id='11111111-1111-1111-1111-111111111111')<>1
 or (select count(*) from public.pets where enclosure_id is null and deleted_at is null)<>1 then raise exception 'Registered members not retained ungrouped'; end if;
 if exists(select 1 from public.pet_camera_assignments where end_at is null) then raise exception 'History not closed'; end if;
 if (select count(*) from public.motion_clips where r2_key='terra-clips/clips/fixture.mp4')<>1
 or (select count(*) from public.clip_favorites)<>1
 or (select count(*) from public.media)<>1
 or (select count(*) from public.pet_events)<>1 then raise exception 'Original content deleted'; end if;
end $$;
