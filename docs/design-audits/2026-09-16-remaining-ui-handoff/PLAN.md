# 남은 Figma 화면 수정 Implementation Plan — Claude 전달용

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 이번 문서는 실행 이관용이며 작성자인 Codex는 앱 코드를 수정하지 않았다.

**Goal:** 아래 18개 작업 묶음의 남은 UI 차이를 수정하고, 같은 크기의 원본/앱 비교 결과를 사용자에게 돌려준다.

**Architecture:** Flutter·Riverpod의 기존 화면/컨트롤러/Repository를 유지한다. 화면 스타일과 배치는 Figma로 맞추되, 이미 확정한 저장·기기 명령·활동 집계 계약은 바꾸지 않는다. 전체 화면 선택/편집기와 플로팅 CTA는 기능별로 분리하고, 공통 위젯 수정으로 이미 승인한 화면을 되돌리지 않는다.

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase, Hive, 기존 SVG/3배율 PNG, ColorSystem.

**Spec:** `docs/superpowers/specs/2026-09-15-figma-redesign-approved-design.md`, `docs/design-audits/2026-09-15-ui-review/REVIEW_STATUS.md`, `docs/design-audits/2026-09-16-remaining-ui-handoff/SCREEN_MATRIX.md`.

## 0. 실행 위치·전달물·현재 상태

- 작업 트리: `/Users/baek/myProjects/tera-ai-flutter/.worktrees/redesign-20260915`
- 브랜치: `codex/figma-redesign-20260915`
- 앱 코드 기준 커밋: `570c0c0`, 버전 `0.107.33+244`. 이후 전달 문서 커밋은 코드 기준을 바꾸지 않는다.
- 메인 체크아웃 `/Users/baek/myProjects/tera-ai-flutter`에 덮어쓰지 않는다. 사용자/다른 작업자의 변경을 취소하지 않는다.
- 근거 폴더: `docs/design-audits/2026-09-16-remaining-ui-handoff/`의 `preview.html`, `SCREEN_MATRIX.md`, `inventory.json`, `figma/`, `specs/`, `app/`, `reproduction/`.
- 원본: Talk to Figma **axfr9s1n**, Final Design `0:1`. 2026-09-16 재접속해 활성 6개 섹션을 읽었다. 다른 Figma MCP로 임의 대체하지 않는다.
- **104개 원본 상태/참고 이미지**를 18개 작업에 매핑했다. 중복 프레임·부분 바텀시트·팝업을 포함하며 104개의 독립 앱 페이지라는 뜻이 아니다. **52개 현재 제품 위젯 캡처**를 제공한다.
- 제품 위젯 캡처는 실제 앱 위젯을 mock provider로 렌더링했다. OS 시뮬레이터 스크린샷/실기기/BLE/운영 데이터 검증으로 부르지 않는다. 회색 영상은 mock 썸네일이며 원본 영상 수신 오류의 증거가 아니다.
- 각 원본의 실제 문자·색·노드 경계·반경·글자 크기/굵기/줄높이/자간은 `specs/<node-id>.json`에 있다. `rect.x/y`는 해당 원본 프레임에 대한 상대 좌표다. 바텀시트 단독 PNG의 y=0을 휴대폰 y=0에 배치하지 않는다.

## Global Constraints

1. `CLAUDE.md`와 `.claude/rules/vivanaut-caof.md` 준수. 기존 UI 개선은 Standard, 신규 상태 흐름은 범위와 계약을 확인한다.
2. 01~29 승인 결과를 보존한다. 특히 그룹/개체 이름, 오류 배치, 저장 버튼 플로팅, 원본 체크박스 계열을 이전 디자인으로 되돌리지 않는다.
3. 상단 선택 이름은 그룹이면 그룹명, 미그룹이면 사육장/카메라/개체명. 기본값은 `사육 환경 1`, `사육장 1`, `카메라 1`부터 시작한다.
4. 신규 종·모프는 크레스티드 게코만. 기존 다른 종 데이터는 계속 보여야 한다. 원본의 레오파드 예시는 새 카탈로그 추가 명령이 아니다.
5. 그룹당 개체1마리. 그룹 삭제는 구성원 보존/연결 해제. 기기·개체 실제 삭제 범위 및 이동 확인은 기존 확정 정책 유지.
6. 북마크는 기존 `clip_favorites` 동기화 유지, 메모는 계정·휴대폰별 Hive만. 메모 삭제≠북마크 해제. 영상 삭제는 해당 유저 목록 숨김이며 R2 원본 삭제 금지.
7. 모든 영상에 메모 편집 가능, 메모 카드 UI는 북마크 목록만. 색상은 기존6색, 새 메모 연속 동일색 금지, 수정 시 기존색 보존.
8. 냉각은 `fan2`; 상태 미보고는 `--`·제어 비활성. 타이머 최대7,200,000ms. 환기팬과 명령·기록 혼합 금지.
9. 밝기는 지원 기기에만 **20~100%, 10% 단위**. 기존 확정은 슬라이더 선택 후 적용 전송, 닫기는 미전송이다.
10. 기존 분무 확정은 탭 즉시3초·5초 중복 방지. 새 원본의 지연/취소 동작은 P11의 충돌 안건이다.
11. LCD 최대20자, 공백 포함, 기기 이름과 독립, 중복 허용. Figma의 “중복되지 않는 이름” 안내를 LCD 제약으로 구현하지 않는다.
12. 흰 화면의 스크롤 상단 회색 tint 금지. 단, 새 예약 화면처럼 원본이 명시적으로 #F4F4F4인 화면까지 전부 흰색으로 덮지 않는다.
13. ColorSystem 역할색과 기존 자산 사용. 새로운 하드코딩 색·문자열·Material 대체 아이콘·새 패키지를 임의 도입하지 않는다.
14. 메인 탭 업데이트 문구는 `업데이트 + 상대 날짜`, 데이터 없으면 `업데이트 없음`. 평균/관측 데이터가 없다는 이유로 값을 합성하지 않는다.
15. 현재 그룹 카메라의 조회 가능 기록을 MyCre에 표시한다. 연결/등록일로 잘라내거나 과거 카메라와 병합하지 않는다.
16. 이번 실행은 운영 DB·R2·실제 기기 명령·외부 메시지 전송을 포함하지 않는다. 서버 계약을 확인할 때는 로컬 수신 문서부터 읽고 배포 완료를 추측하지 않는다.
17. **서버/기능 결정이 필요한 P11과 일부 P04/P09/P10은 UI 승인으로 기능까지 승인받았다고 간주하지 않는다.** 확정된 부분을 먼저 수정하고 남은 결정을 결과에 분명히 남긴다.

