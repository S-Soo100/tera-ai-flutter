# 카메라 라이브 — 펌웨어 수정 전 앱 개선 검증 결과

작성일: 2026-09-24 · 브랜치 `feat/live-pre-firmware` · 앱 `0.133.9+338`

기획 [`2026-09-23-camera-live-pre-firmware-app-design.md`](../../superpowers/specs/2026-09-23-camera-live-pre-firmware-app-design.md)(§11 우선) · 계획 [`2026-09-23-camera-live-pre-firmware-app-implementation.md`](../../superpowers/plans/2026-09-23-camera-live-pre-firmware-app-implementation.md)

> **앱 개선 완료 ≠ 제품 안정화 완료**(기획 §7). 아래는 자동 테스트와 시뮬레이터 1대·실카메라 1대의 짧은 확인이며, 60분 시청·실기기(Android/iOS)·네트워크 전환 시험은 아직 하지 않았다.

## 1. 자동 검증

| 항목 | 결과 |
|---|---|
| `flutter analyze` | error·warning 0 (기존 info 6건은 이번 변경과 무관) |
| `flutter test` 전체 | 1180 통과 / 10 skip / 실패 0 (Task 9 시점) |
| 컨트롤러 테스트 | 15 → 29개. 병합·디바운스·망 없음·시도 예산 60초·인증 고정·정지 5/15초·통계 부재·카운터 리셋·안정 30초·집중 복구 90초·저빈도 60초 |
| 뷰 테스트(신규) | phase별 문구 키·버튼 유무·알약 우선순위 |
| 제어기 상태 | `ModuleLink` unknown/offline 판정 + "확인 중" 안내 |

## 2. 시뮬레이터 확인 (iPhone 17 · iOS 26.4 · 실카메라 `8a56bc96`, 같은 Wi-Fi)

앱 내 진단 내보내기 파일에서 발췌(UTC):

```text
15:32:28.055 gen=0 start
15:32:28.696 gen=0 answer offer_attempts=1 answer_ms=228
15:32:29.246 gen=0 connected
15:32:30.243 gen=0 first-frame           ← 진입 후 2.2초
15:32:35.527 gen=0 suspend               ← 홈 버튼
15:32:39.709 gen=1 resume / restart reason=resume
15:32:41.606 gen=2 connected
15:32:42.170 gen=2 first-frame           ← 복귀 후 2.5초
15:33:12.173 gen=2 stable                ← 30초 안정 → 백오프 초기화 (debug 로그)
```

| # | 기획 §7 회귀 기준 | 결과 |
|---|---|---|
| 1 | 최초 진입에 실패/오프라인 안내 없음 | ✅ 두 번 진입 모두 스켈레톤 → 영상. 제어기 "끊겼어요" 없음 |
| 2 | 정상 영상 중 중복 신호만으로 연결 종료 없음 | ⏳ 미시험(시뮬레이터에서 망 신호 조작 불가) — 자동 테스트로만 확인 |
| 3 | 같은 카메라 동시 offer 없음 | ⏳ 실패 화면 재현이 필요해 미시험 — 자동 테스트(`restart-merged` 2건)로만 확인 |
| 4 | 지연 close/콜백이 새 연결에 영향 없음 | ✅ 백그라운드 복귀 1회: 세대 0→2, 새 세션으로 정상 재생 |
| 5 | 사진/계정 혼선 없음 | 해당 없음(마지막 수신 사진은 P1) · 진단 파일에 계정 정보 없음 확인 |

진단 내보내기: 마이페이지 행 → 공유 시트 → 텍스트 파일 생성 확인. 파일은 iOS `Library/Caches/live-diag-*.txt`(path_provider의 iOS 임시 폴더).

## 3. 계획과 달라진 점

- **진단 내보내기 위치:** 계획은 환경설정(`/env-settings`)이었으나 그 화면은 **앱 안 진입점이 없다**(9/18 점검 미결). 마이페이지 "앱 설정"의 화면 모드 아래로 옮겼다(0.133.9).
- **망 변경 유예 조건:** 계획은 `streaming`일 때만 유예했지만 `stalled`(영상 있음)도 포함했다.
- **정지 테스트 틱 수:** 첫 샘플은 진행으로 세므로 "마지막 진행 뒤 5틱"으로 테스트를 맞췄다.

## 4. 남은 검증 (병합 후 실기기)

- Android/iOS 실기기 각각 같은 Wi-Fi 60분 시청: 정지 횟수·총 정지 시간·재접속 횟수·`stats-unknown` 발생, 배터리.
- Wi-Fi↔셀룰러 전환 10회, 5초 단절 복구, 카메라 전원 차단(→ `recovering` → 카메라 오프라인 `failed` → 전원 복귀 시 자동 연결).
- "다시 연결" 연타 시 서버 로그 offer 1건.
- 1초 getStats 비용이 크면 `kWebRtcStatsInterval` 2초로 조정하고 감지 지연(틱 × 2초)을 보고.
