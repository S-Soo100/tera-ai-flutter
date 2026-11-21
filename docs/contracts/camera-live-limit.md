# 카메라 라이브 시청 제한 계약

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 2단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 이 주제의 경위·수치·날짜 기록은 앞으로 이 문서에 이어서 적는다. 코드와 다르면 코드를 확인한 뒤 이 문서를 고친다.
> 문단 안의 `home/…`·`my_cage/…` 같은 경로는 `lib/features/` 기준, `shared/…`·`core/…`는 `lib/` 기준이다.

## 라이브 시청 제한 (2026-09-29)

**라이브 시청 제한**(2026-09-29, 0.144.0, 서버 `terra-server` `docs/APP_LIVE_VIEW_LIMIT_2026-09-30.md` — 한 번에 15분·끝나면 5분 쉼·한 기기, **서버 배포·migration 전**): offer에 `viewer_id`(= 푸시와 같은 설치 ID `core/app_installation.dart`, `liveViewerIdProvider`)·`takeover`를 싣는다. **기기 이름(`viewer_label`)은 보내지도 표시하지도 않는다**(2026-09-30 사용자 결정 — 안내는 항상 "다른 기기", `device_info_plus` 제거). 409 `live_in_use`·429 `live_cooldown`/`rate_limited`(구 서버 문자열 429 포함) → 단계 `limited`(`WebRtcLiveState.limit`, 도메인 `domain/live_limit.dart`). 보는 중 끊김은 `cameraLiveSessionProvider`(`presentation/live_limit_providers.dart`, 그 카메라 행 UPDATE만, `camerasProvider`에 넣지 말 것)로 `taken_over`·`time_limit`을 받아 **close 없이** 정리 — 가져가짐은 **`live_viewer_id`가 내 설치 ID와 다를 때만**(`live_end_reason`은 다음 일반 시청까지 남아 우리 옛 행이 늦게 오면 자기 자신에게 쫓겨난다), offer 대기 중 가져가져 세션 ID가 없던 경우는 실패·504 시점에 마지막 행으로 다시 본다(`_heldByOther`). **`limited`에선 자동 재시도 금지** — 망·복귀·타이머 모두 막히고(`_restart`가 거절) `retry()`/`takeover()`만 푼다. `takeover: true`는 사용자가 고른 **그 세대 하나만**(`_takeoverGen` — offer 전에 죽으면 이후 자동 재연결은 가져오지 않는다)(자동 재연결이 가져오면 두 기기 핑퐁). 409 문구는 사용자 확정: 모달 "시청 기기 전환하기 / 다른 기기에서 시청 중입니다. 이 기기로 전환하면 다른 기기의 시청이 종료됩니다. / 취소·이 기기로 시청"(`takeInUsePrompt`로 제한당 한 번, 보이는 뷰만), 쉼 문구는 owner 결정 "녹화 진행을 위해 카메라 라이브가 절전모드로 들어갑니다", 끝나기 1분 전 알약(`live_until`). 제한 중엔 시청 기록(`webrtc_view_logs`)을 닫는다.