## 1. 권장 실행 순서와 체험 흐름

P01 → P06 → P07 → P13/P14/P15/P16 → P03/P04/P05 → P02/P08 → P09/P10 → P17/P18 순서로 진행한다. P11은 기존 확정 동작과 충돌하므로 결정 기록을 별도로 만든다. 각 묶음은 별도 검증·커밋으로 돌려줄 수 있다.

체험 설계 기준:

- **개체:** 입력 → 검색/선택 → 값 반영 → 저장 성공 → 등록 완료/연결 안내. 뒤로가기는 취소 의미가 명확해야 하고 실패 입력을 지우지 않는다.
- **연결:** 기기 검색 → 타입별 선택 → AP 선택 → 비밀번호 → 연결 대기 → 각 기기의 실제 성공/실패 → 그룹/개체 선택. UI 때문에 재등록하거나 성공한 기기를 다시 프로비저닝하지 않는다.
- **제어:** 실제 상태 확인 → 설정만 변경 → 승인된 실행 조작 → 송신 중 중복 차단 → 성공/실패·보고값 표시. 원본의 스위치 그림을 실제 기기 성공 상태로 선반영하지 않는다.
- **예약:** 기기 선택 → 시간/반복 입력 → 저장 → 목록 반영 → 개별 수정/삭제. 같은 pair_id의 on/off는 하나의 사용자 예약으로 다룬다.
- **영상:** 목록 → 동일 플레이어 → 이전/다음·회전 → 메모/북마크·저장/숨김 → 현재 목록에 결과 반영. 회전과 팝업이 플레이어를 새로 만들지 않는다.

## 2. P01 — 모프 검색 결과·검색 없음

**근거:** `1043:4873`, `1043:5003`. 현재 `app/widget-morph-initial-search.png`, `app/widget-morph-no-result.png`.

**차이:** 현재는 단순 `contains(query)`와 초성 그룹 목록을 그대로 재사용한다. `ㄹ` 같은 초성 검색이 안 되고, 일치 글자 빨간 강조·검색어 삭제X·검색 결과 없음 문구가 없다. 입력값 초기화 행을 없앤29번 승인과 **검색창 내용 지우기**는 다른 기능이다.

**파일:** `lib/features/my_pets/domain/pet_registration_catalog.dart`, `lib/features/my_pets/presentation/widgets/pet_form_screen.dart`, `assets/l10n/ko.json`. Test: `test/features/my_pets/pet_registration_catalog_test.dart`, `pet_morph_selection_test.dart`.

- [ ] 검색어가 비면 승인된 초성 그룹 목록, 검색어가 있으면 **초성 섹션 없는 결과 목록**으로 분기한다. 한글·영문 검색을 보존하고 각 한글 음절의 초성 검색도 지원한다. 선택 ID/모프·라인브리드 정체성은 보존한다.
- [ ] 검색 결과의 일치한 글자만 `navSelected`로 강조한다. 원본의 `ㅂ` 검색에서 비/블랙뿐 아니라 디아블로·라벤더·노바가 매치되는 것을 근거로 **문자열 전체 음절의 초성**을 검사한다. 원본의 다른 종 이름은 앱 데이터에 넣지 않는다.
- [ ] 검색어 지우기X를 입력칸 우측에 추가한다. 누르면 검색어만 비우고 이미 선택된 모프/폼 값은 그대로 둔다.
- [ ] 결과0일 때 `일치하는 모프가 없습니다`: x24/y200/w345/h19, 16/500/19.09375/-.32, #949090, 중앙. 검색창 x12/y119/w369/h65 유지.
- [ ] 테스트: `ㄹ`로 릴리 계열과 라벤더 매치, `Lilly`로 릴리 화이트 매치, 무결과 안내, X 후 전체 목록, 뒤로가기 기존값 유지, 결과 선택 후 복귀.

구현 방향(새 이름/저장 계약을 추가하지 않는 순수 검색 함수):
```dart
// 각 음절을 초성으로 변환한 문자열도 검색 대상으로 삼는다.
String initialOf(int rune) {
  const initials = ['ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'];
  return rune >= 0xAC00 && rune <= 0xD7A3
      ? initials[(rune - 0xAC00) ~/ 588]
      : String.fromCharCode(rune);
}
```
영문 검색 결과는 대응 한글을 임의로 붉게 만들지 않고, 실제 매치 가능한 범위만 강조한다.

## 3. P02 — 개체의 그룹 선택·등록 완료·기기 결합 안내

**근거:** `1043:3649`, `1035:2735`, `994:13307`, `990:7508`. 현재 그룹 선택은 `app/widget-pet-group-picker.png`, 저장 이후 경로는 코드 대조.

**차이:** `PetFormScreen._groups()`는 “그룹 없음 + 이름”의 ListTile 바텀시트다. 원본은 그룹 번호/이름/사육장→카메라 아이콘/체크와 하단 “이 사육 환경에서 키우기”·“나중에 하기”를 갖는 전체 화면이다. `_save()`는 성공 후 pop만 하므로 독립된 개체 추가 완료 화면이 없다. 기기 결합은 `_offerExisting/_petChoice`의 간단한 선택/바텀시트 경로와 원본의 확인 카드가 다르다.

**파일:** `pet_form_screen.dart`, `lib/features/my_pets/presentation/pet_add_screen.dart`, `pet_edit_screen.dart`, `pet_form_route.dart`, `lib/features/my_cage/presentation/device_add_flow_screen.dart`, `pairing_pet_selection_screen.dart`, `lib/core/router/app_router.dart`.

