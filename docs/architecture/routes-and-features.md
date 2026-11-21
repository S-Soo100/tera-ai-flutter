# 라우트·feature 구성 스냅샷 (2026-11)

> `CLAUDE.md`(커밋 `5675f3b2`) "아키텍처" 절의 구성 설명을 **문장 그대로** 옮긴 스냅샷이다(2026-11-21). **갱신하지 않는다.**
> 라우트의 SOT는 `lib/core/router/app_router.dart`, 탭 테이블은 `lib/core/router/tab_branches.dart`다. 이 문서와 코드가 다르면 코드가 맞다.
> 2026-09 이후 추가된 라우트(`/devices/*`·`/groups/*`·`/profile/*` 등)는 아래 표에 없다.

## 4탭 셸과 재설계 이력

**4탭** BottomNav(`StatefulShellRoute`) + 보조 라우트 구조. 탭 테이블은 `core/router/tab_branches.dart`(`kHomeTabPaths`), 조립은 `core/router/app_router.dart` 중앙 관리.

**2026-09-04 카메라 탭 재설계(2단계) 구현 완료** — Figma Camera 섹션 5화면(홈/하이라이트/북마크/세로 플레이어). 바텀 네비 아이콘도 Figma 원본 SVG(`assets/icons/nav_*.svg`, `kHomeTabIconAssets` 단일 에셋 — 활성/비활성 색만 다름)로 교체.

**2026-09-02 PRD 전면 개정 1단계 구현 완료** — 탭 = 홈/**카메라**/마이크레/커뮤니티(라벨 영문 Home/Camera/MyCre/Community). **통계 탭 폐지**(`/stats` 라우트 제거 — 온습도 시각화는 `/env-detail`로 흡수), `/crecam`은 **탭2로 승격**(하위 `cameras/...` 경로는 셸 밖 최상위 유지 — 페어링·상세에 독 안 뜸), **`/wiki`·`/search` 라우트 폐기**(care_info_repository 등 data 계층은 공용 인프라라 존치). 계획서: `docs/plans/2026-09-02-prd-redesign-phase1-home.md`.

아래 표는 주요 화면만 적는다. 전체 라우트의 SOT는 `core/router/app_router.dart`다. 표에 없는 묶음: `/devices/*`(추가·관리·네트워크·Wi-Fi·상세), `/groups/*`, `/device-groups/connect-camera`, `/pet-add`·`/pets/:petId`, `/profile/*`, `/crecam/recordings/:id`, 인증(`/login`·`/signup`·`/forgot-password`·`/verify-email`), 온습도·LCD 기기 설정(`kTempHumidSettingPath`·`kLcdSettingsPath`).

## 라우트·feature 표

