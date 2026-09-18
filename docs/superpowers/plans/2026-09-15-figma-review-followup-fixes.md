# Figma 후속 차이 9항목 수정 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 현재 요청은 계획 작성이며 이 문서 자체는 구현 완료·추가 변경 승인 기록이 아니다.

**Goal:** 스크린샷 대조에서 확인한 추가 차이 9항목을 Figma 규격에 맞추고 같은 가상 데이터로 다시 검수한다.

**Architecture:** 기존 화면·Provider·Repository·내비게이션 동작을 유지하고 표현 계층만 수정한다. 그룹 설정은 기존 private 화면에 반영하고, 헤더 수정은 공통 위젯 한 곳으로 전파한다. 기존 SVG 글리프와 GlassPalette 역할색을 사용한다.

**Tech Stack:** Flutter, Riverpod, GoRouter, flutter_svg, EasyLocalization. 새 패키지 없음.

**Spec:** [추가 차이 9항목과 원인](../../design-audits/2026-09-15-post-review16-figma-comparison.md), [이전 16항목 승인 기록](../../design-audits/2026-09-15-simulator-review-decisions.md).

## 전제와 범위

- CAOF Standard: 메인이 분석·계획·직접 구현을 담당한다. 서브에이전트를 쓰게 되면 프로젝트 규칙에 따라 `gpt-5.6-terra` / `medium`을 명시한다.
- 작업 위치: `/Users/baek/myProjects/tera-ai-flutter/.worktrees/redesign-20260915`, 브랜치 `codex/figma-redesign-20260915`. 시작 시 HEAD와 사용자 변경을 확인한다. 기준 구현 커밋 `e3471c6`, 비교 문서 커밋 `925a1bb`.
- 스크린샷 번호는 `docs/design-audits/2026-09-15-review16-captures/`의 01~08을 가리킨다.
- 이번 변경은 아래 9항목에 한정한다. 추가로 발견한 페이지 차이는 별도 기록하며 함께 끼워 넣지 않는다.
- 데이터/API/RPC/Hive/운영 서버·BLE 변경 없음. 이름 중복·글자 수·기본 이름·그룹 인원 정책도 그대로 유지한다.
- 그룹명 우선 표시, 전원 항상 ON, 그룹 제외 확인/취소, 개체 편집 저장 방식 유지.
- MyCre 평균 `--`와 관측 미확인 설명은 유지. 주간 영역 위치를 맞추려고 설명을 지우거나 평균을 만들어 넣지 않는다.
- 카메라 `업데이트 오늘/어제/N일 전`, 하이라이트 `업데이트 없음` 유지.
- 기존 SVG 원본(`assets/figma/2026-09-15/`)은 보존. 원형 배경과 흰 글리프가 있는 다색 SVG 전체에 단색 tint를 적용하지 않는다.
- Talk to Figma MCP만 접근한다. 현재 보관된 PNG·노드 값이 비교 기준이며 실시간 변경 여부는 미확인이다. 다른 Figma MCP로 임의 대체하지 않는다.
- Figma 393pt와 Simulator 402pt는 같은 논리 픽셀 기준으로 비교한다. safe area와 가상 데이터 표시를 제외한 콘텐츠 좌표를 대조한다.
- 단순 색·여백 수정마다 구현을 복사한 테스트를 추가하지 않는다. 기존 기능 회귀 테스트와 원본 대비 화면 검증을 사용한다.

## 사용자 체험 흐름

