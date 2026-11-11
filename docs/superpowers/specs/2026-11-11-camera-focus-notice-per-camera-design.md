# 카메라 렌즈 초점 안내 — 카메라 단위로 정책 변경 (기획)

- 작성: 2026-11-11
- 상태: **확정 (2026-11-11 사용자 합의)** — §8 결정 반영
- 바뀌는 대상: 2026-11-10에 출시한 사람 단위 안내(0.176.0~0.176.5)
  - 계획 `docs/superpowers/plans/2026-11-10-camera-focus-notice.md`
  - 운영 문서 `docs/ops/camera-focus-notice.md`
- Figma: `Final Design` › `카메라 초점`(1813:8269)

## 1. 왜 바꾸나

지금은 안내가 **사람 단위**다. 운영자가 사용자 한 명에게 보내면, 그 사람이 어느 카메라 라이브를 보든 막대가 뜬다. 하지만 초점이 흐린 것은 **특정 카메라**의 문제다. 멀쩡한 카메라에도 "초점을 맞춰주세요"가 뜨면 사용자가 어느 카메라를 고쳐야 하는지 알 수 없다.

## 2. 사용자 결정 (2026-11-11)

| # | 결정 |
|---|---|
| D1 | 카메라 확대(상세) 화면의 '카메라 초점 가이드'는 **지금처럼 항상 보인다** (변경 없음) |
| D2 | 서버(운영자)가 **카메라를 지정해서** 안내를 보낸다. 라이브 위 막대는 **그 카메라의 라이브에서만** 뜬다. 홈·카메라 탭 모두 해당하고, 다른 카메라 라이브에는 뜨지 않는다 |
| D3 | 막대를 누르면 그 카메라 상세로 가고, **그 카메라 안내만** 읽음 처리돼 사라진다 (1회성 유지) |

## 3. 유저 체험

1. 사용자 A는 카메라 '거실'과 '침실' 두 대를 쓴다. 운영자가 '침실'(기기 ID `p4cam-…`)에 초점 안내를 보낸다.
2. A가 홈을 연다. 홈 세트가 '거실'이면 막대가 **없다**. 세트를 '침실'로 바꾸면 라이브가 나온 뒤 막대가 뜬다.
3. 카메라 탭에서도 '거실'에는 없고, '침실'로 넘기면 뜬다.
4. 막대를 누르면 '침실' 상세가 열리고 초점 가이드를 본다. 돌아오면 '침실' 막대도 사라졌다. 다른 기기에서도 사라진다.
5. 운영자가 '거실'에도 따로 보내면, '거실' 막대는 '침실'과 상관없이 따로 뜨고 따로 사라진다.
6. 알림함에는 "카메라 렌즈 초점을 맞춰주세요"가 남는다(문구는 v1·Figma 그대로). 누르면 **그 카메라** 상세로 간다.
7. 카메라 상세의 초점 가이드는 안내를 받았든 안 받았든 항상 보인다.

## 4. 계약 v2 (운영자 → 앱)

v1과 같은 테이블·같은 kind를 쓰고, 카메라 지정 하나만 더한다.

| 필드 | v1 (사람 단위) | **v2 (카메라 단위)** |
|---|---|---|
| 테이블 | `app_notifications` 직접 INSERT | 같음 |
| kind / category | `camera.focus_needed` / `camera` | 같음 |
| user_id | 대상 이메일로 찾음 | **카메라의 `owner_id`** (운영자가 이메일을 몰라도 됨) |
| data | `{"kind","source"}` | **`camera_id` 추가 = `cameras.id`(uuid)**. 사람이 읽을 수 있게 `camera_name`·`device_id`(기기 ID)도 함께 넣는다 |
| title | 카메라 렌즈 초점을 맞춰주세요 | 같음 |
| body | 영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요 | 같음 (Q1: 문구는 Figma 그대로) |
| route | `/crecam` | `/crecam/cameras/<cameras.id>/live` (기록용, 앱은 data.camera_id로 판단) |
| dedupe_key | `ops-focus:<uuid>` | 같음 |

**앱이 요구하는 것은 두 가지뿐이다:** `user_id` = 그 카메라의 `owner_id`, `data.camera_id` = 그 카메라의 `cameras.id`. 카메라를 어떻게 지정할지(기기 ID·관리 화면 등)는 서버가 정한다(Q2). 아래는 기기 ID로 보내는 예시다.

**예시 SQL (기기 ID 하나만 바꾼다)**

```sql
insert into public.app_notifications
  (user_id, kind, category, title, body, route, data, source, source_event_id, dedupe_key)
select c.owner_id, 'camera.focus_needed', 'camera',
       '카메라 렌즈 초점을 맞춰주세요', '영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요',
       '/crecam/cameras/' || c.id || '/live',
       jsonb_build_object('kind', 'camera.focus_needed', 'source', 'external',
                          'camera_id', c.id, 'device_id', c.camera_id, 'camera_name', c.name),
       'external', e.id, 'ops-focus:' || e.id
from public.cameras c, (select gen_random_uuid()::text as id) e
where c.camera_id = '<기기 ID>'
  and c.unlinked_at is null and c.superseded_at is null and c.owner_id is not null;
```

