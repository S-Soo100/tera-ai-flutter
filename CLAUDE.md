# 비바나트 — Claude Code 행동 규칙

## 이름 (2026-08-10 확정)

| 용도 | 값 |
|---|---|
| 한글 표시명 | **비바나트** |
| 영문 | **vivnanaut** (Figma 파일명 기준 = SOT) |
| Dart 패키지 | `vivnanaut` |
| 번들 ID (iOS·Android 공통) | `com.vivnanaut.app` |

> ⚠️ **철자를 추측하지 말 것.** 한때 `vivananunt`(오타)·`vivanart`(구 문서명)가 섞여 있었고, 번들 ID까지 오타로 들어갔다가 되돌렸다. **Figma 파일명 `vivnanaut`이 유일한 근거다.**
> 번들 ID는 스토어 출시 후 변경 불가 — 출시 전에만 손댈 수 있다.
>
> 아직 옛 브랜드가 남은 곳: `assets/images/logo_wordmark.png`(영상 워터마크에 `terra.ai`), 앱 아이콘, 저장소명 `tera-ai-flutter`, git 원격.

## 프로젝트 개요
파충류 사육자를 위한 올인원 앱. 백색목록 검색, 사육 정보, 모프 유전 계산기 + 게코캠 + 사육장 IoT 제어.
- **스택**: Flutter + Riverpod + GoRouter + Hive + easy_localization + Supabase + flutter_blue_plus/permission_handler(BLE) + flutter_webrtc(사육장 캠 라이브) + video_player/gal/share_plus(크레캠 영상 재생·기기저장·공유) + fl_chart(홈·통계 공용 온습도 차트)
- **현재 상태(2026-08-09)**: P2 상당 구현 — Supabase 인증/유저 CRUD + **terra-server 사육장 IoT 실연동**(디바이스/명령/온습도 Realtime + BLE) + **크레캠 영상 개편**(motion_clips 썸네일·저장/공유·즐겨찾기 클라우드·AI분류칩·시크) + **어젯밤 리포트**(마이 크레 탭). **PRD 재설계(`feat/prd-redesign`) — 2026-09-02 전면 개정 + 1단계 구현 완료**: 4탭 IA(홈/카메라/마이크레/커뮤니티, 통계 탭 폐지), 홈 단일 스크롤, 온습도 상세(`/env-detail`), Asset 팔레트 교체, 위키·검색 폐기. 2단계(카메라 탭 재설계)는 미착수. 챗·지식그래프·종비교는 폐기(D3).
  - (P0 "로컬 전용/인증 없음/백엔드 없음"은 초기 설계 — 더 이상 유효하지 않음. 신규 작업은 아래 Phase 경계/CAOF 규칙을 따른다.)
- **기획안 (현행 SOT)**: `docs/prd-vivnanaut-app.md` — **2026-08-08 전면 재작성.** 기존 구현을 전제하지 않고 노션 기획서·PRD만으로 정리한 기획안이다. **구현이 기획안과 다르면 기획안이 맞다.**
  - **기획 ↔ 구현 대조표**: `docs/prd-implementation-gap.md` — 어디가 맞고 어디가 비었는지. 기획안 본문은 구현을 안 다루므로(§0.2) 대조는 이 문서가 맡는다
  - 원문 전사본 + 구 결정 로그 D1~D6: `docs/archive-prd-transcript-and-decisions.md` (보관용, **신규 작업의 근거로 쓰지 말 것**)
  - `docs/spec.md`는 구 기획서(5탭 시절) 열람용.
- **기획 원문 (Notion)**: https://app.notion.com/p/3ab16a5cfa948082864ec59be6b6f532?source=copy_link — **브라우저로 바로 열린다(로그인 불필요).** Notion MCP 인증을 기다릴 필요 없음
- **디자인 원본 (Figma)**: https://www.figma.com/design/EMAYOZxHOyeDLZdIahvDkL/vivnanaut?node-id=0-1 — **talk-to-figma MCP로만 접근**(설치·등록 완료). 다른 Figma MCP로 대체하지 않는다. 소켓 서버(`bunx cursor-talk-to-figma-socket`)는 **세션마다 수동 기동** 필요. 전사본: `docs/figma-final-design-transcript.md`
- **자진신고**: ~~2026-06-13 기한~~ — **기한 경과 + 기능 제거됨**(`cbdad94`에서 자진신고 탭 → 내 사육장으로 교체). 코드·ko.json에 잔재 없음. 신규 작업에서 이 기능을 전제하지 말 것.

