# 이관훈님 전달용 — SQL 초안 검토 회신에 대한 답 (B1~B5·N2 반영본)

수신: 이관훈님 / terra-server

작성일: 2026-09-16

관훈님, 초안 검토 감사합니다. 배포 전 수정 5건과 N2를 전부 반영했고, 회신 §6의 답 5개는 아래와 같습니다. 격리 PostgreSQL에서 번들 7개 파일과 assertion 3개를 다시 돌려 통과했습니다.

| # | 질문 | 답 |
|:---:|---|---|
| 1 | B2 `camera_id` FK | **`ON DELETE CASCADE`.** hard delete는 "기록까지"가 의미이니 이력도 함께 지웁니다. 서버 변경 없음 |
| 2 | B3 `ON DELETE CASCADE` | **새 테이블 3개 + 기존 `pets.user_id` 전부 적용.** `pets_user_id_fkey`를 drop/add로 교체하는 문장을 `assignment_history` 초안에 넣었습니다 |
| 3 | B4 최신본 | 반영본은 **이 문서와 함께 폴더로** 드립니다. 브랜치 push는 별도로 알려드리겠습니다 |
| 4 | §1 트리거 번들 포함 | **동의.** `20260916_relationship_triggers.sql`로 넣었습니다. 단 한 줄 고쳤습니다(아래 §1) |
| 5 | 적용 주체·순서 | **동의.** 앱 팀이 번들 확정 → 관훈님이 SQL Editor에서 §5 순서로 적용 → `MIGRATIONS_APPLIED.md` 기록 |

---

## 1. 트리거 SQL 한 줄 수정 — 그대로 넣으면 카메라 UPDATE가 실패합니다

주신 함수의 owner 계산이 격리 검증에서 이렇게 죽었습니다.

```
ERROR:  record "new" has no field "user_id"
SQL statement "UPDATE public.cameras SET enclosure_id=target WHERE ..."
```

`CASE TG_TABLE_NAME WHEN 'pets' THEN NEW.user_id ELSE NEW.owner_id END`는 PL/pgSQL이 식을 준비할 때 두 필드를 모두 해석해서, `cameras` 행(`user_id` 없음)에서는 분기와 무관하게 실패합니다. 아래로 바꿨습니다.

```sql
owner := (to_jsonb(NEW) ->> CASE TG_TABLE_NAME WHEN 'pets' THEN 'user_id' ELSE 'owner_id' END)::uuid;
```

나머지(트리거 정의, `RETURN NULL`, advisory lock 금지, `devices` 제외)는 그대로입니다. 잠금 순서 역전 설명도 파일 머리말에 옮겨 적었습니다.

## 2. 반영 내역

| 파일 | 변경 |
|---|---|
| `20260915_assignment_history.sql` | B2 `camera_id … ON DELETE CASCADE`, B3 `user_id … ON DELETE CASCADE`, `pets_user_id_fkey` CASCADE 교체, 머리말을 "트리거가 비앱 경로를 커버" 로 갱신 |
| `20260915_redesign_groups.sql` | B3 `redesign_group_requests`·`redesign_group_counters` `ON DELETE CASCADE`, B4 `redesign_owned_member_group`·`redesign_rename_item_v1` `unlinked_at IS NULL`, N2 `redesign_unlink_device_v1` 스텁·권한 문장 제거(`DROP FUNCTION IF EXISTS`로 정리) |
| `20260916_relationship_triggers.sql` (신규) | §1 트리거 + owner 계산 수정 |
| `20260915_redesign_pets.sql` · `_delete_group.sql` · `_clip_visibility.sql` | 변경 없음 |
| `test/sql/redesign_base_schema.sql` | B5 `devices/cameras.unlinked_at`, `unlink_request_id`, `cameras.clip_stats` 추가 |
| `test/sql/redesign_unlink_trigger_assertions.sql` (신규) | 해제 카메라로 `save_group` → `42501`, 해제 카메라 이름 재사용 허용, **RPC 없이** 카메라 `enclosure_id` UPDATE만으로 이력 열림/닫힘, 해제 UPDATE로 열린 이력 종료(행 보존), 개체 툼스톤 UPDATE로 이력 종료 |
| `tools/verify_redesign_sql.py` | 트리거 파일·새 assertion 포함 |

검증: `docker run … public.ecr.aws/supabase/postgres:17.6.1.104` 격리 컨테이너, `verify_redesign_sql.py` exit 0, 마지막 `ROLLBACK`. 운영 DB는 건드리지 않았습니다.

## 3. 권장 항목(N)에 대한 답

- N1 빈 그룹 자동 정리: 동의. 트리거에 얹지 않습니다.
- N3 REST trim: 감사합니다. 앱 사전 검사·RPC·인덱스가 모두 `btrim` 기준이라 일치합니다.
- N4 유니코드 공백: 동의. 레거시 이름은 개명하지 않습니다.
- N5 성능: 동의. 계정당 카메라 수십 대 시점에 statement 트리거로 전환.

## 4. 적용 순서 확인 (회신 §5 그대로)

1. `20260915_assignment_history.sql`
2. `20260915_redesign_groups.sql`
3. `20260916_relationship_triggers.sql`
4. `20260915_redesign_pets.sql`
5. `20260915_redesign_delete_group.sql`
6. `20260915_clip_visibility.sql`

각 파일의 `BEGIN … ROLLBACK`은 검증기용이라 적용 시 `COMMIT`으로 바꾸거나 벗겨서 실행해 주세요. 적용 뒤 함수명·오류코드가 초안과 같은지 한 줄만 회신 주시면 앱은 변경 없이 붙습니다.

## 5. 앱 쪽 참고

- 앱은 `unlink`를 REST로만 호출하고, RPC 스텁 제거로 바뀌는 것이 없습니다.
- 트리거가 들어가면 앱 RPC는 같은 트랜잭션에서 reconcile을 두 번 돌리는데 멱등이라 무해합니다. 성능 이슈가 보이면 앱 RPC의 명시 호출을 빼는 쪽으로 정리하겠습니다.
