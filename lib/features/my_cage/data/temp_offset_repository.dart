import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/network/terra_rest_client.dart';
import '../../../shared/domain/env_thresholds.dart';

/// 온도 보정 기기 명령 — REST `POST /devices/{id}/commands`
/// `set_temp_offset`(v4 1-2, 2026-11-02 사용자 결정 G4).
///
/// **REST 전용** — Supabase `commands` 직결 INSERT로 보내지 않는다(서버가
/// 소유권·허용 범위 ±10.0을 검증하고 MQTT로 내려보낸다). 이 명령은 차트 마커
/// 대상이 아니라 `CommandAction`·`actuator_marker.dart`에 넣지 않는다.
///
/// 보내는 키는 계약([userContract])에 따라 하나뿐이다 — 한 명령에 둘을 같이
/// 보내면 서버가 400으로 거절한다.
/// - 옛 계약: `offset_c` = [TempOffset.toDeviceValue](공장 보정 −1.5 + 사용자
///   보정 — 서버 회신 2026-11-02 §1.2).
/// - 새 계약: `user_offset_c` = 사용자 보정값 그대로(0.1 단위). 공장 보정은 서버가
///   더한다(서버 `APP_TEMP_OFFSET_SERVER_BASE_2026-11-05.md`).
///
/// 사용자 JWT로 써도 되고 빈도 제한은 없다(§2) — 연타 방지는 화면 몫.
class TempOffsetRepository {
  TempOffsetRepository(this._rest, {this.userContract = false});
  final TerraRestClient _rest;

  /// 새 계약(`FeatureFlags.tempOffsetUserContract`)이면 true.
  final bool userContract;

  /// 보낸 명령의 `commands` 행 id. 응답에 id가 없으면 null — 결과
  /// (`commands.result == ok`)는 호출부가 그 행으로 본다. 실패는
  /// [TerraRestException]을 그대로 올린다(404 = 해제·타인 기기, 400 = 범위 밖).
  Future<String?> send(String deviceId, TempOffset offset) async {
    final body = await _rest.post('/devices/$deviceId/commands', {
      'action': 'set_temp_offset',
      'payload': userContract
          // 편집기 값은 0.1 단위지만 const 생성자는 단위를 보장하지 않는다.
          ? {'user_offset_c': (offset.value * 10).round() / 10}
          : {'offset_c': offset.toDeviceValue()},
    });
    final id = body is Map ? body['id'] : null;
    return id is String && id.isNotEmpty ? id : null;
  }
}

final tempOffsetRepositoryProvider = Provider<TempOffsetRepository>((ref) =>
    TempOffsetRepository(ref.watch(terraRestClientProvider),
        userContract: ref.watch(tempOffsetUserContractProvider)));
