# 백엔드 핸드오프 — 개체↔사육장 연결 (`pets.enclosure_id`) (rev.2, 2026-08-06)

> **실행 레포: `petcam-lab` 단독.** 이 마이그레이션을 적용하는 곳은 petcam-lab 세션 하나뿐이다.
> **Flutter 세션(`tera-ai-flutter`)은 DB/Supabase를 직접 수정하거나 마이그레이션을 적용하지 않는다.** 조회(read-only)만 허용.
> 대상 독자: petcam-lab / terra-server 담당
> 앱측 계획: [`docs/plans/2026-08-06-pet-enclosure-assignment.md`](plans/2026-08-06-pet-enclosure-assignment.md)
> 상태: **미적용 (승인 대기).**

> ⚠️ **rev.1 폐기.** rev.1은 (a) UNIQUE 제약을 걸지 않고 앱 UPDATE 3번으로 1:1을 보장했고, (b) 소유권 검사를 "선택 사항"으로 뒀고, (c) 검증에 `total=7` 고정값을 박았고, (d) 프로덕션에서 FK 실패를 실제 UPDATE로 시험했고, (e) 앱 필드가 "이미 머지됨"이라고 잘못 적었다. 전부 이 rev.2에서 교정됨.

---

## 0. 현재 Git 상태 (정확히)

rev.1의 "`Pet.enclosureId`는 이미 머지됨"은 **사실이 아니다.** 실측:

| 항목 | 값 |
|---|---|
| 현재 브랜치 | `feat/prd-redesign` |
| HEAD | `8d5d75a906d834c8d917d7d48107037fafd71f92` |
| upstream | **없음** (`no upstream configured`) — 이 브랜치는 **한 번도 push되지 않음** |
| `Pet.enclosureId` 커밋 | `31420444e34d72d97ec0bba5dc4196c41a5467fa` |
| 이 커밋을 포함한 브랜치 | `feat/prd-redesign` **(로컬 전용)** |
| `origin/main`에 포함? | **NO** |
| `origin/feat/knowledge-graph-layer`에 포함? | **NO** |
| `origin/main` 대비 미푸시 커밋 | 26개 |

→ **백엔드가 신뢰할 수 있는 앱측 상태는 "아직 없음"이다.** 앱 필드는 로컬 브랜치에만 존재하며, 병합·배포 시점은 미정. 이 마이그레이션은 앱 배포와 독립적으로 진행 가능하다(컬럼이 생겨도 구버전 앱은 이 컬럼을 보내지도 읽지도 않으므로 무영향).

---

## 1. 요약 (TL;DR)

| 항목 | 내용 |
|---|---|
| 요청 | `pets.enclosure_id` 추가 + 부분 UNIQUE + 소유권 가드 트리거 + `assign_pet_to_enclosure()` RPC |
| 왜 | PRD 전제 "사육장 1 : 캠 1 : 개체 1". 홈 헤더 `젤리 (1번 사육장)`·사육장 단품 프로필 카드가 이 연결에 의존 |
| 로컬 저장으로 안 되는 이유 | `SupabasePetRepository.syncFromRemote()`가 Hive box를 **clear 후 서버 행으로 재구성**한다. 서버에 컬럼이 없으면 동기화 1회로 배정 전량 소실 |
| 1:1 보장 | **DB가 강제**(부분 UNIQUE 인덱스). 앱 3-UPDATE 방식 폐기 |
| 소유권 검사 | **필수**(선택 아님). `pets.user_id = enclosures.owner_id` |
| 앱 인터페이스 | UPDATE 직접 금지. **`assign_pet_to_enclosure(p_pet_id, p_enclosure_id)` RPC 1회** |
| 미적용 시 앱 | 정상 동작. 헤더에 사육장명만, 배정 UI 미노출(feature flag off) |

---

## 2. 확인된 사실 (실 DB 조회, 2026-08-05)

> 아래는 **조사 시점 스냅샷**이다. 검증 기준으로 이 숫자를 그대로 쓰지 말 것(§5 참조).

