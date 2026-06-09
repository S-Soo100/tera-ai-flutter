# Flutter Cloud Migration & UI Redesign Plan

> 작성: 2026-05-07. 출처: petcam-lab handoff(`/Users/baek/petcam-lab/docs/handoff-prompts/flutter-cloud-migration.md`) + `/Users/baek/Desktop/new-app-design/` 레퍼런스.
> 휘발성 plan 사본: `~/.claude/plans/jaunty-tumbling-waffle.md`

## Context

petcam-lab 백엔드가 클라우드 분산 아키텍처로 재설계됐고, 그에 맞춰 Flutter 앱이 두 단계로 진화한다.

1. **Phase C (Cloud Migration, PR1~5)** — 백엔드 contract 정합. 영상/썸네일 presigned URL, 라벨 read-only 표시, 하이라이트, labeler 외부 링크.
2. **Phase D (UI Redesign, PR6+)** — 새 IA(5탭 BottomNav) + 신규 화면(홈 활동량, 마이 크레, 사육장, 커뮤니티) 적용. 레퍼런스 시안 6장 기반.

**왜 지금 이 변화가 필요한가**
- mp4 직접 스트리밍 → R2 presigned URL (signed URL이라 헤더 첨부 시 signature 깨짐)
- VLM 자동 라벨 + human override 라벨이 백엔드에서 부착 → Flutter는 read-only 표시만
- 라벨 수정/검수는 별도 라벨링 웹(`label.tera-ai.uk`)이 담당
- 신규 IA로 "관찰(개체) / 기록(클립) / 환경(사육장) / 소통(커뮤니티)" 4축 명확히 분리

---

## 사용자 합의된 결정 사항 (Phase C)

| # | 결정 | 내용 |
|---|------|------|
| 1 | 백엔드 검증 | 엔지니어 수동 — petcam-lab에서 `curl 200` 확인 후 "ready" 신호 받으면 PR 시작 |
| 2 | 미구현 endpoint | 피처플래그 OFF로 출시 가능 빌드. `is_labeler` 먼저 추가 → ON. `/highlights`는 그 뒤 → ON |
| 3 | 하이라이트 진입 | `/my-cage/highlights` 새 라우트 + `MyCageScreen` AppBar 아이콘 (Phase D에서 마이 크레 탭으로 재배치) |
| 4 | labeler 링크 | `url_launcher` `LaunchMode.externalApplication` (외부 브라우저) |
| 5 | TTL 갱신 | 403/expired 시 1회 refetch + 재시도. prefetch 없음 |
| 6 | enum 키 네이밍 | wire format 그대로 (백엔드 snake_case → l10n 키도 snake_case) |

---

## Flutter가 가정하는 응답 shape (백엔드가 맞춰줄 것)

### `GET /me/is_labeler` (백엔드 미구현 — 곧 추가)
```json
{ "user_id": "uuid", "is_labeler": true, "added_at": "2026-05-07T..." }
```
404/501 → null 반환 (피처플래그 OFF로 동작).

### `GET /clips/highlights?cursor=&limit=50&pet_id=` (백엔드 미구현 — 그 다음)
```json
{
  "items": [
    {
      "clip": { /* ClipOut 기존 형식 그대로 */ },
      "label": { "action": "eating_paste", "source": "vlm|human", "confidence": 0.87 }
    }
  ],
  "next_cursor": "ISO8601 or null",
  "has_more": false
}
```
404/501 → 빈 페이지 반환.

### `GET /clips/{id}/file/url`, `/thumbnail/url`
```json
{ "url": "https://r2.../signed?...", "ttl_sec": 3600, "type": "r2" }
```

### `GET /clips/{id}/labels`
`[{ "id", "clip_id", "labeled_by", "action": "eating_paste", "lick_target": "dish|null", "note": "string|null", "labeled_at": "ISO8601" }]`

### `GET /clips/{id}/inference`
`{ "id", "clip_id", "action": "eating_paste", "source": "vlm", "confidence": 0.87, "reasoning": "...", "vlm_model": "gemini-...", "created_at": "..." }` 또는 `null`

