# Final Design 색상 전수 감사 — 2026-09-14

## 범위와 원본

- Figma 파일 `vivnanaut`, 페이지 `Final Design`(`0:1`).
- Talk to Figma MCP로 Home, Camera, CreActivity, Asset_v2, 기기 연결v3 섹션과
  홈·온습도·카메라·하이라이트·북마크·플레이어·MyCre 핵심 프레임을 다시 읽었다.
- VIVA 변수 화면에서 17개 원본값을 교차 확인했다.
- 폐기 섹션(`Refer`, `앱 ASIS 0807`, `버린/세이브시안`, 기기 연결v1/v2)은
  현행 앱의 수정 근거로 사용하지 않았다.

## 발견한 원인과 수정

| 발견 | Figma 근거 | 수정 |
|---|---|---|
| Green/Blue/Purple 3개가 코드 원본 토큰에서 누락 | VIVA 컬렉션 17 variables | `VivaColors`에 `#228C73/#2A97DB/#636DDB` 등록 |
| 표준 카드 면이 흰색으로 남음 | Asset_v2 Card, NewHighlight, Home 기기 타일 `#F4F4F4` | 라이트 `overlay`를 Fill/Button에 연결 |
| 켜진 기기 타일에 구 파스텔 배경 사용 | Home의 켜짐/꺼짐 타일 모두 `#F4F4F4` | 라이트 기기 배경 5종을 Fill/Button으로 통일 |
| 분무·히터 아이콘이 습도색/도출색 사용 | 일간 분무 `#2A97DB`, Asset 히터 `#DA4A6A` | Blue/Pink 역할 토큰으로 교체 |
| 라이트 기본 본문이 `#1A1A1A` | VIVA Labels/Primary `#1E1E1E` | 기본 TextTheme을 Labels/Primary에 연결 |
| MyCre 성별 태그가 구 서브컬러 사용 | Asset_v2 수컷 `#636DDB`, 암컷 `#D61619`, 흰 태그 면 | Purple/Main_light 및 흰 표면으로 교체 |
| 기기 온라인 점이 Material Green 사용 | VIVA Green `#228C73` | `signalOk` 역할색 사용 |
| 하단 탭바 상단선이 Button 면색 사용 | Navigation stroke `#E3E3E3` | Fill/Line 역할색 사용 |
| 새 하이라이트 날짜·플레이어 시각이 일반 본문색 사용 | 두 프레임 모두 `#545454`, 배너 제목 `#000000` | 밝기별 `mediaMeta/mediaTitle` 역할색 추가 |

온습도 상세는 2026-09-14 사용자 비교에서 확정한 전용 지표색
`#F85478/#00B2F3`, 일반 `#626262`, 최저 `#A9B3BE`를 유지한다. 이 값은
VIVA의 Pink/Blue 및 과거 프레임의 Main/Sub 색과 섞지 않는다.

영상 위 흰색·검정 스크림, 시스템 상태바 흑백, 썸네일 이미지 색은 고정 대비 또는
콘텐츠이므로 오류로 분류하지 않았다. Figma에 없는 다크 팔레트는 기존 도출값을
유지했다.

## 검증

- `flutter test --no-pub`: 660 passed, 1 skipped, 0 failed.
- `flutter analyze --no-pub`: error 0, warning 0. 기존 info 7건만 남음.
- iPhone 17 시뮬레이터: Home, 온습도 일간·주간, Camera, MyCre를 비교하고
  최종 변경 후 Camera → 하이라이트 → 세로 플레이어를 다시 확인했다.
- 로그인 계정에서 하이라이트 홈 라벨은 `어젯밤`, 북마크 홈 라벨은 `오늘`로
  표시됐다. 새 하이라이트 도착 카드는 이미 읽은 계정 상태라 화면 재현 대신
  `mediaTitle/mediaMeta` 팔레트 회귀 테스트로 검증했다.
