# 카메라 라이브 — 펌웨어 수정 전 앱 개선 구현 계획서

> **구현 방식 (CAOF):** Standard 트랙(기존 feature 개선, 되돌리기 비용 = 라이브 연결 정책). 메인이 task 단위로 직접 구현한다. 체크박스(`- [ ]`)로 진행을 추적한다.
>
> **기준 문서:** [기획서](../specs/2026-09-23-camera-live-pre-firmware-app-design.md) — **§11 코드 대조 보완이 본문보다 우선.** 기준 커밋 `79d84f6`, 앱 `0.132.2+328`.
>
> **범위:** 기획서 "우선 구현" 묶음(A1~A5, 상태 표시 분리, 제어기 미확인 분리, 로컬 진단). **P1(ICE 수집 비교·마지막 수신 사진)과 펌웨어 회신 이후 항목은 이 계획서에 없다** — 이 계획을 실기기로 검증한 뒤 별도 계획.

**Goal:** 펌웨어·서버 API를 바꾸지 않고, 앱이 스스로 만드는 중복 재접속·불필요한 끊김을 없애고, 연결 상태를 "연결 중 / 자동 복구 중 / 연결 실패"로 정직하게 보여준다.

**Architecture:** `WebRtcLiveController`(StateNotifier, 카메라별 family) 한 곳이 연결 세대·타이머·재시도를 조정한다. 이번 변경은 (1) 세대 기반 격리를 유지한 채 재시작 병합·네트워크 디바운스·시간 예산을 컨트롤러에 추가하고, (2) phase에 `stalled`/`recovering`을 더해 뷰가 자동 복구와 최종 실패를 구분하며, (3) 제어기 온라인 판정을 3값(`ModuleLink`)으로 바꾸고, (4) 메모리 진단 버퍼를 환경설정에서 내보낸다. 원격 로그(`webrtc_connect_logs`) 계약은 손대지 않는다.

**Tech Stack:** Flutter + Riverpod(StateNotifier) + flutter_webrtc 1.4.1 + connectivity_plus 7 + share_plus 13 + package_info_plus 10. 테스트는 `flutter_test`의 가짜 시계(`tester.pump(Duration)`)와 기존 가짜 피어/시그널링 하네스.

---

## 전체 파일 지도

| 파일 | 역할 | 변경 |
|---|---|---|
| `lib/features/my_cage/domain/webrtc_diag.dart` | 진단 이벤트·순환 버퍼(순수 Dart) | **신규** |
| `lib/features/my_cage/presentation/webrtc_diag_providers.dart` | 버퍼 provider(계정 전환 시 비움) | **신규** |
| `lib/features/my_cage/presentation/webrtc_live_controller.dart` | 연결 조정·세대·예산·감시·상태 | 수정(핵심) |
| `lib/features/my_cage/presentation/widgets/webrtc_live_view.dart` | phase → 화면 | 수정 |
| `lib/features/my_cage/presentation/supabase_module_providers.dart` | `ModuleLink` 3값 provider | 수정 |
| `lib/features/home/presentation/widgets/device_offline_notice.dart` | 미확인/오프라인 안내 분리 | 수정 |
| `lib/features/my_cage/presentation/widgets/live_diag_export_tile.dart` | 진단 내보내기 타일 | **신규** |
| `lib/features/my_cage/presentation/env_settings_screen.dart` | 타일 등록 | 수정 |
| `assets/l10n/ko.json` | 문구 | 수정 |
| `test/features/my_cage/webrtc_live_controller_test.dart` | 컨트롤러 회귀 | 수정·추가 |
| `test/features/my_cage/webrtc_diag_test.dart` | 버퍼 단위 | **신규** |
| `test/features/my_cage/webrtc_live_view_test.dart` | phase별 화면 | **신규** |
| `test/features/home/device_offline_notice_test.dart` | 3값 안내 | 수정 |
| `CHANGELOG.md`, `pubspec.yaml` | 패치노트·버전 | 매 task |

**전 task 공통 규칙:**
- 커밋 전 `flutter analyze` 에러 0 + `flutter test test/features/my_cage test/features/home` 통과.
- `lib/` 변경 커밋마다 `pubspec.yaml` 버전을 올리고 CHANGELOG에 한글 항목을 같은 커밋에 넣는다. 버전은 아래 표대로(Task 1이 `feat` minor, 이후 patch).
- 하드코딩 문자열·색 금지. 로딩은 shimmer.
- **Dart 3 switch 패턴**(`case a || b`)과 record를 쓴다(프로젝트 SDK가 이미 사용 중).

| Task | 버전 |
|---|---|
| 1 | 0.133.0+329 |
| 2 | 0.133.1+330 |
| 3 | 0.133.2+331 |
| 4 | 0.133.3+332 |
| 5 | 0.133.4+333 |
| 6 | 0.133.5+334 |
| 7 | 0.133.6+335 |
| 8 | 0.133.7+336 |
| 9 | 0.133.8+337 |

---

### Task 0: 작업 트리 격리와 기준선 확인

**Context:**
- Depends on: 없음
- Inputs: main `79d84f6`
- Outputs: worktree `../tera-ai-flutter-live` 브랜치 `feat/live-pre-firmware`, 기존 테스트 통과 확인
- Must know: 같은 워킹트리에 다른 Claude 세션이 떠 있다(세션 시작 경고). **반드시 worktree로 분리**한다. `tools/git-hooks/pre-push`가 `81a5f25` 미포함 브랜치 push를 막으므로 main에서 분기하면 문제없다.
- Acceptance: `flutter test test/features/my_cage/webrtc_live_controller_test.dart` 전부 PASS(현재 15개).

- [ ] **Step 1: worktree 생성**

```bash
cd /Users/baek/myProjects/tera-ai-flutter && git worktree add -b feat/live-pre-firmware ../tera-ai-flutter-live main
```

- [ ] **Step 2: 기준선 테스트**

Run: `cd /Users/baek/myProjects/tera-ai-flutter-live && flutter pub get && flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: `All tests passed!`

이후 모든 경로는 worktree 기준이다.

---

### Task 1: 진단 이벤트 버퍼와 컨트롤러 `_diag` 훅

**Context:**
- Depends on: Task 0
- Inputs: 기획서 §6 "앱 단독으로 추가할 로컬 진단", §11.3(메모리 600건)
- Outputs: `WebRtcDiagEvent`, `WebRtcDiagBuffer`, `webrtcDiagBufferProvider`, 컨트롤러의 `_diag(event, data)`
- Must know: 컨트롤러는 시작 시 버퍼를 `ref.read`로 잡아 둔다(dispose 중 ref 사용 불가 — `_logSink`와 같은 이유). 후보 값·SDP·JWT는 절대 넣지 않는다. 테스트 하네스는 이 provider를 **반드시 override**한다(안 하면 `currentUserProvider`가 Supabase를 요구한다).
- Acceptance: `flutter test test/features/my_cage/webrtc_diag_test.dart test/features/my_cage/webrtc_live_controller_test.dart` PASS.

**Files:**
- Create: `lib/features/my_cage/domain/webrtc_diag.dart`
- Create: `lib/features/my_cage/presentation/webrtc_diag_providers.dart`
- Create: `test/features/my_cage/webrtc_diag_test.dart`
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart`
- Modify: `test/features/my_cage/webrtc_live_controller_test.dart` (하네스 override)

- [ ] **Step 1: 버퍼 단위 테스트 작성**

`test/features/my_cage/webrtc_diag_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/domain/webrtc_diag.dart';

WebRtcDiagEvent _e(int i, {Map<String, Object?> data = const {}}) =>
    WebRtcDiagEvent(
      at: DateTime.utc(2026, 9, 23, 1, 0, i),
      cameraId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      gen: i,
      event: 'ev$i',
      data: data,
    );

void main() {
  test('용량을 넘으면 오래된 것부터 버린다', () {
    final b = WebRtcDiagBuffer(capacity: 3);
    for (var i = 0; i < 5; i++) {
      b.add(_e(i));
    }
    expect(b.events.map((e) => e.event), ['ev2', 'ev3', 'ev4']);
  });

  test('한 줄 형식 — UTC 시각·카메라 앞 8자·세대·이벤트·데이터', () {
    final line = _e(7, data: {'delay_s': 3, 'reason': 'timer'}).toLine();
    expect(line,
        '2026-09-23T01:00:07.000Z cam=aaaaaaaa gen=7 ev7 delay_s=3 reason=timer');
  });

  test('내보내기 — 헤더 한 줄 + 이벤트 줄, 비우면 빈 문자열', () {
    final b = WebRtcDiagBuffer()
      ..add(_e(1))
      ..add(_e(2));
    final out = b.export(header: 'vivanaut 0.133.0');
    expect(out.split('\n'), hasLength(3));
    expect(out, startsWith('vivanaut 0.133.0\n'));
    b.clear();
    expect(b.events, isEmpty);
    expect(b.export(), '');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/webrtc_diag_test.dart`
Expected: 컴파일 에러(`webrtc_diag.dart` 없음).

- [ ] **Step 3: 도메인 구현**

`lib/features/my_cage/domain/webrtc_diag.dart`:

```dart
import 'dart:collection';

/// 라이브 연결 진단 이벤트 한 건(앱 로컬, 2026-09-23).
///
/// 원격 `webrtc_connect_logs`는 세대당 결과 1~2행뿐이라 "왜 재연결했는지"를
/// 못 담는다. 이 버퍼는 전환 사유(수동·네트워크·복귀·정지·병합)를 순서대로
/// 남겨 펌웨어·서버 로그와 대조하기 위한 것이다. 후보 값·SDP·JWT·TURN 자격은
/// 넣지 않는다 — 넣는 쪽이 책임진다.
class WebRtcDiagEvent {
  const WebRtcDiagEvent({
    required this.at,
    required this.cameraId,
    required this.gen,
    required this.event,
    this.data = const {},
  });

  final DateTime at;
  final String cameraId;
  final int gen;
  final String event;
  final Map<String, Object?> data;

  String toLine() {
    final cam = cameraId.length > 8 ? cameraId.substring(0, 8) : cameraId;
    final kv = data.entries.map((e) => '${e.key}=${e.value}').join(' ');
    return '${at.toUtc().toIso8601String()} cam=$cam gen=$gen $event'
        '${kv.isEmpty ? '' : ' $kv'}';
  }
}

/// 최근 [capacity]건만 남기는 순환 버퍼. 메모리 전용 — 강제 종료면 사라진다
/// (기획서 §6 한계로 명시).
class WebRtcDiagBuffer {
  WebRtcDiagBuffer({this.capacity = 600});

  final int capacity;
  final ListQueue<WebRtcDiagEvent> _q = ListQueue();

  List<WebRtcDiagEvent> get events => List.unmodifiable(_q);

  void add(WebRtcDiagEvent e) {
    if (_q.length >= capacity) _q.removeFirst();
    _q.addLast(e);
  }

  void clear() => _q.clear();

  String export({String? header}) => [
        if (header != null) header,
        ..._q.map((e) => e.toLine()),
      ].join('\n');
}
```

- [ ] **Step 4: provider**

`lib/features/my_cage/presentation/webrtc_diag_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/webrtc_diag.dart';

/// 앱 전역 진단 버퍼(카메라 구분은 이벤트의 cameraId). 계정이 바뀌면 비운다 —
/// 다른 계정의 카메라 ID·연결 이력이 남지 않게(3층 계정 격리 규칙).
final webrtcDiagBufferProvider = Provider<WebRtcDiagBuffer>((ref) {
  final buffer = WebRtcDiagBuffer();
  ref.listen<String?>(currentUserProvider.select((u) => u?.id), (prev, next) {
    if (prev != next) buffer.clear();
  });
  return buffer;
});
```

- [ ] **Step 5: 컨트롤러에 `_diag` 추가**

