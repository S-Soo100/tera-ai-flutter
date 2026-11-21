# 화면 공통 UI 결정 (색·글자 배율·화면 꺼짐 방지·오프라인 안내·Figma 검수)

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 4단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 규칙만 추린 것은 `CLAUDE.md` "코딩 규칙 > UI"와 `.claude/rules/theme-ui.md`·`.claude/rules/figma-review.md`에 있다. 색 매핑의 상세는 [`../design-system-viva-colors.md`](../design-system-viva-colors.md).

## 현행 공통색 — Figma VIVA 변수 (2026-09-14)

**현행 공통색은 Figma `vivnanaut`의 VIVA 변수 (2026-09-14 Talk to Figma 재확인)** — 원본 17개는 `lib/core/theme/viva_colors.dart`의 `VivaColors`, 라이트 역할 매핑은 `GlassPalette.light`·`AppTheme.light`. 바닥 `#FAFAFA`, 카드·버튼 면 `#F4F4F4`, 선 `#E3E3E3`, 글자 `#1E1E1E/#3C3C3C/#626262/#949090`, 비활성 아이콘 `#B4AEAE`, 기기색 Pink/Yellow/Green/Blue/Purple `#DA4A6A/#E89E00/#228C73/#2A97DB/#636DDB`. 기존 `bodySecondary`=Labels/Tertiary, `textTertiary`=Labels/Quaternary. Main/Sub의 Dark/light는 브랜드 변형이며 앱 테마 모드가 아니다. 온습도 지표 전용색과 다크벌은 기존 값 유지. 상세 매핑·출처 범위: `docs/design-system-viva-colors.md`. 화면은 `context.glass`/`Theme.of(context)` 역할색 사용. **팔레트 필드 추가 시 선언·생성자·dark·light·copyWith·lerp 6곳 동시 수정**.

## (구) B안(Flighty 전광판)과 테마 모드

(구) B안(Flighty 전광판) — 다크/라이트 2벌, 라이트 기본(2026-08-14, A안 2차 교체) — 단색 바닥 + 카드(radius 16·그림자 없음·divider 테두리) + 데이터 라벨 소형 자간(`labelCaps`) + 큰 tabular 수치(`figure`) + 상태 시맨틱 앰버/그린/레드(`signalWarn/Ok/Alert`) + **활성=앰버**(`activeTile`) + 전광판 고정 탭바(`GlassDock`) + 세그먼트는 앰버 텍스트+밑줄. **색 토큰은 `lib/core/theme/glass_palette.dart`의 `GlassPalette`(ThemeExtension) 인스턴스 필드 — `variant_b_tokens.dart`의 미러. 소비처는 `context.glass.overlay`처럼 꺼낸다. `AppTheme.glassX` 정적 색 상수는 삭제됐으니 되살리지 말 것**(두 벌이 남으면 라이트에서 다크 값이 샌다). 모드는 시스템/라이트/다크 3단(`themeModeProvider`, Hive `app_settings/theme_mode`, **기본 라이트** `ThemeModeRepository.defaultMode`, 프로필 "화면 모드"). 공용 위젯 이름(`GlassCard`·`GlassDock` 등)은 **역사적 명칭으로 유지**되며 값만 B다(`blur` 파라미터는 no-op). 랩 A/B(`/design-test`)는 비교 페이지로 존치(설정에서도 진입, `lib/features/dev/design_lab/` 무접촉). 2단계(홈/통계/마이크레 화면 B 문법 이식)는 후속. 상세는 `docs/design-direction.md` §0. 공통 팔레트 SOT는 위 VIVA 변수 규칙을 따른다

## 글자 배율 (2026-10-01)

