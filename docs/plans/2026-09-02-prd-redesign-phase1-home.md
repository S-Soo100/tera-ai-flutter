# PRD 재설계 1단계 — 홈 개편 구현 계획

> **구현 방식 (CAOF):** Critical 트랙. 이 계획을 task 단위로 구현한다. 사용자가 2026-09-02 구현을 사전 승인함 (GATE 3 완료). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Figma `vivanaut app` 페이지대로 4탭(홈/카메라/마이크레/커뮤니티) 재배열 + 홈 단일 스크롤 + 온습도 상세(일간·주간·제어 기록) + Asset 팔레트 토큰 교체 + 위키·검색 진입점 제거.

**Architecture:** 기존 GoRouter StatefulShellRoute 4브랜치를 유지하되 통계 브랜치를 카메라(기존 CrecamScreen)로 교체. 홈은 단일 스크롤로 재작성하고, 온습도 상세는 신설 풀스크린 라우트. 색 토큰은 GlassPalette(ThemeExtension) 값 교체(소비처 API 불변)로 전환한다.

**Tech Stack:** Flutter + Riverpod + GoRouter + fl_chart(기존 EnvChart는 커스텀 페인트) + easy_localization + Supabase(telemetry_30m·commands).

**근거 문서:** `docs/prd-vivnanaut-app.md` (2026-09-02 개정) — §2.1(4탭), §4.1(홈), §4.3(온습도 상세). Figma `vivanaut app` 페이지 (SOT).

---

## §A. Figma 실측 스펙 (2026-09-02 채굴 — talk-to-figma)

구현 시 이 절만 보면 되도록 실측값을 전부 옮겨 둔다. 노드 ID는 재확인용.

### A.1 팔레트 (Asset 섹션 668:2691)

| 토큰(신규 이름) | HEX | 용도 |
|---|---|---|
| `primary` | `#192553` | 브랜드 네이비 (기존 brandNavy와 동일값). 활성 탭·선택 세그먼트·주 버튼 |
| `primaryDisabled` | `#9DA3BA` | 비활성 주 버튼 |
| `accentRed` | `#D61619` | 브랜드 레드 (스와치 존재, 화면 내 용도는 아직 미배정 — 위험 상태 예약) |
| `textStrong` | `#1E1E1E` | 대형 수치·타이틀 |
| `textBody` | `#3C3C3C` | 본문·버튼 텍스트·아이콘 |
| `textMid` | `#626262` | 세그먼트 비선택 등 중간톤 |
| `textMuted` | `#919497` | 보조 라벨·비활성 탭·축 라벨 |
| `iconDisabled` | `#A9B3BE` | 꺼짐 상태 아이콘 원 배경 (`#A9B4BE` 혼용 — B3BE로 통일) |
| `border` | `#E1E3E4` | 칩 테두리·상단바 하단선 |
| `surfaceSubtle` | `#EAEEF0` | 비활성 칩 배경 |
| `surfaceTint` | `#F0F4F9` | 연회색 면(헤더 필·온습도 카드·꺼짐 타일·일정 버튼·탭바 top stroke) |
| `segmentTrack` | `#EFF2F5` | 세그먼트 트랙 배경 |
| `surfaceHeader` | `#FAFBFD` | 상세 상단바·제어기록 섹션 배경 |
| `surface` / `bg` | `#FFFFFF` | 카드·페이지 바닥 (홈·상세 바닥 흰색) |
| `tempAccent` | `#F85478` | 온도 라인·온도계 아이콘·주간 온도 강조 바 |
| `humidAccent` | `#00B2F3` | 습도 라인·물방울 아이콘·분무 아이콘·주간 습도 강조 바 |
| `deviceFan` | `#00B591` | 환기팬 아이콘/그린 (타일 배경 `#DCF5E9`) |
| `deviceCool` | `#6B7FFF` | 냉각팬 아이콘/블루 (타일 배경 `#E0E5FF`) |
| `deviceLed` | `#F5A800` | LED 아이콘/앰버 (타일 배경 `#FFF4D9`, 밝기 게이지 `#FFE2A3`) |
| `deviceMist` | `#00B2F3` | 분무 아이콘 (= humidAccent) |
| `deviceHeat` | `#FF6B57` | 히터팬 (⚠️ Figma 미정의 — 도출값. 타일 배경 `#FFE9E4` 도출) |
| 태그 블루 | bg `#E5EEFF` / fg `#0069F1` | Tag 컴포넌트 (성별 등) |
| 태그 옐로 | bg `#FFF8DB` / fg `#F5A800` | 〃 |

- 라이트 단일 기준. 다크 팔레트는 Figma에 없음 → **기존 다크벌은 값 유지**(후속 과제), 라이트벌만 교체.
- 폰트 Pretendard 유지. letterSpacing = fontSize × -2%.

### A.2 컴포넌트 규격 (Asset)