> wire 값은 snake_case로 가정 (`eating_paste`, `tongue_flicking`). PR1에서 실제 응답으로 최종 확정 — camelCase면 enum의 `fromWire/toWire` 변환 라인만 바꿈.

---

# Phase C — Cloud Migration

## PR 1 — 도메인 모델 + repository 신규 메서드 (UI 변경 0)

**목표**: 새 contract용 모델·enum·repo 메서드만 선반영. caller 영향 0.

**신규 파일**:
- `lib/features/my_cage/domain/action_type.dart` — `ActionType` enum (9종) + `fromWire(String)` / `toWire()` / `localizationKey` getter. unknown wire 값은 `ActionType.unknown` fallback.
- `lib/features/my_cage/domain/lick_target_type.dart` — `LickTargetType` enum (6종).
- `lib/features/my_cage/domain/behavior_label.dart` — `BehaviorLabel(id, clipId, labeledBy, action, lickTarget?, note?, labeledAt)`.
- `lib/features/my_cage/domain/behavior_inference.dart` — `BehaviorInference(id?, clipId, action, source, confidence?, reasoning?, vlmModel?, createdAt?)`.
- `lib/features/my_cage/domain/clip_media_url.dart` — `ClipMediaUrl(url, ttlSec, type)`. file/url, thumbnail/url 공통.
- `lib/features/my_cage/domain/highlights_page.dart` — `HighlightsPage(items, nextCursor?, hasMore)` + `HighlightItem(clip, label)`.
- `lib/features/my_cage/domain/labeler_status.dart` — `LabelerStatus(userId, isLabeler, addedAt?)`.

**수정 파일**:
- `lib/features/my_cage/data/clip_repository.dart` — 신규 async 메서드 6개 추가:
  - `Future<ClipMediaUrl> getFileUrl(String id)` — Bearer 첨부, 200 → fromJson, 401 → throw.
  - `Future<ClipMediaUrl> getThumbnailUrl(String id)`
  - `Future<List<BehaviorLabel>> getLabels(String id)` — `[]` 안전 처리.
  - `Future<BehaviorInference?> getInference(String id)` — null/204 → null.
  - `Future<LabelerStatus?> getMyLabelerStatus()` — 404/501 → null.
  - `Future<HighlightsPage> getHighlights({cursor, limit, petId})` — 404/501 → 빈 페이지.
  - `camera_repository.dart`의 `_authedRequest`/`_extractDetail` 패턴 차용 (mixin으로 빼지 말고 우선 복붙 — 회귀 위험 최소화).
  - 기존 `fileUrl(String)` / `thumbnailUrl(String)` / `authHeaders()` **유지** (PR2에서 제거).

**신규 Provider**: 없음 (PR2부터 도입).

**선행 의존**: 없음 (베이스 PR).

**검증**: `flutter analyze` 통과. 수동 — my_cage 진입/카메라 목록/클립 그리드/재생 동일 동작.

---

## PR 2 — `clip_repository.fileUrl` async 전환 + 헤더 제거

**목표**: presigned URL 흐름으로 caller 3곳 전환. `httpHeaders` 모두 제거.

**신규 파일**:
- `lib/features/my_cage/presentation/widgets/clip_thumbnail.dart` — `ClipThumbnail({clipId, fallback})` ConsumerStatefulWidget. `clipThumbnailUrlProvider(clipId)` watch → `CachedNetworkImage`에 url만 전달 (헤더 X). `thumbnailPath == null`이면 placeholder. `clip_card.dart`/`clip_grid_card.dart` 중복 흡수.

**수정 파일**:
- `lib/features/my_cage/data/clip_repository.dart:142-152` — 기존 동기 `fileUrl`/`thumbnailUrl`/`authHeaders` **삭제**.
- `lib/features/my_cage/presentation/clip_player_screen.dart:33-49` — `_initPlayer` 재작성:
  - L43-44 `headers`/`url` 호출 제거 → `final media = await repo.getFileUrl(widget.clipId);`
  - L46-49 `VideoPlayerController.networkUrl(Uri.parse(media.url))` (httpHeaders 제거)
  - **403/expired 1회 retry**: `controller.initialize()` 또는 재생 중 에러 리스너에서 expired 감지 시 `ref.refresh(clipFileUrlProvider(id))` 후 재초기화 1회.
