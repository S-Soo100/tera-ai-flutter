# 카메라 탭 재설계 — Figma Camera 섹션 구현 계획 (2026-09-04)

PRD 재설계 2단계. SOT: Figma `vivanaut app` > Camera 섹션(668:316). 사용자 지시
"피그마의 Camera frame을 보고 우리의 'camera'탭을 피그마대로 구현해"(2026-09-04).

## 0. 화면 목록 (Figma 프레임 ↔ 라우트)

| Figma | 화면 | 라우트 | 상태 |
|---|---|---|---|
| Camera Home (668:427) | CrecamScreen **전면 재작성** | `/crecam` (탭2) | 신규 |
| 하이라이트 상세 (668:600 배너有 / 668:655 배너無) | HighlightsScreen | `/crecam/highlights` (셸 밖 최상위) | 신규 |
| 북마크 상세 (668:717) | BookmarksScreen | `/crecam/bookmarks` (셸 밖 최상위) | 신규 |
| 플레이어 (668:743) | ClipPlaylistPlayerScreen | `/crecam/player/:clipId` (셸 밖 최상위) | 신규 |

**존치**: `/crecam/cameras/pair`(페어링), `/crecam/cameras/:cameraId`(CameraDetailScreen),
`/crecam/motion-clips/:clipId`(기존 가로 플레이어 — 마이크레 리포트 `/my-pets/clips/:clipId`와 공유),
`/crecam/clips/:clipId`(레거시). 기존 CrecamScreen의 카메라 그리드/리스트는 폐기.

## 1. 공통 실측 (Figma, 393pt 프레임 / 콘텐츠 369 = 좌우 마진 12)

- 팔레트: 기존 GlassPalette 토큰 그대로 — surfaceTint #F0F4F9, textSecondary #3C3C3C,
  textTertiary #919497, deviceOff #9DA3BA(아이콘 원), textStrong #1E1E1E.
  신규 색 1종: **경계선 #E1E3E4** (기간 설정 버튼 stroke) — GlassPalette에 `outline` 토큰
  추가(6곳 동시 수정: 선언·생성자·dark·light·copyWith·lerp). 다크벌은 기존 divider 계열로 도출.
- 타이포: Pretendard, letterSpacing -2%. 섹션 시간 16 SemiBold #3C3C3C,
  보조 14 Medium/SemiBold #919497, 타이틀 18 Bold #000.

## 2. Camera Home (CrecamScreen 재작성)

세로 단일 스크롤, 위→아래:

1. **헤더**: `HomeHeaderBar` 재사용(세트 필 + [+] + 사람). Figma Frame 55와 동일 구성.
   - [+] 메뉴에 **카메라 추가** 항목 신설(`/crecam/cameras/pair`) — 기존 FAB·카메라
     그리드가 사라지면서 2번째 카메라 페어링 진입점이 없어지기 때문(홈에서도 유효).
2. **라이브**(369×271 radius 12, 우하단 32pt 확장버튼): 신규 `CameraLiveArea` —
   `TopFixedArea`와 달리 **camerasProvider 전체**를 PageView로 돈다(세트에 안 묶인
   카메라도 도달 가능해야 함 — 기존 카메라 그리드의 역할 흡수). 페이지가
   `WebRtcLiveView(cameraUuid, cover:true)` 재사용, 확장버튼 → `/crecam/cameras/:id`.
   현재 보는 카메라 인덱스는 `selectedCrecamCameraProvider`(StateProvider)로 노출 —
   아래 클립 그리드의 기준 카메라. 카메라 0대면 접힌 안내 + "카메라 연결" 버튼(페어링).
3. **엔트리 카드 2개**(Frame 61): 각 178.5×72 근사 — `Expanded` 2개 + 갭 12,
   bg surfaceTint radius 12, 좌 40×40 원(#9DA3BA=deviceOff) 안 24 아이콘(cards_star/
   bookmark_check — Material `star`/`bookmarks`로 대체), 타이틀 16 SemiBold
   ("하이라이트"/"북마크 영상"), 서브 14 Medium #919497 "업데이트 {상대시각}".
   - 하이라이트 최신 시각: `highlightRepository.list(since: 30일 전, limit 1)` 래핑 provider.
   - 북마크 최신 시각: `favoriteClipRepository.listAll()` 최신 favoritedAt.
   - 탭 → `/crecam/highlights` / `/crecam/bookmarks`.
