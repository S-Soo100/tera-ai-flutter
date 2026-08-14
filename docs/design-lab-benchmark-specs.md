# 디자인 랩 — 벤치마크 3안 스펙 (2026-08-13)

> UIUX 전면 개선 프로젝트 1단계 산출물. 벤치마크 3앱(사용자 확정 2026-08-13)의
> 디자인 언어를 비바나트 홈 탭에 이식하는 체험 페이지(`/design-test` —
> 구 `/dev/design-lab`, 2026-08-14 비로그인 공개로 교체: `design-test-rollout-plan.md`) 스펙.
> 원칙: **구조·위계·인터랙션·모션은 픽셀 수준 모방, 아이콘·일러스트·브랜드 그래픽은 비바나트 자산으로 치환**
> (트레이드 드레스 회피). 최종 선정안은 앱 전체에 적용하고 Figma/design-direction.md SOT를 갱신한다.

## 0. 공통 규칙

- 3개 변형 모두 **같은 더미 데이터**(fixtures)를 쓴다 — 비교 공정성 확보. 실 provider 미연결.
- 체험 화면 = **4탭(홈/통계/마이크레/커뮤니티) 풀 셸** (2026-08-14 `/design-test` 공개와 함께 확장 —
  처음엔 홈 1장이었으나 B·C 4탭 셸에 A안도 맞췄다). 홈 구성: 헤더 → 라이브(루프 영상) → 온습도 요약 → 제어 그리드 → 미니 차트 → 타임라인.
- 각 변형은 자기 토큰 세트만 쓴다. `AppTheme`/`AppStyles` 참조 금지 (랩 격리 — 기존 앱 무영향).
- 폰트는 Pretendard 유지(웨이트·스케일만 벤치마크를 따름). 숫자 강조 구간은 `FontFeature.tabularFigures()`.
- 로딩은 shimmer 스켈레톤 (CircularProgressIndicator 금지 — 프로젝트 규칙).

## A안 — Apple Home (iOS 26, Liquid Glass)

**핵심 문법**: 배경 위 유리 타일. 콘텐츠(월페이퍼/카메라)가 바닥이고 UI는 그 위에 떠 있는 반투명 레이어.

### 토큰
| 항목 | 값 |
|---|---|
| 배경 | 딥 그라데이션 월페이퍼(네이비→틸, 비바나트 브랜드 도출) + 블러 |
| 타일 | `BackdropFilter(blur 24)` + 흰색 12~18% 오버레이, radius 26(squircle 느낌 continuous) |
| 활성 타일 | 불투명 흰색(라이트)/기기 색 틴트 — 히터=주황, 분무=파랑, LED=노랑, 팬=민트 |
| 타이포 | 타일 제목 15 SemiBold, 상태 13 Regular(60% 투명), 헤더 34 Bold |
| 스페이싱 | 타일 그리드 2열, gap 12, 화면 좌우 16 |

### 화면 구성
1. **헤더**: 대형 타이틀 "내 사육장" + 세트 드롭다운(유리 캡슐). 스크롤 시 타이틀 축소.
2. **카메라 카드**: 상단 고정 16:9 라이브 스틸(더미 이미지) — Home 앱 홈캠 카드 그대로. 좌하단 LIVE 배지, 우하단 타임스탬프.
3. **센서 칩 행**: 온도·습도를 가로 유리 캡슐 칩으로(Home 앱 '기후' 요약 문법).
4. **액세서리 타일 그리드**: 히터/분무/LED/팬 2×2. 아이콘 좌상단(활성 시 기기색), 탭=토글 시각 피드백, 롱프레스=상세 시트(밝기/시간 — 더미).
5. **미니 차트**: 유리 카드 안에 기존 `EnvChart` 축소판(더미 데이터).
6. **타임라인**: 얇은 유리 카드 리스트, 아이콘+한 줄 텍스트.
7. **모션**: 스크롤 시 하단 탭바 축소/복원(iOS 26 문법), 타일 탭 스프링 스케일(0.96→1.0).

