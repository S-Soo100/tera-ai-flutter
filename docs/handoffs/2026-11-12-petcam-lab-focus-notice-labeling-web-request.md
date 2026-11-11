# [요청] 라벨링 웹에 "카메라 초점 안내 보내기" 기능 추가

- 보내는 곳: 비바나트 앱(tera-ai-flutter) → petcam-lab
- 작성: 2026-11-12
- 앱 상태: 받는 쪽은 **이미 구현·배포됨** (앱 0.177.1+510, main). 남은 건 보내는 쪽 UI뿐입니다.

## 1. 무엇을 원하나

라벨링하다가 영상이 흐린 클립을 보면, **그 클립을 찍은 카메라의 주인에게** "카메라 렌즈 초점을 맞춰주세요" 안내를 버튼 하나로 보내고 싶습니다.

지금은 운영자가 Supabase SQL 편집기에서 직접 INSERT해야 합니다. 라벨러가 흐린 영상을 가장 먼저 보는 사람이니, 라벨링 웹에서 바로 보낼 수 있게 해 주세요.

## 2. 앱에서 사용자가 보는 것 (참고)

- 받은 사용자는 **그 카메라의** 라이브 위(홈·카메라 탭)에 안내 막대가 뜹니다. 다른 카메라에는 뜨지 않습니다.
- 알림함에도 남습니다. 휴대폰 푸시는 나가지 않습니다.
- 사용자가 막대나 알림을 누르면 그 카메라 안내만 읽음 처리되어 모든 기기에서 사라집니다.
- 같은 카메라에 다시 보내면 다시 뜹니다.

## 3. 라벨링 웹에 바라는 동작 (제안 — 화면 구성은 자유)

1. 클립 보기 화면에 **[초점 안내 보내기]** 버튼.
2. 누르면 확인창: 카메라 이름·기기 ID(`p4cam-…`)·주인 표시 + "이 카메라 주인에게 초점 안내를 보냅니다".
3. 보내기 → 성공/실패 표시.
4. **이미 안 읽은 안내가 있으면** 버튼 옆에 "보냄 · 미확인 (N일 전)"을 보여 주고, 중복 발송 전에 한 번 더 묻기. (중복 발송 자체는 앱이 문제없이 처리합니다 — 막대는 하나만 뜨고 한 번에 다 읽음 처리됩니다.)
5. (선택) 보낸 기록 목록: 보낸 시각·카메라·보낸 사람·읽음 여부. 미확인 건 취소 버튼.

## 4. 앱 계약 (반드시 지켜 주세요)

`public.app_notifications`에 1행을 직접 INSERT합니다. 트리거·푸시 큐는 거치지 않습니다.

| 컬럼 | 값 |
|---|---|
| user_id | **그 카메라의 `cameras.owner_id`** |
| kind / category | `camera.focus_needed` / `camera` |
| title | `카메라 렌즈 초점을 맞춰주세요` |
| body | `영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요` |
| data | `{"kind":"camera.focus_needed","source":"external","camera_id":"<cameras.id uuid>","device_id":"<cameras.camera_id>","camera_name":"<cameras.name>"}` — **`camera_id` 필수** |
| route | `/crecam/cameras/<cameras.id>/live` |
| source / source_event_id / dedupe_key | `external` / 새 uuid / `ops-focus:<같은 uuid>` |
| read_at | null |

- 문구는 Figma 그대로입니다. 바꾸지 말아 주세요(카메라 이름도 넣지 않음).
- `data.camera_id`가 없거나 틀리면 막대가 어디에도 안 뜨고 알림함에만 남습니다. 앱은 오류를 내지 않으니 **조용히 실패**합니다 — 보내는 쪽에서 꼭 맞춰 주세요.

### 클립 → 카메라 찾기

클립(`motion_clips`)에서 카메라를 찾아, 그 카메라가 **지금도 연결된 상태**일 때만 보냅니다.

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

- 클립이 카메라를 어떤 컬럼으로 가리키는지(uuid인지 기기 ID인지)는 petcam-lab 쪽 스키마에 맞춰 `where`만 바꿔 주세요.
- **영향 행이 1이 아니면 실패로 표시**해 주세요. 0행 원인: 연결 해제된 카메라, 다른 계정으로 넘어간 카메라(재등록 시 새 행이 생깁니다), 주인 없음.
- 클립을 찍은 시점의 주인과 지금 주인이 다를 수 있습니다. **지금 주인**에게 보내는 게 맞습니다(위 조건이 그렇게 합니다).

### 미확인 여부 조회 (§3-4용)

```sql
select id, created_at from public.app_notifications
where kind = 'camera.focus_needed' and read_at is null
  and data->>'camera_id' = '<cameras.id>'
order by created_at desc;
```

### 취소 (사용자가 보기 전)

해당 행의 `read_at = now()`로 업데이트하면 앱에서 사라집니다. 행 삭제는 하지 말아 주세요(기록 보존).

## 5. 권한·보안

- INSERT는 **서버(service role)에서만** 해 주세요. 브라우저에서 anon/사용자 키로 남의 `user_id` 행을 쓰는 구조는 안 됩니다(RLS상 막혀야 정상이고, 열면 아무나 아무에게 알림을 보낼 수 있게 됩니다).
- 버튼은 라벨러/관리자 권한이 있는 계정에만 보여 주세요.
- 보낸 사람을 남기고 싶으면 `data`에 `sent_by`(라벨러 id 또는 이메일)를 더해도 됩니다 — 앱은 모르는 키를 무시합니다. 주인 이메일은 화면에 꼭 필요할 때만 노출해 주세요.

## 6. 하지 않아도 되는 것

- DB 스키마·트리거·RLS 변경 없음 (앱 쪽 요구 기준).
- 푸시 발송 없음.
- 앱 수정 없음 — 위 계약대로 들어오면 바로 동작합니다.

## 7. 확인 방법

1. 테스트 계정 카메라 클립에서 버튼 → 영향 행 1 확인.
2. 그 계정 앱(0.177.1+)에서 해당 카메라 라이브에만 막대가 뜨는지, 다른 카메라엔 없는지.
3. 막대를 누른 뒤 라벨링 웹에서 "읽음"으로 바뀌는지.
4. 확인 후 테스트 행은 `read_at`으로 정리.

## 참고

- 앱 운영 문서: `docs/ops/camera-focus-notice.md`
- 기획: `docs/superpowers/specs/2026-11-11-camera-focus-notice-per-camera-design.md`
- 서버 운영 절차: terra-server `docs/OPERATIONS.md` "1-3"(gwanhun/terra-server#63)

궁금한 점(특히 클립↔카메라 연결 컬럼, 라벨러 권한 구조)은 회신 주세요.