### Supabase / 백엔드 관련 문서
- **DB 스키마 (DDL 원본)**: `docs/supabase-schema.md` (메인 15개 + terra-server IoT 테이블)
- **연동 현황 (접속 정보/RLS/시드/Flutter 코드 예시)**: `docs/supabase-setup.md`
- **사육장 IoT 통합 (단일 진실 소스)**: `~/Downloads/APP_INTEGRATION.md` (terra-server) — 디바이스 제어/텔레메트리/BLE 페어링 계약
- **백엔드 핸드오프 2026-08-14 (신규 계약 요약)**: `docs/backend-handoff-2026-08-14-summary.md` — 팬 타이머·예약 guard·구간 on/off·LCD·commands 출처 컬럼. 앱 반영 계획: `docs/plans/2026-08-14-backend-handoff-fan-timer-guard-lcd.md`
- **백엔드 핸드오프 2026-08-18 → 회신·반영 완료**: 요청 `docs/backend-handoff-2026-08-18-webrtc-keyframe-and-contracts.md`, 회신 `docs/backend-reply-2026-08-18-app-delivery.md` — `devices.capabilities`·`device_settings` REST·`schedules.pair_id`·`telemetry.led`·예약 toggle/off+guard 400은 **앱 반영 완료**(v0.64.0). 카메라 첫 프레임(IDR)은 esp_video 2.2.0이 force-key-frame 미지원이라 **하드웨어 담당 결정 대기**(앱 변경 없음)
- **BLE Wi-Fi 프로비저닝 (사육장·카메라 단일 진실 소스)**: `docs/ble-provisioning-protocol.md` — `terra-iot`/`FB2_P4_CAM` 공통 GATT·명령·응답 + 페어링 결정((a): 앱은 WiFi만, 토큰/DB 사전 세팅)
- **클라우드 마이그레이션/UI 개편 (Phase C/D)**: `docs/flutter-cloud-migration-plan.md`
- **Storage 파일 복사 우회 (MCP·service_role 제약)**: 메모리 `project_supabase_storage_edge_workaround` — edge function으로 `storage.copy`, 경로 `pet-media/{user_id}/pets/{pet_id}.png`

## Phase 로드맵

| Phase | 범위 | 상태 |
|-------|------|------|
| P0 | 로컬 데이터, 검색/상세/모프계산기/가이드, 3탭 | ✅ 완료 |
| P1 | OnboardingScreen, ProfileScreen(내 사육장), 로컬 알림(D-day 리마인더), en 다국어, Pretendard 폰트 | 부분 (알림/en 미완) |
| P2 | Supabase 도입, 인증(이메일+소셜), 클라우드 동기화, FCM 푸시, 거래 기록 | 상당 구현 (Email 인증·유저 CRUD 완료, 소셜/FCM 후속) |
| C/D | 게코캠 클라우드 마이그레이션(petcam-lab) + 5탭 UI 개편 + **사육장 IoT(terra-server)** | 진행 중 — `docs/flutter-cloud-migration-plan.md` |
| PRD 재설계 | 비바나트 4탭 IA — 홈·통계 구현, 컬러 시스템 교체 | ⚠️ **2026-08-08 기획 리셋.** 구현 디자인이 기획 의도를 못 맞춰 기획안을 새로 썼다(`docs/prd-vivnanaut-app.md`). 기존 구현은 **재검토 대상**이고, 신규 작업은 새 기획안을 따른다. **1:N은 1:1로 확정**(§1.3). **활동 집계는 밤 22:00~06:00, 날짜 경계는 07:00**(§3.1). **클립 재생은 전체화면 가로**(§6-B, 2026-08-09). 남은 미결: 통계 탭 확정(§6-D), 캠 보면서 제어 재설계(§6-N), 계정 화면 진입점(§6-O). **큰 공백: §4.2 타이머&일정이 통째로 미구현** — 대조표 `docs/prd-implementation-gap.md` |

## 아키텍처

```
lib/
├── main.dart                    # 앱 진입점 (Hive init, EasyLocalization, ProviderScope)
├── app.dart                     # MaterialApp.router, 테마, GoRouter
├── core/
│   ├── constants/               # AppConstants (색상, 문자열, D-day 날짜)
│   ├── theme/                   # AppTheme + GlassPalette(다크/라이트 2벌) + themeModeProvider
│   ├── router/                  # GoRouter 설정, 리다이렉트
│   └── error/                   # AppException 계층
├── features/
│   ├── {feature}/
│   │   ├── data/                # Repository 구현 (로컬 데이터)
│   │   ├── domain/              # 모델 클래스
│   │   └── presentation/        # Screen, Widget, Provider
│   ├── auth/                    # placeholder (P2용)
│   ├── onboarding/              # placeholder (P1용)
│   ├── profile/                 # placeholder (P1용)
│   └── notification/            # placeholder (P2용)
├── shared/
│   ├── widgets/                 # 공통 위젯 (LegalBadge 등)
│   └── providers/               # 공통 프로바이더
└── l10n/ → assets/l10n/ko.json  # easy_localization
```

