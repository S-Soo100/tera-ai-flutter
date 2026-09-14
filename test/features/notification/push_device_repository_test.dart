import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/notification/data/push_device_repository.dart';

void main() {
  test('registration binds expected account and emits only approved RPC fields',
      () async {
    String? userId = 'a';
    final calls = <(String, Map<String, Object?>)>[];
    final repo = PushDeviceRepository(
      currentUserId: () => userId,
      rpc: (name, params) async {
        calls.add((name, params));
      },
    );
    await repo.register(
        userId: 'a',
        installationId: 'installation',
        token: 'test-token',
        appVersion: '1+1',
        locale: 'ko');
    expect(calls.single.$1, 'register_push_device');
    expect(calls.single.$2, <String, Object?>{
      'p_installation_id': 'installation',
      'p_fcm_token': 'test-token',
      'p_platform': 'android',
      'p_app_version': '1+1',
      'p_locale': 'ko',
    });
    userId = 'b';
    await repo.register(
        userId: 'a',
        installationId: 'installation',
        token: 'old-token',
        appVersion: '1+1',
        locale: 'ko');
    expect(calls, hasLength(1));
    await repo.deactivate('installation');
    expect(calls.last.$1, 'deactivate_push_device');
    expect(
        calls.last.$2, <String, Object?>{'p_installation_id': 'installation'});
  });
}
