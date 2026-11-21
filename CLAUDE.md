# 비바나트 — Claude Code 행동 규칙

파충류 사육자를 위한 앱. 사육장 IoT 제어, 카메라 라이브·영상, 개체 관리, 커뮤니티. 백엔드는 Supabase + terra-server(기기·카메라·라이브 신호) + petcam-lab(영상 판정·하이라이트).
스택: Flutter + Riverpod + GoRouter + Hive + easy_localization + Supabase + flutter_blue_plus(BLE) + flutter_webrtc + video_player + fl_chart.

이 파일에는 파일을 열기 전에 알아야 하는 것만 둔다. 기능별 규칙은 `.claude/rules/*.md`(해당 파일을 열 때 실린다), 경위·수치·날짜는 `docs/contracts/`에 있다.

## 이름 (2026-08-10 확정)

| 용도 | 값 |
|---|---|
| 한글 표시명 | **비바나트** |
| 영문 | **vivanaut** (2026-09-14 사용자 직접 결정 = SOT) |
| Dart 패키지 | `vivanaut` |
| 번들 ID (iOS·Android 공통) | `com.vivanaut.app` |

> ⚠️ **철자를 추측하지 말 것.** 한때 `vivnanaut`·`vivananunt`(오타)·`vivanart`(구 문서명)가 섞여 있었다. 영문명·패키지·번들 ID의 유일한 근거는 2026-09-14 사용자 직접 결정 `vivanaut`이다. Figma URL의 `/vivnanaut` 경로는 외부 원본의 과거 파일명으로 보존한다.
> 번들 ID는 스토어 출시 후 변경 불가 — 출시 전에만 손댈 수 있다.
> 아직 옛 브랜드가 남은 곳: 앱 아이콘, 저장소명 `tera-ai-flutter`, git 원격.

## 기획·디자인 기준

- **우선순위(2026-11-21 사용자 결정): 늦은 결정이 우선한다.** 2026-09-15 뒤에 날짜와 함께 적힌 사용자 개별 결정(이 파일·`.claude/rules/`·`docs/contracts/`) > 2026-09-15 Figma 재설계 확정 기획(`docs/superpowers/specs/2026-09-15-figma-redesign-approved-design.md`) > 2026-09-14 Final Design 결정(`docs/contracts/clips-highlights.md`의 같은 이름 절) > 그 이전 결정과 PRD `docs/prd-vivanaut-app.md`(2026-08-08). 구현이 이 기획 문서들과 다르면 기획이 맞다. `docs/contracts/`는 구현 경위 기록이라, 코드와 다르면 어느 쪽이 낡았는지 확인한다(그 안의 사용자 결정 문장은 코드보다 우선).
- 디자인 수치의 원본은 Figma다: https://www.figma.com/design/EMAYOZxHOyeDLZdIahvDkL/vivnanaut?node-id=0-1 — **talk-to-figma MCP로만 접근**한다(다른 Figma MCP로 대체하지 않는다). 소켓 서버(`bunx cursor-talk-to-figma-socket`)는 세션마다 수동 기동. 전사본 `docs/figma-final-design-transcript.md`.
- 기획 원문(Notion): https://app.notion.com/p/3ab16a5cfa948082864ec59be6b6f532?source=copy_link — 브라우저로 바로 열린다(로그인·MCP 인증 불필요).
- 기획 ↔ 구현 대조표: `docs/prd-implementation-gap.md`. `docs/spec.md`(5탭 시절)와 `docs/archive-prd-transcript-and-decisions.md`는 구 문서라 신규 작업의 근거로 쓰지 않는다.
- 미결(사용자 지시까지 보류): 히터 켜기 진입점. 다크모드는 현행 유지.

## 명령

```bash
flutter analyze                      # 에러 0 유지 — 코드 수정 뒤 필수
flutter test
flutter build apk --debug            # Claude Code 안에서 직접 실행 가능
tools/worktree.sh new <type>/<이름>  # 최신 main에서 ../tera-ai-flutter-<이름> 작업 공간 (.env 링크·pub get 자동)
tools/worktree.sh finish <branch>    # main 병합·push·작업 공간 정리
tools/worktree.sh list
tools/testflight.sh [--dry-run]      # iOS 베타 업로드 — 스킬 `testflight`, 사용자가 요청했을 때만
```

