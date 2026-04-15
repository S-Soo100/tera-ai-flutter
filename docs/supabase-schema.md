# Supabase DB Schema Design v1

## Overview
Tera AI Flutter 앱의 전체 데이터를 Supabase로 이관하기 위한 스키마 설계.
레퍼런스 데이터 + 유저 데이터 모두 포함 (방안 B).

## 단계별 진행 계획
1. 테이블 구조 생성 (스키마 + 인덱스)
2. 레퍼런스 데이터 시딩 (species, care_info, morph_genetics, guide, citations, graph)
3. RLS 정책 설정
4. Flutter 연동 (P2)

## Tables (14개)

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
```

## Seed Data Sources (현재 앱 내 로컬 데이터)
- species: `lib/features/home/data/species_repository.dart` (하드코딩 16종)
- care_info: `assets/data/care_info/*.json`
- morph_genetics: `assets/data/morphs/*.json`
- guide: `assets/data/guide.json`
- citations: `assets/data/citations.json`
- graph: `assets/data/graph.json`
