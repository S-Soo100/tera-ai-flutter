import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/terra_rest_client.dart';

/// 디바이스 LCD 상단 커스텀 텍스트 (2026-08-14 핸드오프 §3). REST 전용.
///
/// 서버가 텍스트를 비트맵으로 렌더해 전송하고, 디바이스에 저장된다(재부팅
/// 유지). 글자수 하드 상한 64자, 권장 한글 ~8자/영문 ~12자(넘으면 서버가
/// 자동 축소). 빈 문자열도 서버가 clear로 처리하지만 앱은 의도를 분명히
/// 하려고 [clear]를 따로 부른다.
///
/// 응답의 command(`lcd_bitmap`/`lcd_clear`)는 `commands`로 흐른다 — 상태
/// 추적이 필요하면 `commands-rt`를 보면 되지만, 지금 UI는 발행 성공/실패
/// 토스트까지만 한다.
class LcdRepository {
  final TerraRestClient _client;

  LcdRepository(this._client);

  Future<void> setText(String deviceId, String text) async {
    await _client.post('/devices/$deviceId/lcd', {'text': text});
  }

  Future<void> clear(String deviceId) async {
    await _client.post('/devices/$deviceId/lcd/clear');
  }
}

final lcdRepositoryProvider = Provider<LcdRepository>((ref) {
  return LcdRepository(ref.watch(terraRestClientProvider));
});