| 탭/라우트 | feature | 화면 | 데이터 소스 |
|-----------|---------|------|------------|
| `/home` (탭1) | home | HomeScreen — **단일 스크롤**(2026-09-02): 헤더(세트 드롭다운/`[+]` 추가 메뉴/`[사람]`=계정) + 라이브(`TopFixedArea`) + 온습도 요약 카드(`EnvSummaryCard`, 탭→`/env-detail`) + 제어 그리드(`CageControlGrid` 4타일 — 히터팬은 2026-09-04 사용자 지시로 **평소 숨김**, 히터가 켜져 있거나 안전잠금이면 `_heaterTile`이 나타나 끄기·잠금 해제 진입점이 된다(켜기 진입점은 없음 — 사용자 지시까지 보류), 냉각팬(`fan2_on/off`)은 배선됨(2026-09-25 확인 — fan2 미보고 보드는 타일·예약 목록에서 막는다. `FeatureFlags.coolFanEnabled`가 false면 칸은 "비활성화"이고 이미 켜진 팬 끄기만 허용 — 현재 true)) + 일정 설정. 서브탭·타임라인·개체 프로필 분기 폐기 | 사육장 세트(`EnclosureSet`) + `homeTodayExtremesProvider`(오늘 자정~) |
| `/crecam` (탭2, Camera) | my_cage | CrecamScreen — **Camera Home 전면 재작성**(2026-09-04, Figma Camera 668:427): `HomeHeaderBar` + `CameraLiveArea`(전 카메라 PageView — **세트 순서 정렬 + 홈과 현재 카메라 양방향 동기화**(2026-09-07, `selectedCrecamCameraProvider`는 카메라 **id**)·오프라인 안내·0대 페어링 카드) — 확대 버튼은 라이브 전체화면(`/crecam/cameras/:id/live`, 가로·영상만, 2026-09-07) + 하이라이트/북마크 엔트리 카드 + 기간 설정(미선택=**최근 영상 날짜 자동**, `crecamResolvedDayProvider` — 명시 선택은 빈 날짜여도 존중, 2026-09-07) + 시간대별 3열 클립 그리드. 라이브는 failed 시 **지수 백오프 자동 재연결**(3~60s, `WebRtcLiveController`). 셸 밖 최상위: CameraPairingScreen(`cameras/pair`) + `/crecam/highlights`(HighlightsScreen — 도착 배너·**72h 창 앱측 그룹핑**, 백엔드 묶음 계약 확정 시 교체) + `/crecam/bookmarks`(BookmarksScreen) + `/crecam/player/:clipId`(**세로 재생목록 플레이어** ClipPlaylistPlayerScreen, extra=클립 id 목록 — 좌/우 1/3 탭 이전/다음·종료 자동 다음. 세로 진입, 명시 버튼으로 가로 전환(2026-09-14, `PlayerOrientationController` — 구 미결 R '회전 금지'(2026-09-07)를 대체)) | **terra-server** `cameras`(ESP32-P4) + WebRTC P2P 라이브 + `motion_clips` 비디오(썸네일·즐겨찾기 클라우드) + terra-api `/clips/highlights` + BLE 페어링. 계획서 `docs/plans/2026-09-04-camera-tab-redesign.md` |
| `/my-pets` (탭3) | my_pets | MyPetsScreen ([개체목록\|리포트] — 개체 CRUD + 어젯밤 리포트) | Supabase `pets`/`pet_events`/`media` + terra-api 하이라이트 |
| `/community` (탭4) | community | CommunityScreen — **클립 공유 피드**(2026-08-31 리뉴얼): 공지 배너·위키 카드·피드(무한 스크롤·자동재생)·댓글/좋아요·신고/차단. 전체화면 플로우는 최상위 라우트 `/community-share`(글쓰기)·`/community-player/:postId`·`/community-user/:userId` | Supabase `community_*` 6테이블 + `community-media` 버킷(**스냅샷 복사** — 영상·썸네일·크레 사진) + `public_profiles` 뷰. 계획서 `docs/plans/2026-08-29-community-clip-feed.md` |
| `/env-detail` (보조, 2026-09-02 신설) | home | EnvDetailScreen — 세그먼트 [일간\|주간]. 일간=자정 경계 날짜 페이징 + 524pt 가로 스크롤 듀얼 라인 차트(`EnvDayChart`, 마커 행·스크러버) + 현재값/최고최저 + **사육장 제어 기록**(`ControlLogList`, 켠~끈 델타). 주간=요일 min/max 범위 바(`WeekRangeChart`) | `telemetry_30m` + `commands` (`env_detail_providers.dart`, 도메인 `shared/domain/{env_day,week_range,control_log}.dart`) |
| `/smart-cage` (보조) | my_cage | SmartCageScreen + DevicePairingScreen | **terra-server** `devices`/`telemetry`/`commands` + BLE |
| `/notifications`·`/enclosure-settings`·`/env-settings`·`/home/routines` (보조) | notification / my_cage / home | 홈 헤더·루틴 진입점. **연동/설정 분리(2026-09-08)**: `/enclosure-settings`=**사육장 연동**(개체 배정·페어링·사육장 관리, `[+]` 메뉴 "사육장 연동") / `/env-settings`=**환경설정**(`EnvSettingsScreen` — 목표 온습도·화면 뒤집기, 홈 헤더 ⚙️ 신설 — 2026-09-02의 ⚙️ 제거를 사용자 결정으로 되돌림) | PRD §3.1 / §3.4 |
| `/dev/chart-lab` (보조) | dev | ChartLabScreen — 온습도 그래프 디자인 검토(더미 데이터) | 없음(하드코딩 픽스처) |
| `/design-test` (보조, **공개**) | dev/design_lab | 디자인 테스트 선택 + **A/B** 4탭 mock 셸(구 `/dev/design-lab` 교체, 비로그인 공개 — `kPublicPaths`). C안은 2026-08-14 폐기. 롤백: `docs/design-test-rollout-plan.md` §2.4 | 없음(랩 fixtures + 번들 루프 영상) |
| — | splash/error | SplashScreen / ErrorScreen | — |

