import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/terra_rest_client.dart';
import '../../../shared/domain/env_thresholds.dart';

/// 온도 보정 기기 명령 — REST `POST /devices/{id}/commands`
/// `set_temp_offset`(v4 1-2, 2026-11-02 사용자 결정 G4).
///
/// **REST 전용** — Supabase `commands` 직결 INSERT로 보내지 않는다(서버가
/// 소유권·허용 범위 ±10.0을 검증하고 MQTT로 내려보낸다). 이 명령은 차트 마커
/// 대상이 아니라 `CommandAction`·`actuator_marker.dart`에 넣지 않는다.
///
/// 기기 값 변환은 반드시 [TempOffset.toDeviceValue]를 거친다(D1 임시 규칙이
/// 서버 회신으로 바뀌면 그 한 곳만 고친다).
class TempOffsetRepository {
  TempOffsetRepository(this._rest);
  final TerraRestClient _rest;

  /// 보낸 명령의 `commands` 행 id. 응답에 id가 없으면 null — 결과
  /// (`commands.result == ok`)는 호출부가 그 행으로 본다. 실패는
  /// [TerraRestException]을 그대로 올린다(404 = 해제·타인 기기, 400 = 범위 밖).
  Future<String?> send(String deviceId, TempOffset offset) async {
    final body = await _rest.post('/devices/$deviceId/commands', {
      'action': 'set_temp_offset',
      'payload': {'offset_c': offset.toDeviceValue()},
    });
    final id = body is Map ? body['id'] : null;
    return id is String && id.isNotEmpty ? id : null;
  }
}

final tempOffsetRepositoryProvider = Provider<TempOffsetRepository>(
    (ref) => TempOffsetRepository(ref.watch(terraRestClientProvider)));