- `lib/features/my_cage/presentation/widgets/clip_grid_card.dart` 전면 재구성 — `_headers`/`_loadHeaders` 제거 (L32, L40-45). `repo.thumbnailUrl(clip.id)` 호출(L66) 삭제. 새 `ClipThumbnail` 위젯으로 교체.
- `lib/features/my_cage/presentation/widgets/clip_card.dart` — 동일하게 `ClipThumbnail`로 교체.
- `lib/features/my_cage/presentation/my_cage_providers.dart` — 신규 provider 2종 추가.

**신규 Provider**:
- `clipFileUrlProvider = FutureProvider.autoDispose.family<ClipMediaUrl, String>` — clip_player에서 직접 await + 만료 시 `ref.refresh`.
- `clipThumbnailUrlProvider = FutureProvider.autoDispose.family<ClipMediaUrl, String>` — `ClipThumbnail` 위젯이 watch.

**선행 의존**: PR1.

**검증**:
1. 클립 그리드 진입 → 썸네일 정상 노출 (60개 한 시간)
2. 클립 탭 → 영상 재생/일시정지/seek
3. presigned URL 강제 만료 시뮬레이션 → 403 → 1회 refetch → 재생 복구
4. Supabase signOut 후 클립 진입 → 401 → `/login` redirect

---

## PR 3 — clip 상세 라벨/추론 chip 섹션

**목표**: `ClipPlayerScreen` 하단 메타에 라벨/추론 chip을 read-only로 노출. **수정 UI 절대 만들지 않음**.

**신규 파일**:
- `lib/features/my_cage/presentation/widgets/behavior_chip_section.dart` — `BehaviorChipSection({clipId})` ConsumerWidget. `clipLabelsProvider`/`clipInferenceProvider` watch. 둘 다 빈/null이면 섹션 숨김. 우선순위: human label chip(여러 개) → 옅은 톤으로 inference chip 1개. chip 라벨은 `ActionType.localizationKey`를 `tr()`로 풀어서.

**수정 파일**:
- `lib/features/my_cage/presentation/clip_player_screen.dart:144-184` — 하단 메타 `Container` 안 duration Text(L170-180) 다음에 `BehaviorChipSection(clipId: widget.clipId)` 삽입.
- `lib/features/my_cage/presentation/my_cage_providers.dart` — provider 2종.
- `assets/l10n/ko.json` — `clip_label_section_title`, `clip_inference_section_title`, ActionType 9종 / LickTargetType 6종 키 (snake_case wire 값 그대로 — 예: `behavior_action_eating_paste`, `behavior_lick_target_dish`).

**신규 Provider**:
- `clipLabelsProvider = FutureProvider.autoDispose.family<List<BehaviorLabel>, String>`
- `clipInferenceProvider = FutureProvider.autoDispose.family<BehaviorInference?, String>`

**선행 의존**: PR1. PR2와 독립이지만 머지 순서는 PR2 먼저.

**검증**: 4 케이스(라벨+추론 / 라벨만 / 추론만 / 둘 다 없음) 분기 + chip 섹션 async error가 화면 깨뜨리지 않음.

---

## PR 4 — 하이라이트 화면 (피처플래그 가드)

**목표**: 별도 라우트로 하이라이트 피드. 백엔드 미구현 시 `EnvConfig.highlightsEnabled = false`로 진입점 자체 숨김.

**신규 파일**:
- `lib/features/my_cage/presentation/highlights_screen.dart` — `HighlightsScreen` ConsumerStatefulWidget. cursor 무한 스크롤. row: `ClipThumbnail` + 시간 + 라벨 chip 1개. 탭 시 `/my-cage/clips/{clipId}` push.
- `lib/features/my_cage/presentation/widgets/highlight_row.dart` — row 위젯 분리.