- [ ] 폼의 그룹 선택과 **저장 후 연결 안내**를 동일한 저장 타이밍으로 섞지 않는다. 폼 내부 선택은 draft만 변경하고 최종 저장 시 기존 `petProfileAndGroupSaveProvider`를 사용한다.
- [ ] 전체 화면 그룹 카드 선택기를 분리한다. 미선택 CTA 비활성,1그룹 선택, 기존 다른 그룹 개체 교체/이동 시 기존 확인 절차 유지. 아이콘 순서는 사육장→카메라→개체.
- [ ] **신규 등록 성공에만** 체크 아이콘/“도마뱀 추가 완료”/기기 추가 하기/나중에 하기 화면. 편집 성공은 원래 화면으로 복귀. 저장 재시도 시 동일 개체를 또 만들지 않는다.
- [ ] 사육장·카메라 함께/따로 사용하기 확인은 원본 카드와 CTA로 표현하되 현재 autoGroup/명시 선택 정책을 확인한 후 연결한다. UI 변경만으로 자동 결합 범위를 확장하지 않는다.
- [ ] 테스트: 신규/편집 분기, 저장 실패 입력 유지, 그룹 없는 신규 등록, 기존 개체 보존, 이동 취소, 나중에 하기 무쓰기, 뒤로가기 재등록 없음.

## 4. P03 — BLE 검색·미선택·1개/2개 선택·검색 실패

**근거:** `971:1837`, `990:11220`, `990:7601`, `990:7744`, `990:11450`. `app/pairing-scan-*.png`.

**차이:** 원본 미선택 상태는 다시 스캔 CTA 하나, 선택하면 기기 N개 추가로 바뀐다. 현재 미선택에도 비활성 “기기0개 추가”와 보조 다시 검색이 함께 나타나며, 선택 후에도 추가 보조 버튼 때문에 원본 CTA y696과 다르다. 로딩은 제목 옆 원본과 달리 별도 중앙 행. 검색0 결과는 원본의 회색 둥근 목록 행과 다르다. 본문 장치명/하드웨어명 열 배치도 원본과 다르다.

**파일:** `lib/features/my_cage/presentation/device_add_flow_screen.dart` (`_scan`, `_heading`, footer), `widgets/management_widgets.dart`는 공유 영향 검토. Test: `device_add_flow_screen_test.dart`, `device_add_flow_test.dart`.

- [ ] 미선택: 다시 스캔, scan중 비활성+기존 회전SVG. 선택수>0: `기기 N개 추가`. 필요한 재검색 복구 진입은 원본 패턴 안에서 제공하고 정상 화면에 중복 CTA를 붙이지 않는다.
- [ ] CTA x12/y696/w369/h56, 목록과 독립된 플로팅. 기존 Column/Spacer/SingleChildScrollView 안의 CTA를 화면 하단 overlay로 분리한다. 마지막 행이 버튼 뒤로 숨어 접근 불가능하지 않도록 scroll bottom padding 확보.
- [ ] 목록 #F4F4F4, 행 구분선, 반경12. 체크는 selected400/unselected400,24 프레임. 아이콘40과 신호SVG는 원본과 현재 자산의 실제 그림 크기로 비교한다.
- [ ] 실제 RSSI·기기 이름을 사용한다. 원본의 이미 등록된 기기는 검색에 나타나지 않을 수 있으므로 가짜 항목을 추가하지 않는다.
- [ ] 테스트: 검색중/0개/1개/2개, 타입당1선택, 다시 검색 후선택, 긴 하드웨어명,320폭/글자1.7배/긴 목록 플로팅 접근성.

## 5. P04 — 네트워크 목록·비밀번호·연결 대기·오류

**근거:** `982:3103`, `990:11306`, `990:11380`, `982:3174`, `982:3413`, `982:3459`, `982:3500`, `982:3604`. `app/pairing-network-*`, `pairing-password-*`, `pairing-connecting.png`.

**차이:** 네트워크 화면 우측X 누락, 로딩위치/빈상태 회색행/버튼 문구 차이. 신호 색·보안 자물쇠가 원본과 다르다. 연결 중 원본은 화면 위 흰 투명 마스크+spinner, 현재는 폼과 같은 스크롤 Column. 오류는 원본 확인 모달 대신 아래쪽 붉은 문자열이다. 비밀번호 정상 화면에 원본에 없는 “다른 네트워크 선택” 행이 있고 CTA가 밀린다.

**파일:** `device_add_flow_screen.dart`, `device_add_flow_controller.dart`, `lib/features/my_cage/domain/wifi_access_point.dart`, `assets/l10n/ko.json`.

- [ ] 단계별 header의 뒤로/X 의미를 보존하며 원본 위치 적용. 네트워크 재검색/직접 입력 문구와 정상/검색 실패 회색 리스트 배치를 맞춘다.
- [ ] 비밀번호 필드65·radius12·#FAFAFA/선#E3E3E3, 눈SVG24, 기억하기 selected300/unselected300 및 원본 글자/간격 유지. 입력이 있을 때 show/hide가 비밀번호 노출 의미와 일치해야 한다.
- [ ] busy는 별도 Stack overlay로 차단하고 스피너·“WiFi 연결 중”을 표시한다. 실패 시 입력 유지·확인 모달·확인 후 재시도. **오류가 모두 비밀번호 오류인 것처럼 바꾸지 않는다.** timeout/BLE/등록 지연은 기존 오류 의미를 보존한다.
- [ ] 빈 비밀번호 활성 조건은 보류: 현재 AP 모델에 보안 여부가 없으므로 UI 맞춤용으로 전부 비활성화하면 개방형 AP를 막는다. `WifiAccessPoint`/BLE 응답에 security 정보가 실제 있는지 먼저 확인한다. 있으면 protected/unknown/open3상태로 처리, 없으면 기존 허용을 유지하고 차이를 보고한다. 자물쇠도 임의로 채우지 않는다.
- [ ] 키보드 위 CTA 위치(원본 y466/height56인 키보드 상태)와 정상 y696/height56을 각각 재측정. OS 키보드 높이를 상수로 박지 않는다.
- [ ] 테스트: 공개AP/암호AP/정보없음, 기억하기, show/hide, keyboard, 연결중 중복 차단, 실패 후재시도, 연결된 기기 재송신 방지.

