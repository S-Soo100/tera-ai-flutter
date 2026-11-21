# 진행 중인 인계와 정리 기록

2026-09-23 기준 문서 정리 결과입니다. ‘전달 완료’와 ‘배포·검증 완료’를 구분합니다. 날짜가 오래됐다는 이유만으로 미완료 계약·회신을 삭제하지 않았습니다.

## 지금 확인할 문서

| 주제 | 진입 문서 | 보존 이유 / 상태 |
|---|---|---|
| 카메라 라이브 안정화 | [펌웨어 종합 요청서](2026-09-23-camera-live-stability-firmware-request.md) | 사용자 전달 완료. 펌웨어 회신·수정·실기기 검증 필요 |
| 펌웨어 수정 전 앱 개선 | [앱 기획서](../superpowers/specs/2026-09-23-camera-live-pre-firmware-app-design.md) | 사용자가 별도 작업에서 구현 계획 수립 중이라고 확인 |
| TURN·연결 로그 | [9/22 서버 요청](2026-09-22-camera-live-stability-server-requests.md) | TURN 운영 확인과 상세 요청 이력 보존. 로그 구현·과거 첫 프레임 설명은 위 최신 종합 요청서 §4를 함께 읽을 것 |
| 분무 5/10초 | [서버·펌웨어 요청](2026-09-23-mist-duration-5-7-10-server-request.md) | 서버 허용값·펌웨어 제한 변경 대기. 파일명의 7초가 현행 정책을 뜻하지 않음 |
| 그룹·기기 해제·RPC | [회신 반영 원장](2026-09-16-assumed-server-contracts.md) | 배포 확인·잔여 계약 추적에 필요. 원장에 연결된 요청서·결정 답신·SQL 회신도 보존 |
| 재설계 재개·담당 구분 | [체크포인트](2026-09-15-redesign-session-checkpoint.md), [담당 구분](2026-09-15-redesign-server-work-split.md) | CLAUDE.md에서 참조하며 외부 의존·전달 이력 포함. 과거 구현 상태와 현행 main을 구분 |
| 알림 배포·기기 이벤트 | [배포 체크리스트](2026-09-15-fcm-deployment-checklist.md), [재개 기록](2026-09-15-fcm-session-checkpoint.md), [이벤트 요청](2026-09-15-terra-server-notification-events-request.md) | 실기기 수신·생산자 연동·미확인 후속 작업이 남아 있음. 후속 9/16 회신·결정을 우선 확인 |
| 하이라이트 | [정책 v2 요청](2026-09-19-petcam-lab-highlight-policy-v2-request.md) | 구 승인 스냅샷 정책을 대체. 배포 확인 기록과 남은 요청 보존 |
| 마이페이지 | [서버 요청](2026-09-16-mypage-server-requests.md) | 서버 의존 항목의 완료 근거가 확인되지 않아 보존 |
| 자동 환기·분무 | [서버·펌웨어 요청](2026-11-05-auto-vent-mist-request.md), [앱 계획](../superpowers/plans/2026-11-05-auto-env-app.md) | 서버 회신(계약 확정) → 앱 Task 1~4 main 병합(0.174.0+479, 토글 숨김). §7 회신 받음(§8 — 습도 1시간 연속으로 서버 변경, 합치기 창 8분 반영). 남은 것: 테스트 기기 UUID 전달, 예약 실행 중 앱 판정(D2), 서버 전체 켬 → Task 5 출시 |
| LCD 문구 | [서버 요청](2026-10-06-lcd-text-server-request.md) | 회신 반영(0.154.0, 서버 값 우선)·서버 배포 완료(10/7). 실기기 검증 대기 |
| 카메라 회전 | [9/9 후속 통보](../handoff-update-camera-rotate180-2026-09-09.md) | 재부팅 후 적용 계약과 라이브 멈춤 수정의 실기기 미확인 기록 포함. 최신 토글 노출 정책은 [카메라 회전 계약](../contracts/camera-rotate.md) 우선 |

