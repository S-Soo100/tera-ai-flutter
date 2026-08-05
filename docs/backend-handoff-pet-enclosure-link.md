# 백엔드 핸드오프 — 개체↔사육장 연결 (`pets.enclosure_id`) (2026-08-05)

> 대상: petcam-lab / terra-server
> 배경: Flutter 앱 홈 탭 PRD 재설계 구현 중, **개체(pet)와 사육장(enclosure)을 잇는 필드가 어디에도 없어** 막힌 지점입니다.
> 관련 앱 문서: `docs/prd-vivanart-app.md` (§2 전제), `docs/plans/2026-08-05-prd-redesign.md` (Task 3)
> 상태: **미적용.** 앱은 이 컬럼 없이도 죽지 않고, 배정 기능만 비활성입니다.

---

## 요약 (TL;DR)

| 항목 | 내용 |
|---|---|
| 요청 | `pets` 테이블에 `enclosure_id UUID` 컬럼 추가 (nullable, FK → `enclosures.id`) |
| 왜 | PRD 전제가 "사육장 1 : 캠 1 : 개체 1". 홈 헤더 `젤리 (1번 사육장)`·사육장 단품 프로필 카드(D-Day·체중)가 전부 이 연결에 의존 |
| 로컬 저장으로 안 되는 이유 | `SupabasePetRepository.syncFromRemote()`가 Hive box를 **clear 후 Supabase 행으로 재구성**한다. 서버에 컬럼이 없으면 동기화 1회로 배정이 전량 소실 |
| 위험도 | 낮음 — nullable 가산 컬럼, 기존 행 무영향, 롤백 1줄 |
| 미적용 시 앱 | 정상 동작. 헤더가 개체명 없이 사육장명만 표시, 배정 UI 미노출 |

---

## 확인된 사실 (실 DB 조회, 2026-08-05)

```sql
-- pets 컬럼 14개 전수 확인 → enclosure_id 없음
id, user_id, species_id, name, species_name, morph, sex,
birth_date, adoption_date, weight, avatar_url, memo, created_at, updated_at
```

- `enclosures` 테이블 **존재**, `enclosures.id` = `uuid`, `pets.id` = `uuid` → FK 타입 호환
- 현재 데이터: `enclosures` 1행 / `pets` 7행
- RLS 현황
  - `enclosures`: `own enclosures all` — `ALL`, `auth.uid() = owner_id`
  - `pets`: SELECT/INSERT/UPDATE/DELETE 각각 `auth.uid() = user_id`

---

## 마이그레이션

### UP

```sql
-- 개체를 사육장 세트에 연결한다 (PRD 전제: 사육장 1 : 캠 1 : 개체 1).
-- nullable 가산 컬럼이라 기존 7행은 전부 NULL로 채워지고 동작 영향이 없다.
-- ON DELETE SET NULL: 사육장을 지워도 개체 레코드는 남기고 배정만 해제한다
--   (CASCADE로 개체가 지워지면 사용자 데이터가 사라진다 — 절대 금지).
ALTER TABLE public.pets
  ADD COLUMN enclosure_id UUID
  REFERENCES public.enclosures(id) ON DELETE SET NULL;

-- 홈 진입 시 "이 사육장의 개체" 조회가 매번 돈다.
CREATE INDEX IF NOT EXISTS pets_enclosure_id_idx
  ON public.pets (enclosure_id)
  WHERE enclosure_id IS NOT NULL;
```

### 검증

```sql
-- 1) 컬럼 생성 확인
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'pets' AND column_name = 'enclosure_id';
-- 기대: enclosure_id | uuid | YES

-- 2) 기존 행 무영향 확인 (7행 전부 NULL)
SELECT count(*) AS total, count(enclosure_id) AS assigned FROM public.pets;
-- 기대: total=7, assigned=0

-- 3) FK 동작 확인 — 존재하지 않는 사육장으로는 배정 불가
--    (실행하면 실패해야 정상. 성공하면 FK가 안 걸린 것)
-- UPDATE public.pets SET enclosure_id = gen_random_uuid() WHERE id = (SELECT id FROM public.pets LIMIT 1);
-- 기대: ERROR insert or update on table "pets" violates foreign key constraint
```

### 롤백