## B안 — Flighty (Apple Design Award, 공항 전광판 데이터 밀도)

**핵심 문법**: "라이브 상태 추적 대시보드". 상단 맵/라이브 헤더 + 하단 카드 리스트. 공항 전광판(FIDS) 위계 —
50년 검증된 "뭐가 중요한가" 규칙. 항공편 추적 ↔ 사육장 밤 활동 추적이 구조적으로 동일.

### 토큰
| 항목 | 값 |
|---|---|
| 배경 | 거의 검정 네이비 `#0B0F1A` (다크 고정) |
| 카드 | `#161B2C` radius 16, 구분선 얇은 흰 6% |
| 강조색 | 전광판 앰버 `#FFB300`(주의), 그린 `#34C759`(정상), 레드(경보) — 상태 시맨틱 엄격 |
| 타이포 | 데이터 라벨 11 Medium 대문자 자간+0.8(전광판), 수치 22~28 Bold tabular, 본문 15 |
| 진행 바 | 밤 활동 진행(22:00~06:00)을 비행 진행 바 문법으로 — 두꺼운 트랙+비행기 대신 게코 아이콘 |

### 화면 구성
1. **라이브 헤더**: 상단 40% 고정 영역 — 맵 대신 사육장 라이브 스틸 + 어두운 그라데이션. 그 위에 현재 상태 오버레이(온도·습도 대형 수치, 전광판 스타일).
2. **상태 카드(핵심)**: "오늘 밤" 카드 — 비행 카드 문법 그대로: 좌측 출발지/도착지 대신 `22:00 → 06:00`, 중앙 진행 바, 하단 3열 데이터 그리드(활동량/최고온도/분무횟수). 상태 배지 ON TIME→"안정" / DELAYED→"주의".
3. **타임라인**: Flighty의 수직 스텝 타임라인(체크인→탑승→이륙) 문법으로 밤 이벤트(첫 활동 감지→분무→피크 활동)를 표시. 완료 스텝 그린 도트+실선, 예정 스텝 회색 점선.
4. **제어**: 다크 카드 안 가로 스크롤 캡슐 버튼 행(Flighty 하단 액션 문법). 데이터가 주인공, 제어는 보조.
5. **모션**: 수치 카운트업, 진행 바 부드러운 채움, 카드 진입 시 순차 페이드+슬라이드.

## C안 — Copilot Money (프리미엄 데이터 시각화)

**핵심 문법**: 밝은 배경 + 채도 높은 그라데이션 차트 + 큰 라운드 수치. "데이터가 아름다워서 매일 열어보고 싶은 앱".
가계부 월 요약 ↔ 사육장 환경 요약이 동형. 통계 탭까지의 확장성이 가장 좋다.

### 토큰
| 항목 | 값 |
|---|---|
| 배경 | 웜 화이트 `#FAF9F7`, 카드 순백 + 그림자 8% blur 24 |
| 차트 | 그라데이션 필: 온도=코럴→퍼플, 습도=블루→시안. 라인 3px 라운드캡 |
| 카테고리 색 | 파스텔 칩: 히터=피치, 분무=스카이, LED=레몬, 팬=민트 (Copilot 카테고리 문법) |
| 타이포 | 대형 수치 40 Bold(소수점은 20 Medium 60%), 섹션 라벨 13 SemiBold 그레이 |
| radius | 카드 20, 칩 풀라운드, 버튼 14 |

