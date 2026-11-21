# 카메라 180° 회전 계약

> 이 문서는 `CLAUDE.md`(커밋 `5675f3b2`)에 있던 문단을 **문장 그대로** 옮긴 것이다(2026-11-21, CLAUDE.md 축소 2단계). 문장을 다듬지 않아 날짜·버전이 섞인 긴 문단 그대로다.
> 이 주제의 경위·수치·날짜 기록은 앞으로 이 문서에 이어서 적는다. 코드와 다르면 코드를 확인한 뒤 이 문서를 고친다.
> 문단 안의 `home/…`·`my_cage/…` 같은 경로는 `lib/features/` 기준, `shared/…`·`core/…`는 `lib/` 기준이다.

## 카메라 180° 회전(설치 방향 보정)

**카메라 180° 회전(설치 방향 보정)**(2026-09-08 회신 수용, [당시 회신 이력](https://github.com/S-Soo100/tera-ai-flutter/blob/ba747f1606eacffdec8d14ee7da5266e2c913714/docs/handoff-reply-camera-rotate180-2026-09-08.md); 구 요청·회신은 2026-09-23 정리, 현행 계약은 이 문단과 9/9 후속 통보): 앱은 환경설정(`/env-settings`)의 `CameraRotateTile` 토글 하나 — REST `PATCH /cameras/{id}` body `{rotate_180: bool}`만 보낸다(**Supabase 직결 UPDATE 금지** — 서버가 MQTT `set_rotation` 발행+재연결 동기화를 책임진다). 노출은 **항상**(2026-09-23 사용자 결정 — 환경설정 타일·라이브 확대 화면 버튼 모두, `rotate180Capable` 게이팅 폐지. 구 펌웨어도 PATCH는 보내며 펌웨어가 무시할 수 있음. 세트에 카메라 없으면 타일은 비활성+이유 부제). 반영은 cameras Realtime → `camerasProvider` 캐스케이드. **서버·펌웨어 배포 완료 + E2E 검증됨(2026-09-08)** — 토글→PATCH→DB→라이브 180° 반전을 시뮬 실측으로 확인. capabilities 미보고 구 펌웨어는 토글해도 반영 안 될 수 있다(순차 플래시 중). 과거 클립 소급 불가(합의), 90°/270° 범위 밖. **R6 개정(2026-09-09, `docs/handoff-update-camera-rotate180-2026-09-09.md`)**: 적용은 즉시가 아니라 **카메라 재부팅 후 ~20초**(Bayer 재설정이 스트리밍 중 불가) — 라이브 시청 중 토글이면 끊겼다 자동 재연결(기존 백오프 로직), 그동안 오프라인처럼 보임. 앱은 토글 성공 스낵바(`camera_rotate_applying`)로 예고, 그 외 변경 없음.