1. **그룹 설정:** [화면] 기기 정보와 그룹별 사육장/카메라/개체 아이콘, 선택 체크, 회색 `+ 그룹 추가` 카드 → [조작] 그룹 선택 또는 추가 → [반응] 기존 선택·추가 흐름 → [감정] 구성과 현재 선택을 쉽게 구별한다. 제외는 기존 확인창을 거치고 취소하면 소속이 유지된다.
2. **기기 상세:** [화면] 중앙 구분선이 있는 켬/끔 버튼과 ON 상태 → [조작] 어느 쪽을 눌러도 → [반응] 현행 계약대로 ON 유지, 명령 전송 없음 → [감정] 기존 화면의 상태가 일관되게 보인다.
3. **온습도:** [화면] 잘리지 않은 상·하단 눈금과 시간 격자, 파란 분무 표시 → [조작] 가로 스크롤·스크럽 → [반응] 시간선·마커·데이터는 같이 움직이고 Y축은 고정 → [감정] 시간과 지표를 혼동하지 않는다.
4. **탭 헤더:** [화면] 현재 그룹명 옆 V자 → [조작] 드롭다운에서 다른 그룹 선택 → [반응] 기존 대상 선택 → [감정] Figma와 동일한 조작 단서.
5. **개체 폼:** [화면] 연한 회색 사진 아이콘과 구분선이 있는 성별 선택 → [조작] 성별 변경 → [반응] 선택 칸만 남색과 기존 체크로 표시 → [감정] 선택 상태가 명료하다.

## 변경 파일 지도

| 단계 | 수정 파일 | 책임 |
|---|---|---|
| 1 | `lib/features/my_cage/presentation/device_detail_screen.dart` | 그룹 설정 아이콘·카드·치수, 기기 전원 외형 |
| 1 | `lib/features/my_cage/presentation/widgets/management_widgets.dart` | 필요 시 구성원 아이콘 배경색 인자만 추가, 기존 기본값 유지 |
| 2 | `lib/features/home/presentation/widgets/env_day_chart.dart` | Y축 잘림, 시간 격자 |
| 2 | `lib/features/home/presentation/widgets/control_log_list.dart` | 분무 마커·제어 기록 배경 역할색 적용 |
| 2 | `assets/icons/redesign_v2/2828/humidity_high_glyph.svg`, `assets/icons/redesign_v2/3636/humidity_high_glyph.svg` (신규 파생본) | 원본 viewBox·path를 보존한 흰 글리프 전용 에셋 |
| 2 | `docs/design-audits/2026-09-15-mist-badge-derivation.md` (신규) | 파생 SVG 원본 경로·변경 내용·해시 기록 |
| 3 | `lib/shared/widgets/redesign_tab_header.dart` | 공통 V자 드롭다운 |
| 4 | `lib/features/my_pets/presentation/widgets/pet_form_screen.dart` | 사진 아이콘 회색·성별 구분선 |
| 마무리 | `pubspec.yaml`, `CHANGELOG.md`, 구현 결과 문서·캡처 | 버전/한글 기록/검증 근거 |

기존 테스트 파일은 아래 실행 대상으로 사용한다. 새 회귀 테스트가 필요해지는 동작 변경을 발견하면 해당 단계에서 원인과 검증 범위를 먼저 기록한다.

## 1단계 — 03 그룹 설정 및 02 기기 상세

**대응:** 차이 1, 2, 3, 9.

**인터페이스:** `ManagementInventory.members(String groupId)`와 `ManagementKind {device, camera, pet}` 사용. `_selectedDeviceGroupProvider`, `groups()`, `_removeGroupAction` 반환 규약 유지. `_DeviceGroupSettings`의 선택 결과를 반환한 뒤 기존 이동/제외 확인을 수행한다.

- [ ] Figma `765:7526`·`765:7565` 기준 행과 버튼 규격을 구현 메모에 고정한다: 기기 행 높이36, 좌우24, 헤더 아래16; 행 이후28 → 그룹 카드 y186; 그룹 카드 최소78, 좌우16/상하12; 그룹 추가 높이52, 위 간격8; 하단 완료56 + 제외56.
- [ ] 그룹 행 우측에 device→camera→pet 순서의 원형36px 아이콘 슬롯 3개와 체크24px를 배치한다. 소속된 종류는 `textSecondary`, 없는 종류는 `textTertiary`; glyph20px는 기존 `surfaceHeader`. 체크까지 각 간격8px. 카메라·개체 부재를 아이콘 자체 삭제로 표현하지 않는다.