이 표의 서버·펌웨어 상태는 보관 문서와 이번 대화 기준이며 이번 정리에서 운영 환경을 재검증하지 않았습니다. `docs/references/`의 원문 회신과 나머지 인계 문서는 완료 근거·현행 계약 대체 여부가 확실하지 않아 유지했습니다.

## 삭제한 전달문 5개

| 삭제 파일 | 근거 / 남은 기준 |
|---|---|
| `docs/handoffs/2026-09-15-petcam-lab-highlight-slack-script.md` | 승인 스냅샷 요구 철회. 9/19 정책 v2 요청으로 대체 |
| `docs/handoffs/2026-09-15-terra-server-slack-script.md` | 상세 이벤트 요청서와 중복. 후속 회신·결정 답신 보존 |
| `docs/handoffs/2026-09-16-server-request-led-timer-schedule-payload.md` | 9/16 결정 답신 §2에서 LED 타이머 제거·예약 payload 유지로 결정 완료 |
| `docs/handoff-camera-rotate180-2026-09-08.md` | 회신·구현 및 9/9 적용 시점 계약으로 대체 |
| `docs/handoff-reply-camera-rotate180-2026-09-08.md` | 즉시 적용·토글 숨김 등 옛 설명이 현행과 충돌. [카메라 회전 계약](../contracts/camera-rotate.md)과 9/9 후속 통보 보존 |

과거 문서의 인용은 삭제 전 커밋을 가리키는 GitHub 링크로 변경했고, 현재 작업의 진입 링크는 후속 문서로 연결했습니다. 삭제한 내용은 아래 커밋의 git 이력에서 확인할 수 있습니다.

```bash
git show ba747f1606eacffdec8d14ee7da5266e2c913714:docs/handoffs/2026-09-15-terra-server-slack-script.md
```

## 재설계 확정 기준·재개 순서 (CLAUDE.md에서 옮김)

`CLAUDE.md`(커밋 `5675f3b2`)의 해당 문단을 문장 그대로 옮겼다(2026-11-21, CLAUDE.md 축소 2단계). 2026-09-15 재설계 당시의 기준 문서와 외부 의존 상태다.

새 디자인·동작의 확정 기준은 [`docs/superpowers/specs/2026-09-15-figma-redesign-approved-design.md`](../../docs/superpowers/specs/2026-09-15-figma-redesign-approved-design.md)다. 해당 재설계 구현에서는 아래 과거 결정과 충돌할 경우 이 확정 기획을 우선한다.

[7단계 구현계획](../../docs/superpowers/plans/2026-09-15-figma-redesign-implementation.md), [서버 담당·직접 수행 구분](../../docs/handoffs/2026-09-15-redesign-server-work-split.md)을 함께 읽는다.

사용자가 전체 자동 구현을 승인했다. (구)`codex/figma-redesign-20260915` 작업 트리(2026-09-18 main 병합 후 삭제)에 Home·Camera·MyCre·통합 BLE·그룹/개체 관리·메모/계정별 숨김 UI와 저장소·라우트를 구현했다. [구현 결과와 검증](../../docs/design-audits/2026-09-15-redesign-implementation-results.md)을 현재 상태 기준으로 읽는다.

petcam-lab은 `owner-activity-v1` API 배포를 완료했다. [수신 계약](../../docs/references/2026-09-15-petcam-activity-handoff.md). 이관훈님 회신의 soft unlink/공통 그룹 write/온습도 count/푸시 보완은 미배포다. 앱 전용 SQL은 `supabase/drafts/`에 검토용으로 저장하고 격리 DB에서 검증했으며 **운영 DB는 변경하지 않았다**. UI 구현과 운영 사용 완료를 구분한다.

재개 시 [재설계 세션 체크포인트](../../docs/handoffs/2026-09-15-redesign-session-checkpoint.md)를 먼저 읽는다. 최신 그룹명 우선 표시·첫 기본 이름 번호 1 규칙과 외부 전달 상태를 보존한다.
