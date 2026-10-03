# 카메라 재부팅 API가 성공해도 `published: false`를 돌려줌 (terra-server 확인 요청)

> 작성 2026-10-03 · 앱 비바나트 0.151.0 (379) · 근거 가이드 `docs/references/2026-10-03-camera-reboot-app-web-guide.md` §1

## 현상

`POST /cameras/{uuid}/reboot`가 **카메라를 실제로 재부팅시키는데도** 응답 본문이 `{"published": false, "msg_id": null}`입니다. 가이드 §1의 "`published: false` = 브로커 순간 장애, 잠시 후 재시도"와 반대입니다.

## 재현 (iOS 시뮬레이터, tester01@test.com, 카메라 3 `p4cam-3a9f61ce` / `86f3335e-4faf-42a6-a125-35488b1365d3`, 펌웨어 `fb2-p4 0.2.0-20260928`, 온라인)

| 요청 시각 (KST) | 응답 | 카메라 `clip_stats.sys` |
|---|---|---|
| 16:04:50 | 앱 기준 published≠true | 16:05:13 `reset=SW:mqtt_reboot`, `uptime_s=22` → 16:04:51 부팅 |
| 16:08:30 | `{published: false, msg_id: null}` | 16:09:09 `SW:mqtt_reboot`, `uptime_s=23` → 16:08:46 부팅 |
| 16:09:35 | `{published: false, msg_id: null}` | 16:09:39 뒤 heartbeat 끊김(재부팅) |

응답은 HTTP 200이며 3번 모두 같은 결과였습니다.

## 영향

앱은 가이드대로 `published: false`면 "잠시 후 다시 시도해 주세요"를 띄우고 재시작 대기에 들어가지 않습니다. 사용자는 실패로 알고 다시 누르게 되어 **카메라가 두 번 재부팅**되고, "재시작 중" 화면·자동 재연결도 동작하지 않습니다.

## 요청

1. 발행이 성공했으면 `published: true`와 `msg_id`를 돌려주도록 확인·수정 부탁드립니다. (예: MQTT publish 결과를 기다리는 방식·타임아웃·`is_published()` 판정 시점 등)
2. 수정 배포 시점을 알려 주시면 앱에서 다시 검증하겠습니다. 앱은 서버 수정 전까지 현재 동작을 유지합니다(2026-10-03 결정).