- **버튼**: radius 8. S=28h(패딩 8×5, 텍스트 14 SemiBold), M=32h(12×7, 14 SemiBold), L=44h(16×10, 텍스트 16). Enabled bg `#192553`/white, Disabled bg `#9DA3BA`/white.
- **칩**: radius 16, h32. Enabled `#192553`/white 14 SemiBold. Default white + border `#E1E3E4`, text `#3C3C3C` 14 Medium. Disabled bg `#EAEEF0`, text `#A9B4BE`.
- **토스트**: white bg radius 8, h60, 좌측 28 원형 아이콘(`#192553`) + 텍스트 18 Medium `#1E1E1E`.
- **세그먼트(수평 토글)**: 트랙 `#EFF2F5` radius 18 h32, 선택 반쪽 white radius 14 h28(inset 2), 선택 텍스트 14 Bold `#3C3C3C`, 비선택 14 SemiBold `#626262`.
- **상단 탭(사육장|크레캠형)**: h48, 선택 = 20 Bold `#192553` + 하단 언더라인 `#192553`, 비선택 20 Medium `#919497`.

### A.3 하단 탭바 (Navigation 668:2485)

- 393×80(+safe area), bg white, **top stroke `#F0F4F9`**. 그림자 없음.
- 탭 4개: `Home`(home) / `Camera`(camera_video) / `MyCre`(fertile=발바닥) / `Community`(mode_comment). 아이콘 24, 라벨 12 Medium, 간격 icon→label 4.
- 활성 `#192553`, 비활성 `#919497`. **라벨은 영문 그대로**(Figma 표기 채택).

### A.4 홈 화면 (668:833, 393×852)

위→아래, 좌우 마진 12, 섹션 간격 12:

1. **헤더** (369×44): 좌 세트 드롭다운 필(bg `#F0F4F9` radius 12 h44, 텍스트 16 SemiBold `#3C3C3C` + `keyboard_arrow_down` 24) / 우 원형버튼 44×44 radius 22 bg white ×2: `add`, `person` (아이콘 `#3C3C3C`). 버튼 간격 12.
2. **라이브** (369×271 radius 12): 영상 fill, 우하단 32×32 radius 16 black 30% + white `zoom_out_map` 아이콘(전체화면). LIVE/OFFLINE 뱃지·재연결은 기존 스펙 유지.
3. **온습도 요약 카드** (369×69, bg `#F0F4F9` radius 12): 2열. 각 열 = 값 20 SemiBold `#1E1E1E`(`32℃`/`60%`) + `최고: 36° 최저:27°` 14 Medium `#919497`. 패딩 16×12. **카드 탭 → 온습도 상세**.
4. **제어 그리드** (369, 타일 180.5×72, 가로/세로 갭 8, radius 12): 타일 = 좌 40×40 radius 20 아이콘 원 + 이름 16 SemiBold `#3C3C3C` + 상태 14 Medium(켜짐 `#3C3C3C`/꺼짐 `#919497`), 패딩 16.
   - ON: 기기색 타일 (환기팬 `#DCF5E9`+`#00B591`, 냉각팬 `#E0E5FF`+`#6B7FFF`, LED `#FFF4D9`+`#F5A800`+밝기 게이지 `#FFE2A3` 좌측 채움, 히터팬 `#FFE9E4`+`#FF6B57`(도출)). OFF: bg `#F0F4F9` + 아이콘 원 `#A9B3BE`.
   - 분무는 모멘터리(작동 후 5초 잠금) — OFF 스타일 기본, 작동 직후 5초는 humid 색.
   - 타일 5개(환기팬·분무·냉각팬·히터팬·LED) → 2열 3행, 마지막 홀수 칸은 빈 칸.
5. **일정 설정**: 라벨 `일정 설정` 14 Medium `#919497` + 로우 버튼 369×51 bg `#F0F4F9` radius 12(텍스트 16 SemiBold `#3C3C3C` + `arrow_forward_ios` 18).

### A.5 온습도 상세 — 일간 (668:899, 393×1090 스크롤)

- **상단바**: h106(상태바 포함), bg `#FAFBFD` + 하단선 `#E1E3E4`. 타이틀 `온습도 상세` 16 Bold 중앙, 우측 ✕ 44×44.
- **세그먼트** `[일간|주간]`: A.2 수평 토글, 상단바 아래 마진 12.
- **날짜 페이저**: `←` 40×40 / `2026. 8. 30` 18 SemiBold `#3C3C3C` 중앙 / `→`(오늘이면 숨김·비활성). 세로 h40.
- **마커 아이콘 행 + 차트** (GraphGroup): 차트 전체 폭 524pt(= 24h)로 **가로 스크롤**, 화면 좌우 12 흰 마스크. X축 눈금 `오전 12시/오전 6시/오후 12시/오후 6시` 12 Medium `#919497`(자정 경계). Y좌 온도 6눈금(45°~20°), Y우 습도 6눈금(75%~50%) — 눈금 6개 고정·1-2-5 계열은 기존 EnvChart 규칙 재사용. 라인: 온도 `#F85478`, 습도 `#00B2F3`.
  - 마커 행: 차트 위 y=차트상단, 28×28 radius 14 원 아이콘. 동작 시각 x좌표에 기기색(ON)/`#A9B3BE`(OFF·꺼짐) 원. 겹치면 좌우로 밀착 배치(Figma는 22px 간격 겹침 허용).
  - **스크러버**: 차트 롱프레스/드래그 → 세로선 + 상단 툴팁 칩(`오전 11:23` + `35.2°C 59%`).
  - 오늘 페이지 기본 가로스크롤 위치 = 현재 시각이 보이는 끝쪽. 미도래 구간은 데이터 없음(빈 영역).
