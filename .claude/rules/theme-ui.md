---
paths:
  - "lib/core/theme/**"
  - "lib/shared/widgets/**"
  - "lib/shared/providers/screen_wake_lock_provider.dart"
  - "lib/features/profile/presentation/**"
  - "lib/features/dev/design_lab/**"
  - "assets/**/*.svg"
  - "tools/prepare_redesign_assets.py"
---
# 테마·공용 위젯 규칙

색 매핑·출처: `docs/design-system-viva-colors.md`. 방향: `docs/design-direction.md`. 경위 원문: `docs/contracts/ui-common.md`. 화면 공통 금지(하드코딩 색, 고정 `TextScaler.linear`, `KeepScreenOn` 라우트 단위, 전체 차단 오버레이)는 CLAUDE.md에 있다.

- 공통색 원본은 `VivaColors`(`viva_colors.dart`), 라이트 역할 매핑은 `GlassPalette.light`·`AppTheme.light`.
- 팔레트 필드를 추가하면 선언·생성자·dark·light·copyWith·lerp **6곳을 같이** 고친다.
- `AppTheme.glassX` 정적 색 상수를 되살리지 않는다(두 벌이 남으면 라이트에서 다크 값이 샌다).
- `GlassCard`·`GlassDock` 같은 이름은 역사적 명칭이다(값만 바뀜, `blur`는 no-op). Main/Sub의 Dark/light는 브랜드 변형이지 앱 테마 모드가 아니다. 온습도 지표 전용색과 다크벌은 기존 값을 유지한다.
- `lib/features/dev/design_lab/`은 비교용 랩이다. 테마를 바꿀 때 손대지 않는다.
- Final Design runtime SVG의 불투명 alpha mask는 흰 mask로 정규화한다(원본 export는 보존). 신규 역할색: `envTempValue/envHumidValue`, `envTempPeak/envHumidPeak`, `envBarNeutral/envBarMinimum`, `navSelected/navUnselected`.
- 글자 배율은 `AppTextScaler` = Figma 크기(1.0) × 휴대폰 설정, 최대 2.0. 1.15배 기준을 되살리지 않는다. 고정 높이 행은 글자 높이에 맞춰 늘리거나 짧은 라벨만 제한한다. 새 주요 화면은 `test/design/text_scale_overflow_test.dart`에 추가한다.
- `KeepScreenOn`은 보는 중일 때만 건다(보이는지는 TickerMode, 여러 곳은 참조 수, 켜기 실패·앱 복귀 시 다시 건다). 영상은 `KeepScreenOnWhilePlaying`으로 감싼다. 커뮤니티 피드 자동 재생은 제외(사용자 결정).
- `MyPageRow`는 선 없는 흰 면 r12다. 테두리를 되살리지 않는다(Figma에 없음).
- 공용 입력은 `VivaTextField`/`VivaCheckRow`, 확인 모달은 `showVivaModal`.
