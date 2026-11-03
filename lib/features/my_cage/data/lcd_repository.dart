import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/terra_rest_client.dart';
import '../domain/lcd_screen_state.dart';
import '../domain/lcd_text.dart';

/// `GET /devices/{id}/lcd` 결과 — 화면 설정 + 문구 + 지금 사진 미리보기.
class LcdStateSnapshot {
  const LcdStateSnapshot({
    required this.screen,
    required this.text,
    required this.previewUrl,
  });

  final DeviceLcdScreen screen;
  final DeviceLcdText text;

  /// 지금 올라간 사진의 미리보기(presigned, **1시간** 유효 — 캐시하지 않는다).
  /// 사진이 없으면 null.
  final String? previewUrl;

  factory LcdStateSnapshot.fromJson(Map<String, dynamic> j) {
    final url = j['preview_url'];
    return LcdStateSnapshot(
      screen: DeviceLcdScreen.fromJson(j),
      text: DeviceLcdText.fromJson(j),
      previewUrl: url is String && url.isNotEmpty ? url : null,
    );
  }
}

/// `POST /devices/{id}/lcd/image` 201 응답.
class LcdImageUpload {
  const LcdImageUpload({
    required this.commandId,
    required this.previewUrl,
    required this.sha256,
  });

  /// 기기 전송 명령(`lcd_image`) id — 결과는 그 `commands` 행으로 본다.
  final String commandId;

  /// 기기 화면과 같은 색·자르기의 미리보기 — 기기 반영 전에 바로 보인다.
  final String? previewUrl;
  final String? sha256;
}

/// 디바이스 LCD — 상단 문구(2026-08-14 핸드오프 §3) + 모듈 화면 설정
/// (전원·꺼짐 예약·화면 보호기·사진, 2026-11-03 가이드 `API.md §4.14`). REST 전용.
///
/// 문구: 서버가 텍스트를 비트맵으로 렌더해 전송하고, 디바이스에 저장된다(재부팅
/// 유지). 글자수 하드 상한 64자, 권장 한글 ~8자/영문 ~12자(넘으면 서버가
/// 자동 축소). 빈 문자열도 서버가 clear로 처리하지만 앱은 의도를 분명히
/// 하려고 [clear]를 따로 부른다.
///
/// 화면 설정 쓰기는 모두 명령을 큐에 넣고 201 `{id, action, status:"pending"}`을
/// 돌려준다 — 반환값은 그 **명령 id**다. 반영은 기기 ACK(`result == ok`) 뒤
/// `devices.lcd_*`로 확정된다. 구 펌웨어는 400 `unsupported_firmware`
/// ([TerraRestException.isUnsupportedFirmware]).
class LcdRepository {
  final TerraRestClient _client;

  LcdRepository(this._client);

  Future<void> setText(String deviceId, String text) async {
    await _client.post('/devices/$deviceId/lcd', {'text': text});
  }

  Future<void> clear(String deviceId) async {
    await _client.post('/devices/$deviceId/lcd/clear');
  }

  /// 설정 화면 진입 시 1회 + `lcd_image_key`가 바뀌었을 때·미리보기 만료 때.
  Future<LcdStateSnapshot> getState(String deviceId) async {
    final body = await _client.get('/devices/$deviceId/lcd');
    if (body is! Map) {
      throw const TerraRestException(
          500, 'lcd state response is not an object');
    }
    return LcdStateSnapshot.fromJson(body.cast<String, dynamic>());
  }

  /// 화면 전원. 구 펌웨어에선 끄기가 다시 켤 때까지 유지(sticky), 신 펌웨어
  /// (`lcd_override`)는 예약이 있으면 다음 경계까지만(기획 §12-1).
  Future<String> setPower(String deviceId, bool on) async =>
      _commandId(await _client.put('/devices/$deviceId/lcd/power', {'on': on}));

  /// 꺼짐 예약(KST `HH:MM`). 시작=종료면 서버 400 — 보내기 전에 막는다.
  Future<String> setQuiet(String deviceId, LcdQuietWindow window) async {
    if (!window.isValid) {
      throw ArgumentError.value(window, 'window', 'start == end');
    }
    return _commandId(
        await _client.put('/devices/$deviceId/lcd/quiet', window.toApi()));
  }

  /// 꺼짐 예약 해제(`lcd_quiet_clear`). 서버 값이 NULL이 되므로 시간은 폰이
  /// 기억한다(`LcdQuietStore`, D2).
  Future<String> clearQuiet(String deviceId) async =>
      _commandId(await _client.delete('/devices/$deviceId/lcd/quiet'));

  /// 화면 보호기 — 5개 필드를 항상 전부 보낸다(부분 수정이 아니다).
  Future<String> setSaver(String deviceId, LcdSaverSettings settings) async =>
      _commandId(
          await _client.put('/devices/$deviceId/lcd/saver', settings.toJson()));

  /// 보호 사진 업로드(multipart `file`). 원본 ≤5MB JPEG — 크기·형식 검사는
  /// 호출측이 보내기 전에 한다.
  Future<LcdImageUpload> uploadImage(
    String deviceId,
    List<int> bytes, {
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final body = await _client.postMultipart(
      '/devices/$deviceId/lcd/image',
      field: 'file',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    final id = _commandId(body);
    final map = body! as Map;
    final url = map['preview_url'];
    final sha = map['sha256'];
    return LcdImageUpload(
      commandId: id,
      previewUrl: url is String && url.isNotEmpty ? url : null,
      sha256: sha is String && sha.isNotEmpty ? sha : null,
    );
  }

  /// 보호 사진 삭제(`lcd_image_clear`) — 보호기는 온습도로 떨어진다.
  Future<String> deleteImage(String deviceId) async =>
      _commandId(await _client.delete('/devices/$deviceId/lcd/image'));

  /// 201 `{id, …}`의 명령 id. 없으면 결과를 추적할 수 없으니 실패로 본다
  /// (사육장 재시작과 같은 규칙).
  static String _commandId(Object? body) {
    final id = body is Map ? body['id'] : null;
    if (id is! String || id.isEmpty) {
      throw const TerraRestException(500, 'lcd command response without id');
    }
    return id;
  }
}

final lcdRepositoryProvider = Provider<LcdRepository>((ref) {
  return LcdRepository(ref.watch(terraRestClientProvider));
});