## 6. P05 — 연결 성공·개체 카드 선택

**근거:** `982:3643`, `990:7549`, `990:11583`, `1043:5893`, `1043:5992`. `app/pairing-result-*`, `pairing-pet-*`.

**차이:** 성공 아이콘·제목·CTA의 세로 위치가 현재 Spacer 배분에 따라 원본과 다르다. 사육장/카메라 단독 성공에는 기존 기기 연결 보조 동작이 추가된다. 개체선택 기본 구조는 이전 구현으로 유사하지만 원본의 1마리 확인 제목/카드 상태와 별도 비교가 필요하다. 작은 화면·큰 글자에서 제목/선택 카드와 CTA가 겹치거나 잘려 읽기 어렵게 보이는 캡처가 있다(렌더 overflow 예외0만으로 통과시키지 말 것).

**파일:** `device_add_flow_screen.dart` (`_results`), `pairing_pet_selection_screen.dart`.

- [ ] 성공별 원본문구/체크64/가운데 정렬/CTA56/보조나중에56 위치를 조건별로 맞춘다. 기본은 x12/y696/w369/h56.
- [ ] “기존 기기와 연결”은 기존 사용자를 위한 승인된 경로이므로 삭제하지 말고 전체 화면 카드 확인으로 옮길 필요가 있는지 P02와 함께 정리한다.
- [ ] 여러 개체는1개 선택, selected300/unselected400. 한 마리 상태는 `1043:5992`의 확인형 문구/구성 적용. 기존 다른 그룹에서 이동은 확인 취소 시 원복.
- [ ] 긴 이름/모프를 무조건 축소하지 않는다. 작은 화면·큰 글자는 텍스트 줄바꿈/콘텐츠 스크롤 및 CTA 여백으로 전체 내용을 읽고 선택 가능하게 한다.
- [ ] 테스트: device/camera/both success, partial success·pending(원본없음→기존복구유지),0/1/여러개체,나중에무쓰기,동시탭1회,대상group 소멸.

## 7. P06 — 빈 화면과 미연결 MyCre

**근거:** `1043:5063/5110/5161`, `1063:7793/7731/7663`, `990:11767`, `1107:9719`. `app/redesign-home-empty.png`, `redesign-camera-empty*.png` 및 현재 shared widget.

**차이:** 빈 화면 CTA가 현재 사각에 가까운 radius12/‘＋’ 없음. 원본 CTA는142×56·radius29.5 및 plus icon. PNG 자체는 보유. 공통빈상태의 고정 top132는 호스트 header/SafeArea에 의존하므로 탭별 그림 y250/문구y493/CTAy547을 재측정해야 한다. 초기 mock 이미지가 로드되지 않은 빈 썸네일은 제품 누락으로 오판하지 않는다.

**파일:** `lib/shared/widgets/redesign_empty_state.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/my_cage/presentation/crecam_screen.dart`, `lib/features/my_pets/presentation/my_cre_activity_screen.dart`, `device_management_screen.dart`.

- [ ] red CTA142×56/radius29.5, 기존 add SVG, 원본 여백/서체 적용. MyCre의 긴 버튼문구는 원본 폭·글자 기준을 별도 측정한다.
- [ ] empty_01~03 PNG는 `assets/figma/2026-09-15/images/Empty_0*x3.png`를 scale3으로 사용하고 투명 여백을 포함한 외곽/실제 그림 모두 비교한다.
- [ ] MyCre 미등록(empty03)과 개체있음/카메라미연결(프로필+연동CTA+0h0m 그래프)을 구별한다. 데이터 없는 연결 카메라를 미연결0값으로 바꾸지 않는다.
- [ ] 기기관리0개 화면은 회색 안내 두 영역과 하단기기추가, 기능있는경우와 문구/CTA를 구분한다.
- [ ] 테스트: 3탭 모두0개,개체만,카메라만,사육장만,최초PNG precache,320폭,Android 스크롤상단색.

## 8. P07 — 온습도 일간·주간·스크럽·제어 기록

**근거:** Main `1081:4873`, `1081:5052`를 현재 배치 기준으로, Home `945:3245/3650/3867/3428`을 긴 화면·스크럽 참고로 사용. `app/widget-env-*.png`.

**차이:** 주간 헤더의 SVG를 원 전체 단색으로 tint해서 내부 온도계/물방울이 사라지는 모습이 재현된다. 최고 막대 위/아래 수치가 원본의 강조색과 다르며 앱은 원본에 없는 최고 요일 강조를 한다. 격자는 현재 가로선 중심이고 원본은 세로 점선도 있다. 주간 축·막대 위치/두께/헤더 간격을 실측해야 한다. 데이터 차이로 곡선 모양이 다른 것을 UI 오류로 분류하지 않는다.

**파일:** `lib/features/home/presentation/env_detail_screen.dart`, `widgets/env_day_chart.dart`, `widgets/week_range_chart.dart`, `widgets/control_log_list.dart`, `lib/shared/widgets/figma_icon.dart`(사용처 수정 우선).