### 화면 구성
1. **헤더**: 인사말 + 이번 주 요약 한 줄("이번 주 평균 26.4℃ · 안정"). 우측 아바타(게코 프로필).
2. **히어로 수치**: 현재 온도 초대형(40) + 전일 대비 증감 배지(▲0.8℃ 그린/레드) — Copilot 잔액 헤더 문법.
3. **메인 차트**: 그라데이션 영역 차트(스크러버 포함) — Cash Flow 차트 문법. 기간 칩(24h/7d/30d).
4. **카테고리 그리드**: 기기별 오늘 가동 요약을 지출 카테고리 카드 문법으로 — 파스텔 아이콘 원+가동시간+미니 진행 링. 탭하면 제어 시트.
5. **타임라인**: 거래 내역 리스트 문법 — 좌측 파스텔 아이콘 원, 우측 시각, 날짜 섹션 헤더.
6. **모션**: 차트 그리기 애니메이션(좌→우 reveal), 스프링 전환, 숫자 롤링.

## `/design-test` 설계 (구 `/dev/design-lab`)

```
lib/features/dev/design_lab/
├── design_lab_screen.dart          # 선택 화면: A/B/C 카드 → push
├── design_lab_fixtures.dart        # 공용 더미(온습도 24h·주간 7일, 기기 4종, 개체 3, 리포트, 게시글)
├── mock_live_player.dart           # 공용 mock 라이브 루프 플레이어(LIVE 배지+폴백, A·B 홈)
├── variant_a_shell.dart            # A안 4탭 셸(IndexedStack, 유리 독+축소 모션)
├── variant_a_{home,stats,pets,community}_screen.dart
├── variant_a_widgets.dart          # A 공용 조각(AWallpaper/AGlass/AScreenScaffold 등)
├── variant_b_shell.dart            # B안 4탭 셸(Flighty 전광판 탭바)
├── variant_b_{home,stats,pets,community}_screen.dart
├── variant_c_shell.dart            # C안 4탭 셸(Copilot 필 탭바)
├── variant_c_{home,stats,pets,community}_screen.dart
└── tokens/
    ├── variant_a_tokens.dart       # 안별 색·타이포·radius·spacing 상수 (AppTheme 미참조)
    ├── variant_b_tokens.dart
    └── variant_c_tokens.dart
```

- 라우트: `/design-test`(선택 화면) + `/design-test/a|b|c`. `app_router.dart` 보조 최상위 등록(`/dev/chart-lab` 옆). 2026-08-14부터 비로그인 공개(`kPublicPaths`) — 진입점·롤백은 `design-test-rollout-plan.md` §2.4.
- 상태 관리 없음(StatelessWidget + 로컬 인터랙션만). Riverpod provider 미도입 — 더미라 불필요.
- 하드코딩 색상·문자열: **랩 한정 허용**(chart-lab 전례 — 픽스처·검토용 화면은 예외). 전면 적용 단계에서 토큰은 AppTheme으로, 문자열은 ko.json으로 승격.
- 진입: 개발 중에는 URL 직접 진입. 필요 시 설정 화면에 임시 진입점(후속 판단).

## 전면 적용 로드맵 (선정 후)

1. 선정안 tokens → `AppTheme`·`AppStyles` 교체 (단독 커밋)
2. 공용 위젯(`EnvChart`·`EnvSummaryBar`·`QuickControlGrid`·카드류) 마이그레이션
3. 탭별 순차: 홈(랩 코드 승격) → 통계 → 마이크레 → 커뮤니티 → 보조 라우트
4. SOT 갱신: `docs/design-direction.md` + Figma 팔레트. 갱신 전까지 신규 작업 규칙 충돌 주의
5. 단계마다 analyze 0 + 단독 커밋, 완료 후 사용자 `/code-review` 호출 요청

## 참고 자료
- Apple Home/Liquid Glass: apple.com/newsroom 2025-06 "delightful and elegant new software design", MacRumors Liquid Glass gallery
- Flighty: Apple Developer "Behind the Design: Flighty", blakecrosley.com "Flighty: Data Visualization Done Right", 60fps.design/apps/flighty
- Copilot Money: Apple Developer "How Copilot Money developed an interest in Swift Charts", screensdesign.com Copilot UI Breakdown, mattstromawn.com/projects/copilotmoney