`webrtc_live_controller.dart` — import 두 줄 추가:

```dart
import '../domain/webrtc_diag.dart';
import 'webrtc_diag_providers.dart';
```

`startConnection()`을 아래로 교체:

```dart
  void startConnection() {
    if (_started) return;
    _started = true;
    _logSink = ref.read(webrtcConnectLogSinkProvider);
    _diagBuffer = ref.read(webrtcDiagBufferProvider);
    _watchEnvironment();
    _diag('start');
    unawaited(_start(_gen));
  }

  /// 로컬 진단(메모리 버퍼 + debugPrint). 시작 때 잡아 둔다 — dispose 중엔 ref를 못 읽는다.
  WebRtcDiagBuffer? _diagBuffer;

  void _diag(String event, [Map<String, Object?> data = const {}]) {
    final row = <String, Object?>{'t_ms': _timing.elapsedMilliseconds, ...data};
    debugPrint('[webrtc-timing] cam=$cameraUuid gen=$_gen $event $row');
    _diagBuffer?.add(WebRtcDiagEvent(
      at: DateTime.now(),
      cameraId: cameraUuid,
      gen: _gen,
      event: event,
      data: row,
    ));
  }
```

기존 debugPrint 중 아래 지점을 `_diag`로 바꾼다(문자열 로그는 남겨도 되지만 버퍼에는 이 6곳이 들어가야 한다):

| 위치 | 교체 |
|---|---|
| `_scheduleReconnect` "auto-reconnect in" | `_diag('reconnect-scheduled', {'delay_s': delay.inSeconds, 'attempt': _reconnectAttempt});` |
| `_scheduleReconnect` "offline — wait for online" | `_diag('wait-online');` |
| `_watchEnvironment` "network $before→$now" | `_diag('network-changed', {'from': before, 'to': now});` |
| `_watchEnvironment` "back online" | `_diag('camera-online');` |
| `_suspend` 진입(첫 줄 뒤) | `_diag('suspend');` / `_resume`: `_diag('resume');` |
| `_doConnect` `_sessionId = offerResult.sessionId;` 직후 | `_diag('answer', {'session': offerResult.sessionId, 'offer_attempts': offerResult.offerAttempts, 'answer_ms': offerResult.answerMs});` |
| `onConnectionState` Connected 분기 debugPrint | `_diag('connected', {'config_ms': a?.msConfig, 'answer_ms': a?.msAnswer});` |
| `onConnectionState` Disconnected 분기 첫 줄 | `_diag('disconnected');` |
| `renderer.onFirstFrameRendered` debugPrint | `_diag('first-frame');` |
| `_fail` 첫 줄(`_endAttempt` 직후) | `_diag('fail', {'outcome': outcome, 'phase': state.phase.name});` |
| `_restart` 첫 줄(guard 통과 후) | `_diag('restart');` |

- [ ] **Step 6: 테스트 하네스 override**

`webrtc_live_controller_test.dart` import 추가:

```dart
import 'package:vivanaut/features/my_cage/domain/webrtc_diag.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_diag_providers.dart';
```

`_Harness`에 필드와 override 추가:

```dart
  final diag = WebRtcDiagBuffer();
  // overrides 목록 마지막에:
      webrtcDiagBufferProvider.overrideWithValue(diag),
```

- [ ] **Step 7: 테스트 통과 확인**

Run: `flutter analyze && flutter test test/features/my_cage/webrtc_diag_test.dart test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 에러 0, `All tests passed!`

- [ ] **Step 8: 커밋** (버전 `0.133.0+329`, CHANGELOG "추가 — 카메라 라이브 연결 진단을 앱 안에 기록합니다(최근 600건, 메모리). 내보내기는 후속 항목.")

```bash
git add lib/features/my_cage/domain/webrtc_diag.dart lib/features/my_cage/presentation/webrtc_diag_providers.dart lib/features/my_cage/presentation/webrtc_live_controller.dart test/features/my_cage/webrtc_diag_test.dart test/features/my_cage/webrtc_live_controller_test.dart pubspec.yaml CHANGELOG.md
git commit -m "feat(live): 라이브 연결 로컬 진단 버퍼 (0.133.0+329)"
```

---

### Task 2: 상태 모델 확장과 타이밍 상수 정리

**Context:**
- Depends on: Task 1
- Inputs: 기획서 §11.4 상태 모델
- Outputs: `WebRtcLivePhase.stalled/recovering`, `WebRtcLiveState.statsUnknown`, `WebRtcLivePhaseX.hasVideo/isConnecting`, 상수 9종. 뷰는 컴파일만 되게 최소 매핑(문구 개편은 Task 7).
- Must know: 이 task는 **동작을 바꾸지 않는다.** 기존 `kWebRtcStallCheckInterval`/`kWebRtcStallChecks`는 Task 5에서 제거하므로 여기선 남긴다.
- Acceptance: 기존 테스트 전부 PASS, analyze 0.

**Files:**
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart:19-53, 128-146`
- Modify: `lib/features/my_cage/presentation/widgets/webrtc_live_view.dart:35-58`

- [ ] **Step 1: 상태 정의 교체**

```dart
enum WebRtcLivePhase {
  connectingConfig,
  offering,
  connectingIce,

  /// ICE는 붙었고 첫 영상 프레임을 기다리는 중(키프레임 대기).
  waitingVideo,
  streaming,

  /// 재생 중 디코딩이 [kWebRtcSoftStallTicks]초 멈춤 — renderer는 살아 있어
  /// 마지막 장면이 남고, 위에 "잠시 멈췄어요" 안내를 얹는다.
  stalled,

  /// 실패 뒤 집중 복구 예산([kWebRtcRecoveryBudget]) 안의 자동 재시도 대기·진행.
  /// 사용자에게 버튼을 요구하지 않는다.
  recovering,

  /// 집중 복구 예산 소진·카메라 오프라인·망 없음·인증 실패. "다시 연결" 버튼이
  /// 있고 저빈도([kWebRtcLowRetryInterval]) 자동 재시도만 돈다.
  failed,
}

extension WebRtcLivePhaseX on WebRtcLivePhase {
  /// 영상 면을 그릴 renderer가 있는 단계.
  bool get hasVideo =>
      this == WebRtcLivePhase.streaming || this == WebRtcLivePhase.stalled;

  /// 연결 시퀀스 진행 중(config~첫 프레임 대기).
  bool get isConnecting => index <= WebRtcLivePhase.waitingVideo.index;
}

class WebRtcLiveState {
  final WebRtcLivePhase phase;
  final String? errorKey; // ko.json 키
  final RTCVideoRenderer? renderer;

  /// 재생 중 통계를 [kWebRtcStatsUnknownTicks]초 연속 못 읽음 — 영상은 나올 수
  /// 있으니 가리지 않고, "영상 상태 확인 중"만 얹는다.
  final bool statsUnknown;

  const WebRtcLiveState({
    required this.phase,
    this.errorKey,
    this.renderer,
    this.statsUnknown = false,
  });

  WebRtcLiveState copyWith({
    WebRtcLivePhase? phase,
    String? errorKey,
    bool clearError = false,
    RTCVideoRenderer? renderer,
    bool? statsUnknown,
  }) {
    return WebRtcLiveState(
      phase: phase ?? this.phase,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      renderer: renderer ?? this.renderer,
      statsUnknown: statsUnknown ?? this.statsUnknown,
    );
  }
}
```

- [ ] **Step 2: 상수 추가** (`kWebRtcFirstFrameTimeout` 아래)

```dart
/// 재생 중 통계 샘플 주기. getStats는 겹치지 않게 호출한다(busy 가드).
const kWebRtcStatsInterval = Duration(seconds: 1);

/// 디코딩 프레임이 이 틱만큼 연속 그대로면 `stalled`(안내만, 연결 유지).
/// GOP 15/6fps = 키프레임 2.5초라 3초면 정상 손실에도 깜빡인다 → 5초(§11.3).
const kWebRtcSoftStallTicks = 5;

/// 이 틱만큼 연속 그대로면 재연결. 시각이 아니라 틱으로 세는 이유: 가짜 시계는
/// Timer만 흘린다(§11.3).
const kWebRtcHardStallTicks = 15;

/// 통계를 이 틱만큼 연속 못 읽으면 `statsUnknown`(연결은 끊지 않는다).
const kWebRtcStatsUnknownTicks = 10;

/// 첫 프레임 뒤 이 시간 동안 `streaming`이 유지돼야 백오프·복구 예산을 초기화.
const kWebRtcStableAfter = Duration(seconds: 30);

/// 개별 연결 시도(config 수신~첫 프레임) 전체 예산. ICE 연결 단계엔 다른 한도가
/// 없어 이것이 유일한 상한이다(§11.2).
const kWebRtcAttemptBudget = Duration(seconds: 60);

/// 시청 진입·정지 뒤 자동 복구를 `recovering`으로 조용히 반복하는 예산.
/// 넘기면 `failed`(버튼) + 저빈도 재시도.
const kWebRtcRecoveryBudget = Duration(seconds: 90);
const kWebRtcLowRetryInterval = Duration(seconds: 60);

/// connectivity_plus 신호 합치기 창.
const kWebRtcNetworkDebounce = Duration(seconds: 1);

/// 망 신호가 바뀌어도 프레임이 이 틱 안에 진행하면 연결을 유지한다.
const kWebRtcNetworkFrameGraceTicks = 3;
```

- [ ] **Step 3: 뷰 최소 매핑** — `webrtc_live_view.dart`의 switch에 두 case 추가(문구는 Task 7에서 교체):

```dart
      WebRtcLivePhase.stalled => _StreamingView(
          renderer: state.renderer!,
          cover: cover,
        ),
      WebRtcLivePhase.recovering => _ConnectingView(
          labelKey: 'crecam_live_phase_config',
        ),
```

- [ ] **Step 4: 확인·커밋** (버전 `0.133.1+330`, CHANGELOG는 이 task 단독으로 사용자 변화가 없으므로 "변경 — 내부 상태 모델 확장(화면 변화 없음)" 한 줄)

Run: `flutter analyze && flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: PASS.

```bash
git add lib/features/my_cage/presentation/webrtc_live_controller.dart lib/features/my_cage/presentation/widgets/webrtc_live_view.dart pubspec.yaml CHANGELOG.md
git commit -m "refactor(live): 라이브 phase에 stalled·recovering 추가, 타이밍 상수 정리 (0.133.1+330)"
```

---

### Task 3: 실패 처리 재작성 — 세대 종료·인증 실패 고정·개별 시도 예산 60초

**Context:**
- Depends on: Task 2
- Inputs: §11.2(ICE 단계 무한 대기, 인증 무한 재시도), A5 개별 예산
- Outputs: `_fail(gen, {outcome, errorKey, reconnect})`가 세대를 닫고 정리한다; `BackendException 401/403` → `failed` 고정; `_attemptDeadline`.
- Must know: `_fail`이 **세대를 올린다**(`++_gen`). 그래야 실패 뒤 늦게 오는 offer 응답·콜백이 실패 화면을 덮지 않는다. `_scheduleReconnect`에는 **올린 뒤의 세대**를 넘긴다(아니면 타이머가 영원히 안 뛴다). 이 task에서는 `recovering` 분기를 아직 넣지 않는다(Task 6) — `_fail`은 여전히 `failed`를 그린다.
- Acceptance: 새 테스트 2개 + 기존 PASS.

**Files:**
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart` (`_start`, `_fail`, `_cancelTimers`, 필드)
- Test: `test/features/my_cage/webrtc_live_controller_test.dart`

- [ ] **Step 1: 실패 테스트 작성** — 하네스 `_FakeSignaling`에 필드 추가:

```dart
  /// 다음 offer를 이 예외로 실패시킨다(1회).
  Object? failOfferWith;
```

`sendOffer` 맨 앞(holdOffer 대기 뒤)에:

```dart
    final fail = failOfferWith;
    if (fail != null) {
      failOfferWith = null;
      throw fail;
    }
```

테스트 추가(`main` 안):

```dart
  testWidgets('인증 실패(401)는 자동 재시도하지 않고 failed로 멈춘다', (tester) async {
    final h = _Harness();
    h.signaling.failOfferWith = const BackendException(401, 'expired');
    await _settleConnect(tester);
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_auth');
    await tester.pump(const Duration(minutes: 3));
    expect(h.pcs, hasLength(1), reason: '토큰이 죽었는데 offer를 반복하면 안 된다');
    await h.dispose();
  });

  testWidgets('ICE가 60초 안에 붙지도 실패하지도 않으면 시도 예산으로 끊고 다시 붙인다',
      (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    expect(h.state.phase, WebRtcLivePhase.connectingIce);
    final first = h.pc;
    await tester.pump(kWebRtcAttemptBudget);
    await tester.pump();
    expect(first.closed, isTrue);
    expect(h.logs.single.outcome, 'failed');
    expect(h.logs.single.failPhase, 'connectingIce');
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 두 테스트 FAIL(`errorKey`가 `crecam_live_error_failed`, 60초 뒤에도 `connectingIce`).

- [ ] **Step 3: 구현**

필드 추가(`_frameDeadline` 아래):

```dart
  /// 개별 시도 전체 예산 — ICE 연결 단계엔 다른 한도가 없다.
  Timer? _attemptDeadline;
```

`_start` 시작부를 교체:

```dart
  Future<void> _start(int gen) async {
    _attempt = _Attempt(gen, _reconnectAttempt,
        ref.read(webrtcNetworkSignalProvider).valueOrNull);
    _attemptDeadline?.cancel();
    _attemptDeadline = Timer(kWebRtcAttemptBudget, () {
      if (!_isCurrent(gen) || state.phase.hasVideo) return;
      _diag('attempt-budget-exhausted', {'phase': state.phase.name});
      _fail(gen);
    });
    try {
      await _doConnect(gen);
    } on CameraUnresponsiveException {
      if (!_isCurrent(gen)) return;
      // 504 = 서버가 3회 모두 무응답(정의상 offer_attempts=3, 백엔드 회신 §1.3).
      _attempt?.offerAttempts = 3;
      if (!_autoRetried) {
        // 펌웨어가 offer를 놓친 일시 무응답일 수 있어 1회만 자동 재시도.
        _autoRetried = true;
        _endAttempt(gen, 'unresponsive');
        await Future<void>.delayed(kWebRtcUnresponsiveRetryDelay);
        if (!_isCurrent(gen)) return;
        await _restart();
        return;
      }
      _fail(gen,
          outcome: 'unresponsive',
          errorKey: 'crecam_live_error_unresponsive');
    } on BackendException catch (e) {
      if (!_isCurrent(gen)) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        // 세션 복구까지 한 번 거친 뒤의 401 — 반복해 봐야 같은 답이다.
        _fail(gen, errorKey: 'crecam_live_error_auth', reconnect: false);
        return;
      }
      _fail(gen);
    } catch (e) {
      if (!_isCurrent(gen)) return;
      _diag('error', {'phase': state.phase.name, 'err': e.runtimeType.toString()});
      _fail(gen);
    }
  }
```

`_fail` 교체:

```dart
  /// 이 세대를 실패로 끝낸다. 세대를 **올려** 늦게 오는 offer 응답·콜백·폴링이
  /// 실패 화면을 덮지 못하게 하고, 피어·세션·렌더러를 정리한다.
  /// [reconnect]가 false면(인증 실패) 자동 재시도 없이 버튼만 남긴다.
  void _fail(
    int gen, {
    String outcome = 'failed',
    String errorKey = 'crecam_live_error_failed',
    bool reconnect = true,
  }) {
    if (!_isCurrent(gen)) return;
    _endAttempt(gen, outcome);
    _diag('fail', {'outcome': outcome, 'phase': state.phase.name});
    _cancelTimers();
    final next = ++_gen;
    unawaited(_cleanup(closeRemote: true));
    state = WebRtcLiveState(phase: WebRtcLivePhase.failed, errorKey: errorKey);
    if (reconnect) _scheduleReconnect(next);
  }
```

`_cancelTimers` 교체(keepReconnect 파라미터 제거 — 재시작이 항상 모든 타이머를 끊는다. 호출부 `_restart`의 `_cancelTimers(keepReconnect: true)`도 `_cancelTimers()`로):

```dart
  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _disconnectGrace?.cancel();
    _frameTimer?.cancel();
    _frameDeadline?.cancel();
    _attemptDeadline?.cancel();
  }
```

`_enterStreaming`의 `_frameDeadline?.cancel();` 다음 줄에 `_attemptDeadline?.cancel();` 추가.

`_kFailPhase`에 `WebRtcLivePhase.stalled: 'streaming',` 추가(정지 종료 행의 fail_phase는 기존 허용값 `streaming`).

- [ ] **Step 4: 통과 확인**

Run: `flutter analyze && flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 전부 PASS. 특히 '기록 — 504 두 번이면 unresponsive 행 둘'이 여전히 2행인지 확인(`_endAttempt` 중복 방지 `a.ended`).

- [ ] **Step 5: 커밋** (버전 `0.133.2+331`, CHANGELOG "수정 — 카메라 라이브: 연결이 60초 안에 성사되지 않으면 끊고 다시 시도합니다(전에는 무한 대기 가능). 로그인 만료로 실패하면 반복 재시도 대신 안내와 다시 연결 버튼만 둡니다.")

```bash
git add lib/features/my_cage/presentation/webrtc_live_controller.dart test/features/my_cage/webrtc_live_controller_test.dart pubspec.yaml CHANGELOG.md
git commit -m "fix(live): 실패 시 세대 종료·시도 예산 60초·인증 실패 고정 (0.133.2+331)"
```

---

### Task 4: 재시작 병합과 네트워크 디바운스, 백오프 초기화 제거

**Context:**
- Depends on: Task 3
- Inputs: A1(단일화), A2(디바운스·망 없음), A3(초기화 조건), §11.2
- Outputs: `_restart({reason, force})` 병합 규칙, `_onNetworkSettled`, `_waitingNetwork`, `_reconnectNow(reason)`가 백오프를 초기화하지 않음.
- Must know: `_reconnectAttempt = 0`은 이 task 이후 **수동 `retry()`와 Task 5의 안정 30초**에서만 일어난다. 네트워크 변경이 `streaming` 중이면 유예 틱만 걸고 실제 판단은 Task 5의 감시 루프가 한다 — 이 task에서는 `_netGraceTicks`를 세팅만 하고, Task 5 전까지는 아무도 읽지 않는다(그동안 streaming 중 망 변경은 유지로 동작).
- Acceptance: 새 테스트 3개 + 기존 PASS(기존 'Wi-Fi→LTE'·'cancelled' 테스트는 디바운스 1초를 흘리도록 수정).

**Files:**
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart` (`_watchEnvironment`, `_reconnectNow`, `_resume`, `retry`, `_restart`, `_scheduleReconnect`, 필드)
- Test: `test/features/my_cage/webrtc_live_controller_test.dart`

- [ ] **Step 1: 테스트 작성/수정**

기존 'Wi-Fi→LTE 전환이면…' 테스트에서 `h.network.add('mobile');` 다음 줄에 `await tester.pump(kWebRtcNetworkDebounce);`를 넣고, `h.network.add('none');` 다음에도 같은 줄을 넣는다. '기록 — 결과 전에 네트워크가 바뀌면 cancelled'도 `h.network.add('mobile');` 뒤에 같은 줄.

추가:

```dart
  testWidgets('1초 안에 wifi→mobile→wifi로 돌아오면 재연결하지 않는다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    h.network.add('mobile');
    await tester.pump(const Duration(milliseconds: 300));
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(1));
    expect(h.diag.events.where((e) => e.event == 'restart'), isEmpty);
    await h.dispose();
  });

  testWidgets('망이 없으면 재시도를 멈추고, 돌아오면 곧바로 붙는다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _settleConnect(tester);
    h.network.add('none');
    await tester.pump(kWebRtcNetworkDebounce);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_no_network');
    await tester.pump(const Duration(minutes: 2));
    expect(h.pcs, hasLength(1), reason: '망 없이 offer를 반복하지 않는다');
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });

  testWidgets('정리 중 겹친 재시작 요청은 병합돼 offer가 하나만 나간다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    final n = h.container.read(webrtcLiveControllerProvider(_cam).notifier);
    unawaited(n.retry());
    unawaited(n.retry());
    unawaited(n.retry());
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    expect(h.diag.events.where((e) => e.event == 'restart-merged'), hasLength(2));
    await h.dispose();
  });

  testWidgets('연결 성공만으로는 백오프가 초기화되지 않는다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    // 1차 실패 → 3초, 2차 실패 → 6초.
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    // 영상 없이 곧 죽는 연결.
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2), reason: '3초 뒤가 아니라 6초 뒤에 붙어야 한다');
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(3));
    await h.dispose();
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 새 4개 FAIL.

- [ ] **Step 3: 구현**

필드 추가:

```dart
  /// 재시작이 이전 세대를 정리하는 중 — 이때 온 재시작 요청은 병합한다.
  bool _cleaningUp = false;

  // 네트워크 신호 — connectivity_plus는 같은 변화에 여러 이벤트를 낼 수 있어
  // [kWebRtcNetworkDebounce] 동안 합친 뒤 마지막 값만 반영한다.
  Timer? _netDebounce;
  String? _lastNetwork; // 마지막 신호
  String? _netApplied; // 연결에 반영한 망(기준선)
  bool _waitingNetwork = false; // 망 없음으로 재시도를 멈춘 상태
  int? _netGraceTicks; // 망 변경 후 프레임 진행을 기다리는 남은 틱(Task 5가 읽는다)

  bool _isNoNetwork(String? sig) =>
      sig == null || sig.isEmpty || sig == ConnectivityResult.none.name;
```

`_watchEnvironment`의 네트워크 listen을 교체:

```dart
    ref.listen<AsyncValue<String>>(webrtcNetworkSignalProvider, (_, next) {
      final now = next.valueOrNull;
      if (now == null) return;
      _lastNetwork = now;
      _netDebounce?.cancel();
      _netDebounce = Timer(kWebRtcNetworkDebounce, _onNetworkSettled);
    });
```

새 메서드(`_cameraOffline` 위):

```dart
  /// 디바운스가 끝난 망 신호 처리. 첫 값은 기준선만 잡고, 되돌아온 변화는
  /// 무시하며, 영상이 나오는 중이면 연결을 유지한 채 프레임 진행으로 판단한다.
  void _onNetworkSettled() {
    if (_suspended || _disposed) return;
    final now = _lastNetwork;
    if (_isNoNetwork(now)) {
      _diag('network-none');
      return; // 기준선은 그대로 — 돌아오면 그때 비교한다
    }
    if (_waitingNetwork) {
      _waitingNetwork = false;
      _netApplied = now;
      _diag('network-back', {'to': now});
      _reconnectNow('network-back');
      return;
    }
    if (_netApplied == null) {
      _netApplied = now;
      return;
    }
    if (now == _netApplied) return;
    _netApplied = now;
    _diag('network-changed', {'to': now});
    if (state.phase == WebRtcLivePhase.streaming) {
      // 영상이 진행 중이면 철거하지 않는다 — 감시 루프가 유예 틱 안에 프레임이
      // 안 늘면 그때 다시 붙인다.
      _netGraceTicks = kWebRtcNetworkFrameGraceTicks;
      return;
    }
    _reconnectNow('network');
  }
```

`_reconnectNow`·`_resume` 교체(백오프 초기화 제거):