- [ ] 주간 헤더는 원본 복합색 SVG의 흰 내부 글리프를 보존한다. 전체 SVG를 단색 tint하지 않고 기존 metric/원본색 렌더링 규칙을 적용한다. daily28 아이콘과 비교.
- [ ] Main 원본에서 최고 막대의 상·하 수치 모두 강조색(온도 빨강/습도남색), 최소 막대 회색, 요일은 회색. `WeekRangeChart`의 라벨/요일 규칙을 맞추되 이미 승인한 MyCre 차트 컴포넌트를 같이 바꾸지 않는다.
- [ ] y축은 실제 값에 맞춰 확장하되 원본 예시의 “32.5가30눈금 위” 같은 모순까지 복제하지 않는다. 없는 요일/미래는 막대 미표시, valid count/평균 계약 유지.
- [ ] 일간 스크럽: 시간·값 chip,선·원형포인트·아이콘마커 및 현재 시각 기반 창을 원본과 대조. 현재 데이터와 선택날짜/SafeArea를 고정해 동일 조건 PNG를 만든다.
- [ ] 제어기록: 아이콘40,행간·보조글자·오른쪽측정/델타 정렬을 specs에 맞춘다. fan/fan2 ON/OFF 짝·모르는값`--`·실패명령 제외 유지. `envDetail`의 설명문이 원본에 없으면 UI에서 제거하되 계산/근사치 근거는 문서로 남긴다.
- [ ] 테스트: 온도/습도 개별결측,주간최대·최소동률,빈주,과거/오늘/미래,스크럽,log 0/다수/짝없음,30분평균 동일값.

## 9. P08 — LCD 문구 전체 화면

**근거:** `1081:3160`, `1081:3323`; `app/widget-lcd.png`.

**차이:** 현재 `DeviceSettingSheet`에 기본값복원/적용 버튼. 원본은 전체 화면/모듈 그림/안내문구/입력카운터/플로팅 완료다. 모듈 그림은 현재 확보한 Empty_01을 임의 crop/확대해서 대체하면 안 된다.

**파일:** `lib/features/my_cage/presentation/widgets/lcd_setting_tile.dart`, `lib/features/home/presentation/home_screen.dart`, `assets/l10n/ko.json`, 자산 매핑문서. Repository `lcd_repository.dart` 유지.

- [ ] `showLcdSheet`의 public 호출은 유지하거나 호출처를 함께 갱신하고, 내부는 전체 화면으로 전환한다. header44·제목16/700/19, 입력x12/y359/369×65,카운터/20,기본CTA x12/y696/369×56.
- [ ] 모듈 illustration은 원본 하위 노드에서 SVG 또는 x3 PNG로 확보한다. 파일에 실제 들어오기 전 새로 그리거나 Material 아이콘으로 대체하지 않는다.
- [ ] 수정 없음/전송중 완료 비활성,키보드위 고정,실패입력유지. 현재 이름문구를 읽을 계약이 없으면 기기 이름을 현재 LCD값인 것처럼 채우지 않는다. 마지막 성공값 로컬 저장/서버읽기 가능 여부를 확인해 결과를 명시한다.
- [ ] 중복 허용·20자 유지. 원본의 숨은 중복오류문구는 실제 제약으로 만들지 않는다. **기본값 복원은 기존 기능**이므로 모프 초기화 제거 지시를 근거로 같이 삭제하지 않는다. 원본에 없는 복원 UI의 노출 위치는 결정목록에 남긴다.
- [ ] 테스트:20자/한글emoji grapheme/공백/대상변경/두번탭/송신실패/키보드/복원별도clear 호출.

## 10. P09 — 환기팬·냉각팬·LED 즉시 제어 화면

**근거:** 환기팬 `1106:4296/4322`, 냉각 `1106:4394/4642`, LED `1106:4127`, `1107:8102`, 홈위overlay `1107:7996/8292/8134`. `app/widget-fan-duration.png`, `widget-led.png`, 제어 코드 대조.

**차이:** 현재 제목+ChoiceChip+시작/끄기 시트. 원본은 즉시/예약 segment,전원 스위치,장치별색 시간칩 및 LED 밝기 row. 원본에는 별도 ‘시작’이 없어서 **언제 송신하는지** 기존 확정과 충돌할 수 있다.

**파일:** `lib/features/home/presentation/cage_control_actions.dart`, `widgets/fan_duration_sheet.dart`, `widgets/cage_control_grid.dart`, `home_control_providers.dart`. 신규 분리 후보 `widgets/actuator_control_sheet.dart` (표시·임시선택만 담당).

- [ ] 레이아웃은 원본의 radius/면색/좌우24/segment/전원row/시간row로 분리. 색은 fan#228C73,cooling#636DDB,LED#E89E00를 현재 역할색에 연결한다. 각 chip radius/높이는 node별(specs) 확인, 공통 Material ChoiceChip 체크를 그대로 노출하지 않는다.
- [ ] 환기10/30/60/120분·계속,냉각30/60/120분,LED30/60/120/180분·계속이라는 **새 원본 옵션**과 현재 지원 duration/payload를 대조한다. 냉각 계속켜기 또는2시간 초과는 만들지 않는다.
- [ ] LED20~100/10%단위·지원여부 gate 보존. 원본 밝기row(값+track+white thumb)로 그리되 드래그마다 명령을 보내지 않는다.
- [ ] UI 조작→송신 타이밍은 P11 결정 전 기존 확정 유지. 스위치만 붙인 채 동작은없는 가짜 완성 상태를 보고하지 않는다.
- [ ] 테스트: 각지속시간 ms,fan2미보고,offline,target변경,중복송신,밝기20/100/미지원,시트취소미전송,실패상태유지.

## 11. P10 — 예약 목록·추가·상세·수정·삭제

**근거:** `1106:4955/5317/7142/7234`, `1107:10307/10246/9697`, 네 장치 상세/수정 `1107:8758/9131/9236/9325/9413/9509/9578`, 예약탭 `1106:5524/6415/4890/5648/6527/5438/5629/5734`. 전체 ID는 matrix에 P10으로 연결했다. 현재 `app/widget-routine-empty.png`, `widget-schedule-editor.png`, `routine_settings_screen.dart` 대조.

**차이:** 현재 구형 일정목록/FAB/시점·구간·스마트조건 시트. 원본은 #F4F4F4 전체 화면,장치 아이콘별 목록,전체폭 고정CTA,장치선택4타일,장치별시간편집,삭제모드/확인창. 앱에 원본에 없는 내부지원설명 각주가 표시된다.

**파일:** `lib/features/home/presentation/routine_settings_screen.dart`, `widgets/schedule_editor_sheet.dart`, `schedule_providers.dart`, `lib/features/home/domain/schedule.dart`. 분리 후보 `widgets/schedule_time_fields.dart`, `widgets/schedule_actuator_picker.dart`.

