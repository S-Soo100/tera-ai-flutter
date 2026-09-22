import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/core/supabase/supabase_provider.dart';
import 'package:vivanaut/features/my_cage/domain/pair_target_kind.dart';
import 'package:vivanaut/features/my_cage/presentation/device_add_flow_controller.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'device_add_flow_test.dart' show Gateway;

/// 2026-09-22 사고: `DeviceAddFlowRoute`가 안쪽 `ProviderScope`에서 자동 묶기·
/// 완료 콜백을 바꿔 끼웠지만 flow provider에 `dependencies`가 없어 최상위의
/// 기본값(항상 실패)을 읽었다 — 릴리스에선 조용히, 디버그에선 assertion.
void main() {
  test('안쪽 scope에서 바꾼 자동 묶기·완료 콜백을 flow가 그대로 쓴다', () {
    final client = SupabaseClient('http://localhost', 'anon');
    addTearDown(client.dispose);
    final root = ProviderContainer(overrides: [
      supabaseClientProvider.overrideWithValue(client),
      deviceAddAccountProvider.overrideWithValue('a'),
      deviceAddGatewayFactoryProvider.overrideWithValue(Gateway.new),
      freshAccessTokenProvider.overrideWithValue(() async => null),
    ]);
    addTearDown(root.dispose);
    Future<String> group(String _, Map<PairTargetKind, String> __) async =>
        'scoped';
    void completed() {}
    final child = ProviderContainer(parent: root, overrides: [
      deviceAddAutoGroupProvider.overrideWithValue(group),
      deviceAddCompletedProvider.overrideWithValue(completed),
    ]);
    addTearDown(child.dispose);

    final controller = child.read(deviceAddFlowProvider('k').notifier);
    expect(controller.debugAutoGroup, same(group));
    expect(controller.debugCompleted, same(completed));
  });
}