- `pets` 컬럼 14개 전수 → `enclosure_id` **없음**
  `id, user_id, species_id, name, species_name, morph, sex, birth_date, adoption_date, weight, avatar_url, memo, created_at, updated_at`
- `enclosures` 테이블 **존재**. `enclosures.id` = `uuid`, `pets.id` = `uuid`, `pets.user_id` = `uuid`, `enclosures.owner_id` = `uuid` → 타입 호환
- RLS 현황
  - `enclosures`: `own enclosures all` — `ALL`, `USING/WITH CHECK: auth.uid() = owner_id`
  - `pets`: SELECT/INSERT/UPDATE/DELETE 각각 `auth.uid() = user_id`
- 조사 시점 행 수: `enclosures` 1, `pets` 7 — **참고용. 검증은 적용 직전 실측값과 비교한다.**

### 적용 전 전제조건 (precondition)

```sql
-- 컬럼이 아직 없어야 한다 (재실행 방지)
SELECT count(*) AS must_be_zero
FROM information_schema.columns
WHERE table_schema='public' AND table_name='pets' AND column_name='enclosure_id';
```

---

## 3. 마이그레이션 (UP)

> petcam-lab에서 **한 트랜잭션으로** 적용한다. 실패 시 전체 롤백되어 중간 상태가 남지 않는다.