### 핵심 feature

**4탭** BottomNav(`StatefulShellRoute`) + 보조 라우트 구조. 탭 테이블은 `core/router/tab_branches.dart`(`kHomeTabPaths`), 조립은 `core/router/app_router.dart` 중앙 관리.
**2026-09-02 PRD 전면 개정 1단계 구현 완료** — 탭 = 홈/**카메라**/마이크레/커뮤니티(라벨 영문 Home/Camera/MyCre/Community). **통계 탭 폐지**(`/stats` 라우트 제거 — 온습도 시각화는 `/env-detail`로 흡수), `/crecam`은 **탭2로 승격**(하위 `cameras/...` 경로는 셸 밖 최상위 유지 — 페어링·상세에 독 안 뜸), **`/wiki`·`/search` 라우트 폐기**(care_info_repository 등 data 계층은 공용 인프라라 존치). 계획서: `docs/plans/2026-09-02-prd-redesign-phase1-home.md`.

| 탭/라우트 | feature | 화면 | 데이터 소스 |
|-----------|---------|------|------------|
| `/home` (탭1) | home | HomeScreen — **단일 스크롤**(2026-09-02): 헤더(세트 드롭다운/`[+]` 추가 메뉴/`[사람]`=계정) + 라이브(`TopFixedArea`) + 온습도 요약 카드(`EnvSummaryCard`, 탭→`/env-detail`) + 제어 그리드(`CageControlGrid` 5타일 — 냉각팬·히터팬은 API 없어 미배선 "준비 중") + 일정 설정. 서브탭·타임라인·개체 프로필 분기 폐기 | 사육장 세트(`EnclosureSet`) + `homeTodayExtremesProvider`(오늘 자정~) |
| `/crecam` (탭2, Camera) | my_cage | CrecamScreen(구 화면 그대로 — **Figma Camera 섹션 재설계는 2단계**) + CameraPairingScreen(셸 밖) | **terra-server** `cameras`(ESP32-P4) + WebRTC P2P 라이브 + `motion_clips` 비디오(썸네일·즐겨찾기 클라우드·AI분류칩) + BLE 페어링 |
| `/my-pets` (탭3) | my_pets | MyPetsScreen ([개체목록\|리포트] — 개체 CRUD + 어젯밤 리포트) | Supabase `pets`/`pet_events`/`media` + terra-api 하이라이트 |
| `/community` (탭4) | community | CommunityScreen — **클립 공유 피드**(2026-08-31 리뉴얼): 공지 배너·위키 카드·피드(무한 스크롤·자동재생)·댓글/좋아요·신고/차단. 전체화면 플로우는 최상위 라우트 `/community-share`(글쓰기)·`/community-player/:postId`·`/community-user/:userId` | Supabase `community_*` 6테이블 + `community-media` 버킷(**스냅샷 복사** — 영상·썸네일·크레 사진) + `public_profiles` 뷰. 계획서 `docs/plans/2026-08-29-community-clip-feed.md` |
| `/env-detail` (보조, 2026-09-02 신설) | home | EnvDetailScreen — 세그먼트 [일간\|주간]. 일간=자정 경계 날짜 페이징 + 524pt 가로 스크롤 듀얼 라인 차트(`EnvDayChart`, 마커 행·스크러버) + 현재값/최고최저 + **사육장 제어 기록**(`ControlLogList`, 켠~끈 델타). 주간=요일 min/max 범위 바(`WeekRangeChart`) | `telemetry_30m` + `commands` (`env_detail_providers.dart`, 도메인 `shared/domain/{env_day,week_range,control_log}.dart`) |
| `/smart-cage` (보조) | my_cage | SmartCageScreen + DevicePairingScreen | **terra-server** `devices`/`telemetry`/`commands` + BLE |
| `/notifications`·`/enclosure-settings`·`/home/routines` (보조) | notification / my_cage / home | 홈 헤더·루틴 진입점 | PRD §3.1 / §3.4 |
| `/dev/chart-lab` (보조) | dev | ChartLabScreen — 온습도 그래프 디자인 검토(더미 데이터) | 없음(하드코딩 픽스처) |
| `/design-test` (보조, **공개**) | dev/design_lab | 디자인 테스트 선택 + **A/B** 4탭 mock 셸(구 `/dev/design-lab` 교체, 비로그인 공개 — `kPublicPaths`). C안은 2026-08-14 폐기. 롤백: `docs/design-test-rollout-plan.md` §2.4 | 없음(랩 fixtures + 번들 루프 영상) |
| — | splash/error | SplashScreen / ErrorScreen | — |