```dart
  void _reconnectNow(String reason) {
    _waitingOnline = false;
    _reconnectTimer?.cancel();
    unawaited(_restart(reason: reason, force: true));
  }

  void _resume() {
    if (!_suspended || _disposed) return;
    _suspended = false;
    _diag('resume');
    _reconnectNow('resume');
  }
```

카메라 온라인 listen의 `_reconnectNow();` → `_reconnectNow('camera-online');`.

`retry()` 교체:

```dart
  Future<void> retry() async {
    _autoRetried = false;
    _waitingOnline = false;
    _waitingNetwork = false;
    _reconnectAttempt = 0; // 사용자 의도 — 백오프를 처음부터
    _reconnectTimer?.cancel();
    ref.invalidate(webrtcConfigProvider);
    await _restart(reason: 'manual', force: true);
  }
```

`_restart` 교체:

```dart
  /// 새 세대로 다시 붙는다. 세대를 **먼저** 올려 이전 세대의 잔여 작업을 즉시
  /// 무효로 만들고, 정리 도중 더 새로운 재시작이 오면 이쪽은 물러난다.
  ///
  /// 병합 규칙(A1): 정리 중이면 무시(이미 새 세대가 온다). 연결 시퀀스가 진행
  /// 중인데 [force]가 아니면 무시(같은 환경에서 offer를 두 번 내지 않는다).
  /// 환경이 바뀐 요청(망·복귀·수동)은 [force]로 현재 시도를 취소하고 새로 간다.
  Future<void> _restart({String reason = 'timer', bool force = false}) async {
    if (_disposed || _suspended) return;
    if (_cleaningUp || (!force && state.phase.isConnecting)) {
      _diag('restart-merged', {'reason': reason});
      return;
    }
    _diag('restart', {'reason': reason});
    _endAttempt(_gen, null);
    final gen = ++_gen;
    _cancelTimers();
    _cleaningUp = true;
    try {
      await _cleanup(closeRemote: true);
    } finally {
      _cleaningUp = false;
    }
    if (!_isCurrent(gen)) return;
    _pendingCandidates.clear();
    state = const WebRtcLiveState(phase: WebRtcLivePhase.connectingConfig);
    await _start(gen);
  }
```

`_start`의 504 자동 재시도 `await _restart();` → `await _restart(reason: 'unresponsive-retry', force: true);`.

`_scheduleReconnect` 교체(망 없음 대기 추가, 타이머 호출부 reason):

```dart
  void _scheduleReconnect(int gen) {
    if (!_isCurrent(gen)) return;
    _reconnectTimer?.cancel();
    if (_cameraOffline()) {
      // 꺼진 카메라에 무한히 offer를 보내 봐야 매번 15초 무응답이다.
      _waitingOnline = true;
      state = state.copyWith(
          phase: WebRtcLivePhase.failed,
          errorKey: 'crecam_live_error_camera_offline');
      _diag('wait-online');
      return;
    }
    if (_isNoNetwork(_lastNetwork) && _netApplied != null) {
      // 망 자체가 없다 — 카메라 탓으로 그리지 않고 복구 신호를 기다린다.
      _waitingNetwork = true;
      state = state.copyWith(
          phase: WebRtcLivePhase.failed,
          errorKey: 'crecam_live_error_no_network');
      _diag('wait-network');
      return;
    }
    // 3·6·12·24·48·60초 — 지수는 5에서 멈춘다(상한 60초에 이미 도달;
    // 무한 증가시키면 pow가 언젠가 inf로 넘친다).
    final delay = Duration(
        seconds: math.min(
            60, 3 * math.pow(2, math.min(5, _reconnectAttempt)).toInt()));
    _reconnectAttempt++;
    _diag('reconnect-scheduled',
        {'delay_s': delay.inSeconds, 'attempt': _reconnectAttempt});
    _reconnectTimer = Timer(delay, () {
      if (!_isCurrent(gen)) return;
      // 서버 ICE 설정(TURN 자격 등)이 바뀌었을 수 있어 자동 재연결도 새로 받는다.
      ref.invalidate(webrtcConfigProvider);
      unawaited(_restart(reason: 'timer'));
    });
  }
```

`onConnectionState` Connected 분기에서 `_reconnectAttempt = 0;` 줄을 **삭제**(주석 "연결 성공 — 재연결 백오프 리셋"도 삭제). `_reconnectTimer?.cancel(); _disconnectGrace?.cancel();`은 유지.

`dispose()`에 `_netDebounce?.cancel();` 추가. `_suspend`에 `_diag('suspend');` 추가(이미 Task 1에서 했다면 생략).

- [ ] **Step 4: 통과 확인**

Run: `flutter analyze && flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 전부 PASS. 기존 '재연결 후 이전 세션의 ICE 후보…' 테스트에서 `_fail`이 이미 gen을 올렸으므로 백오프 타이머는 새 세대로 뛴다 — 여기서 깨지면 Task 3의 `next` 전달을 의심할 것.

- [ ] **Step 5: 커밋** (버전 `0.133.3+332`, CHANGELOG "수정 — 카메라 라이브: 네트워크 신호가 잠깐 흔들리거나 곧 되돌아오면 재연결하지 않습니다. 영상이 나오는 중에는 망 종류가 바뀌어도 먼저 유지합니다. 휴대폰이 인터넷에 연결되지 않았을 때는 카메라 문제로 표시하지 않고 연결이 돌아오면 자동으로 다시 붙습니다. 다시 연결 버튼을 여러 번 눌러도 요청은 한 번만 나갑니다. 재시도 간격은 연결 직후가 아니라 영상이 안정된 뒤에 초기화됩니다(다음 항목).")

```bash
git add lib/features/my_cage/presentation/webrtc_live_controller.dart test/features/my_cage/webrtc_live_controller_test.dart pubspec.yaml CHANGELOG.md
git commit -m "fix(live): 재시작 병합·네트워크 디바운스·망 없음 대기·백오프 초기화 제거 (0.133.3+332)"
```

---

### Task 5: 재생 감시 개편 — 1초 샘플, 정지 5초 안내·15초 재연결, 통계 부재, 안정 30초 초기화

**Context:**
- Depends on: Task 4
- Inputs: A3, A4, A2(망 변경 유예 틱)
- Outputs: `_enterStreaming` 감시 루프 재작성, `_armStableTimer`, `stalled`↔`streaming` 전환, `statsUnknown`, `_netGraceTicks` 소비. `kWebRtcStallCheckInterval`/`kWebRtcStallChecks` 제거.
- Must know: "진행"은 `frames != last`(증가·감소·첫 값 모두). 감소는 카운터 리셋/SSRC 교체이므로 정지로 오판하지 않는다. 통계 null은 정지도 진행도 아니다 — 틱을 세지 않고 `noStats`만 센다. getStats는 `busy` 가드로 겹치지 않는다.
- Acceptance: 새 테스트 5개 + 기존 PASS. 기존 '재생 중 프레임이 15초간 멈추면…'·'기록 — 연결 후 무영상은 no_video, 재생 중 정지는 stalled'는 새 상수로 다시 쓴다.

**Files:**
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart` (`_enterStreaming`, 상수 제거, `_cancelTimers`, 필드)
- Test: `test/features/my_cage/webrtc_live_controller_test.dart`

- [ ] **Step 1: 하네스 확장** — `_FakePc`에:

```dart
  /// true면 getStats가 실패한다(통계 없음).
  bool statsBroken = false;
```

`getStats` 첫 줄에 `if (statsBroken) throw StateError('no stats');`.

헬퍼(`_settleConnect` 아래):

```dart
/// 재생 중 통계 틱을 [n]번 흘린다.
Future<void> _ticks(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(kWebRtcStatsInterval);
    await tester.pump();
  }
}

/// 연결→첫 프레임까지 흘려 streaming 상태로 만든다.
Future<void> _stream(WidgetTester tester, _Harness h, {int frames = 5}) async {
  await _settleConnect(tester);
  h.pc.frames = frames;
  h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
  h.renderer.onFirstFrameRendered!();
  expect(h.state.phase, WebRtcLivePhase.streaming);
}
```

- [ ] **Step 2: 테스트 교체·추가**

기존 '재생 중 프레임이 15초간 멈추면 다시 붙인다'를 아래로 교체:

```dart
  testWidgets('재생 중 프레임이 5초 멈추면 stalled 안내, 15초면 다시 붙인다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    for (var i = 0; i < 4; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    expect(h.state.phase, WebRtcLivePhase.streaming);
    // 첫 틱은 기준값을 잡는다 → 5틱 무진행 뒤 stalled.
    await _ticks(tester, 1 + kWebRtcSoftStallTicks);
    expect(h.state.phase, WebRtcLivePhase.stalled);
    expect(h.state.renderer, isNotNull, reason: '마지막 장면을 지우지 않는다');
    await _ticks(tester, kWebRtcHardStallTicks - kWebRtcSoftStallTicks);
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.logs.last.outcome, 'stalled');
    expect(h.logs.last.failPhase, 'streaming');
    await h.dispose();
  });

  testWidgets('stalled 중 프레임이 다시 늘면 streaming으로 돌아온다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    await _ticks(tester, 1 + kWebRtcSoftStallTicks);
    expect(h.state.phase, WebRtcLivePhase.stalled);
    h.pc.frames += 1;
    await _ticks(tester, 1);
    expect(h.state.phase, WebRtcLivePhase.streaming);
    expect(h.pcs, hasLength(1));
    await h.dispose();
  });

  testWidgets('카운터가 줄어도(리셋) 정지로 보지 않고, 정적 피사체(프레임은 옴)는 멀쩡하다',
      (tester) async {
    final h = _Harness();
    await _stream(tester, h, frames: 900);
    await _ticks(tester, 1);
    h.pc.frames = 3; // SSRC 교체/카운터 리셋
    await _ticks(tester, 1);
    for (var i = 0; i < 20; i++) {
      h.pc.frames += 6; // 화면은 안 변해도 프레임은 온다
      await _ticks(tester, 1);
    }
    expect(h.state.phase, WebRtcLivePhase.streaming);
    await h.dispose();
  });

  testWidgets('통계를 10초 못 읽으면 statsUnknown만 켜고 연결은 유지한다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    h.pc.statsBroken = true;
    await _ticks(tester, kWebRtcStatsUnknownTicks);
    expect(h.state.phase, WebRtcLivePhase.streaming);
    expect(h.state.statsUnknown, isTrue);
    await _ticks(tester, 30);
    expect(h.pcs, hasLength(1), reason: '통계 부재만으로 끊지 않는다');
    h.pc.statsBroken = false;
    h.pc.frames += 6;
    await _ticks(tester, 1);
    expect(h.state.statsUnknown, isFalse);
    await h.dispose();
  });

  testWidgets('영상이 30초 안정되면 백오프가 초기화된다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    h.pc.frames = 5;
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.renderer.onFirstFrameRendered!();
    for (var i = 0; i < 31; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    expect(h.pcs, hasLength(3), reason: '초기화됐으면 6초가 아니라 3초 뒤에 붙는다');
    await h.dispose();
  });

  testWidgets('망 변경 뒤 프레임이 3틱 안에 안 늘면 그때 다시 붙는다', (tester) async {
    final h = _Harness();
    h.network.add('wifi');
    await _stream(tester, h);
    await _ticks(tester, 1);
    h.network.add('mobile');
    await tester.pump(kWebRtcNetworkDebounce);
    // 프레임이 계속 오면 유지.
    for (var i = 0; i < 5; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    expect(h.pcs, hasLength(1));
    // 다시 바뀌었는데 이번엔 프레임이 멈춤 → 3틱 뒤 재연결.
    h.network.add('wifi');
    await tester.pump(kWebRtcNetworkDebounce);
    await _ticks(tester, kWebRtcNetworkFrameGraceTicks);
    await _settleConnect(tester);
    expect(h.pcs, hasLength(2));
    await h.dispose();
  });
```