**수정 파일**:
- `lib/core/config/env_config.dart` — `static bool get highlightsEnabled => dotenv.env['HIGHLIGHTS_ENABLED'] == 'true';` (기본 false).
- `lib/core/router/app_router.dart` — `/my-cage` 하위에 `GoRoute(path: 'highlights', ...)` 추가.
- `lib/features/my_cage/presentation/my_cage_screen.dart` — `EnvConfig.highlightsEnabled == true`일 때만 AppBar `actions`에 ✨ 아이콘 노출. 탭 시 `context.push('/my-cage/highlights')`.
- `lib/features/my_cage/presentation/my_cage_providers.dart` — `highlightsControllerProvider = AsyncNotifierProvider<HighlightsController, HighlightsState>` 추가.
- `assets/l10n/ko.json` — `my_cage_highlights_title`, `my_cage_highlights_empty` 키.

**신규 Provider**:
- `highlightsControllerProvider` — `HighlightsState({items, nextCursor, hasMore, isLoadingMore})`. `loadInitial()`/`loadMore()` 메서드.

**선행 의존**: PR2 (`ClipThumbnail` 위젯).

**검증**: 빈 응답 / 1페이지 / 다중 페이지 무한 스크롤 / 같은 cursor 두 번이면 중단(방어) / row 탭 → 클립 상세.

---

## PR 5 — labeler 외부 링크 (피처플래그 가드)

**목표**: `is_labeler == true`인 사용자에게만 외부 labeler 도구로 가는 진입점.

**신규 파일**:
- `lib/features/my_cage/presentation/widgets/labeler_entry_button.dart` — `LabelerEntryButton` ConsumerWidget. `myLabelerStatusProvider` watch, `isLabeler == true`일 때만 렌더(나머지 모두 `SizedBox.shrink()`). 탭 시 `url_launcher` `LaunchMode.externalApplication`으로 `${EnvConfig.labelerUrl}/labeling/{clipId}` 오픈.

**수정 파일**:
- `lib/core/config/env_config.dart` — `static bool get labelerEnabled` (피처플래그), `static String get labelerUrl => dotenv.env['LABELER_URL'] ?? '';` (opaque secret 박지 않음 — `.env`로만 주입).
- `lib/features/my_cage/presentation/clip_player_screen.dart` — AppBar `actions`에 `LabelerEntryButton(clipId: widget.clipId)` 추가 (피처플래그 가드 안에서).
- `lib/features/my_cage/presentation/my_cage_providers.dart` — `myLabelerStatusProvider = FutureProvider<LabelerStatus?>` 추가.
- `assets/l10n/ko.json` — `my_cage_labeler_open` 키.

**신규 Provider**:
- `myLabelerStatusProvider` — 앱 라이프 1회면 충분 (autoDispose 안 씀).

**선행 의존**: PR1.

**검증**:
1. 백엔드 미구현(404) → 버튼 미노출
2. `is_labeler=false` → 미노출
3. `is_labeler=true` → 노출 + 탭 시 외부 브라우저 오픈
4. `LABELER_URL` 빈 값 → SnackBar 안내

---

## Phase C 회귀 검증 시나리오 (PR 머지 전마다 공통)

1. 카메라 등록: my_cage → "+" → IP/계정 → 연결 테스트 → 등록 → 목록에 신규 row
2. 카메라 삭제: detail → 휴지통 → confirm → 목록 invalidate → pop
3. 클립 그리드 진입: 카메라 detail → latest jump → HourChipRow → 60개 그리드 + 썸네일
4. 클립 재생: 그리드 탭 → 영상 initialize → 자동 play → seek/pause/play
5. 시간/날짜 페이징: HourChipRow 다른 hour → 즉시 갱신. 캘린더 → 날짜 선택 → hourCounts 갱신 + nearest hour 자동 이동
6. 인증 갱신: Supabase 강제 signOut → 401 → `/login` redirect
7. 모션 필터 토글: ClipFilterBar onlyMotion → 그리드/HourChipRow 즉시 갱신
8. 빈 상태: 클립 0건 날짜 → empty body + "다른 날짜 선택" 동작