- 결과가 `INSERT 0 1`이 아니면 보내지지 않은 것이다. 원인은 기기 ID 오타, 연결 해제된 카메라, 다른 계정으로 넘어간 카메라 중 하나다.
- `cameras.camera_id`는 DB 전체에서 UNIQUE다. 반면 카메라 이름은 같은 계정 안에서도 겹치는 경우가 1건 있어(2026-11-11) 식별자로 쓰지 않는다.

## 5. 앱 동작

| 상황 | 동작 |
|---|---|
| 라이브 위 막대 | 지금 보이는 카메라의 `cameras.id`와 같은 `data.camera_id`를 가진 미읽음 안내가 있을 때만. 영상이 나올 때만(streaming·stalled) 보이는 규칙은 그대로 |
| 막대 누름 | 그 카메라 상세로 이동 → **그 카메라의** 미읽음 안내만 전부 읽음 |
| 알림함에서 누름 | `data.camera_id` 카메라가 내 목록에 있으면 그 상세로 이동 + 그 카메라 안내 전부 읽음. 없으면(연결 해제·이관) 카메라 탭으로 이동(`go`) |
| `data.camera_id`가 없는 안내 (v1 사람 단위 행) | **막대 없음.** 알림함에만 남고, 누르면 v1처럼 고른 카메라 상세로 간다. (운영 DB의 v1 행은 전부 읽음 상태 — 2026-11-11 확인) |
| 안내 대상 카메라가 내 목록에 없음 | 막대가 뜰 라이브가 없으니 자연히 안 뜬다. 알림함에만 남는다 |
| 카메라 상세의 초점 가이드 | 항상 보임 (변경 없음) |
| 구버전 앱(0.176.x) | 고려하지 않는다(Q3). 사람 단위 로직이라 v2 행을 받으면 모든 카메라에 막대가 뜬다 |

## 6. 바뀌는 범위 (예상)

앱:
- `notification/presentation/focus_notice_providers.dart`: id 목록 → 카메라별 묶음. `focusNoticeVisibleProvider(cameraId)` family, `dismissFocusNotices(ref, cameraId)`
- `my_cage/presentation/widgets/focus_notice_snack_bar.dart`: 자기 카메라 기준
- `notification/presentation/notification_center_screen.dart` + `domain/focus_notice_target.dart`: data.camera_id 우선
- `notification/domain/app_notification.dart`: `focusCameraId` getter
- 테스트, `docs/ops/camera-focus-notice.md`, CHANGELOG, 버전 minor

서버 (terra-server, 앱이 고치지 않음):
- `docs/OPERATIONS.md` "1-3"(PR gwanhun/terra-server#63, 머지 전)을 v2 SQL로 갱신해 달라고 전달

바꾸지 않는 것: DB 스키마·트리거·RLS, 초점 가이드, 막대 모양·문구·위치, 카메라 상세 레이아웃

## 7. 가정·실패 시나리오

- 확인: `cameras.camera_id` UNIQUE, `cameras.id`가 앱 `TerraCamera.id`. 홈·카메라 탭 라이브 위젯은 이미 `cameraId`를 막대에 넘기고 있다. 운영 DB의 v1 행은 모두 읽음 상태다.
- 미확인: 운영자가 기기 ID(`p4cam-…`)를 어디서 확인하는지(관리 웹 콘솔에 보이는지).
- 실패 시나리오:
  - 운영자가 v1 SQL(이메일)로 보냄 → 카메라 지정이 없어 막대가 안 뜬다. 알림함에만 남는다. 운영 문서와 서버 문서를 v2로 함께 바꿔 막는다.
  - 카메라가 다른 계정으로 넘어간 뒤 보냄 → SQL 조건(`superseded_at is null`)에서 0행이 된다.
  - 사용자가 알림함 "모두 읽음"을 누름 → 모든 카메라 막대가 사라진다(v1과 같음, 의도).

## 8. 결정 (2026-11-11 사용자)

- **Q1 문구:** 모든 문구는 Figma 그대로. 막대·알림 제목·본문 모두 v1과 같고, 카메라 이름은 넣지 않는다.
- **Q2 카메라 지정 방법:** 서버가 알아서 정한다. 앱 계약은 `user_id`(카메라 주인)와 `data.camera_id`(`cameras.id`) 두 가지뿐이다.
- **Q3 구버전 앱:** 버린다(대응하지 않음).

## 9. 검증

- 단위·위젯 테스트: 카메라 A 안내 → A 라이브에만 막대, B에는 없음. A 누름 → A만 읽음, B 안내는 그대로. data.camera_id 없는 행 → 막대 없음. 알림함 → A 상세.
- 실기(13 mini, tester01): 카메라 두 대에 따로 보내 홈·카메라 탭에서 확인. 확인 후 행을 읽음 처리해 정리.