```dart
// ManagementItemIcon: 기존 호출의 외형을 유지하는 선택 인자.
const ManagementItemIcon(this.kind, {super.key, this.backgroundColor});
final Color? backgroundColor;
// decoration.color: backgroundColor ?? context.glass.textSecondary

final present = inventory.members(group.id).map((e) => e.key.kind).toSet();
// 세 종류 모두 렌더하며 해당 종류의 소속 여부로 배경 역할색만 결정한다.
ManagementItemIcon(kind,
  backgroundColor: present.contains(kind)
      ? glass.textSecondary : glass.textTertiary);
```

- [ ] 그룹 이름 영역은 Expanded + 최대2줄/ellipsis로 두고 우측 아이콘 슬롯 너비를 보존한다. 현행 최대 길이의 그룹명, 사육장/카메라 이름과 긴 hardware ID에서 overflow가 없는지 확인한다. 큰 글자에서는 고정78 대신 최소78로 늘어난다.
- [ ] 가운데 `TextButton`을 연회색 Material/InkWell 카드로 교체한다. `FigmaIcons.add` 24px, 글자 앞 간격4px, 좌측16px, 원본 반경12. `onTap: () => Navigator.pop(context, 'new')` 유지.
- [ ] 기기 정보 행을 좌우 추가12px padding으로 감싼다(화면 padding12+추가12=24). ListView top24→16, 기기 행 이후 gap24→28. 원본 구조에 맞춰 그룹 이름 두 줄 사이16px와 상하12px로 조정한다.
- [ ] 제외 TextButton의 세로 padding16을 제거하고 버튼 영역 자체를56px로 둔다. 하단 여백은 기기 상세와 같은 footer 기준을 사용하되 실제 safe area는 존중한다.
- [ ] 02의 켬/끔 외형에서 흰 선택 캡슐과 내부 margin3을 없애고 공통 연회색 면과 중앙1px `glass.border` 선을 둔다. 켬/끔 텍스트와 ON 고정, 두 key, 명령을 보내지 않는 콜백은 유지한다. 폭은 원본 패널112px(56×2), 높이40px.

```dart
// 중앙선은 반대편과 중복해 2px가 되지 않도록 한 번만 그린다.
const SizedBox(width: 56, height: 40); // 각 켬/끔 영역의 규격
// Stack 안 가운데 선: width 1, height 40, color glass.border.
```

- [ ] `flutter test test/features/my_cage/device_management_screen_test.dart test/features/my_cage/redesign_management_controller_test.dart` 실행. 전원 OFF 탭 write0, 그룹 제외 취소 write0, 그룹 이동 취소 원래 소속, 편집 뒤로가기/저장 통과 확인.
- [ ] 03 사육장·카메라 두 진입점과 빈 그룹·1종류 그룹·3종류 그룹을 촬영한다. Figma 원본 보관 PNG가 없는03은 Talk to Figma export가 가능하면 원본 PNG도 확보한다. 불가능하면 노드 치수 검증이라고 명시한다.

## 2단계 — 05 온습도 눈금·격자·분무 색

**대응:** 차이 4, 5, 6.

**인터페이스:** `EnvDayChart.data`, `initialFraction`, `environmentLineSegments`, `controlEntryIcon(ControlLogEntry, GlassPalette, double)` 유지. 524px 시간 콘텐츠·데이터 단절·마커/스크러버 좌표계 변경 없음.

- [ ] 현재 fixture에서 상단 눈금 잘림을 재현한 캡처를 기준으로 남긴다. `_axisOverlay`에서 음수 top이 내부 Stack에 의해 잘리는 경로를 확인한다.
- [ ] 라벨 오버레이의 상단을 반 라벨 높이만큼 올리고 높이를 늘려, 내부 라벨 top은 0 이상으로 배치한다. 격자선과 라벨 중심의 정렬은 그대로 유지한다.

```dart
// Positioned 외곽
 top: EnvDayChart.markerBand - EnvDayChart.labelHeight / 2,
 height: EnvDayChart.plotHeight + EnvDayChart.labelHeight,
// 내부 라벨 Positioned
 top: i * EnvDayChart.rowStep,
```