```sql
DROP INDEX IF EXISTS public.pets_enclosure_id_idx;
ALTER TABLE public.pets DROP COLUMN IF EXISTS enclosure_id;
```

---

## 설계 판단 2건 (합의 필요)

### ① `enclosures`에 FK를 걸어도 되는가

`pets`는 앱 테이블, `enclosures`는 terra-server 테이블이라 **테이블 소유 경계를 넘는 FK**가 된다. 부담되면 FK 없이 UUID 컬럼만 두는 선택지도 있다.

| | FK 있음 (제안) | FK 없음 |
|---|---|---|
| 무결성 | 없는 사육장 배정 차단, 삭제 시 자동 해제 | 앱이 dangling 참조를 직접 정리해야 함 |
| 결합도 | 두 테이블이 스키마 수준에서 묶임 | 느슨함 |
| 마이그레이션 순서 | `enclosures`가 먼저 존재해야 함 (이미 존재) | 무관 |

**제안: FK 있음.** 삭제 시 자동 해제(`SET NULL`)를 앱이 대신 구현하면 누락되기 쉽다.

### ② 1:1을 DB로 강제할 것인가 (`UNIQUE(enclosure_id)`)

**제안: 강제하지 않음.** 배정 변경 시 "기존 해제 → 신규 배정" 2단계가 되는데, UNIQUE가 걸리면 중간 상태에서 제약 위반이 나 UX가 나빠진다. 1:1은 앱에서 교체(swap) 방식으로 보장한다.

거는 쪽으로 결정되면 아래를 추가하면 된다:

```sql
CREATE UNIQUE INDEX pets_enclosure_id_unique
  ON public.pets (enclosure_id)
  WHERE enclosure_id IS NOT NULL;
```

---

## 선택 사항 — 소유권 정합성 (보안 하드닝)

현재 `pets` UPDATE RLS는 `auth.uid() = user_id`만 본다. **`enclosure_id`가 남의 사육장을 가리키는 것은 막지 않는다.**

실피해는 작다 — `enclosures` RLS가 `owner_id` 기준이라 그 사육장을 **읽지는 못한다**. 다만 cross-owner dangling 참조가 쌓인다. 신경 쓰인다면:

```sql
CREATE OR REPLACE FUNCTION public.pets_enclosure_owner_guard()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.enclosure_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.enclosures e
       WHERE e.id = NEW.enclosure_id AND e.owner_id = NEW.user_id
     )
  THEN
    RAISE EXCEPTION '본인 소유 사육장에만 개체를 배정할 수 있습니다';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER pets_enclosure_owner_guard_trg
  BEFORE INSERT OR UPDATE OF enclosure_id ON public.pets
  FOR EACH ROW EXECUTE FUNCTION public.pets_enclosure_owner_guard();
```

**우선순위 낮음.** 단일 사용자 단계에서는 없어도 된다.

---

## 적용 후 앱이 하는 일 (계약)

이 컬럼이 생기면 앱은 아래를 구현한다. 백엔드 추가 작업은 없다.

| 위치 | 변경 |
|---|---|
| `SupabasePetRepository.addPet` / `updatePet` | payload에 `'enclosure_id': pet.enclosureId` 추가 |
| `SupabasePetRepository.syncFromRemote` | `enclosureId: row['enclosure_id'] as String?` **복원 (현재 누락 — 이게 소실 원인)** |
| `enclosure_settings_screen.dart` | "개체 배정" 섹션 — 사육장별 현재 개체 + 선택/해제 시트 |
| 1:1 보장 | 배정 시 ① 같은 개체의 기존 배정 해제 ② 같은 사육장의 기존 개체 해제 → ③ 신규 배정 |

앱측 `Pet.enclosureId`(Hive `@HiveField(13)`)는 **이미 머지됨** (커밋 `3142044`). 서버 컬럼만 생기면 바로 배선 가능.

---

## 적용 방법

Supabase MCP를 쓰는 세션이라면:

```
apply_migration(name: "pets_add_enclosure_id", query: <위 UP 블록>)
```

또는 Supabase 대시보드 SQL Editor에 UP 블록을 그대로 붙여넣으면 된다. 적용 후 **검증 쿼리 3개**를 돌려 결과를 회신 부탁드립니다.
