# 카메라 렌즈 초점 안내 보내기 (운영자용) — 카메라 단위

영상이 흐린 **카메라**의 주인에게 "카메라 렌즈 초점을 맞춰주세요" 안내를 보낸다.

- 받은 사용자는 **그 카메라의** 라이브 위(홈·카메라 탭)에 안내 막대가 보인다. 다른 카메라 라이브에는 뜨지 않는다. 알림함에도 남는다.
- 푸시(휴대폰 시스템 알림)는 나가지 않는다.
- 막대나 알림을 한 번 누르면 그 카메라 안내만 읽음 처리되어 모든 기기에서 사라진다. 다른 카메라 안내는 그대로다.
- 같은 카메라에 다시 보내면 다시 뜬다.
- 앱 0.177.0 이상에서 동작한다. 0.176.x는 고려하지 않는다(2026-11-11 결정).

근거: 기획 `docs/superpowers/specs/2026-11-11-camera-focus-notice-per-camera-design.md`, Figma `카메라 초점`(1813:8269).
서버 쪽 운영 절차: terra-server `docs/OPERATIONS.md` "1-3. 카메라 렌즈 초점 안내 발송"(gwanhun/terra-server#63). 2026-11-11 카메라 단위로 갱신을 요청했다.

## 앱 계약 (반드시 지킬 것)

`public.app_notifications`에 직접 1행을 INSERT한다. 트리거나 푸시 큐를 거치지 않는다.

| 컬럼 | 값 |
|---|---|
| user_id | **그 카메라의 `cameras.owner_id`** |
| kind / category | `camera.focus_needed` / `camera` |
| title | `카메라 렌즈 초점을 맞춰주세요` |
| body | `영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요` (문구는 Figma 그대로) |
| data | object. **`camera_id` = 그 카메라의 `cameras.id`(uuid) 필수.** 사람이 읽을 용도로 `device_id`·`camera_name`을 넣어도 된다 |
| route | `/crecam/cameras/<cameras.id>/live` (기록용) |
| source / source_event_id / dedupe_key | `external` / 새 uuid / `ops-focus:<같은 uuid>` |
| read_at | null |

`data.camera_id`가 없으면 막대가 어디에도 뜨지 않는다. 그 경우 알림함에만 남는다.

카메라를 어떻게 지정할지(기기 ID, 관리 화면 등)는 서버가 정한다. 아래는 기기 ID(`cameras.camera_id`, DB 전체에서 UNIQUE)로 보내는 예시다.

## 보내기 (예시: 기기 ID)

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

**결과가 `INSERT 0 1`인지 반드시 확인한다.** `INSERT 0 0`이면 보내지지 않은 것이다. 원인은 기기 ID 오타, 연결 해제된 카메라, 다른 계정으로 넘어간 카메라 중 하나다.

## 보낸 기록 보기

```sql
select n.created_at, u.email, n.data->>'device_id' as device_id, n.data->>'camera_name' as camera, n.read_at
from public.app_notifications n join auth.users u on u.id = n.user_id
where n.kind = 'camera.focus_needed'
order by n.created_at desc limit 50;
```

`read_at`이 비어 있으면 아직 안 본 것이다.

## 보내기 취소 (사용자가 보기 전)

```sql
update public.app_notifications set read_at = now()
where kind = 'camera.focus_needed' and read_at is null
  and data->>'camera_id' = (select id::text from public.cameras where camera_id = '<기기 ID>');
```