'기록 — 연결 후 무영상은 no_video, 재생 중 정지는 stalled'의 마지막 부분을 교체:

```dart
    await tester.pump(const Duration(seconds: 3));
    await _settleConnect(tester);
    h.pc.frames = 5;
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    h.renderer.onFirstFrameRendered!();
    await _ticks(tester, 1 + kWebRtcHardStallTicks);
    expect(h.logs.map((l) => l.outcome), ['no_video', 'streaming', 'stalled']);
```

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 새/수정 테스트 FAIL(컴파일 에러 `kWebRtcStatsInterval` 미사용은 아님 — 상수는 Task 2에 있음; 동작 불일치로 실패).

- [ ] **Step 4: 구현**

상수 `kWebRtcStallCheckInterval`·`kWebRtcStallChecks`와 그 주석을 삭제. 필드 추가:

```dart
  /// 첫 프레임 뒤 30초 안정 판정 타이머.
  Timer? _stableTimer;
```

`_cancelTimers`에 `_stableTimer?.cancel(); _netGraceTicks = null;` 추가.

`_enterStreaming` 교체:

```dart
  /// 재생 시작 + 감시. 1초마다 디코딩 프레임 수를 읽어
  /// - 진행(값이 달라짐 — 증가·감소·첫 값)이면 기준을 갱신하고 `stalled`면 복귀
  /// - [kWebRtcSoftStallTicks] 연속 그대로면 `stalled`(안내만, 연결 유지)
  /// - [kWebRtcHardStallTicks] 연속 그대로면 재연결
  /// - 통계를 못 읽으면 정지도 진행도 아니다 — [kWebRtcStatsUnknownTicks] 뒤
  ///   `statsUnknown`만 켠다
  /// - 망 변경 유예([_netGraceTicks])는 무진행 틱에서만 줄어들고 0이면 재연결
  void _enterStreaming(int gen, RTCPeerConnection pc, RTCVideoRenderer r) {
    if (!_isCurrent(gen) || state.phase.hasVideo) return;
    _frameDeadline?.cancel();
    _attemptDeadline?.cancel();
    state = WebRtcLiveState(phase: WebRtcLivePhase.streaming, renderer: r);
    final a = _attempt;
    if (a != null && a.gen == gen && a.playing == null) {
      a.msFirstFrame ??= _timing.elapsedMilliseconds;
      a.playing = Stopwatch()..start();
      _writeLog(a, 'streaming');
    }
    _diag('streaming');
    _armStableTimer(gen);

    int? last;
    var still = 0;
    var noStats = 0;
    var busy = false;
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(kWebRtcStatsInterval, (_) async {
      if (!_isCurrent(gen) || busy) return;
      busy = true;
      final frames = await _framesDecoded(pc);
      busy = false;
      if (!_isCurrent(gen)) return;

      if (frames == null) {
        noStats++;
        if (noStats >= kWebRtcStatsUnknownTicks && !state.statsUnknown) {
          _diag('stats-unknown');
          state = state.copyWith(statsUnknown: true);
        }
        return;
      }
      noStats = 0;
      if (state.statsUnknown) state = state.copyWith(statsUnknown: false);

      if (last == null || frames != last) {
        last = frames;
        still = 0;
        _netGraceTicks = null;
        if (state.phase == WebRtcLivePhase.stalled) {
          _diag('stall-recovered');
          state = state.copyWith(phase: WebRtcLivePhase.streaming);
          _armStableTimer(gen);
        }
        return;
      }

      still++;
      final grace = _netGraceTicks;
      if (grace != null) {
        if (grace <= 1) {
          _netGraceTicks = null;
          _diag('network-no-progress');
          _reconnectNow('network');
          return;
        }
        _netGraceTicks = grace - 1;
      }
      if (still >= kWebRtcHardStallTicks) {
        _diag('stall-hard', {'still': still});
        _fail(gen, outcome: 'stalled');
        return;
      }
      if (still >= kWebRtcSoftStallTicks &&
          state.phase == WebRtcLivePhase.streaming) {
        _diag('stall-soft', {'still': still});
        _stableTimer?.cancel(); // 불안정 구간 — 안정 판정을 다시 센다
        state = state.copyWith(phase: WebRtcLivePhase.stalled);
      }
    });
  }

  /// [kWebRtcStableAfter] 동안 `streaming`이 이어지면 백오프·504 가드를
  /// 초기화한다. connected만으로 초기화하면 "영상 있음 → 즉시 실패"가 짧은
  /// 간격으로 반복돼 카메라 세션을 압박한다(A3).
  void _armStableTimer(int gen) {
    _stableTimer?.cancel();
    _stableTimer = Timer(kWebRtcStableAfter, () {
      if (!_isCurrent(gen) || state.phase != WebRtcLivePhase.streaming) return;
      _diag('stable');
      _reconnectAttempt = 0;
      _autoRetried = false;
    });
  }
```

`_kFailPhase`에 `stalled: 'streaming'`이 Task 3에서 들어갔는지 확인(`_endAttempt`가 `stalled` 상태에서 `fail_phase=streaming`을 쓴다).

- [ ] **Step 5: 통과 확인**

