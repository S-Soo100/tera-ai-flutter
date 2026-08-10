# PRD 기준 앱 전면 재설계 Implementation Plan — Part 2: 홈 탭 UI

> ⚠️ **2026-08-08 기획 리셋 이전 문서다.** 이 계획서가 만든 구현의 디자인이 기획 의도를 만족하지 못해,
> 기존 구현을 전제하지 않는 새 기획안(`docs/prd-vivnanaut-app.md`)이 작성되었다.
> 이 문서는 **"무엇이 어떻게 만들어졌는지"의 기록**으로만 유효하다. 신규 작업의 근거로 쓰지 말 것.

> ✅ **완료 (2026-08-08 소급 확인).** Part 1과 마찬가지로 구현은 됐으나 체크박스가 방치돼 있었다.
> 소급 근거: Task 7~16 위젯 11종 + 도메인 6종(`running_timer`·`env_extremes`·`env_chart_series`·
> `actuator_marker`·`mist_lock`·`timeline_summary`·`pet_dday`) 전수 실존 + `flutter test` 200개 통과.
> 계획서에 없던 산출물도 붙었다: `live_clock_overlay.dart`, `nightly_report_badge.dart`
> (커밋 `8a348ef` 라이브 오버레이 수정, `cbc61fb` 실기기 검증 수정에서 파생).
> **개별 스텝 순서까지 소급 검증한 것은 아니고 최종 상태만 확인했다.**

> **구현 방식 (CAOF):** Critical 트랙. 이 계획을 task 단위로 구현한다. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PRD §3.1~3.5의 홈 탭을 구현한다 — 헤더바, 상단 고정 영역(라이브 뷰어 ↔ 개체 프로필 카드 분기 + 세트 스와이프), 서브탭바, 사육장 제어 4종, 타임라인 4종.

**Architecture:** 모든 화면이 Part 1의 `currentSetProvider`·`DeviceMode`·`DayWindow` 위에 선다. 홈 화면은 `PageView`(세트 스와이프) 위에 고정 헤더 + 고정 상단 영역 + 서브탭 컨테이너를 얹은 단일 `Scaffold`다. **서브탭 전환 시 라이브 스트림이 끊기면 안 되므로**(PRD §3.3) 비디오 위젯은 서브탭 컨테이너 밖에 두고 `IndexedStack`으로 컨텐츠만 교체한다.

**Tech Stack:** Flutter · Riverpod 2 · flutter_webrtc · chart_sparkline · video_player · easy_localization

**선행 조건:** Part 1(`docs/plans/2026-08-05-prd-redesign.md`) Task 1~6 전부 통과. Part 2의 모든 Task가 `currentSetProvider`/`DeviceMode`/`DayWindow`를 직접 참조한다.

---

## 타깃 파일 구조 (Part 2)

```
lib/features/home/presentation/
├── home_screen.dart                    # 전면 교체 — 조립부           (Task 10)
├── home_control_providers.dart         # 제어 서브탭 상태             (Task 12,13,14)
├── home_timeline_providers.dart        # 타임라인 서브탭 상태          (Task 15,16)
└── widgets/
    ├── home_header_bar.dart            # 개체 드롭다운/알림/설정       (Task 7)
    ├── pet_profile_card.dart           # 사육장 단품 대체 카드         (Task 8)
    ├── top_fixed_area.dart             # 라이브↔프로필 분기 + 스와이프 (Task 9)
    ├── home_sub_tabs_bar.dart          # 2구분 세그먼트                (Task 10)
    ├── running_timer_chip.dart         # 진행 중 타이머 칩             (Task 11)
    ├── live_env_card.dart              # 실시간 온습도 + 당일 최고/최저 (Task 12)
    ├── env_mini_chart.dart             # 24h 라인 + 동작 마커          (Task 13)
    ├── quick_control_grid.dart         # 2x2 + LED 슬라이더 + 분무 락  (Task 14)
    ├── timeline_summary_chips.dart     # 당일 요약 칩                  (Task 15)
    ├── timeline_date_scroller.dart     # 날짜 스크롤러 + 필터 칩       (Task 15)
    └── timeline_clip_feed.dart         # 클립 피드 + 상단 인라인 재생  (Task 16)

lib/features/home/domain/
├── running_timer.dart                  # 카운트다운 도메인             (Task 11)
├── env_extremes.dart                   # 당일 최고/최저 산출           (Task 12)
└── actuator_marker.dart                # 차트 동작 마커                (Task 13)
```

---

### Task 7: HomeHeaderBar — 개체 드롭다운 / 알림 / 설정

**Context:**
- Depends on: Part 1 Task 5 (`enclosureSetsProvider`, `selectedSetIndexProvider`, `currentSetProvider`)
- Inputs: `EnclosureSet.displayLabel`
- Outputs: `lib/features/home/presentation/widgets/home_header_bar.dart` — `HomeHeaderBar`
- Must know: PRD §3.1 예외 규칙 — **세트가 1개면 드롭다운 화살표를 숨긴다**(누를 게 없는데 누를 수 있어 보이면 안 됨). 알림 Red Dot은 미읽음 알림이 있을 때만. `/notifications`·`/enclosure-settings` 화면은 이 계획 범위 밖이라 **라우트만 만들고 빈 스캐폴드**로 둔다 — 버튼이 아무 데도 안 가면 구현 여부를 판단할 수 없기 때문. 알림 개수 소스가 아직 없으므로 `unreadNotificationCountProvider`는 0 고정으로 두고 실연동은 후속(그래야 Red Dot 로직 자체는 지금 테스트된다).
- Acceptance: `flutter test test/features/home/home_header_bar_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/presentation/widgets/home_header_bar.dart`
- Create: `lib/features/notification/presentation/notification_center_screen.dart`
- Create: `lib/features/my_cage/presentation/enclosure_settings_screen.dart`
- Modify: `lib/core/router/app_router.dart` (`/notifications`, `/enclosure-settings` 최상위 라우트)
- Modify: `assets/l10n/ko.json`
- Test: `test/features/home/home_header_bar_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/home_header_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/enclosure_set.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/home_header_bar.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';

EnclosureSet _set(String id, String encName, {String? petName}) => EnclosureSet(
      enclosure:
          Enclosure(id: id, name: encName, createdAt: DateTime(2026, 1, 1)),
      device: null,
      camera: null,
      pet: petName == null
          ? null
          : Pet(
              id: 'p-$id',
              name: petName,
              speciesId: 'crested_gecko',
              speciesName: '크레스티드 게코',
            ),
    );

Future<void> _pump(
  WidgetTester tester,
  List<EnclosureSet> sets, {
  int unread = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        enclosureSetsProvider.overrideWith((ref) async => sets),
        unreadNotificationCountProvider.overrideWith((ref) => unread),
      ],
      child: const MaterialApp(
        home: Scaffold(body: HomeHeaderBar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('현재 세트 라벨을 보여준다', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장', petName: '젤리')]);
    expect(find.text('젤리 (1번 사육장)'), findsOneWidget);
  });

  testWidgets('세트가 1개면 드롭다운 화살표 비노출 (PRD §3.1 예외)', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장')]);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsNothing);
  });

  testWidgets('세트가 2개 이상이면 화살표 노출', (tester) async {
    await _pump(tester, [_set('e1', 'A'), _set('e2', 'B')]);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsOneWidget);
  });

  testWidgets('드롭다운에서 다른 세트를 고르면 선택 인덱스가 바뀐다', (tester) async {
    final container = ProviderContainer(overrides: [
      enclosureSetsProvider
          .overrideWith((ref) async => [_set('e1', 'A'), _set('e2', 'B')]),
      unreadNotificationCountProvider.overrideWith((ref) => 0),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HomeHeaderBar())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(HomeHeaderBar.dropdownArrowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(container.read(selectedSetIndexProvider), 1);
  });

  testWidgets('미읽음 0이면 Red Dot 없음', (tester) async {
    await _pump(tester, [_set('e1', 'A')], unread: 0);
    expect(find.byKey(HomeHeaderBar.redDotKey), findsNothing);
  });

  testWidgets('미읽음이 있으면 Red Dot 노출', (tester) async {
    await _pump(tester, [_set('e1', 'A')], unread: 3);
    expect(find.byKey(HomeHeaderBar.redDotKey), findsOneWidget);
  });

  testWidgets('세트가 없으면 빈 라벨로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/home_header_bar_test.dart
```

Expected: FAIL — `home_header_bar.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the header widget**

```dart
// lib/features/home/presentation/widgets/home_header_bar.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../home_set_providers.dart';

/// 미읽음 알림 개수. 알림 저장소가 생기기 전까지 0 고정 —
/// Red Dot 표시 로직 자체는 지금 검증 가능해야 하므로 provider로 뺀다.
final unreadNotificationCountProvider = Provider<int>((ref) => 0);

/// PRD §3.1 Header Bar.
///
/// 좌측 개체 선택 드롭다운(세트 1개면 화살표 비노출), 우측 알림 센터(미읽음
/// Red Dot)와 사육장 설정.
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  static const dropdownArrowKey = Key('home_header_dropdown_arrow');
  static const redDotKey = Key('home_header_red_dot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    final multi = sets.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: multi ? () => _openSetPicker(context, ref) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current?.displayLabel ?? 'home_no_set'.tr(),
                      style: AppStyles.subsectionTitle(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (multi)
                    const Icon(
                      Icons.expand_more,
                      key: dropdownArrowKey,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                tooltip: 'home_notifications'.tr(),
                onPressed: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    key: redDotKey,
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'home_enclosure_settings'.tr(),
            onPressed: () => context.push('/enclosure-settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSetPicker(BuildContext context, WidgetRef ref) async {
    final sets = ref.read(enclosureSetsProvider).valueOrNull ?? const [];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < sets.length; i++)
              ListTile(
                title: Text(sets[i].displayLabel),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(selectedSetIndexProvider.notifier).state = picked;
    }
  }
}
```

- [x] **Step 4: Add the two destination scaffolds**

```dart
// lib/features/notification/presentation/notification_center_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// PRD §3.1 알림 센터. 카테고리(긴급/안전, 제어/동작 결과, 주간 AI 리포트,
/// 마케팅/혜택)는 정의됐으나 데이터 소스가 없어 목록은 후속 계획에서 채운다.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_notifications'.tr())),
      body: Center(child: Text('notifications_empty'.tr())),
    );
  }
}
```

```dart
// lib/features/my_cage/presentation/enclosure_settings_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// PRD §3.1 사육장 설정. 지금은 기존 페어링 플로우로 가는 진입점만 제공한다
/// (세트 상세 설정 화면은 스펙 미비 — 후속).
class EnclosureSettingsScreen extends StatelessWidget {
  const EnclosureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_enclosure_settings'.tr())),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text('enclosure_settings_add_device'.tr()),
            onTap: () => context.push('/smart-cage/devices/pair'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text('enclosure_settings_add_camera'.tr()),
            onTap: () => context.push('/crecam/cameras/pair'),
          ),
          ListTile(
            leading: const Icon(Icons.view_in_ar_outlined),
            title: Text('enclosure_settings_manage'.tr()),
            onTap: () => context.push('/smart-cage/enclosures'),
          ),
        ],
      ),
    );
  }
}
```

- [x] **Step 5: Register routes and i18n keys**

`lib/core/router/app_router.dart` — `/profile` GoRoute 뒤에 추가:

```dart
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/enclosure-settings',
        builder: (context, state) => const EnclosureSettingsScreen(),
      ),
```

같은 파일 import 블록에 추가:

```dart
import '../../features/notification/presentation/notification_center_screen.dart';
import '../../features/my_cage/presentation/enclosure_settings_screen.dart';
```

`assets/l10n/ko.json`에 추가:

```json
  "home_no_set": "사육장을 등록해주세요",
  "home_notifications": "알림",
  "home_enclosure_settings": "사육장 설정",
  "notifications_empty": "새 알림이 없어요",
  "enclosure_settings_add_device": "새 사육장 제어기 추가",
  "enclosure_settings_add_camera": "새 카메라 추가",
  "enclosure_settings_manage": "사육장 관리",
```

- [x] **Step 6: Run test to verify it passes**

```bash
flutter test test/features/home/home_header_bar_test.dart && flutter analyze
```

Expected: `All tests passed!` (7 tests) + `No issues found!`

- [x] **Step 7: Commit**

```bash
git add lib/features/home/presentation/widgets/home_header_bar.dart lib/features/notification/presentation/notification_center_screen.dart lib/features/my_cage/presentation/enclosure_settings_screen.dart lib/core/router/app_router.dart assets/l10n/ko.json test/features/home/home_header_bar_test.dart
git commit -m "feat(home): HomeHeaderBar — 개체 드롭다운(단일세트 화살표 숨김)/알림 Red Dot/설정"
```

---

### Task 8: PetProfileCard — 사육장 단품 대체 카드

**Context:**
- Depends on: Part 1 Task 2·3 (`EnclosureSet`, `Pet.enclosureId`)
- Inputs: `Pet`(name/adoptionDate/weight/photoPath), `TelemetryReading`(온습도 정상 판정), `SpeciesComfort`(`lib/features/my_cage/domain/species_comfort.dart`)
- Outputs: `lib/features/home/domain/pet_dday.dart`, `lib/features/home/presentation/widgets/pet_profile_card.dart`
- Must know: PRD 목업 문구가 `젤리와 함께한 지 D+152일`이다. 기존 `Pet.adoptionDuration`은 `입양 5개월째` 형식이라 **재사용하면 안 된다** — 새 D-Day 포매터를 만든다. 입양일이 없으면 D-Day 줄 자체를 숨긴다(0일로 위장하지 않는다). `온습도 정상 🟢` 배지는 종별 안심존(`SpeciesComfort`) 안에 들어올 때만 초록 — 종이 미설정이면 배지를 숨긴다(임의 수치 금지, 메모리 `project_telemetry_chart`).
- Acceptance: `flutter test test/features/home/pet_profile_card_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/pet_dday.dart`
- Create: `lib/features/home/presentation/widgets/pet_profile_card.dart`
- Test: `test/features/home/pet_profile_card_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/pet_profile_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/pet_dday.dart';
import 'package:tera_ai/features/my_cage/domain/species_comfort.dart';

