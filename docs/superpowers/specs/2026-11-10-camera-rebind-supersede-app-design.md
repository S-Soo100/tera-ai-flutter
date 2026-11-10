# 카메라 재등록 되살리기 · 교차 계정 `superseded_at` — 앱 반영 기획

- 작성: 2026-11-10 · **구현 완료 0.175.11+502** (§2-1~2-3, 테스트 4건 추가)
- 근거: terra-server `reports/APP_CAMERA_REBIND_SUPERSEDE_2026-11-10_v2.md` (PR #60 `78427c1`, #61 `83654fc`, 운영 배포 완료)
- CAOF 트랙: **Standard** — `lib/` 3파일, 목록 표시 동작 변경, 되돌리기 1시간 이내

## 1. 서버가 바뀐 것 (요약)

| 변경 | 앱 영향 |
|---|---|
| ① 같은 계정이 해제한 보드를 다시 등록하면 **가장 최근 해제 행을 되살림** (`revived: true`, 같은 `cameras.id`, 과거 영상 다시 보임, 이름·사육장·회전은 요청값으로 초기화) | 코드 변경 없음. 아래 §3 확인만 |
| ② 다른 계정이 같은 보드를 등록하고 새 행 온라인 + 옛 행 24시간+ 오프라인이면 옛 행에 `superseded_at` (해제 아님, `unlinked_at`은 NULL) | **목록에서 숨겨야 함** — 안 하면 "오프라인 카메라"로 계속 보인다 |

운영 DB 확인(2026-11-10, 읽기 전용 SQL):
- `superseded_at`·`superseded_by`·`supersede_suspect_at`·`mqtt_revoked_at`은 **`cameras`에만** 있다. `devices`엔 없다.
- 지금 숨김 대상 **13행**(13개 계정, 모두 `unlinked_at` NULL) — 보고서 작성 시점 10행에서 늘었다. 앱 필터 전까지 이 계정들에 오프라인 유령 카메라로 보인다.

## 2. 고칠 곳

### 2-1. `lib/features/my_cage/data/camera_repository.dart`
- `listAll()` (30줄): `.where((r) => r['unlinked_at'] == null && r['superseded_at'] == null)`
- `getById()` (38줄): `superseded_at`이 있어도 null 반환
- 주석(20줄)에 "다른 계정이 가져간 보드의 옛 행도 뺀다(2026-11-10 서버 계약)" 추가
- `cameras-rt` Realtime이 변경마다 `listAll()`을 다시 읽으므로 숨김·복구는 자동 반영된다(`my_cage_providers.dart:156`).

### 2-2. `lib/features/my_cage/data/redesign_group_repository.dart` (120줄)
- 카메라 줄만: `if (row['unlinked_at'] == null && row['superseded_at'] == null)`
- **사육장 줄(118줄)은 건드리지 않는다**(컬럼 없음 — 읽어도 null이라 무해하지만 의미가 없다).
- `_loadRows`는 `select()` 전체 조회라 컬럼 추가 불필요.

### 2-3. `lib/features/my_cage/data/device_add_registration_repository.dart` `owned()` (64·69줄) — ⚠️ 보고서에 없는 함정
- `owned()`는 **사육장·카메라 공용**이다. 보고서 안내대로 select 문자열에 `superseded_at`을 그냥 붙이면 **`devices` 조회가 400**(없는 컬럼)으로 실패한다.
  - 실패 영향: 기기 추가의 `knownId`/`registered`가 예외 → 사육장 "이미 등록됨" 배지·Wi-Fi만 바꾸기 판정이 깨진다.
- 해결: 종류별로 select를 나눈다.
  - 카메라: `'id,last_seen_at,hw_id,is_online,unlinked_at,superseded_at'`
  - 사육장: 지금 그대로
  - 판정: `unlinked_at != null || superseded_at != null` → null (사육장 행은 `superseded_at` 키가 없어 null)
- 의미: 이 폰이 기억한 카메라가 다른 계정으로 넘어갔으면 "새로 등록"으로 보낸다 → 서버가 원래 계정 재등록이면 `superseded_at`을 풀어 같은 행으로 돌려준다(PR #61).

### 2-4. 바꾸지 않는 곳 (근거)
| 위치 | 이유 |
|---|---|
| `names()` (35줄, 이름 중복 번호) | 보고서 권고대로 유지 — 숨긴 카메라 이름이 번호 계산에 남는 정도 |
| `confirm()` (PAIR_OK 확인) | 되살리기·복구 모두 **같은 행**을 돌려주므로 `camera_id` 1행 조건 그대로 성립 |
| `_unlinkReplaced()` (`device_add_flow_controller.dart:776`) | `old == newId`면 해제하지 않는 가드가 이미 있다 → "새 카메라로 등록"이 되살린 행을 스스로 해제하는 사고 없음 |
| 영상 조회(`motion_clips`·petcam-api) | 카메라 id 단위 조회라 숨긴 카메라의 영상은 목록과 함께 빠진다 — 해제와 같은 동작 |
| 라이브 시청 기록·`cameraLiveSessionProvider`·`cameraHealthProvider` | 숨김 대상은 24시간+ 오프라인이라 시청 중일 수 없다 |
| `supabase_module_providers.dart:257` | 사육장(`devices`) 전용 — 대상 아님 |

## 3. 되살리기(①) 확인 항목 — 구현 때 코드로 확인

| 로컬 저장 | 확인할 것 | 예상 |
|---|---|---|
| `known_device_store` (BLE→행 id) | 해제 때 지우는지, 되살아난 같은 id 저장 시 충돌 | 같은 id 덮어쓰기라 무해 |
| `device_wifi_name_store` (행 id→SSID) | 해제 때 안 지우면 옛 SSID가 남는지 | 재등록 성공 시 `_saveWifi`가 새 SSID로 덮어씀 → 무해 |
| `highlight_read_store`·`highlight_banner_store` | 옛 영상 읽음 표시가 되살아남 | 이미 본 영상이라 읽음 유지가 맞다 |
| 홈 선택·순서 기억(0.174.8) | 되살아난 id가 옛 순서 자리로 돌아가는지 | 무해(오히려 자연스러움). 그대로 둠 |
| 자동 묶기(`groupConfirmed`) | 되살아난 행도 `registered` 결과라 새 그룹 묶기에 들어가는지 | 들어가야 맞다 — 서버가 `enclosure_id`를 NULL로 초기화하므로 |

사용자에게 보이는 변화: 되살린 카메라는 **180° 회전이 꺼진 상태**로 돌아온다(서버가 false로 초기화). 거꾸로 설치한 사용자는 환경설정에서 다시 켜야 한다 — 앱 변경 범위 밖, 안내만.

## 4. 유저 체험 시뮬레이션

1. **A 계정 사용자** — 쓰던 카메라를 중고로 넘김. B가 자기 계정으로 등록.
2. B의 카메라가 온라인이 되고 A 쪽 옛 행이 24시간 넘게 오프라인 → 서버가 10분 주기 스캔에서 `superseded_at`을 찍는다.
3. A의 앱: Realtime UPDATE → 목록 재조회 → 홈 드롭다운·카메라 탭 라이브 넘기기·기기 관리에서 **그 카메라가 조용히 사라진다**. 그 카메라의 영상 목록·하이라이트도 같이 빠진다. 알림·안내는 없다.
4. 그 카메라가 속했던 그룹은 "카메라 없음"으로 보인다.
5. 보드가 다시 A 자격증명으로 접속하거나 A가 다시 등록하면 → 서버가 `superseded_at`을 NULL로 → A 목록에 **같은 카메라가 돌아온다**.
6. **B 계정 사용자** — 아무 변화 없음.

## 5. 가정

| 가정 | 상태 |
|---|---|
| 새 컬럼은 `cameras`에만 있다 | **확인** (운영 information_schema) |
| `cameras-rt`가 숨김·복구 UPDATE를 A 계정에도 전달한다 (행 소유자는 그대로 A) | 미확인 — RLS가 owner 기준이라 그럴 것. 실기 확인 항목 |
| 운영 `redesign_save_group_v1`이 `supabase/drafts/20260915_redesign_groups.sql`과 같다 | 미확인 (draft 기준으로 §6 판단) |
| 같은 계정 재등록 시 PR #61이 `enclosure_id`를 유지하는지 초기화하는지 | 미확인 — 보고서에 없음 |

## 6. 실패 시나리오

1. **`owned()` 공용 select에 컬럼 추가** → 사육장 조회 400 → 사육장 추가·Wi-Fi 바꾸기 판정 붕괴. → §2-3처럼 종류별 분기 + 사육장 select 문자열에 `superseded_at`이 없음을 테스트로 고정.
2. **숨긴 카메라가 든 그룹을 저장하면 그 카메라가 그룹에서 빠진다** (새 부작용): 앱은 그룹에 카메라가 없다고 보므로 `p_camera_id = null`로 저장 → RPC(draft 178줄)가 그 그룹의 다른 카메라 `enclosure_id`를 NULL로 → 숨긴 카메라의 사육장·열린 반려동물 배정이 닫힌다. 나중에 보드가 돌아와 복구돼도 그룹 밖으로 돌아온다. 서버 문서의 "설정 그대로"와 어긋난다.
   - **결정(2026-11-10 사용자): A — 앱은 바꾸지 않고 서버에 알린다.** 전달문 `docs/handoffs/2026-11-10-camera-supersede-group-save-note.md`.
   - 선택지 A(채택): **받아들이고 서버에 알린다.** 24시간+ 오프라인 + 다른 계정 등록 뒤 복구는 드물고, 앱이 숨긴 행을 그룹 저장에 끼우면 숨김 의미가 흐려진다.
   - 선택지 B: 서버 RPC가 `superseded_at IS NOT NULL` 카메라는 detach에서 빼도록 서버에 요청.
   - 선택지 C: 앱이 숨긴 카메라를 `p_expected_members`에 넣어 보존 — 복잡하고 화면과 저장 내용이 달라져 비추천.
3. 필터를 `listAll()`만 고치고 `getById()`를 빼먹으면 → 북마크·딥링크로 들어간 숨긴 카메라 상세가 열린다. 3곳 모두 고친다.

## 7. 검증 방법 (구현 전 확정)

- 단위 테스트 (기존 파일에 추가):
  - `test/features/my_cage/redesign_group_repository_test.dart` (~200줄 `unlinked_at` 케이스 옆): `superseded_at` 카메라 제외, 사육장 행은 영향 없음
  - `test/features/my_cage/device_add_registration_repository_test.dart` (~97줄 옆): 카메라 `superseded_at` → null / **사육장 조회 select에 `superseded_at` 미포함**
  - `CameraRepository` 테스트는 없음 → `listAll`·`getById` 필터 테스트 신설(가짜 Supabase 응답)
- `flutter analyze` 0, `flutter test` 관련 테스트 통과
- 운영 데이터 대조(읽기 전용): 숨김 13행 계정 중 테스트 가능한 계정이 있으면 앱 목록에서 사라지는지 — **사용자만 확인 가능**(타 계정)
- 버전: 0.175.x patch bump + `CHANGELOG.md` "수정: 다른 계정으로 넘어간 카메라가 오프라인으로 남던 문제"

## 8. 사용자가 정할 것

1. ~~§6-2 그룹 저장 부작용~~ — **A로 결정(2026-11-10)**: 앱 변경 없음, 서버에 알림.
2. 카메라가 조용히 사라지는 것으로 충분한지, "다른 계정에 등록된 카메라" 안내가 필요한지 — 추천: 이번엔 조용히 숨김(서버 계약 그대로), 문의가 생기면 후속.
3. 구현 시점 — 다른 세션이 끝난 뒤 `tools/worktree.sh new fix/camera-supersede`로 최신 main에서.
