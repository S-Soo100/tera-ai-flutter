# PRD 기준 앱 전면 재설계 Implementation Plan — Part 1: 기반 + 4탭 셸

> ⚠️ **2026-08-08 기획 리셋 이전 문서다.** 이 계획서가 만든 구현의 디자인이 기획 의도를 만족하지 못해,
> 기존 구현을 전제하지 않는 새 기획안(`docs/prd-vivanart-app.md`)이 작성되었다.
> 이 문서는 **"무엇이 어떻게 만들어졌는지"의 기록**으로만 유효하다. 신규 작업의 근거로 쓰지 말 것.

> ✅ **완료 (2026-08-08 소급 확인).** 구현은 진행됐는데 체크박스만 갱신이 안 된 상태였다.
> 소급 근거: Task 1~6 산출물 파일 전수 실존(`day_window.dart`·`device_mode.dart`·`enclosure_set.dart`·
> `enclosure_set_repository.dart`·`home_set_providers.dart`·`tab_branches.dart`·`stats_screen.dart`,
> `pet.g.dart`에 `enclosureId` 반영) + `flutter test` 200개 전부 통과 + 4탭 라우터 실동작.
> 단, **개별 스텝의 실행 순서(테스트 먼저 실패 확인 등)까지 소급 검증한 것은 아니다** — 최종 상태만 확인했다.

> **구현 방식 (CAOF):** Critical 트랙. 이 계획을 task 단위로 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 신규 PRD(`docs/prd-vivanart-app.md`)를 단일 기준으로, 4탭 IA(홈/통계/마이크레/커뮤니티)와 "사육장 세트" 도메인 위에 홈 탭을 재구성한다. Part 1은 그 토대(도메인·데이터·탭 셸)를 만든다.

**Architecture:** PRD의 최소 단위는 **사육장 세트**(사육장 1 + 캠 0~1 + 제어기 0~1 + 개체 0~1)다. 세트 구성에서 `DeviceMode`(통합/사육장단품/캠단품/없음)를 도출하고, 홈 탭의 모든 분기가 이 한 값에서 파생된다. 기존 화면(`crecam_screen`, `smart_cage_screen`)은 삭제하지 않고 탭에서만 내린다 — 되돌리기 비용을 낮추기 위함.

**Tech Stack:** Flutter · Riverpod 2 · GoRouter (StatefulShellRoute) · Supabase (enclosures/devices/cameras/telemetry/commands/motion_clips) · Hive (Pet) · easy_localization

---

## 전제 (Assumptions) — 구현 전 확인 필요

| # | 가정 | 근거 | 틀렸을 때 영향 |
|---|---|---|---|
| A1 | 세트의 앵커는 `enclosures` 행. 캠·제어기·개체가 여기에 붙는다 | PRD §2 "한개의 사육장에는 한개의 캠과 한마리의 도마뱀" | 세트 모델 전면 재작성 |
| A2 | 개체↔사육장 연결이 현재 없다 → `Pet`(Hive)에 `enclosureId` 추가 | `lib/features/my_pets/domain/pet.dart` 필드 0~12에 없음 | Task 3 불필요 |
| A3 | 당일 = **07:00 ~ 익일 07:00** (PRD §5-1.2 채택). §4의 "어제 19시~오늘 7시"는 불일치로 보고 PRD 우선 | PRD Q9 | 전 화면 집계 창 재계산 |
| A4 | 4탭 전환 시 `/crecam`·`/smart-cage` 화면 파일은 **보존**, 라우트만 보조 경로로 강등 | 되돌리기 비용 | — |
| A5 | 분무 = `relay`(워터펌프). `module_actuator_relay`=`워터펌프` | `assets/l10n/ko.json` | 제어판 매핑 오류 |

## 백엔드 선행과제 (terra-server) — 앱과 병렬 진행

앱은 전부 **graceful degrade**로 구현한다(없으면 해당 UI 미노출). 즉 이 과제들이 Part 1을 막지 않는다.

| # | 과제 | 막히는 PRD 항목 | 앱측 폴백 |
|---|---|---|---|
| BE1 | `telemetry_5m` 집계 뷰 | §3.4 차트 "5분 단위" | `telemetry_30m`(30분 버킷)로 렌더 |
| BE2 | `relay_pulse` 명령(1회 분사) | §3.4 "1회 즉시 분사" | `relay_toggle` 1회 발행 |
| BE3 | `led_on` payload `brightness` | §3.4 LED 0~100% 슬라이더 | payload 동봉 후 무시 허용 |
| BE4 | `device_timers` 테이블 | §3.4 진행 중 타이머 칩 | 조회 실패 → 칩 미노출 |
| BE5 | `behavior_logs` RLS(labeler 정책) | §3.5 필터칩/요약칩 | 라벨 없음 → 전체 미분류 |

## 타깃 파일 구조 (Part 1)

```
lib/features/home/
├── domain/
│   ├── day_window.dart          # 07:00 기준 당일 창 + 차트 범위  (Task 1)
│   ├── device_mode.dart         # 통합/사육장단품/캠단품/없음      (Task 2)
│   └── enclosure_set.dart       # 세트 = 사육장+캠+제어기+개체     (Task 2)
├── data/
│   └── enclosure_set_repository.dart                              (Task 4)
└── presentation/
    └── home_set_providers.dart  # 세트 목록/선택/현재세트          (Task 5)

lib/features/my_pets/domain/pet.dart   # @HiveField(13) enclosureId (Task 3)
lib/core/router/app_router.dart        # 4탭 전환                   (Task 6)
assets/l10n/ko.json                    # 탭 라벨 키                 (Task 6)
```

---

### Task 1: DayWindow — 07:00 기준 당일 창