- TestFlight 빌드는 팀 `XYNNB47RN3`·번들 `com.vivanaut.beta`로만 바꿔 올린다. **이 두 값을 main의 `project.pbxproj`에 넣지 않는다**(`com.vivanaut.app`은 법인 팀용). 계정 현황 `docs/ops/apple-developer-account.md`.

## 브랜치·작업 공간

- **main이 유일한 기준이다**(재설계 `81a5f25` 병합, 2026-09-18 사고 후 확정). 새 브랜치·worktree는 반드시 현재 main에서 만들고, 끝나면 바로 main에 병합·삭제한다. 화면 확인은 main 빌드로 한다.
- 한 폴더를 여러 세션이 공유하지 않는다. 세션마다 `tools/worktree.sh new`로 작업 공간을 만들고, 메인 폴더(`tera-ai-flutter`)는 main 확인·병합용으로 비워 둔다.
- `tools/git-hooks/pre-push`가 막는 것: `81a5f25`를 포함하지 않는 브랜치, 빌드번호 역행, `lib/`를 바꾸고 버전을 안 올린 push.
- `test/regression/redesign_baseline_guard_test.dart`가 재설계 핵심 파일·표지를 감시한다. 화면을 의도적으로 바꿀 땐 목록을 고치되 **지워서 우회하지 않는다.**
- 버전 충돌: 다른 세션이 먼저 병합해 `pubspec.yaml` 버전·`CHANGELOG.md`가 충돌하면, 병합 직전에 main을 받아 main보다 한 칸 위 버전으로 다시 올리고 CHANGELOG 두 항목을 모두 살린다.
- 사고 경위·보관 태그(`archive/*`, `stable/redesign-2026-09-18`)는 `tools/git-hooks/README.md`. Clarity 분석은 사용자 결정으로 꺼 둔 상태다 — 재개 방법 `docs/clarity-policy.md`(옛 정책 커밋을 cherry-pick하지 않는다).

## 커밋·버전·push

- **작업 단위마다 커밋한다. 커밋 여부를 묻지 않는다.** 논리적으로 완결된 변경 하나 = 커밋 하나. 관심사가 다른 변경을 섞지 않는다. 전면 교체·구조 변경은 그 파일만 단독 커밋한다.
- 커밋 전 `flutter analyze` 에러 0 + 관련 테스트 통과. 깨진 상태를 커밋하지 않는다.
- `lib/` 변경이 있으면 `pubspec.yaml` 버전을 올린다(fix→patch / feat→minor / breaking→major, build+1).
- **push(2026-11-21 사용자 결정): 커밋한 작업 브랜치는 묻지 않고 push하고, 작업이 끝나 검증(analyze 0·관련 테스트)을 마치면 묻지 않고 `tools/worktree.sh finish`로 main 병합·push까지 한다.** force push와 내 작업 브랜치가 아닌 브랜치 push만 먼저 묻는다. 실기기 확인이나 `/code-review`가 남았으면 보고에 적는다.
- **패치노트**: 앱 동작·UI·데이터 구조·서버 계약·빌드·배포 설정에 영향을 주는 변경은 구현·버전과 같은 커밋에서 루트 `CHANGELOG.md`에 한글로 적는다. 필요한 패치노트가 빠진 변경은 완료로 보지 않는다(최신이 위, `버전 + 날짜`, 추가/변경/수정/제거/보안 중 해당 분류만). 사용자·운영자가 이해할 결과 중심으로 쓰고, 배포되지 않은 계획을 완료처럼 적지 않는다. 다른 에이전트의 항목을 지우거나 덮어쓰지 않고, 같은 릴리스면 그 버전 항목에 덧붙인다. 과거 항목은 오탈자·사실 정정 외에는 고치지 않고, 정정할 때는 이유를 추적할 수 있게 남긴다. 순수 계획서·내부 메모만 바꾼 경우는 제외.

## 구조

```
lib/
├── main.dart · app.dart
├── core/      analytics · config(feature_flags, env_config) · constants · network · router · storage · supabase · theme
├── features/  app_update · auth · community · dev · error · home · my_cage · my_pets · notification · profile · splash · wiki(라우트 폐기, 데이터 계층만 사용)
│   └── {feature}/ data(Repository) · domain(모델) · presentation(Screen·Widget·Provider)
└── shared/    domain · providers · services · widgets
문자열: assets/l10n/ko.json (easy_localization)
```