- [ ] Figma `765:2544` PNG/`765:2557` 노드와 시간 격자를 대조한다. 6시간 주선과 중간3시간 보조 점선의 위치를 확인하고, 동일524px 시간 콘텐츠 안에 그린다. 선 두께·점선 주기는 원본 PNG 3배 픽셀을 실측해 기록한 뒤 적용한다. 현재 JSON은 Line의 자식을 비워 반환하므로 점선 숫자를 JSON으로 확인했다고 보고하지 않는다.
- [ ] 시간 격자에는 `glass.border`를 사용한다. 선은 플롯과 시간 라벨 행까지 이어지며 바깥 경계를 포함한다. Y축 마스크로 가려진 구간과 스크럽 선을 구분한다. 전체 높이·좌우42px Y축 영역·현재24시간 범위를 임의로 변경하지 않는다.

```dart
// 시간에 따른 x값은 데이터·라벨·마커와 동일 기준이다.
final x = hour / 24 * EnvDayChart.contentWidth;
// 격자는 스크롤 콘텐츠에 포함하고 곡선 아래 레이어에 둔다.
```

- [ ] 28/36px 분무 SVG에서 원형 배경 요소만 제거한 파생 글리프 파일을 만든다. 원본 `assets/figma/`와 기존 runtime 파일은 그대로 둔다. viewBox, path, mask, 흰 글리프 크기/위치를 보존하고 파생 기록을 남긴다.
- [ ] 분무가 작동/on일 때만 `controlEntryIcon`에서 원 배경을 `controlEntryColor(entry, glass)`로 그리고 원본 규격 글리프를 얹는다. compact28과 기록36 두 크기 모두 처리한다. off 분기는 기존 회색 아이콘을 유지한다. 습도 수치의 남색은 바꾸지 않는다.

```dart
if (entry.kind == MarkerKind.mist && !off) {
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: controlEntryColor(entry, glass)),
    child: FigmaIcon.metric(
      'redesign_v2/${compact ? '2828' : '3636'}/humidity_high_glyph',
      size: size),
  );
}
```

- [ ] `flutter test test/features/shared/env_day_chart_test.dart test/features/home/env_detail_screen_test.dart test/features/home/control_log_list_test.dart` 실행. 같은 날 갱신 시 스크롤 위치 유지, 데이터 누락 구간 선 단절, 마커 겹침 보정, 제어 이력 델타 유지 확인.
- [ ] 393/402px에서 온도·습도 최상단/최하단, 소수/음수 눈금과 가로 스크롤 양끝을 확인한다. 배경 마스크가 마커를 새로 가리지 않는지 검사한다. 분무28·36px, 라이트·다크를 확인한다.

## 3단계 — 06·08 및 홈 공통 드롭다운

**대응:** 차이 7.

**인터페이스:** `RedesignTabHeader`의 choices, selectedId, onSelected 및 key 유지. 소비처 별로 따로 수정하지 않는다.

- [ ] 현재 채운 삼각형을 기존 `FigmaIcons.dropdown`으로 교체한다. Figma `keyboard_arrow_down`과 원본 SVG path의 V자 형태를 확인한다.

```dart
FigmaIcon.tinted(FigmaIcons.dropdown,
  key: arrowKey, color: glass.textSecondary, size: 24);
```

- [ ] pill 높이44, 좌우12, 텍스트와 화살표 사이4, 원본24px viewBox 유지. 종 선택 필드의 삼각형은 이 공통 헤더 변경에 포함하지 않는다.
- [ ] `flutter test test/features/home/home_header_bar_test.dart test/features/my_cage/crecam_home_test.dart` 실행. 기존 선택·빈 목록·긴 이름·계정/관리 이동 확인.
- [ ] 홈·카메라·MyCre 세 탭에서 같은 V자와 그룹명 표시, 드롭다운 메뉴 선택을 확인한다.

## 4단계 — 07 개체 폼

**대응:** 차이 8.

**인터페이스:** PetFormScreen의 draft/sex, 사진 선택·날짜·저장 콜백과 유효성 검사 유지.

- [ ] 사진 추가 glyph40px의 tint만 `p.textTertiary`→`p.deviceOff`로 바꾼다. 사진 추가 글자 색(textTertiary), 영역180×180, 그림 원본과 실제 사진 표시에는 영향이 없어야 한다.
- [ ] 성별 세 칸의 외곽 ClipRRect와 동일 폭을 유지하고, 비선택 칸끼리 맞닿는 경계에1px `p.border` 선을 한 번만 추가한다. 선택된 남색 영역 안으로 선이 들어가지 않게 한다.

