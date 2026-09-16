# 이관훈님 전달용 — `device.action.skipped` 발송 시작해도 됩니다

작성일: 2026-09-16

결정 답신 §4에서 "앱 수신부 준비 뒤 신호를 드리겠다"고 한 그 신호입니다.

- 앱 수신 endpoint(`notification-ingest`)가 `device.action.skipped`를 받습니다(앱 0.108.5+270). 계약은 결정 답신 §4 그대로입니다.
  - `execution_source: "schedule"`, `execution_phase: "skipped"`, `outcome: "skipped"`, `result: "guard_skipped"`
  - `guard` 객체는 선택. 있으면 `{ "kind", "metric": "temperature"|"humidity", "threshold", "value" }` — 알림 문구에 값이 들어갑니다.
  - `event_id`: `command:{가드 감사 행 id}:skipped`
- 발행 조건은 기존 3종과 같은 워커에서 `source = 'guard'` 행만 추가하시면 됩니다.
- secret은 기존 3종과 같은 값을 씁니다. 별도 전달 없음.

스테이징 검증 때 started/ended/failed 3종에 skipped 1건을 더해 4종으로 보겠습니다.