```sql
BEGIN;

-- ── 1) 컬럼 ──────────────────────────────────────────────────────────────────
-- nullable 가산 컬럼이라 기존 행은 전부 NULL로 채워지고 동작 영향이 없다.
-- ON DELETE SET NULL: 사육장을 지워도 개체 레코드는 남기고 배정만 해제한다.
--   (CASCADE면 사육장 삭제가 사용자의 개체 데이터를 지운다 — 절대 금지)
ALTER TABLE public.pets
  ADD COLUMN enclosure_id UUID
  REFERENCES public.enclosures(id) ON DELETE SET NULL;

-- ── 2) 1:1 강제 (PRD 전제) ───────────────────────────────────────────────────
-- 부분 UNIQUE: 사육장 하나에 개체는 최대 하나. NULL(미배정)은 제한 없음.
-- 조회 인덱스 역할도 겸하므로 별도 일반 인덱스를 만들지 않는다.
CREATE UNIQUE INDEX pets_enclosure_id_unique
  ON public.pets (enclosure_id)
  WHERE enclosure_id IS NOT NULL;

-- ── 3) 소유권 가드 (필수) ────────────────────────────────────────────────────
-- pets.user_id 와 enclosures.owner_id 가 반드시 같아야 한다.
--
-- SECURITY DEFINER를 쓰는 이유: 남의 사육장을 가리키는 시도를 잡으려면
-- RLS로 숨겨진 행의 owner_id까지 읽어 "실제로 비교"해야 한다. RLS 가시성에
-- 의존한 간접 판정(안 보이면 거부)은 RLS 설정이 바뀌면 함께 무너진다.
--
-- DEFINER 하드닝 3종 (전부 필수):
--   a) search_path 고정 — 검색 경로 하이재킹 차단
--   b) PUBLIC EXECUTE 회수 — 직접 호출 경로 제거
--   c) 부수효과 없음 — 읽기 + RAISE만. 이 함수는 아무것도 쓰지 않는다.
CREATE OR REPLACE FUNCTION public.pets_enclosure_owner_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_owner uuid;
BEGIN
  IF NEW.enclosure_id IS NULL THEN
    RETURN NEW;                                  -- 미배정/해제는 통과
  END IF;

  SELECT e.owner_id INTO v_owner
    FROM public.enclosures e
   WHERE e.id = NEW.enclosure_id;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'enclosure % not found', NEW.enclosure_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF NEW.user_id IS NULL OR v_owner <> NEW.user_id THEN
    RAISE EXCEPTION
      'ownership mismatch: pets.user_id=% enclosures.owner_id=%',
      NEW.user_id, v_owner
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.pets_enclosure_owner_guard() FROM PUBLIC;

DROP TRIGGER IF EXISTS pets_enclosure_owner_guard_trg ON public.pets;
CREATE TRIGGER pets_enclosure_owner_guard_trg
  BEFORE INSERT OR UPDATE OF enclosure_id ON public.pets
  FOR EACH ROW EXECUTE FUNCTION public.pets_enclosure_owner_guard();

-- ── 4) 배정 RPC (앱의 유일한 쓰기 경로) ──────────────────────────────────────
-- 앱이 UPDATE를 3번 날리면 그 사이에 부분 UNIQUE 위반·부분 적용이 생긴다.
-- 하나의 함수 = 하나의 트랜잭션이라 "기존 점유 해제 → 신규 배정"이 원자적으로 끝난다.
--
-- p_enclosure_id = NULL 이면 배정 해제.
-- 실패는 전부 예외로 드러낸다(조용한 no-op 금지).
CREATE OR REPLACE FUNCTION public.assign_pet_to_enclosure(
  p_pet_id       uuid,
  p_enclosure_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_pet_owner uuid;
  v_enc_owner uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated'
      USING ERRCODE = 'invalid_authorization_specification';
  END IF;

  SELECT p.user_id INTO v_pet_owner
    FROM public.pets p WHERE p.id = p_pet_id;

  IF v_pet_owner IS NULL THEN
    RAISE EXCEPTION 'pet % not found', p_pet_id USING ERRCODE = 'no_data_found';
  END IF;
  IF v_pet_owner <> v_uid THEN
    RAISE EXCEPTION 'pet % is not owned by caller', p_pet_id
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_enclosure_id IS NOT NULL THEN
    SELECT e.owner_id INTO v_enc_owner
      FROM public.enclosures e WHERE e.id = p_enclosure_id;

    IF v_enc_owner IS NULL THEN
      RAISE EXCEPTION 'enclosure % not found', p_enclosure_id
        USING ERRCODE = 'no_data_found';
    END IF;
    IF v_enc_owner <> v_uid THEN
      RAISE EXCEPTION 'enclosure % is not owned by caller', p_enclosure_id
        USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- 1:1 유지: 대상 사육장의 기존 점유 개체를 먼저 비운다.
    -- 부분 UNIQUE 인덱스는 문장 단위로 즉시 검사되므로 이 순서여야 한다.
    UPDATE public.pets
       SET enclosure_id = NULL, updated_at = now()
     WHERE enclosure_id = p_enclosure_id
       AND id <> p_pet_id;
  END IF;

  UPDATE public.pets
     SET enclosure_id = p_enclosure_id, updated_at = now()
   WHERE id = p_pet_id;
END;
$$;

REVOKE ALL ON FUNCTION public.assign_pet_to_enclosure(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_pet_to_enclosure(uuid, uuid) TO authenticated;

COMMIT;
```

> **설계 메모 — 점유 해제 UPDATE에 `user_id` 조건을 넣지 않은 이유:**
> 넣으면 타 계정 소유의 dangling 배정이 남아 있을 때 해제되지 않아 UNIQUE 위반으로 영구히 막힌다. 함수는 SECURITY DEFINER라 정리가 가능하고, 애초에 가드 트리거가 신규 cross-owner 배정을 차단하므로 이 UPDATE가 남의 정상 데이터를 건드릴 경로는 없다. (적용 시점 기존 배정은 전부 NULL이라 dangling 자체가 0건)

---

## 4. 검증 — 적용 직전/직후 비교 (고정값 금지)

`total=7` 같은 고정 기대값은 쓰지 않는다. 조사 시점과 적용 시점 사이에 개체가 늘거나 줄면 검증이 거짓 실패/거짓 성공한다.

### 4-1. 적용 **직전** — 기준값 기록

```sql
SELECT count(*) AS total_before FROM public.pets;
```

→ 결과를 **기록**한다. (예: `total_before = N`)