- **현재값 바** (h54): 2열 — 28×28 radius 14 아이콘 원(`thermometer` `#F85478` / `humidity_high` `#00B2F3`) + 값 28 SemiBold `#1E1E1E` + 아래 `최고: 36° 최저:27°` 14 Medium `#919497`. 과거 날짜 페이지에서는 현재값 대신 그 날 마지막 관측값(라벨 동일 배치).
- **사육장 제어 기록** (bg `#FAFBFD`, 페이지 하단 전폭): 타이틀 `사육장 제어 기록` 18 Bold `#1E1E1E`, 로우 h40 간격 20 — 좌: 36×36 radius 18 아이콘 원(켜짐/작동=기기색, 꺼짐=`#A9B3BE`) + `냉각팬 꺼짐` 16 SemiBold `#3C3C3C` + 시각(`오후 12:59`) 14 Medium `#919497`. 우: `32℃ 52%` 16 SemiBold + 아래 델타(`-5℃ +2%`) 또는 `작동 시점 온습도` 14 Medium `#919497`.
  - **델타 규칙**: OFF 이벤트 로우에만 표기 — 같은 기기의 직전 ON 시점 온습도와의 차이(PRD §4.3.2). ON/분무 로우는 `작동 시점 온습도` 캡션.

### A.6 온습도 상세 — 주간 (668:1408)

- 주 페이저 `← 2026. 8. 24 - 8. 30 →`.
- 온도 섹션: 헤더 `🌡(원형 아이콘) 32.5°C`(주간 최고, 20~ SemiBold `#F85478`) + `21.2°C`(주간 최저, `#919497`). 차트 369×297: 요일(월~일)별 세로 min-max 라운드 바 + 바 위/아래 수치 라벨, 우측 Y축(예: 18°~30°, 2° 간격), 연한 그리드. 선택 요일 바만 컬러(`#F85478`), 나머지 `#3C3C3C`(데이터 有)/`#A9B3BE`(희박). 요일 탭 → 헤더 수치가 그 요일 최고/최저로 전환(재탭 해제 시 주간 전체).
- 습도 섹션: 동일 구조, 강조 `#00B2F3`, 축 42%~60% 3% 간격.
- 데이터: `telemetry_30m` 7일치의 일별 min/max (0값 센티넬 `v>0` 필터 필수).

---

## §B. 결정 사항 (기획 대화 2026-09-02 — PRD 개정 반영 완료)

1. 탭 = 홈/카메라/마이크레/커뮤니티. 통계 탭 폐지. `/stats` 라우트 제거, StatsScreen 코드는 **1단계에서 삭제하지 않고 라우트만 끊는다**(별도 정리 커밋).
2. 홈 단일 스크롤. 서브탭·타임라인·개체 프로필 분기 폐기.
3. 팬 3종: 환기팬(기존 `fan_*` 명령 배선)·냉각팬·히터팬(**API 없음 — UI만**, 탭 시 "준비 중" 안내). 기존 `heater_*` 명령 귀속은 미결 Q — 1단계에서는 히터팬 타일을 미배선으로 둔다(기존 히터 2단 확인 로직은 코드 보존).
4. 일간 차트 하루 = 자정~자정, 날짜 페이징. 홈 최고/최저 = 오늘(자정~).
5. 위키·검색: 진입점·라우트 제거만(코드 폴더 삭제는 후속 정리 커밋).
6. 계정 = 헤더 person(기존 프로필/설정 화면으로 연결). 알림·사육장 설정 진입은 계정 화면 안(기존 화면 재사용, 이번엔 연결만).
7. 마이크레·커뮤니티는 팔레트만 적용(GlassPalette 값 교체로 자동 반영).
8. 카메라 탭 = 기존 CrecamScreen을 브랜치로 이동(화면 재설계는 2단계).

## §C. 구현 순서 (task 그룹)

1. **T1 토큰 교체**: GlassPalette 라이트벌 값 교체 + 기기색 토큰 추가.
2. **T2 탭 재배열**: tab_branches/app_router — stats→camera, 위키·검색 라우트 제거, 탭바 Figma 스타일.
3. **T3 도메인**: EnvDay(자정 경계)·일간 시리즈·주간 min/max·제어기록(델타) 모델+provider (TDD).
4. **T4 홈 화면**: 단일 스크롤 재작성 (헤더/라이브/요약 카드/그리드 5타일/일정 설정).
5. **T5 온습도 상세**: 라우트 신설 + 일간(가로 스크롤 차트+마커+스크러버+제어기록) + 주간(범위 바).
6. **T6 마무리**: analyze/test/버전 bump, 대조표·CLAUDE.md 갱신.

> 상세 task는 §D. 코드 조사 결과(2026-09-02, Explore 에이전트)의 충돌 지점 20개를 반영했다.

---

## §D. Task 상세