Run: `flutter analyze && flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: PASS. '첫 프레임 콜백이 없어도 디코딩 통계로 streaming'은 `_awaitFirstFrame`(변경 없음)을 쓰므로 그대로 통과해야 한다.

- [ ] **Step 6: 커밋** (버전 `0.133.4+333`, CHANGELOG "변경 — 카메라 라이브: 영상이 5초 멈추면 마지막 장면 위에 '영상이 잠시 멈췄어요 · 자동 연결 중'을 보이고, 15초까지 스스로 돌아오지 않을 때만 다시 연결합니다. 영상 상태를 읽지 못하는 동안은 '영상 상태 확인 중'으로 표시하고 연결은 끊지 않습니다. 재시도 간격은 영상이 30초 안정된 뒤에만 처음으로 돌아갑니다." — 문구는 Task 7에서 실제로 뜬다; 이 커밋에서는 "(문구는 0.133.6에서 반영)" 각주)

```bash
git add lib/features/my_cage/presentation/webrtc_live_controller.dart test/features/my_cage/webrtc_live_controller_test.dart pubspec.yaml CHANGELOG.md
git commit -m "feat(live): 재생 감시 1초 샘플·정지 5/15초 분리·통계 부재·안정 30초 초기화 (0.133.4+333)"
```

---

### Task 6: 집중 복구 예산 90초 — `recovering`/`failed` 분리와 저빈도 재시도

**Context:**
- Depends on: Task 5
- Inputs: A5(집중 복구 90초·저빈도 60초), §11.4
- Outputs: `_recoveryDeadline`, `_recoveryExhausted`, `_lastErrorKey`; `_fail`이 예산 안이면 `recovering`, 소진이면 `failed`; `_scheduleReconnect`가 소진 시 60초.
- Must know: 예산 창은 **시청 진입(startConnection)·복귀(_resume)·수동 retry**에서 새로 열고, **안정 30초**에서 닫는다. 창이 닫힌 뒤 실패하면(안정 재생 후 첫 끊김) 새 창을 연다. 백그라운드 동안은 세지 않는다(`_suspend`가 창을 끈다). 창이 `recovering`(백오프 대기) 도중 소진되면 화면을 `failed`로 바꾸고 **걸려 있던 백오프 타이머를 60초 저빈도 타이머로 교체**한다(그래야 소진 뒤 첫 재시도 시점이 결정적이다). 소진 시점에 연결 시도가 진행 중(config~waitingVideo)이면 그 시도는 그대로 두고, 그 시도가 실패할 때 `_fail`이 소진 상태를 보고 `failed`+60초로 간다.
- Acceptance: 새 테스트 3개 + 기존 PASS. 기존 테스트 중 `failed`를 기대하던 곳은 예산 안이면 이제 `recovering`이다 — 아래 표대로 고친다.

**Files:**
- Modify: `lib/features/my_cage/presentation/webrtc_live_controller.dart`
- Test: `test/features/my_cage/webrtc_live_controller_test.dart`

- [ ] **Step 1: 기존 테스트 기대값 수정**

| 테스트 | 변경 |
|---|---|
| '재연결 후 이전 세션의 ICE 후보…' | `expect(h.state.phase, WebRtcLivePhase.failed)` → `recovering` |
| '연결됐는데 30초간 영상이 없으면…' | `failed` → `recovering` |
| '재생 중 프레임이 5초 멈추면…'(Task 5) | 마지막 `failed` → `recovering` |
| '기록 — 504 두 번이면…' | `failed` → `recovering` |
| 'ICE가 60초 안에…'(Task 3) | phase 검사 없음 — 변경 없음 |
| '인증 실패(401)…' | `failed` 유지(reconnect:false) |
| '망이 없으면…'(Task 4) | `failed` 유지(대기 상태) |
| '정리 중 겹친 재시작…'(Task 4) | `retry()`는 `failed`에서만 의미가 있지만 컨트롤러는 phase를 검사하지 않으므로 그대로 통과 |

- [ ] **Step 2: 새 테스트**

```dart
  testWidgets('예산 안의 실패는 recovering(버튼 없음), 90초 넘기면 failed + 60초 간격',
      (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    expect(h.state.errorKey, isNull);
    // 90초를 흘린다. 그동안 재연결·60초 시도 예산 실패가 섞여 돌지만, 소진
    // 시점에 (a) 백오프 대기 중이면 즉시 failed, (b) 연결 시도 중이면 그 시도가
    // 실패할 때 failed — 둘 다 만들어 준다.
    await tester.pump(kWebRtcRecoveryBudget);
    await tester.pump();
    if (h.state.phase.isConnecting) {
      h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
      await tester.pump();
    }
    expect(h.state.phase, WebRtcLivePhase.failed);
    expect(h.state.errorKey, 'crecam_live_error_failed');
    // 소진 뒤 재시도는 60초 간격 — 59초까지는 새 피어가 없고 61초에 하나.
    final before = h.pcs.length;
    await tester.pump(const Duration(seconds: 59));
    expect(h.pcs.length, before);
    await tester.pump(const Duration(seconds: 2));
    await _settleConnect(tester);
    expect(h.pcs.length, before + 1);
    await h.dispose();
  });

  testWidgets('안정 재생 뒤 끊기면 새 90초 창이 열린다', (tester) async {
    final h = _Harness();
    await _stream(tester, h);
    for (var i = 0; i < 31; i++) {
      h.pc.frames += 6;
      await _ticks(tester, 1);
    }
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    await tester.pump(const Duration(seconds: 80));
    expect(h.state.phase, isNot(WebRtcLivePhase.failed));
    await h.dispose();
  });

  testWidgets('수동 다시 연결은 예산 창을 새로 연다', (tester) async {
    final h = _Harness();
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await tester.pump(kWebRtcRecoveryBudget);
    await tester.pump();
    if (h.state.phase.isConnecting) {
      h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
      await tester.pump();
    }
    expect(h.state.phase, WebRtcLivePhase.failed);
    unawaited(h.container
        .read(webrtcLiveControllerProvider(_cam).notifier)
        .retry());
    await _settleConnect(tester);
    h.pc.emit(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    expect(h.state.phase, WebRtcLivePhase.recovering);
    await h.dispose();
  });
```

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: 새 3개 + 기대값 바꾼 기존 테스트 FAIL.

- [ ] **Step 4: 구현**

필드:

```dart
  /// 집중 복구 예산 창. 열려 있으면 실패는 `recovering`, 소진되면 `failed`.
  Timer? _recoveryDeadline;
  bool _recoveryExhausted = false;

  /// recovering 중 소진되면 그때 보여 줄 사유.
  String _lastErrorKey = 'crecam_live_error_failed';
```

메서드(`_scheduleReconnect` 위):

```dart
  void _startRecoveryWindow() {
    _recoveryExhausted = false;
    _recoveryDeadline?.cancel();
    _recoveryDeadline = Timer(kWebRtcRecoveryBudget, () {
      if (_disposed) return;
      _recoveryExhausted = true;
      _diag('recovery-budget-exhausted', {'phase': state.phase.name});
      if (state.phase == WebRtcLivePhase.recovering) {
        // 백오프 대기 중 — 화면을 정직하게 바꾸고, 걸려 있던 백오프 타이머를
        // 저빈도 타이머로 교체한다(_scheduleReconnect가 exhausted를 보고 60초).
        state = state.copyWith(
            phase: WebRtcLivePhase.failed, errorKey: _lastErrorKey);
        _scheduleReconnect(_gen);
      }
      // 연결 시도 중이면 그 시도가 끝날 때 _fail이 exhausted를 반영한다.
    });
  }

  void _closeRecoveryWindow() {
    _recoveryDeadline?.cancel();
    _recoveryDeadline = null;
    _recoveryExhausted = false;
  }
```

`startConnection()`의 `_watchEnvironment();` 다음에 `_startRecoveryWindow();`.
`_resume()`의 `_reconnectNow('resume');` 앞에 `_startRecoveryWindow();`.
`_suspend()`의 `_cancelTimers();` 다음에 `_recoveryDeadline?.cancel();`.
`retry()`의 `ref.invalidate(...)` 앞에 `_startRecoveryWindow();`.
`dispose()`에 `_recoveryDeadline?.cancel();`.
`_armStableTimer` 콜백의 `_autoRetried = false;` 다음에 `_closeRecoveryWindow();`.

`_fail` 교체:

```dart
  void _fail(
    int gen, {
    String outcome = 'failed',
    String errorKey = 'crecam_live_error_failed',
    bool reconnect = true,
  }) {
    if (!_isCurrent(gen)) return;
    _endAttempt(gen, outcome);
    _diag('fail', {'outcome': outcome, 'phase': state.phase.name});
    _cancelTimers();
    final next = ++_gen;
    unawaited(_cleanup(closeRemote: true));
    if (!reconnect) {
      state = WebRtcLiveState(phase: WebRtcLivePhase.failed, errorKey: errorKey);
      return;
    }
    // 안정 재생으로 닫혔던 창이면 이 실패가 새 창을 연다.
    if (!_recoveryExhausted && _recoveryDeadline == null) _startRecoveryWindow();
    _lastErrorKey = errorKey;
    state = _recoveryExhausted
        ? WebRtcLiveState(phase: WebRtcLivePhase.failed, errorKey: errorKey)
        : const WebRtcLiveState(phase: WebRtcLivePhase.recovering);
    _scheduleReconnect(next);
  }
```

`_scheduleReconnect`의 지연 계산을 교체:

```dart
    final Duration delay;
    if (_recoveryExhausted) {
      delay = kWebRtcLowRetryInterval;
    } else {
      // 3·6·12·24·48·60초 — 지수는 5에서 멈춘다(상한 60초에 이미 도달;
      // 무한 증가시키면 pow가 언젠가 inf로 넘친다).
      delay = Duration(
          seconds: math.min(
              60, 3 * math.pow(2, math.min(5, _reconnectAttempt)).toInt()));
      _reconnectAttempt++;
    }
```

`_closeRecoveryWindow`가 `_recoveryDeadline = null`로 두므로 `_fail`의 `== null` 검사가 "닫힌 창"을 뜻한다. `_startRecoveryWindow`는 항상 non-null로 만든다.

- [ ] **Step 5: 통과 확인**

Run: `flutter analyze && flutter test test/features/my_cage/webrtc_live_controller_test.dart`
Expected: PASS.

- [ ] **Step 6: 커밋** (버전 `0.133.5+334`, CHANGELOG "변경 — 카메라 라이브: 처음 열었을 때와 끊긴 뒤 90초 동안은 '다시 연결' 버튼 대신 자동으로 다시 연결하는 상태를 보입니다. 90초가 지나도 안 되면 '라이브에 연결하지 못했어요'와 다시 연결 버튼을 두고 1분마다 조용히 다시 시도합니다.")

```bash
git add lib/features/my_cage/presentation/webrtc_live_controller.dart test/features/my_cage/webrtc_live_controller_test.dart pubspec.yaml CHANGELOG.md
git commit -m "feat(live): 집중 복구 90초 — recovering/failed 분리·저빈도 재시도 (0.133.5+334)"
```

---

### Task 7: 화면 상태 표시와 문구

**Context:**
- Depends on: Task 6
- Inputs: 기획서 §5 표(+§11.3 LIVE 배지 없음·statsUnknown 알약)
- Outputs: `WebRtcLiveView` phase 매핑, `_LivePill` 공용 알약, ko.json 키, 위젯 테스트.
- Must know: 내부 단계(config/offering/ice)를 나열하지 않는다 — 셋 다 "라이브 연결 중". 옛 키 `crecam_live_phase_*` 4개는 뷰만 쓰므로 삭제(`grep -rn crecam_live_phase lib test`로 0건 확인 후). `crecam_live_error_failed`는 `test/design/redesign_camera_pet_capture_test.dart`가 쓰므로 키는 유지하고 값만 바꾼다. 영상 위 알약은 `_ConnectingView`의 검은 알약과 같은 스타일이며 **가운데**에 둔다(하단은 페이지 인디케이터 자리).
- Acceptance: `flutter test test/features/my_cage/webrtc_live_view_test.dart test/design test/features/my_cage/crecam_home_test.dart` PASS.

**Files:**
- Modify: `lib/features/my_cage/presentation/widgets/webrtc_live_view.dart`
- Modify: `assets/l10n/ko.json:708-713`
- Create: `test/features/my_cage/webrtc_live_view_test.dart`

- [ ] **Step 1: 위젯 테스트**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/widgets/webrtc_live_view.dart';

const _cam = 'cam-1';

class _Fixed extends WebRtcLiveController {
  _Fixed(super.ref, super.cameraUuid, WebRtcLiveState s) {
    state = s;
  }
  int retries = 0;
  @override
  Future<void> retry() async => retries++;
}

Future<_Fixed> _pump(WidgetTester tester, WebRtcLiveState s) async {
  late _Fixed c;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        webrtcLiveControllerProvider(_cam)
            .overrideWith((ref) => c = _Fixed(ref, _cam, s)),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ko')],
        path: 'assets/l10n',
        fallbackLocale: const Locale('ko'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: const SizedBox(
                width: 320, height: 180, child: WebRtcLiveView(cameraUuid: _cam)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('연결 단계 셋은 모두 "라이브 연결 중" 하나로 보인다', (tester) async {
    for (final p in [
      WebRtcLivePhase.connectingConfig,
      WebRtcLivePhase.offering,
      WebRtcLivePhase.connectingIce,
    ]) {
      await _pump(tester, WebRtcLiveState(phase: p));
      expect(find.text('라이브 연결 중'), findsOneWidget, reason: p.name);
      expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
    }
  });

  testWidgets('recovering은 자동 복구 문구만, 버튼 없음', (tester) async {
    await _pump(tester, const WebRtcLiveState(phase: WebRtcLivePhase.recovering));
    expect(find.text('자동으로 다시 연결하고 있어요'), findsOneWidget);
    expect(find.byKey(WebRtcLiveView.retryButtonKey), findsNothing);
  });

  testWidgets('failed는 사유 + 다시 연결 버튼, 누르면 retry 한 번', (tester) async {
    final c = await _pump(
        tester,
        const WebRtcLiveState(
            phase: WebRtcLivePhase.failed,
            errorKey: 'crecam_live_error_camera_offline'));
    expect(find.text('카메라가 오프라인이에요. 전원과 Wi-Fi를 확인해주세요.'),
        findsOneWidget);
    await tester.tap(find.byKey(WebRtcLiveView.retryButtonKey));
    await tester.pump();
    expect(c.retries, 1);
  });
}
```

(`stalled`/`statsUnknown`은 실제 `RTCVideoRenderer`가 필요해 위젯 테스트에서 제외 — 실기기 검증 항목. 대신 `_pillKeyFor` 순수 함수를 테스트한다:)

```dart
  test('영상 위 알약 — stalled 우선, 그다음 statsUnknown, 정상은 없음', () {
    expect(
        WebRtcLiveView.pillKeyFor(
            const WebRtcLiveState(phase: WebRtcLivePhase.stalled, statsUnknown: true)),
        'crecam_live_stalled');
    expect(
        WebRtcLiveView.pillKeyFor(const WebRtcLiveState(
            phase: WebRtcLivePhase.streaming, statsUnknown: true)),
        'crecam_live_stats_unknown');
    expect(
        WebRtcLiveView.pillKeyFor(
            const WebRtcLiveState(phase: WebRtcLivePhase.streaming)),
        isNull);
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/my_cage/webrtc_live_view_test.dart`
Expected: 컴파일 에러(`retryButtonKey`, `pillKeyFor` 없음).

- [ ] **Step 3: ko.json** — 708~713행의 `crecam_live_phase_*` 4개와 error 2개를 아래로 교체:

```json
  "crecam_live_connecting": "라이브 연결 중",
  "crecam_live_loading_video": "영상을 불러오고 있어요",
  "crecam_live_recovering": "자동으로 다시 연결하고 있어요",
  "crecam_live_stalled": "영상이 잠시 멈췄어요 · 자동 연결 중",
  "crecam_live_stats_unknown": "영상 상태 확인 중",
  "crecam_live_retry": "다시 연결",
  "crecam_live_error_failed": "라이브에 연결하지 못했어요",
  "crecam_live_error_unresponsive": "카메라가 응답하지 않아요. 전원과 네트워크 상태를 확인해주세요.",
  "crecam_live_error_camera_offline": "카메라가 오프라인이에요. 전원과 Wi-Fi를 확인해주세요.",
  "crecam_live_error_no_network": "휴대폰이 인터넷에 연결되어 있지 않아요",
  "crecam_live_error_auth": "로그인 정보를 확인할 수 없어요. 다시 로그인해주세요.",
```

- [ ] **Step 4: 뷰 구현** — `webrtc_live_view.dart` 전체 교체:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/live_surface.dart';
import '../webrtc_live_controller.dart';

/// WebRTC 라이브 뷰.
///
/// 고객에게는 내부 단계(config/offering/ICE)를 나열하지 않는다(2026-09-23 기획 §5):
/// - 연결 중·복구 중: shimmer 스켈레톤 + 한 줄 문구 (CircularProgressIndicator 금지)
/// - streaming/stalled: RTCVideoView (+ 정지·관측 불가 알약)
/// - failed: 사유 + "다시 연결" — 집중 복구 예산이 끝났거나 카메라/망/인증 문제일 때만
class WebRtcLiveView extends ConsumerWidget {
  const WebRtcLiveView({
    super.key,
    required this.cameraUuid,
    this.cover = false,
  });

  final String cameraUuid;

  /// true면 영상이 면을 **꽉 채운다**(가장자리 크롭 허용). 홈 풀블리드 면이
  /// 쓴다. 기본 false(contain) — 카메라 상세는 프레임 전체를 보여준다.
  final bool cover;

  static const retryButtonKey = Key('webrtc_live_retry');
  static const pillKey = Key('webrtc_live_pill');

  /// 영상 위에 얹을 알약 문구 키. 정지가 관측 불가보다 우선한다.
  static String? pillKeyFor(WebRtcLiveState s) {
    if (s.phase == WebRtcLivePhase.stalled) return 'crecam_live_stalled';
    if (s.statsUnknown) return 'crecam_live_stats_unknown';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(webrtcLiveControllerProvider(cameraUuid));

    return switch (state.phase) {
      WebRtcLivePhase.connectingConfig ||
      WebRtcLivePhase.offering ||
      WebRtcLivePhase.connectingIce =>
        const _ConnectingView(labelKey: 'crecam_live_connecting'),
      WebRtcLivePhase.waitingVideo =>
        const _ConnectingView(labelKey: 'crecam_live_loading_video'),
      WebRtcLivePhase.recovering =>
        const _ConnectingView(labelKey: 'crecam_live_recovering'),
      WebRtcLivePhase.streaming || WebRtcLivePhase.stalled => _StreamingView(
          renderer: state.renderer!,
          cover: cover,
          pillLabelKey: pillKeyFor(state),
        ),
      WebRtcLivePhase.failed => _FailedView(
          errorKey: state.errorKey ?? 'crecam_live_error_failed',
          onRetry: () => ref
              .read(webrtcLiveControllerProvider(cameraUuid).notifier)
              .retry(),
        ),
    };
  }
}

// ── 알약 (연결 중 문구·영상 위 안내 공용) ──────────────────────────────────────

class _LivePill extends StatelessWidget {
  const _LivePill({required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: WebRtcLiveView.pillKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing12,
        vertical: AppStyles.spacing4,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppStyles.chipRadius),
      ),
      child: Text(
        labelKey.tr(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── 연결 중 (shimmer 스켈레톤 + 한 줄 문구) ───────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    // 영상 뷰포트는 테마와 무관하게 어둡다. 밝은 회색 스켈레톤을 쓰면
    // 연결 전 화면이 죽은 공백으로 보인다(AppTheme.liveSurface 주석 참조).
    const baseColor = AppTheme.liveSurface;
    final highlightColor = Colors.white.withValues(alpha: 0.06);

    return Stack(
      fit: StackFit.expand,
      children: [
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(color: baseColor),
        ),
        // 하단이 아니라 **가운데** — 하단은 페이지 인디케이터 자리라 겹친다.
        Center(child: _LivePill(labelKey: labelKey)),
      ],
    );
  }
}

// ── 스트리밍 (+ 정지·관측 불가 알약) ─────────────────────────────────────────

class _StreamingView extends StatelessWidget {
  const _StreamingView({
    required this.renderer,
    required this.cover,
    this.pillLabelKey,
  });

  final RTCVideoRenderer renderer;
  final bool cover;
  final String? pillLabelKey;

  @override
  Widget build(BuildContext context) {
    final video = RTCVideoView(
      renderer,
      objectFit: cover
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
    final key = pillLabelKey;
    if (key == null) return video;
    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        Center(child: _LivePill(labelKey: key)),
      ],
    );
  }
}

