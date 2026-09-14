# VIVA 컬러 시스템

2026-09-14 사용자 제공 Figma `vivnanaut` → `VIVA` 변수 화면 기준.
원본은 `lib/core/theme/viva_colors.dart`, 화면 역할 매핑은 `GlassPalette.light`와
`AppTheme.light`에서 관리한다. 화면 위젯은 `context.glass` 또는
`Theme.of(context).colorScheme`을 사용한다.

| Figma 변수 | HEX | 원본 토큰 | 라이트 역할 |
|---|---|---|---|
| Labels/Primary | #1E1E1E | labelPrimary | textPrimary / textTitle |
| Labels/Secondary | #3C3C3C | labelSecondary | textSecondary / textBody |
| Labels/Tertiary | #626262 | labelTertiary | bodySecondary / navUnselected / envBarNeutral |
| Labels/Quaternary | #949090 | labelQuaternary | textTertiary / textMuted |
| Fill/Icon | #B4AEAE | fillIcon | deviceOff |
| Fill/Line | #E3E3E3 | fillLine | border / outline / lineColor |
| Fill/Button | #F4F4F4 | fillButton | surfaceTint / segmentTrack / overlayFaint / surfaceMuted |
| Fill/Back | #FAFAFA | fillBack | wallpaper / overlayStrong / surfaceHeader |
| Color/Main_Dark | #C00306 | mainDark | navSelected |
| Color/Main_light | #D61619 | mainLight | signalAlert / brandRed |
| Color/Sub_dark | #192553 | subDark | brandNavy / Material primary |
| Color/Sub_light | #2E408C | subLight | 브랜드 보조색 |
| Color/Pink | #DA4A6A | pink | 원본색 등록, 화면 용도 미확인 |
| Color/Yellow | #E89E00 | yellow | signalWarn / deviceLed / activeTile / heaterTint |

온습도 상세는 VIVA 브랜드색과 별도로 Figma 프레임의 지표색을 그대로 쓴다.

| 상세 역할 | HEX | 팔레트 역할 |
|---|---|---|
| 온도 대표값·최고 막대·아이콘 | #F85478 | envTempValue / envTempPeak / tempAccent |
| 습도 대표값·최고 막대·아이콘 | #00B2F3 | envHumidValue / envHumidPeak / humidAccent |
| 일반 막대 | #626262 | envBarNeutral |
| 최저 막대 | #A9B3BE | envBarMinimum |

## 적용 원칙

- 스크린샷에 보이는 14개만 전사했다. 잘린 하단 변수는 추측하지 않았다.
- `Dark`/`light`는 브랜드색 변형 이름이다. 앱 다크모드용 색이라는 뜻이 아니다.
- 다크모드는 기존 도출 팔레트를 유지한다. 원본 라이트 토큰을 다크 화면에서 직접 사용하지 않는다.
- 기존 `textTertiary`는 가장 흐린 보조 글자 역할이므로 Labels/Quaternary에 연결한다.
  Labels/Tertiary는 기존 `bodySecondary`다. 기존 소비처의 위계를 보존한다.
- 카드·탭바는 흰색을 유지하고 페이지 바닥은 Fill/Back을 사용한다.
- 브랜드 원본 이름이 Material 역할을 자동 결정하지 않는다. 기존 남색 버튼과
  빨강 선택 탭은 유지하고, 온습도 상세는 별도 지표색을 사용한다.
- VIVA 변수의 Pink `#DA4A6A`와 온도 지표색 `#F85478`은 다른 색이다.
  스크린샷 밖의 기기색·배지색과 다크 도출값은 기존 정의를 유지한다.
- `/design-test`의 A/B 비교용 토큰은 독립된 과거 디자인이므로 수정하지 않는다.

## 유저 체험 확인

1. [화면] 홈 진입: #FAFAFA 바닥 위 카드와 4단계 글자 위계가 보인다.
2. [조작] 카메라 탭 이동 및 기간 선택 버튼 열기.
3. [반응] 공통 선·버튼 면·보조 글자가 홈과 같은 VIVA 역할색으로 표시된다.
4. [감정] 화면을 바꿔도 동일한 정보 위계를 자연스럽게 인식한다.

이 흐름은 컬러 변경의 목표이며 실기기 검증 결과를 뜻하지 않는다.
