import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vivanaut/core/network/auth_session.dart';
import 'package:vivanaut/core/network/terra_rest_client.dart';
import 'package:vivanaut/features/my_cage/data/lcd_repository.dart';
import 'package:vivanaut/features/my_cage/domain/lcd_screen_state.dart';

class _Session implements AuthSession {
  _Session({this.recovers = false});
  final bool recovers;
  var recoveries = 0;

  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> recoverFromUnauthorized() async {
    recoveries++;
    return recovers;
  }
}

/// 호출(메서드·경로·본문)을 기록하고 미리 정한 응답을 돌려준다.
class _FakeRest extends TerraRestClient {
  _FakeRest(this.response)
      : super(baseUrl: 'https://terra.test', session: _Session());

  final Object? response;
  final calls = <(String, String, Object?)>[];

  @override
  Future<Object?> get(String path) async {
    calls.add(('GET', path, null));
    return response;
  }

  @override
  Future<Object?> put(String path, Map<String, dynamic> body) async {
    calls.add(('PUT', path, body));
    return response;
  }

  @override
  Future<Object?> delete(String path) async {
    calls.add(('DELETE', path, null));
    return response;
  }

  @override
  Future<Object?> postMultipart(String path,
      {required String field,
      required List<int> bytes,
      required String filename,
      required String contentType}) async {
    calls.add((
      'MULTIPART',
      path,
      {
        'field': field,
        'bytes': bytes,
        'filename': filename,
        'type': contentType
      }
    ));
    return response;
  }
}

/// 실제 [TerraRestClient]를 HTTP 층에서 본다(헤더·본문 바이트).
class _Http extends http.BaseClient {
  _Http(this._responses);
  final List<http.Response> _responses;
  final requests = <http.BaseRequest>[];
  final bodies = <List<int>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    bodies.add(await request.finalize().toBytes());
    final resp =
        _responses[(requests.length - 1).clamp(0, _responses.length - 1)];
    return http.StreamedResponse(Stream.value(resp.bodyBytes), resp.statusCode);
  }
}

const _created = {'id': 'cmd-1', 'action': 'lcd_power', 'status': 'pending'};