---

## Phase C 가드레일 (handoff 문서 준수)

- **회귀 0**: 기존 카메라/클립/재생/인증 흐름 그대로 동작. 새 기능이 깨면 PR 막힘.
- **petcam-lab 코드 수정 금지**: 본 plan은 `lib/features/my_cage/**` + `lib/core/router/app_router.dart` + `lib/core/config/env_config.dart` + `assets/l10n/ko.json`만 변경.
- **라벨 수정 UI 만들지 않음**: PR3 chip은 read-only `Chip`만 사용.
- **백엔드 endpoint 시그니처 임의 변경 금지**: 본 plan에 적힌 응답 shape이 Flutter가 가정한 contract. 백엔드가 그대로 맞춤.
- **opaque secret 박지 않음**: `LABELER_URL`은 `.env` 주입, 코드 fallback은 빈 문자열.
- **destructive 동작 사용자 승인 없이 금지**: 마이그레이션, force push, 브랜치 삭제 모두.

---

## Phase C 작업 순서 요약

1. petcam-lab에서 `/clips/{id}/file/url`, `/thumbnail/url`, `/labels`, `/inference` 4개 ready 신호 → **PR1 시작**
2. PR1 머지 → PR2 (영상/썸네일 async 전환) → PR3 (라벨 chip)
3. petcam-lab에서 `/me/is_labeler` ready 신호 → **PR5** + `.env` `LABELER_ENABLED=true`
4. petcam-lab에서 `/clips/highlights` ready 신호 → **PR4** + `.env` `HIGHLIGHTS_ENABLED=true`

---

# Phase D — UI Redesign

> 레퍼런스: `/Users/baek/Desktop/new-app-design/` 6장 (001-main-tab, 002-my-cre-tab, 003-01-cre-cam-tab, 003-02-cre-cam-tab-detail-page, 004-cage-tab, 005-community-tab)

## Phase D 진행 현황 (2026-06-09 업데이트)

5탭 IA + 주요 탭이 구현됨 (커밋 `a62a012`, `55c46d5`). `StatefulShellRoute.indexedStack` 기반 5탭 BottomNav 동작.

| 항목 | 상태 | 비고 |
|------|------|------|
| **D1** 5탭 BottomNav 골조 | ✅ 구현 | `/home` `/my-pets` `/crecam` `/smart-cage` `/community` (`app_router.dart`) |
| **D2** 크레캠 탭 | ✅ 구현 | `crecam_screen.dart` (현 my_cage 흡수), `cameras/:cameraId`, `clips/:clipId` |
| **D4** 마이 크레 탭 | ✅ 구현 | `my_pets_screen.dart` + `add`/`:petId`/`:petId/edit` (pets CRUD) |
| **D7** 홈 탭 | ✅ 구현 | `home_screen.dart` 재구성 |
| **D8** 사육장 탭 (IoT) | ✅ 구현 | **terra-server 채택** — 아래 § 참조. `smart_cage_screen.dart` + BLE 페어링 |
| **D9** 커뮤니티 탭 | ✅ 구현 | `community_screen.dart` + Supabase `community` 데이터 |
| D3/D5/D6 sub-tab 세부 | 부분/점진 | 크레캠 detail·하이라이트 모음·리포트 그래프는 점진 적용 |

> 위키/자진신고(P0 3탭)는 BottomNav 에서 빠지고 보조 라우트(`/wiki`, `/search` 등)로 유지.

## terra-server 사육장 IoT 통합 (D8 실현 — 2026-06-09)

미정 사항 #2(사육장 IoT 통합 범위)를 **terra-server 백엔드 채택**으로 확정·구현.