void main() {
  group('dDayLabel — PRD 목업 문구 형식', () {
    test('입양 152일차 → "젤리와 함께한 지 D+152일"', () {
      final label = dDayLabel(
        petName: '젤리',
        adoptionDate: DateTime(2026, 3, 6),
        now: DateTime(2026, 8, 5),
      );
      expect(label, '젤리와 함께한 지 D+152일');
    });

    test('입양 당일 → D+0일', () {
      final label = dDayLabel(
        petName: '젤리',
        adoptionDate: DateTime(2026, 8, 5),
        now: DateTime(2026, 8, 5, 23),
      );
      expect(label, '젤리와 함께한 지 D+0일');
    });

    test('입양일 없으면 null — 0일로 위장하지 않는다', () {
      expect(
        dDayLabel(petName: '젤리', adoptionDate: null, now: DateTime(2026, 8, 5)),
        isNull,
      );
    });

    test('시각 차이는 무시하고 날짜 경계로만 센다', () {
      final label = dDayLabel(
        petName: '젤리',
        adoptionDate: DateTime(2026, 8, 4, 23, 59),
        now: DateTime(2026, 8, 5, 0, 1),
      );
      expect(label, '젤리와 함께한 지 D+1일');
    });
  });

  group('envStatus — 온습도 정상 판정', () {
    const comfort = SpeciesComfort(
      speciesId: 'crested_gecko',
      speciesNameKo: '크레스티드 게코',
      tempMin: 20,
      tempMax: 27,
      humidMin: 50,
      humidMax: 80,
    );

    test('둘 다 안심존 안 → normal', () {
      expect(envStatus(temp: 24.5, humid: 68, comfort: comfort),
          EnvStatus.normal);
    });

    test('온도가 범위를 벗어나면 warning', () {
      expect(envStatus(temp: 29, humid: 68, comfort: comfort),
          EnvStatus.warning);
    });

    test('습도가 범위를 벗어나면 warning', () {
      expect(envStatus(temp: 24, humid: 35, comfort: comfort),
          EnvStatus.warning);
    });

    test('종 미설정(comfort=null) → unknown, 배지 숨김', () {
      expect(envStatus(temp: 24, humid: 68, comfort: null), EnvStatus.unknown);
    });

    test('측정값 없음 → unknown', () {
      expect(envStatus(temp: null, humid: 68, comfort: comfort),
          EnvStatus.unknown);
    });

    test('0값은 센서 오프라인 센티넬 → unknown', () {
      expect(envStatus(temp: 0, humid: 0, comfort: comfort), EnvStatus.unknown);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/pet_profile_card_test.dart
```

Expected: FAIL — `pet_dday.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the domain helpers**

```dart
// lib/features/home/domain/pet_dday.dart
import '../../my_cage/domain/species_comfort.dart';

/// 개체 D-Day 문구. PRD §3.2 목업 문구 형식 `젤리와 함께한 지 D+152일`.
///
/// 기존 `Pet.adoptionDuration`(`입양 5개월째`)과 형식이 달라 재사용하지 않는다.
/// 입양일이 없으면 null — 줄 자체를 숨기기 위함이지 0일이 아니다.
String? dDayLabel({
  required String petName,
  required DateTime? adoptionDate,
  required DateTime now,
}) {
  if (adoptionDate == null) return null;
  final from = DateTime(adoptionDate.year, adoptionDate.month, adoptionDate.day);
  final to = DateTime(now.year, now.month, now.day);
  final days = to.difference(from).inDays;
  return '$petName와 함께한 지 D+$days일';
}

/// 사육장 환경 상태 배지. PRD §3.2 `온습도 정상 🟢`.
enum EnvStatus {
  /// 종별 안심존 안.
  normal,

  /// 안심존을 벗어남.
  warning,

  /// 판정 불가(종 미설정 / 측정값 없음 / 센서 오프라인). 배지를 숨긴다.
  unknown,
}

/// 온습도가 종별 안심존 안인지 판정한다.
///
/// [comfort]가 null(종 미설정)이면 판정하지 않는다 — 임의 기준치를 지어내면
/// 사용자가 잘못된 안전 신호를 믿게 된다.
/// 0값은 실측이 아니라 센서 오프라인 센티넬이다(DHT22는 0을 못 낸다).
EnvStatus envStatus({
  required double? temp,
  required double? humid,
  required SpeciesComfort? comfort,
}) {
  if (comfort == null) return EnvStatus.unknown;
  if (temp == null || humid == null) return EnvStatus.unknown;
  if (temp <= 0 || humid <= 0) return EnvStatus.unknown;

  final tempOk = temp >= comfort.tempMin && temp <= comfort.tempMax;
  final humidOk = humid >= comfort.humidMin && humid <= comfort.humidMax;
  return tempOk && humidOk ? EnvStatus.normal : EnvStatus.warning;
}
```

- [x] **Step 4: Write the card widget**

```dart
// lib/features/home/presentation/widgets/pet_profile_card.dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_pets/domain/pet.dart';
import '../../domain/pet_dday.dart';

/// PRD §3.2 사육장 단품 모드의 상단 대체 카드.
///
/// 대표 사진 + D-Day + 최근 상태 요약(마지막 급여일, 체중) + 온습도 배지.
class PetProfileCard extends StatelessWidget {
  const PetProfileCard({
    super.key,
    required this.pet,
    required this.lastFedAt,
    required this.status,
  });

  final Pet? pet;
  final DateTime? lastFedAt;
  final EnvStatus status;

  @override
  Widget build(BuildContext context) {
    final p = pet;
    if (p == null) {
      return Padding(
        padding: AppStyles.pagePadding,
        child: Text('home_no_pet'.tr()),
      );
    }

    final dday = dDayLabel(
      petName: p.name,
      adoptionDate: p.adoptionDate,
      now: DateTime.now(),
    );

    return Padding(
      padding: AppStyles.pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: p.photoPath == null
                ? null
                : FileImage(File(p.photoPath!)),
            child: p.photoPath == null ? const Icon(Icons.pets) : null,
          ),
          const SizedBox(width: AppStyles.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dday ?? p.name,
                  style: AppStyles.subsectionTitle(context),
                ),
                const SizedBox(height: AppStyles.spacing4),
                Text(
                  _summaryLine(context),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (status != EnvStatus.unknown) ...[
                  const SizedBox(height: AppStyles.spacing8),
                  _StatusBadge(status: status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _summaryLine(BuildContext context) {
    final parts = <String>[];
    if (lastFedAt != null) {
      parts.add('home_last_fed'
          .tr(args: [DateFormat('MM/dd').format(lastFedAt!)]));
    }
    if (pet?.weight != null) {
      parts.add('home_weight'.tr(args: [pet!.weight!.toStringAsFixed(0)]));
    }
    return parts.join(' · ');
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EnvStatus status;

  @override
  Widget build(BuildContext context) {
    final normal = status == EnvStatus.normal;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing8,
        vertical: AppStyles.spacing4,
      ),
      decoration: BoxDecoration(
        color: (normal ? Colors.green : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppStyles.chipRadius),
      ),
      child: Text(
        normal ? 'home_env_normal'.tr() : 'home_env_warning'.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: normal ? Colors.green.shade800 : Colors.orange.shade900,
            ),
      ),
    );
  }
}
```

- [x] **Step 5: Add i18n keys**

`assets/l10n/ko.json`에 추가:

```json
  "home_no_pet": "개체를 등록해주세요",
  "home_last_fed": "최근 급여 {}",
  "home_weight": "체중 {}g",
  "home_env_normal": "온습도 정상 🟢",
  "home_env_warning": "온습도 주의 🟠",
```

- [x] **Step 6: Run test to verify it passes**

```bash
flutter test test/features/home/pet_profile_card_test.dart && flutter analyze
```

Expected: `All tests passed!` (10 tests) + `No issues found!`

- [x] **Step 7: Commit**

```bash
git add lib/features/home/domain/pet_dday.dart lib/features/home/presentation/widgets/pet_profile_card.dart assets/l10n/ko.json test/features/home/pet_profile_card_test.dart
git commit -m "feat(home): PetProfileCard — D-Day 문구 + 종별 안심존 기반 온습도 배지"
```

---

### Task 9: TopFixedArea — 라이브 ↔ 프로필 분기 + 세트 스와이프

**Context:**
- Depends on: Task 8 (`PetProfileCard`), Part 1 Task 2·5 (`DeviceMode`, `enclosureSetsProvider`, `selectedSetIndexProvider`)
- Inputs: `WebRtcLiveView({required String cameraUuid})` (`lib/features/my_cage/presentation/widgets/webrtc_live_view.dart`) — `cameraUuid`는 `TerraCamera.id`. `cameraPresence(...)` (`lib/features/my_cage/domain/camera_presence.dart`)
- Outputs: `lib/features/home/presentation/widgets/top_fixed_area.dart` — `TopFixedArea`
- Must know: **PageView와 `selectedSetIndexProvider`가 서로를 갱신하므로 무한 루프를 조심해야 한다.** 드롭다운으로 인덱스가 바뀌면 `PageController.animateToPage`, 스와이프하면 `onPageChanged`가 provider를 갱신 — 같은 값이면 아무것도 하지 않도록 양쪽에 가드를 둔다. 16:9 고정(`AspectRatio`)이라 서브탭 컨텐츠 높이가 변해도 상단이 흔들리지 않는다. `WebRtcLiveView`는 자체적으로 연결/실패 상태를 그리므로 여기서는 **배지와 오프라인 레이어만** 얹는다. PRD의 오버레이 컨트롤(캡처·수동녹화)은 기존 `video_controls.dart`가 클립 재생용이라 재사용할 수 없다 — 라이브용 캡처/녹화는 백엔드 계약이 없어 이 Task에서는 **전체화면 버튼과 시각 오버레이만** 넣고 나머지는 후속으로 남긴다.
- Acceptance: `flutter test test/features/home/top_fixed_area_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/presentation/widgets/top_fixed_area.dart`
- Test: `test/features/home/top_fixed_area_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/top_fixed_area_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/enclosure_set.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/top_fixed_area.dart';
import 'package:tera_ai/features/my_cage/domain/device.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';
import 'package:tera_ai/features/my_cage/domain/terra_camera.dart';

EnclosureSet _set(String id, {bool cam = false, bool dev = false}) =>
    EnclosureSet(
      enclosure: Enclosure(id: id, name: id, createdAt: DateTime(2026, 1, 1)),
      device: dev
          ? Device(
              id: 'd-$id',
              ownerId: 'u1',
              enclosureId: id,
              name: 'dev',
              isOnline: true,
              lastSeenAt: null)
          : null,
      camera: cam
          ? TerraCamera(
              id: 'c-$id',
              cameraId: 'p4cam-$id',
              name: 'cam',
              isOnline: true,
              enclosureId: id,
              createdAt: DateTime(2026, 1, 1))
          : null,
      pet: null,
    );

Future<ProviderContainer> _pump(
    WidgetTester tester, List<EnclosureSet> sets) async {
  final c = ProviderContainer(overrides: [
    enclosureSetsProvider.overrideWith((ref) async => sets),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: TopFixedArea())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('캠 없는 세트 → 프로필 카드 영역', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    expect(find.byKey(TopFixedArea.profileKey), findsOneWidget);
    expect(find.byKey(TopFixedArea.liveKey), findsNothing);
  });

  testWidgets('캠 있는 세트 → 라이브 영역', (tester) async {
    await _pump(tester, [_set('e1', cam: true, dev: true)]);
    expect(find.byKey(TopFixedArea.liveKey), findsOneWidget);
    expect(find.byKey(TopFixedArea.profileKey), findsNothing);
  });

  testWidgets('세트 1개면 페이지 인디케이터 비노출', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    expect(find.byKey(TopFixedArea.indicatorKey), findsNothing);
  });

  testWidgets('세트 2개 이상이면 인디케이터 노출', (tester) async {
    await _pump(tester, [_set('e1', dev: true), _set('e2', dev: true)]);
    expect(find.byKey(TopFixedArea.indicatorKey), findsOneWidget);
  });

  testWidgets('스와이프하면 선택 인덱스가 따라온다', (tester) async {
    final c = await _pump(
        tester, [_set('e1', dev: true), _set('e2', dev: true)]);
    await tester.drag(
        find.byKey(TopFixedArea.pageViewKey), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(c.read(selectedSetIndexProvider), 1);
  });

  testWidgets('16:9 비율을 유지한다 — 서브탭 높이 변화에 안 흔들림', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    final ar = tester.widget<AspectRatio>(
        find.descendant(
            of: find.byType(TopFixedArea), matching: find.byType(AspectRatio))
        .first);
    expect(ar.aspectRatio, closeTo(16 / 9, 0.001));
  });

  testWidgets('세트 없음 → 빈 상태로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(TopFixedArea), findsOneWidget);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/top_fixed_area_test.dart
```

Expected: FAIL — `top_fixed_area.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the widget**

```dart
// lib/features/home/presentation/widgets/top_fixed_area.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/presentation/widgets/webrtc_live_view.dart';
import '../../domain/enclosure_set.dart';
import '../../domain/pet_dday.dart';
import '../home_set_providers.dart';
import 'pet_profile_card.dart';

/// PRD §3.2 Top Fixed Area.
///
/// 캠이 있으면 라이브 뷰어, 없으면 개체 프로필 카드. 좌/우 스와이프로 세트를
/// 전환하고 하단 인디케이터가 이를 반영한다(PRD §3.2 스와이프 UX).
///
/// 16:9 고정이라 아래 서브탭 컨텐츠 높이가 바뀌어도 상단이 흔들리지 않는다.
class TopFixedArea extends ConsumerStatefulWidget {
  const TopFixedArea({super.key});

  static const pageViewKey = Key('top_fixed_pageview');
  static const liveKey = Key('top_fixed_live');
  static const profileKey = Key('top_fixed_profile');
  static const indicatorKey = Key('top_fixed_indicator');

  @override
  ConsumerState<TopFixedArea> createState() => _TopFixedAreaState();
}

class _TopFixedAreaState extends ConsumerState<TopFixedArea> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        PageController(initialPage: ref.read(selectedSetIndexProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];

    // 드롭다운 등 외부에서 인덱스가 바뀌면 페이지를 따라 움직인다.
    // 같은 값이면 아무것도 하지 않는다 — onPageChanged와 서로를 다시 부르는
    // 무한 루프를 막기 위한 가드.
    ref.listen<int>(selectedSetIndexProvider, (_, next) {
      if (!_controller.hasClients || sets.isEmpty) return;
      final target = next.clamp(0, sets.length - 1);
      if (_controller.page?.round() == target) return;
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });

    if (sets.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: Text('home_no_set'.tr())),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            key: TopFixedArea.pageViewKey,
            controller: _controller,
            itemCount: sets.length,
            onPageChanged: (i) {
              if (ref.read(selectedSetIndexProvider) == i) return;
              ref.read(selectedSetIndexProvider.notifier).state = i;
            },
            itemBuilder: (_, i) => _SetPane(set: sets[i]),
          ),
        ),
        if (sets.length > 1)
          Padding(
            key: TopFixedArea.indicatorKey,
            padding: const EdgeInsets.only(top: AppStyles.spacing8),
            child: _PageDots(
              count: sets.length,
              current: ref.watch(selectedSetIndexProvider)
                  .clamp(0, sets.length - 1),
            ),
          ),
      ],
    );
  }
}

