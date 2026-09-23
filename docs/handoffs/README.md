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
| 카메라 회전 | [9/9 후속 통보](../handoff-update-camera-rotate180-2026-09-09.md) | 재부팅 후 적용 계약과 라이브 멈춤 수정의 실기기 미확인 기록 포함. 최신 토글 노출 정책은 CLAUDE.md 우선 |

이 표의 서버·펌웨어 상태는 보관 문서와 이번 대화 기준이며 이번 정리에서 운영 환경을 재검증하지 않았습니다. `docs/references/`의 원문 회신과 나머지 인계 문서는 완료 근거·현행 계약 대체 여부가 확실하지 않아 유지했습니다.

## 삭제한 전달문 5개

| 삭제 파일 | 근거 / 남은 기준 |
|---|---|
| `docs/handoffs/2026-09-15-petcam-lab-highlight-slack-script.md` | 승인 스냅샷 요구 철회. 9/19 정책 v2 요청으로 대체 |
| `docs/handoffs/2026-09-15-terra-server-slack-script.md` | 상세 이벤트 요청서와 중복. 후속 회신·결정 답신 보존 |
| `docs/handoffs/2026-09-16-server-request-led-timer-schedule-payload.md` | 9/16 결정 답신 §2에서 LED 타이머 제거·예약 payload 유지로 결정 완료 |
| `docs/handoff-camera-rotate180-2026-09-08.md` | 회신·구현 및 9/9 적용 시점 계약으로 대체 |
| `docs/handoff-reply-camera-rotate180-2026-09-08.md` | 즉시 적용·토글 숨김 등 옛 설명이 현행과 충돌. CLAUDE.md 계약 요약과 9/9 후속 통보 보존 |

과거 문서의 인용은 삭제 전 커밋을 가리키는 GitHub 링크로 변경했고, 현재 작업의 진입 링크는 후속 문서로 연결했습니다. 삭제한 내용은 아래 커밋의 git 이력에서 확인할 수 있습니다.

```bash
git show ba747f1606eacffdec8d14ee7da5266e2c913714:docs/handoffs/2026-09-15-terra-server-slack-script.md
```
