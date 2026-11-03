# 영상 배속 4단계(1x~4x)·조작줄 재디자인 Implementation Plan

> **구현 방식 (CAOF):** 이 계획을 task 단위로 구현한다. Standard 트랙 — 메인이 직접 구현. Steps use checkbox (`- [ ]`) syntax for tracking.

- 트랙: **Standard** (영상 플레이어 한 화면의 조작줄 + 배속 도메인·저장소, 3~4 파일. 되돌리기 1시간 안)
- 원본: Figma Camera 섹션 안 **"배속 버튼 수정 261103" `1689:5771`** (talk-to-figma 채널 `twt84ya0`, 2026-11-03 확인)
- 에셋: 디자이너 전달 `~/Downloads/speed-buttons/` — `speed_4.svg`(28 속도계), `1x.svg`·`2x.svg`·`3x.svg`·`4x.svg`(글자 윤곽)
- Figma 캡처: `docs/design-audits/2026-11-03-player-speed-4x/`(섹션 전체·새 버튼 4배·기존 조작줄 3배)
- 직전 작업: 0.159.0 배속 기억(`PlayerSpeedStore`, Hive `app_settings/player_speed`) — 이 계획이 단계·기본값·버튼을 바꾼다

**Goal:** 영상 플레이어 배속을 1x/2x/3x/4x(기본 2x)로 바꾸고, Figma대로 배속 버튼(속도계+글자 알약)과 조작줄(둥근 바탕 버튼·시간 알약)을 다시 그린다.

**Architecture:** 단계·기본값은 `domain/player_speed.dart` 한 곳에서 정하고 저장소·버튼이 그것만 본다. 아이콘은 디자이너 SVG를 `FigmaIcons`에 등록하고, 조작줄은 `ClipPlaylistPlayerScreen._controlRow` 안에서만 바꾼다(다른 화면의 같은 아이콘은 그대로).

**Tech Stack:** Flutter, Riverpod(StateNotifier), Hive, flutter_svg(`FigmaIcon`), video_player

**Spec:** Figma `1689:5771` (아래 §1 측정표가 이 계획의 원본 수치). 별도 기획서 없음.

## 1. Figma 확인 결과 (2026-11-03)

### 1-1. 동작 (Figma 메모 원문)
- "디폴트 값: 2x" / "배속 방법은 기존과 동일하게 2x → 3x → 4x → 다시 1x → 2x"
- 단계: **1x · 2x · 3x · 4x** (기존 1X·1.2X·1.5X·2X 대체)
- 메모 "← 새로생긴 아이콘"=속도계(`speed_4`), "← 수정된 아이콘"=play_arrow·zoom_in_map·zoom_out_map, "아이콘 크기랑 위치가 약간 바뀌었습니다"
- 빨간 메모 "12 → 16 으로 수정" = 세로 조작줄 좌우 여백

### 1-2. 수치 (세로 프레임 `1689:5305`/`1689:5774` 393×852, 가로 `1689:5647` 852×393 기준)

