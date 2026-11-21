# 계약 문서

기능별 계약(서버·펌웨어와의 약속, 앱이 지키는 규칙)과 그 경위·수치를 모은다. 2026-11-21에 `CLAUDE.md`의 긴 문단을 문장 그대로 옮겨 만들었다.
날짜별 기록(`docs/handoffs/`·`docs/references/`·`docs/design-audits/`)은 그 시점의 문서이고, 주제별 현재 서술은 여기에 이어서 적는다.

| 문서 | 주제 |
|---|---|
| [cage-control.md](cage-control.md) | 제어 명령 경유·절대 명령·확인 대기·분무·LED·팬 타이머·예약·mist 블랙아웃 회신 |
| [camera-live.md](camera-live.md) | 라이브 연결 안정성(세대·재연결·기록) |
| [camera-live-limit.md](camera-live-limit.md) | 라이브 시청 제한(15분·쉼·한 기기) |
| [camera-rotate.md](camera-rotate.md) | 카메라 180° 회전 |
| [device-health.md](device-health.md) | 카메라·사육장 재시작, Wi-Fi 약함 |
| [env-telemetry.md](env-telemetry.md) | 온습도 표시·온도 보정·추이 차트·목표 온습도 |
| [clips-highlights.md](clips-highlights.md) | 영상 목록·플레이어 방향·하이라이트 정책 |
| [push-consent.md](push-consent.md) | 알림 권한 프리팝업 |
| [ui-common.md](ui-common.md) | 색·글자 배율·화면 꺼짐 방지·오프라인 안내·Figma 검수 지시 원문 |

BLE Wi-Fi 프로비저닝은 [`../ble-provisioning-protocol.md`](../ble-provisioning-protocol.md), 화면·라우트 구성 스냅샷은 [`../architecture/routes-and-features.md`](../architecture/routes-and-features.md).