void main() {
  group('LcdRepository', () {
    test('getState — GET /lcd → 화면 설정·문구·미리보기', () async {
      final fake = _FakeRest({
        'device_id': 'd1',
        'lcd_text': '밥 6시',
        'lcd_text_updated_at': '2026-11-03T01:00:00+00:00',
        'lcd_power': true,
        'lcd_quiet_start': '23:00:00',
        'lcd_quiet_end': '07:00:00',
        'lcd_saver': null,
        'lcd_image_key': 'lcd/d1/3f9a',
        'preview_url': 'https://r2.test/3f9a.png?sig',
      });
      final s = await LcdRepository(fake).getState('d1');
      expect(fake.calls.single.$1, 'GET');
      expect(fake.calls.single.$2, '/devices/d1/lcd');
      expect(s.screen.quiet, LcdQuietWindow.parse('23:00', '07:00'));
      expect(s.screen.saver, isNull);
      expect(s.screen.imageKey, 'lcd/d1/3f9a');
      expect(s.text.text, '밥 6시');
      expect(s.previewUrl, 'https://r2.test/3f9a.png?sig');
    });

    test('getState — 사진 없으면 미리보기 null, 객체가 아니면 실패', () async {
      final s =
          await LcdRepository(_FakeRest({'preview_url': null})).getState('d1');
      expect(s.previewUrl, isNull);
      await expectLater(LcdRepository(_FakeRest([])).getState('d1'),
          throwsA(isA<TerraRestException>()));
    });

    test('setPower — PUT /lcd/power {on} → 명령 id', () async {
      final fake = _FakeRest(_created);
      expect(await LcdRepository(fake).setPower('d1', false), 'cmd-1');
      final (method, path, body) = fake.calls.single;
      expect(method, 'PUT');
      expect(path, '/devices/d1/lcd/power');
      expect(body, {'on': false});
    });

    test('setQuiet — PUT /lcd/quiet {start,end} HH:MM', () async {
      final fake = _FakeRest(_created);
      await LcdRepository(fake).setQuiet('d1', LcdQuietWindow.defaults);
      expect(fake.calls.single.$1, 'PUT');
      expect(fake.calls.single.$2, '/devices/d1/lcd/quiet');
      expect(fake.calls.single.$3, {'start': '20:00', 'end': '08:00'});
    });

    test('setQuiet — 시작=종료는 보내지 않는다', () async {
      final fake = _FakeRest(_created);
      await expectLater(
          LcdRepository(fake).setQuiet(
              'd1', const LcdQuietWindow(startMinute: 60, endMinute: 60)),
          throwsArgumentError);
      expect(fake.calls, isEmpty);
    });

    test('clearQuiet — DELETE /lcd/quiet 본문의 id', () async {
      final fake = _FakeRest({'id': 'cmd-2', 'action': 'lcd_quiet_clear'});
      expect(await LcdRepository(fake).clearQuiet('d1'), 'cmd-2');
      expect(fake.calls.single.$1, 'DELETE');
      expect(fake.calls.single.$2, '/devices/d1/lcd/quiet');
    });

    test('setSaver — PUT /lcd/saver 5필드 전부', () async {
      final fake = _FakeRest(_created);
      await LcdRepository(fake).setSaver('d1',
          LcdSaverSettings.defaults.copyWith(enabled: true, imageSec: 120));
      expect(fake.calls.single.$2, '/devices/d1/lcd/saver');
      expect(fake.calls.single.$3, {
        'enabled': true,
        'mode': 'rotate',
        'image_sec': 120,
        'info_sec': 10,
        'show_offline_icon': true,
      });
    });

    test('uploadImage — multipart file → 명령 id·미리보기·sha', () async {
      final fake = _FakeRest({
        'id': 'cmd-3',
        'action': 'lcd_image',
        'status': 'pending',
        'sha256': '3f9a1c2e',
        'preview_url': 'https://r2.test/3f9a1c2e.png?sig',
      });
      final up = await LcdRepository(fake).uploadImage('d1', [1, 2, 3]);
      expect(up.commandId, 'cmd-3');
      expect(up.sha256, '3f9a1c2e');
      expect(up.previewUrl, 'https://r2.test/3f9a1c2e.png?sig');
      final (method, path, body) = fake.calls.single;
      expect(method, 'MULTIPART');
      expect(path, '/devices/d1/lcd/image');
      expect(body, {
        'field': 'file',
        'bytes': [1, 2, 3],
        'filename': 'photo.jpg',
        'type': 'image/jpeg',
      });
    });

    test('deleteImage — DELETE /lcd/image', () async {
      final fake = _FakeRest({'id': 'cmd-4', 'action': 'lcd_image_clear'});
      expect(await LcdRepository(fake).deleteImage('d1'), 'cmd-4');
      expect(fake.calls.single.$1, 'DELETE');
      expect(fake.calls.single.$2, '/devices/d1/lcd/image');
    });

    test('응답에 id가 없으면 실패 — 결과를 추적할 수 없다', () async {
      for (final body in [
        null,
        <String, dynamic>{},
        {'id': ''},
        'ok'
      ]) {
        await expectLater(LcdRepository(_FakeRest(body)).setPower('d1', true),
            throwsA(isA<TerraRestException>()),
            reason: '$body');
      }
    });
  });

  group('TerraRestClient — put·delete 본문·multipart', () {
    TerraRestClient client(_Http h, {_Session? session}) => TerraRestClient(
        baseUrl: 'https://terra.test',
        session: session ?? _Session(),
        httpClient: h);

    test('put은 JSON 본문·인증 헤더', () async {
      final h = _Http([http.Response(jsonEncode(_created), 201)]);
      final body = await client(h).put('/devices/d1/lcd/power', {'on': true});
      expect(body, _created);
      final req = h.requests.single;
      expect(req.method, 'PUT');
      expect(req.url.toString(), 'https://terra.test/devices/d1/lcd/power');
      expect(req.headers['Authorization'], 'Bearer token');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(utf8.decode(h.bodies.single)), {'on': true});
    });

    test('delete는 201 본문을 돌려준다', () async {
      final h = _Http([
        http.Response(
            jsonEncode({'id': 'c9', 'action': 'lcd_quiet_clear'}), 201)
      ]);
      expect(await client(h).delete('/devices/d1/lcd/quiet'),
          {'id': 'c9', 'action': 'lcd_quiet_clear'});
      expect(h.requests.single.method, 'DELETE');
    });

    test('delete 본문이 없으면 null(기존 호출 호환)', () async {
      final h = _Http([http.Response('', 204)]);
      expect(await client(h).delete('/schedules/s1'), isNull);
    });

    test('multipart — 파일 필드·파일명·형식·바이트', () async {
      final h = _Http([http.Response(jsonEncode(_created), 201)]);
      await client(h).postMultipart('/devices/d1/lcd/image',
          field: 'file',
          bytes: [0xFF, 0xD8, 0x00, 0xFF],
          filename: 'photo.jpg',
          contentType: 'image/jpeg');
      final req = h.requests.single;
      expect(req.method, 'POST');
      expect(req.headers['Authorization'], 'Bearer token');
      final type = req.headers['Content-Type']!;
      expect(type, startsWith('multipart/form-data; boundary='));
      final boundary = type.split('boundary=').last;
      final bytes = h.bodies.single;
      final text = latin1.decode(bytes);
      expect(text, startsWith('--$boundary\r\n'));
      expect(
          text,
          contains(
              'content-disposition: form-data; name="file"; filename="photo.jpg"'));
      expect(text, contains('content-type: image/jpeg'));
      expect(text, contains('\r\n\r\nÿØ\u0000ÿ\r\n--$boundary--'));
    });

    test('multipart도 401이면 세션을 되살려 새 요청으로 한 번 더', () async {
      final session = _Session(recovers: true);
      final h = _Http([
        http.Response('{"detail":"expired"}', 401),
        http.Response(jsonEncode(_created), 201),
      ]);
      final body = await client(h, session: session).postMultipart(
          '/devices/d1/lcd/image',
          field: 'file',
          bytes: [1],
          filename: 'p.jpg',
          contentType: 'image/jpeg');
      expect(body, _created);
      expect(session.recoveries, 1);
      expect(h.requests, hasLength(2));
      expect(identical(h.requests[0], h.requests[1]), isFalse);
    });

    test('400 unsupported_firmware는 예외에서 구분된다', () async {
      final h = _Http([
        http.Response(
            jsonEncode({'detail': 'unsupported_firmware: lcd_saver'}), 400)
      ]);
      await expectLater(
          client(h).put('/devices/d1/lcd/saver', {}),
          throwsA(isA<TerraRestException>()
              .having((e) => e.isUnsupportedFirmware, 'unsupported', isTrue)
              .having((e) => e.statusCode, 'status', 400)));
      expect(
          const TerraRestException(400, 'start == end').isUnsupportedFirmware,
          isFalse);
      expect(
          const TerraRestException(422, 'unsupported_firmware')
              .isUnsupportedFirmware,
          isFalse);
    });
  });
}