### 4-2. 적용 **직후** — 불변성 확인

```sql
SELECT
  count(*)              AS total_after,     -- 기대: total_before 와 동일
  count(enclosure_id)   AS assigned_after   -- 기대: 0 (기존 행은 전부 NULL)
FROM public.pets;
```

**합격 조건: `total_after = total_before` AND `assigned_after = 0`.**

### 4-3. 객체 생성 확인

```sql
SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name='pets' AND column_name='enclosure_id';
-- 기대: enclosure_id | uuid | YES

SELECT indexname FROM pg_indexes
 WHERE schemaname='public' AND tablename='pets' AND indexname='pets_enclosure_id_unique';
-- 기대: 1행

SELECT tgname FROM pg_trigger
 WHERE tgrelid='public.pets'::regclass AND tgname='pets_enclosure_owner_guard_trg';
-- 기대: 1행

SELECT p.proname, p.prosecdef, p.proconfig
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN ('assign_pet_to_enclosure','pets_enclosure_owner_guard');
-- 기대: 2행, prosecdef=true, proconfig에 search_path 포함
```

### 4-4. 음성 테스트 — **데이터 훼손 없이**

> 아래는 **실패해야 정상**인 시험이다. 프로덕션에서 그냥 실행하면 실제 행이 바뀔 수 있으므로,
> **(권장) 브랜치/테스트 프로젝트에서 실행**하거나, 불가피하면 **아래처럼 트랜잭션 안에서 실행하고 반드시 ROLLBACK** 한다.
> 문장이 에러를 내면 트랜잭션은 이미 abort 상태이므로 `ROLLBACK`으로 닫으면 된다. **`COMMIT` 금지.**

```sql
-- (A) 존재하지 않는 사육장 → 실패해야 정상
BEGIN;
  UPDATE public.pets
     SET enclosure_id = '00000000-0000-0000-0000-000000000000'
   WHERE id = (SELECT id FROM public.pets LIMIT 1);
  -- 기대: ERROR (FK violation 또는 가드의 'enclosure ... not found')
ROLLBACK;

-- (B) 1:1 위반 → 실패해야 정상
--     같은 사육장에 개체 둘을 배정 시도
BEGIN;
  WITH e AS (SELECT id, owner_id FROM public.enclosures LIMIT 1)
  UPDATE public.pets p
     SET enclosure_id = (SELECT id FROM e)
   WHERE p.user_id = (SELECT owner_id FROM e)
     AND p.id IN (SELECT id FROM public.pets
                   WHERE user_id = (SELECT owner_id FROM e) LIMIT 2);
  -- 기대: ERROR duplicate key value violates unique constraint
  --       "pets_enclosure_id_unique"
ROLLBACK;

-- (C) 소유권 불일치 → 실패해야 정상
--     타 계정 사육장을 가리키는 시도. 테스트 계정 2개가 있을 때만 의미 있음.
BEGIN;
  UPDATE public.pets
     SET enclosure_id = (SELECT id FROM public.enclosures
                          WHERE owner_id <> (SELECT user_id FROM public.pets
                                              WHERE id = :pet_id) LIMIT 1)
   WHERE id = :pet_id;
  -- 기대: ERROR ownership mismatch: pets.user_id=... enclosures.owner_id=...
ROLLBACK;
```

### 4-5. RPC 정상 경로 (배정 데이터가 생기는 시험)

RPC 실동작 확인은 **Owner canary 단계**(§6-5)에서 실사용자 1명으로 수행한다. 여기서 미리 임의 데이터를 만들지 않는다.

---

## 5. 롤백 정책

**배정 데이터 존재 여부로 갈린다.**

### 5-1. 실제 배정이 아직 0건일 때 (`SELECT count(enclosure_id) FROM pets` = 0)

컬럼 삭제 롤백 허용:

```sql
BEGIN;
DROP TRIGGER IF EXISTS pets_enclosure_owner_guard_trg ON public.pets;
DROP FUNCTION IF EXISTS public.assign_pet_to_enclosure(uuid, uuid);
DROP FUNCTION IF EXISTS public.pets_enclosure_owner_guard();
DROP INDEX IF EXISTS public.pets_enclosure_id_unique;
ALTER TABLE public.pets DROP COLUMN IF EXISTS enclosure_id;
COMMIT;
```

### 5-2. 실제 배정 데이터가 생긴 뒤 — **컬럼 삭제 금지**

`DROP COLUMN`은 사용자의 배정 정보를 복구 불가능하게 지운다. 대신 **roll-forward**:

```sql
-- ① 쓰기 경로만 차단 (데이터 보존)
REVOKE EXECUTE ON FUNCTION public.assign_pet_to_enclosure(uuid, uuid) FROM authenticated;
```

② 앱은 feature flag(`kPetEnclosureAssignmentEnabled = false`)로 배정 UI를 끈다 — 앱 배포 없이 끄려면 원격 설정이 필요하므로, 급하면 ①만으로도 쓰기는 즉시 막힌다(앱은 예외를 받아 토스트 표시).
③ 문제를 고친 새 마이그레이션을 올린다. 컬럼과 데이터는 그대로 둔다.

---

## 6. 배포 순서 (역순 진행 금지)

| # | 단계 | 담당 | 완료 판정 |
|---|---|---|---|
| 1 | **DB 마이그레이션** | petcam-lab | §3 트랜잭션 COMMIT 성공 |
| 2 | **DB 검증** | petcam-lab | §4-1~4-4 전부 합격 + 결과 회신 |
| 3 | **Flutter repository 배선/테스트** | tera-ai-flutter | 앱 계획 F1~F3, `flutter test` 통과 |
| 4 | **배정 UI 활성화** | tera-ai-flutter | flag on + F4, 실기기 확인 |
| 5 | **Owner canary** | 양쪽 | 소유자 계정 1명이 배정/해제/교체 왕복, `enclosure_id` 정합 확인 |

**2단계 결과 회신 전에는 3단계를 시작하지 않는다.** 앱이 없는 컬럼을 전제로 배선되면 런타임에서만 터진다.

---

## 7. 역할 분리

| 영역 | petcam-lab (백엔드) | tera-ai-flutter (앱) |
|---|---|---|
| 스키마 변경 | **전담** — 컬럼/인덱스/트리거/RPC | **금지** — 조회만 |
| 마이그레이션 적용 | **전담** | **금지** |
| 1:1 보장 | UNIQUE 인덱스 + RPC 원자성 | RPC 호출만. 클라이언트 보정 로직 없음 |
| 소유권 검증 | 가드 트리거 + RPC 내부 검사 | 서버 예외를 그대로 사용자에게 전달 |
| 배정 쓰기 | `assign_pet_to_enclosure` RPC | **RPC 1회 호출.** `pets` 직접 UPDATE 금지 |
| 배정 읽기 | `pets.enclosure_id` 노출 | `syncFromRemote()`에서 Hive로 복원 |
| 롤백 판단 | 데이터 유무로 §5 분기 | flag off로 UI 차단 |

앱측 상세 태스크는 [`docs/plans/2026-08-06-pet-enclosure-assignment.md`](plans/2026-08-06-pet-enclosure-assignment.md).

---

## 8. 백엔드에 요청하는 회신 항목

2단계 완료 시 아래를 회신해 주세요. 앱 배선 착수 조건입니다.

- [ ] `total_before` / `total_after` / `assigned_after` 실측값
- [ ] §4-3 객체 4종 생성 확인 결과
- [ ] §4-4 음성 테스트 (A)(B) 결과 — 각각 어떤 에러가 났는지. (C)는 테스트 계정 2개가 있을 때만
- [ ] 음성 테스트를 어디서 돌렸는지 (브랜치/테스트 프로젝트 vs 프로덕션 트랜잭션 롤백)
- [ ] `assign_pet_to_enclosure` 의 `authenticated` EXECUTE 권한 부여 확인