- **백엔드**: terra-server (ESP32-S3 펌웨어 + terra-bridge MQTT dispatcher + terra-api REST). **메인 앱과 동일한 Supabase 프로젝트 공유**.
- **연동 테이블**(Flutter): `devices`(SELECT) / `telemetry`(Realtime INSERT) / `commands`(INSERT + Realtime UPDATE). 캠(`cameras`/`motion_clips`)은 전환 범위 밖 — 게코캠은 petcam-lab `camera_clips` 유지.
- **제어**: 팬/히터(safety latch)/LED 밝기/워터펌프 릴레이 → `commands` INSERT → MQTT → ESP32 → ack Realtime.
- **모니터링**: DHT22 2채널 온/습도 + 액추에이터 상태 실시간(`telemetry` 3초 주기).
- **페어링**: BLE(`flutter_blue_plus` + `permission_handler`) — SSID/PASS/NAME/JWT 전달 → ESP32 가 `POST /devices/pair`.
- **단일 진실 소스**: `~/Downloads/APP_INTEGRATION.md`(terra-server v0.1.0). 스키마: `docs/supabase-schema.md § terra-server IoT 테이블`.
- **E2E 검증 완료**(2026-06-09): 디바이스 목록/온습도 실시간/제어(팬·히터·LED·릴레이)/BLE 페어링 실기 동작 확인. 캠 라이브는 범위 밖.

**신규 파일**(my_cage feature 내):
- 데이터: `data/ble_pairing_repository.dart`, `data/supabase_module_control_repository.dart`
- 도메인: `domain/device.dart`, `domain/telemetry_reading.dart`, `domain/device_command.dart`, `domain/actuator_state.dart`
- 화면/위젯: `presentation/smart_cage_screen.dart`, `presentation/device_pairing_screen.dart`, `presentation/supabase_module_providers.dart`, `presentation/widgets/{actuator_controls,heater_lock_dialog,module_status_card}.dart`

## IA 변경 (3탭 → 5탭)

| 현재 | 신규 (BottomNav 5탭) |
|------|---------------------|
| 검색 / 모프 / 가이드 + my_cage 진입 | 홈 / 마이 크레 / 크레캠 / 사육장 / 커뮤니티 |

### 탭별 정의

| 탭 | 핵심 컴포넌트 | 데이터 source |
|----|-------------|--------------|
| **홈** | 환영 헤더 + 내 개체 라이브 카드(이미지+이름+종+온/습도) + 활동량 분석 요약(어젯밤 그래프) | pets + cameras + behavior_labels 시계열 집계 |
| **마이 크레** | 3 sub-tab: 개체 목록 / 리포트 / 하이라이트 모음. 개체 카드(이미지+이름+종+체중+입양일) + "정보 수정" + "새 개체 등록" CTA | pets 테이블 (Supabase) + behavior_labels |
| **크레캠** | 카메라 그리드/리스트 토글, 카드(썸네일+온/습도+상태), "새 카메라 찾기" placeholder, FAB(+) | 현재 my_cage_screen 흡수 |
| **크레캠 detail** | 영상 상단 + 간단 활동량(어제/오늘 토글, 움직임/음수/식사 카운트) + 비디오 기록(하이라이트/움직임만/전체 필터) | clips + behavior_labels 집계 |
| **사육장** | 메인/서브 사육장 카드, 현재 온/습도, "환기 조절" / "환경 설정" 버튼, 가이드라인 초과 경고 | IoT 디바이스 (백엔드 미정) |
| **커뮤니티** | 카테고리 칩(전체/공지/사육위키/Q&A/...) + 게시글 카드 리스트, FAB(+) | 커뮤니티 백엔드 (미정) |

## Phase C와 Phase D의 정합 포인트

| Phase C 산출물 | Phase D에서의 위치 |
|---------------|------------------|
| PR3 라벨 chip 섹션 | 크레캠 detail 클립 row의 chip("음수" 등)으로 재배치 |
| PR4 하이라이트 화면 | "마이 크레 → 하이라이트 모음" sub-tab + "크레캠 detail → 비디오 기록 → 하이라이트" 필터 양쪽 진입점 |
| PR5 labeler 외부 링크 | 위치 변경 없음 (clip detail AppBar 유지) |
| 현재 `MyCageScreen` | 크레캠 탭으로 이동 + 카드 디자인 적용 (그리드/리스트 토글, 카드 레이아웃) |
| 현재 P1 placeholder `ProfileScreen` | 마이 크레 탭에 흡수 (개체 관리 + 리포트) |