> 홈 탭 도메인: `home/domain/{day_window,device_mode,enclosure_set,env_extremes,env_chart_series,actuator_marker,chart_time_axis,running_timer,mist_lock,mist_duration,schedule,timeline_summary,pet_dday}.dart`. 하루 경계 개념 셋 혼용 금지(PRD §3.1): 활동·클립 귀속=**07:00~익일 07:00**(`DayWindow`) / 밤 집계=22~06시 / **환경(온습도) 하루=자정~자정**(`EnvDay`, 2026-09-02 — 홈 최고최저·온습도 상세 일간 페이징). 구 '전날 19:00~현재' 홈 차트는 폐기(홈엔 차트 없음).
> **⚠️ 사육장 제어 명령은 반드시 `home/presentation/cage_control_actions.dart`를 경유한다.** 히터 2단 안전확인(과열=개체 폐사)이 거기 있다. 진입점은 서브탭 `QuickControlGrid` **하나뿐**이다 — 라이브 아래 `LiveControlBar`는 버튼이 두 벌 쌓여 2026-08-09 제거(D4 철회). 제어 진입점을 다시 늘린다면 반드시 이 모듈을 경유할 것.
>
> **⚠️ 제어는 toggle이 아니라 절대 상태 명령을 쓴다** (2026-08-12). `fan_on/off`·`heater_on/off`·`relay_on/off`가 펌웨어에 **처음부터 있었다** — `APP_INTEGRATION.md §3.2` 표에 toggle만 적혀 있어 없는 줄 알았을 뿐이다. 뒤집기는 기기의 현재 상태를 전제하는데 그 전제가 어긋나면 끄려던 조작이 켜고, 히터에서는 과열=폐사다. 홈 `QuickControlGrid`·사육장 탭 `actuator_controls` 둘 다 전환 완료.
> **⚠️ 새 명령을 추가하면 `shared/domain/actuator_marker.dart`의 `_kindByAction`을 같이 고칠 것.** 안 하면 그 동작만 차트에서 **조용히** 사라진다(에러 없음). `led_toggle` 누락으로 12건을 놓쳤고, `mist` 전환 때도 밟을 뻔했다.
> **분무**: `mist` + `payload.duration_ms`(1000/2000/3000). 앱은 지속시간만 보내고 **OFF는 보내지 않는다** — 펌웨어가 스스로 끈다. 과거 `relay_toggle` 144건도 계속 분무로 해석한다(`MistDuration`, `home_mist_*`).
> **LED 밝기는 보드 능력으로 분기한다**(2026-08-18): `devices.capabilities.led_dimmable`(`Device.ledDimmable`)이 true인 MOSFET 보드만 `openLedSheet`에 슬라이더(`led_on`+`brightness`)가 뜬다. 릴레이 보드는 on/off만. **⚠️ 펌웨어가 아직 capabilities를 보고하지 않아 전 기기가 `relay`로 백필**돼 있다 — 실제 MOSFET이면 운영자가 DB를 고치거나 펌웨어 보고가 붙어야 슬라이더가 열린다. 앱은 분기만 갖고 기다린다. **LED 실상태는 `telemetry.led`/`led_brightness`**(`TelemetryReading.led`)만 본다 — 구 펌웨어(`unavailable`)는 "모름"으로 그리고 켜기/끄기 버튼을 둘 다 내놓는다(홈 캡슐·사육장 타일 동일 규칙, 로컬 추측 없음).
> **팬 타이머**(2026-08-14): `fan_on` + `payload.duration_ms`(최대 2h) → **펌웨어가 자동 OFF**, 취소는 `fan_off`. 진행 칩(`RunningTimerChip`)은 서버 상태가 아니라 `commands` 이력에서 `issued_at+duration_ms`로 계산한다(`RunningTimer.fanTimerFrom`). 히터 타이머는 보드 미탑재로 미지원.
> **예약(일정)**: `home/data/schedule_repository.dart`(REST 전용) + `home/presentation/schedule_providers.dart` + `RoutineSettingsScreen`. **쓰기는 반드시 REST** — RLS가 있어 직결 INSERT도 통과하지만 서버가 `next_run_at`을 계산하므로 직접 넣으면 예약이 영영 안 돈다. `next_run_at`은 UTC로 오니 `.toLocal()` 한 번(문서 예제의 `+9h`는 이중 변환 버그). 예약 액션은 **절대 명령만 selectable**(toggle은 무인 실행에서 위험해 제외). **구간 예약**은 편집기 [구간]이 **같은 `pair_id`(앱 UUID)**로 on/off 2건을 만든다(`addSpan`, off 실패 시 on 롤백) — 서버가 짝을 묶어 **한 건 DELETE로 둘 다 삭제**되고, 목록은 `Schedule.group()`이 `SchedulePair` 한 줄로 그린다(토글·편집도 두 행 동시, `setPairEnabled`/`updateSpanTiming` — **off 실패 시 on을 원래 값으로 롤백**, 삭제 후엔 목록 재조회로 서버 캐스케이드를 확인). 반쪽 켜짐(on만 enabled)은 **켜짐+경고**로 그린다(OFF로 숨기면 안 꺼지는 히터를 감춘다). 2026-08-18 이전 낱개 구간은 짝 없이 그대로 보인다. **스마트 가드**는 스킵형 4종(`ScheduleGuard`), 가드는 on쪽에만 건다 — **off+guard는 서버가 400**, `*_toggle` 예약도 서버 400(앱은 이미 안 고름).
> **화면에서 이유를 밝힌다**: 정지형 가드·히터 타이머는 펌웨어 후속이라 `RoutineSettingsScreen` 하단 각주로 밝힌다. 기기 오프라인도 `DeviceOfflineNotice`로 밝힌다 — 회색 버튼만 두면 고장으로 읽힌다. **LCD 문구**는 사육장 설정의 `LcdSettingTile`(REST `/lcd`, 64자 상한) — `lcd_bitmap/lcd_clear`는 차트 마커에서 **의도적으로 제외**(액추에이터 동작이 아님).
> 백엔드 계약 결정 로그: `docs/backend-handoff-timer-mist.md` §10 (2026-08-14 해소 현황 포함) + 신규 계약 `docs/backend-handoff-2026-08-14-summary.md`. ⚠️ 팬타이머·LCD 실동작은 **펌웨어 플래시 선행**.
> **온습도 차트는 홈·통계 공용이다** — `shared/widgets/env_chart.dart`(`EnvChart`) + `shared/domain/{chart_window,env_chart_data,axis_bounds,actuator_marker,night_band}.dart`. 창(`ChartWindow`)은 **지금 이후 첫 6시간 눈금(04/10/16/22시)에서 24시간 뒤로**, 6시간마다 통째로 전진한다. 남는 꼬리가 미도래 밴드(= 아직 안 지난 시간). 치수는 Figma 393pt 프레임 실측값(`docs/figma-final-design-transcript.md` §3.1 실측 좌표표)이고, 격자는 라이브러리가 아니라 직접 그린다(가로선·세로선·밴드가 서로 다른 세로 범위를 쓴다). Y 눈금은 **항상 6개**, 칸 크기는 데이터에 맞춰 1·2·5 계열로 정해진다.
> 요약(현재값 + 최고/최저)도 공용이다 — `shared/widgets/env_summary_bar.dart`(`EnvSummaryBar`). **두 위젯 다 provider를 읽지 않고 값만 받는다**(순환 참조 방지). 화면별 얇은 래퍼가 배선한다: 홈 `LiveEnvCard`, 통계 `StatsSummaryBar`.
> 화면별 차이: 홈은 **밤 띠 on·스크러버 off**(차트 전체가 `/stats` 진입점), 통계는 **밤 띠 off·스크러버 on**(손 떼도 유지, ✕로 해제). 그 외 표시는 완전히 같다 — 홈의 위험/주의 배지는 2026-08-10 제거(사용자 결정). 안심존 판정(`classifyComfort`)은 사육장 탭 추이 차트에 남아 있다.
> 프로바이더는 `home/presentation/home_control_providers.dart`에 모여 있다(`chartWindowProvider`·`envChartDataProvider`·`chartExtremesProvider`·`actuatorMarkersProvider`). 최고/최저는 **차트와 같은 창**을 쓴다(당일 07:00~ 창을 쓰던 `todayExtremesProvider`는 제거).