**글자 배율(2026-10-01, UX-06 → 같은 날 사용자 결정 "싹 다 Figma 크기")**: 전역은 `AppTextScaler`(`core/theme/app_text_scaler.dart`) = **Figma 크기 그대로(1.0)** × 휴대폰 글자 설정, 최대 2.0. 구 1.15배 기준(Figma 16→18.4)은 폐지 — 다시 키우지 말 것, 고정 `TextScaler.linear(…)`로 덮지 말 것(접근성 설정 무시). 고정 높이 행은 글자 높이에 맞춰 늘리거나(`CageControlGrid` 타일) 짧은 라벨만 제한(`GlassDock` 1.5). 회귀 검사 `test/design/text_scale_overflow_test.dart`(1.0/1.3/상한) — 새 주요 화면은 여기 추가.

## 화면 꺼짐 방지 (2026-10-16)

**화면 꺼짐 방지(2026-10-16, 0.154.5)**: `KeepScreenOn`(`shared/widgets/keep_screen_on.dart`, 잠금 `shared/providers/screen_wake_lock_provider.dart`, `wakelock_plus`)은 **보는 중일 때만** 건다 — 라이브는 `WebRtcLiveView`가 `WebRtcLivePhase.keepsScreenOn`(실패·시청 제한이면 놓음)으로, 영상은 `VideoPlayer`를 `KeepScreenOnWhilePlaying`으로 감싸 재생 중에만. 보이는지는 TickerMode, 여러 곳은 참조 수, 켜기 실패·앱 복귀 시 다시 건다. 라우트(탭) 단위로 감싸지 말 것(0.154.4에서 그렇게 했다가 빈 화면에서도 배터리를 붙잡아 되돌림). 새 영상 플레이어도 `KeepScreenOnWhilePlaying`을 쓸 것. 단 커뮤니티 피드 자동 재생(`post_card.dart`)은 제외(사용자 결정, 0.154.6 — 전체화면 재생만).

## 오프라인 안내 (2026-10-01)

**오프라인 안내(2026-10-01, UX-05)**: 화면을 덮지 않는 상단 `OfflineBanner`. 전체 차단 오버레이를 되살리지 말 것 — 서버 작업 실패는 작업별로 알린다.

## Figma 대조 검수 지시 원문 (2026-09-16)

**페이지별 필수 수치 검수 (2026-09-16 사용자 추가 지시):** 모든 페이지에서 Figma와 같은 논리 화면 크기/SafeArea로 간격·패딩, 폰트 크기/굵기/줄높이/자간, 실제 ColorSystem 색상, 아이콘 프레임과 내부 그림 크기/정렬, 버튼 위치/활성 조건/터치 영역을 확인한다. 시각적으로 비슷하다는 이유만으로 통과시키지 않는다. 원본 및 앱 측정값·수정 전후 캡처와 차이를 기록하고, 차이가 남으면 보고 후 확정한다. 원본이 확인되지 않은 항목을 검수 완료로 간주하지 않는다.

**페이지별 버튼 구조 검수 (2026-09-16 사용자 지시):** Figma의 하단 버튼이 스크롤 내부인지, 별도 영역 고정인지, 콘텐츠 위에 겹치는 플로팅인지 구분한다. 활성/비활성 조건·좌우/하단 위치·SafeArea·마지막 항목 접근성까지 확인하고 모든 페이지를 동일한 footer 구조로 일괄 치환하지 않는다. 그룹 구성원 선택의 선택 버튼은 콘텐츠 위에 고정하며 목록이 뒤로 스크롤된다.

**Figma 공통 하단 CTA 패턴 (2026-09-16 사용자 재확인):** 저장·선택 등 주요 하단 버튼은 콘텐츠 위에 떠 있는 구조를 우선 확인한다. ‘폼 끝에 있으니 스크롤 내부’로 추정하지 않는다. 원본에서 버튼 아래로 콘텐츠가 이어지는지, 하단 기준 좌표·SafeArea·키보드 위치·가려지는 마지막 입력칸의 접근성을 함께 검증한다. 개체 정보 입력은 정상/오류 상태 모두 플로팅 저장 버튼으로 확정했다. 다른 페이지도 이 기준을 필수로 대조하되 확인 없이 모든 화면의 footer를 일괄 변경하지 않는다.
