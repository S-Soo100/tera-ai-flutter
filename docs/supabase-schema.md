# Supabase DB Schema Design v1

## Overview
Tera AI Flutter 앱의 전체 데이터를 Supabase로 이관하기 위한 스키마 설계.
레퍼런스 데이터 + 유저 데이터 모두 포함 (방안 B).

> 아래 **Tables (15개)** 는 메인 앱 소유 테이블이다. 사육장 IoT 제어용 terra-server 테이블(`devices`/`telemetry`/`commands` 등)은 동일 Supabase 프로젝트를 공유하며 별도 섹션 [terra-server IoT 테이블](#terra-server-iot-테이블-사육장-제어--동일-프로젝트-공유)에 정리.

## 단계별 진행 계획
1. 테이블 구조 생성 (스키마 + 인덱스)
2. 레퍼런스 데이터 시딩 (species, care_info, morph_genetics, guide, citations, graph)
3. RLS 정책 설정
4. Flutter 연동 (P2)

## Tables (15개)

### 레퍼런스 데이터 (공개 읽기, 관리자만 수정)

#### 1. species_categories
```sql
CREATE TABLE species_categories (
  id          TEXT PRIMARY KEY,
  name_ko     TEXT NOT NULL,
  name_en     TEXT,
  sort_order  INT DEFAULT 0
);
```

#### 2. species
```sql
CREATE TABLE species (
  id                    TEXT PRIMARY KEY,
  category_id           TEXT REFERENCES species_categories(id),
  korean_name           TEXT NOT NULL,
  scientific_name       TEXT NOT NULL,
  common_name           TEXT NOT NULL,
  family                TEXT,
  registration_required BOOLEAN DEFAULT false,
  has_care_info         BOOLEAN DEFAULT false,
  has_morph_data        BOOLEAN DEFAULT false,
  tags                  TEXT[],
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);
```

#### 3. care_info
```sql
CREATE TABLE care_info (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id      TEXT UNIQUE REFERENCES species(id),
  species_name_ko TEXT NOT NULL,
  scientific_name TEXT NOT NULL,
  last_updated    TEXT,
  difficulty      TEXT,
  lifespan        TEXT,
  adult_size      TEXT,
  temperament     TEXT,
  comparison      TEXT,
  temperature     JSONB NOT NULL,
  humidity        JSONB NOT NULL,
  enclosure       JSONB NOT NULL,
  diet            JSONB NOT NULL,
  meta            JSONB,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);
```

#### 4. morph_genetics
```sql
CREATE TABLE morph_genetics (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id       TEXT UNIQUE REFERENCES species(id),
  species_name_ko  TEXT NOT NULL,
  calculator_type  TEXT NOT NULL,
  calculator_note  TEXT,
  genes            JSONB NOT NULL,
  morphs           JSONB NOT NULL,
  line_bred_traits JSONB,
  allele_groups    JSONB DEFAULT '{}',
  pattern_groups   JSONB DEFAULT '{}',
  notes            JSONB,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);
```

#### 5. guide
```sql
CREATE TABLE guide (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deadline            TEXT NOT NULL,
  grace_period_end    TEXT,
  legal_basis         TEXT,
  system_name         TEXT,
  system_url          TEXT,
  system_note         TEXT,
  steps               JSONB NOT NULL,
  required_documents  JSONB,
  faq                 JSONB,
  report_types        JSONB,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);
```

#### 6. citations
```sql
CREATE TABLE citations (
  id          TEXT PRIMARY KEY,
  type        TEXT NOT NULL,
  title       TEXT NOT NULL,
  authors     TEXT[],
  publisher   TEXT,
  year        INT,
  url         TEXT,
  doi         TEXT,
  accessed_at TEXT,
  reviewed_by TEXT,
  reviewed_at TEXT,
  confidence  TEXT DEFAULT 'unverified',
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

#### 7. graph_entities
```sql
CREATE TABLE graph_entities (
  id      TEXT PRIMARY KEY,
  kind    TEXT NOT NULL,
  ref_id  TEXT,
  label   TEXT NOT NULL,
  payload JSONB DEFAULT '{}'
);
```

#### 8. graph_relations
```sql
CREATE TABLE graph_relations (
  id            TEXT PRIMARY KEY,
  from_entity   TEXT NOT NULL REFERENCES graph_entities(id),
  relation_type TEXT NOT NULL,
  to_entity     TEXT NOT NULL REFERENCES graph_entities(id),
  citation_ids  TEXT[]
);
```

### 유저 데이터 (본인만 CRUD, P2에서 RLS 적용)

#### 9. user_profiles
```sql
CREATE TABLE user_profiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name      TEXT,
  avatar_url        TEXT,
  timezone          TEXT DEFAULT 'Asia/Seoul',
  experience        TEXT,
  preferred_species TEXT[],
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);
```

#### 10. pets
```sql
CREATE TABLE pets (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id),
  species_id    TEXT REFERENCES species(id),
  name          TEXT NOT NULL,
  species_name  TEXT NOT NULL,
  morph         TEXT,
  sex           TEXT DEFAULT 'unknown',
  birth_date    DATE,
  adoption_date DATE,
  weight        DOUBLE PRECISION,
  avatar_url    TEXT,
  memo          TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);