- [ ] 목록 header44 “기기 예약 설정”, 우측휴지통,시작시각정렬,반경12 장치row·실제 enabled색,하단 x12/y696/369×56 “예약 추가”. 빈목록 안내를 원본 흰박스에 배치. 지원설명 각주는 문서로 옮긴다.
- [ ] 장치4타일→해당장치 전용 전체화면. fan/LED 시작·종료,fan2 시작+30/60/120분 종료,분무 시작만. 반복요일은 월~일 원본칩. 이미 존재하는 숨겨진 guard는 편집기에서 없앴다고 삭제/재활성화하지 않는다.
- [ ] 입력시간은 유효한12시간제/24시간제로 일관되게 변환한다. 원본의 오후14시 같은 예시모순을 실제 값에 반영하지 않는다. 자정넘김·요일없음/매일·종료같음·기존예약편집을 테스트한다.
- [ ] 기존 `ScheduleDraft`, `SchedulesNotifier.add/addSpan/updateSpanTiming/setPairEnabled` 및 `Schedule.group`를 사용한다. 예시 UI 하나를 만들기 위해 새 서버모델을 만들지 않는다. 현재 서버의 LED brightness payload 편집 가능 여부·fan2 duration 저장은 계약 확인 후 연결한다.
- [ ] 삭제모드는 n개사용자예약 선택+“n개 항목 삭제” 빨간 고정CTA. on/off pair는1항목으로 세고 둘 다 처리한다. 원본 확인345×144/radius12/본문중앙/취소검정·삭제빨강. 부분실패 시 남은 항목을 다시읽고 성공한것을 다시 삭제하지 않는다.
- [ ] 편집 저장CTA와 하단“예약 삭제”는 스크롤과 독립하고 입력 마지막행이 접근 가능해야 한다. 원본 모든 페이지에 같은 bottom값을 기계적으로 넣지 않는다.
- [ ] 테스트:각장치신규/편집,시점·pair호환,시작순정렬,1/복수삭제,일부실패,guard보존,enabled반영,기기변경,서버가못받는payload미전송.

## 12. P11 — 원본과 기존 확정 기능의 충돌 목록

**이 섹션은 임의 구현 금지. 다른 확정 UI 수정은 계속 진행한다.**

| 항목 | 새 원본 | 기존 확정/현재계약 | Claude 결과에 요구하는 결정안 |
|---|---|---|---|
| 분무 | 시트의1회분사·실행전2초·취소·완료토스트 `1106:6391/6605/6646/6790` | 홈탭 즉시3초 실행,5초중복방지 | 동작 변경 제안과 기존 유지 결과를 분리. 실제송신전 취소인지 이미송신한명령취소인지 명확히 한다. 서버가취소불가면 가능하다고 표시하지 않는다. |
| 제어스위치 | 스위치 변경으로 전원상태표현 | 팬시간선택→시작,LED선택→적용 | 스위치/시간/밝기 중 어떤 조작이 송신인지 한 흐름으로 확정한다. |
| 예약작동중 | 즉시 제어 비활성+안내 `1106:6362/6302/6939/6235` | 예약 enabled는현재작동중이 아님 | 실제active예약을판정할서버/텔레메트리필드확인. 시간범위만으로진행중이라고단정금지(guard skip/수동제어/실패 가능). |
| LED지속시간 |30분~3시간/계속|현재 LED immediate payload는brightness 중심|서버가LED타이머를지원하는지수신계약으로확인. 로컬화면닫으면사라지는Timer로대체금지.|
| LCD기본값복원 |원본에없음|기존clear호출기능|노출위치/제거여부결정필요. 모프초기화제거와혼동금지.|
| Wi-Fi빈암호/자물쇠 |빈암호비활성·보안아이콘|AP security정보없음|P04의open/protected/unknown처리결정.|

서버 작업이 필요한 결론이 나오면 **요청 대상**을 붙인다: terra-server/기기명령·예약·LCD·BLE 계약은 이관훈님, 카메라영상/공개batch/관측coverage는 petcam-lab, 표현·로컬draft·Hive는 앱팀. 실제 요청/전송은 사용자가 한다.

## 13. P12 — 하이라이트 목록

**근거:** 최신 Main `1081:5235`, 보조 Camera `945:4287`; `app/widget-highlights*.png`.

**차이:** 현재는 밤별 문자열+대표영상 전폭카드/시각/후보구분이다. 원본은 날짜범위+3열연속그리드. 이는 영상이미지 fixture 차이가 아니라 실제 `_Section/_FeaturedCard` 구조 차이다. 배너도 원본보다안쪽padding20으로 일부텍스트/이미지가 다르다.

**파일:** `lib/features/my_cage/presentation/highlights_screen.dart`, `widgets/crecam_detail_top_bar.dart`. 기존 controller/groupByDay/publication 데이터 유지.

- [ ] 도착배너 x12/y118/w369,내부 원본padding·닫기24·겹친이미지·radius12를 specs로 맞춘다. 문자열/날짜14·500,제목18·600 등 실제노드값 사용.
- [ ] 섹션은3열그리드/연속썸네일/동일radius모음. 대표/후보의 재생순서·playFromSec는 유지하고 새 정보문구/큰카드를 끼워넣지 않는다.
- [ ] **날짜범위는 실제 publication.captureStart/end 등 근거가 있을 때만** 표시한다. 원본8/28~8/31을 앱에 고정하거나 알수없는batch를 합성하지 않는다. 실제서버group단위가1박이면 그 실제기간을 표시한다.
- [ ] 읽음은 실제재생진전으로만 처리. 단순카드노출/탭/목록수신을읽음으로바꾸지않는다. 닫은배너계정분리 유지.
- [ ] 테스트:대표/후보혼합·빈batch·publication없음·읽음/닫기·3열줄바꿈·자동다음은하이라이트만·날짜필터/숨김반영.

## 14. P13 — 북마크 목록·메모 메뉴