공통 규칙:
- 각 task 완료 시 `flutter analyze` 에러 0 + 관련 테스트 통과 후 **즉시 커밋**(버전 bump: feat→minor, build+1) + push.
- 색은 반드시 `context.glass.*` 또는 `AppTheme.*` 토큰. 문자열은 `assets/l10n/ko.json` 키 추가 후 `.tr()`.
- 로딩은 shimmer 스켈레톤(CircularProgressIndicator 금지).
- 제어 명령은 반드시 `cage_control_actions.dart` 경유(히터 2단 확인·분무 5초 잠금이 거기 있다).

### Task 1: 팔레트 교체 (GlassPalette 라이트벌 + 기기색 토큰)

**Context:**
- Depends on: 없음
- Inputs: §A.1 팔레트 표. `lib/core/theme/glass_palette.dart`(462줄), `lib/core/theme/app_theme.dart`
- Outputs: 신규 필드 7개(`deviceFan`,`deviceCool`,`deviceLed`,`deviceHeat`,`deviceFanTintBg`···) + 라이트벌 값 교체. 다크벌은 **값 유지**(신규 필드만 다크 대응값 추가 — 채도 유지 명도 조정 or 동일값).
- Must know: GlassPalette 필드 추가 시 **생성자·`dark`·`light`·`copyWith`·`lerp` 5곳 동시 수정** — 하나라도 빠지면 조용히 잘못된 색. `AppTheme.glassX` 정적 색 부활 금지(CLAUDE.md). `variant_b_tokens.dart`는 design_lab 전용이라 **건드리지 않는다**.
- Acceptance: `flutter analyze` 0. `flutter test test/core/theme/` 통과(기대값 갱신 포함).

**Files:**
- Modify: `lib/core/theme/glass_palette.dart`
- Modify: `lib/core/theme/app_theme.dart` — `chartTemperature → 0xFFF85478`, `chartHumidity → 0xFF00B2F3`
- Test: `test/core/theme/app_theme_palette_test.dart` 기대값 갱신

**신규 필드와 라이트 값** (다크는 동일 hue 유지 판단):

```dart
// 기기 상태색 (Figma A.1)
final Color deviceFan;      // light: 0xFF00B591  액티브 아이콘/글리프
final Color deviceFanBg;    // light: 0xFFDCF5E9  액티브 타일 배경
final Color deviceCool;     // light: 0xFF6B7FFF
final Color deviceCoolBg;   // light: 0xFFE0E5FF
final Color deviceLed;      // light: 0xFFF5A800
final Color deviceLedBg;    // light: 0xFFFFF4D9
final Color deviceLedGauge; // light: 0xFFFFE2A3  LED 밝기 게이지
final Color deviceHeat;     // light: 0xFFFF6B57 (도출값)
final Color deviceHeatBg;   // light: 0xFFFFE9E4 (도출값)
final Color deviceMist;     // light: 0xFF00B2F3 (= 습도 액센트)
final Color deviceOff;      // light: 0xFFA9B3BE  꺼짐 아이콘 원
final Color tempAccent;     // light: 0xFFF85478
final Color humidAccent;    // light: 0xFF00B2F3
final Color surfaceTint;    // light: 0xFFF0F4F9  연회색 면(필·카드·꺼짐 타일)
final Color segmentTrack;   // light: 0xFFEFF2F5
final Color surfaceHeader;  // light: 0xFFFAFBFD
```

**라이트벌 기존 필드 값 교체**: `wallpaper→0xFFFFFFFF`, `overlay(카드)→0xFFFFFFFF`, `border→0xFFE1E3E4`, `textPrimary→0xFF1E1E1E`, `textSecondary→0xFF3C3C3C`, `textTertiary→0xFF919497`, `bodySecondary→0xFF626262`, `signalOk→0xFF00B591`, `signalWarn→0xFFF5A800`, `signalAlert→0xFFD61619`, `tabBar→0xFFFFFFFF`, `heaterTint/mistTint/ledTint/fanTint→기기색 Bg 값과 동기`. 나머지(차트·스켈레톤·날씨바)는 새 그레이스케일에 맞춰 근사 조정.

- [ ] Step 1: 필드 추가(생성자+선언) → dark/light/copyWith/lerp 5곳 반영
- [ ] Step 2: 라이트 값 교체 (§A.1 표)
- [ ] Step 3: `app_theme.dart` 차트색 2종 교체
- [ ] Step 4: `flutter test test/core/theme/` — 실패하는 기대값을 신 팔레트로 갱신
- [ ] Step 5: `flutter analyze` 0 확인 → 커밋 `feat(theme): Figma Asset 팔레트로 라이트벌 교체 + 기기 상태색 토큰`

### Task 2: 탭 재배열 + 위키·검색 진입점 제거 + 탭바 스타일