## Phase D 작업 큰 그림 (PR 분할은 사용자 합의 후 확정)

| PR | 범위 | 의존 |
|----|------|------|
| **D1** | BottomNav 5탭 골조 + GoRouter ShellRoute 도입. 5개 placeholder 화면 (탭 전환만 동작) | 없음 |
| **D2** | 크레캠 탭 — 현재 `MyCageScreen`을 D1의 크레캠 위치로 이전 + 카드 디자인(003-01) 적용 | D1 |
| **D3** | 크레캠 detail — 003-02 디자인 적용. 간단 활동량 토글(어제/오늘) + 비디오 기록 필터(하이라이트/움직임만/전체) | Phase C PR3 + PR4, D2 |
| **D4** | 마이 크레 탭 — 개체 목록 sub-tab (pets CRUD) + "정보 수정" 페이지 + "새 개체 등록" 폼 | D1, pets 테이블 정합 확인 |
| **D5** | 마이 크레 — 하이라이트 모음 sub-tab (Phase C PR4 화면 재배치) | D4, Phase C PR4 |
| **D6** | 마이 크레 — 리포트 sub-tab (활동량 시계열 그래프) | D4, behavior_labels 집계 endpoint |
| **D7** | 홈 탭 — 환영 헤더 + 내 개체 라이브 카드 + 활동량 분석 요약 그래프 | D6과 동일 데이터 source |
| **D8** | 사육장 탭 — IoT 통합 (백엔드 추가 필요, Phase 결정 필요) | IoT 백엔드 |
| **D9** | 커뮤니티 탭 — Q&A/공지/사육위키 게시판 (백엔드 추가 필요) | 커뮤니티 백엔드 |

> D3 / D5는 Phase C가 끝나야 풀 동작. D1 / D2 / D4는 Phase C와 병렬 가능.

## Phase D 미정 사항 (사용자 후속 결정 필요)

1. **활동량 그래프 데이터 source** — VLM 라벨 시계열을 클라이언트에서 집계 vs 백엔드에 `/pets/{id}/activity-summary?date=` endpoint 추가? (홈 + 마이 크레 리포트 + 크레캠 detail 간단 활동량 3곳에서 공통 사용)
2. ~~**사육장 IoT 통합 범위**~~ — ✅ **해결(2026-06-09)**: 자체 디바이스(ESP32-S3 + terra-server) 채택, D8 구현 완료. 위 § terra-server 사육장 IoT 통합 참조.
3. **커뮤니티 백엔드** — Supabase 테이블만으로 가능 vs 별도 서비스 (notification, moderation 필요)?
4. **마이 크레 vs 기존 P1 ProfileScreen** — 마이 크레 탭이 기존 P1 placeholder를 흡수하는 게 맞나? P1 로드맵 재정의 필요.
5. **Phase C ↔ Phase D 인터리브** — Phase C 5 PR 끝나고 Phase D 시작 vs D1(BottomNav 골조)을 Phase C 사이에 끼워넣기?
6. **GoRouter ShellRoute 패턴** — 현재 단일 라우트 구조에서 BottomNav + per-tab 스택을 어떻게 구성? (StatefulShellRoute.indexedStack 권장)
7. **개체(pet) 모델 정의** — 현재 `pets` 테이블에 어떤 필드 있는지 / 디자인의 "릴리 화이트 / 12g / 입양일 2025.01.15"를 다 커버하나?
8. **온도 단위 / locale** — 디자인이 ℃ / 한국어 고정인데 P1의 en 다국어 계획과의 정합?

---

## Critical Files (Phase C 기준)