**근거:** `945:4351`, `1084:7291`; `app/widget-bookmarks.png`, `memo-six-colors.png`.

**차이:** 썸네일/메모180높이와112폭,6색은현재존재한다. 날짜헤더 크기/굵기·행간과 원본 메뉴형태·삭제붉은색을 다시 맞춰야 한다. PopupMenuItem은기본Material스타일이고 메모긴글은ClipRect여서원본말줄임과다를수있다.

**파일:** `bookmarks_screen.dart`, `widgets/clip_memo_card.dart`, `clip_memo_colors.dart`.

- [ ] 썸네일메모있음249/간격8/메모112,없음369,높이180/r12 유지. 날짜헤더·sectiongap은원본textstyle와같게. 현재16/600이원본과동일한지spec실측후수정.
- [ ] 메모메뉴는원본90폭/각행44·수정/삭제·삭제빨강·white/radius/anchor 위치. 북마크해제/영상삭제메뉴를추가하지 않는다.
- [ ] 긴메모는원본처럼말줄임하고내용을수정팝업에서끝까지볼수있게한다.6색순서·계정키·저장색정책변경금지.
- [ ] 테스트:메모0/짧음/긴글/6색·menuanchor·삭제후북마크남음·해제후메모남음·favoritedAt내림차순.

## 15. P14 — 플레이어 세로·가로·컨트롤 숨김

**근거:** `941:1834`, `941:1928`, `941:2062`; `app/widget-player-portrait/landscape/portrait-narrow.png`.

**차이:** 세로 하단동작은현재 메모→다운로드→공유→북마크이고원본은 다운로드→공유→메모→북마크. 가로는현재세로형헤더/하단pill을재사용하지만원본은영상위close·날짜pill·우측actions overlay다. “가로폭으로그려짐”만으로가로완료가아니다.

**파일:** `lib/features/my_cage/presentation/clip_playlist_player_screen.dart`, `widgets/clip_filmstrip.dart`, `camera_live_fullscreen_screen.dart`(공유영향확인).

- [ ] 세로하단action순서수정.44터치면·아이콘실그림·pill216×48/r24·좌우arrow48/strip위치를실측한다. FigmaIcons의36프레임이24그림을담는지확인한후size를정한다.
- [ ] 가로 전용Stack chrome 구성:영상중앙contain,좌상단닫기,상단날짜pill,우상단삭제/다운로드/공유/메모/북마크,하단seek/play/speed/expand/strip. safeinsets·노치별영역존중.
- [ ] 컨트롤숨김은동일VideoPlayerController/position유지. 탭/자동숨김으로표시전환,팝업/작업진행중에필수조작숨기지않는다. `941:2062`는영상만의숨김상태참고다.
- [ ] 영상R2삭제를만들지않고기존account별숨김유지.일반/북마크끝정지·하이라이트자동다음·seek·2x·재생목록추가로드를보존한다.
- [ ] 테스트:세로→가로→세로controller1개,시간보존,이전/다음경계,숨김현재clip제거후인덱스,notch/작은폭,하단strip스크럽·settle.

## 16. P15 — 메모 추가/수정 모달·저장 토스트

**근거:** `1081:6727/6803/6895/6962`; `app/memo-portrait/landscape.png`,실제showClipMemoEditor호출확인.

**차이:** 현재제목은‘메모’,원본은‘메모 추가’. 현재버튼기본색/disabled색은남색계열이며원본활성북마크저장은빨강. 빈메모캡처의비활성상태를원본입력있음활성상태와혼동하지말것. 모달단독캡처는배경영상/OS키보드를재현하지않았다.

**파일:** `widgets/clip_memo_editor.dart`, `clip_memo_providers.dart`, `clip_playlist_player_screen.dart`, `assets/l10n/ko.json`.

- [ ] 새메모‘메모 추가’,기존메모수정은이미합의된수정문구유지. 흰modal/r12/본문입력x간격·h130·좌우CTA/간격을원본metrics로맞춘다.
- [ ] 활성저장빨강,메모없이저장검정,전송중중복차단. 빈메모이더라도“메모없이저장”으로북마크가능해야 한다.
- [ ] 가로는키보드위viewport에모달전체를두고본문만스크롤한다.모달때문에가로orientation을강제세로로바꾸지않는다.
- [ ] “북마크에 저장되었습니다”아이콘토스트는원본white pill에맞춘다.메모단독수정성공을북마크신규저장성공으로잘못안내하지않는다.
- [ ] 테스트:추가/수정/빈값/실패/연속탭/계정변경/가로키보드/메모없이저장/로컬만쓰기.

## 17. P16 — 다운로드 대기/성공·기간 선택

**근거:** `1106:3584/3659`, 기간버튼이있는Highlight/Bookmark/Camera. 현재 `_save()`코드와 `app/widget-calendar.png`.

**차이:** 다운로드는현재Snackbar중/완료메시지+일부버튼비활성이고원본은흰mask/spinner/중앙‘영상 다운로드 중’및white완료토스트. 기간선택의완성된팝업원본은이번활성섹션에서찾지못했다. 앱은Material달력을사용하며QA렌더에서는헤더가‘202...’로잘린다. 이캡처는테스트화면의가로orientation설정영향가능성이있어네이티브재현전에앱결함으로단정하지않는다.

**파일:** `clip_playlist_player_screen.dart`, `lib/features/my_cage/presentation/widgets/crecam_detail_top_bar.dart`의 `showCrecamDayPicker`, 기간 설정 호출부 `highlights_screen.dart`·`bookmarks_screen.dart`·`crecam_screen.dart`.

- [ ] 다운로드진행overlay·성공토스트를원본대로하되실제진행율미제공이면percent를꾸미지않는다. 실패는별도실패상태/재시도,성공처럼완료토스트금지.
- [ ] 작업시작clipId고정·계정변경·화면이탈을검증.스크린차단과뒤로가기허용범위를명시하고파일중복저장을막는다.
- [ ] Camera기본전체기간/달력기존필터의미보존.날짜선택은시스템/앱달력원본미확보로‘Figma완전일치’판정에서제외,잘림/다크톤/날짜범위/취소보존을네이티브확인한다.
- [ ] 테스트:downloadpending/success/failure/권한거절,기간전체/하루/없음,취소시기존필터,미래차단,자정타임존.