**Context:**
- Depends on: Task 1 (탭바 색 토큰)
- Inputs: `lib/core/router/{tab_branches,app_router}.dart`, `lib/shared/widgets/glass_dock.dart`, `assets/l10n/ko.json`
- Outputs: 4탭 = `/home`·`/crecam`·`/my-pets`·`/community`. `/stats`·`/wiki`·`/search` 라우트 제거. 신규 최상위 라우트 `/env-detail`(Task 5에서 화면 구현 — 여기서는 placeholder 등록하지 않고 **Task 5에서 등록**).
- Must know:
  - `tab_branches.dart`의 3중 테이블(kHomeTabPaths/kHomeTabLabelKeys/kHomeTabIcons)은 **인덱스 강결합** — 셋 동시 수정. `app_router.dart:400` for-루프가 이 테이블에서 독을 파생.
  - 탭 경로는 `/crecam` 재사용(딥링크 보존). **하위 라우트(`/crecam/cameras/...` 등)는 셸 밖 최상위로 유지** — 기존 최상위 `/crecam` GoRoute에서 루트 화면만 브랜치로 옮기고, 하위 GoRoute들은 최상위 `/crecam/cameras/pair`… 개별 경로로 남긴다(`/home/routines` 선례 패턴). 페어링·상세에 독이 뜨면 안 된다.
  - `kPublicPaths`: `/stats`·`/wiki`·`/search` 제거. `/crecam`은 **비공개**(추가하지 않음 — 카메라는 계정 종속).
  - 위키 제거 범위: 라우트 + 진입점 3곳 — `community_screen.dart:339–373` `_WikiShortcutCard` 통째 제거, `pet_detail_screen.dart:78` `context.go('/wiki')` 버튼 제거, `search_screen.dart`는 라우트만 제거(파일 삭제는 후속 정리 커밋). **`care_info_repository`·`wiki_providers`는 홈/사육장/마이펫 공용 인프라라 남긴다.**
  - stats: 라우트·브랜치에서만 제거. `lib/features/stats/` 파일은 남긴다. 단 **`stats/domain/daily_rollup.dart`를 `lib/shared/domain/daily_rollup.dart`로 이동**(홈이 import — `home_control_providers.dart:13` + 홈 테스트 3파일의 import 경로 수정, stats 쪽은 재-export 또는 import 경로 수정).
  - `weekly_env_rows_card.dart:154` `context.go('/stats')` → `context.push('/env-detail')`로 교체(Task 5 전까지 라우트 부재 — Task 4에서 홈에서 이 카드가 빠지므로 실경로 도달 없음, analyze도 통과).
  - GlassDock 스타일 교체: bg white(`glass.tabBar`), top stroke `glass.surfaceTint`, 블러/전광판 제거, 활성 `#192553`(primary)·비활성 `glass.textTertiary`, 라벨 12 Medium. `GlassDock.height` 56→64 검토(Figma 80은 safe area 포함) — 소비처 9곳이 `glassDockListPadding` 경유라 그 함수만 맞으면 됨.
- Acceptance: `flutter analyze` 0. `flutter test test/features/home/router_tabs_test.dart` 통과(기대값을 신 4탭으로 갱신). 앱 빌드 시 4탭 = Home/Camera/MyCre/Community.

**Files:**
- Modify: `lib/core/router/tab_branches.dart` — paths `['/home','/crecam','/my-pets','/community']`, labelKeys `['tab_home','tab_camera','tab_my_pets','tab_community']`, icons[1] `Icons.videocam_outlined/videocam`
- Modify: `lib/core/router/app_router.dart` — 브랜치2 StatsScreen→CrecamScreen, 기존 최상위 `/crecam` 루트 제거·하위만 개별 최상위로 재배치, `/wiki`·`/search` 블록 삭제
- Modify: `lib/shared/widgets/glass_dock.dart`
- Move: `lib/features/stats/domain/daily_rollup.dart` → `lib/shared/domain/daily_rollup.dart` (+ import 5곳)
- Modify: `lib/features/community/presentation/community_screen.dart`, `lib/features/my_pets/presentation/pet_detail_screen.dart`
- Modify: `assets/l10n/ko.json` — `tab_home:"Home"`, `tab_camera:"Camera"`, `tab_my_pets:"MyCre"`, `tab_community:"Community"` (Figma 영문 라벨 채택)
- Test: `test/features/home/router_tabs_test.dart` 갱신

- [ ] Step 1: daily_rollup 이동 + import 경로 수정 → analyze 0
- [ ] Step 2: tab_branches 3중 테이블 + ko.json
- [ ] Step 3: app_router 재배치 (stats 브랜치→crecam, wiki/search 삭제, crecam 하위 최상위화)
- [ ] Step 4: GlassDock 스타일 교체
- [ ] Step 5: community 위키 카드·pet_detail 위키 버튼 제거
- [ ] Step 6: router_tabs_test 갱신 → `flutter test test/features/home/router_tabs_test.dart` PASS
- [ ] Step 7: analyze 0 → 커밋 `feat(router): 4탭 재배열(카메라 승격·통계 폐지) + 위키·검색 진입점 제거`

### Task 3: 도메인 — 자정 하루 창·주간 범위·제어 기록 (TDD)