// ── 실패 ─────────────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  const _FailedView({required this.errorKey, required this.onRetry});

  final String errorKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 영상 면은 실패해도 어둡다. 여기서 테마 surface를 쓰면 밝은 회색이 되어
    // 위아래 어두운 덩어리가 깨진다(실기기에서 제어 바만 검게 떠 있었다).
    return ColoredBox(
      color: AppTheme.liveSurface,
      child: LiveSurfaceNotice(
        key: WebRtcLiveView.retryButtonKey,
        title: errorKey.tr(),
        actionLabel: 'crecam_live_retry'.tr(),
        onAction: onRetry,
      ),
    );
  }
}
```

`LiveSurfaceNotice`가 `key`를 받는지 확인(`lib/shared/widgets/live_surface.dart:95` 생성자에 `super.key` 있음 — 있다). 버튼 자체가 아니라 notice에 키가 붙으므로 테스트의 `tester.tap(find.byKey(retryButtonKey))`는 notice 가운데를 누른다 — 버튼이 가운데가 아니면 `find.descendant(of: find.byKey(...), matching: find.byType(TextButton))`로 바꾼다(`LiveSurfaceNotice` 본문의 버튼 타입을 열어 확인).

- [ ] **Step 5: 통과·회귀 확인**

Run: `grep -rn "crecam_live_phase" lib test` → 0건. `flutter analyze && flutter test test/features/my_cage/webrtc_live_view_test.dart test/design test/features/my_cage/crecam_home_test.dart test/features/home`
Expected: PASS. `test/design`의 캡처 테스트가 문구 변경으로 깨지면 **기대 문구만** 갱신한다.

- [ ] **Step 6: 커밋** (버전 `0.133.6+335`, CHANGELOG "변경 — 카메라 라이브 문구: 연결 단계별 문구('설정 수신 중…' 등)를 '라이브 연결 중' 하나로 합치고, 자동 복구 중에는 '자동으로 다시 연결하고 있어요', 최종 실패는 '라이브에 연결하지 못했어요'로 표시합니다. 카메라 오프라인·인터넷 없음·로그인 만료는 각각의 사유로 안내합니다. 버튼 문구는 '다시 연결'.")

```bash
git add lib/features/my_cage/presentation/widgets/webrtc_live_view.dart assets/l10n/ko.json test/features/my_cage/webrtc_live_view_test.dart pubspec.yaml CHANGELOG.md
git commit -m "feat(live): 라이브 상태 표시 — 연결 중/자동 복구/실패 분리, 정지·관측 불가 알약 (0.133.6+335)"
```

---

### Task 8: 사육장 제어기 상태 3값 — 미확인을 오프라인으로 그리지 않기

**Context:**
- Depends on: 없음(라이브 컨트롤러와 독립 — 병렬 가능)
- Inputs: 기획서 §3-E, §5 마지막 행, §11.1 마지막 행
- Outputs: `ModuleLink {unknown, online, offline}`, `moduleLinkProvider(deviceId)`, `moduleOnlineProvider`는 `== online`으로 유지(제어 차단은 그대로 보수적), `DeviceOfflineNotice`가 unknown이면 중립 안내.
- Must know: `currentDeviceProvider`는 autoDispose FutureProvider라 재조회 중에도 `hasValue`가 참(이전 값 유지)이다 — `isLoading`이 아니라 `!hasValue`로 unknown을 판정해야 깜빡이지 않는다(2026-09-19 재조회 깜빡임 교훈). `moduleOnlineProvider`를 override하는 기존 테스트 11곳은 그대로 두고, 안내 위젯 테스트만 `moduleLinkProvider`를 override한다. `redesign_home_capture_test`·`home_layout_test`가 홈에서 안내를 그리면 거기에도 `moduleLinkProvider(...).overrideWithValue(ModuleLink.online)`을 추가한다.
- Acceptance: `flutter test test/features/home test/features/my_cage/module_connection_test.dart test/design` PASS.

**Files:**
- Modify: `lib/features/my_cage/presentation/supabase_module_providers.dart:156-171`
- Modify: `lib/features/home/presentation/widgets/device_offline_notice.dart`
- Modify: `assets/l10n/ko.json:926` 근처
- Modify: `test/features/home/device_offline_notice_test.dart`

- [ ] **Step 1: 테스트 수정** — `_pump`의 `moduleOnlineProvider(_deviceId).overrideWithValue(online)`을 `moduleLinkProvider(_deviceId).overrideWithValue(link)`로, 파라미터 `required bool online` → `required ModuleLink link`. 기존 호출 `online: false` → `link: ModuleLink.offline`, `online: true` → `link: ModuleLink.online`. 추가:

```dart
  testWidgets('아직 모르면(조회 중) 오프라인이 아니라 "확인 중"으로 그린다', (tester) async {
    await _pump(tester, link: ModuleLink.unknown, lastSeen: null);
    expect(find.byKey(DeviceOfflineNotice.checkingKey), findsOneWidget);
    expect(find.byKey(DeviceOfflineNotice.noticeKey), findsNothing);
  });
```

provider 단위 테스트(`test/features/my_cage/module_connection_test.dart` 끝에 추가 — 파일의 기존 하네스를 열어 `currentDeviceProvider`·`telemetryStaleProvider` override 방식을 그대로 따른다):

```dart
  test('moduleLink — 기기 조회 전이면 unknown, 실패해도 unknown, 값이 있어야 online/offline',
      () {
    ModuleLink linkWith(AsyncValue<Device?> device, {bool stale = false}) {
      final c = ProviderContainer(overrides: [
        currentDeviceProvider.overrideWith((ref) => device.when(
            data: (d) async => d,
            loading: () => Completer<Device?>().future,
            error: (e, _) => Future<Device?>.error(e))),
        telemetryStaleProvider(_deviceId)
            .overrideWith((ref) => Stream.value(stale)),
      ]);
      addTearDown(c.dispose);
      c.listen(currentDeviceProvider, (_, __) {});
      return c.read(moduleLinkProvider(_deviceId));
    }

    expect(linkWith(const AsyncLoading()), ModuleLink.unknown);
    expect(linkWith(AsyncError(Exception('x'), StackTrace.empty)),
        ModuleLink.unknown);
  });
```

(비동기 값이 실제로 도착한 뒤의 online/offline은 기존 `module_connection_test.dart`의 `moduleOnlineProvider` 테스트 7개가 이미 검증한다 — 그 테스트가 계속 통과하는 것이 판정.)

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/home/device_offline_notice_test.dart`
Expected: 컴파일 에러(`ModuleLink`, `moduleLinkProvider`, `checkingKey` 없음).

- [ ] **Step 3: provider 구현** — `supabase_module_providers.dart`의 `moduleOnlineProvider` 블록을 교체:

```dart
/// 사육장 제어기 연결 상태 3값(2026-09-23). "모름"을 오프라인으로 그리면 앱을
/// 켜자마자 "기기 연결이 끊겼어요"가 보이고 카메라까지 고장으로 읽힌다.
enum ModuleLink { unknown, online, offline }

/// - `unknown`: 기기 목록을 아직 못 받았거나(조회 중·실패) 이 세트에 제어기가 없음
/// - `online`: `device.is_online` 스냅샷 **AND** telemetry 최신 — 제어 허용
/// - `offline`: 둘 중 하나라도 끊김
///
/// 재조회 중에는 이전 값을 유지한다(`hasValue`) — `isLoading`으로 판정하면
/// 15초 생존신호마다 "확인 중"이 깜빡인다(2026-09-19 교훈).
final moduleLinkProvider =
    Provider.autoDispose.family<ModuleLink, String>((ref, deviceId) {
  final device = ref.watch(currentDeviceProvider);
  if (!device.hasValue) return ModuleLink.unknown;
  final snapshot = device.value?.isOnline;
  if (snapshot == null) return ModuleLink.unknown;
  final isStale =
      ref.watch(telemetryStaleProvider(deviceId)).valueOrNull ?? false;
  return snapshot && !isStale ? ModuleLink.online : ModuleLink.offline;
});

/// 사육장 제어 가능 여부 = [moduleLinkProvider]가 `online`. 미확인도 차단한다
/// (보수적 — "오프라인인데 제어됨"이 "정상인데 잠깐 차단"보다 나쁘다).
final moduleOnlineProvider =
    Provider.autoDispose.family<bool, String>((ref, deviceId) =>
        ref.watch(moduleLinkProvider(deviceId)) == ModuleLink.online);
```

- [ ] **Step 4: 안내 위젯** — `device_offline_notice.dart`의 `build`를 교체하고 키 추가:

```dart
  static const noticeKey = Key('device_offline_notice');
  static const checkingKey = Key('device_link_checking_notice');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();
    final link = ref.watch(moduleLinkProvider(deviceId));
    if (link == ModuleLink.online) return const SizedBox.shrink();

    final theme = Theme.of(context);
    if (link == ModuleLink.unknown) {
      // 아직 모른다 — 경고색이 아니라 중립색. 고장이 아니라 확인 중이다.
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          key: checkingKey,
          padding: const EdgeInsets.all(AppStyles.spacing12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppStyles.spacing8),
              Expanded(
                child: Text(
                  'home_device_link_checking'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final device = ref.watch(currentDeviceProvider).valueOrNull;
    // 1분 틱에 맞춰 다시 그린다. 안 그러면 "8시간 전"이 그대로 멈춘다.
    final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
    final lastSeen = device?.lastSeenAt;
    // (아래는 기존 offline 카드 그대로)
```