```dart
const sexes = ['male', 'female', 'unknown'];
// 기존 for(final sex ...)를 같은 순서의 index 루프로 바꾼다.
final showDivider = index < sexes.length - 1 &&
    d.sex != sexes[index] && d.sex != sexes[index + 1];
// sexes는 현행 순서 ['male', 'female', 'unknown']를 사용한다.
// 각 칸 BoxDecoration의 오른쪽 border에만 적용한다.
```

- [ ] 남색 선택 칸·흰 체크15×11(viewBox,24px 배치 영역)·40px 높이는 유지한다. 성별 데이터 값을 새로 정의하지 않는다.
- [ ] `flutter test test/features/my_pets/pet_form_screen_test.dart test/features/my_pets/pet_form_save_test.dart` 실행. 기존 입력/선택/저장/실패 시 초안 보존 확인.
- [ ] 미구분→수컷→암컷 세 상태를 촬영해 구분선과 체크를 확인한다. 이번에는 스크롤 아래 입양일·체중·그룹·메모·저장까지 추가 촬영하며 새 차이는 별도로 기록한다.

## 5단계 — 통합 검증·재촬영·기록

- [ ] 수정 단계마다 `git diff --stat`로 범위를 확인하고 기능 그룹별로 검토한다. 실패 시 동일 문제의 빌드/수정 루프는 최대3회 후 오류를 정리한다.
- [ ] `flutter analyze --no-fatal-infos` 실행: error0, warning0. 기존 info6건은 이번 수정과 분리하되 새 항목이 생기면 해결한다.
- [ ] 위 관련 테스트를 한 번에 실행한다. 공용 관리 위젯·아이콘 경로 변경이 포함되므로 최종 `flutter test`를1회 실행한다. 실패나 새 변경이 없으면 반복하지 않는다.
- [ ] `flutter build ios --simulator --debug --no-pub --target=lib/main.dart`, `flutter build apk --debug --no-pub --target=lib/main.dart` 성공 확인.
- [ ] 기존 `docs/design-audits/2026-09-15-review16-captures/simulator_qa_entrypoint.dart.txt`에서 동일 가상 fixture를 재사용한다. 실제 서버·BLE·계정 데이터에 쓰지 않는다. 새로운 검수용 파일은 최종 일반 앱 빌드에 포함하지 않는다.
- [ ] 새 폴더 `docs/design-audits/2026-09-15-followup-captures/`에 이전 번호를 유지한01~08 및 추가 홈/카메라 상세/폼 하단·선택 상태를 저장한다. 데스크톱에는 `Vivanaut_Simulator_2026-09-15_Followup`으로 복사하고 원본/이전/수정 후 비교 HTML을 만든다.
- [ ] 각 후보1~9를 `일치/승인된 기능 차이/추가 확인 필요`로 판정한다. 01·04 및 기존 그래프 색·굵기·체크·업데이트 문구가 회귀하지 않았는지 확인한다. 전체 앱이 픽셀 단위로 같다고 일괄 판정하지 않는다.
- [ ] 가능하면 Android 에뮬레이터에서 흰 상단 배경, 스크롤, 텍스트 크기 확대를 확인한다. 사용할 수 없으면 Android는 빌드 검증만 완료했다고 구분해 보고한다.
- [ ] 검수용 임시 진입점을 정리하고 일반 `lib/main.dart` 앱으로 시뮬레이터를 복원한다.
- [ ] 실제 lib 변경마다 프로젝트 버전 정책에 맞춰 patch/build 증가 및 한글 CHANGELOG를 같은 커밋에 포함한다. 첫 구현 단위가 현재 버전에서 시작하면 `0.107.3+214`; 실행 시 버전이 이미 바뀌었으면 그 최신값에서 증가한다. 이후 독립 구현 커밋도 동일 정책을 따른다.
- [ ] 커밋은 관리/그래프/공통 헤더/폼/최종 검수 문서의 논리 단위로 나눈다. push는 해당 실행에 대한 사용자 지시 범위를 확인해 수행한다. 운영 배포·메인 병합은 별개다.