- 4탭(홈/카메라/마이크레/커뮤니티) `StatefulShellRoute`. 탭 테이블은 `core/router/tab_branches.dart`, 조립은 `core/router/app_router.dart`이고 **라우트의 SOT는 이 파일**이다(새 화면은 여기에 등록). `/crecam/cameras/...`처럼 셸 밖 최상위 경로에는 독이 뜨지 않는다.
- `my_cage`가 사육장 기기·카메라·영상·페어링을 모두 담는다. 홈 제어는 `home`, 공용 차트·제어 기록 도메인은 `shared/domain`.
- 2026-11 시점의 화면·라우트 설명은 `docs/architecture/routes-and-features.md`(스냅샷, 갱신하지 않음).

## 코딩 규칙

### 상태 관리
- **앱·서버 상태는 Riverpod만 쓴다.** 한 위젯 안에서만 쓰는 UI 상태(시트 안 선택, 입력 중 값, 애니메이션)는 `setState`를 써도 된다. `ChangeNotifier`는 GoRouter 갱신 같은 프레임워크 접점에만 쓴다(2026-11-21 사용자 결정).
- 위젯에서 `ref.watch`는 build 안에서만, `ref.read`는 콜백/이벤트에서. Provider는 각 feature의 `presentation/`에 둔다.
- **인증 의존 Provider stale 방지**: 유저 데이터를 fetch하는 non-autoDispose provider는 반드시 `ref.watch(currentUserProvider.select((u) => u?.id))`로 계정 id만 감시한다. User 객체 전체를 watch하면 무관한 필드(updatedAt 등) 변경에도 재build가 발생한다.
  - **3층 계정 격리**: ① provider에서 userId select-watch → ② 위젯에서 `_initializedForId` 가드(캐시된 위젯의 중복 init 방지) → ③ 로그아웃 시 Hive 로컬 캐시 clear(타 계정 데이터 프라이버시). 상세: 메모리 `project_auth_provider_stale_pattern`
  - 비동기 콜백에서 `mounted` 확인 없이 `state=`/`ref.read`/setState 호출 금지.

### 데이터 접근
- **Repository 패턴 필수.** Widget에서 Hive·Supabase에 직접 접근하지 않는다.
- 테이블·RLS·접속 정보는 `docs/supabase-setup.md`, DDL은 `docs/supabase-schema.md`.
- **운영 DB는 사용자 승인 없이 바꾸지 않는다**(마이그레이션 적용 포함). 검토 전 SQL 초안은 `supabase/drafts/`에 두고 격리 DB에서 검증한다. 적용할 마이그레이션은 `supabase/migrations/`. RLS로 막은 테이블을 읽는 운영자용 조회 view는 public 스키마에 두지 않는다(RLS 우회 누출 — PostgREST 비노출 스키마 `ops.*`에 둔다. `public_profiles`처럼 공개가 목적인 view는 예외).
- 서버·펌웨어 배포가 필요한 기능은 "UI 구현 완료"와 "운영에서 사용 가능"을 구분해 보고한다.
- 파충류 사육 수치(온도·습도·먹이)는 생명과 직결된다. 데이터를 고칠 때는 출처를 확인하고, 온습도·안심존·목표값에 임의 수치나 기본값을 채우지 않는다.