> 사육장 IoT 데이터 계층: `my_cage/data/{ble_pairing_repository,supabase_module_control_repository}.dart`, `my_cage/domain/{device,telemetry_reading,telemetry_bucket,device_command,actuator_state,wifi_access_point,pair_target_kind,species_comfort}.dart`.
> BLE 페어링(2026-07-02 개편): Wi-Fi 프로비저닝 프로토콜(`SCAN`→`SSID`→`PASS`→`CONNECT`, JWT 흐름 제거). 사육장·카메라 공통 `presentation/widgets/wifi_provisioning_view.dart` + 래퍼 `{device,camera}_pairing_screen.dart`(라우트 `/smart-cage/devices/pair`, `/crecam/cameras/pair`). **앱은 WiFi 연결만 — 토큰/DB등록/owner는 사전 세팅((a) 방식)**. 상세: `docs/ble-provisioning-protocol.md`, 메모리 `project_ble_provisioning_scheme`.
> SmartCageScreen UI(2026-06-12 개편): 현황(`module_status_card`)+제어(`actuator_controls`)를 단일 통합 카드로 병합 + 테두리. 액추에이터='사육장 제어'(iOS 제어센터 스타일 한 row 타일). LED는 앱이 `CommandAction.ledOff`를 선제 추가(terra-server 계약에 led_off·LED telemetry 없음 → 메모리 `project_led_control_gap`).
> 온습도 추이 차트(2026-07-07, v0.12.0+22): `telemetry_history_chart.dart`(chart_sparkline) — 지표별 카드 + 매끈한 스파크라인 + **초록 안심존 밴드** + 최고/최저 마커, 기간 24h/7d/30d. 안심존=종 care_info 자동도출(`SpeciesComfort`; device_settings는 전 디바이스 비어있어 미사용, **임의 수치 금지**). **`telemetry_30m` 0값=센서 오프라인 센티넬 → 로드 시 `v>0` 필터 필수.** 상세: 메모리 `project_telemetry_chart`·`project_telemetry_zero_sentinel`.
> **목표 온습도(setpoint)는 REST `device_settings`**(2026-08-18) — `my_cage/data/device_settings_repository.dart` + `presentation/device_settings_providers.dart`. 미설정 기기는 404가 아니라 전부 null인 200이고 화면은 "목표 미설정"으로 그린다(**앱이 임의 기본값을 채우지 않는다**). 편집은 사육장 설정 `SetpointSettingTile`(홈 세트의 기기 — title에 기기명 표시) **또는 사육장 탭 카드의 목표 줄 탭**(`showSetpointSheet`, 그 카드의 기기) — 두 화면의 기기 축이 달라 어느 쪽에서 고치든 "보고 있는 기기"가 대상이 되게 했다. 서버와 같은 범위 검증(−20~60℃/0~100%). 카드는 로딩·에러면 목표 줄을 비우고 서버가 null일 때만 "미설정". **사육장 설정의 "현재 세트 기기" 타일은 `DeviceSettingTile`/`DeviceSettingSheet`/`submitAndClose`(`my_cage/presentation/widgets/device_setting_sheet.dart`)를 경유한다**(LCD·setpoint 공용 — 새 기기 설정을 추가하면 이걸 쓰고 타일/시트를 복붙하지 말 것). 숫자 표기·JSON double 파싱은 `shared/domain/num_format.dart`(`formatCompact`·`parseDouble`) — 흩어진 `_fmt`/`_parseDouble` 복제는 2026-08-18에 여기로 통합했다. 정지형 가드(히터 목표온도 정지)가 생기면 이 값이 기준이다.

