---
paths:
  - "lib/features/my_cage/**/highlight*.dart"
  - "lib/features/my_cage/data/passed_clip_feed_source.dart"
  - "lib/features/my_cage/data/motion_clip_repository.dart"
  - "lib/features/my_cage/data/clip_repository.dart"
  - "lib/features/my_cage/data/thumbnail_cache_repository.dart"
  - "lib/features/my_cage/presentation/my_cage_providers.dart"
  - "lib/features/my_cage/presentation/crecam_screen.dart"
  - "lib/features/my_cage/presentation/bookmarks_screen.dart"
  - "lib/features/my_cage/presentation/clip_*.dart"
  - "lib/features/my_cage/presentation/motion_clip_player_screen.dart"
  - "lib/features/my_cage/presentation/player_view_providers.dart"
  - "lib/features/my_cage/presentation/widgets/clip_*.dart"
  - "lib/features/my_pets/**/*activity*"
---
# 영상 목록·플레이어·하이라이트 규칙

경위·수치·날짜: `docs/contracts/clips-highlights.md`. 정책 SOT: `docs/superpowers/specs/2026-09-19-highlight-policy-v2-design.md`.

- 카메라 탭 전체 영상 목록은 하이라이트 규칙 통과분 전부다(`PassedClipFeedSource`, 그리드·필름스트립 공용 `passedClipFeedSourceProvider`). 미통과 영상은 숨긴다(북마크·커뮤니티는 무관).
- **판정 전 영상은 보여준다.** 판정 전 구간을 끝까지 다 읽은 뒤 통과 목록으로 넘어간다(맨 위 한 페이지만 얹으면 가운데가 뚫린다).
- 활동시간은 통과 영상 길이의 합이다(`PassedClipActivityRepository`). `HttpActivityRepository`는 계약 디코더로만 남아 있다.
- 하이라이트는 밤 D 20:00~D+1 08:00 KST만, D+2일 08:00 KST에 공개한다. 앱이 시간으로 게이트하고, 서버 publication이 없으면 그 시각으로 합성한다(`applyNightPolicy`). KST는 UTC+9 고정 계산. 검수 지연은 기다리지 않는다.
- 카드 "업데이트 N일 전"은 공개 시각(서버 값 또는 앱 합성)의 최댓값이다(`latestHighlightAtProvider`). 촬영 시각을 도착으로 쓰지 않는다. 안 본 최신 공개 묶음이 있으면 "새 하이라이트"(`latestPublishedHighlight`, 배너와 같은 읽음 기준).
- 읽음은 실제 재생 진전으로 처리한다.
- 영상 목록은 기본 전체 기간, 60개 복합 커서 pagination, 로컬 썸네일 캐시 200MB. 카메라 상태 갱신이 feed를 초기화하면 안 된다.
- 플레이어·라이브 확대는 세로 진입, 명시 버튼으로 가로 전환(`PlayerOrientationController`). 커뮤니티 플레이어는 이 결정의 범위 밖이다.
- 활동·클립의 하루는 07:00~익일 07:00(`DayWindow`)이다.
- 미결: 어젯밤 리포트의 하이라이트 영역은 현행 유지(기획서 §6).
