# 카메라 라이브 연결 안정성 — 서버 요청 2건 (2026-09-22)

받는 분: 이관훈님 (terra-server / 인프라)
보내는 쪽: 비바나트 앱

## 배경

카메라 라이브(WebRTC)가 "안 붙는다", "붙었다 끊긴다"는 체감이 있어 앱 코드를 점검했습니다. 앱 쪽 원인은 이번에 고쳤습니다(0.129.0).

- 재연결할 때 이전 세션의 ICE 폴링이 살아남아, 이전 세션 후보가 새 피어에 섞이던 문제를 고쳤습니다.
- 백그라운드에 들어가면 연결을 닫고, 앱으로 돌아오면 바로 다시 연결합니다.
- 네트워크가 바뀌면(Wi-Fi↔LTE) 바로 다시 연결합니다.
- 카메라가 오프라인이면 자동 재시도를 멈추고, 온라인이 되면 다시 붙습니다.
- 첫 프레임이 와야 LIVE로 표시합니다. 연결 후 30초간 영상이 없거나, 재생 중 15초간 멈추면 다시 연결합니다.
- ICE 수집 대기를 계약 권장값인 2초로 맞췄습니다(기존 1초).
- offer 응답을 기다리는 사이 버려진 세션은 `/webrtc/close`로 닫습니다.

남은 두 가지는 앱만으로는 해결할 수 없습니다.

---

## 요청 1. 연결 결과 기록 테이블 — 실패 원인을 측정하기 위해

**지금 문제:** 연결 실패는 앱 디버그 로그(`[webrtc-timing]`)에만 남고, 출시 빌드에서는 아무것도 수집되지 않습니다. 그래서 실패가 앱·펌웨어·NAT(TURN 부재) 중 어디서 생기는지 비율을 알 수 없습니다. 요청 2의 TURN 효과도 측정할 방법이 없습니다.

**제안:** Supabase 테이블 하나에 앱이 연결 시도 1건마다 1행을 INSERT합니다. terra-server REST로 받는 방식도 괜찮으니, 편한 쪽을 알려 주세요.

```sql
create table public.webrtc_connect_logs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id),
  camera_id       uuid not null references public.cameras(id) on delete cascade,
  created_at      timestamptz not null default now(),
  app_version     text,            -- 예: 0.129.0+322
  platform        text,            -- ios / android
  network         text,            -- wifi / mobile / ethernet ...
  outcome         text not null,   -- streaming / failed / unresponsive / no_video / stalled / cancelled
  fail_phase      text,            -- config / offering / connectingIce / waitingVideo / streaming
  ms_config       int,             -- 시도 시작 → ICE 설정 수신
  ms_answer       int,             -- → answer 수신(펌웨어 응답 포함)
  ms_connected    int,             -- → ICE connected
  ms_first_frame  int,             -- → 첫 프레임
  local_cand      text,            -- 선택된 쌍의 로컬 후보 타입 host/srflx/prflx/relay
  remote_cand     text,            -- 선택된 쌍의 원격(카메라) 후보 타입
  reconnect_attempt int,           -- 자동 재연결 몇 번째 시도인지
  streamed_sec    int              -- 재생 유지 시간(끊겼을 때)
);
alter table public.webrtc_connect_logs enable row level security;
create policy "insert own" on public.webrtc_connect_logs
  for insert to authenticated with check (user_id = auth.uid());
-- SELECT는 운영자(service_role)만. 앱은 읽지 않습니다.
create index on public.webrtc_connect_logs (camera_id, created_at desc);
```

- 보존 기간은 90일이면 충분합니다(주기 삭제는 어느 방식이든 괜찮습니다).
- 앱은 테이블이 준비되면 기록을 붙이고, 실패해도 사용자 흐름에는 영향을 주지 않습니다(fire-and-forget).
- 이 데이터로 볼 것:
  - 실패의 NAT 비율(remote/local이 host·srflx뿐이고 실패한 경우)
  - 첫 프레임 지연 분포(펌웨어 키프레임)
  - 504 비율
  - 재생 중 끊김(`stalled`) 빈도

## 요청 2. TURN 서버 배포 — LTE·까다로운 공유기 환경 연결

**지금 문제:** `GET /cameras/webrtc/config`가 STUN만 주고, TURN은 배포돼 있지 않습니다(`APP_WEBRTC.md`: TURN은 `WEBRTC_TURN_*`가 설정됐을 때만 포함). 그래서 폰이 LTE(통신사 NAT)에 있거나, 카메라나 폰 어느 한쪽이 대칭형 NAT 뒤에 있으면 연결 자체가 되지 않습니다. 계약 문서가 추정하는 STUN 커버리지는 약 80%이고, 나머지 약 20%는 매번 실패하며 재연결 루프만 돕니다.

**요청:**

1. **coturn(또는 관리형 TURN) 배포**
   - 리전은 서울을 권장합니다.
   - 리스너: `turn:<host>:3478?transport=udp`, `turn:<host>:3478?transport=tcp`, `turns:<host>:443?transport=tcp`. 443/TLS는 UDP가 막힌 망을 위한 것입니다.
2. **단기 자격 증명**
   - coturn `use-auth-secret`(TURN REST API 방식) 기준으로, `username = <만료 unix ts>:<user_id>`, `credential = base64(HMAC-SHA1(secret, username))`, 유효기간 6~24시간을 제안합니다.
   - 고정 계정은 앱에 박히면 유출 위험이 있어 피하고 싶습니다.
3. **`/cameras/webrtc/config` 응답의 `iceServers`에 TURN 항목 포함.** 앱은 이미 이 값을 그대로 `RTCPeerConnection`에 넘기므로 **앱 수정 없이 적용됩니다.** 자동 재연결 때마다 config를 다시 받으므로, 자격 증명이 만료돼도 다음 시도에서 갱신됩니다.
4. **펌웨어(ESP32-P4) ICE 확인.** 보통 한쪽(앱)만 relay를 쓰면 연결되지만, 카메라가 relay 주소로 향하는 connectivity check를 보낼 수 있어야 합니다. 펌웨어가 TURN을 직접 지원할 필요는 없는지 확인 부탁드립니다.

**완료 기준(같이 검증하겠습니다):**
- 폰 LTE + 카메라 집 Wi-Fi에서 라이브가 붙는다.
- 요청 1의 로그에서 해당 시도의 `local_cand = relay`가 확인된다.

**비용 참고:** relay는 영상 트래픽을 그대로 중계합니다. HD 10fps 기준 대략 0.5~1.5 Mbps이고, 라이브를 보는 동안에만 발생합니다. 요청 1 로그로 relay 비율과 시청 시간을 보고 용량을 잡으면 됩니다.

---

## 참고: 서버·펌웨어 쪽에서 함께 봐 주시면 좋은 것 (선택)

- **첫 프레임 지연(~18초):** 새 세션이 시작될 때 IDR(키프레임)을 바로 보내면 첫 화면이 즉시 뜹니다(메모 `webrtc_first_frame_keyframe_gap`, HW 담당 결정 대기 중).
- **남은 펌웨어 세션:** 앱이 `/close`를 못 보내고 죽으면 펌웨어 세션이 남아 다음 연결을 방해한다고 계약 문서에 적혀 있습니다. 서버에서 세션 TTL이나 새 offer가 오면 이전 세션을 정리하는 방식이 있는지 궁금합니다.
- 앱 코드 주석이 인용하던 "라이브 ~20분 뒤 소리 없이 끊김" 핸드오프(`backend-handoff-2026-09-07-mist-blackout.md` §3) 원문을 찾지 못했습니다. 갖고 계시면 공유 부탁드립니다.