**Context:**
- Depends on: Task 2 (shared/domain/daily_rollup.dart 위치)
- Inputs: `lib/shared/domain/{env_chart_data,axis_bounds,actuator_marker,env_extremes,daily_rollup}.dart`, `supabase_module_control_repository.telemetryHistory(deviceId, from, {to})`, `fetchActuatorMarkers`(home_control_providers.dart:117 — commands 조회 `select id, action, status, issued_at`)
- Outputs: 신규 파일 3개 + provider 파일 1개(아래 시그니처). 기존 코드 수정 없음.
- Must know: `telemetry_30m` 0값=센서 오프라인 센티넬 → `EnvChartData.from`·`rollupByDay`가 이미 필터. 시각은 UTC로 오면 `.toLocal()`. 델타는 **같은 kind의 직전 ON↔OFF 짝**(PRD §4.3.2). commands `action` 문자열: `fan_on/fan_off/heater_on/heater_off/led_on/led_off/mist/relay_toggle/led_toggle/fan_toggle/heater_toggle`(과거 toggle 이력 존재 — `_kindByAction` 참조. toggle은 방향 미상 → 델타 없음, 표기는 "작동").
- Acceptance: `flutter test test/features/shared/env_day_test.dart test/features/shared/week_range_test.dart test/features/shared/control_log_test.dart` PASS. analyze 0.

**Files:**
- Create: `lib/shared/domain/env_day.dart`
- Create: `lib/shared/domain/week_range.dart`
- Create: `lib/shared/domain/control_log.dart`
- Create: `lib/features/home/presentation/env_detail_providers.dart`
- Test: `test/features/shared/env_day_test.dart`, `week_range_test.dart`, `control_log_test.dart`

**핵심 계약:**

```dart
// env_day.dart — 자정 경계 하루 창 (PRD §3.1 ③)
class EnvDay {
  final DateTime date; // 자정 정규화된 로컬 날짜
  const EnvDay(this.date);
  factory EnvDay.of(DateTime now) => EnvDay(DateTime(now.year, now.month, now.day));
  DateTime get start => date;
  DateTime get end => date.add(const Duration(days: 1));
  bool get isToday; // EnvDay.of(clock now)와 비교는 호출부에서 now 주입
  EnvDay get previous; EnvDay get next;
  bool containsNow(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

// week_range.dart — 월요일 시작 7일 창 + 요일별 min/max
class WeekRange {
  final DateTime monday; // 자정 정규화
  factory WeekRange.containing(DateTime day); // 그 날이 속한 주
  DateTime get start; DateTime get end; // [monday, monday+7d)
  WeekRange get previous; WeekRange get next;
}
class DayMinMax { final DateTime day; final double? min; final double? max; }
// rollupByDay(=shared) 산출 TelemetryBucket에서 온/습 각각 7요일 리스트로:
List<DayMinMax> weekTempRanges(List<TelemetryBucket> dailyBuckets, WeekRange week);
List<DayMinMax> weekHumidRanges(List<TelemetryBucket> dailyBuckets, WeekRange week);

// control_log.dart — 사육장 제어 기록 (PRD §4.3.2)
enum ControlLogState { on, off, ran } // ran = 분무·toggle(방향 미상)
class ControlLogEntry {
  final MarkerKind kind; final ControlLogState state; final DateTime at;
  final double? temperature; final double? humidity;   // 그 시점 온습도 (최근접 버킷)
  final double? deltaTemperature; final double? deltaHumidity; // off일 때만: 직전 on과의 차
}
List<ControlLogEntry> buildControlLog({
  required List<Map<String, dynamic>> commandRows, // fetchActuatorMarkers와 같은 rows(action, issued_at)
  required List<TelemetryBucket> buckets,          // 그 날 창의 30분 버킷
});
// 온습도 매칭: |bucket - at| 최소 버킷의 tAvg/hAvg (30분 초과 이격이면 null)
```

```dart
// env_detail_providers.dart
final envDetailDayProvider = StateProvider.autoDispose<EnvDay>((ref) => EnvDay.of(DateTime.now()));
final envDetailWeekProvider = StateProvider.autoDispose<WeekRange>((ref) => WeekRange.containing(DateTime.now()));
final envDayBucketsProvider  = FutureProvider.autoDispose<List<TelemetryBucket>>(...); // telemetryHistory(start, to: min(end, now))
final envDayChartDataProvider = FutureProvider.autoDispose<EnvChartData>(...);          // EnvChartData.from(buckets, from: day.start, to: day.end)
final envDayExtremesProvider  = FutureProvider.autoDispose<EnvExtremes>(...);           // EnvExtremes.from(buckets)
final envDayMarkersProvider   = FutureProvider.autoDispose<List<ActuatorMarker>>(...);  // fetchActuatorMarkers(from: start, to: end)
final envDayControlLogProvider = FutureProvider.autoDispose<List<ControlLogEntry>>(...); // 원시 command rows + buckets
final envWeekRowsProvider     = FutureProvider.autoDispose<({List<DayMinMax> temp, List<DayMinMax> humid})>(...);
final homeTodayExtremesProvider = FutureProvider.autoDispose<EnvExtremes>(...);         // 오늘(자정~) — 홈 요약 카드용
```
※ 전부 `currentDeviceIdProvider` watch. 원시 command rows가 필요하므로 `fetchActuatorMarkers`를 rows 반환 함수(`fetchCommandRows`)와 marker 변환으로 분리(기존 호출부 시그니처는 유지).