**Context:**
- Depends on: 없음
- Inputs: 없음 (순수 함수)
- Outputs: `lib/features/home/domain/day_window.dart` — `DayWindow.of(DateTime)`, `DayWindow.chartRange(DateTime)`
- Must know: PRD의 하루는 자정이 아니라 **07:00 경계**다. 07:00 이전 시각은 *전날* 창에 속한다. 차트 범위는 이와 별개로 "전날 19:00 ~ 현재"라 창 계산을 공유하지 않는다. 기존 `highlights_controller.dart`의 `lastNightSince/lastNightEnd`(22~06시)는 어젯밤 리포트 전용이므로 **건드리지 않는다**.
- Acceptance: `flutter test test/features/home/day_window_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/day_window.dart`
- Test: `test/features/home/day_window_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/day_window_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/day_window.dart';

void main() {
  group('DayWindow.of — 07:00 경계', () {
    test('07:00 정각은 당일 창의 시작', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 7, 0));
      expect(w.start, DateTime(2026, 8, 5, 7));
      expect(w.end, DateTime(2026, 8, 6, 7));
    });

    test('06:59는 전날 창에 속한다', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 6, 59));
      expect(w.start, DateTime(2026, 8, 4, 7));
      expect(w.end, DateTime(2026, 8, 5, 7));
    });

    test('23:30은 당일 창', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 23, 30));
      expect(w.start, DateTime(2026, 8, 5, 7));
    });

    test('labelDate = 창이 시작한 날짜', () {
      expect(DayWindow.of(DateTime(2026, 8, 5, 3)).labelDate,
          DateTime(2026, 8, 4));
    });

    test('contains — 경계는 start 포함, end 미포함', () {
      final w = DayWindow.of(DateTime(2026, 8, 5, 12));
      expect(w.contains(DateTime(2026, 8, 5, 7)), isTrue);
      expect(w.contains(DateTime(2026, 8, 6, 7)), isFalse);
    });

    test('forDate — 특정 날짜의 창 (날짜 스크롤러용)', () {
      final w = DayWindow.forDate(DateTime(2026, 8, 3));
      expect(w.start, DateTime(2026, 8, 3, 7));
      expect(w.end, DateTime(2026, 8, 4, 7));
    });
  });

  group('DayWindow.chartRange — 전날 19:00 ~ 현재', () {
    test('시작은 전날 19:00, 끝은 현재', () {
      final now = DateTime(2026, 8, 5, 14, 30);
      final r = DayWindow.chartRange(now);
      expect(r.start, DateTime(2026, 8, 4, 19));
      expect(r.end, now);
    });

    test('새벽 02:00에도 시작은 전날(=8/4) 19:00', () {
      final r = DayWindow.chartRange(DateTime(2026, 8, 5, 2));
      expect(r.start, DateTime(2026, 8, 4, 19));
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/day_window_test.dart
```

Expected: FAIL — `Error: Couldn't resolve the package 'tera_ai' ... day_window.dart` (파일 없음)

- [x] **Step 3: Write minimal implementation**

```dart
// lib/features/home/domain/day_window.dart

/// PRD §5-1.2 시간 정책: 당일 = 07:00 ~ 익일 07:00 (야행성 활동 주기 반영).
///
/// 자정이 아니라 **07:00**이 하루의 경계다. 06:59는 전날 창에 속한다.
/// 어젯밤 리포트(22~06시)의 `lastNightSince/lastNightEnd`와는 별개 개념이니
/// 혼용하지 말 것.
class DayWindow {
  /// 창 시작 (inclusive), 항상 07:00.
  final DateTime start;

  /// 창 끝 (exclusive), 항상 익일 07:00.
  final DateTime end;

  const DayWindow._(this.start, this.end);

  /// [now]가 속한 창.
  factory DayWindow.of(DateTime now) {
    final anchor = now.hour < dayStartHour
        ? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1))
        : DateTime(now.year, now.month, now.day);
    return DayWindow.forDate(anchor);
  }

  /// [date]의 날짜 부분을 기준으로 한 창 (날짜 스크롤러가 쓴다).
  factory DayWindow.forDate(DateTime date) {
    final s = DateTime(date.year, date.month, date.day, dayStartHour);
    return DayWindow._(s, s.add(const Duration(days: 1)));
  }

  /// 하루의 시작 시각(시). PRD 고정값.
  static const int dayStartHour = 7;

  /// 차트 X축 시작 시각(시). PRD §5-1.2 "전날 19:00부터".
  static const int chartStartHour = 19;

  /// 창을 대표하는 날짜(= 시작한 날). 날짜 라벨에 쓴다.
  DateTime get labelDate => DateTime(start.year, start.month, start.day);

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// 최근 24시간 실시간 차트 범위: 전날 19:00 ~ [now].
  static ({DateTime start, DateTime end}) chartRange(DateTime now) {
    final yesterday =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    return (
      start: DateTime(yesterday.year, yesterday.month, yesterday.day, chartStartHour),
      end: now,
    );
  }
}
```

- [x] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/home/day_window_test.dart
```

Expected: `All tests passed!` (8 tests)

- [x] **Step 5: Commit**

```bash
git add lib/features/home/domain/day_window.dart test/features/home/day_window_test.dart
git commit -m "feat(home): DayWindow — PRD 07:00 기준 당일 창 + 차트 범위"
```

---

### Task 2: EnclosureSet + DeviceMode — 세트 도메인

**Context:**
- Depends on: 없음 (Task 1과 병렬 가능)
- Inputs: 기존 도메인 타입 `Enclosure`(`lib/features/my_cage/domain/enclosure.dart`), `Device`(`.../device.dart`), `TerraCamera`(`.../terra_camera.dart`), `Pet`(`lib/features/my_pets/domain/pet.dart`)
- Outputs: `lib/features/home/domain/device_mode.dart`, `lib/features/home/domain/enclosure_set.dart`
- Must know: PRD §5-1.1의 홈 UI 3분기가 전부 이 `DeviceMode` 하나에서 나온다. `Device`는 사육장 IoT 제어기이고 `TerraCamera`가 캠이다 — 이름이 헷갈리니 주의. 캠도 제어기도 없는 세트(`none`)는 PRD에 명세가 없지만 등록 직후 실재하므로 enum에 포함하고 홈에서 빈 상태로 처리한다.
- Acceptance: `flutter test test/features/home/enclosure_set_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/device_mode.dart`, `lib/features/home/domain/enclosure_set.dart`
- Test: `test/features/home/enclosure_set_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/enclosure_set_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/device_mode.dart';
import 'package:tera_ai/features/home/domain/enclosure_set.dart';
import 'package:tera_ai/features/my_cage/domain/device.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';
import 'package:tera_ai/features/my_cage/domain/terra_camera.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';

Enclosure _enc() => Enclosure(
      id: 'enc-1',
      name: '1번 사육장',
      species: 'crested_gecko',
      createdAt: DateTime(2026, 1, 1),
    );

Device _dev() => const Device(
      id: 'dev-1',
      ownerId: 'u1',
      enclosureId: 'enc-1',
      name: '제어기',
      isOnline: true,
      lastSeenAt: null,
    );

TerraCamera _cam() => TerraCamera(
      id: 'cam-1',
      cameraId: 'p4cam-1',
      name: '캠',
      isOnline: true,
      enclosureId: 'enc-1',
      createdAt: DateTime(2026, 1, 1),
    );

Pet _pet() => Pet(
      id: 'pet-1',
      name: '젤리',
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
    );