class _SetPane extends StatelessWidget {
  const _SetPane({required this.set});

  final EnclosureSet set;

  @override
  Widget build(BuildContext context) {
    final cam = set.camera;
    if (cam == null) {
      return Container(
        key: TopFixedArea.profileKey,
        alignment: Alignment.centerLeft,
        child: PetProfileCard(
          pet: set.pet,
          lastFedAt: null,
          status: EnvStatus.unknown,
        ),
      );
    }
    return Stack(
      key: TopFixedArea.liveKey,
      fit: StackFit.expand,
      children: [
        WebRtcLiveView(cameraUuid: cam.id),
        Positioned(
          left: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: _LiveBadge(isOnline: cam.isOnline),
        ),
        Positioned(
          right: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: Text(
            DateFormat('yyyy.MM.dd HH:mm').format(DateTime.now()),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        if (!cam.isOnline)
          Container(
            color: Colors.black54,
            alignment: Alignment.center,
            child: Text(
              'home_cam_disconnected'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? Colors.red : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOnline ? 'LIVE' : 'OFFLINE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).disabledColor,
            ),
          ),
      ],
    );
  }
}
```

- [x] **Step 4: Add i18n key**

`assets/l10n/ko.json`에 추가:

```json
  "home_cam_disconnected": "⚠️ 사육장 카메라 연결이 끊겼습니다.",
```

- [x] **Step 5: Run test to verify it passes**

```bash
flutter test test/features/home/top_fixed_area_test.dart && flutter analyze
```

Expected: `All tests passed!` (7 tests) + `No issues found!`

- [x] **Step 6: Commit**

```bash
git add lib/features/home/presentation/widgets/top_fixed_area.dart assets/l10n/ko.json test/features/home/top_fixed_area_test.dart
git commit -m "feat(home): TopFixedArea — 라이브↔프로필 분기 + 세트 스와이프 + LIVE/OFFLINE 배지"
```

---

### Task 10: HomeSubTabsBar + HomeScreen 조립

**Context:**
- Depends on: Task 7·9, Part 1 Task 2·5
- Inputs: `DeviceMode.controlEnabled/timelineEnabled/defaultTab`, `homeSubTabProvider`
- Outputs: `lib/features/home/presentation/widgets/home_sub_tabs_bar.dart`, `lib/features/home/presentation/home_screen.dart` (전면 교체)
- Must know: **서브탭 전환 시 라이브 스트림이 끊기면 안 된다**(PRD §3.3). 그래서 `TopFixedArea`는 서브탭 컨테이너 **밖**에 두고, 컨테이너만 `IndexedStack`으로 교체한다 — `TabBarView`나 조건부 rebuild를 쓰면 `WebRtcLiveView`가 dispose되어 재연결이 걸린다(첫 프레임까지 수초, 메모리 `project_webrtc_first_frame_keyframe_gap`). 세트를 바꾸면 새 모드에서 비활성인 탭이 선택돼 있을 수 있으므로 `defaultTab`으로 되돌린다. 기존 `home_screen.dart`(대시보드)는 이 Task에서 완전히 대체되며, `home_providers.dart`의 종 검색 관련 provider는 다른 화면이 쓰므로 **건드리지 않는다**.
- Acceptance: `flutter test test/features/home/home_sub_tabs_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/presentation/widgets/home_sub_tabs_bar.dart`
- Rewrite: `lib/features/home/presentation/home_screen.dart`
- Test: `test/features/home/home_sub_tabs_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/home_sub_tabs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/device_mode.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/home_sub_tabs_bar.dart';

Future<ProviderContainer> _pump(WidgetTester tester, DeviceMode mode) async {
  final c = ProviderContainer(overrides: [
    currentDeviceModeProvider.overrideWith((ref) async => mode),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: HomeSubTabsBar())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

bool _enabled(WidgetTester tester, Key key) {
  final w = tester.widget<InkWell>(find.descendant(
      of: find.byKey(key), matching: find.byType(InkWell)));
  return w.onTap != null;
}

void main() {
  testWidgets('integrated — 두 탭 모두 활성', (tester) async {
    await _pump(tester, DeviceMode.integrated);
    expect(_enabled(tester, HomeSubTabsBar.controlKey), isTrue);
    expect(_enabled(tester, HomeSubTabsBar.timelineKey), isTrue);
  });

  testWidgets('cageOnly — 타임라인 비활성', (tester) async {
    await _pump(tester, DeviceMode.cageOnly);
    expect(_enabled(tester, HomeSubTabsBar.controlKey), isTrue);
    expect(_enabled(tester, HomeSubTabsBar.timelineKey), isFalse);
  });

  testWidgets('camOnly — 사육장 제어 비활성', (tester) async {
    await _pump(tester, DeviceMode.camOnly);
    expect(_enabled(tester, HomeSubTabsBar.controlKey), isFalse);
    expect(_enabled(tester, HomeSubTabsBar.timelineKey), isTrue);
  });

  testWidgets('camOnly 진입 시 기본 선택은 타임라인', (tester) async {
    final c = await _pump(tester, DeviceMode.camOnly);
    expect(c.read(homeSubTabProvider), HomeSubTab.timeline);
  });

  testWidgets('활성 탭을 누르면 선택이 바뀐다', (tester) async {
    final c = await _pump(tester, DeviceMode.integrated);
    await tester.tap(find.byKey(HomeSubTabsBar.timelineKey));
    await tester.pumpAndSettle();
    expect(c.read(homeSubTabProvider), HomeSubTab.timeline);
  });

  testWidgets('비활성 탭을 눌러도 선택이 안 바뀐다', (tester) async {
    final c = await _pump(tester, DeviceMode.cageOnly);
    await tester.tap(find.byKey(HomeSubTabsBar.timelineKey));
    await tester.pumpAndSettle();
    expect(c.read(homeSubTabProvider), HomeSubTab.control);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/home_sub_tabs_test.dart
```

Expected: FAIL — `home_sub_tabs_bar.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the sub-tabs bar**

```dart
// lib/features/home/presentation/widgets/home_sub_tabs_bar.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/device_mode.dart';
import '../home_set_providers.dart';

/// PRD §3.3 Sub-Tabs Bar — `[사육장 제어] | [타임라인]` 2구분 세그먼트.
///
/// 모드에 따라 한쪽이 비활성화되고, 세트가 바뀌면 그 모드의 기본 탭으로
/// 되돌아간다(비활성 탭이 선택된 채 남으면 빈 화면이 보인다).
class HomeSubTabsBar extends ConsumerWidget {
  const HomeSubTabsBar({super.key});

  static const controlKey = Key('home_subtab_control');
  static const timelineKey = Key('home_subtab_timeline');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(currentDeviceModeProvider).valueOrNull ?? DeviceMode.none;
    final selected = ref.watch(homeSubTabProvider);

    // 선택된 탭이 현재 모드에서 비활성이면 기본 탭으로 교정한다.
    // build 중 provider를 쓰면 안 되므로 프레임 뒤로 미룬다.
    final needsFix = (selected == HomeSubTab.control && !mode.controlEnabled) ||
        (selected == HomeSubTab.timeline && !mode.timelineEnabled);
    if (needsFix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(homeSubTabProvider.notifier).state = mode.defaultTab;
      });
    }

    return Row(
      children: [
        Expanded(
          child: _SegmentTab(
            key: controlKey,
            label: 'home_subtab_control'.tr(),
            enabled: mode.controlEnabled,
            selected: selected == HomeSubTab.control,
            onTap: () =>
                ref.read(homeSubTabProvider.notifier).state = HomeSubTab.control,
          ),
        ),
        Expanded(
          child: _SegmentTab(
            key: timelineKey,
            label: 'home_subtab_timeline'.tr(),
            enabled: mode.timelineEnabled,
            selected: selected == HomeSubTab.timeline,
            onTap: () => ref.read(homeSubTabProvider.notifier).state =
                HomeSubTab.timeline,
          ),
        ),
      ],
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    super.key,
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected && enabled ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: enabled
                    ? (selected ? scheme.primary : null)
                    : Theme.of(context).disabledColor,
              ),
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Rewrite the home screen**

```dart
// lib/features/home/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/device_mode.dart';
import 'home_set_providers.dart';
import 'widgets/home_header_bar.dart';
import 'widgets/home_sub_tabs_bar.dart';
import 'widgets/top_fixed_area.dart';

/// PRD §2 홈 탭 와이어프레임 조립.
///
/// Header / TopFixedArea / SubTabsBar 는 고정이고 그 아래 컨테이너만 바뀐다.
/// **TopFixedArea가 서브탭 컨테이너 밖에 있는 것이 핵심**이다 — 안에 두면
/// 탭 전환 때 WebRtcLiveView가 dispose되어 재연결(수초)이 걸린다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeSubTabProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeaderBar(),
            const TopFixedArea(),
            const HomeSubTabsBar(),
            Expanded(
              // IndexedStack: 두 컨테이너를 살려둔 채 보이는 것만 바꾼다.
              child: IndexedStack(
                index: tab == HomeSubTab.control ? 0 : 1,
                children: const [
                  _ControlContainer(),
                  _TimelineContainer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사육장 제어 서브탭. 내용은 Task 11~14에서 채운다.
class _ControlContainer extends StatelessWidget {
  const _ControlContainer();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 타임라인 서브탭. 내용은 Task 15~16에서 채운다.
class _TimelineContainer extends StatelessWidget {
  const _TimelineContainer();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [x] **Step 5: Add i18n keys**

`assets/l10n/ko.json`에 추가:

```json
  "home_subtab_control": "사육장 제어",
  "home_subtab_timeline": "타임라인",
```

- [x] **Step 6: Run test to verify it passes**

```bash
flutter test test/features/home/home_sub_tabs_test.dart && flutter analyze
```

Expected: `All tests passed!` (6 tests) + `No issues found!`

- [x] **Step 7: Verify the whole app still builds**

```bash
flutter test && flutter build apk --debug
```

Expected: 전체 테스트 통과 + `Built build/app/outputs/flutter-apk/app-debug.apk`

- [x] **Step 8: Commit**

```bash
git add lib/features/home/presentation/widgets/home_sub_tabs_bar.dart lib/features/home/presentation/home_screen.dart assets/l10n/ko.json test/features/home/home_sub_tabs_test.dart
git commit -m "feat(home): 서브탭바 + 홈 조립 — 탭 전환 시 라이브 스트림 유지(IndexedStack)"
```

---

### Task 11: RunningTimerChip — 진행 중 타이머

**Context:**
- Depends on: Task 10 (`_ControlContainer` 자리)
- Inputs: 없음 (`device_timers` 테이블은 BE4 — **아직 없다**)
- Outputs: `lib/features/home/domain/running_timer.dart`, `lib/features/home/presentation/widgets/running_timer_chip.dart`
- Must know: 타이머 데이터 소스가 백엔드에 **없다**(BE4). 그래서 repository는 조회 실패·테이블 부재를 빈 목록으로 흡수하고, 칩은 데이터가 있을 때만 뜬다. 이렇게 해야 BE4 없이도 카운트다운 포맷·만료 처리 로직을 지금 검증할 수 있다. 카운트다운은 1초 tick provider로 갱신하되 **autoDispose**여야 한다 — 아니면 홈을 떠나도 타이머가 계속 돈다. 남은 시간이 0 이하면 칩을 숨긴다(음수 카운트다운 방지).
- Acceptance: `flutter test test/features/home/running_timer_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/running_timer.dart`
- Create: `lib/features/home/presentation/widgets/running_timer_chip.dart`
- Test: `test/features/home/running_timer_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/running_timer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/running_timer.dart';

RunningTimer _t(DateTime endsAt) => RunningTimer(
      id: 't1',
      deviceId: 'd1',
      actuatorLabelKey: 'module_actuator_fan',
      durationMinutes: 30,
      endsAt: endsAt,
    );

void main() {
  group('RunningTimer.remaining', () {
    test('남은 시간 = endsAt - now', () {
      final t = _t(DateTime(2026, 8, 5, 12, 18, 20));
      expect(t.remaining(DateTime(2026, 8, 5, 12)),
          const Duration(minutes: 18, seconds: 20));
    });

    test('만료됐으면 Duration.zero — 음수로 안 간다', () {
      final t = _t(DateTime(2026, 8, 5, 12));
      expect(t.remaining(DateTime(2026, 8, 5, 12, 5)), Duration.zero);
    });
  });

  group('RunningTimer.isActive', () {
    test('남은 시간이 있으면 활성', () {
      expect(_t(DateTime(2026, 8, 5, 12, 1)).isActive(DateTime(2026, 8, 5, 12)),
          isTrue);
    });

    test('정확히 만료 시점이면 비활성', () {
      expect(_t(DateTime(2026, 8, 5, 12)).isActive(DateTime(2026, 8, 5, 12)),
          isFalse);
    });
  });

  group('formatRemaining — PRD 목업 문구', () {
    test('18분 20초', () {
      expect(formatRemaining(const Duration(minutes: 18, seconds: 20)),
          '18분 20초');
    });

    test('1분 미만은 초만', () {
      expect(formatRemaining(const Duration(seconds: 7)), '7초');
    });

    test('1시간 이상은 시간 포함', () {
      expect(formatRemaining(const Duration(hours: 1, minutes: 5, seconds: 3)),
          '1시간 5분 3초');
    });
  });

  group('RunningTimer.fromJson', () {
    test('테이블 컬럼 매핑', () {
      final t = RunningTimer.fromJson({
        'id': 't1',
        'device_id': 'd1',
        'actuator': 'fan',
        'duration_minutes': 30,
        'ends_at': '2026-08-05T12:18:20Z',
      });
      expect(t.deviceId, 'd1');
      expect(t.actuatorLabelKey, 'module_actuator_fan');
      expect(t.durationMinutes, 30);
    });

    test('알 수 없는 actuator도 죽지 않는다', () {
      final t = RunningTimer.fromJson({
        'id': 't1',
        'device_id': 'd1',
        'actuator': 'mystery',
        'duration_minutes': 5,
        'ends_at': '2026-08-05T12:00:00Z',
      });
      expect(t.actuatorLabelKey, 'module_actuator_unknown');
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/running_timer_test.dart
```

Expected: FAIL — `running_timer.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the domain**

```dart
// lib/features/home/domain/running_timer.dart

/// PRD §3.4 진행 중 타이머 칩의 데이터 모델.
///
/// 백엔드 `device_timers` 테이블(BE4)이 아직 없다 — 그 전까지 조회는 항상 빈
/// 목록이고 칩은 뜨지 않는다. 포맷·만료 로직은 그와 무관하게 여기서 검증된다.
class RunningTimer {
  final String id;
  final String deviceId;

  /// 액추에이터 i18n 키. 기존 `module_actuator_*` 키를 그대로 쓴다.
  final String actuatorLabelKey;

  /// 사용자가 건 타이머 길이(분). 칩 문구 `팬 30분 타이머 가동 중`의 30.
  final int durationMinutes;

  final DateTime endsAt;

  const RunningTimer({
    required this.id,
    required this.deviceId,
    required this.actuatorLabelKey,
    required this.durationMinutes,
    required this.endsAt,
  });

  /// 남은 시간. 만료됐으면 [Duration.zero] — 음수 카운트다운을 막는다.
  Duration remaining(DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool isActive(DateTime now) => remaining(now) > Duration.zero;

  factory RunningTimer.fromJson(Map<String, dynamic> j) {
    return RunningTimer(
      id: j['id'] as String? ?? '',
      deviceId: j['device_id'] as String? ?? '',
      actuatorLabelKey: _labelKey(j['actuator'] as String?),
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
      endsAt: j['ends_at'] != null
          ? DateTime.tryParse(j['ends_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  static String _labelKey(String? actuator) {
    const known = {'fan', 'heater', 'led', 'relay'};
    return known.contains(actuator)
        ? 'module_actuator_$actuator'
        : 'module_actuator_unknown';
  }
}

/// `18분 20초` / `7초` / `1시간 5분 3초` 형식. PRD 목업 문구를 따른다.
String formatRemaining(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h시간 $m분 $s초';
  if (m > 0) return '$m분 $s초';
  return '$s초';
}
```

- [x] **Step 4: Write the chip widget + provider**

```dart
// lib/features/home/presentation/widgets/running_timer_chip.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/theme/app_styles.dart';
import '../../domain/running_timer.dart';
import '../home_set_providers.dart';

/// 1초 tick. autoDispose라 홈을 떠나면 타이머가 멈춘다.
final _secondTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// 현재 세트 제어기의 진행 중 타이머.
///
/// `device_timers`(BE4)가 없으면 조회가 실패한다 — 빈 목록으로 흡수해서
/// 칩만 안 뜨게 한다. 여기서 throw하면 제어 탭 전체가 에러 화면이 된다.
final runningTimersProvider =
    FutureProvider.autoDispose<List<RunningTimer>>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  final deviceId = set?.device?.id;
  if (deviceId == null) return const [];
  try {
    final rows = await ref
        .watch(supabaseClientProvider)
        .from('device_timers')
        .select()
        .eq('device_id', deviceId)
        .order('ends_at', ascending: true);
    return (rows as List)
        .map((r) => RunningTimer.fromJson(r as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
});

/// PRD §3.4 진행 중 타이머 칩. 가동 중 타이머가 있을 때만 노출.
class RunningTimerChip extends ConsumerWidget {
  const RunningTimerChip({super.key});

  static const chipKey = Key('running_timer_chip');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(_secondTickProvider).valueOrNull ?? DateTime.now();
    final timers = ref.watch(runningTimersProvider).valueOrNull ?? const [];
    final active = timers.where((t) => t.isActive(now)).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    final t = active.first;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      key: chipKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppStyles.spacing12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppStyles.chipRadius),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16),
            const SizedBox(width: AppStyles.spacing8),
            Expanded(
              child: Text(
                'home_timer_running'.tr(args: [
                  t.actuatorLabelKey.tr(),
                  '${t.durationMinutes}',
                  formatRemaining(t.remaining(now)),
                ]),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 5: Add i18n keys**

`assets/l10n/ko.json`에 추가:

```json
  "module_actuator_unknown": "기기",
  "home_timer_running": "{} {}분 타이머 가동 중 ({} 남음)",
```

- [x] **Step 6: Run test to verify it passes**

```bash
flutter test test/features/home/running_timer_test.dart && flutter analyze
```

Expected: `All tests passed!` (9 tests) + `No issues found!`

- [x] **Step 7: Commit**

```bash
git add lib/features/home/domain/running_timer.dart lib/features/home/presentation/widgets/running_timer_chip.dart assets/l10n/ko.json test/features/home/running_timer_test.dart
git commit -m "feat(home): 진행 중 타이머 칩 — device_timers 부재 시 graceful degrade"
```

---

### Task 12: LiveEnvCard — 실시간 온습도 + 당일 최고/최저

**Context:**
- Depends on: Part 1 Task 1·5 (`DayWindow`, `currentSetProvider`)
- Inputs: `telemetryStreamProvider(deviceId)` (`lib/features/my_cage/presentation/supabase_module_providers.dart`), `SupabaseModuleControlRepository.telemetryHistory(deviceId, from, to:)`
- Outputs: `lib/features/home/domain/env_extremes.dart`, `lib/features/home/presentation/widgets/live_env_card.dart`, `lib/features/home/presentation/home_control_providers.dart`
- Must know: **`telemetry_30m`의 0값은 실측이 아니라 센서 오프라인 센티넬이다**(DHT22는 0을 못 낸다). `v > 0` 필터를 빼면 최저값이 항상 0으로 찍힌다(메모리 `project_telemetry_zero_sentinel`). 최고/최저 구간은 **당일(07:00~)**이라 `DayWindow.of(now)`를 쓰고, 차트(Task 13)의 전날 19:00~ 구간과 다르다 — 두 창을 섞지 말 것. 유효 표본이 하나도 없으면 최고/최저 줄을 숨긴다(0으로 위장 금지).
- Acceptance: `flutter test test/features/home/env_extremes_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/env_extremes.dart`
- Create: `lib/features/home/presentation/home_control_providers.dart`
- Create: `lib/features/home/presentation/widgets/live_env_card.dart`
- Test: `test/features/home/env_extremes_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/env_extremes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/env_extremes.dart';
import 'package:tera_ai/features/my_cage/domain/telemetry_bucket.dart';

TelemetryBucket _b({
  required double tMin,
  required double tMax,
  required double hMin,
  required double hMax,
}) =>
    TelemetryBucket.fromJson({
      'bucket': '2026-08-05T09:00:00Z',
      'sample_count': 10,
      't_a_avg': (tMin + tMax) / 2,
      't_a_min': tMin,
      't_a_max': tMax,
      'h_a_avg': (hMin + hMax) / 2,
      'h_a_min': hMin,
      'h_a_max': hMax,
    });

void main() {
  group('EnvExtremes.from', () {
    test('여러 버킷에서 전체 최고/최저를 뽑는다', () {
      final e = EnvExtremes.from([
        _b(tMin: 23.5, tMax: 25.0, hMin: 60, hMax: 75),
        _b(tMin: 24.0, tMax: 26.0, hMin: 62, hMax: 82),
      ]);
      expect(e.tempMin, 23.5);
      expect(e.tempMax, 26.0);
      expect(e.humidMin, 60);
      expect(e.humidMax, 82);
    });

    test('0값은 센서 오프라인 센티넬 — 최저에 섞이면 안 된다', () {
      final e = EnvExtremes.from([
        _b(tMin: 0, tMax: 0, hMin: 0, hMax: 0),
        _b(tMin: 23.5, tMax: 26.0, hMin: 60, hMax: 82),
      ]);
      expect(e.tempMin, 23.5);
      expect(e.humidMin, 60);
    });

    test('유효 표본이 없으면 hasData=false', () {
      final e = EnvExtremes.from([_b(tMin: 0, tMax: 0, hMin: 0, hMax: 0)]);
      expect(e.hasData, isFalse);
      expect(e.tempMin, isNull);
    });

    test('빈 목록 → hasData=false', () {
      expect(EnvExtremes.from(const []).hasData, isFalse);
    });

    test('온도만 유효하고 습도가 전부 0이어도 온도는 살린다', () {
      final e = EnvExtremes.from([_b(tMin: 22, tMax: 25, hMin: 0, hMax: 0)]);
      expect(e.tempMin, 22);
      expect(e.humidMin, isNull);
      expect(e.hasData, isTrue);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/env_extremes_test.dart
```

Expected: FAIL — `env_extremes.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the domain**

```dart
// lib/features/home/domain/env_extremes.dart
import '../../my_cage/domain/telemetry_bucket.dart';

/// PRD §3.4 "당일(07:00~) 최고/최저 온도 및 습도".
///
/// `telemetry_30m`의 **0값은 실측이 아니라 센서 오프라인 센티넬**이다
/// (DHT22는 0을 못 낸다). 필터하지 않으면 최저가 항상 0으로 찍힌다.
class EnvExtremes {
  final double? tempMin;
  final double? tempMax;
  final double? humidMin;
  final double? humidMax;

  const EnvExtremes({
    required this.tempMin,
    required this.tempMax,
    required this.humidMin,
    required this.humidMax,
  });

  /// 온도·습도 중 하나라도 유효 표본이 있으면 true.
  bool get hasData => tempMin != null || humidMin != null;

  factory EnvExtremes.from(List<TelemetryBucket> buckets) {
    final temps = <double>[];
    final humids = <double>[];
    for (final b in buckets) {
      for (final v in [b.tMin, b.tMax]) {
        if (v != null && v > 0) temps.add(v);
      }
      for (final v in [b.hMin, b.hMax]) {
        if (v != null && v > 0) humids.add(v);
      }
    }
    return EnvExtremes(
      tempMin: temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b),
      tempMax: temps.isEmpty ? null : temps.reduce((a, b) => a > b ? a : b),
      humidMin: humids.isEmpty ? null : humids.reduce((a, b) => a < b ? a : b),
      humidMax: humids.isEmpty ? null : humids.reduce((a, b) => a > b ? a : b),
    );
  }
}
```

> `TelemetryBucket`의 필드명은 `tAvg/tMin/tMax`, `hAvg/hMin/hMax`로 확인됨 (`lib/features/my_cage/domain/telemetry_bucket.dart:13-20`). 위 코드는 그 이름을 그대로 쓴다.

- [x] **Step 4: Write providers and the card**

```dart
// lib/features/home/presentation/home_control_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../my_cage/domain/telemetry_bucket.dart';
import '../../my_cage/presentation/supabase_module_providers.dart';
import '../domain/day_window.dart';
import '../domain/env_extremes.dart';
import 'home_set_providers.dart';

/// 현재 세트 제어기 id. 없으면 null(사육장 단품이 아닌 캠 단품 등).
final currentDeviceIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  return set?.device?.id;
});

/// 당일(07:00~) 온습도 버킷. 최고/최저 산출용.
final todayBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final w = DayWindow.of(DateTime.now());
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, w.start, to: w.end);
});

/// 당일 최고/최저.
final todayExtremesProvider =
    FutureProvider.autoDispose<EnvExtremes>((ref) async {
  return EnvExtremes.from(await ref.watch(todayBucketsProvider.future));
});
```

```dart
// lib/features/home/presentation/widgets/live_env_card.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/env_extremes.dart';
import '../home_control_providers.dart';

/// PRD §3.4 실시간 온습도 카드 — 현재값 + 당일 최고/최저.
class LiveEnvCard extends ConsumerWidget {
  const LiveEnvCard({super.key});

  static const cardKey = Key('live_env_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(todayExtremesProvider).valueOrNull;

    return Card(
      key: cardKey,
      margin: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'home_env_temp_now'
                      .tr(args: [t?.tA?.toStringAsFixed(1) ?? '--']),
                  style: AppStyles.subsectionTitle(context),
                ),
                Text(
                  'home_env_humid_now'
                      .tr(args: [t?.hA?.toStringAsFixed(0) ?? '--']),
                  style: AppStyles.subsectionTitle(context),
                ),
              ],
            ),
            if (ex != null && ex.hasData) ...[
              const SizedBox(height: AppStyles.spacing4),
              Text(
                _extremesLine(ex),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _extremesLine(EnvExtremes ex) {
    final parts = <String>[];
    if (ex.tempMax != null) {
      parts.add('home_env_temp_range'.tr(args: [
        ex.tempMax!.toStringAsFixed(1),
        ex.tempMin!.toStringAsFixed(1),
      ]));
    }
    if (ex.humidMax != null) {
      parts.add('home_env_humid_range'.tr(args: [
        ex.humidMax!.toStringAsFixed(0),
        ex.humidMin!.toStringAsFixed(0),
      ]));
    }
    return parts.join(' · ');
  }
}
```

- [x] **Step 5: Add i18n keys**

```json
  "home_env_temp_now": "현재 {}°C",
  "home_env_humid_now": "현재 {}%",
  "home_env_temp_range": "오늘 최고 {}°C / 최저 {}°C",
  "home_env_humid_range": "최고 {}% / 최저 {}%",
```

- [x] **Step 6: Run test to verify it passes**

```bash
flutter test test/features/home/env_extremes_test.dart && flutter analyze
```

Expected: `All tests passed!` (5 tests) + `No issues found!`

- [x] **Step 7: Commit**

```bash
git add lib/features/home/domain/env_extremes.dart lib/features/home/presentation/home_control_providers.dart lib/features/home/presentation/widgets/live_env_card.dart assets/l10n/ko.json test/features/home/env_extremes_test.dart
git commit -m "feat(home): 실시간 온습도 카드 — 당일 최고/최저(0 센티넬 필터)"
```

---

### Task 13: EnvMiniChart — 24h 라인 + 동작 마커 + 통계탭 이동

**Context:**
- Depends on: Task 12 (`home_control_providers.dart`), Part 1 Task 1·6 (`DayWindow.chartRange`, `/stats`)
- Inputs: `SupabaseModuleControlRepository.telemetryHistory`, `commands` 테이블(`issued_at`, `action`, `status`), `chart_sparkline` 패키지
- Outputs: `lib/features/home/domain/actuator_marker.dart`, `lib/features/home/presentation/widgets/env_mini_chart.dart`
- Must know: **동작 마커의 데이터 소스는 `commands` 테이블이다.** PRD는 "분무/팬/히터/LED 작동 시점"을 요구하는데 `telemetry_30m`에는 액추에이터 상태가 없다 — 30분 집계라 전이 시점도 못 뽑는다. `commands`의 `issued_at` + `status='acked'`가 실제 동작 시점의 유일한 기록이다. 라인은 `telemetry_30m`(30분 버킷)로 그린다 — PRD의 5분 단위는 BE1(`telemetry_5m` 뷰) 이후. 여기서도 **`v > 0` 필터 필수**(0 = 센서 오프라인 센티넬, 안 걸면 Y축이 0까지 눌려 곡선이 납작해진다). 차트 범위는 `DayWindow.chartRange`(전날 19:00~현재)로 Task 12의 당일 창과 **다르다**.
- Acceptance: `flutter test test/features/home/actuator_marker_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/actuator_marker.dart`
- Create: `lib/features/home/presentation/widgets/env_mini_chart.dart`
- Modify: `lib/features/home/presentation/home_control_providers.dart` (차트용 provider 추가)
- Test: `test/features/home/actuator_marker_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/actuator_marker_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/actuator_marker.dart';

Map<String, dynamic> _cmd(String action, String issuedAt,
        {String status = 'acked'}) =>
    {
      'id': 'c-$action-$issuedAt',
      'action': action,
      'status': status,
      'issued_at': issuedAt,
    };

void main() {
  group('ActuatorMarker.fromCommands', () {
    test('acked 명령만 마커가 된다 — 실행 안 된 명령을 동작으로 그리면 안 됨', () {
      final m = ActuatorMarker.fromCommands([
        _cmd('fan_toggle', '2026-08-05T10:00:00Z'),
        _cmd('heater_toggle', '2026-08-05T11:00:00Z', status: 'rejected'),
        _cmd('led_on', '2026-08-05T12:00:00Z', status: 'pending'),
      ]);
      expect(m, hasLength(1));
      expect(m.single.kind, MarkerKind.fan);
    });

    test('action → 마커 종류 매핑', () {
      final m = ActuatorMarker.fromCommands([
        _cmd('relay_toggle', '2026-08-05T09:00:00Z'),
        _cmd('fan_toggle', '2026-08-05T10:00:00Z'),
        _cmd('heater_toggle', '2026-08-05T11:00:00Z'),
        _cmd('led_on', '2026-08-05T12:00:00Z'),
      ]);
      expect(m.map((e) => e.kind).toList(), [
        MarkerKind.mist,
        MarkerKind.fan,
        MarkerKind.heater,
        MarkerKind.led,
      ]);
    });

    test('알 수 없는 action은 버린다', () {
      final m = ActuatorMarker.fromCommands(
          [_cmd('token_rotate', '2026-08-05T10:00:00Z')]);
      expect(m, isEmpty);
    });

    test('issued_at이 없으면 버린다 — 시점 없는 마커는 못 찍는다', () {
      final m = ActuatorMarker.fromCommands([
        {'id': 'c1', 'action': 'fan_toggle', 'status': 'acked'},
      ]);
      expect(m, isEmpty);
    });

    test('시간순 정렬', () {
      final m = ActuatorMarker.fromCommands([
        _cmd('fan_toggle', '2026-08-05T12:00:00Z'),
        _cmd('relay_toggle', '2026-08-05T09:00:00Z'),
      ]);
      expect(m.first.kind, MarkerKind.mist);
    });
  });

  group('ActuatorMarker.positionIn', () {
    test('구간 중앙이면 0.5', () {
      final m = ActuatorMarker(
          kind: MarkerKind.fan, at: DateTime.utc(2026, 8, 5, 12));
      final p = m.positionIn(
        start: DateTime.utc(2026, 8, 5, 6),
        end: DateTime.utc(2026, 8, 5, 18),
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('구간 밖이면 null — 차트 밖에 찍히지 않는다', () {
      final m = ActuatorMarker(
          kind: MarkerKind.fan, at: DateTime.utc(2026, 8, 5, 20));
      expect(
        m.positionIn(
          start: DateTime.utc(2026, 8, 5, 6),
          end: DateTime.utc(2026, 8, 5, 18),
        ),
        isNull,
      );
    });

    test('길이 0 구간이면 null — 0으로 나누지 않는다', () {
      final t = DateTime.utc(2026, 8, 5, 12);
      final m = ActuatorMarker(kind: MarkerKind.fan, at: t);
      expect(m.positionIn(start: t, end: t), isNull);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/actuator_marker_test.dart
```

Expected: FAIL — `actuator_marker.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the domain**

```dart
// lib/features/home/domain/actuator_marker.dart

/// 차트에 찍는 기기 동작 종류. PRD §3.4 "분무(💦), 팬(🔵), 히터(🔥), LED(💡)".
enum MarkerKind { mist, fan, heater, led }

/// PRD §3.4 기기 동작 마커.
///
/// 데이터 소스는 **`commands` 테이블**이다. `telemetry_30m`은 30분 집계라
/// 액추에이터 전이 시점을 담지 못하므로, 실제로 언제 동작했는지 아는 유일한
/// 기록이 명령 이력이다. `status='acked'`(기기가 받아 실행)만 마커가 된다 —
/// 거부/대기 중인 명령을 동작으로 그리면 사용자가 오해한다.
class ActuatorMarker {
  final MarkerKind kind;
  final DateTime at;

  const ActuatorMarker({required this.kind, required this.at});

  /// [start]~[end] 구간에서의 0.0~1.0 위치. 구간 밖이거나 길이가 0이면 null.
  double? positionIn({required DateTime start, required DateTime end}) {
    final span = end.difference(start).inMilliseconds;
    if (span <= 0) return null;
    if (at.isBefore(start) || at.isAfter(end)) return null;
    return at.difference(start).inMilliseconds / span;
  }

  static const _kindByAction = {
    'relay_toggle': MarkerKind.mist,
    'fan_toggle': MarkerKind.fan,
    'heater_toggle': MarkerKind.heater,
    'led_on': MarkerKind.led,
    'led_off': MarkerKind.led,
  };

  /// `commands` 행 목록 → 시간순 마커 목록.
  static List<ActuatorMarker> fromCommands(List<Map<String, dynamic>> rows) {
    final out = <ActuatorMarker>[];
    for (final r in rows) {
      if (r['status'] != 'acked') continue;
      final kind = _kindByAction[r['action'] as String?];
      if (kind == null) continue;
      final at = r['issued_at'] == null
          ? null
          : DateTime.tryParse(r['issued_at'].toString());
      if (at == null) continue;
      out.add(ActuatorMarker(kind: kind, at: at));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
```

- [x] **Step 4: Add chart providers**

`lib/features/home/presentation/home_control_providers.dart` 끝에 추가:

```dart
/// 차트 구간(전날 19:00~현재) 온습도 버킷.
/// 당일 창(todayBucketsProvider)과 **다른 구간**이니 혼용하지 말 것.
final chartBucketsProvider =
    FutureProvider.autoDispose<List<TelemetryBucket>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final r = DayWindow.chartRange(DateTime.now());
  return ref
      .watch(supabaseModuleControlRepositoryProvider)
      .telemetryHistory(deviceId, r.start, to: r.end);
});

/// 차트 구간의 기기 동작 마커. `commands` 직결.
/// 조회 실패는 빈 목록으로 흡수한다 — 마커가 없다고 차트를 못 그릴 이유는 없다.
final actuatorMarkersProvider =
    FutureProvider.autoDispose<List<ActuatorMarker>>((ref) async {
  final deviceId = await ref.watch(currentDeviceIdProvider.future);
  if (deviceId == null) return const [];
  final r = DayWindow.chartRange(DateTime.now());
  try {
    final rows = await ref
        .watch(supabaseClientProvider)
        .from('commands')
        .select('id, action, status, issued_at')
        .eq('device_id', deviceId)
        .gte('issued_at', r.start.toUtc().toIso8601String())
        .lte('issued_at', r.end.toUtc().toIso8601String());
    return ActuatorMarker.fromCommands(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  } catch (_) {
    return const [];
  }
});
```

같은 파일 import 블록에 추가:

```dart
import '../../../core/supabase/supabase_provider.dart';
import '../domain/actuator_marker.dart';
```

- [x] **Step 5: Write the chart widget**

```dart
// lib/features/home/presentation/widgets/env_mini_chart.dart
import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/actuator_marker.dart';
import '../../domain/day_window.dart';
import '../home_control_providers.dart';

/// PRD §3.4 최근 24시간 실시간 차트.
///
/// 라인은 `telemetry_30m`(BE1의 `telemetry_5m`가 생기면 교체), 마커는
/// `commands`. **0값은 센서 오프라인 센티넬이라 반드시 필터**한다 — 안 걸면
/// Y축이 0까지 늘어나 곡선이 납작해진다.
///
/// 차트 영역 터치 시 통계 탭으로 이동(PRD §3.4 화면 전환 연동).
class EnvMiniChart extends ConsumerWidget {
  const EnvMiniChart({super.key});

  static const chartKey = Key('env_mini_chart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = ref.watch(chartBucketsProvider).valueOrNull ?? const [];
    final markers = ref.watch(actuatorMarkersProvider).valueOrNull ?? const [];

    final temps = [
      for (final b in buckets)
        if (b.tAvg != null && b.tAvg! > 0) b.tAvg!,
    ];
    final humids = [
      for (final b in buckets)
        if (b.hAvg != null && b.hAvg! > 0) b.hAvg!,
    ];

    final range = DayWindow.chartRange(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: InkWell(
        key: chartKey,
        onTap: () => context.go('/stats'),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppStyles.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('home_chart_title'.tr(),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppStyles.spacing8),
                SizedBox(
                  height: 64,
                  child: temps.length < 2 && humids.length < 2
                      ? Center(child: Text('home_chart_no_data'.tr()))
                      : Stack(
                          children: [
                            if (temps.length >= 2)
                              Sparkline(
                                data: temps,
                                lineColor: Colors.orange,
                                lineWidth: 2,
                              ),
                            if (humids.length >= 2)
                              Sparkline(
                                data: humids,
                                lineColor: Colors.blue,
                                lineWidth: 2,
                              ),
                            _MarkerRow(
                              markers: markers,
                              start: range.start,
                              end: range.end,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppStyles.spacing4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'home_chart_goto_stats'.tr(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.markers,
    required this.start,
    required this.end,
  });

  final List<ActuatorMarker> markers;
  final DateTime start;
  final DateTime end;

  static const _icon = {
    MarkerKind.mist: Icons.water_drop,
    MarkerKind.fan: Icons.mode_fan_off,
    MarkerKind.heater: Icons.local_fire_department,
    MarkerKind.led: Icons.lightbulb,
  };

  static const _color = {
    MarkerKind.mist: Colors.lightBlue,
    MarkerKind.fan: Colors.blueGrey,
    MarkerKind.heater: Colors.deepOrange,
    MarkerKind.led: Colors.amber,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            for (final m in markers)
              if (m.positionIn(start: start, end: end) case final p?)
                Positioned(
                  left: (p * c.maxWidth).clamp(0.0, c.maxWidth - 10),
                  bottom: 0,
                  child: Icon(_icon[m.kind], size: 10, color: _color[m.kind]),
                ),
          ],
        );
      },
    );
  }
}
```

- [x] **Step 6: Add i18n keys**

```json
  "home_chart_title": "최근 24시간",
  "home_chart_no_data": "표시할 데이터가 없어요",
  "home_chart_goto_stats": "차트 터치 시 통계 탭으로 이동 ›",
```

- [x] **Step 7: Run test to verify it passes**

```bash
flutter test test/features/home/actuator_marker_test.dart && flutter analyze
```

Expected: `All tests passed!` (8 tests) + `No issues found!`

- [x] **Step 8: Commit**

```bash
git add lib/features/home/domain/actuator_marker.dart lib/features/home/presentation/widgets/env_mini_chart.dart lib/features/home/presentation/home_control_providers.dart assets/l10n/ko.json test/features/home/actuator_marker_test.dart
git commit -m "feat(home): 24h 미니 차트 — commands 기반 동작 마커 + 통계탭 이동"
```

---

### Task 14: QuickControlGrid — 2x2 제어 + LED 밝기 + 분무 5초 락

**Context:**
- Depends on: Task 12 (`currentDeviceIdProvider`)
- Inputs: `moduleCommandSenderProvider`(`supabase_module_providers.dart`), `CommandAction`(`lib/features/my_cage/domain/device_command.dart`), `telemetryStreamProvider`
- Outputs: `lib/features/home/domain/mist_lock.dart`, `lib/features/home/presentation/widgets/quick_control_grid.dart`
- Must know: **분무는 명령 송출 후 5초 비활성화**(PRD §3.4 중복 클릭 방지). 락 상태는 위젯 로컬 타이머가 아니라 provider로 둬야 서브탭을 오갔다 와도 유지된다. **BE2(`relay_pulse`) 이전에는 `relay_toggle`을 1회 보낸다** — 1회 분사 시맨틱은 펌웨어 몫이라 앱에서 펄스를 흉내내면(ON 후 지연 OFF) 앱이 백그라운드로 가는 순간 펌프가 계속 돈다. 절대 하지 말 것. LED 밝기는 `led_on` payload에 `{'brightness': n}`을 동봉한다(BE3 전까지 펌웨어가 무시). 히터는 기존 `heater_lock_dialog.dart`의 안전 확인 플로우를 **반드시 거친다** — 온도 사고 방지 장치다.
- Acceptance: `flutter test test/features/home/mist_lock_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/mist_lock.dart`
- Create: `lib/features/home/presentation/widgets/quick_control_grid.dart`
- Test: `test/features/home/mist_lock_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/mist_lock_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/mist_lock.dart';

void main() {
  group('MistLock', () {
    test('초기 상태는 잠금 해제', () {
      expect(const MistLock(lockedUntil: null).isLocked(DateTime(2026, 8, 5)),
          isFalse);
    });

    test('잠금 시작 후 5초 동안 잠김', () {
      final lock = MistLock.startingAt(DateTime(2026, 8, 5, 12));
      expect(lock.isLocked(DateTime(2026, 8, 5, 12, 0, 4)), isTrue);
    });

    test('정확히 5초 뒤 해제', () {
      final lock = MistLock.startingAt(DateTime(2026, 8, 5, 12));
      expect(lock.isLocked(DateTime(2026, 8, 5, 12, 0, 5)), isFalse);
    });

    test('락 지속시간은 PRD 명시값 5초', () {
      expect(MistLock.duration, const Duration(seconds: 5));
    });

    test('남은 시간 — 해제 상태면 zero', () {
      final lock = MistLock.startingAt(DateTime(2026, 8, 5, 12));
      expect(lock.remaining(DateTime(2026, 8, 5, 12, 0, 2)),
          const Duration(seconds: 3));
      expect(lock.remaining(DateTime(2026, 8, 5, 12, 0, 9)), Duration.zero);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/mist_lock_test.dart
```

Expected: FAIL — `mist_lock.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the domain**

```dart
// lib/features/home/domain/mist_lock.dart

/// PRD §3.4 분무 버튼 예외 처리 — 명령 송출 후 5초간 비활성화(중복 클릭 방지).
///
/// 위젯 로컬 타이머가 아니라 상태값으로 두는 이유: 서브탭을 오가거나 세트를
/// 스와이프해도 락이 유지돼야 한다.
class MistLock {
  final DateTime? lockedUntil;

  const MistLock({required this.lockedUntil});

  /// PRD 명시값.
  static const duration = Duration(seconds: 5);

  factory MistLock.startingAt(DateTime now) =>
      MistLock(lockedUntil: now.add(duration));

  bool isLocked(DateTime now) =>
      lockedUntil != null && now.isBefore(lockedUntil!);

  Duration remaining(DateTime now) {
    if (lockedUntil == null) return Duration.zero;
    final d = lockedUntil!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}
```

- [x] **Step 4: Write the control grid**

```dart
// lib/features/home/presentation/widgets/quick_control_grid.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/domain/actuator_state.dart';
import '../../../my_cage/domain/device_command.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../domain/mist_lock.dart';
import '../home_control_providers.dart';

/// 분무 중복 클릭 락.
final mistLockProvider =
    StateProvider<MistLock>((ref) => const MistLock(lockedUntil: null));

/// LED 밝기(0~100). BE3 전까지 펌웨어가 payload를 무시할 수 있다.
final ledBrightnessProvider = StateProvider<int>((ref) => 70);

/// PRD §3.4 IoT 퀵 제어판 (2x2 Grid).
class QuickControlGrid extends ConsumerWidget {
  const QuickControlGrid({super.key});

  static const mistKey = Key('quick_control_mist');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final online = ref.watch(moduleOnlineProvider(deviceId));
    final lock = ref.watch(mistLockProvider);
    final brightness = ref.watch(ledBrightnessProvider);
    final mistLocked = lock.isLocked(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppStyles.spacing8,
        crossAxisSpacing: AppStyles.spacing8,
        childAspectRatio: 2.4,
        children: [
          _Tile(
            label: 'module_actuator_fan'.tr(),
            value: _stateLabel(t?.fan),
            icon: Icons.mode_fan_off,
            enabled: online,
            onTap: () => _send(ref, deviceId, CommandAction.fanToggle),
          ),
          _Tile(
            label: 'module_actuator_heater'.tr(),
            value: _stateLabel(t?.heaterState),
            icon: Icons.local_fire_department,
            enabled: online,
            onTap: () => _send(ref, deviceId, CommandAction.heaterToggle),
          ),
          _Tile(
            label: 'module_actuator_led'.tr(),
            value: '$brightness%',
            icon: Icons.lightbulb_outline,
            enabled: online,
            onTap: () => _openBrightness(context, ref, deviceId),
          ),
          _Tile(
            key: mistKey,
            label: 'home_mist_once'.tr(),
            value: mistLocked
                ? 'home_mist_cooldown'
                    .tr(args: ['${lock.remaining(DateTime.now()).inSeconds}'])
                : '',
            icon: Icons.water_drop_outlined,
            enabled: online && !mistLocked,
            onTap: () => _mist(context, ref, deviceId),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(ActuatorState? s) {
    switch (s) {
      case ActuatorState.on:
        return 'ON';
      case ActuatorState.off:
        return 'OFF';
      default:
        return '--';
    }
  }

  Future<void> _send(
      WidgetRef ref, String deviceId, CommandAction action) async {
    await ref.read(moduleCommandSenderProvider.notifier).send(deviceId, action);
  }

  /// 1회 즉시 분사.
  ///
  /// BE2(`relay_pulse`)가 없으므로 `relay_toggle`을 **1회만** 보낸다.
  /// 앱에서 ON→지연 OFF로 펄스를 흉내내면 앱이 백그라운드로 가는 순간 펌프가
  /// 계속 돈다 — 절대 하지 않는다.
  Future<void> _mist(
      BuildContext context, WidgetRef ref, String deviceId) async {
    ref.read(mistLockProvider.notifier).state =
        MistLock.startingAt(DateTime.now());
    try {
      await _send(ref, deviceId, CommandAction.relayToggle);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_mist_sent'.tr())),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_mist_failed'.tr())),
      );
    }
  }

  Future<void> _openBrightness(
      BuildContext context, WidgetRef ref, String deviceId) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        var v = ref.read(ledBrightnessProvider).toDouble();
        return StatefulBuilder(
          builder: (ctx, setLocal) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppStyles.spacing16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('home_led_brightness'.tr(args: ['${v.round()}'])),
                  Slider(
                    value: v,
                    max: 100,
                    divisions: 20,
                    onChanged: (n) => setLocal(() => v = n),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(v.round()),
                    child: Text('common_confirm'.tr()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    ref.read(ledBrightnessProvider.notifier).state = picked;
    await ref.read(moduleCommandSenderProvider.notifier).send(
          deviceId,
          picked == 0 ? CommandAction.ledOff : CommandAction.ledOn,
          payload: {'brightness': picked},
        );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppStyles.cardRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: enabled ? null : Theme.of(context).disabledColor),
            const SizedBox(height: AppStyles.spacing4),
            Text(
              value.isEmpty ? label : '$label $value',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: enabled ? null : Theme.of(context).disabledColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 5: Add i18n keys**

```json
  "home_mist_once": "1회 즉시 분사",
  "home_mist_cooldown": "{}초",
  "home_mist_sent": "분무가 정상적으로 실행됐습니다",
  "home_mist_failed": "분무 명령을 보내지 못했어요",
  "home_led_brightness": "LED 밝기 {}%",
  "common_confirm": "확인",
```

- [x] **Step 6: Wire the control container**

`lib/features/home/presentation/home_screen.dart`의 `_ControlContainer`를 교체:

```dart
class _ControlContainer extends StatelessWidget {
  const _ControlContainer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        RunningTimerChip(),
        LiveEnvCard(),
        EnvMiniChart(),
        QuickControlGrid(),
        SizedBox(height: AppStyles.spacing16),
        _RoutineSettingsButton(),
        SizedBox(height: AppStyles.spacing24),
      ],
    );
  }
}

/// PRD §3.4 `[자동 루틴 & 타이머 설정 >]` 풀스크린 모달 호출 버튼.
/// 모달 내용은 PRD Q2("논의 필요")라 이 계획 범위 밖 — 버튼과 이동만 만든다.
class _RoutineSettingsButton extends StatelessWidget {
  const _RoutineSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: Text('home_routine_settings'.tr()),
        onPressed: () => context.push('/home/routines'),
      ),
    );
  }
}
```

같은 파일 import 블록에 추가:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_styles.dart';
import 'widgets/env_mini_chart.dart';
import 'widgets/live_env_card.dart';
import 'widgets/quick_control_grid.dart';
import 'widgets/running_timer_chip.dart';
```

`assets/l10n/ko.json`에 추가:

```json
  "home_routine_settings": "자동 루틴 & 타이머 설정",
```

`lib/core/router/app_router.dart` — `/notifications` 옆에 추가:

```dart
      GoRoute(
        path: '/home/routines',
        builder: (context, state) => const RoutineSettingsScreen(),
      ),
```

- [x] **Step 7: Add the routine scaffold**

```dart
// lib/features/home/presentation/routine_settings_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// PRD §3.4 자동 루틴 & 타이머 설정 (풀스크린 모달).
///
/// 내용은 PRD가 "논의 필요"(Q2)로 남긴 구간이라 스펙 확정 후 별도 계획에서
/// 채운다. 지금은 버튼의 목적지가 존재한다는 것까지만 보장한다.
class RoutineSettingsScreen extends StatelessWidget {
  const RoutineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home_routine_settings'.tr())),
      body: Center(child: Text('home_routine_empty'.tr())),
    );
  }
}
```

`assets/l10n/ko.json`에 추가: `"home_routine_empty": "루틴 설정은 준비 중이에요",`
`app_router.dart` import에 추가: `import '../../features/home/presentation/routine_settings_screen.dart';`

- [x] **Step 8: Run tests**

```bash
flutter test test/features/home/mist_lock_test.dart && flutter test && flutter analyze
```

Expected: `All tests passed!` (5 tests) + 전체 통과 + `No issues found!`

- [x] **Step 9: Commit**

```bash
git add lib/features/home/domain/mist_lock.dart lib/features/home/presentation/widgets/quick_control_grid.dart lib/features/home/presentation/routine_settings_screen.dart lib/features/home/presentation/home_screen.dart lib/core/router/app_router.dart assets/l10n/ko.json test/features/home/mist_lock_test.dart
git commit -m "feat(home): 2x2 퀵 제어 — LED 밝기 슬라이더 + 분무 5초 락 + 루틴 진입"
```

---

### Task 15: 타임라인 요약 칩 + 날짜 스크롤러 + 필터 칩

**Context:**
- Depends on: Part 1 Task 1·5 (`DayWindow`, `currentSetProvider`)
- Inputs: `MotionClipRepository`(`lib/features/my_cage/data/motion_clip_repository.dart`), `kClipActions`(`lib/features/my_cage/domain/clip_action.dart`), `MotionClip.action`
- Outputs: `lib/features/home/domain/timeline_summary.dart`, `lib/features/home/presentation/home_timeline_providers.dart`, `lib/features/home/presentation/widgets/timeline_summary_chips.dart`, `.../timeline_date_scroller.dart`
- Must know: 기존 `listByCamera(day:)`는 **로컬 00:00~24:00** 기준이라 PRD의 07:00 창과 다르다 — 그대로 쓰면 새벽 활동이 엉뚱한 날짜에 붙는다. 창을 직접 받는 메서드를 새로 추가한다. **필터 칩은 0건이어도 사라지지 않고 Disabled로 고정 노출**된다(PRD §3.5) — 칩이 사라지면 사용자가 "그 행동은 원래 없는 기능"으로 오해한다. 행동 분류는 `behavior_logs`(BE5)에 의존하므로 라벨이 없으면 전부 미분류 → 움직임 외 칩이 전부 Disabled인 게 정상 동작이다. 미래 날짜로는 못 넘어가게 막는다.
- Acceptance: `flutter test test/features/home/timeline_summary_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/domain/timeline_summary.dart`
- Create: `lib/features/home/presentation/home_timeline_providers.dart`
- Create: `lib/features/home/presentation/widgets/timeline_summary_chips.dart`
- Create: `lib/features/home/presentation/widgets/timeline_date_scroller.dart`
- Modify: `lib/features/my_cage/data/motion_clip_repository.dart` (창 기반 조회 추가)
- Test: `test/features/home/timeline_summary_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/timeline_summary_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/timeline_summary.dart';
import 'package:tera_ai/features/my_cage/domain/motion_clip.dart';

MotionClip _c({required double sec, String? action}) => MotionClip(
      id: 'c-$sec-$action',
      cameraId: 'cam1',
      startedAt: DateTime(2026, 8, 5, 10),
      durationSec: sec,
      action: action,
    );

void main() {
  group('TimelineSummary.from', () {
    test('움직임 시간 = 전체 클립 duration 합', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 3600), _c(sec: 1800)],
        window: const Duration(hours: 24),
      );
      expect(s.movingSeconds, 5400);
    });

    test('휴식 시간 = 창 길이 - 움직임 시간', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 3600)],
        window: const Duration(hours: 24),
      );
      expect(s.restingSeconds, 24 * 3600 - 3600);
    });

    test('휴식은 음수가 되지 않는다', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 100000)],
        window: const Duration(hours: 24),
      );
      expect(s.restingSeconds, 0);
    });

    test('식사 횟수 — 3종 식사 액션을 합산', () {
      final s = TimelineSummary.from(
        clips: [
          _c(sec: 10, action: 'eating_paste'),
          _c(sec: 10, action: 'eating_prey'),
          _c(sec: 10, action: 'hand_feeding'),
          _c(sec: 10, action: 'drinking'),
        ],
        window: const Duration(hours: 24),
      );
      expect(s.eatCount, 3);
    });

    test('물 마신 횟수', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 5, action: 'drinking'), _c(sec: 5, action: 'drinking')],
        window: const Duration(hours: 24),
      );
      expect(s.drinkCount, 2);
    });

    test('미분류(action=null)는 어떤 횟수에도 안 들어간다', () {
      final s = TimelineSummary.from(
        clips: [_c(sec: 5), _c(sec: 5)],
        window: const Duration(hours: 24),
      );
      expect(s.eatCount, 0);
      expect(s.drinkCount, 0);
      expect(s.movingSeconds, 10);
    });

    test('빈 클립 목록 → 전부 0, 휴식은 창 전체', () {
      final s = TimelineSummary.from(
        clips: const [],
        window: const Duration(hours: 24),
      );
      expect(s.movingSeconds, 0);
      expect(s.restingSeconds, 24 * 3600);
    });
  });

  group('countByFilter — 필터 칩 활성 판정', () {
    test('해당 행동이 0건이면 0 — 칩은 Disabled', () {
      final counts = countByFilter([_c(sec: 5, action: 'drinking')]);
      expect(counts[TimelineFilter.shedding], 0);
      expect(counts[TimelineFilter.drinking], 1);
    });

    test('전체 필터는 항상 클립 총 개수', () {
      final counts = countByFilter([_c(sec: 5), _c(sec: 5, action: 'drinking')]);
      expect(counts[TimelineFilter.all], 2);
    });

    test('움직임 = 미분류 포함 전체 (모션 클립 자체가 움직임 근거)', () {
      final counts = countByFilter([_c(sec: 5), _c(sec: 5, action: 'moving')]);
      expect(counts[TimelineFilter.moving], 2);
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/timeline_summary_test.dart
```

Expected: FAIL — `timeline_summary.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the domain**

```dart
// lib/features/home/domain/timeline_summary.dart
import '../../my_cage/domain/motion_clip.dart';

/// PRD §3.5 이벤트 필터 칩. 0건이어도 **사라지지 않고 Disabled로 고정 노출**된다.
enum TimelineFilter { all, moving, eating, drinking, shedding }

/// PRD §3.5 당일 요약 칩 — 움직임/휴식 시간, 식사/물 마신 횟수.
///
/// 행동 분류는 `behavior_logs`(BE5)에 의존한다. 라벨이 없으면 전부 미분류라
/// 식사·물마심 횟수가 0인 게 정상 — 이건 버그가 아니라 백엔드 대기 상태다.
class TimelineSummary {
  final int movingSeconds;
  final int restingSeconds;
  final int eatCount;
  final int drinkCount;

  const TimelineSummary({
    required this.movingSeconds,
    required this.restingSeconds,
    required this.eatCount,
    required this.drinkCount,
  });

  static const eatActions = {'eating_paste', 'eating_prey', 'hand_feeding'};

  factory TimelineSummary.from({
    required List<MotionClip> clips,
    required Duration window,
  }) {
    final moving =
        clips.fold<double>(0, (sum, c) => sum + c.durationSec).round();
    final resting = window.inSeconds - moving;
    return TimelineSummary(
      movingSeconds: moving,
      // 감지 표본이 창을 넘길 수 있다(중복 구간). 음수 휴식은 의미가 없다.
      restingSeconds: resting < 0 ? 0 : resting,
      eatCount: clips.where((c) => eatActions.contains(c.action)).length,
      drinkCount: clips.where((c) => c.action == 'drinking').length,
    );
  }
}

/// 필터별 건수. 0인 필터의 칩은 Disabled로 그린다.
///
/// `moving`은 미분류 클립까지 포함한다 — 모션 클립이 존재한다는 사실 자체가
/// 움직임의 근거이기 때문(분류는 그 위에 얹히는 정보다).
Map<TimelineFilter, int> countByFilter(List<MotionClip> clips) {
  return {
    TimelineFilter.all: clips.length,
    TimelineFilter.moving: clips.length,
    TimelineFilter.eating: clips
        .where((c) => TimelineSummary.eatActions.contains(c.action))
        .length,
    TimelineFilter.drinking:
        clips.where((c) => c.action == 'drinking').length,
    TimelineFilter.shedding:
        clips.where((c) => c.action == 'shedding').length,
  };
}
```

- [x] **Step 4: Add the window-based query**

`lib/features/my_cage/data/motion_clip_repository.dart` — `listByCamera` 바로 뒤에 추가:

```dart
  /// [from](inclusive)~[to](exclusive) 구간의 모션 클립 (최신순).
  ///
  /// `listByCamera(day:)`는 로컬 00:00~24:00 기준이라 PRD의 07:00 하루 경계에
  /// 못 쓴다 — 새벽 활동이 엉뚱한 날짜에 붙는다.
  Future<List<MotionClip>> listByCameraInWindow(
    String cameraId, {
    required DateTime from,
    required DateTime to,
    int limit = 200,
  }) async {
    final rows = await _supabase
        .from('motion_clips')
        .select()
        .eq('camera_id', cameraId)
        .gte('started_at', from.toUtc().toIso8601String())
        .lt('started_at', to.toUtc().toIso8601String())
        .order('started_at', ascending: false)
        .limit(limit);
    final clips = (rows as List)
        .map((r) => MotionClip.fromJson(r as Map<String, dynamic>))
        .toList();
    if (!kClipClassificationEnabled || clips.isEmpty) return clips;
    final labels = await _fetchLabels(clips.map((c) => c.id).toList());
    return [
      for (final c in clips)
        labels.containsKey(c.id) ? c.copyWith(action: labels[c.id]) : c,
    ];
  }
```

- [x] **Step 5: Add timeline providers**

```dart
// lib/features/home/presentation/home_timeline_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../my_cage/domain/motion_clip.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../domain/day_window.dart';
import '../domain/timeline_summary.dart';
import 'home_set_providers.dart';

/// 타임라인이 보고 있는 날짜(창의 시작 날짜). 기본은 오늘.
final timelineDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DayWindow.of(DateTime.now()).labelDate;
});

/// 선택된 이벤트 필터.
final timelineFilterProvider =
    StateProvider.autoDispose<TimelineFilter>((ref) => TimelineFilter.all);

/// 선택 날짜 창(07:00~익일 07:00)의 모션 클립.
final timelineClipsProvider =
    FutureProvider.autoDispose<List<MotionClip>>((ref) async {
  final set = await ref.watch(currentSetProvider.future);
  final cameraId = set?.camera?.id;
  if (cameraId == null) return const [];
  final w = DayWindow.forDate(ref.watch(timelineDateProvider));
  return ref
      .watch(motionClipRepositoryProvider)
      .listByCameraInWindow(cameraId, from: w.start, to: w.end);
});

/// 당일 요약.
final timelineSummaryProvider =
    FutureProvider.autoDispose<TimelineSummary>((ref) async {
  final clips = await ref.watch(timelineClipsProvider.future);
  return TimelineSummary.from(
    clips: clips,
    window: const Duration(hours: 24),
  );
});

/// 필터별 건수 — 0인 필터의 칩은 Disabled.
final timelineFilterCountsProvider =
    FutureProvider.autoDispose<Map<TimelineFilter, int>>((ref) async {
  return countByFilter(await ref.watch(timelineClipsProvider.future));
});

/// 필터가 적용된 클립 목록.
final filteredTimelineClipsProvider =
    FutureProvider.autoDispose<List<MotionClip>>((ref) async {
  final filter = ref.watch(timelineFilterProvider);
  final clips = await ref.watch(timelineClipsProvider.future);
  switch (filter) {
    case TimelineFilter.all:
    case TimelineFilter.moving:
      return clips;
    case TimelineFilter.eating:
      return clips
          .where((c) => TimelineSummary.eatActions.contains(c.action))
          .toList();
    case TimelineFilter.drinking:
      return clips.where((c) => c.action == 'drinking').toList();
    case TimelineFilter.shedding:
      return clips.where((c) => c.action == 'shedding').toList();
  }
});
```

- [x] **Step 6: Write the chips and date scroller**

```dart
// lib/features/home/presentation/widgets/timeline_summary_chips.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../home_timeline_providers.dart';

/// PRD §3.5 당일 요약 칩 (Horizontal Chips).
class TimelineSummaryChips extends ConsumerWidget {
  const TimelineSummaryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timelineSummaryProvider).valueOrNull;
    if (s == null) return const SizedBox(height: 48);

    final items = [
      ('home_chip_moving', _hours(s.movingSeconds)),
      ('home_chip_resting', _hours(s.restingSeconds)),
      ('home_chip_eating', '${s.eatCount}회'),
      ('home_chip_drinking', '${s.drinkCount}회'),
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppStyles.spacing8),
        itemBuilder: (_, i) => Chip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(items[i].$1.tr(),
                  style: Theme.of(context).textTheme.labelSmall),
              Text(items[i].$2,
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }

  static String _hours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m분';
    return m == 0 ? '$h시간' : '$h시간 $m분';
  }
}
```

```dart
// lib/features/home/presentation/widgets/timeline_date_scroller.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/day_window.dart';
import '../../domain/timeline_summary.dart';
import '../home_timeline_providers.dart';

/// PRD §3.5 날짜 스크롤러 + 이벤트 필터 칩.
class TimelineDateScroller extends ConsumerWidget {
  const TimelineDateScroller({super.key});

  static const nextKey = Key('timeline_next_day');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(timelineDateProvider);
    final today = DayWindow.of(DateTime.now()).labelDate;
    final canGoNext = date.isBefore(today);
    final counts =
        ref.watch(timelineFilterCountsProvider).valueOrNull ?? const {};
    final selected = ref.watch(timelineFilterProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref.read(timelineDateProvider.notifier).state =
                  date.subtract(const Duration(days: 1)),
            ),
            Text(
              DateFormat('yyyy.MM.dd').format(date) +
                  (date == today ? ' ${'home_date_today'.tr()}' : ''),
            ),
            IconButton(
              key: nextKey,
              icon: const Icon(Icons.chevron_right),
              // 미래 날짜로는 못 간다.
              onPressed: canGoNext
                  ? () => ref.read(timelineDateProvider.notifier).state =
                      date.add(const Duration(days: 1))
                  : null,
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
            children: [
              for (final f in TimelineFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppStyles.spacing8),
                  child: FilterChip(
                    label: Text('home_filter_${f.name}'.tr()),
                    selected: selected == f,
                    // 0건이어도 칩을 없애지 않는다 — 없애면 "지원 안 하는 기능"
                    // 으로 오해한다. 비활성으로 남긴다(PRD §3.5).
                    onSelected: (counts[f] ?? 0) == 0
                        ? null
                        : (_) => ref
                            .read(timelineFilterProvider.notifier)
                            .state = f,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [x] **Step 7: Add i18n keys**

```json
  "home_chip_moving": "움직임",
  "home_chip_resting": "휴식",
  "home_chip_eating": "식사",
  "home_chip_drinking": "물마심",
  "home_date_today": "(오늘)",
  "home_filter_all": "전체",
  "home_filter_moving": "움직임",
  "home_filter_eating": "식사",
  "home_filter_drinking": "물마심",
  "home_filter_shedding": "탈피",
```

- [x] **Step 8: Run test to verify it passes**

```bash
flutter test test/features/home/timeline_summary_test.dart && flutter analyze
```

Expected: `All tests passed!` (10 tests) + `No issues found!`

- [x] **Step 9: Commit**

```bash
git add lib/features/home/domain/timeline_summary.dart lib/features/home/presentation/home_timeline_providers.dart lib/features/home/presentation/widgets/timeline_summary_chips.dart lib/features/home/presentation/widgets/timeline_date_scroller.dart lib/features/my_cage/data/motion_clip_repository.dart assets/l10n/ko.json test/features/home/timeline_summary_test.dart
git commit -m "feat(home): 타임라인 요약칩/날짜 스크롤러/필터칩 — 07:00 창 기준 조회"
```

---

### Task 16: 클립 피드 + 상단 인라인 재생

**Context:**
- Depends on: Task 9(`TopFixedArea`), Task 15(`filteredTimelineClipsProvider`)
- Inputs: `motionThumbnailProvider`, `motionClipUrlProvider`(`lib/features/my_cage/presentation/my_cage_providers.dart`), `video_player`
- Outputs: `lib/features/home/presentation/widgets/timeline_clip_feed.dart` + `TopFixedArea` 수정
- Must know: **썸네일 터치 시 상단 Top Fixed 영역에서 재생**한다(PRD §3.5) — 새 화면으로 이동하는 게 아니다. 그래서 재생 대상을 `inlinePlayingClipProvider`로 공유하고 `TopFixedArea`가 이를 보고 라이브↔클립을 전환한다. **`VideoPlayerController.initialize()`가 실패하면 catch에서 반드시 `dispose()`** 해야 한다 — 안 하면 네이티브 리소스가 샌다(메모리 `project_video_player_controller_leak`). 클립 재생 중 라이브로 돌아가는 명시적 닫기 버튼이 필요하다(안 그러면 라이브로 못 돌아간다).
- Acceptance: `flutter test test/features/home/timeline_clip_feed_test.dart` → All tests passed.

**Files:**
- Create: `lib/features/home/presentation/widgets/timeline_clip_feed.dart`
- Modify: `lib/features/home/presentation/widgets/top_fixed_area.dart` (인라인 재생 분기)
- Modify: `lib/features/home/presentation/home_screen.dart` (`_TimelineContainer` 채우기)
- Test: `test/features/home/timeline_clip_feed_test.dart`

- [x] **Step 1: Write the failing test**

```dart
// test/features/home/timeline_clip_feed_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/presentation/home_timeline_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/timeline_clip_feed.dart';
import 'package:tera_ai/features/my_cage/domain/motion_clip.dart';

MotionClip _c(String id, DateTime at, {String? action, double sec = 20}) =>
    MotionClip(
      id: id,
      cameraId: 'cam1',
      startedAt: at,
      durationSec: sec,
      action: action,
    );

Future<ProviderContainer> _pump(
    WidgetTester tester, List<MotionClip> clips) async {
  final c = ProviderContainer(overrides: [
    filteredTimelineClipsProvider.overrideWith((ref) async => clips),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: TimelineClipFeed())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('클립이 없으면 빈 상태 문구', (tester) async {
    await _pump(tester, const []);
    expect(find.byKey(TimelineClipFeed.emptyKey), findsOneWidget);
  });

  testWidgets('클립 개수만큼 행을 그린다', (tester) async {
    await _pump(tester, [
      _c('c1', DateTime(2026, 8, 5, 3, 12)),
      _c('c2', DateTime(2026, 8, 5, 1, 20)),
    ]);
    expect(find.byType(ClipFeedRow), findsNWidgets(2));
  });

  testWidgets('행에 시각과 녹화 길이가 보인다', (tester) async {
    await _pump(tester, [_c('c1', DateTime(2026, 8, 5, 3, 12, 0), sec: 200)]);
    expect(find.textContaining('03:12'), findsOneWidget);
    expect(find.textContaining('03m 20s'), findsOneWidget);
  });

  testWidgets('썸네일 탭 → 인라인 재생 대상이 설정된다 (화면 이동 아님)',
      (tester) async {
    final c = await _pump(tester, [_c('c1', DateTime(2026, 8, 5, 3, 12))]);
    await tester.tap(find.byType(ClipFeedRow).first);
    await tester.pumpAndSettle();
    expect(c.read(inlinePlayingClipProvider)?.id, 'c1');
  });

  group('formatClipDuration', () {
    test('200초 → 03m 20s', () {
      expect(formatClipDuration(200), '03m 20s');
    });

    test('15초 → 00m 15s', () {
      expect(formatClipDuration(15), '00m 15s');
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/home/timeline_clip_feed_test.dart
```

Expected: FAIL — `timeline_clip_feed.dart` 미존재로 컴파일 에러

- [x] **Step 3: Write the feed**

```dart
// lib/features/home/presentation/widgets/timeline_clip_feed.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../my_cage/domain/clip_action.dart';
import '../../../my_cage/domain/motion_clip.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../home_timeline_providers.dart';

/// 상단 Top Fixed 영역에서 인라인 재생할 클립. null = 라이브 표시.
///
/// PRD §3.5: "썸네일 터치 시 상단 Top Fixed Live 비디오 영역에서 해당 녹화
/// 클립 즉시 재생" — 새 화면으로 이동하지 않는다.
final inlinePlayingClipProvider = StateProvider<MotionClip?>((ref) => null);

/// `03m 20s` 형식. PRD §3.5 목업 표기.
String formatClipDuration(double seconds) {
  final total = seconds.round();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '${m}m ${s}s';
}

/// PRD §3.5 비디오 클립 피드 (List View).
class TimelineClipFeed extends ConsumerWidget {
  const TimelineClipFeed({super.key});

  static const emptyKey = Key('timeline_clip_feed_empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips =
        ref.watch(filteredTimelineClipsProvider).valueOrNull ?? const [];
    if (clips.isEmpty) {
      return Padding(
        key: emptyKey,
        padding: AppStyles.pagePadding,
        child: Center(child: Text('home_timeline_empty'.tr())),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clips.length,
      itemBuilder: (_, i) => ClipFeedRow(clip: clips[i]),
    );
  }
}

/// 클립 한 줄 — 썸네일 · 시각 · 이벤트명 · 녹화 길이.
class ClipFeedRow extends ConsumerWidget {
  const ClipFeedRow({super.key, required this.clip});

  final MotionClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(motionThumbnailProvider(clip.id)).valueOrNull;
    final label = clip.action == null
        ? 'clip_action_unlabeled'.tr()
        : clipActionKey(clip.action!).tr();

    return ListTile(
      onTap: () =>
          ref.read(inlinePlayingClipProvider.notifier).state = clip,
      leading: SizedBox(
        width: 64,
        height: 40,
        child: thumb == null
            ? Container(color: Theme.of(context).dividerColor)
            : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
      ),
      title: Text('$label (${formatClipDuration(clip.durationSec)})'),
      subtitle: Text(DateFormat('HH:mm:ss').format(clip.startedAt)),
    );
  }
}
```

- [x] **Step 4: Wire inline playback into TopFixedArea**

`lib/features/home/presentation/widgets/top_fixed_area.dart` — `_SetPane.build`의 `return Stack(key: TopFixedArea.liveKey, ...)` 직전에 인라인 재생 분기를 넣는다. 먼저 `_SetPane`을 `ConsumerWidget`으로 바꾸고:

```dart
class _SetPane extends ConsumerWidget {
  const _SetPane({required this.set});

  final EnclosureSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(inlinePlayingClipProvider);
    if (playing != null) {
      return _InlineClipPlayer(
        clipId: playing.id,
        onClose: () =>
            ref.read(inlinePlayingClipProvider.notifier).state = null,
      );
    }
    final cam = set.camera;
    // …(이하 기존 코드 그대로)
  }
}
```

import 추가:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'timeline_clip_feed.dart';
```

그리고 같은 파일 끝에 플레이어를 추가한다:

```dart
/// 상단 영역 인라인 클립 플레이어.
///
/// `initialize()`가 실패하면 catch에서 반드시 dispose 한다 — 안 하면 네이티브
/// 플레이어 리소스가 샌다.
class _InlineClipPlayer extends ConsumerStatefulWidget {
  const _InlineClipPlayer({required this.clipId, required this.onClose});

  final String clipId;
  final VoidCallback onClose;

  @override
  ConsumerState<_InlineClipPlayer> createState() => _InlineClipPlayerState();
}

class _InlineClipPlayerState extends ConsumerState<_InlineClipPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VideoPlayerController? c;
    try {
      final url = await ref.read(motionClipUrlProvider(widget.clipId).future);
      c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
      await c.play();
    } catch (_) {
      // 실패해도 네이티브 리소스는 반드시 반납한다.
      await c?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_failed)
          Center(child: Text('home_clip_play_failed'.tr()))
        else if (c == null)
          const ColoredBox(color: Colors.black)
        else
          VideoPlayer(c),
        Positioned(
          right: AppStyles.spacing8,
          top: AppStyles.spacing8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'home_back_to_live'.tr(),
            onPressed: widget.onClose,
          ),
        ),
      ],
    );
  }
}
```

`top_fixed_area.dart` import에 추가: `import 'package:video_player/video_player.dart';`, `import '../../../my_cage/presentation/my_cage_providers.dart';`

- [x] **Step 5: Fill the timeline container**

`lib/features/home/presentation/home_screen.dart`의 `_TimelineContainer`를 교체:

```dart
class _TimelineContainer extends StatelessWidget {
  const _TimelineContainer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        TimelineSummaryChips(),
        TimelineDateScroller(),
        TimelineClipFeed(),
        SizedBox(height: AppStyles.spacing24),
      ],
    );
  }
}
```

import 추가:

```dart
import 'widgets/timeline_clip_feed.dart';
import 'widgets/timeline_date_scroller.dart';
import 'widgets/timeline_summary_chips.dart';
```

- [x] **Step 6: Add i18n keys**

```json
  "home_timeline_empty": "이 날 기록된 영상이 없어요",
  "home_clip_play_failed": "영상을 재생할 수 없어요",
  "home_back_to_live": "라이브로 돌아가기",
```

- [x] **Step 7: Run all tests and build**

```bash
flutter test && flutter analyze && flutter build apk --debug
```

Expected: 전체 통과 + `No issues found!` + `Built build/app/outputs/flutter-apk/app-debug.apk`

- [x] **Step 8: Bump version and commit**

`pubspec.yaml`의 `version:`을 minor +1, build +1로 올린다 (예: `0.21.0+36` → `0.22.0+37`). 신규 기능 추가이므로 minor.

```bash
git add lib/features/home/presentation/widgets/timeline_clip_feed.dart lib/features/home/presentation/widgets/top_fixed_area.dart lib/features/home/presentation/home_screen.dart assets/l10n/ko.json pubspec.yaml test/features/home/timeline_clip_feed_test.dart
git commit -m "feat(home): 타임라인 클립 피드 + 상단 인라인 재생(컨트롤러 누수 방지)"
```

---

## 작성 상태 (Part 2)

| Task | 내용 | 상태 |
|---|---|---|
| 7 | HomeHeaderBar + `/notifications`·`/enclosure-settings` 스캐폴드 | ✅ 작성 완료 |
| 8 | PetProfileCard (D-Day, 온습도 배지) | ✅ 작성 완료 |
| 9 | TopFixedArea (라이브↔프로필 분기 + 세트 스와이프 + LIVE/OFFLINE) | ✅ 작성 완료 |
| 10 | HomeSubTabsBar + HomeScreen 조립 | ✅ 작성 완료 |
| 11 | RunningTimerChip (진행 중 타이머) | ✅ 작성 완료 |
| 12 | LiveEnvCard (실시간 온습도 + 당일 최고/최저) | ✅ 작성 완료 |
| 13 | EnvMiniChart (24h 라인 + 동작 마커 + 통계탭 이동) | ✅ 작성 완료 |
| 14 | QuickControlGrid (2x2 + LED 슬라이더 + 분무 5초 락) | ✅ 작성 완료 |
| 15 | 타임라인 요약 칩 + 날짜 스크롤러 + 필터 칩 | ✅ 작성 완료 |
| 16 | 타임라인 클립 피드 + 상단 인라인 재생 | ✅ 작성 완료 |

## 실행 순서 (자동진행용)

```
Part 1 (Task 1~6) 전부 통과
   ↓
7 (헤더) ─┐
8 (프로필카드) ─→ 9 (상단영역) ─→ 10 (서브탭바+조립)
                                    ↓
              ┌─────────────────────┼──────────────────┐
              ↓                     ↓                  ↓
        11 (타이머칩)         12 (온습도카드)      15 (요약·날짜·필터)
                                    ↓                  ↓
                        13 (차트) → 14 (제어판)   16 (클립피드+인라인재생)
```

- 11·12·15는 10 완료 후 병렬 가능. 13은 12의 `home_control_providers.dart`를, 16은 15의 `filteredTimelineClipsProvider`와 9의 `TopFixedArea`를 필요로 한다.
- 각 Task 종료 시 `flutter analyze` 에러 0. **버전 bump는 Task 16에서 1회**(minor +1, build +1) — pre-push 훅이 lib 변경 무버전업 push를 차단한다.
- 빌드/수정 루프 3회 초과 시 CAOF 규칙대로 중단 후 보고.

---

## Self-Review

**1. 스펙 커버리지 (PRD §3.1~3.5)**

| PRD 항목 | Task | 비고 |
|---|---|---|
| §3.1 개체 드롭다운 / 1개면 화살표 숨김 | 7 | ✅ |
| §3.1 알림 센터 + 카테고리 + Red Dot | 7 | 화면은 스캐폴드(데이터 소스 없음) |
| §3.1 사육장 설정 + 기기 등록 위저드 진입 | 7 | 기존 페어링 플로우로 연결 |
| §3.2 WebRTC 16:9 라이브 | 9 | ✅ |
| §3.2 좌/우 스와이프 + 페이지 인디케이터 | 9 | ✅ |
| §3.2 LIVE / OFFLINE 배지 | 9 | ✅ |
| §3.2 오프라인 경고 레이어 | 9 | ⚠️ `[재연결]` 버튼 미구현 — `WebRtcLiveView`가 자체 retry를 갖고 있어 중복 UI가 된다. 레이어 문구만 넣었다 |
| §3.2 오버레이 컨트롤 (시각·전체화면·캡처·수동녹화) | 9 | ⚠️ 시각만 구현. 전체화면/캡처/수동녹화는 **미구현** — 백엔드·플랫폼 계약 없음 |
| §3.2 사육장 단품 프로필 카드 (D-Day·급여·체중·상태배지) | 8 | ⚠️ `lastFedAt`을 Task 9에서 `null`로 넘김 — 급여 이력 조회 배선은 미구현 |
| §3.3 2구분 서브탭 + 단품 분기 | 10 | ✅ |
| §3.3 탭 전환 시 스트림 유지 | 10 | ✅ IndexedStack |
| §3.4 진행 중 타이머 칩 | 11 | BE4 대기 — 데이터 없으면 미노출 |
| §3.4 실시간 온습도 + 당일 최고/최저 | 12 | ✅ |
| §3.4 24h 차트 + 동작 마커 + 통계탭 이동 | 13 | 5분 단위는 BE1 대기(현재 30분) |
| §3.4 2x2 제어 + LED 슬라이더 | 14 | 밝기 반영은 BE3 대기 |
| §3.4 분무 5초 락 + 토스트 | 14 | ✅ (1회 분사 시맨틱은 BE2 대기) |
| §3.4 자동 루틴 & 타이머 풀스크린 | 14 | 스캐폴드만 (PRD Q2 "논의 필요") |
| §3.5 요약 칩 4종 | 15 | 식사·물마심은 BE5 대기 |
| §3.5 날짜 스크롤러 (07:00 창) | 15 | ✅ |
| §3.5 필터 칩 + 0건 Disabled 고정 | 15 | ✅ |
| §3.5 클립 피드 + 상단 인라인 재생 | 16 | ✅ |

**미구현으로 남긴 3건**(위 ⚠️)은 스펙이 있으나 의도적으로 제외했다 — 오버레이 캡처/녹화는 백엔드 계약이 없고, `[재연결]`은 기존 위젯과 중복되며, `lastFedAt`은 급여 이력 소스(`pet_events`) 배선이 별건이다. 추측으로 채우지 않았다.

**2. Placeholder 스캔**
Task 9 Step 4의 `// …(이하 기존 코드 그대로)`는 같은 Task Step 3에서 방금 작성한 코드를 가리키는 것이라 미정의가 아니다. 그 외 TBD·"적절히 처리" 류 없음. 모든 코드 스텝에 실제 코드가 들어 있다.

**3. 타입 일관성 (수정 반영됨)**
- `TelemetryBucket`의 필드명을 실제 파일에서 확인해 `tAvg/tMin/tMax`, `hAvg/hMin/hMax`로 확정 (추정 주석 제거).
- `LiveEnvCard._extremesLine`의 인자 타입을 `dynamic` → `EnvExtremes`로 교정하고 import 추가. `dynamic`이면 오타가 런타임까지 숨는다.
- `MarkerKind`·`TimelineFilter`·`HomeSubTab`·`DeviceMode` 전부 정의 Task와 소비 Task 간 이름 일치 확인.
- `inlinePlayingClipProvider`는 Task 16에서 정의하고 Task 9의 파일에서 소비한다 — **Task 9를 먼저 구현하면 그 시점엔 존재하지 않는다.** Task 16 Step 4가 Task 9 파일을 수정하는 순서라 문제없지만, 순서를 뒤집으면 컴파일이 깨진다. 실행 순서도에 반영됨.
- `EnvMiniChart`가 `moduleOnlineProvider`를 쓰지 않고 `QuickControlGrid`만 쓴다 — 차트는 오프라인이어도 과거 데이터를 보여주는 게 맞다(의도된 차이).

**4. 자동진행 리스크**
- Task 9의 `PageView` ↔ `selectedSetIndexProvider` 양방향 갱신은 가드가 있어도 위젯 테스트로만 검증된다. 실기기에서 스와이프 반동이 관찰되면 `onPageChanged` 대신 `PageController.addListener` 기반 디바운스로 바꾼다.
- Task 10에서 `home_screen.dart`를 전면 교체한다. 기존 대시보드 기능(종 검색 진입 등)이 사라지므로, 되돌릴 수 있게 **Task 10을 단독 커밋**으로 유지한다.
- `home_providers.dart`(종 검색)는 다른 화면이 참조하므로 삭제하지 않는다.