```

#### 11. pet_events
```sql
CREATE TABLE pet_events (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id     UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  type       TEXT NOT NULL,
  value      DOUBLE PRECISION,
  title      TEXT,
  note       TEXT,
  metadata   JSONB,
  event_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### 12. media
```sql
CREATE TABLE media (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id        UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  event_id      UUID REFERENCES pet_events(id) ON DELETE SET NULL,
  type          TEXT NOT NULL,
  url           TEXT NOT NULL,
  thumbnail_url TEXT,
  caption       TEXT,
  file_size     INT,
  duration      INT,
  sort_order    INT DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT now()
);
```

#### 13. conversations
```sql
CREATE TABLE conversations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users(id),
  pet_id        UUID REFERENCES pets(id) ON DELETE SET NULL,
  species_id    TEXT REFERENCES species(id),
  title         TEXT NOT NULL,
  message_count INT DEFAULT 0,
  tags          TEXT[],
  is_archived   BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);
```

#### 14. chat_messages
```sql
CREATE TABLE chat_messages (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id    UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role               TEXT NOT NULL,
  content            TEXT NOT NULL,
  token_count        INT,
  from_cache         BOOLEAN DEFAULT false,
  knowledge_entry_id TEXT,
  created_at         TIMESTAMPTZ DEFAULT now()
);
```

#### 15. camera_clips
펫캠(게코 캠) 영상 세그먼트 메타데이터. 실제 mp4 파일은 petcam-lab 서버 로컬 디스크에 저장되고, 이 테이블에는 경로와 메타만 기록. `petcam-lab` 백엔드가 `service_role` 로 INSERT, Flutter 앱은 `anon` + JWT 로 본인 것만 SELECT.

```sql
CREATE TABLE camera_clips (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  pet_id        UUID REFERENCES pets(id) ON DELETE SET NULL,
  camera_id     TEXT NOT NULL,
  started_at    TIMESTAMPTZ NOT NULL,
  duration_sec  REAL NOT NULL,
  has_motion    BOOLEAN NOT NULL DEFAULT false,
  motion_frames INT,
  file_path     TEXT NOT NULL,     -- petcam-lab 서버 로컬 절대경로
  file_size     BIGINT,
  codec         TEXT,              -- 예: 'avc1'
  width         INT,
  height        INT,
  fps           REAL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE camera_clips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User reads own clips" ON camera_clips
  FOR SELECT USING (auth.uid() = user_id);
```

**앱 연동 노트 (Stage D):**
- 목록: Supabase 에 직접 SELECT (RLS 로 본인 것만 나옴)
- 재생: `petcam-lab` 서버의 `GET /clips/{id}/file` (HTTP Range 지원) 호출 — 영상 바이트는 Supabase 가 아닌 petcam-lab 서버에서 스트리밍
- Storage 업로드는 Stage E 이후 (용량 이슈로 전부 업로드 X, "중요 클립" 선별만)

---

## terra-server IoT 테이블 (사육장 제어 — 동일 프로젝트 공유)

> **소유**: terra-server 백엔드. **DDL 원본**: terra-server `docs/DATABASE.md` + `~/Downloads/APP_INTEGRATION.md`(앱 통합 단일 진실 소스, v0.1.0).
> **프로젝트**: 메인 앱과 **동일한 Supabase 프로젝트**(`slxjvzzfisxqwnghvrit`)를 공유한다 (`lib/core/config/env_config.dart` 참조). `api.terra-server.uk`는 페어링/presigned URL 등 서버 로직용 REST(terra-api)이고, IoT 데이터(디바이스/명령/센서)는 Supabase Postgres + RLS 로 직결한다.
> **아래 DDL은 Flutter가 실제 의존하는 컬럼만 표기** (terra-server가 추가 컬럼을 소유할 수 있음). 매핑 코드: `lib/features/my_cage/domain/{device,telemetry_reading,device_command}.dart`.

terra-server는 `enclosures` / `devices` / `cameras` / `commands` / `telemetry` / `telemetry_1m` / `alerts` / `motion_clips` 테이블을 정의한다. **현재 Flutter 앱이 연동한 것은 `devices` / `telemetry` / `commands` / `cameras` 4개**이며(클립은 petcam-lab `camera_clips` 유지), 나머지는 명세만 존재하고 앱 미연동 상태다.

> **주의 (2026-06-11)**: `cameras` 테이블은 terra-server 스키마(ESP32-P4 사육장 캠)로 교체되어 있다. 과거 petcam-lab RTSP 카메라용 컬럼(host/port/path/username)은 존재하지 않으며, 앱의 RTSP 등록 흐름(CameraAddScreen)도 제거됨. 앱 의존 컬럼: `id`(uuid, WebRTC API의 camera_uuid) / `camera_id`(text) / `name` / `model` / `resolution` / `is_online` / `last_seen_at` / `enclosure_id` / `created_at`. RLS: `auth.uid() = owner_id`. 라이브 영상은 WebRTC P2P — 시그널링 REST 계약은 `~/Downloads/APP_WEBRTC.md`(terra-server SOT), 클라 구현은 `lib/features/my_cage/{data/webrtc_signaling_repository,presentation/webrtc_live_controller}.dart`.

#### IoT-1. devices
```sql
-- terra-server 소유. 앱은 SELECT 만 (페어링은 ESP32가 POST /devices/pair 로 생성).
CREATE TABLE devices (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     UUID REFERENCES auth.users(id),
  enclosure_id UUID,                  -- REFERENCES enclosures(id)
  name         TEXT,
  is_online    BOOLEAN DEFAULT false,
  last_seen_at TIMESTAMPTZ
  -- (+ terra-server 소유 컬럼: mqtt_token 등)
);
```

#### IoT-2. telemetry
```sql
-- 디바이스가 3초 주기로 INSERT. 7일 보관(telemetry_1m 로 1분 평균 롤업, 1년 보관).
-- relay/fan/heater_state: DB에서 bool 또는 'ON'/'OFF' 문자열 둘 다 허용(클라가 양쪽 파싱).
CREATE TABLE telemetry (
  device_id     UUID NOT NULL REFERENCES devices(id),
  t_a           DOUBLE PRECISION,     -- DHT22-A 메인 온도(℃)
  h_a           DOUBLE PRECISION,     -- DHT22-A 메인 습도(%)
  a_ok          BOOLEAN,              -- A 센서 정상 여부
  t_b           DOUBLE PRECISION,     -- DHT22-B 보조 온도
  h_b           DOUBLE PRECISION,     -- DHT22-B 보조 습도
  b_ok          BOOLEAN,
  relay         TEXT,                 -- 워터펌프 상태 (ON/OFF)
  fan           TEXT,                 -- 팬 상태
  heater_state  TEXT,                 -- 히터 상태
  heater_locked BOOLEAN,              -- safety latch 활성 여부
  ts            TIMESTAMPTZ
);
```

#### IoT-3. commands
```sql
-- 앱이 INSERT(=명령 발행). terra-bridge dispatcher가 1초 내 SELECT → MQTT publish.
-- ESP32 ack → status='acked' + result + acked_at 로 UPDATE. 앱은 Realtime UPDATE 구독.
CREATE TABLE commands (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(id),
  issued_by UUID NOT NULL REFERENCES auth.users(id),
  action    TEXT NOT NULL,            -- relay_toggle | fan_toggle | heater_toggle |
                                      -- heater_clear | led_on | led_up | led_down | token_rotate
  payload   JSONB,                    -- 예: token_rotate 시 {"new_token": "..."}
  ttl_sec   INT DEFAULT 10,
  status    TEXT DEFAULT 'pending',   -- pending → sent → acked | rejected | expired
  result    TEXT,                     -- ok | rejected_locked | rejected_ttl_expired |
                                      -- rejected_unknown_action | rejected_duplicate_msg_id
  issued_at TIMESTAMPTZ DEFAULT now(),
  acked_at  TIMESTAMPTZ
);
```

**명령 상태 머신**: `INSERT(pending)` → dispatcher가 TTL 검사 → `expired` / `rejected` / MQTT publish 성공 시 `sent` → ESP32 ack 시 `acked`(+result).

**RLS** (terra-server 정의):
- `devices`: `auth.uid() = owner_id` — 본인 디바이스만 SELECT.
- `telemetry`: 본인 `devices`의 telemetry 만 SELECT (다른 사용자 센서값 격리).
- `commands` INSERT: `issued_by = auth.uid()` 이면서 본인 소유 `device_id` 여야 통과.

**앱 연동 노트:**
- 디바이스 목록: `devices` 직접 SELECT (`order by last_seen_at desc`).
- 온/습도 실시간: `telemetry` INSERT 를 Supabase Realtime 구독(`telemetry-<deviceId>` 채널, `device_id` 필터) + 진입 시 최신값 1건 seed.
- 제어: `commands` INSERT(편의 메서드 `toggleFan`/`toggleRelay`/`toggleHeater`/`clearHeater`/`ledOn`/`ledUp`/`ledDown`) + `commands` UPDATE Realtime 로 ack 추적.
- 페어링: BLE(`flutter_blue_plus` + `permission_handler`) 로 SSID/PASS/NAME/JWT 전달 → ESP32 가 `POST /devices/pair`. 프로토콜 §6은 `APP_INTEGRATION.md` 참조.

## Indexes
```sql
CREATE INDEX idx_species_category ON species(category_id);
CREATE INDEX idx_pets_user ON pets(user_id);
CREATE INDEX idx_pet_events_pet_date ON pet_events(pet_id, event_date);
CREATE INDEX idx_media_pet ON media(pet_id);
CREATE INDEX idx_media_event ON media(event_id);
CREATE INDEX idx_conversations_user ON conversations(user_id);
CREATE INDEX idx_chat_messages_conversation ON chat_messages(conversation_id);
CREATE INDEX idx_graph_relations_from ON graph_relations(from_entity);
CREATE INDEX idx_graph_relations_to ON graph_relations(to_entity);

-- camera_clips (Stage C+, petcam-lab)
CREATE INDEX idx_camera_clips_user_started
  ON camera_clips(user_id, started_at DESC);
CREATE INDEX idx_camera_clips_pet_started
  ON camera_clips(pet_id, started_at DESC)
  WHERE pet_id IS NOT NULL;
CREATE INDEX idx_camera_clips_motion
  ON camera_clips(user_id, has_motion, started_at DESC)
  WHERE has_motion = true;
```

## Seed Data Sources (현재 앱 내 로컬 데이터)
- species: `lib/features/home/data/species_repository.dart` (하드코딩 16종)
- care_info: `assets/data/care_info/*.json`
- morph_genetics: `assets/data/morphs/*.json`
- guide: `assets/data/guide.json`
- citations: `assets/data/citations.json`
- graph: `assets/data/graph.json`
