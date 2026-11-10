# 카메라 렌즈 초점 안내 보내기 (운영자용)

영상이 흐린 사용자에게 "카메라 렌즈 초점을 맞춰주세요" 안내를 보낸다.

- 받은 사용자는 앱의 홈·카메라 탭 라이브 위에 안내 막대가 보이고, 알림함에도 남는다.
- 푸시(휴대폰 시스템 알림)는 나가지 않는다.
- 사용자가 막대나 알림을 한 번 누르면 읽음 처리되어 모든 기기에서 사라진다.
- 같은 사람에게 다시 보내면 다시 뜬다.
- 앱 0.176.0 이상에서 막대가 보인다. 그보다 낮은 버전에서는 알림함에 "일반 알림"으로만 보인다.

근거: 계획 `docs/superpowers/plans/2026-11-10-camera-focus-notice.md`, Figma `카메라 초점`(1813:8269).
서버 쪽 운영 절차: terra-server `docs/OPERATIONS.md` "1-3. 카메라 렌즈 초점 안내 발송"(gwanhun/terra-server#63, 2026-11-10 기준 머지 전). 계약 값과 SQL은 이 문서와 같다.

## 보내기

Supabase 대시보드 → SQL Editor에서 `<대상 이메일>`만 바꿔 실행한다.

```sql
insert into public.app_notifications
  (user_id, kind, category, title, body, route, data, source, source_event_id, dedupe_key)
select u.id, 'camera.focus_needed', 'camera',
       '카메라 렌즈 초점을 맞춰주세요', '영상이 흐릿하게 보인다면 렌즈 초점을 맞춰주세요',
       '/crecam', jsonb_build_object('kind', 'camera.focus_needed', 'source', 'external'),
       'external', e.id, 'ops-focus:' || e.id
from auth.users u, (select gen_random_uuid()::text as id) e
where u.email = '<대상 이메일>';
```

**결과가 `INSERT 0 1`인지 반드시 확인한다.** `INSERT 0 0`이면 이메일이 틀린 것이다. 이때는 아무것도 보내지지 않았다.

## 보낸 기록 보기

```sql
select n.created_at, u.email, n.read_at
from public.app_notifications n join auth.users u on u.id = n.user_id
where n.kind = 'camera.focus_needed'
order by n.created_at desc limit 50;
```

`read_at`이 비어 있으면 아직 안 본 것이다.

## 보내기 취소 (사용자가 보기 전)

```sql
update public.app_notifications n set read_at = now()
from auth.users u
where u.id = n.user_id and u.email = '<대상 이메일>'
  and n.kind = 'camera.focus_needed' and n.read_at is null;
```