- [ ] Step 1: env_day_test 작성(경계·previous/next·containsNow) → FAIL 확인 → 구현 → PASS
- [ ] Step 2: week_range_test(월요일 시작·min/max 집계·빈 요일 null) → FAIL → 구현 → PASS
- [ ] Step 3: control_log_test(on/off 짝 델타·toggle=ran·버킷 매칭·30분 초과 null) → FAIL → 구현 → PASS
- [ ] Step 4: providers 작성 → analyze 0 → 커밋 `feat(env-detail): 자정 하루 창·주간 범위·제어 기록 도메인`

### Task 4: 홈 단일 스크롤 재작성

**Context:**
- Depends on: Task 1(토큰), Task 3(homeTodayExtremesProvider)
- Inputs: §A.4 실측. `home_screen.dart`(178), `home_header_bar.dart`, `top_fixed_area.dart`, `quick_control_grid.dart`, `cage_control_actions.dart` 공개 API
- Outputs: 단일 스크롤 홈. 신규 `EnvSummaryCard`(탭→`/env-detail`), `CageControlGrid`(5타일), 헤더 개편(+메뉴/person).
- Must know:
  - **TopFixedArea(WebRTC 라이브)는 dispose 금지 제약** — 단일 ListView 안에 넣으면 스크롤 아웃 시 dispose됨. 홈은 스크롤 화면이지만 라이브가 최상단이라 실사용 위험 낮음 → `ListView` 대신 `Column(헤더, Expanded(ListView))`가 아니라 **라이브 포함 전체를 `SingleChildScrollView`(또는 ListView) + `AutomaticKeepAliveClientMixin`/`KeepAlive`**로 유지. 최소침습: 기존 TopFixedArea를 재사용하되 개체 프로필 분기(`_SetPane`의 pet 카드)를 라이브 전용으로 단순화.
  - 제어 그리드: 환기팬 타일 = 기존 `handleFanTap`(fan_* 절대 명령), 분무 = `openMistSheet`/`mistOnce`(5초 잠금 유지), LED = `openLedSheet`(밝기 게이지 = telemetry.ledBrightness), **냉각팬·히터팬 = 미배선**(탭 시 SnackBar `준비 중인 기기예요` + ko.json 키 `home_device_not_ready`). 상태 표기: telemetry 기반(`TelemetryReading` — LED는 `led`/`ledBrightness`, unavailable=모름 규칙 유지).
  - 헤더: `[+]` → showMenu(기기 추가→`/smart-cage/devices/pair`, 개체 추가→`/my-pets/add`, 사육세트 추가→`/enclosure-settings`), `[person]` → `/profile`. 알림 진입은 `/profile` 화면 안(이번 task에서는 프로필 화면에 알림 메뉴 타일 1개 추가 — `/notifications` push).
  - 폐기(홈에서 참조 제거, 파일은 존치): HomeSubTabsBar, TonightCard, HourlyEnvStrip, WeeklyEnvRowsCard, LiveEnvCard, timeline_* 3종, pet_profile_card. `homeSubTabProvider`도 미사용화.
  - 깨지는 테스트 처리: `control_tab_golden_test`·`control_tab_layout_test`·`home_sub_tabs_test`·`top_fixed_area_test`(프로필 분기 기대)·`timeline_*` 3종 → **삭제**(재작성 대상은 신규 홈 레이아웃 테스트 1본 + 헤더 테스트 갱신). `test/features/home/failures/*.png` 4장 삭제. 골든 `preview/control_*.png` 삭제.
- Acceptance: analyze 0, `flutter test test/features/home/` PASS. 홈 = 헤더/라이브/요약 카드/그리드 5타일/일정 설정 단일 스크롤.

**Files:**
- Rewrite: `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/features/home/presentation/widgets/home_header_bar.dart`, `top_fixed_area.dart`
- Create: `lib/features/home/presentation/widgets/env_summary_card.dart`, `cage_control_grid.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart` — 알림 타일 추가
- Modify: `assets/l10n/ko.json` — `home_add_device`,`home_add_pet`,`home_add_set`,`home_device_not_ready`,`home_schedule_settings`,`device_cool_fan`,`device_heat_fan`,`device_vent_fan` 등
- Delete: 깨지는 테스트 7파일 + 골든/실패 png
- Create: `test/features/home/home_layout_test.dart` (단일 스크롤 구성·요약 카드 탭 라우팅·미배선 타일 SnackBar)

- [ ] Step 1: EnvSummaryCard + 테스트 (값·최고최저 표기, 탭→/env-detail push 스텁 라우터로 검증)
- [ ] Step 2: CageControlGrid + 테스트 (5타일 렌더·미배선 SnackBar·환기팬→handleFanTap 경유)
- [ ] Step 3: 헤더 개편 (+메뉴·person) + home_header_bar_test 갱신
- [ ] Step 4: home_screen 재작성 + top_fixed_area 단순화
- [ ] Step 5: 구 테스트/골든 삭제, home_layout_test 작성 → `flutter test test/features/home/` PASS
- [ ] Step 6: analyze 0 → 커밋 `feat(home): 단일 스크롤 홈 재작성 — Figma vivanaut Home`

