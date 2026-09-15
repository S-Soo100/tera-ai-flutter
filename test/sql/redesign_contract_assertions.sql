-- Synthetic fixtures only, run in an isolated transaction with the draft schema.
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222');
insert into public.devices(id,owner_id,device_id,token_hash,name) values
('10000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','fixture-device','fixture','사육장 1');
insert into public.cameras(id,owner_id,camera_id,token_hash,name) values
('20000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','fixture-camera','fixture','카메라 1');
insert into public.pets(id,user_id,name,species_name) values
('30000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','크레','크레스티드 게코');
insert into public.motion_clips(id,camera_id,owner_id,started_at,duration_sec,r2_key,clip_purpose) values
('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',now(),10,'terra-clips/clips/fixture.mp4','production');
insert into public.clip_favorites(owner_id,clip_id) values
('11111111-1111-1111-1111-111111111111','40000000-0000-0000-0000-000000000001');
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ declare first_result jsonb; repeat_result jsonb; begin
 first_result := public.redesign_save_group_v1(null,null,
 '10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
 '[{"kind":"device","id":"10000000-0000-0000-0000-000000000001","group_id":null},{"kind":"camera","id":"20000000-0000-0000-0000-000000000001","group_id":null},{"kind":"pet","id":"30000000-0000-0000-0000-000000000001","group_id":null}]'::jsonb,
 '50000000-0000-0000-0000-000000000001');
 repeat_result := public.redesign_save_group_v1(null,null,
 '10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
 '[{"kind":"device","id":"10000000-0000-0000-0000-000000000001","group_id":null},{"kind":"camera","id":"20000000-0000-0000-0000-000000000001","group_id":null},{"kind":"pet","id":"30000000-0000-0000-0000-000000000001","group_id":null}]'::jsonb,
 '50000000-0000-0000-0000-000000000001');
 if first_result <> repeat_result then raise exception 'Group retry was not idempotent'; end if;
 insert into public.user_hidden_clips(user_id,clip_id) values(auth.uid(),'40000000-0000-0000-0000-000000000001');
 if (select count(*) from public.user_hidden_clips)<>1 then raise exception 'Owner hide not readable'; end if;
end $$;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin
 if exists(select 1 from public.user_hidden_clips) then raise exception 'Hidden IDs leaked across owners'; end if;
 begin
   insert into public.user_hidden_clips(user_id,clip_id) values(auth.uid(),'40000000-0000-0000-0000-000000000001');
   raise exception 'Foreign clip hide succeeded';
 exception when insufficient_privilege then null; end;
 begin
   perform public.redesign_rename_item_v1('device','10000000-0000-0000-0000-000000000001','침범');
   raise exception 'Foreign device renamed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.motion_clips)<>1 or (select count(*) from public.clip_favorites)<>1 then raise exception 'Hide modified originals/favorites'; end if;
 if (select count(*) from public.enclosures)<>1 then raise exception 'Duplicate group retry'; end if;
 if (select name from public.enclosures limit 1)<>'사육 환경 1' then raise exception 'Default first group name'; end if;
 if (select count(*) from public.pet_camera_assignments)<>1 then raise exception 'Assignment history missing/duplicated'; end if;
 if exists(select 1 from public.pet_camera_assignments where origin<>'recorded' or start_at is null) then raise exception 'New pets inherited fake past'; end if;
end $$;

-- Profile deletion must never activate media/event foreign-key cascades.
insert into public.pet_events(pet_id,type) values
('30000000-0000-0000-0000-000000000001','fixture');
insert into public.media(pet_id,type,url) values
('30000000-0000-0000-0000-000000000001','photo','fixture://preserved');
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ declare old_group uuid; first_result jsonb; repeat_result jsonb; begin
 select enclosure_id into old_group from public.pets where id='30000000-0000-0000-0000-000000000001';
 first_result := public.redesign_delete_pet_v1('30000000-0000-0000-0000-000000000001',old_group,'50000000-0000-0000-0000-000000000002');
 repeat_result := public.redesign_delete_pet_v1('30000000-0000-0000-0000-000000000001',old_group,'50000000-0000-0000-0000-000000000002');
 if first_result <> repeat_result then raise exception 'Pet delete retry was not idempotent'; end if;
 if exists(select 1 from public.pets) then raise exception 'Deleted profile still visible'; end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.pets where deleted_at is not null and enclosure_id is null)<>1 then raise exception 'Original pet not retained'; end if;
 if (select count(*) from public.media)<>1 or (select count(*) from public.pet_events)<>1 then raise exception 'Profile delete cascaded into originals'; end if;
 if (select count(*) from public.motion_clips)<>1 or (select count(*) from public.clip_favorites)<>1 then raise exception 'Profile delete modified clips/favorites'; end if;
 if exists(select 1 from public.pet_camera_assignments where end_at is null) then raise exception 'Deleted profile assignment remains open'; end if;
 if (select count(*) from public.enclosures)<>1 then raise exception 'Group with devices was deleted'; end if;
end $$;
