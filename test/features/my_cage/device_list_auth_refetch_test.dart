import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivnanaut/features/my_cage/data/supabase_module_control_repository.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';

/// 로그인 직후 기기 목록 빈 캐시 회귀 테스트 (2026-08-14 실기기 발견).
///
/// 게스트(비로그인)로 홈에 들어오면 devices RLS가 빈 목록을 **무에러** 반환하고,
/// 그 값이 provider에 캐시된다. 이후 로그인해도 [deviceListProvider]가 계정을
/// watch하지 않으면 빈 캐시가 그대로 재사용된다 — 통계·제어가 "연결된 사육장이
/// 없어요"로 죽어 보이던 원인.
///
/// 계약: **계정(id)이 바뀌면 기기 목록은 반드시 다시 조회된다.**
/// (project_auth_provider_stale_pattern — enclosures·cameras·petList와 동일)

/// listDevices 호출 횟수를 세는 fake. 첫 호출은 게스트(빈 목록), 이후엔 기기 1대.
class _FakeRepo implements SupabaseModuleControlRepository {
  int calls = 0;

  @override
  Future<List<Device>> listDevices() async {
    calls++;
    if (calls == 1) return const [];
    return [
      Device.fromJson(const {'id': 'd1', 'enclosure_id': 'e1'}),
    ];
  }

  // 이 테스트가 쓰지 않는 나머지 멤버는 호출되면 즉시 드러나게 둔다.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('계정이 바뀌면 deviceListProvider가 다시 조회한다', () async {
    final repo = _FakeRepo();
    User? user; // null = 게스트

    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => user),
      supabaseModuleControlRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // 게스트 상태에서 캐시 형성. autoDispose 유지를 위해 listen을 잡아 둔다
    // (실앱에서 enclosureSetsProvider가 계속 watch하는 상황의 재현).
    final sub = container.listen(deviceListProvider.future, (_, __) {});
    addTearDown(sub.close);
    expect(await container.read(deviceListProvider.future), isEmpty,
        reason: '게스트 첫 조회는 RLS 빈 목록');

    // 로그인: 계정 id 등장.
    user = User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
    );
    container.refresh(currentUserProvider);
    await container.pump();

    // 계정이 바뀌었으니 재조회돼 기기가 보여야 한다.
    final after = await container.read(deviceListProvider.future);
    expect(after, hasLength(1),
        reason: '로그인 후에도 게스트 빈 캐시가 재사용되면 이 버그의 재발');
    expect(repo.calls, greaterThanOrEqualTo(2),
        reason: '재조회가 실제로 발생해야 한다');
  });
}