| 요소 | 기존(941:1834 / 1238:12858) | 새 디자인 |
|---|---|---|
| 조작줄 좌우 여백(세로) | 12 | **16** |
| 조작줄 좌우(가로) | 48 / 804 | 48 / 804 (그대로) |
| 조작줄 y·높이 | 430 · 36 | 430 · 36 (그대로) |
| 재생/일시정지 | 36 아이콘, 바탕 없음 | **36 원, 바탕 #F4F4F4 (r18)** |
| 재생 시간 | 글자만 x56, 14/**500** #3C3C3C | **알약** x60, 높이 36 r16 #F4F4F4, 좌우 안쪽 12, 글자 14/**600** 줄높이 16.707 자간 −0.28 #3C3C3C (원본 폭 89 = 12+65+12) |
| 재생↔시간 간격 | 8 | 8 |
| 배속 | 36 글리프 아이콘(1X·1.2X·1.5X·2X) | **알약 81×36 r16 #F4F4F4** — 속도계 28 @(12,4), 글자 SVG 왼쪽 45·세로 가운데(잉크 y 11.5~24.5) |
| 배속↔확대 간격 | 12 | **8** (세로 252+81+8=341, 가로 679+81+8=768) |
| 확대(세로 zoom_out_map)/축소(가로 zoom_in_map) | 36, 그림 20×20 @8 | **36 원 #F4F4F4**, 그림 **18×18 @9** (0.9배) |
| play 그림 | 잉크 x 11.33~24.67 | 잉크 x **13.00~26.25** (같은 모양, 오른쪽 +1.67) |
| pause 그림(가로 원본) | — | 잉크 x 10.00~25.50 y 9~27 (수정 표시 없음 — 현행 유지, 픽셀 대조만) |
| 버튼 글자·아이콘 색 | 세로 #1E1E1E / 가로 밝은 색(0.158.7) | 세로·가로 모두 **알약 위 #1E1E1E**(글자 #3C3C3C) |
| 가로 아래 흐림 | 흰 그라데이션 | 흰 그라데이션 **변경 없음** — 앱은 0.158.7 사용자 결정대로 회색 유지 |

배속 버튼 픽셀 측정(4배 export, 바탕 합성): 속도계 잉크 x 14.75~37.25 y 9.5~26.5(= 28 프레임 @12,4 의 2.8~25.2). 글자 잉크 x 44.75~45.0 시작, 끝 63.75~64.5.
**1x 상태만 원본에서 내용이 +1.5pt 오른쪽**(`1689:5530` 속도계 x13.5, `1689:5802` x13) — §3 결정 1.

### 1-3. 에셋
| 파일 | 크기 | 비고 |
|---|---|---|
| `speed_4.svg` | 28×28 | alpha mask 사각형이 `#D9D9D9` → 런타임 규칙대로 `#FFFFFF`로 정규화(CLAUDE.md Final Design 규칙, 기존 `redesign_v2/*.svg`와 같음). 칠 `#1C1B1F`는 tint로 덮인다 |
| `1x/2x/3x/4x.svg` | 17×13 / 19×13 / 20×14 / 20×13 | Pretendard SemiBold 18 윤곽, 칠 `#1E1E1E`. 글리프가 viewBox 왼쪽 0에서 시작 |

play·zoom 아이콘의 새 SVG는 전달되지 않았다 — 기존 SVG의 배치로 맞춘다(§3 결정 2).

## 2. 사용자 체험 흐름

1. 처음 쓰는 사용자(저장값 없음)가 영상을 열면 배속 알약이 **[속도계 2x]**이고 영상이 **2배**로 재생된다.
2. 알약을 누를 때마다 2x → 3x → 4x → 1x → 2x … 로 바뀌고 영상 속도가 바로 바뀐다. 바꾼 값은 기억된다(0.159.0 동작 유지 — 다른 영상·앱 재시작에도 유지).
3. 예전에 1.2X·1.5X를 골라 둔 사용자는 업데이트 후 **2x**로 시작한다. 1X를 골라 둔 사용자는 1x, 2X는 2x 그대로.
4. 세로 조작줄: 왼쪽에 둥근 회색 [▶] + 회색 알약 [0:12 / 1:00], 오른쪽에 [속도계 2x] 알약 + 둥근 회색 [확대]. 좌우 끝이 화면 가장자리에서 16 안쪽.
5. 가로(확대 버튼): 같은 알약·둥근 버튼이 회색 화면 위에 그대로 있고 글자·아이콘은 진한 색. 위치는 기존 가로 좌표(왼쪽 48, 오른쪽 804).
6. 휴대폰 글자를 키우면 시간 알약만 글자에 맞춰 넓어지고, 배속 알약(그림 글자)은 81 그대로다. 줄이 넘치지 않는다.

## Global Constraints
- 배속 단계 `[1.0, 2.0, 3.0, 4.0]`, 기본 `2.0`, 순환 `1→2→3→4→1`.
- 저장 키는 그대로 Hive `app_settings` / `player_speed`(0.159.0). 목록 밖 값·없음 → `2.0`.
- 색은 `context.glass`/`VivaColors` 역할색만(하드코딩 금지). #F4F4F4=`glass.surfaceTint`(라이트 = `VivaColors.fillButton`, 기존 `_datePill`과 같은 면), #1E1E1E=`glass.textPrimary`(`labelPrimary`), #3C3C3C=`glass.textSecondary`(`labelSecondary`) — 2026-11-03 `glass_palette.dart` 확인.
- 글자 크기는 Figma 그대로(14/600). `TextScaler.linear`로 덮지 않는다(AppTextScaler 규칙).
- 문자열은 `assets/l10n/ko.json` 키로.
- 로딩 표시에 CircularProgressIndicator 금지(이 작업엔 로딩 없음).
- 건드리지 않는 것: 커뮤니티 플레이어(Final Design 결정으로 범위 밖), 카메라 라이브 확대 화면의 `FigmaIcons.zoomInMap`(`camera_live_fullscreen_screen.dart:390`), 가로 아래 회색 흐림·썸네일 줄·상단 바·이전/다음·액션 알약, 하이라이트 읽음 판정(`HighlightPlaybackTracker` — 위치 증가만 보므로 배속 무관, 확인함).

## Review Focus
1. **iOS에서 3x·4x가 실제로 2배로 깎이는 경우** — `video_player_avfoundation 2.9.4` `FVPVideoPlayer.m:350`은 `canPlayFastForward`가 false면 오류 없이 2.0으로 재생한다. 아이콘은 4x인데 2배로 보이는 상태. → Task 4 실기기 Acceptance.
2. **옛 저장값(1.2·1.5) 사용자** — 업데이트 후 2x로 시작해야 한다(오류·1x 아님). → Task 1 테스트.
3. **휴대폰 글자 2.0배** — 시간 알약이 넓어져도 세로 393폭에서 넘치지 않아야 한다("처음부터" 버튼이 같이 뜰 때 포함). → Task 3 테스트.
4. **가로 화면 대비** — 알약 위 글자가 0.158.7의 밝은 색으로 남으면 #F4F4F4 위에서 안 보인다. → Task 3 테스트(가로 색 assertion 교체).
5. **안드로이드 4배 재생 시 버퍼링** — 원격 mp4를 4배로 받으면 끊길 수 있다(앱이 막을 일은 아님). → Task 4 실기기에서 관찰만, 결과 기록.

---

### Task 1: 배속 단계·기본값·저장값 해석

**Files:**
- Modify: `lib/features/my_cage/domain/player_speed.dart`
- Modify: `lib/features/my_cage/data/player_speed_store.dart` (`load()`)
- Test: `test/features/my_cage/player_speed_test.dart`, `test/features/my_cage/player_speed_store_test.dart`

**Context:**
- Depends on: 없음
- Produces: `const List<double> kPlayerSpeeds = [1.0, 2.0, 3.0, 4.0]`, `const double kDefaultPlayerSpeed = 2.0`, `double nextPlayerSpeed(double current)` (목록 밖이면 `kDefaultPlayerSpeed`), `double normalizePlayerSpeed(Object? raw)` (num이고 목록에 있으면 그 값, 아니면 `kDefaultPlayerSpeed`)
- Must know: `HivePlayerSpeedStore.load()`는 `normalizePlayerSpeed(_box?.get(key))`만 돌려준다. 박스가 닫혀 있으면 2.0. 주석의 "1배" 문구도 2배로.
- Acceptance: 아래 테스트 통과.

- [ ] **Step 1: 실패 테스트**

```dart
test('네 단계를 2→3→4→1→2로 돈다', () {
  expect(kPlayerSpeeds, [1.0, 2.0, 3.0, 4.0]);
  expect(kDefaultPlayerSpeed, 2.0);
  expect(nextPlayerSpeed(2.0), 3.0);
  expect(nextPlayerSpeed(3.0), 4.0);
  expect(nextPlayerSpeed(4.0), 1.0);
  expect(nextPlayerSpeed(1.0), 2.0);
});
test('목록 밖 옛 값은 기본 2배로', () {
  expect(nextPlayerSpeed(1.5), 2.0);
  expect(normalizePlayerSpeed(1.2), 2.0);
  expect(normalizePlayerSpeed(1.5), 2.0);
  expect(normalizePlayerSpeed('x'), 2.0);
  expect(normalizePlayerSpeed(null), 2.0);
  expect(normalizePlayerSpeed(1), 1.0);
  expect(normalizePlayerSpeed(4), 4.0);
});
```
`player_speed_store_test.dart`: '미저장 기본은 2배'(`load()==2.0`), '저장 → 그대로 재현'(3.0), '손상·옛 값(1.2·1.5·garbage)은 2배, 1.0은 1배', '박스 닫힘이면 2배', 재시작 유지 테스트는 `set(4.0)` → 새 컨테이너 4.0.

- [ ] **Step 2: 실패 확인** — `flutter test test/features/my_cage/player_speed_test.dart test/features/my_cage/player_speed_store_test.dart` → FAIL
- [ ] **Step 3: 구현** — 위 Produces 시그니처대로.
- [ ] **Step 4: 통과 확인** — 같은 명령 → PASS
- [ ] **Step 5: 커밋** (Task 3과 합쳐 한 버전으로 올려도 된다 — 버전·CHANGELOG는 Task 4)

### Task 2: 배속 아이콘 에셋 등록·옛 배속 에셋 정리

**Files:**
- Create: `assets/icons/redesign_v2/2828/speed_4.svg` (마스크 `#D9D9D9`→`#FFFFFF`만 바꿔 복사)
- Create: `assets/icons/redesign_v2/speed_label_1x.svg` · `_2x` · `_3x` · `_4x` (전달 파일 그대로 복사)
- Delete: `assets/icons/redesign_v2/speed_1_2x.svg`, `speed_1_2x-1.svg`, `speed_1_5x.svg`, `assets/icons/speed_2x.svg`, `assets/icons/redesign_v2/speed_2x.svg` — **삭제 전** `grep -rn "speed_1_\|speed_2x" lib test` 결과가 `figma_icon.dart`·`player_speed_test.dart`뿐인지 확인
- Modify: `lib/shared/widgets/figma_icon.dart` (`speed2x`·`speed()` 대체)
- Test: `test/features/my_cage/player_speed_test.dart` (아이콘 테스트 교체)

**Context:**
- Depends on: Task 1 (`kPlayerSpeeds`)
- Produces: `FigmaIcons.speedGauge` = `'redesign_v2/2828/speed_4'`, `static String speedLabel(double value)` → `'redesign_v2/speed_label_${n}x'`(n=1~4, 목록 밖이면 2)
- Must know: `pubspec.yaml`에 `assets/icons/redesign_v2/`·`2828/`이 이미 등록돼 있어 pubspec 수정 없음. 글자 SVG는 크기가 제각각이라 고유 크기(viewBox 폭·높이)로 그린다 — 늘리지 않는다.
- Acceptance: 아래 테스트 통과.

- [ ] **Step 1: 실패 테스트** — 기존 '단계마다 아이콘…'·'아이콘 파일명이 아니라 글리프…'·'36 프레임 export' 3개를 지우고:

```dart
test('단계마다 글자 SVG가 있고 서로 다르다', () {
  final names = [for (final s in kPlayerSpeeds) FigmaIcons.speedLabel(s)];
  expect(names.toSet().length, 4);
  for (final n in names) {
    expect(File('assets/icons/$n.svg').existsSync(), isTrue, reason: n);
  }
});
test('글자 SVG는 Figma 윤곽 크기 그대로', () {
  // 1x 17×13, 2x 19×13, 3x 20×14, 4x 20×13 (디자이너 전달 2026-11-03)
  const sizes = {1.0: '0 0 17 13', 2.0: '0 0 19 13', 3.0: '0 0 20 14', 4.0: '0 0 20 13'};
  sizes.forEach((s, vb) => expect(
      File('assets/icons/${FigmaIcons.speedLabel(s)}.svg').readAsStringSync(),
      contains('viewBox="$vb"')));
});
test('속도계는 28 프레임, 흰 마스크', () {
  final svg = File('assets/icons/${FigmaIcons.speedGauge}.svg').readAsStringSync();
  expect(svg, contains('viewBox="0 0 28 28"'));
  expect(svg, isNot(contains('#D9D9D9')));
});
```
- [ ] **Step 2: 실패 확인** — `flutter test test/features/my_cage/player_speed_test.dart` → FAIL
- [ ] **Step 3: 에셋 복사·`FigmaIcons` 수정·옛 에셋 삭제**
- [ ] **Step 4: 통과 확인** — 같은 명령 → PASS

### Task 3: 조작줄 재디자인 (`_controlRow`)

**Files:**
- Modify: `lib/features/my_cage/presentation/clip_playlist_player_screen.dart` (`_controlRow` 1164~1233, `_iconButton36` 1235~1248)
- Modify: `assets/l10n/ko.json` — `"player_speed_label": "{}배속"`
- Test: `test/features/my_cage/player_layout_test.dart`, `test/features/my_cage/live_recording_player_test.dart`

**Context:**
- Depends on: Task 1, Task 2
- Consumes: `playerSpeedProvider`(0.159.0, `set(double)`), `nextPlayerSpeed`, `FigmaIcons.speedGauge`, `FigmaIcons.speedLabel`
- Produces: 키 유지 — `player_play_pause`(36×36 원), `player_speed`(81×36 알약), `player_orientation`(36×36 원). 새 키 `player_time_pill`(시간 알약).
- Must know:
  - 세로 `padded: true`면 좌우 **16**, 가로 `padded: false`(SafeArea 여백) 그대로.
  - `_iconButton36`에 바탕 `glass.surfaceTint` 원(r18)을 넣는다. 잉크 반응은 `customBorder: CircleBorder()` 유지.
  - 재생 아이콘: 기존 `FigmaIcons.play`를 36 크기로 그리되 **x +1.67 이동**(`Transform.translate(offset: Offset(1.67, 0))`) — Figma 잉크 13.00~26.25. 일시정지는 이동 없음.
  - 확대·축소 아이콘: 기존 SVG를 **32.4**로 그려 가운데 정렬(그림 20→18, 잉크 9~27). `camera_live_fullscreen_screen.dart`의 zoomInMap은 건드리지 않는다.
  - 시간 알약: `Container(height: 36, padding: EdgeInsets.symmetric(horizontal: 12), decoration: r16 surfaceTint)`, 폭은 글자에 맞춘다(고정 89 금지 — 59:59 / 긴 영상, 글자 배율). 글자 14 / w600 / 줄높이 16.70703125/14 / 자간 −0.28 / `glass.textSecondary`.
  - 배속 알약: `SizedBox(81×36)` + `Stack` — 속도계 `FigmaIcon.tinted(speedGauge, size: 28)` @(12,4), 글자 `FigmaIcon.tinted(speedLabel(speed))` 고유 크기, left 45, 세로 가운데. 색 `glass.textPrimary`. 둥근 모서리 16 잉크. `Semantics(label: 'player_speed_label'.tr(args: [n]))`(n = "1"~"4").
  - 간격: 재생↔시간 8, 배속↔확대 **8**.
  - **가로에서도 알약 위 글자·아이콘은 `glass.textPrimary`/`textSecondary`** — `AppTheme.landscapeForeground*`를 이 줄에서 쓰지 않는다(시크바 등 다른 곳은 그대로).
  - 탭 동작은 0.159.0과 같다: `set(next)` + `_controller?.setPlaybackSpeed(next)`.
- Acceptance: 아래 테스트 + Task 4 캡처 대조.

- [ ] **Step 1: 실패 테스트** — `player_layout_test.dart` 'portrait' 기대값 교체:

```dart
expect(play.left, 16);
expect(play.size, const Size(36, 36));
final timePill = tester.getRect(find.byKey(const Key('player_time_pill')));
expect(timePill.left, 60);
expect(timePill.height, 36);
final speed = tester.getRect(find.byKey(const Key('player_speed')));
expect(speed, Rect.fromLTWH(252, play.top, 81, 36));
final expand = tester.getRect(find.byKey(const Key('player_orientation')));
expect(expand.left, 341);
expect(expand.right, 377); // 393 - 16
expect(tester.widget<Text>(find.textContaining(' / ')).style!.fontWeight, FontWeight.w600);
```
'landscape' 테스트: 배속 알약 `left == 679`, 확대 `left == 768`(SafeArea 0 기준), 재생 아이콘 색 `AppTheme.landscapeForeground` assertion을 `glass.textPrimary`(라이트 #1E1E1E)로 교체.
새 테스트 '글자 2배에서도 조작줄이 넘치지 않는다': `MediaQuery(textScaler: TextScaler.linear(2.0))`로 세로 393×852 + 중간 시작(`playFromSec`로 "처음부터" 노출) → `tester.takeException()`이 null, `player_speed`·`player_orientation` 오른쪽 끝 ≤ 377.
`live_recording_player_test.dart`: '2X는 배속을 순환…' → 기본 저장소 `_MemSpeedStore(2.0)`, 탭 후 `video.speeds.last == 3.0`. '저장된 배속으로…' → 저장 3.0에서 시작, 탭 → 4.0 저장.
- [ ] **Step 2: 실패 확인** — `flutter test test/features/my_cage/player_layout_test.dart test/features/my_cage/live_recording_player_test.dart` → FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — 같은 명령 → PASS

### Task 4: 마무리·대조·실기기

**Files:**
- Modify: `pubspec.yaml`(minor +1 — 착수 시 main 버전 확인, 2026-11-03 기준 0.169.2+466 → 0.170.0+467), `CHANGELOG.md`
- 대조 결과: `docs/design-audits/2026-11-03-player-speed-4x/RESULTS.md` + 앱 캡처·Figma PNG

**Context:**
- Depends on: Task 1~3
- Must know: 수치 검수 규칙(CLAUDE.md "페이지별 필수 수치 검수") — Figma와 같은 393×852에서 캡처해 §1-2 표 항목별 원본·앱 값을 기록. 차이가 남으면 보고 후 확정.
- Acceptance:
  1. `flutter analyze` 에러 0, `flutter test` 전체 통과.
  2. 393×852 캡처(기존 `test/design/final_design_capture_test.dart` 플레이어 캡처 재사용)와 Figma `1689:5774`(1x)·`1689:5305`(2x)·`1689:5647`(가로 4x) 2배 PNG를 겹쳐, 조작줄 요소 위치 차이 ≤ 1pt.
  3. **iOS 실기기**: 원격 클립을 열고 4x로 바꾼 뒤 5초 동안 재생 시간이 약 20초 진행 → 통과. 약 10초만 진행하면 2배로 깎인 것 → 구현 중단·사용자 보고(§3 결정 4).
  4. **안드로이드 실기기**: 같은 확인 + 4x에서 끊김(버퍼링 표시) 유무를 RESULTS에 기록.
  5. 앱을 종료했다 다시 열어 마지막 배속이 유지되는지(0.159.0 회귀).

- [ ] **Step 1: 전체 analyze·test**
- [ ] **Step 2: 캡처·Figma 대조, RESULTS 작성**
- [ ] **Step 3: 버전·CHANGELOG** — "변경: 영상 재생 속도가 1x·2x·3x·4x 네 단계로 바뀌고 처음 기본값은 2x입니다. 예전에 1.2X·1.5X를 골라 둔 경우 2x로 시작합니다. 재생·시간·배속·확대 버튼이 Figma처럼 회색 바탕 위에 놓입니다."
- [ ] **Step 4: 커밋 → `tools/worktree.sh finish`로 main 병합·push**
- [ ] **Step 5: 실기기 확인(iOS·안드로이드) 결과를 RESULTS에 추가** — 사용자만 할 수 있으면 요청

## 3. 사용자가 정할 것

| # | 항목 | 추천 | 다른 선택 |
|---|---|---|---|
| 1 | 1x 상태에서 원본 내용이 1.5pt 오른쪽 | **모든 단계 같은 자리(속도계 12, 글자 45)** — 누를 때 아이콘이 흔들리지 않는다 | 원본대로 1x만 +1.5 |
| 2 | 수정된 아이콘(play·zoom) 새 SVG 미전달 | **기존 SVG 배치로 맞춤**(play +1.67 이동, zoom 0.9배) — 측정상 모양은 같고 크기·위치만 달라짐 | 디자이너에게 SVG 요청 후 교체 |
| 3 | 옛 저장값 1.2X·1.5X | **2x로 시작**(새 기본값) | 가까운 값(1.2→1x, 1.5→2x) |
| 4 | iOS가 3x·4x를 2배로 깎는 경우 | 실기기 확인 후 결정 — 깎이면 ① iOS만 3x·4x를 건너뛰기 ② 그대로 두고 안내 중 택1 | — |

## 4. 가정

| 가정 | 상태 |
|---|---|
| 배속 버튼은 영상 플레이어(`ClipPlaylistPlayerScreen`) 한 곳뿐 — 하이라이트·전체·북마크·직접 녹화가 같은 화면 | 확인(grep `player_speed`) |
| 가로 조작줄 좌표는 바뀌지 않음(48/804, y285) | 확인(1238:12858 ↔ 1689:5647) |
| 가로 아래 흐림은 원본에서 바뀌지 않음 → 앱 회색 유지 | 확인(두 프레임 같은 그라데이션) |
| 안드로이드 ExoPlayer는 4배를 그대로 적용 | 확인(`video_player_android 2.9.5` `setPlaybackParameters`) |
| iOS는 `canPlayFastForward`에 따라 2배로 제한될 수 있음 | 확인(소스) / 우리 클립의 실제 값은 **미확인** |
| 원격 mp4 4배 재생 시 끊김 없음 | 미확인 — Task 4 |

## 5. 실패 시나리오

- 글자 SVG를 `FigmaIcon.tinted(size: 36)`처럼 정사각으로 그리면 글자가 늘어나거나 작아진다 → 고유 크기로 그린다(Task 2 Must know).
- 가로에서 밝은 글자색이 남으면 회색 알약 위에서 안 보인다 → Task 3 가로 색 테스트.
- 시간 알약을 89로 고정하면 10분 넘는 영상·큰 글자에서 잘린다 → 폭은 글자에 맞춘다.
- 옛 에셋을 지우고 다른 곳에서 쓰고 있었다면 런타임에 빈 아이콘 → 삭제 전 grep(Task 2).
