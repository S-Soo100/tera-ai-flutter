-- REVIEW DRAFT. Provided by terra-server (backend review 2026-09-16 §1, B1)
-- and bundled here because redesign_reconcile_assignments is app-owned.
-- Apply after 20260915_redesign_groups.sql. Never as an automated migration.
--
-- Why: terra-server (service_role, auth.uid() NULL) and the web console cannot
-- join the RPC owner-lock protocol, so PATCH enclosure_id, REST unlink and
-- DELETE /enclosures (FK SET NULL) would skip history until the next app RPC.
-- reconcile is state-based and idempotent, so calling it from a row trigger is
-- safe. DO NOT take the advisory lock here: the RPC order is advisory lock ->
-- FOR UPDATE row lock; a trigger already holds the row lock, so grabbing the
-- advisory lock inside it inverts the order and can deadlock. Row locks plus
-- the pet_camera_assignment_open partial UNIQUE index serialize writers.
BEGIN;

-- 관계가 바뀌면 경로와 무관하게 개체↔카메라 이력을 맞춘다.
-- 앱 RPC 는 이미 명시 호출하므로 같은 트랜잭션에서 두 번 돌지만 멱등이라 무해.
CREATE OR REPLACE FUNCTION public.redesign_touch_assignments()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE owner uuid;
BEGIN
  -- Not `CASE ... NEW.user_id ELSE NEW.owner_id`: PL/pgSQL resolves both record
  -- fields when the expression is prepared, and cameras has no user_id
  -- (verified 2026-09-16: "record new has no field user_id"). Read by name.
  owner := (to_jsonb(NEW) ->> CASE TG_TABLE_NAME WHEN 'pets' THEN 'user_id' ELSE 'owner_id' END)::uuid;
  IF owner IS NOT NULL THEN
    PERFORM public.redesign_reconcile_assignments(owner, clock_timestamp());
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.redesign_touch_assignments() FROM PUBLIC, anon, authenticated;

-- 카메라: 그룹 이동·해제(unlink 는 enclosure_id=NULL 로 잡힘)
DROP TRIGGER IF EXISTS trg_cameras_touch_assignments ON public.cameras;
CREATE TRIGGER trg_cameras_touch_assignments
  AFTER UPDATE OF enclosure_id ON public.cameras
  FOR EACH ROW WHEN (OLD.enclosure_id IS DISTINCT FROM NEW.enclosure_id)
  EXECUTE FUNCTION public.redesign_touch_assignments();

-- 개체: 그룹 이동·툼스톤
DROP TRIGGER IF EXISTS trg_pets_touch_assignments ON public.pets;
CREATE TRIGGER trg_pets_touch_assignments
  AFTER UPDATE OF enclosure_id, deleted_at ON public.pets
  FOR EACH ROW WHEN (OLD.enclosure_id IS DISTINCT FROM NEW.enclosure_id
                  OR OLD.deleted_at IS DISTINCT FROM NEW.deleted_at)
  EXECUTE FUNCTION public.redesign_touch_assignments();

-- devices 는 개체↔카메라 이력과 무관(reconcile 이 pets↔cameras 만 봄).
-- ON DELETE SET NULL 도 행 UPDATE 트리거를 발화시켜 REST DELETE /enclosures 까지 커버.
ROLLBACK;