### Task 5: 온습도 상세 화면 (일간·주간·제어 기록)

**Context:**
- Depends on: Task 3(도메인·프로바이더), Task 1(토큰)
- Inputs: §A.5·A.6 실측, `EnvChartData`·`AxisBounds`·`ActuatorMarker`, env_detail_providers
- Outputs: 라우트 `/env-detail`(셸 밖 최상위, 비공개), `EnvDetailScreen` + `EnvDayChart`(가로 스크롤 커스텀 페인트) + `WeekRangeChart`.
- Must know:
  - 일간 차트: 콘텐츠 폭 = 24h × (524/24)pt ≈ 524pt 고정, `SingleChildScrollView(horizontal)` + 좌우 12 마스크. Y축 라벨은 스크롤 밖 고정(좌 온도·우 습도) — Figma 구조(Hide 마스크 + 축 오버레이) 그대로. 축은 `AxisBounds.forValues`(6눈금 고정) 재사용.
  - 마커 행: 차트 상단 h28 별도 밴드. 같은 시각대 겹침은 x순 정렬 후 최소 22pt 간격 보정.
  - 스크러버: `GestureDetector` onLongPress/onHorizontalDrag → 위치 스냅(버킷) → 툴팁 칩(시각 + 온습도). 손 떼도 유지, 재탭/✕로 해제(통계 탭 관례 계승).
  - 날짜 페이저: `envDetailDayProvider` state 교체. 오늘이면 `→` 비활성. 초기 스크롤 오프셋 = 오늘이면 현재 시각 위치가 우측에 오도록, 과거일은 0.
  - 주간: 요일 바 = min/max 라운드 바 + 상하 수치 라벨(12), 우측 Y축, 요일 탭 → 해당 요일 강조(헤더 수치 전환). 데이터 없는 요일은 표시 생략(라벨만).
  - 제어 기록: `ControlLogEntry` 리스트 렌더. state별 아이콘 원 색(§A.5), off 로우만 델타, 없으면 `작동 시점 온습도` 캡션. 빈 날은 빈 상태 문구.
  - ko.json: `env_detail_title`,`env_detail_daily`,`env_detail_weekly`,`env_detail_control_log`,`env_detail_at_operation`,`env_detail_empty_log`,`env_detail_no_data` 등.
- Acceptance: analyze 0. `flutter test test/features/home/env_detail_*` PASS. 홈 요약 카드 탭→상세 진입, 일간/주간 전환·페이징 동작.

**Files:**
- Create: `lib/features/home/presentation/env_detail_screen.dart`
- Create: `lib/features/home/presentation/widgets/env_day_chart.dart`, `week_range_chart.dart`, `control_log_list.dart`
- Modify: `lib/core/router/app_router.dart` — `/env-detail` 등록 (fullscreenDialog)
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/env_detail_screen_test.dart`(세그먼트 전환·페이저·빈 상태), `test/features/shared/env_day_chart_test.dart`(레이아웃 스모크)

- [ ] Step 1: EnvDayChart 페인터 + 스모크 테스트
- [ ] Step 2: WeekRangeChart + 스모크
- [ ] Step 3: ControlLogList
- [ ] Step 4: EnvDetailScreen 조립 + 라우트 + 화면 테스트
- [ ] Step 5: analyze 0 + 전체 `flutter test` → 커밋 `feat(env-detail): 온습도 상세 화면 — 일간·주간·제어 기록`

### Task 6: 마무리 — 전체 검증·문서

**Context:**
- Depends on: Task 1~5
- Acceptance: `flutter analyze` 0 · `flutter test` 전체 PASS · `flutter build apk --debug` 성공.

- [ ] Step 1: 전체 analyze/test/build
- [ ] Step 2: `docs/prd-implementation-gap.md` 갱신(4탭·홈·온습도 상세 반영), CLAUDE.md 핵심 feature 표 갱신
- [ ] Step 3: 커밋 `docs: PRD 재설계 1단계 반영 — 대조표·CLAUDE.md`
- [ ] (후속 정리 커밋 — 1단계 범위 밖) stats/wiki/search/design_lab·타임라인 위젯 파일 삭제, ko.json 고아 키 정리

## Self-Review 결과

- Spec coverage: PRD §2.1(T2)·§4.1(T4)·§4.3(T3+T5)·팔레트(T1)·위키 폐기(T2)·마이크레/커뮤니티 팔레트만(T1로 자동) — 커버. §4.4 카메라 화면 재설계는 **2단계 범위**(이 계획은 탭 승격까지만) — PRD §7 순서와 일치.
- 타입 일치: `EnvDay`/`WeekRange`/`ControlLogEntry` 시그니처를 T3·T5가 공유 — 일치 확인.
- 함정 반영: rollupByDay 이동(충돌 1), go('/stats') (충돌 2), 3중 테이블(충돌 4), kPublicPaths(충돌 5), 테스트 하드코딩(충돌 6), care_info 공용(충돌 8), WebRTC dispose(충돌 13), GlassPalette 5곳 동기(충돌 15), 골든 실패 산출물(충돌 18).