## 18. P17 — 자산·그림자·새 컨트롤 상태

**근거:** `1107:10445`, `1056:2944`, LCD원본과전체specs.

- [ ] 드롭다운은이미승인된너비/행/선택label보존,원본effect값을읽을수있는경로로shadow만확인한다. 현재MCP의node정보에effects누락이있어PNG만보고정확한blur/spread를지어내지않는다.
- [ ] LCDillustration·새예약up/down·toggle·minus/plus·모프clearX·lock·progress·emptyplus를기존자산manifest와대응. 원본node→원본SVG/PNG→runtime경로→소비처→프레임/실그림크기를표로갱신한다.
- [ ] 기존체크300/400은유지. 새예약삭제모드체크는원본픽셀/벡터를기준으로분류하고파일명만으로결정하지않는다.
- [ ] 여러역할색이들어간SVG전체tint로흰내부그림이사라지는지P07와함께검증한다.

## 19. P18 — 승인 화면 회귀·구형 경로·평균 안건

**근거:** 01~29 REVIEW_STATUS, `990:11607`(기기관리 재참고), `1081:6397`(개체폼 재참고), 실제라우터.

- [ ] **발견된실패:** `test/design/redesign_camera_pet_capture_test.dart:526`은편집SVG프레임24×24를기대하지만실제36×36이다.26번에서승인한photo badge36/내부그림18 변경후테스트기대값이낡은것으로확인된다. 코드를24로되돌리지말고frame/내부그림을분리검증하도록테스트수정. 이실패를큰종이름레이아웃실패라고보고하지않는다.
- [ ] 실제라우트 `/my-pets/:petId`는 `PetDetailScreen`을반환하며하드코딩‘개체 삭제’·`을(를)`구형AlertDialog가남아있다.진입메뉴/딥링크를추적하고살아있으면23번공통확인창으로맞춘다.기존체중/이벤트/갤러리데이터를없애기위해구형화면을삭제하지않는다.
- [ ] 01~29의플로팅CTA/에러문구/숫자라벨/아이콘배열/모프초기화제거를회귀검증한다.커밋별before/after가이번수정범위밖에없어야한다.
- [ ] **UI 검수 종료 후 사용자에게 반드시 다시 논의:** ‘주간 평균 활동 시간’/일평균은관측완료coverage가없어서`--`일수있다.사용자가검수후다시논의하자고명시했다. 지금임의평균·실측추정·서버변경금지. petcam-lab의실제coverage응답/배포확인과앱완료일판정계약을별도결정안으로돌려준다.

## 20. 검증·커밋·반환 계약

각 작업의 체크리스트에 실제수행결과/캡처파일/테스트명/커밋을기록한다.본계획의읽기만으로체크완료표시하지않는다.

```bash
cd /Users/baek/myProjects/tera-ai-flutter/.worktrees/redesign-20260915
git status --short
git diff --stat
/Users/baek/develop/flutter/bin/flutter test --no-pub test/features/my_pets/pet_morph_selection_test.dart test/features/my_pets/pet_registration_catalog_test.dart
/Users/baek/develop/flutter/bin/flutter test --no-pub test/features/my_cage/device_add_flow_screen_test.dart test/features/my_cage/pairing_pet_selection_screen_test.dart
/Users/baek/develop/flutter/bin/flutter analyze --no-pub
git diff --check
```

위 명령은관련묶음예시다.예약·영상묶음수정시기존해당테스트와새회귀를함께실행한다.코드변경후에는프로젝트버전/CHANGELOG규칙을따른다.이전 기록의 정적 분석 기준은 오류 0/경고 0, info 6개다. 이번 문서 작업에서는 분석을 재실행하지 않았으므로 구현 후 새 결과를 기록한다.분석과빌드통과를픽셀검수완료의대체로쓰지않는다.

**새 테스트의 최소 형태:** 현재 widget-test fixture/provider overrides를재사용해 실제위젯을검증한다.아래같이레이아웃외의효과를검증하며UI를테스트에다시구현하지않는다.
```dart
// 모프 선택 화면이 열려 있는 기존 fixture에서
await tester.enterText(find.byType(TextField), '없는모프검색');
await tester.pumpAndSettle();
expect(find.text('일치하는 모프가 없습니다'), findsOneWidget);
// 선택하지 않고 뒤로가기했을때 기존선택이그대로인지 parent field까지 확인한다.
```

**비교 프로토콜:**

1. 기준393×852/SafeArea상62하34,세로긴본문은추가스크롤캡처,가로852×393.원본이889/1084/1603인프레임은뷰포트와긴콘텐츠높이를구분한다.
2. 각 작업: 원본/수정전/수정후PNG와노드경계/서체/색/아이콘실그림/CTA테이블.텍스트2px차이도데이터차이와분리해원인기록.
3. iOS simulator 실제키보드/스크롤/회전/사진permission,Android상단흰색/키보드back/edge-to-edge를별도검증. 접근불가면미검증이라고표시한다.
4. partial UI fixture에서SVG가아직로드되지않았으면precache후재촬영.값/영상이mock이라는이유로실제기기UI완료라고쓰지않는다.
5. 로컬커밋단위분리.푸시·운영반영은추가사용자지시없으면하지않는다.

**Claude가 돌려줄 것:**

- `RESULTS.md`: P01~P18 각각수정완료/기존유지/결정대기/검증불가와구체적이유.
- 수정커밋목록,변경파일요약,테스트/분석/빌드결과,이전실패처리.
- 같은크기원본/after 비교HTML,개별PNG,측정JSON.뷰어에그레이영상이fixture임을명시.
- P11결정안,남은자산/그림자/OS검수,평균안건을한곳에모아서사용자에게반환.
- ‘전체완료’라는표현은모든필수검증과결정이실제로끝났을때만사용.
