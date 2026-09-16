-- 2026-09-16 backend review B4/B5: unlinked devices never join groups and the
-- relationship triggers keep pet↔camera history current without an app RPC.
reset role;
insert into public.cameras(id,owner_id,camera_id,token_hash,name,unlinked_at) values
('20000000-0000-0000-0000-000000000009','11111111-1111-1111-1111-111111111111','fixture-camera-unlinked','fixture','카메라 9',now());
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$ begin
 begin
  perform public.redesign_save_group_v1(null,null,null,'20000000-0000-0000-0000-000000000009',null,
   '[{"kind":"camera","id":"20000000-0000-0000-0000-000000000009","group_id":null}]'::jsonb,
   '50000000-0000-0000-0000-000000000009');
  raise exception 'Unlinked camera joined a group';
 exception when insufficient_privilege then null; end;
 begin
  perform public.redesign_rename_item_v1('camera','20000000-0000-0000-0000-000000000001','카메라 9');
 exception when unique_violation then raise exception 'Unlinked camera name blocked reuse'; end;
end $$;
reset role;

-- Trigger path: a plain UPDATE (what terra-server PATCH/unlink does) opens and
-- closes history for a live pet/camera pair with no RPC involved.
insert into public.enclosures(id,owner_id,name) values
('60000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','사육 환경 T');
insert into public.pets(id,user_id,name,species_name,enclosure_id) values
('30000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','크레2','크레스티드 게코','60000000-0000-0000-0000-000000000001');
insert into public.cameras(id,owner_id,camera_id,token_hash,name) values
('20000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','fixture-camera-2','fixture','카메라 2');
update public.cameras set enclosure_id='60000000-0000-0000-0000-000000000001' where id='20000000-0000-0000-0000-000000000002';
do $$ begin
 if not exists(select 1 from public.pet_camera_assignments where pet_id='30000000-0000-0000-0000-000000000002'
   and camera_id='20000000-0000-0000-0000-000000000002' and end_at is null) then
   raise exception 'Camera assign via UPDATE did not open history (trigger missing)'; end if;
end $$;
update public.cameras set enclosure_id=null, unlinked_at=now() where id='20000000-0000-0000-0000-000000000002';
do $$ begin
 if exists(select 1 from public.pet_camera_assignments where camera_id='20000000-0000-0000-0000-000000000002' and end_at is null) then
   raise exception 'Camera unlink via UPDATE left history open (trigger missing)'; end if;
 if (select count(*) from public.cameras where id='20000000-0000-0000-0000-000000000002')<>1 then
   raise exception 'Unlink deleted the camera row'; end if;
end $$;
-- Pet tombstone via UPDATE closes its history too.
update public.cameras set enclosure_id='60000000-0000-0000-0000-000000000001', unlinked_at=null where id='20000000-0000-0000-0000-000000000002';
update public.pets set deleted_at=now() where id='30000000-0000-0000-0000-000000000002';
do $$ begin
 if exists(select 1 from public.pet_camera_assignments where pet_id='30000000-0000-0000-0000-000000000002' and end_at is null) then
   raise exception 'Pet tombstone via UPDATE left history open (trigger missing)'; end if;
end $$;
