---
paths:
  - "lib/features/my_cage/**/webrtc_*.dart"
  - "lib/features/my_cage/**/live_limit*.dart"
  - "lib/features/my_cage/domain/live_view_session.dart"
  - "lib/features/my_cage/presentation/my_cage_providers.dart"
  - "lib/features/my_cage/presentation/widgets/camera_live_area.dart"
  - "lib/features/my_cage/presentation/camera_live_fullscreen_screen.dart"
  - "lib/core/app_installation.dart"
---
# 카메라 라이브 규칙

경위·수치·날짜: `docs/contracts/camera-live.md`(연결), `docs/contracts/camera-live-limit.md`(시청 제한), `docs/contracts/device-health.md`(재시작).

## 연결 (`webrtc_live_controller.dart`)
- 연결 1회 = 세대(`_gen`). 재연결·백그라운드·dispose마다 세대를 올리고, 이전 세대의 콜백·ICE 폴링·타이머·offer 응답은 무시한다.
- LIVE(`streaming`)는 첫 프레임 이후다. ICE connected는 `waitingVideo`.
- `stalled`는 영상을 유지한 채 안내, `recovering`은 버튼 없는 자동 복구다. `failed`는 예산 소진·카메라 오프라인·망 없음·인증 실패만. 401/403은 재시도하지 않는다. 통계 부재는 `statsUnknown`으로만 다룬다.
- 백오프 초기화는 영상 30초 안정(`stable`)과 수동 재시도에서만 한다.
- DB `is_online=false`면 offer를 생략하고 바로 오프라인 안내를 띄운다. 수동 재시도·망 복귀만 `_forceAttempt`로 한 번 강제한다.
- 앱 백그라운드(paused)는 즉시 연결을 내리고 복귀 시 재연결한다. 화면에 안 보이는 것(다른 탭·불투명 화면)은 시청 기록을 즉시 닫고 30초 뒤 연결을 내린다.
- 카메라 탭 스와이프는 `ScrollEndNotification`에서 확정한다(`onPageChanged`는 절반 지점에서 불린다).
- 새 "자동 재연결 멈춤" 상태는 `_held`에 더한다. 진입점마다 따로 검사하지 않는다.
- 라이브 세션·heartbeat 구독을 `camerasProvider`에 합치지 않는다(생존 신호만 바뀐 갱신을 일부러 버리는 곳이다).

## 기록 (Supabase 직결)
- `webrtc_connect_logs`·`webrtc_view_logs` INSERT에 `.select()`를 붙이지 않는다(SELECT 정책이 없어 RETURNING이 RLS 위반).

## 시청 제한
- offer에 `viewer_id`(설치 ID, `core/app_installation.dart`)·`takeover`를 싣는다. `viewer_label`은 보내지도 표시하지도 않는다(안내는 항상 "다른 기기").
- `limited`에서는 **자동 재시도 금지.** `retry()`/`takeover()`만 푼다.
- `takeover: true`는 사용자가 고른 그 세대 하나만(`_takeoverGen`). 자동 재연결이 가져오면 두 기기가 핑퐁한다.
- 가져가짐 판정은 `live_viewer_id`가 내 설치 ID와 다를 때만 한다. offer 대기 중 가져가져 세션 ID가 없으면 실패·504 시점에 마지막 행으로 다시 본다(`_heldByOther`).
- `taken_over`·`time_limit`으로 끝날 때는 서버에 close를 보내지 않고 로컬만 정리한다.
- 409 모달은 제한당 한 번, 보이는 뷰에서만 띄운다(`takeInUsePrompt`). 409 모달·쉼 문구는 사용자가 확정한 문구다.
- 제한 중에는 시청 기록을 닫는다.

## 재시작 중
- `WebRtcLivePhase.rebooting`에서는 모든 재연결을 하지 않는다. 재시작 중 `takeover()`는 버린다.
- 실패 화면의 [카메라 재시작]은 무응답·영상 없음·멈춤에서만 보인다(`rebootErrorKeys`).
- 세로 확대 화면의 실패 안내엔 재시작 버튼이 없다(`showReboot:false`). 가로 전체화면엔 Wi-Fi·재시작 버튼이 없다.
- 확대 화면의 회전 버튼은 녹화 중엔 막는다(카메라가 재부팅하며 녹화가 끊긴다). 회전은 REST `PATCH /cameras/{id}`만.