## 코딩 규칙

### 상태 관리
- **Riverpod만 사용**. setState, ChangeNotifier 금지.
- `ref.watch`는 build 안에서만, `ref.read`는 콜백/이벤트에서.
- Provider는 각 feature의 `presentation/` 폴더에 위치.
- **인증 의존 Provider stale 방지**: 유저 데이터를 fetch하는 non-autoDispose provider는 반드시 `ref.watch(currentUserProvider.select((u) => u?.id))`로 계정 id만 감시한다. User 객체 전체를 watch하면 무관한 필드(updatedAt 등) 변경에도 재build가 발생한다.
  - **3층 계정 격리**: ① provider에서 userId select-watch → ② 위젯에서 `_initializedForId` 가드(캐시된 위젯의 중복 init 방지) → ③ 로그아웃 시 Hive 로컬 캐시 clear(타 계정 데이터 프라이버시). 상세: 메모리 `project_auth_provider_stale_pattern`
  - 비동기 콜백에서 `mounted` 확인 없이 `state=`/`ref.read`/setState 호출 금지.

### 데이터 접근
- **Repository 패턴 필수**. Widget에서 Hive/데이터 직접 접근 금지.
- P0은 로컬 상수 → P2에서 Repository 구현체만 Supabase로 교체.
- Supabase 테이블/RLS/접속 정보는 `docs/supabase-setup.md` 참조.