void main() {
  group('EnclosureSet.mode', () {
    test('캠 + 제어기 → integrated', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: _cam(), pet: _pet());
      expect(s.mode, DeviceMode.integrated);
    });

    test('제어기만 → cageOnly', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: null, pet: _pet());
      expect(s.mode, DeviceMode.cageOnly);
    });

    test('캠만 → camOnly', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: null, camera: _cam(), pet: _pet());
      expect(s.mode, DeviceMode.camOnly);
    });

    test('둘 다 없음 → none', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: null, camera: null, pet: null);
      expect(s.mode, DeviceMode.none);
    });
  });

  group('DeviceMode 서브탭 가용성 (PRD §3.3)', () {
    test('integrated — 둘 다 활성, 기본은 제어', () {
      expect(DeviceMode.integrated.controlEnabled, isTrue);
      expect(DeviceMode.integrated.timelineEnabled, isTrue);
      expect(DeviceMode.integrated.defaultTab, HomeSubTab.control);
    });

    test('cageOnly — 타임라인 비활성, 기본은 제어', () {
      expect(DeviceMode.cageOnly.controlEnabled, isTrue);
      expect(DeviceMode.cageOnly.timelineEnabled, isFalse);
      expect(DeviceMode.cageOnly.defaultTab, HomeSubTab.control);
    });

    test('camOnly — 제어 비활성, 기본은 타임라인', () {
      expect(DeviceMode.camOnly.controlEnabled, isFalse);
      expect(DeviceMode.camOnly.timelineEnabled, isTrue);
      expect(DeviceMode.camOnly.defaultTab, HomeSubTab.timeline);
    });

    test('none — 둘 다 비활성', () {
      expect(DeviceMode.none.controlEnabled, isFalse);
      expect(DeviceMode.none.timelineEnabled, isFalse);
    });
  });

  group('showsLiveVideo (PRD §3.2)', () {
    test('캠이 있으면 라이브 영역, 없으면 프로필 카드', () {
      expect(DeviceMode.integrated.showsLiveVideo, isTrue);
      expect(DeviceMode.camOnly.showsLiveVideo, isTrue);
      expect(DeviceMode.cageOnly.showsLiveVideo, isFalse);
      expect(DeviceMode.none.showsLiveVideo, isFalse);
    });
  });

  group('EnclosureSet 표시 라벨', () {
    test('개체가 있으면 "개체명 (사육장명)"', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: _cam(), pet: _pet());
      expect(s.displayLabel, '젤리 (1번 사육장)');
    });

    test('개체가 없으면 사육장명만', () {
      final s = EnclosureSet(
          enclosure: _enc(), device: _dev(), camera: _cam(), pet: null);
      expect(s.displayLabel, '1번 사육장');
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/enclosure_set_test.dart
```

Expected: FAIL — `device_mode.dart` / `enclosure_set.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write minimal implementation**

```dart
// lib/features/home/domain/device_mode.dart

/// 홈 탭 서브탭 식별자. PRD §3.3 2구분 세그먼트 탭.
enum HomeSubTab { control, timeline }

/// PRD §5-1.1 "기기 연동 모드에 따른 홈 탭 UI 자동 전환".
///
/// 세트가 가진 기기 조합에서 도출되며, 홈 탭의 모든 분기(상단 영역 종류,
/// 서브탭 활성/비활성, 기본 선택 탭)가 이 값 하나에서 나온다.
enum DeviceMode {
  /// 통합 세트 — 캠 + 제어기 둘 다.
  integrated,

  /// 사육장 단품 — 제어기만. 상단은 개체 프로필 카드로 대체.
  cageOnly,

  /// 캠 단품 — 캠만. 사육장 제어 서브탭 비활성.
  camOnly,

  /// 기기 미연동 — 사육장만 등록된 상태. PRD 미명세이나 등록 직후 실재한다.
  none;

  /// 사육장 제어 서브탭 활성 여부.
  bool get controlEnabled =>
      this == DeviceMode.integrated || this == DeviceMode.cageOnly;

  /// 타임라인 서브탭 활성 여부.
  bool get timelineEnabled =>
      this == DeviceMode.integrated || this == DeviceMode.camOnly;

  /// 상단 고정 영역에 라이브 비디오를 띄우는가. false면 개체 프로필 카드.
  bool get showsLiveVideo =>
      this == DeviceMode.integrated || this == DeviceMode.camOnly;

  /// 진입 시 기본 선택 서브탭. 활성 탭이 없으면 control(빈 상태 표시용).
  HomeSubTab get defaultTab =>
      controlEnabled ? HomeSubTab.control : HomeSubTab.timeline;
}
```

```dart
// lib/features/home/domain/enclosure_set.dart
import '../../my_cage/domain/device.dart';
import '../../my_cage/domain/enclosure.dart';
import '../../my_cage/domain/terra_camera.dart';
import '../../my_pets/domain/pet.dart';
import 'device_mode.dart';

/// PRD의 최소 단위 "사육장 세트".
///
/// 앵커는 [enclosure]. 캠([camera])·IoT 제어기([device])·개체([pet])가 여기에
/// 0~1개씩 붙는다 (PRD §2 전제: 사육장 1 : 캠 1 : 개체 1).
///
/// 주의: [device]는 사육장 IoT 제어기이고 [camera]가 펫캠이다. terra-server
/// 스키마의 `devices` / `cameras`가 각각 대응한다.
class EnclosureSet {
  final Enclosure enclosure;
  final Device? device;
  final TerraCamera? camera;
  final Pet? pet;

  const EnclosureSet({
    required this.enclosure,
    required this.device,
    required this.camera,
    required this.pet,
  });

  String get id => enclosure.id;

  DeviceMode get mode {
    final hasCam = camera != null;
    final hasDev = device != null;
    if (hasCam && hasDev) return DeviceMode.integrated;
    if (hasDev) return DeviceMode.cageOnly;
    if (hasCam) return DeviceMode.camOnly;
    return DeviceMode.none;
  }

  /// 헤더 드롭다운 라벨. PRD 목업 문구 `젤리 (1번 사육장)` 형식.
  String get displayLabel =>
      pet == null ? enclosure.name : '${pet!.name} (${enclosure.name})';
}
```

- [x] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/home/enclosure_set_test.dart
```

Expected: `All tests passed!` (11 tests)

- [x] **Step 5: Commit**

```bash
git add lib/features/home/domain/device_mode.dart lib/features/home/domain/enclosure_set.dart test/features/home/enclosure_set_test.dart
git commit -m "feat(home): EnclosureSet + DeviceMode — PRD 기기연동 모드 분기 도메인"
```

---

### Task 3: `Pet.enclosureId` — 개체를 사육장 세트에 연결

**Context:**
- Depends on: 없음 (Task 1·2와 병렬 가능)
- Inputs: `lib/features/my_pets/domain/pet.dart` (Hive `@HiveType(typeId: 0)`, 현재 필드 0~12)
- Outputs: `Pet.enclosureId` (`@HiveField(13)`, nullable, mutable) + 재생성된 `pet.g.dart`
- Must know: **기존 Hive 레코드를 깨면 안 된다.** 새 필드는 반드시 (a) 미사용 인덱스 13, (b) nullable, (c) 생성자 optional 이어야 한다 — 셋 중 하나라도 어기면 기존 사용자 데이터가 읽히지 않는다. `Pet`은 `copyWith`가 없고 필드가 mutable이므로 `pet.enclosureId = x` 직접 대입이 이 코드베이스의 관례다. `pet.g.dart`는 **손으로 고치지 말고 build_runner로 재생성**한다.
- Acceptance: `flutter test test/features/my_pets/pet_enclosure_test.dart` → All tests passed. 그리고 `flutter analyze` 에러 0.

**Files:**
- Modify: `lib/features/my_pets/domain/pet.dart` (필드 블록 끝 + 생성자)
- Regenerate: `lib/features/my_pets/domain/pet.g.dart`
- Test: `test/features/my_pets/pet_enclosure_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/my_pets/pet_enclosure_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';

Pet _pet({String? enclosureId}) => Pet(
      id: 'pet-1',
      name: '젤리',
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
      enclosureId: enclosureId,
    );

void main() {
  group('Pet.enclosureId', () {
    test('미지정이면 null — 기존 레코드 호환', () {
      expect(_pet().enclosureId, isNull);
    });

    test('생성자로 지정 가능', () {
      expect(_pet(enclosureId: 'enc-1').enclosureId, 'enc-1');
    });

    test('mutable — 배정/해제를 직접 대입으로 처리', () {
      final p = _pet();
      p.enclosureId = 'enc-9';
      expect(p.enclosureId, 'enc-9');
      p.enclosureId = null;
      expect(p.enclosureId, isNull);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/my_pets/pet_enclosure_test.dart
```

Expected: FAIL — `No named parameter with the name 'enclosureId'`

- [x] **Step 3: Add the field**

`lib/features/my_pets/domain/pet.dart` — `@HiveField(12) DateTime updatedAt;` 바로 뒤에 추가:

```dart
  /// 이 개체가 배정된 사육장 세트(`enclosures.id`). null = 미배정.
  /// PRD 세트 개념(사육장 1 : 캠 1 : 개체 1)의 개체측 연결점.
  /// 필드 인덱스 13은 신규 — 기존 레코드는 null로 읽힌다.
  @HiveField(13)
  String? enclosureId;
```

같은 파일 생성자에서 `DateTime? updatedAt,` 바로 앞에 추가:

```dart
    this.enclosureId,
```

- [x] **Step 4: Regenerate the Hive adapter**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `Succeeded after ...` 출력. `lib/features/my_pets/domain/pet.g.dart`에 `..writeByte(14)` 와 `..write(obj.enclosureId)` 가 생겼는지 확인:

```bash
grep -n "enclosureId" lib/features/my_pets/domain/pet.g.dart
```

Expected: 2줄 이상 매칭 (read 케이스 `13:` 와 write 케이스)

- [x] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/my_pets/pet_enclosure_test.dart && flutter analyze
```

Expected: `All tests passed!` + `No issues found!`

- [x] **Step 6: Commit**

```bash
git add lib/features/my_pets/domain/pet.dart lib/features/my_pets/domain/pet.g.dart test/features/my_pets/pet_enclosure_test.dart
git commit -m "feat(my_pets): Pet.enclosureId — 개체를 사육장 세트에 연결(HiveField 13)"
```

---

### Task 4: EnclosureSetRepository — 세트 조립

**Context:**
- Depends on: Task 2 (`EnclosureSet`), Task 3 (`Pet.enclosureId`)
- Inputs: `EnclosureRepository.listAll()`, `CameraRepository.listAll()`, `SupabaseModuleControlRepository.listDevices()`, `PetRepository.getAllPets()`
- Outputs: `lib/features/home/data/enclosure_set_repository.dart` — `EnclosureSetRepository.listSets()`
- Must know: 네 소스는 **서로 다른 저장소**다 — enclosures/cameras/devices는 Supabase(RLS로 본인 것만), pets는 Hive 로컬. 그래서 이 클래스는 함수 주입(loader 콜백)으로 받아 **네트워크 없이 단위 테스트 가능**하게 만든다 (기존 `MotionClipRepository`의 `ActivityRowsLoader` 관례와 동일). 세 원격 호출은 `Future.wait`로 병렬 — 순차로 하면 진입이 3배 느려진다. `enclosure_id`가 null인 캠·제어기는 어느 세트에도 속하지 않으므로 **버린다**(미배정 기기 관리 UI는 이 계획 범위 밖).
- Acceptance: `flutter test test/features/home/enclosure_set_repository_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/data/enclosure_set_repository.dart`
- Test: `test/features/home/enclosure_set_repository_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/enclosure_set_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/data/enclosure_set_repository.dart';
import 'package:tera_ai/features/home/domain/device_mode.dart';
import 'package:tera_ai/features/my_cage/domain/device.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';
import 'package:tera_ai/features/my_cage/domain/terra_camera.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';

Enclosure _enc(String id, String name) =>
    Enclosure(id: id, name: name, createdAt: DateTime(2026, 1, 1));

Device _dev(String id, String? encId) => Device(
      id: id,
      ownerId: 'u1',
      enclosureId: encId,
      name: 'dev',
      isOnline: true,
      lastSeenAt: null,
    );

TerraCamera _cam(String id, String? encId) => TerraCamera(
      id: id,
      cameraId: 'p4cam-$id',
      name: 'cam',
      isOnline: true,
      enclosureId: encId,
      createdAt: DateTime(2026, 1, 1),
    );

Pet _pet(String id, String name, String? encId) => Pet(
      id: id,
      name: name,
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
      enclosureId: encId,
    );

EnclosureSetRepository _repo({
  List<Enclosure> enclosures = const [],
  List<Device> devices = const [],
  List<TerraCamera> cameras = const [],
  List<Pet> pets = const [],
}) =>
    EnclosureSetRepository(
      loadEnclosures: () async => enclosures,
      loadDevices: () async => devices,
      loadCameras: () async => cameras,
      loadPets: () => pets,
    );

void main() {
  group('EnclosureSetRepository.listSets', () {
    test('사육장 없음 → 빈 목록', () async {
      expect(await _repo().listSets(), isEmpty);
    });

    test('캠·제어기·개체가 enclosure_id로 결합된다', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', '1번 사육장')],
        devices: [_dev('d1', 'e1')],
        cameras: [_cam('c1', 'e1')],
        pets: [_pet('p1', '젤리', 'e1')],
      ).listSets();

      expect(sets, hasLength(1));
      expect(sets.single.mode, DeviceMode.integrated);
      expect(sets.single.displayLabel, '젤리 (1번 사육장)');
    });

    test('다른 사육장 소속 기기는 섞이지 않는다', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', 'A'), _enc('e2', 'B')],
        devices: [_dev('d1', 'e1')],
        cameras: [_cam('c1', 'e2')],
        pets: const [],
      ).listSets();

      expect(sets, hasLength(2));
      expect(sets[0].mode, DeviceMode.cageOnly);
      expect(sets[1].mode, DeviceMode.camOnly);
    });

    test('enclosure_id가 null인 기기는 버린다', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', 'A')],
        devices: [_dev('d1', null)],
        cameras: [_cam('c1', null)],
      ).listSets();

      expect(sets.single.mode, DeviceMode.none);
    });

    test('같은 사육장에 기기가 둘이면 첫 번째만 (PRD 1:1 전제)', () async {
      final sets = await _repo(
        enclosures: [_enc('e1', 'A')],
        cameras: [_cam('c1', 'e1'), _cam('c2', 'e1')],
      ).listSets();

      expect(sets.single.camera!.id, 'c1');
    });

    test('정렬은 사육장 생성순 — 세트 순서가 세션마다 흔들리면 안 된다', () async {
      final sets = await _repo(
        enclosures: [
          Enclosure(id: 'e2', name: 'B', createdAt: DateTime(2026, 3, 1)),
          Enclosure(id: 'e1', name: 'A', createdAt: DateTime(2026, 1, 1)),
        ],
      ).listSets();

      expect(sets.map((s) => s.id).toList(), ['e1', 'e2']);
    });

    test('원격 호출 하나가 실패해도 나머지로 조립한다', () async {
      final repo = EnclosureSetRepository(
        loadEnclosures: () async => [_enc('e1', 'A')],
        loadDevices: () async => throw StateError('devices down'),
        loadCameras: () async => [_cam('c1', 'e1')],
        loadPets: () => const [],
      );

      final sets = await repo.listSets();
      expect(sets.single.mode, DeviceMode.camOnly);
    });

    test('사육장 조회 자체가 실패하면 throw — 빈 화면으로 위장하지 않는다', () async {
      final repo = EnclosureSetRepository(
        loadEnclosures: () async => throw StateError('enclosures down'),
        loadDevices: () async => const [],
        loadCameras: () async => const [],
        loadPets: () => const [],
      );

      expect(repo.listSets(), throwsStateError);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/enclosure_set_repository_test.dart
```

Expected: FAIL — `enclosure_set_repository.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write minimal implementation**

```dart
// lib/features/home/data/enclosure_set_repository.dart
import '../../my_cage/domain/device.dart';
import '../../my_cage/domain/enclosure.dart';
import '../../my_cage/domain/terra_camera.dart';
import '../../my_pets/domain/pet.dart';
import '../domain/enclosure_set.dart';

/// 사육장 세트를 네 저장소에서 조립한다.
///
/// enclosures/devices/cameras는 Supabase(RLS로 본인 것만), pets는 Hive 로컬이라
/// 소스가 이질적이다. 그래서 loader를 주입받아 네트워크 없이 테스트 가능하게 둔다
/// (`MotionClipRepository`의 ActivityRowsLoader와 같은 관례).
///
/// 기기 조회는 **부분 실패를 허용**한다 — 캠 서비스가 죽어도 사육장 제어는 계속
/// 보여야 하기 때문. 반면 사육장 목록 조회 실패는 그대로 throw한다: 세트가 정말
/// 없는 것과 조회가 실패한 것을 빈 화면으로 뭉개면 사용자가 오해한다.
class EnclosureSetRepository {
  final Future<List<Enclosure>> Function() _loadEnclosures;
  final Future<List<Device>> Function() _loadDevices;
  final Future<List<TerraCamera>> Function() _loadCameras;
  final List<Pet> Function() _loadPets;

  EnclosureSetRepository({
    required Future<List<Enclosure>> Function() loadEnclosures,
    required Future<List<Device>> Function() loadDevices,
    required Future<List<TerraCamera>> Function() loadCameras,
    required List<Pet> Function() loadPets,
  })  : _loadEnclosures = loadEnclosures,
        _loadDevices = loadDevices,
        _loadCameras = loadCameras,
        _loadPets = loadPets;

  /// 사육장 생성순으로 정렬된 세트 목록.
  Future<List<EnclosureSet>> listSets() async {
    // 사육장은 앵커라 실패를 삼키지 않는다.
    final enclosures = await _loadEnclosures();
    if (enclosures.isEmpty) return const [];

    // 기기 조회는 병렬 + 부분 실패 허용. 레코드 `.wait`로 받아 캐스팅을 없앤다
    // (List<Object> 캐스팅은 타입 실수를 런타임까지 숨긴다).
    final (devices, cameras) = await (
      _safe(_loadDevices, const <Device>[]),
      _safe(_loadCameras, const <TerraCamera>[]),
    ).wait;
    final pets = _loadPets();

    final byEnclosure = [...enclosures]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return [
      for (final e in byEnclosure)
        EnclosureSet(
          enclosure: e,
          device: _firstWhereOrNull(devices, (d) => d.enclosureId == e.id),
          camera: _firstWhereOrNull(cameras, (c) => c.enclosureId == e.id),
          pet: _firstWhereOrNull(pets, (p) => p.enclosureId == e.id),
        ),
    ];
  }

  /// 기기 조회 1건의 실패를 [fallback]으로 흡수한다.
  static Future<List<T>> _safe<T>(
    Future<List<T>> Function() load,
    List<T> fallback,
  ) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  static T? _firstWhereOrNull<T>(List<T> items, bool Function(T) test) {
    for (final it in items) {
      if (test(it)) return it;
    }
    return null;
  }
}
```

- [x] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/home/enclosure_set_repository_test.dart
```

Expected: `All tests passed!` (8 tests)

- [x] **Step 5: Commit**

```bash
git add lib/features/home/data/enclosure_set_repository.dart test/features/home/enclosure_set_repository_test.dart
git commit -m "feat(home): EnclosureSetRepository — 사육장/캠/제어기/개체 세트 조립"
```

---

### Task 5: 세트 providers — 목록 / 선택 / 현재 세트

**Context:**
- Depends on: Task 4 (`EnclosureSetRepository`)
- Inputs: `enclosureRepositoryProvider`·`cameraRepositoryProvider`(`lib/features/my_cage/presentation/my_cage_providers.dart`), `supabaseModuleControlRepositoryProvider`(`.../supabase_module_providers.dart`), `petRepositoryProvider`(`lib/features/my_pets/data/pet_repository.dart`), `currentUserProvider`(`lib/features/auth/presentation/auth_providers.dart`)
- Outputs: `lib/features/home/presentation/home_set_providers.dart` — `enclosureSetRepositoryProvider`, `enclosureSetsProvider`, `selectedSetIndexProvider`, `currentSetProvider`, `currentDeviceModeProvider`, `homeSubTabProvider`
- Must know: **계정 격리 필수.** 프로젝트 규칙상 인증 의존 provider는 `ref.watch(currentUserProvider.select((u) => u?.id))`로 **계정 id만** 감시한다. `User` 객체 전체를 watch하면 `updatedAt` 같은 무관한 필드 변경에도 재빌드된다. 이걸 빠뜨리면 계정 전환 시 이전 계정 세트가 캐시된 채 남는다(메모리 `project_auth_provider_stale_pattern`). `selectedSetIndexProvider`는 세트 개수가 줄었을 때 인덱스가 범위를 넘을 수 있으므로 `currentSetProvider`에서 **clamp**한다 — 안 하면 캠 해제 직후 RangeError.
- Acceptance: `flutter test test/features/home/home_set_providers_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/presentation/home_set_providers.dart`
- Test: `test/features/home/home_set_providers_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/home_set_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/device_mode.dart';
import 'package:tera_ai/features/home/domain/enclosure_set.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';

EnclosureSet _set(String id) => EnclosureSet(
      enclosure:
          Enclosure(id: id, name: id, createdAt: DateTime(2026, 1, 1)),
      device: null,
      camera: null,
      pet: null,
    );

ProviderContainer _container(List<EnclosureSet> sets) => ProviderContainer(
      overrides: [
        enclosureSetsProvider.overrideWith((ref) async => sets),
      ],
    );

void main() {
  test('세트 없음 → currentSet은 null', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    expect(await c.read(currentSetProvider.future), isNull);
  });

  test('기본 선택은 첫 세트', () async {
    final c = _container([_set('e1'), _set('e2')]);
    addTearDown(c.dispose);
    expect((await c.read(currentSetProvider.future))!.id, 'e1');
  });

  test('선택 인덱스 변경이 currentSet에 반영된다', () async {
    final c = _container([_set('e1'), _set('e2')]);
    addTearDown(c.dispose);
    c.read(selectedSetIndexProvider.notifier).state = 1;
    expect((await c.read(currentSetProvider.future))!.id, 'e2');
  });

  test('인덱스가 범위를 넘으면 clamp — RangeError 없이 마지막 세트', () async {
    final c = _container([_set('e1')]);
    addTearDown(c.dispose);
    c.read(selectedSetIndexProvider.notifier).state = 5;
    expect((await c.read(currentSetProvider.future))!.id, 'e1');
  });

  test('음수 인덱스도 clamp', () async {
    final c = _container([_set('e1'), _set('e2')]);
    addTearDown(c.dispose);
    c.read(selectedSetIndexProvider.notifier).state = -3;
    expect((await c.read(currentSetProvider.future))!.id, 'e1');
  });

  test('currentDeviceMode — 세트 없으면 none', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    expect(await c.read(currentDeviceModeProvider.future), DeviceMode.none);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/home_set_providers_test.dart
```

Expected: FAIL — `home_set_providers.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write minimal implementation**

```dart
// lib/features/home/presentation/home_set_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../../my_pets/data/pet_repository.dart';
import '../data/enclosure_set_repository.dart';
import '../domain/device_mode.dart';
import '../domain/enclosure_set.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final enclosureSetRepositoryProvider =
    Provider<EnclosureSetRepository>((ref) {
  return EnclosureSetRepository(
    loadEnclosures: () => ref.read(enclosureRepositoryProvider).listAll(),
    loadDevices: () =>
        ref.read(supabaseModuleControlRepositoryProvider).listDevices(),
    loadCameras: () => ref.read(cameraRepositoryProvider).listAll(),
    loadPets: () => ref.read(petRepositoryProvider).getAllPets(),
  );
});

// ── 세트 목록 ──────────────────────────────────────────────────────────────────

/// 사육장 세트 목록.
///
/// 계정 id만 select-watch 한다 — User 객체 전체를 watch하면 updatedAt 같은
/// 무관한 필드 변경에도 재조회가 돈다. 반대로 아예 watch하지 않으면 계정 전환
/// 시 이전 계정 세트가 캐시된 채 남는다.
final enclosureSetsProvider =
    FutureProvider<List<EnclosureSet>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(enclosureSetRepositoryProvider).listSets();
});

// ── 선택 상태 ──────────────────────────────────────────────────────────────────

/// 헤더 드롭다운 / 상단 스와이프로 갱신되는 선택 인덱스.
/// 범위 검증은 여기서 하지 않고 [currentSetProvider]가 clamp 한다.
final selectedSetIndexProvider = StateProvider<int>((ref) => 0);

/// 현재 서브탭. 세트가 바뀌면 [DeviceMode.defaultTab]으로 되돌린다.
final homeSubTabProvider = StateProvider<HomeSubTab>(
  (ref) => HomeSubTab.control,
);

// ── 현재 세트 ──────────────────────────────────────────────────────────────────

/// 선택된 세트. 세트가 없으면 null.
///
/// 인덱스는 clamp 한다: 캠 해제·사육장 삭제로 목록이 줄면 저장된 인덱스가
/// 범위를 넘어 RangeError가 난다.
final currentSetProvider = FutureProvider<EnclosureSet?>((ref) async {
  // watch는 반드시 await **앞에서** 한다. await 뒤의 ref.watch는 의존이
  // 등록되지 않거나 늦게 등록돼 인덱스 변경이 반영되지 않는다.
  final raw = ref.watch(selectedSetIndexProvider);
  final sets = await ref.watch(enclosureSetsProvider.future);
  if (sets.isEmpty) return null;
  return sets[raw.clamp(0, sets.length - 1)];
});

/// 현재 세트의 기기 연동 모드. 세트가 없으면 [DeviceMode.none].
final currentDeviceModeProvider = FutureProvider<DeviceMode>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  return set?.mode ?? DeviceMode.none;
});
```

- [x] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/home/home_set_providers_test.dart && flutter analyze
```

Expected: `All tests passed!` (6 tests) + `No issues found!`

- [x] **Step 5: Commit**

```bash
git add lib/features/home/presentation/home_set_providers.dart test/features/home/home_set_providers_test.dart
git commit -m "feat(home): 세트 providers — 계정격리 watch + 인덱스 clamp"
```

---

### Task 6: 라우터 4탭 전환

**Context:**
- Depends on: 없음 (Task 1~5와 독립. 단 홈 화면 재구성은 Part 2)
- Inputs: `lib/core/router/app_router.dart` (현재 `StatefulShellRoute` 5브랜치: home/my-pets/crecam/smart-cage/community), `assets/l10n/ko.json` (`tab_*` 키)
- Outputs: 4탭 셸(홈/통계/마이크레/커뮤니티) + `/crecam`·`/smart-cage`를 보조 라우트로 강등 + `/stats` 신규
- Must know: **화면 파일은 삭제하지 않는다.** `CrecamScreen`·`SmartCageScreen`은 탭 브랜치에서 내려 보조 최상위 라우트로 옮긴다 — 되돌리기 비용을 낮추고, Part 2에서 홈이 완성될 때까지 기능 공백을 만들지 않기 위함. 하위 라우트(`cameras/pair`, `devices/pair`, `enclosures`, `motion-clips/:clipId` 등)는 **경로를 그대로 유지**해야 한다: 앱 곳곳의 `context.go('/crecam/...')` 호출이 깨진다. `/stats`는 PRD §3.4 "차트 터치 시 통계 탭으로 이동"의 목적지라 Part 1에서 **빈 스캐폴드**로 먼저 만든다(내용은 스펙 미비 — 미작성 구간). `publicPaths`에 `/stats` 추가를 잊으면 비로그인 시 로그인으로 튄다.
- Acceptance: `flutter test test/features/home/router_tabs_test.dart` → All tests passed. 그리고 `flutter analyze` 에러 0.

**Files:**
- Create: `lib/features/stats/presentation/stats_screen.dart`
- Modify: `lib/core/router/app_router.dart` (브랜치 목록, `_ScaffoldWithBottomNav.destinations`, `publicPaths`)
- Modify: `assets/l10n/ko.json` (`tab_stats` 추가)
- Test: `test/features/home/router_tabs_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/router_tabs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tera_ai/core/router/tab_branches.dart';

void main() {
  group('4탭 IA (PRD 목업 바텀 네비)', () {
    test('탭은 홈/통계/마이크레/커뮤니티 4개', () {
      expect(kHomeTabPaths, ['/home', '/stats', '/my-pets', '/community']);
    });

    test('탭 라벨 키가 경로와 1:1', () {
      expect(kHomeTabLabelKeys, hasLength(kHomeTabPaths.length));
      expect(kHomeTabLabelKeys,
          ['tab_home', 'tab_stats', 'tab_my_pets', 'tab_community']);
    });

    test('크레캠·사육장은 더 이상 탭이 아니다', () {
      expect(kHomeTabPaths, isNot(contains('/crecam')));
      expect(kHomeTabPaths, isNot(contains('/smart-cage')));
    });

    test('보조 경로로는 살아있다 — 기존 딥링크 보존', () {
      expect(kLegacySecondaryPaths, contains('/crecam'));
      expect(kLegacySecondaryPaths, contains('/smart-cage'));
    });
  });

  group('publicPaths', () {
    test('통계 탭은 공개 경로 — 비로그인이 탭 눌러도 튕기지 않는다', () {
      expect(kPublicPaths, contains('/stats'));
    });
  });

  group('라우터 조립', () {
    test('GoRouter가 4탭 셸로 구성된다', () {
      final router = buildAppRouter(isAuthenticated: () => true);
      expect(router, isA<GoRouter>());
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/router_tabs_test.dart
```

Expected: FAIL — `tab_branches.dart` 미존재로 컴파일 에러

- [x] **Step 3: Extract the tab table**

```dart
// lib/core/router/tab_branches.dart

/// 바텀 네비 탭 경로. PRD 목업 바텀 네비 = 홈/통계/마이크레/커뮤니티 4탭.
///
/// 순서가 곧 탭 인덱스이고 `StatefulShellRoute`의 브랜치 순서와 일치해야 한다.
/// 라우터 본문에서 분리한 이유는 이 테이블만 단위 테스트하기 위해서다.
const List<String> kHomeTabPaths = [
  '/home',
  '/stats',
  '/my-pets',
  '/community',
];

/// [kHomeTabPaths]와 같은 순서의 i18n 라벨 키.
const List<String> kHomeTabLabelKeys = [
  'tab_home',
  'tab_stats',
  'tab_my_pets',
  'tab_community',
];

/// 탭에서 내렸지만 화면·딥링크는 유지하는 경로.
/// 삭제하지 않는 이유: 되돌리기 비용을 낮추고 홈 재구성 전까지 기능 공백을
/// 만들지 않기 위함. 하위 경로(`/crecam/cameras/pair` 등)도 그대로 산다.
const List<String> kLegacySecondaryPaths = ['/crecam', '/smart-cage'];

/// 인증 없이 접근 가능한 경로.
const List<String> kPublicPaths = [
  '/splash',
  '/home',
  '/stats',
  '/wiki',
  '/community',
  '/search',
  '/login',
  '/signup',
  '/verify-email',
  '/error',
];
```

- [x] **Step 4: Add the stats screen scaffold**

```dart
// lib/features/stats/presentation/stats_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 통계 탭. PRD §3.4 "차트 터치 시 통계 탭으로 이동"의 목적지.
///
/// 내용(온습도 일/주 그래프, 크레 활동 통계·분석)은 PRD 기능요약 수준까지만
/// 정의되어 별도 계획서에서 다룬다. 여기서는 탭이 존재하고 이동이 성립하는
/// 것까지만 보장한다.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('tab_stats'.tr())),
      body: Center(child: Text('stats_empty'.tr())),
    );
  }
}
```

- [x] **Step 5: Add i18n keys**

`assets/l10n/ko.json`의 `"tab_community"` 항목 바로 뒤에 추가:

```json
  "tab_stats": "통계",
  "stats_empty": "통계는 준비 중이에요",
```

- [x] **Step 6: Rewire the router**

`lib/core/router/app_router.dart`:

1. import 추가 — 파일 상단 import 블록 끝에:

```dart
import 'tab_branches.dart';
import '../../features/stats/presentation/stats_screen.dart';
```

2. `redirect` 안의 인라인 `const publicPaths = [...]` 블록(59~69행)을 삭제하고 아래로 교체:

```dart
      final isPublic = kPublicPaths.any(
        (p) => path == p || path.startsWith('$p/'),
      );
```

3. `StatefulShellRoute.indexedStack`의 `branches:`를 **홈 → 통계 → 마이크레 → 커뮤니티** 순으로 재배열한다. 홈·마이크레·커뮤니티 브랜치는 기존 `GoRoute` 정의를 **그대로 옮기고**, 통계 브랜치를 2번째로 새로 넣는다:

```dart
          // Tab 2: 통계
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
```

4. 크레캠·사육장 브랜치 2개를 `branches:`에서 **잘라내어**, `StatefulShellRoute` 블록 바로 뒤(`/wiki` GoRoute 앞)에 최상위 `GoRoute`로 붙여넣는다. `StatefulShellBranch(routes: [...])` 껍데기만 벗기고 내부 `GoRoute`는 하위 라우트 포함 그대로 유지한다.

5. `_ScaffoldWithBottomNav.destinations`를 4개로 교체:

```dart
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: kHomeTabLabelKeys[0].tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: kHomeTabLabelKeys[1].tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.pets_outlined),
            selectedIcon: const Icon(Icons.pets),
            label: kHomeTabLabelKeys[2].tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: kHomeTabLabelKeys[3].tr(),
          ),
        ],
```

6. `routerProvider` 본문을 `buildAppRouter`로 감싸 테스트 가능하게 만든다. 파일 하단 `_ScaffoldWithBottomNav` 앞에 추가하고, 기존 `GoRouter(...)` 반환부를 이 함수 안으로 옮긴다:

```dart
/// 라우터 조립. `isAuthenticated`를 주입받아 ProviderContainer 없이도
/// 테스트에서 구성 가능하게 한다.
GoRouter buildAppRouter({
  required bool Function() isAuthenticated,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == '/splash') return null;
      final isPublic = kPublicPaths.any(
        (p) => path == p || path.startsWith('$p/'),
      );
      if (!isAuthenticated() && !isPublic) return '/login';
      if (isAuthenticated() &&
          (path == '/login' || path == '/signup' || path == '/verify-email')) {
        return '/home';
      }
      return null;
    },
    routes: [ /* 기존 routes 목록을 그대로 이동 */ ],
  );
}
```

그리고 `routerProvider`는:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier();
  ref.listen(isAuthenticatedProvider, (_, __) => authNotifier.notify());
  return buildAppRouter(
    isAuthenticated: () => ref.read(isAuthenticatedProvider),
    refreshListenable: authNotifier,
  );
});
```

- [x] **Step 7: Run test to verify it passes**

```bash
flutter test test/features/home/router_tabs_test.dart && flutter analyze
```

Expected: `All tests passed!` (6 tests) + `No issues found!`

- [x] **Step 8: Verify the app still builds and navigates**

```bash
flutter test && flutter build apk --debug
```

Expected: 전체 테스트 통과 + `Built build/app/outputs/flutter-apk/app-debug.apk`

- [x] **Step 9: Commit**

```bash
git add lib/core/router/tab_branches.dart lib/core/router/app_router.dart lib/features/stats/presentation/stats_screen.dart assets/l10n/ko.json test/features/home/router_tabs_test.dart
git commit -m "feat(router): 4탭 IA 전환(홈/통계/마이크레/커뮤니티) — 크레캠·사육장은 보조 라우트로"
```

---

## 실행 순서 (자동진행용)

Task 1·2·3·6은 서로 독립이라 순서 무관. 4는 2·3을, 5는 4를 필요로 한다.

```
1 (DayWindow) ─┐
2 (Set/Mode) ──┼─→ 4 (Repository) ─→ 5 (Providers)
3 (Pet 필드) ──┘
6 (4탭 라우터) — 독립, 언제든
```

**커밋마다 지켜야 할 것 (프로젝트 규칙):**
- 각 Task 종료 시 `flutter analyze` 에러 0.
- `lib/` 변경을 push하려면 `pubspec.yaml` version bump가 필요하다 — pre-push 훅(`tools/git-hooks`)이 무버전업 push를 차단한다. Part 1 전체를 끝낸 뒤 minor bump 1회로 묶는다(신규 기능 추가이므로 `feat` → minor, build +1).
- Task 3의 `dart run build_runner build`는 생성 파일을 바꾸므로 반드시 같은 커밋에 `pet.g.dart`를 포함한다.

## 작성 상태

| Task | 내용 | 상태 |
|---|---|---|
| 1 | DayWindow (07:00 당일 창 + 차트 범위) | ✅ 작성 완료 |
| 2 | EnclosureSet + DeviceMode | ✅ 작성 완료 |
| 3 | `Pet.enclosureId` Hive 필드 추가 | ✅ 작성 완료 |
| 4 | `EnclosureSetRepository` | ✅ 작성 완료 |
| 5 | 세트 providers (계정격리 + clamp) | ✅ 작성 완료 |
| 6 | 라우터 4탭 전환 + `/stats` 스캐폴드 | ✅ 작성 완료 |

**Part 2 (홈 탭 UI)** — 별도 계획서로 작성 예정 `2026-08-05-prd-redesign-home.md`:
헤더바(개체 드롭다운·알림·설정) / 상단 고정 영역(라이브 뷰어·프로필 카드 분기·스와이프·인디케이터·오프라인 레이어) / 서브탭바 / 사육장 제어 4종(타이머 칩·온습도 카드·24h 차트·2x2 제어) / 타임라인 4종(요약 칩·날짜 스크롤러·필터 칩·클립 피드).
Part 1의 Task 1~6이 전부 통과한 뒤 착수한다 — Part 2의 모든 화면이 `currentSetProvider`·`DeviceMode`·`DayWindow`에 의존한다.

**계획 미작성 — PRD 스펙 부족으로 착수 불가:**
통계 탭 내용(PRD 기능요약 수준만 존재), 마이크레 탭(PRD Q6 "우선 후순위" + 통계 통합 여부 미결), 커뮤니티, 푸시, `/notifications`, `/enclosure-settings`, 자동 루틴 & 타이머 모달 내용(PRD Q2 "논의 필요"), 최초 온보딩(PRD Q7 "더 고민 필요").

---

## Self-Review

**1. 스펙 커버리지 (Part 1 범위 기준)**

| PRD 항목 | 담당 Task |
|---|---|
| §5-1.2 시간 정책 (07:00 경계, 차트 전날 19:00~) | Task 1 |
| §5-1.1 기기 연동 모드 3분기 | Task 2 |
| §2 전제 "사육장 1 : 캠 1 : 개체 1" | Task 2·3·4 |
| §3.1 개체 선택 드롭다운의 데이터 원천 | Task 4·5 |
| 목업 바텀 네비 4탭 | Task 6 |
| §3.4 "차트 터치 → 통계 탭" 목적지 존재 | Task 6 (`/stats` 스캐폴드) |

Part 1 범위 내 누락 없음. §3.1~3.5의 UI 자체는 의도적으로 Part 2.

**2. Placeholder 스캔**
한 곳만 남겼다 — Task 6 Step 6의 `routes: [ /* 기존 routes 목록을 그대로 이동 */ ]`. 이건 미정의(TBD)가 아니라 **기존 파일의 구체적 코드 블록을 옮기라는 기계적 지시**다. 실행자가 새로 작성할 코드가 없으므로 그대로 둔다. 나머지 스텝은 전부 실제 코드/명령을 담고 있다.

**3. 타입 일관성 점검 (수정 반영됨)**
- `DeviceMode`/`HomeSubTab`은 Task 2에서 정의, Task 5에서만 소비 — 이름 일치 확인.
- `EnclosureSet` 생성자는 4개 필드 전부 `required`(nullable 포함). Task 4·5·테스트 전부 이 시그니처로 호출.
- **수정 1:** Task 4의 `Future.wait` + `as List<Device>` 캐스팅을 Dart 3 레코드 `.wait` + `_safe()` 헬퍼로 교체. `List<Object>` 캐스팅은 타입 실수를 런타임까지 숨긴다.
- **수정 2:** Task 5 `currentSetProvider`에서 `ref.watch(selectedSetIndexProvider)`를 `await` **앞으로** 이동. await 뒤의 watch는 의존이 제때 등록되지 않아 "드롭다운을 눌러도 세트가 안 바뀐다"는 증상이 된다.
- `enclosureSetsProvider`는 `FutureProvider<List<EnclosureSet>>` — 테스트의 `overrideWith((ref) async => sets)`와 시그니처 일치.

**4. 자동진행 리스크 (실행 전 인지 사항)**
- Task 3의 `build_runner`는 프로젝트 전체 생성 파일을 다시 만든다. 다른 `.g.dart`에 무관한 diff가 생기면 그건 정상이며, 같은 커밋에 포함시킨다.
- Task 6은 `app_router.dart`를 크게 재배열한다. 실패 시 이 파일만 되돌리면 복구되도록 Task 6은 **단독 커밋**으로 유지한다.
- 빌드/수정 루프 3회 초과 시 CAOF 규칙대로 중단하고 보고한다.
