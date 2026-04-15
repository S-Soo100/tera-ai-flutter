# Supabase 연동 현황

> 최종 업데이트: 2026-04-13
> 작업자: Claude Code (Opus)

## 접속 정보

| 항목 | 값 |
|------|-----|
| Project Ref | `slxjvzzfisxqwnghvrit` |
| API URL | `https://slxjvzzfisxqwnghvrit.supabase.co` |
| Anon Key (legacy) | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNseGp2enpmaXN4cXduZ2h2cml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjU5NTksImV4cCI6MjA5MTY0MTk1OX0.-O9QF1V3mqAmNnlkgYhMVP8m8hPYEy20C9gWO0rgtvY` |
| Publishable Key | `sb_publishable_OLm606X-6yn1ypbCsZ2D1g_pXL5ybQY` |

> **주의**: 이 키들은 클라이언트용(anon/publishable)이므로 코드에 포함 가능. `service_role` 키는 절대 클라이언트에 노출하지 않는다.

## 테이블 구조 (14개)

스키마 원본: [`docs/supabase-schema.md`](./supabase-schema.md)

### 레퍼런스 테이블 (8개) — 공개 읽기, 관리자만 수정

| 테이블 | PK 타입 | 행 수 | 설명 |
|--------|---------|-------|------|
| `species_categories` | TEXT | 4 | 도마뱀/뱀/거북/양서류 |
| `species` | TEXT | 17 | 전체 종 목록 (featured 3 + 기타 14) |
| `care_info` | UUID | 3 | 사육 정보 (레오파드/크레스티드/펫테일) |
| `morph_genetics` | UUID | 3 | 모프 유전 데이터 (위 3종) |
| `guide` | UUID | 1 | 자진신고 가이드 (D-day 2026-06-13) |
| `citations` | TEXT | 25 | 출처/참고문헌 |
| `graph_entities` | TEXT | 69 | 지식 그래프 노드 (종/환경/질병/먹이/장비) |
| `graph_relations` | TEXT | 135 | 지식 그래프 엣지 |

### 유저 테이블 (6개) — 본인만 CRUD (P2 활성화)

| 테이블 | PK | FK 기준 | 설명 |
|--------|-----|---------|------|
| `user_profiles` | UUID (= auth.users.id) | 직접 | 사용자 프로필 |
| `pets` | UUID | user_id → auth.users | 내 반려동물 |
| `pet_events` | UUID | pet_id → pets | 급이/체중/탈피 이벤트 |
| `media` | UUID | pet_id → pets | 사진/영상 |
| `conversations` | UUID | user_id → auth.users | AI 대화 세션 |
| `chat_messages` | UUID | conversation_id → conversations | 대화 메시지 |

## 인덱스 (9개)

```
idx_species_category         → species(category_id)
idx_pets_user                → pets(user_id)
idx_pet_events_pet_date      → pet_events(pet_id, event_date)
idx_media_pet                → media(pet_id)
idx_media_event              → media(event_id)
idx_conversations_user       → conversations(user_id)
idx_chat_messages_conversation → chat_messages(conversation_id)
idx_graph_relations_from     → graph_relations(from_entity)
idx_graph_relations_to       → graph_relations(to_entity)
```

## RLS 정책

### 레퍼런스 테이블 (8개)

| 정책 | 대상 | 조건 |
|------|------|------|
| `Public read {table}` | SELECT | `USING (true)` — 누구나 읽기 가능 |
| INSERT/UPDATE/DELETE | 없음 | service_role만 가능 (RLS 바이패스) |

### 유저 테이블 — 직접 소유 (user_profiles, pets, conversations)

| 정책 | 조건 |
|------|------|
| SELECT / UPDATE / DELETE | `USING (auth.uid() = user_id)` |
| INSERT | `WITH CHECK (auth.uid() = user_id)` |

> `user_profiles`는 `auth.uid() = id` (PK가 곧 user ID)

### 유저 테이블 — 간접 소유 (pet_events, media, chat_messages)

| 정책 | 조건 |
|------|------|
| SELECT / UPDATE / DELETE | `USING (EXISTS (SELECT 1 FROM {parent} WHERE {parent}.id = {child}.{fk} AND {parent}.user_id = auth.uid()))` |
| INSERT | `WITH CHECK (동일 서브쿼리)` |

부모 테이블 매핑:
- `pet_events`, `media` → `pets.user_id`
- `chat_messages` → `conversations.user_id`

## 시드 데이터 소스 매핑

| DB 테이블 | 로컬 파일 |
|-----------|-----------|
| species_categories | `species_repository.dart`에서 추출 (4개 카테고리) |
| species | `lib/features/home/data/species_repository.dart` (17종) |
| care_info | `assets/data/care_info/*.json` (3파일) |
| morph_genetics | `assets/data/morphs/*.json` (3파일) |
| guide | `assets/data/guide_steps.json` |
| citations | `assets/data/citations.json` (25개) |
| graph_entities | `assets/data/graph.json` → entities (69개) |
| graph_relations | `assets/data/graph.json` → relations (135개) |

## Flutter 연동 방법 (P2)

### 1. 패키지 설치

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.0.0
```

### 2. 초기화 (main.dart)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: 'https://slxjvzzfisxqwnghvrit.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIs...', // .env로 분리 권장
);
final supabase = Supabase.instance.client;
```

### 3. 레퍼런스 데이터 읽기 (로그인 불필요)

```dart
// species 목록
final species = await supabase.from('species').select();

// care_info (species_id로 조회)
final care = await supabase
    .from('care_info')
    .select()
    .eq('species_id', 'leopard-gecko')
    .single();

// 지식 그래프 (특정 종의 관계)
final relations = await supabase
    .from('graph_relations')
    .select()
    .eq('from_entity', 'ent-species-leogecko');
```

### 4. 인증 (P2 1차: Email/Password)

```dart
// 회원가입
await supabase.auth.signUp(email: email, password: password);

// 로그인
await supabase.auth.signInWithPassword(email: email, password: password);

// 로그아웃
await supabase.auth.signOut();

// 현재 유저
final user = supabase.auth.currentUser;
```

### 5. 유저 데이터 CRUD (로그인 필수)

```dart
// 내 펫 등록
await supabase.from('pets').insert({
  'user_id': supabase.auth.currentUser!.id,
  'species_id': 'leopard-gecko',
  'name': '하루',
  'species_name': '레오파드 게코',
});

// 내 펫 목록 (RLS가 자동으로 본인 것만 반환)
final myPets = await supabase.from('pets').select();
```

## 마이그레이션 이력

| 순서 | 이름 | 내용 |
|------|------|------|
| 1 | `create_reference_tables` | 레퍼런스 테이블 8개 생성 |
| 2 | `create_user_tables` | 유저 테이블 6개 생성 |
| 3 | `create_indexes` | 인덱스 9개 생성 |
| 4 | `enable_rls_reference_tables` | 레퍼런스 RLS + 공개 읽기 정책 |
| 5 | `enable_rls_user_tables` | 유저 RLS + 본인 CRUD 정책 |

## Phase별 활용 계획

| Phase | Supabase 활용 범위 |
|-------|-------------------|
| P0 (현재) | 로컬 데이터 사용, Supabase 미연동 |
| P1 | 레퍼런스 데이터를 Supabase에서 fetch로 전환 (로그인 불필요) |
| P2 1차 | Email/Password 인증 + 유저 데이터 CRUD |
| P2 2차 | Google + Apple 소셜 로그인 |
| P2 3차 | Kakao 소셜 로그인 (OIDC Custom Provider) |