기존 (수정 대상):
- `lib/features/my_cage/data/clip_repository.dart` (PR1 메서드 추가, PR2 동기 함수 삭제)
- `lib/features/my_cage/presentation/clip_player_screen.dart` (PR2 async 전환, PR3 chip 섹션, PR5 labeler 버튼)
- `lib/features/my_cage/presentation/my_cage_providers.dart` (PR2~5 provider 추가)
- `lib/features/my_cage/presentation/widgets/clip_grid_card.dart` (PR2 헤더 제거)
- `lib/features/my_cage/presentation/widgets/clip_card.dart` (PR2 헤더 제거)
- `lib/features/my_cage/presentation/my_cage_screen.dart` (PR4 AppBar 아이콘)
- `lib/core/router/app_router.dart` (PR4 라우트 추가, Phase D BottomNav 재설계)
- `lib/core/config/env_config.dart` (PR4/5 피처플래그 + labelerUrl)
- `assets/l10n/ko.json` (PR3/4/5 + Phase D 신규 키 다수)

신규 (생성, Phase C):
- `lib/features/my_cage/domain/action_type.dart`
- `lib/features/my_cage/domain/lick_target_type.dart`
- `lib/features/my_cage/domain/behavior_label.dart`
- `lib/features/my_cage/domain/behavior_inference.dart`
- `lib/features/my_cage/domain/clip_media_url.dart`
- `lib/features/my_cage/domain/highlights_page.dart`
- `lib/features/my_cage/domain/labeler_status.dart`
- `lib/features/my_cage/presentation/widgets/clip_thumbnail.dart`
- `lib/features/my_cage/presentation/widgets/behavior_chip_section.dart`
- `lib/features/my_cage/presentation/highlights_screen.dart`
- `lib/features/my_cage/presentation/widgets/highlight_row.dart`
- `lib/features/my_cage/presentation/widgets/labeler_entry_button.dart`

신규 (Phase D, PR 분할 합의 후 확정):
- `lib/features/shell/` — BottomNav 골조 + StatefulShellRoute
- `lib/features/home/` — 홈 탭 화면 + 활동량 요약 위젯
- `lib/features/my_creature/` — 마이 크레 탭 (개체/리포트/하이라이트 sub-tab)
- `lib/features/cre_cam/` — 크레캠 탭 (현 my_cage 흡수, 폴더명 미정)
- `lib/features/smart_cage/` — 사육장 탭 (IoT)
- `lib/features/community/` — 커뮤니티 탭

---

## End-to-End 검증 절차

각 PR 머지 전:
1. `flutter analyze` 0 issues
2. `flutter test`
3. `flutter build apk --debug` (Android 빌드 통과)
4. `flutter build ios --simulator` (iOS 빌드 통과)
5. Phase C 회귀 시나리오 8개 실 디바이스/시뮬레이터 수동 검증
6. 해당 PR 신규 기능 수동 검증 (각 PR §검증 참조)
7. (Phase D부터) 디자인 레퍼런스와 픽셀 비교 + 디자인 시스템 토큰 사용 여부 확인 (`docs/design-system.md`)

전체 머지 후:
- 일반 유저(is_labeler=false) 플로우: 클립 재생 + 라벨 chip 표시 + 하이라이트 탭 보임/숨김(플래그)
- labeler 유저 플로우: clip detail에서 외부 브라우저로 labeler 진입
- 백엔드 endpoint 추가됨에 따라 `.env`의 `HIGHLIGHTS_ENABLED`, `LABELER_ENABLED` 단계적 ON
- (Phase D 완료 후) 5탭 BottomNav 진입/전환/back stack/딥링크 정상

---

## 변경 이력

- 2026-05-07: 초안 작성. Phase C(PR1~5) 사용자 합의 완료. Phase D(PR D1~D9) 큰 그림 + 미정 8개 명시.
- 2026-06-09: Phase D 진행 현황 추가(5탭 IA + D1/D2/D4/D7/D8/D9 구현). **D8 사육장 IoT = terra-server 채택·구현**(미정 #2 해결). 커밋 `a62a012`(전환) + `55c46d5`(BLE 권한). E2E 검증 완료(캠 제외).