## 완료 기준과 커버리지

| 후보 | 완료 단계 | 최종 확인 |
|---|---|---|
| 1 그룹 아이콘 | 1 | 세 종류 슬롯과 소속 색 구분 |
| 2 그룹 추가 카드 | 1 | plus24·높이52·회색·좌측 정렬 |
| 3 그룹 치수 | 1 | 기기행/그룹카드/하단 버튼 실측 |
| 4 눈금 잘림 | 2 | 위·아래 라벨 전체 표시 및 격자 중심 정렬 |
| 5 세로 격자 | 2 | 원본 실측 패턴, 스크롤·시간 정렬 |
| 6 분무 색 | 2 | 파란 배경+흰 원본 글리프,28/36px |
| 7 V자 | 3 | 홈·카메라·MyCre 공통 적용 |
| 8 폼 아이콘·선 | 4 | 사진 회색, 성별 세 상태 검수 |
| 9 전원 외형 | 1 | 중앙선·회색 외형, OFF 탭 write0 유지 |

계획 자체 검토: 후보1~9에 누락 없음. 기존 기능 계약 유지. 신규 API·색상 토큰·패키지 불필요. Figma 점선 주기의 정확한 숫자와03 원본 PNG는 구현 시작 시 근거를 확보하는 작업으로 명시했으며, 현재 확보했다고 간주하지 않는다.

## 추가 Figma 수신 및 기능 확정

2026-09-15 새 채널 `jpgja1tq`에서 ‘추가내용’과 미연결 상태 섹션을 직접 확인했다. [원본·변경사항 기록](../../design-audits/2026-09-15-figma-additional/README.md).

1. **3단계 확장 후보:** V자 외에 드롭다운 메뉴의 흰 배경200px/반경12, 항목44px, 선택 Bold·빨강 ‘선택됨’, 구분선·그림자까지 맞춘다. 기존 그룹명 우선 정책 유지.
2. **기능 확정:** 그룹 상세 ‘이 그룹 삭제’는 그룹만 제거하고 구성원을 모두 그룹 없음으로 이동한다. 기기 등록·소유권·개체·영상·메모 보존, 확인 문구와 취소/삭제, 원자적 전체 성공/실패 처리 승인. 기존 단일 구성원 제외를 반복 호출하지 않으며 실제 서버 계약을 확인한다.
3. **기능 확정:** 확인된 카메라 미연결 MyCre는 연결 안내·‘카메라와 그룹만들기’ CTA·빈 격자 및 총 활동/평균0h0m을 표시한다. 연결됨의 확인 불가능한 값은 --, 정상 관측 무활동은0이다. 초기 표시0을 측정 기록으로 저장하지 않는다.
4. **검증 예시 추가:** 그룹에는 사육장·개체, 그룹 없음에는 카메라가 있는 상태. ‘그룹의 장점 안내’ 메모는 원문에서 나중 추가로 적혀 있어 이번 범위에 자동 포함하지 않는다.

그룹 삭제와 MyCre 표시 범위는 사용자 승인 완료. [확정 기획 및 검증 상태표](../../design-audits/2026-09-15-figma-additional/approved-behavior.md)를 실행 기준으로 함께 읽는다. 나머지 항목의 승인 상태는 유지하며, 이 기록은 구현 완료를 뜻하지 않는다.

## 실행 기록 — 2026-09-15

사용자 ‘구현 시작’ 지시에 따라 1~4단계 표현 수정과 추가 확정 기능을 구현했다. 5단계 검증 결과는 [구현 결과](../../design-audits/2026-09-15-followup-implementation-results.md)를 따른다. 기존 체크박스는 계획 원문으로 보존하며 완료 범위를 위 결과표로 구분한다. 앱 버전0.107.7+218, 전체859통과·6건너뜀, 일반 iOS/Android 빌드 성공. 운영 그룹 삭제 RPC 배포·팝업 그림자 정밀 실측·Android 화면 대조는 결과 문서의 잔여 사항이다.