### UI/테마
- **현행은 Figma `vivanaut app` Asset 팔레트 (2026-09-02, 라이트벌 교체)** — 바닥 white, 면 `surfaceTint`(#F0F4F9), 텍스트 그레이스케일(#1E1E1E/#3C3C3C/#919497), 기기 상태색(`deviceFan` 그린 · `deviceCool` 블루 · `deviceLed` 앰버 · `deviceHeat` 도출 레드 · `deviceMist`=`humidAccent` #00B2F3 · 온도 `tempAccent` #F85478), 탭바 white+top stroke(활성 primary #192553). 신규 토큰 16종은 `GlassPalette` 필드로 추가됨 — **필드 추가 시 선언·생성자·dark·light·copyWith·lerp 6곳 동시 수정**. 다크벌은 구 B안 값 유지(Figma에 다크 없음 — 후속). 실측 SOT: `docs/plans/2026-09-02-prd-redesign-phase1-home.md` §A.
- (구) B안(Flighty 전광판) — 다크/라이트 2벌, 라이트 기본(2026-08-14, A안 2차 교체) — 단색 바닥 + 카드(radius 16·그림자 없음·divider 테두리) + 데이터 라벨 소형 자간(`labelCaps`) + 큰 tabular 수치(`figure`) + 상태 시맨틱 앰버/그린/레드(`signalWarn/Ok/Alert`) + **활성=앰버**(`activeTile`) + 전광판 고정 탭바(`GlassDock`) + 세그먼트는 앰버 텍스트+밑줄. **색 토큰은 `lib/core/theme/glass_palette.dart`의 `GlassPalette`(ThemeExtension) 인스턴스 필드 — `variant_b_tokens.dart`의 미러. 소비처는 `context.glass.overlay`처럼 꺼낸다. `AppTheme.glassX` 정적 색 상수는 삭제됐으니 되살리지 말 것**(두 벌이 남으면 라이트에서 다크 값이 샌다). 모드는 시스템/라이트/다크 3단(`themeModeProvider`, Hive `app_settings/theme_mode`, **기본 라이트** `ThemeModeRepository.defaultMode`, 프로필 "화면 모드"). 공용 위젯 이름(`GlassCard`·`GlassDock` 등)은 **역사적 명칭으로 유지**되며 값만 B다(`blur` 파라미터는 no-op). 랩 A/B(`/design-test`)는 비교 페이지로 존치(설정에서도 진입, `lib/features/dev/design_lab/` 무접촉). 2단계(홈/통계/마이크레 화면 B 문법 이식)는 후속. 상세는 `docs/design-direction.md` §0. **Figma 팔레트 SOT 갱신은 후속 과제(사용자 작업 필요)** — Figma `Asset`은 아직 구 팔레트다
- **시각 디자인 방향**: `docs/design-direction.md` — 위계·타이포·색 역할·시그니처(밤 띠). **팔레트·컴포넌트 규격 SOT는 Figma**(`docs/figma-final-design-transcript.md` §4)
- **디자인 시스템(구)**: `docs/design-system.md` — 토큰·공유 위젯 정의
- **하드코딩 색상 금지**. `AppTheme` 또는 `Theme.of(context)` 사용.
- **하드코딩 문자열 금지**. `assets/l10n/ko.json`에 키 추가 후 `.tr()` 사용.
- **Primary: `#192553`**(Figma 메인컬러, `AppTheme.brandNavy`). 구 Green 800은 2026-08-08 폐기 — 결정 로그 D2-1
- 의미색: `AppTheme.success`(서브 초록) / `warning`(#FF8F00, **Figma 미정의**) / `danger`(서브 빨강). 브랜드 빨강 `#d61619`는 **용도 미정이라 미배정**
- 다크 Primary는 `brandNavyDark`(#768ad6) — Figma에 다크 팔레트가 없어 명도만 올린 도출값
- 폰트: Pretendard (Regular/Medium/SemiBold/Bold)
- 간격: `AppStyles.spacingN` 토큰 사용, 태그: `AppTag` 위젯, 섹션 제목: `SectionHeader` 위젯

### 라우팅
- GoRouter 사용. 경로는 `core/router/app_router.dart`에서 중앙 관리.
- 새 화면 추가 시 라우터에 등록 필수.

### 다국어
- `easy_localization` + `assets/l10n/ko.json`.
- 새 문자열 추가 순서: ko.json에 키 추가 → 코드에서 `'key'.tr()`.

## CAOF (Claude Agent Orchestration Framework)

이 프로젝트는 CAOF를 따른다. 원본: `/Users/baek/ideaBank/frameworks/claude-agent-orchestration.md`

### 역할 매핑 (에이전트 분리는 Critical 트랙만 — CAOF v1.3)
- **Designer**: 메인 Claude -- 분석, 설계, Phase 전환 판단
- **Implementer**: flutter-dev -- Dart 코드 구현 (Critical에서 투입, 모델은 상속 기본)
- Standard는 메인이 역할 겸임 (분석서 → 합의 → 직접 구현)

### 사용자 안내 규칙
작업 요청 시, 메인 Claude는 **트랙 판단 결과를 먼저 알려준다**:
```
CAOF 트랙: [Trivial / Standard / Critical]
이유: [1줄 근거]
-> [어떤 에이전트가 어떤 순서로 작동하는지]
```
사용자가 "CAOF 끄기"라고 하면 해당 세션에서 비활성화.

### 트랙 분류

| 트랙 | 기준 | 파이프라인 |
|------|------|-----------|
| Trivial | 상수 수정, 스타일 변경, 텍스트 수정 | 메인 직접 처리 |
| Standard | 기존 feature 수정, 새 위젯, Provider 추가 | 메인이 분석서 -> 합의 -> 직접 구현 |
| Critical | 새 feature, Phase 전환 (패키지 도입 제외 — 자유 재량) | 풀 GATE (에이전트 분리) |

**판단 기준은 줄 수가 아니라 "실패 시 되돌리기 비용"이다.**
상세 라우팅 트리: `.claude/rules/vivnanaut-caof.md`

### 에이전트 폭주 방지

**대규모 변경 처리:**
- 변경 파일 10개+ -> 한 번에 전부 읽지 않는다
- overview(git diff --stat) -> 기능별 그룹핑 -> 그룹별 순차 처리

**실패 제한:**
- 에이전트 스폰 재시도: **3회**
- 빌드/수정 루프: **3회**
- 3회 실패 시 즉시 중단 + 사용자에게 보고

### 실패 에스컬레이션
```
1회 실패: 원인 분석 후 재시도
2회 실패: Designer 역할로 원인 재분석 -> 다른 접근법
3회 실패: 즉시 중단 + 사용자에게 보고 + 범위 축소 또는 대안 제시
```
"빨리 해", "바로 구현해"는 GATE 스킵 승인이 아니다. "N단계 스킵 승인"만 허용.

## 빌드/검증

```bash
flutter analyze          # 정적 분석 (에러 0 유지)
flutter build apk --debug  # Android 빌드 확인
flutter test             # 테스트 실행
```

- 코드 수정 후 `flutter analyze` 에러 0 확인 필수.
- `flutter build`는 Claude Code 안에서 직접 실행 가능 (리소스 경합 낮음, Unity와 다름).

### 커밋 (2026-08-06 확정) — 묻지 말고 자동
**작업 단위마다 커밋한다. 사용자에게 커밋 여부를 묻지 않는다.**
- **단위 기준**: 논리적으로 완결된 변경 하나 = 커밋 하나. 태스크 1개, 버그 1건, 문서 1건, 리팩터링 1건.
  관심사가 다른 변경을 한 커밋에 섞지 않는다(되돌릴 때 같이 딸려온다).
- **커밋 전 필수**: `flutter analyze` 에러 0 + 관련 테스트 통과. 깨진 상태를 커밋하지 않는다.
- **위험한 변경은 단독 커밋**: 전면 교체·구조 변경(예: 화면 전면 재작성, 라우터 재배열)은 그 파일만 따로 커밋해 되돌리기 쉽게 둔다.
- **version bump**: `lib/` 변경이 포함되면 `pubspec.yaml` 버전을 올린다(fix→patch / feat→minor / breaking→major, build+1). pre-push 훅이 무버전업 push를 차단한다. 상세: 메모리 `project_release_versioning`
- **push는 자동이 아니다** — 원격은 공유 자산이라 사용자가 요청할 때 한다. 커밋만 쌓아두고 필요 시 제안한다.

### 코드 리뷰 (2026-08-06 확정)
**코드 리뷰는 내장 `/code-review`만 쓴다.** 예외 없음.
- Codex·Gemini 등 외부 CLI로 diff 리뷰를 돌리지 않는다. `/검수`는 기획 문서 전용이라 코드에 쓰지 않는다.
- Claude는 `/code-review`를 대신 실행할 수 없다 — **사용자가 직접 호출**한다. 리뷰가 필요하면 요청하고 기다릴 것.

## 금지 사항
- placeholder feature(onboarding, profile, notification)를 기획 확정 전 구현하지 않기 (auth는 Email 인증 구현 완료 — 제외)
- **CircularProgressIndicator 사용 금지** — 로딩 상태는 항상 `shimmer` 패키지의 스켈레톤 UI를 사용할 것

## 패키지·버전 관리 (2026-07-08 — 자유 재량)
- **신규 라이브러리 설치·pubspec 버전 조정은 Claude 재량으로 자유롭게** 한다. 사용자 사전 승인 불필요. (기존 "새 패키지 추가 시 승인" 규칙 해제.)
- **CAOF "외부 패키지 도입 = Critical 자동 승격" 해제** — 되돌리기 비용은 사안별 판단(대개 Trivial~Standard).
- 가드레일(승인 게이트 아님, 상식): ① 유지보수되는 패키지 우선 ② 기존 기능과 중복 도입 회피 ③ 커밋/보고에 무엇을·왜 추가했는지 기록 ④ dependency solving 충돌 시 원인·선택을 보고에 남김.
- 표준 선호(강제 아님): HTTP는 `http` 우선(dio는 특별한 이유 시), 로컬 저장은 Hive 우선(flutter_secure_storage는 필요 시 도입 가능).