### UI
- **하드코딩 색상 금지** — `context.glass`/`Theme.of(context)` 역할색을 쓴다. **하드코딩 문자열 금지** — `assets/l10n/ko.json`에 키를 추가한 뒤 `'key'.tr()`.
- Primary `#192553`(`AppTheme.brandNavy`, 구 Green 800은 2026-08-08 폐기), 다크는 `brandNavyDark`(#768ad6 — Figma에 다크 팔레트가 없어 도출한 값). 의미색 `AppTheme.success`/`warning`(#FF8F00, Figma 미정의)/`danger`. 브랜드 빨강 `#D61619`는 온도 최고값·경보.
- 폰트 Pretendard. 간격은 `AppStyles.spacingN`, 태그는 `AppTag`, 섹션 제목은 `SectionHeader`.
- 글자 크기는 Figma 그대로다(`AppTextScaler` = 1.0 × 휴대폰 설정, 최대 2.0). **고정 `TextScaler.linear(…)`로 덮지 않는다**(접근성 설정 무시).
- 화면 꺼짐 방지는 보는 중일 때만 건다. 새 영상 플레이어는 `KeepScreenOnWhilePlaying`으로 감싸고, **`KeepScreenOn`을 라우트(탭) 단위로 감싸지 않는다.** 커뮤니티 피드 자동 재생은 감싸지 않는다(사용자 결정).
- 공용 입력은 `VivaTextField`/`VivaCheckRow`, 확인 모달은 `showVivaModal`을 쓴다. 새 주요 화면은 `test/design/text_scale_overflow_test.dart`에 추가한다.
- 오프라인 안내는 화면을 덮지 않는 상단 `OfflineBanner`다. **전체 차단 오버레이를 되살리지 않는다.** 서버 작업 실패는 작업별로 알린다.
- 로딩은 `shimmer` 스켈레톤으로 그린다. **`CircularProgressIndicator` 금지.**
- Figma에 맞출 때는 눈대중이 아니라 수치로 대조한다(`.claude/rules/figma-review.md`).


## 파일을 열기 전에 알아야 하는 함정

- **⚠️ 제어는 toggle이 아니라 절대 상태 명령을 쓴다**(`fan_on/off`·`heater_on/off`·`relay_on/off`). 계약서 `APP_INTEGRATION.md §3.2` 표에는 toggle만 적혀 있지만 절대 명령은 펌웨어에 처음부터 있었다. 뒤집기는 기기의 현재 상태를 전제하는데, 그 전제가 어긋나면 끄려던 조작이 켠다. 히터에서는 과열=폐사다.
- **⚠️ 사육장 제어 명령은 반드시 `home/presentation/cage_control_actions.dart`를 경유한다.** 히터 2단 안전확인이 거기 있다. 진입점은 홈 `CageControlGrid`이고, 새 진입점을 만들더라도 이 모듈을 거친다(구 사육장 탭 `/smart-cage`의 `ActuatorControls`는 이 모듈 이전의 옛 진입점으로 남아 있다 — 팬·분무·LED 절대 명령만 보낸다). **히터 켜기 진입점은 사용자 지시가 있을 때까지 만들지 않는다.**
- **⚠️ 새 명령을 추가하면 `shared/domain/actuator_marker.dart`의 `_kindByAction`과 `shared/domain/control_log.dart`의 `_entryByAction`을 같이 고친다.** 안 하면 그 동작만 차트(마커)와 제어 기록에서 에러 없이 조용히 사라진다.
- **하루 경계 셋을 섞지 않는다**(PRD §3.1): 활동·클립 귀속 = 07:00~익일 07:00(`DayWindow`) / 밤 집계 = 22~06시 / 온습도 하루 = 자정~자정(`EnvDay`).
- **기기를 재등록하면 서버가 새 행을 만든다**(사육장 새 `device_id`, 카메라 새 `camera_id`). 이름·그룹·예약·기록이 끊긴다. Wi-Fi만 바꿀 때는 등록을 유지하는 경로(`/devices/network`)를 쓴다. 예외: `superseded_at`이 찍힌 카메라는 새로 등록하면 같은 행을 돌려받는다.
- **`camerasProvider`에 heartbeat(`clip_stats`)·라이브 세션처럼 자주 바뀌는 값을 넣지 않는다.** 생존 신호만 바뀐 갱신을 일부러 버리는 곳이라, 넣으면 홈이 깜빡인다.

## 서버 쓰기 경로

| 대상 | 경로 | 주의 |
|---|---|---|
| 사육장 제어 명령 | `commands` 직결 INSERT(`cage_control_actions.dart` 경유) | 절대 명령만. 분무는 `duration_ms`만 보내고 OFF는 보내지 않는다 |
| 예약 | REST만(`schedule_repository.dart`) | 직결 INSERT는 RLS를 통과하지만 `next_run_at`이 없어 영영 안 돈다 |
| 목표 온습도 | REST `device_settings` | 미설정에 임의 기본값을 채우지 않는다 |
| 온도 보정 | REST `POST /devices/{id}/commands`, `user_offset_c`만 | 기기별 공장 기준을 앱에서 가정하지 않는다 |
| LCD 문구 | REST `/devices/{id}/lcd` | 64자 상한 |
| 카메라 회전 | REST `PATCH /cameras/{id}` `{rotate_180}` | 직결 UPDATE 금지(서버가 MQTT `set_rotation`을 발행). 적용은 재부팅 후 약 20초 |
| 재시작 | REST `POST /cameras/{id}/reboot`, `POST /devices/{uuid}/reboot` | 사육장은 `commands` 행의 `status`가 아니라 `result == ok`만 성공 |
| 라이브 연결·시청 기록 | `webrtc_connect_logs`·`webrtc_view_logs` 직결 INSERT | `.select()` 금지(SELECT 정책이 없어 RETURNING이 RLS 위반) |

표에 없는 쓰기는 해당 repository의 주석을 따른다. 새 쓰기 경로를 만들 때는 REST(서버가 부수 동작을 책임지는 것)인지 직결인지 먼저 확인한다.

## 문서 색인

| 주제 | 경위·수치 | 규칙(해당 파일을 열 때 실림) |
|---|---|---|
| 사육장 제어(확인 대기·분무·LED·팬 타이머·예약) | `docs/contracts/cage-control.md` | `.claude/rules/cage-control.md` |
| 온습도 표시·보정·목표값 | `docs/contracts/env-telemetry.md` | `.claude/rules/env-telemetry.md` |
| 카메라 라이브·시청 제한 | `docs/contracts/camera-live.md`, `camera-live-limit.md` | `.claude/rules/camera-live.md` |
| 재시작·Wi-Fi 약함·카메라 회전 | `docs/contracts/device-health.md`, `camera-rotate.md` | `.claude/rules/device-health.md` |
| 기기 등록·Wi-Fi(BLE) | `docs/ble-provisioning-protocol.md` | `.claude/rules/pairing-wifi.md` |
| 영상 목록·플레이어·하이라이트 | `docs/contracts/clips-highlights.md` | `.claude/rules/clips-highlights.md` |
| 알림 권한 | `docs/contracts/push-consent.md` | `.claude/rules/push-consent.md` |
| 색·글자·공용 위젯 | `docs/design-system-viva-colors.md`, `docs/design-direction.md`, `docs/contracts/ui-common.md` | `.claude/rules/theme-ui.md` |
| Figma 대조 검수 | — | `.claude/rules/figma-review.md` |

**규칙 파일은 그 경로의 파일을 열 때만 실린다.** Standard 이상 작업의 분석서를 쓰기 전에, 그리고 새 파일을 만들거나 Grep만으로 설계할 때는 위 표에서 관련 규칙 파일을 직접 읽는다.

- 사육장 IoT 통합 계약(terra-server): `~/Downloads/APP_INTEGRATION.md`(레포 밖). §3.2 표는 toggle만 적혀 있어 불완전하다.
- 서버·펌웨어 인계와 회신: `docs/handoffs/README.md`(진행 중 색인), `docs/references/`(원문). 2026-09-07 이전에 지운 핸드오프는 `git log --diff-filter=D -- docs/`.
- 그 밖: `docs/flutter-cloud-migration-plan.md`(Phase C/D), Storage 파일 복사 우회는 메모리 `project_supabase_storage_edge_workaround`.
- 코드 주석이 가리키는 옛 절 이름: "CLAUDE.md LED 규칙"·"분무 항목"은 `.claude/rules/cage-control.md`, "공통 하단 CTA"는 `.claude/rules/figma-review.md`로 옮겼다.

## CAOF

- 트랙 규칙은 글로벌 `~/.claude/CLAUDE.md`, 이 프로젝트의 라우팅·사례는 `.claude/rules/vivanaut-caof.md`를 따른다.
- 역할: Designer = 메인 Claude, Implementer = `flutter-dev`(Critical에서만 투입, 모델은 상속). Standard는 메인이 겸임한다.
- 사용자가 "CAOF 끄기"라고 하면 그 세션에서 끈다.

## 패키지·금지

- 신규 패키지 설치와 버전 조정은 Claude 재량이다(사전 승인 불필요, 2026-07-08). 유지보수되는 패키지를 고르고, 기존 기능과 중복 도입을 피하고, 커밋·보고에 무엇을 왜 넣었는지 적고, dependency solving 충돌은 원인과 선택을 남긴다. 선호: HTTP는 `http`, 로컬 저장은 Hive(필요하면 flutter_secure_storage).
- onboarding은 기획 확정 전 구현하지 않는다.