## 홈 도메인과 하루 경계

홈 탭 도메인: `home/domain/`(파일 목록은 폴더가 SOT — 차트 창·마커·최고최저 계산은 `shared/domain/`). 하루 경계 개념 셋 혼용 금지(PRD §3.1): 활동·클립 귀속=**07:00~익일 07:00**(`DayWindow`) / 밤 집계=22~06시 / **환경(온습도) 하루=자정~자정**(`EnvDay`, 2026-09-02 — 홈 최고최저·온습도 상세 일간 페이징). 구 '전날 19:00~현재' 홈 차트는 폐기(홈엔 차트 없음).

## 공용 온습도 차트

**온습도 차트는 홈·통계 공용이다** — `shared/widgets/env_chart.dart`(`EnvChart`) + `shared/domain/{chart_window,env_chart_data,axis_bounds,actuator_marker,night_band}.dart`. 창(`ChartWindow`)은 **지금 이후 첫 6시간 눈금(04/10/16/22시)에서 24시간 뒤로**, 6시간마다 통째로 전진한다. 남는 꼬리가 미도래 밴드(= 아직 안 지난 시간). 치수는 Figma 393pt 프레임 실측값(`docs/figma-final-design-transcript.md` §3.1 실측 좌표표)이고, 격자는 라이브러리가 아니라 직접 그린다(가로선·세로선·밴드가 서로 다른 세로 범위를 쓴다). Y 눈금은 **항상 6개**, 칸 크기는 데이터에 맞춰 1·2·5 계열로 정해진다.

요약(현재값 + 최고/최저)도 공용이다 — `shared/widgets/env_summary_bar.dart`(`EnvSummaryBar`). **두 위젯 다 provider를 읽지 않고 값만 받는다**(순환 참조 방지). 소비처는 `/dev/chart-lab`만 남았다(홈 `LiveEnvCard`·통계 `StatsSummaryBar` 래퍼는 2026-09-04 정리로 stats 폐지와 함께 삭제 — 실화면 온습도는 `/env-detail`의 `EnvDayChart`/`WeekRangeChart`).

화면별 차이: 홈은 **밤 띠 on·스크러버 off**(차트 전체가 `/stats` 진입점), 통계는 **밤 띠 off·스크러버 on**(손 떼도 유지, ✕로 해제). 그 외 표시는 완전히 같다 — 홈의 위험/주의 배지는 2026-08-10 제거(사용자 결정). 안심존 판정(`classifyComfort`)은 사육장 탭 추이 차트에 남아 있다.

프로바이더는 `home/presentation/home_control_providers.dart`에 모여 있다(`chartWindowProvider`·`envChartDataProvider`·`chartExtremesProvider`·`actuatorMarkersProvider`). 최고/최저는 **차트와 같은 창**을 쓴다(당일 07:00~ 창을 쓰던 `todayExtremesProvider`는 제거).

## 사육장 IoT 데이터 계층·SmartCageScreen

사육장 IoT 데이터 계층: `my_cage/data/{ble_pairing_repository,supabase_module_control_repository}.dart`, `my_cage/domain/{device,telemetry_reading,telemetry_bucket,device_command,actuator_state,wifi_access_point,pair_target_kind,species_comfort}.dart`.

SmartCageScreen UI(2026-06-12 개편): 현황(`module_status_card`)+제어(`actuator_controls`)를 단일 통합 카드로 병합 + 테두리. 액추에이터='사육장 제어'(iOS 제어센터 스타일 한 row 타일). LED는 앱이 `CommandAction.ledOff`를 선제 추가(terra-server 계약에 led_off·LED telemetry 없음 → 메모리 `project_led_control_gap`).

> 2026-11-21 덧붙임: 위 표의 `/smart-cage`와 `/enclosure-settings` 라우트·화면은 0.186.4에서 삭제됐다.