4. **기간 설정 버튼**(우측 정렬 95×40, bg white, stroke `outline`, radius 8,
   calendar_today 16 + "기간 설정" 14 SemiBold): showDatePicker → 선택 날짜의 클립.
   기본값 = 오늘. 선택 상태는 `crecamDayProvider`(StateProvider<DateTime>).
5. **시간대별 클립 그리드**(선택 날짜, 기준 카메라): `motionClipsProvider((cameraId,
   day))` 재사용 → 클라이언트에서 hour 그룹핑, 최신 시간부터. 섹션 헤더: 좌
   "오전 8:00"(16 SemiBold) + 우 날짜 "2026. 8. 31"(14 SemiBold #919497, **첫 섹션만**).
   그리드: 3열, 셀 비율 121.67:113, 갭 2, 그룹 전체 radius 12로 클립.
   썸네일 `motionThumbnailProvider` + CachedNetworkImage(기존 _MotionClipPoster 패턴).
   셀 탭 → `/crecam/player/:clipId` + extra로 그 날짜 전체 클립 id 목록(재생목록).
   클립 0건이면 빈 상태 문구.

## 3. 플레이어 (ClipPlaylistPlayerScreen — 세로 고정)

Figma 668:743. **세로 고정**(기존 가로 플레이어와 별개 — 미결 R "가로 버전 or 회전
금지"는 회전 금지로 잠정 확정, PRD에 기록). 흰 배경.

- 상단바(44): 좌 back(arrow_back_ios_new 44×44) + 중앙 2줄: 날짜 "2026. 08. 28"
  16 SemiBold + 시각 "오전 10:21" 14 Medium #919497 — **현재 재생 클립**의 startedAt.
- 페이지네이션 세그먼트(345 폭, 상단바 아래): 재생목록 클립 수만큼 균등 분할 바(높이 4,
  radius 2, 갭 8), 현재 인덱스 #1E1E1E, 나머지 #E1E3E4. 클립 수 많으면(>10) 표시 생략.
- 비디오: 풀폭 393×224(16:9 letterbox, 검정 배경 없이 흰 바닥 위 그대로).
- 시크바(345 폭): 기존 VideoControls의 Slider 로직 재사용하되 Figma 스타일(회색 트랙
  + 진한 진행).
- 컨트롤 로우: fast_rewind+"10초 전" / pause·play(44) / fast_forward+"10초 뒤"
  (12 SemiBold #1E1E1E).
- 하단 액션 필(172×48 radius 24 bg surfaceTint, 중앙 정렬): bookmark(즐겨찾기 토글,
  기존 favorite 로직) / share / download — 기존 `_save`/`_share`/`_toggleFavorite`
  로직(video_export_service, favoriteClipRepository) 이식.
- **이전/다음**: 화면 좌/우 절반 탭 → 이전/다음 클립(Figma 노트 "제스쳐, 오른쪽 왼쪽
  터치"). 영상 끝나면 자동 다음(마지막이면 정지). 컨트롤 위젯 위 탭은 컨트롤 우선.
- 재생목록: GoRouter extra `List<String>`(clip id 순서). extra 없으면(딥링크) 단일 재생.
- 초기화·에러·재시도는 기존 MotionClipPlayerScreen `_init` 패턴(즐겨찾기 로컬 파일
  우선 → presign URL, retry 시 invalidate) 재사용. 컨트롤러 dispose 누수 주의
  (메모리 project_video_player_controller_leak).

## 4. 북마크 상세 (BookmarksScreen)

- 상단바: back + 중앙 "북마크" + 우 calendar(기간 필터 — 날짜 선택 시 그 날짜만).
- 리스트: 카드 = 헤더 "2026. 08. 12 · 오전 12:50"(16 SemiBold) + 8 갭 + 썸네일
  369×180 radius 12. 카드 간 20.
- 데이터: `favoriteClipRepository.listAll()` 래핑 `allFavoriteClipsProvider` 신설,
  favoritedAt/startedAt desc. 썸네일은 로컬 mp4가 있어도 **키/URL 우선**
  (motionThumbnailProvider) — 없으면 회색 플레이스홀더.
- 탭 → `/crecam/player/:clipId` + extra 재생목록(북마크 전체 순서).

## 5. 하이라이트 상세 (HighlightsScreen)

- 상단바: back + 중앙 "하이라이트" + 우 calendar.
- **도착 배너**(최신 묶음 있을 때만, 668:644): bg surfaceTint radius 12, 패딩 20 —
  "하이라이트가 도착했어요" 18 Bold + 기간 14 Medium #545454(→textSecondary 근사) +
  대표 썸네일(폭 가득 radius 12, 뒤에 살짝 겹친 카드 스택 장식) + 우상단 X(44).
  X 탭 → 그 묶음 key를 Hive `app_settings`에 dismiss 저장(재방문 시 유지).
  배너 탭 → 플레이어(그 묶음 재생목록).
- 묶음 섹션: 헤더 "2026. 8. 28 - 8. 31"(16 SemiBold) + 3열 그리드(Camera Home과 동일
  규격). 묶음 = **최신 하이라이트부터 3일(72h) 창으로 앱측 그룹핑**(정책 노트
  "2-3일 하이라이트를 묶어서 제공" — 백엔드 묶음 계약이 아직 없어 앱이 근사, 계약이
  생기면 교체). 행동 필터는 정책대로 없음.
- 데이터: `highlightRepository.list(since: 30일 전, limit 200)` → clipId로
  motion_clips 썸네일(`motionThumbnailProvider`). 신규 `highlightGroupsProvider`.
- 탭 → 플레이어(그 묶음 재생목록).

## 6. 신규 데이터/프로바이더 요약

- `selectedCrecamCameraProvider` — 카메라 탭 라이브 PageView 인덱스.
- `crecamDayProvider` — 기간 설정 날짜(기본 오늘).
- `crecamHourGroupsProvider` — (카메라,날짜) 클립 hour 그룹.
- `allFavoriteClipsProvider` — listAll 래핑(+최신 favoritedAt).
- `latestHighlightProvider` / `highlightGroupsProvider` — 엔트리 카드 시각 + 묶음.
- ko.json 신규 키: `crecam_home_*`(entry cards, 기간 설정, 빈 상태),
  `crecam_bookmarks_*`, `crecam_highlights_*`(배너), `crecam_player_*`(10초 전/뒤).

## 7. 구현 순서 (커밋 단위)

1. **T1 플레이어** — 독립 신규 화면 + 라우트. (다른 화면의 탭 목적지 선행)
2. **T2 Camera Home** — CrecamScreen 재작성 + CameraLiveArea + 그리드 + 엔트리 카드
   + [+] 메뉴 카메라 추가 + GlassPalette `outline` 토큰.
3. **T3 북마크 상세**.
4. **T4 하이라이트 상세**.
5. **T5** — 문서(CLAUDE.md·PRD 대조표) + 시뮬레이터 검증 + 잔여 정리.

각 단계: flutter analyze 0 + 관련 테스트 + 자동 커밋·푸시. 구현은 flutter-dev
에이전트(Critical 트랙), 검증은 메인이 시뮬레이터로.

## 8. 리스크 / 미결

- 하이라이트 묶음은 앱측 근사(72h 창) — 백엔드 계약 확정 시 교체(PRD 미결).
- 세로 플레이어 도입으로 PRD §6-B(전체화면 가로)와 이원화 — 카메라 탭 계열은 세로,
  마이크레 리포트 경로는 기존 가로 유지. 미결 R은 "회전 금지" 잠정.
- 기존 CrecamScreen 폐기로 카메라 목록 그리드 사라짐 — 라이브 PageView(전 카메라)가
  대체. 카메라 다수(5+)면 PageView 탐색이 불편할 수 있음(후속 관찰).