기존 `Padding(...)` 이하 offline 카드는 그대로 둔다. `if (ref.watch(moduleOnlineProvider(deviceId))) return ...` 두 줄은 삭제.

ko.json `home_device_offline_body_unknown` 다음 줄에:

```json
  "home_device_link_checking": "사육장 제어기 연결을 확인하고 있어요 · 확인될 때까지 제어가 잠시 잠겨요",
```

- [ ] **Step 5: 통과·회귀**

Run: `flutter analyze && flutter test test/features/home test/features/my_cage/module_connection_test.dart test/design`
Expected: PASS. 홈 캡처/레이아웃 테스트가 "확인 중" 카드 때문에 깨지면 해당 테스트에 `moduleLinkProvider(...).overrideWithValue(ModuleLink.online)`을 추가한다(레이아웃 기대값을 바꾸지 않는다).

- [ ] **Step 6: 커밋** (버전 `0.133.7+336`, CHANGELOG "수정 — 홈: 사육장 제어기 상태를 아직 확인하지 못한 동안 '기기 연결이 끊겼어요'로 표시하던 것을 '연결을 확인하고 있어요'로 바꿨습니다. 제어 잠금은 전과 같이 확인될 때까지 유지됩니다.")

```bash
git add lib/features/my_cage/presentation/supabase_module_providers.dart lib/features/home/presentation/widgets/device_offline_notice.dart assets/l10n/ko.json test/features/home/device_offline_notice_test.dart test/features/my_cage/module_connection_test.dart pubspec.yaml CHANGELOG.md
git commit -m "fix(home): 제어기 상태 미확인을 오프라인으로 그리지 않음 — ModuleLink 3값 (0.133.7+336)"
```

---

### Task 9: 라이브 진단 내보내기 타일(환경설정)

**Context:**
- Depends on: Task 1
- Inputs: 기획서 §6 "사용자가 명시적으로 실행하는 지원용 동작", §11.3(텍스트 공유)
- Outputs: `LiveDiagExportTile`(환경설정 마지막 항목), ko 키 3개.
- Must know: 일반 라이브 화면에는 노출하지 않는다. 공유 파일은 앱 임시 폴더(`getTemporaryDirectory`), 갤러리 아님. 헤더에 앱 버전·OS만 넣고 계정 정보는 넣지 않는다. `SharePlus.instance.share(ShareParams(files: [...]))`가 프로젝트 표준(`video_export_service.dart:39`).
- Acceptance: analyze 0, 환경설정 위젯 테스트(있으면) PASS, 시뮬레이터에서 타일 탭 → 공유 시트가 뜨고 텍스트 파일에 `start`/`answer`/`streaming` 줄이 보인다.

**Files:**
- Create: `lib/features/my_cage/presentation/widgets/live_diag_export_tile.dart`
- Modify: `lib/features/my_cage/presentation/env_settings_screen.dart:22-27`
- Modify: `assets/l10n/ko.json`

- [ ] **Step 1: ko.json 키 추가**

```json
  "live_diag_export_title": "라이브 연결 진단 내보내기",
  "live_diag_export_subtitle": "최근 연결 기록을 텍스트로 공유해요. 영상·비밀번호는 포함되지 않아요.",
  "live_diag_export_empty": "아직 기록된 라이브 연결이 없어요",
```

- [ ] **Step 2: 타일 구현**

```dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../webrtc_diag_providers.dart';

/// 환경설정 — 라이브 연결 진단(메모리 버퍼)을 텍스트 파일로 공유한다.
/// 지원용 명시 동작이며 자동 발송은 없다(2026-09-23 기획 §6).
class LiveDiagExportTile extends ConsumerWidget {
  const LiveDiagExportTile({super.key});

  static const tileKey = Key('live_diag_export_tile');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: tileKey,
      leading: const Icon(Icons.bug_report_outlined),
      title: Text('live_diag_export_title'.tr()),
      subtitle: Text('live_diag_export_subtitle'.tr()),
      onTap: () => _export(context, ref),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final buffer = ref.read(webrtcDiagBufferProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (buffer.events.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text('live_diag_export_empty'.tr())));
      return;
    }
    final info = await PackageInfo.fromPlatform();
    final header = 'vivanaut ${info.version}+${info.buildNumber} '
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final file = File('${dir.path}/live-diag-$stamp.txt');
    await file.writeAsString(buffer.export(header: header));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'vivanaut live diag'),
    );
  }
}
```

- [ ] **Step 3: 환경설정 등록** — `env_settings_screen.dart`:

```dart
import 'widgets/live_diag_export_tile.dart';
// children:
          children: const [
            SetpointSettingTile(),
            // capabilities 미보고(구 펌웨어)·카메라 없음이면 자체적으로 숨는다.
            CameraRotateTile(),
            // 지원용 — 라이브 연결 진단 텍스트 공유(자동 발송 없음).
            LiveDiagExportTile(),
          ],
```

- [ ] **Step 4: 확인·커밋** (버전 `0.133.8+337`, CHANGELOG "추가 — 환경설정에 '라이브 연결 진단 내보내기'를 추가했습니다. 최근 라이브 연결 기록(최대 600건, 앱을 완전히 종료하면 사라짐)을 텍스트로 공유할 수 있습니다. 영상·비밀번호·계정 정보는 포함되지 않습니다.")

Run: `flutter analyze && flutter test test/features/my_cage test/features/home`
Expected: PASS.

```bash
git add lib/features/my_cage/presentation/widgets/live_diag_export_tile.dart lib/features/my_cage/presentation/env_settings_screen.dart assets/l10n/ko.json pubspec.yaml CHANGELOG.md
git commit -m "feat(settings): 라이브 연결 진단 내보내기 타일 (0.133.8+337)"
```

---

### Task 10: 실기기 검증과 문서·병합

**Context:**
- Depends on: Task 1~9
- Inputs: 기획서 §7 지표, §8 실기기 시나리오
- Outputs: 검증 기록 `docs/design-audits/2026-09-2x-camera-live-pre-firmware/RESULTS.md`, CLAUDE.md "라이브 연결 안정성" 단락 갱신, main 병합·브랜치 삭제·push.
- Must know: 이 계획의 코드 완료 ≠ 제품 안정화 완료(기획서 §7). 실기기 결과 없이 "개선됨"이라 쓰지 않는다. 사용자에게 `/code-review` 실행을 요청한 뒤 병합한다(Claude가 대신 실행 불가).
- Acceptance: 아래 회귀 5항목이 시뮬/실기기에서 확인되고 RESULTS.md에 표본 수와 함께 기록됨.

- [ ] **Step 1: 자동 회귀 전체** — `flutter analyze && flutter test`. 실패 0.

- [ ] **Step 2: 실기기 필수 회귀(기획서 §7)** — 각 항목을 RESULTS.md 표로:

| # | 시나리오 | 확인 방법 | 기대 |
|---|---|---|---|
| 1 | 앱 최초 진입 | 홈 진입 직후 10초 화면 녹화 | "기기 연결이 끊겼어요"·"연결하지 못했어요"가 **처음부터** 뜨지 않음 |
| 2 | 시청 중 Wi-Fi 신호 흔들림(공유기 재부팅 없이 AP 근처 이동) | 진단 내보내기의 `network-*` 줄 | `restart reason=network`가 `network-no-progress` 없이 나오지 않음 |
| 3 | "다시 연결" 3연타 | 진단 `restart-merged` 2건, 서버 로그 offer 1건 | 동시 offer 없음 |
| 4 | 백그라운드 10회 복귀 | `webrtc_connect_logs` outcome | `closed`/`streaming` 쌍, 잔여 세션 없음 |
| 5 | 카메라 전원 차단 | 화면 | `recovering` → 카메라 오프라인 사유 `failed`, 전원 복귀 시 자동 연결 |

추가로 §8의 60분 앱 시청 1회(정지 횟수·총 정지 시간·재접속 횟수·`stats-unknown` 발생 여부·배터리 소모)를 기록한다. 1초 getStats 비용이 눈에 띄면 `kWebRtcStatsInterval`을 2초로 올리고 감지 지연(틱 수치는 그대로 → 실제 시간 2배)을 보고한다.

- [ ] **Step 3: CLAUDE.md 갱신** — "라이브 연결 안정성" 단락 끝에 한 문장 추가: "**펌웨어 수정 전 앱 개선(2026-09-2x, 0.133.x):** 재시작 병합·망 디바운스 1초·시도 예산 60초·집중 복구 90초(`recovering`)·저빈도 60초(`failed`)·정지 5/15초(`stalled`)·안정 30초 백오프 초기화·`ModuleLink` 3값·환경설정 진단 내보내기. 기획 `docs/superpowers/specs/2026-09-23-camera-live-pre-firmware-app-design.md` §11, 결과 `docs/design-audits/...`."

- [ ] **Step 4: 리뷰 요청 → 병합**

사용자에게 `/code-review` 실행을 요청하고 결과를 반영한 뒤:

```bash
cd /Users/baek/myProjects/tera-ai-flutter && git merge --no-ff feat/live-pre-firmware && git push && git worktree remove ../tera-ai-flutter-live && git branch -d feat/live-pre-firmware
```

---

## Self-Review

**Spec coverage (기획서 §4~§6 → task):**
- A1 단일화 → Task 3(세대 종료), Task 4(병합·force) ✅
- A2 네트워크 판단 → Task 4(디바운스·되돌아옴 무시·망 없음 대기), Task 5(유예 틱) ✅. "백그라운드 시청 없음"은 기존 유지 ✅
- A3 안정 후 초기화 → Task 4(Connected 초기화 제거), Task 5(`_armStableTimer`) ✅. 인증 실패 → Task 3 ✅
- A4 관측/복구 분리 → Task 5 ✅ (PLI/FIR·ICE restart 미호출 — 코드 추가 없음 ✅)
- A5 예산 → Task 3(60초), Task 6(90초·60초 저빈도) ✅. 카메라 offline 재조회는 §11.3으로 **의도적 제외** ✅
- A6 ICE 비교 → 범위 밖(§11.5) ✅
- §5 상태 표시 → Task 7 ✅, 제어기 미확인 → Task 8 ✅, 마지막 수신 사진 → P1 범위 밖 ✅
- §6 진단 → Task 1·9 ✅ (원격 스키마 무변경 ✅)
- §7·§8 검증 → Task 10 ✅

**Placeholder scan:** "TBD/TODO/적절히" 없음. Task 7 Step 4의 `LiveSurfaceNotice` 버튼 탐색 대안은 조건부 지시이며 코드가 제시돼 있다. Task 8 Step 1의 provider 테스트는 파일 기존 하네스를 따르라고 했으나 코드 전문을 넣었다.

**Type consistency:**
- `_restart({String reason, bool force})` — Task 4 정의, Task 3의 `await _restart()`는 Task 4에서 `reason:'unresponsive-retry', force:true`로 갱신 ✅
- `_reconnectNow(String reason)` — Task 4 정의, Task 5 `_reconnectNow('network')` ✅
- `_fail(gen, {outcome, errorKey, reconnect})` — Task 3 정의, Task 6 재정의(같은 시그니처) ✅
- `state.phase.hasVideo/isConnecting` — Task 2 정의, Task 3·4·5·6 사용 ✅
- `WebRtcLiveView.retryButtonKey/pillKey/pillKeyFor` — Task 7 정의·테스트 일치 ✅
- `ModuleLink`·`moduleLinkProvider`·`DeviceOfflineNotice.checkingKey` — Task 8 정의·테스트 일치 ✅
- `_Harness.diag`, `_FakePc.statsBroken`, `_FakeSignaling.failOfferWith`, `_ticks`, `_stream` — 정의 task(1·5·3·5·5)가 사용 task보다 앞섬 ✅
