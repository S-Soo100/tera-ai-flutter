import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// MJPEG multipart 스트림을 JPEG 바이트 스트림으로 변환하는 클라이언트.
///
/// 사용 예:
/// ```dart
/// final client = MjpegStreamClient(url: url, username: user, password: pass);
/// await for (final frame in client.connect()) {
///   // frame: Uint8List (JPEG 바이트)
/// }
/// await client.close();
/// ```
class MjpegStreamClient {
  MjpegStreamClient({
    required this.url,
    this.username,
    this.password,
  });

  final String url;
  final String? username;
  final String? password;

  http.Client? _client;

  /// MJPEG 스트림에 연결하고 프레임(JPEG 바이트)을 yield한다.
  /// 정상 종료/오류 시 [close]를 반드시 호출해야 한다.
  Stream<Uint8List> connect() async* {
    _client = http.Client();
    final client = _client!;

    try {
      final request = http.Request('GET', Uri.parse(url));

      // Basic Auth 헤더
      if (username != null && password != null) {
        final credentials = base64Encode(utf8.encode('$username:$password'));
        request.headers['Authorization'] = 'Basic $credentials';
      }

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'MJPEG stream HTTP ${response.statusCode}',
        );
      }

      // Content-Type 헤더에서 boundary 파싱
      // 예: "multipart/x-mixed-replace; boundary=123456789000000000000987654321"
      final contentType = response.headers['content-type'] ?? '';
      final boundary = _parseBoundary(contentType);
      if (boundary == null) {
        throw Exception('boundary를 찾을 수 없습니다: $contentType');
      }

      // "--boundary" 패턴 (멀티파트 표준)
      final boundaryMarker = '--$boundary';
      final boundaryBytes = utf8.encode(boundaryMarker);

      // chunked 스트림을 누적 버퍼링
      var buffer = <int>[];

      await for (final chunk in response.stream) {
        buffer.addAll(chunk);

        // 버퍼에서 완성된 part를 반복 추출
        while (true) {
          final result = _extractFrame(buffer, boundaryBytes);
          if (result == null) break;
          final frame = result.$1;
          buffer = result.$2;
          if (frame != null) {
            yield frame;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// 버퍼에서 boundary → part 헤더 → JPEG 바이트를 추출.
  /// 반환: (frame | null, 남은버퍼) 또는 데이터 부족 시 null.
  (Uint8List?, List<int>)? _extractFrame(
    List<int> buffer,
    List<int> boundaryBytes,
  ) {
    // boundary 위치 탐색
    final boundaryIdx = _indexOf(buffer, boundaryBytes);
    if (boundaryIdx < 0) return null;

    // boundary 이후부터 part 시작
    var pos = boundaryIdx + boundaryBytes.length;

    // \r\n 건너뜀 (boundary 바로 다음)
    if (pos + 1 < buffer.length &&
        buffer[pos] == 0x0D &&
        buffer[pos + 1] == 0x0A) {
      pos += 2;
    }

    // 헤더 종료 "\r\n\r\n" 탐색
    const headerEnd = [0x0D, 0x0A, 0x0D, 0x0A];
    final headerEndIdx = _indexOf(buffer.sublist(pos), headerEnd);
    if (headerEndIdx < 0) return null; // 헤더 아직 미완성

    final headerBytes = buffer.sublist(pos, pos + headerEndIdx);
    final headerStr = utf8.decode(headerBytes, allowMalformed: true);
    final dataStart = pos + headerEndIdx + 4; // \r\n\r\n 이후

    // Content-Length 파싱
    final contentLength = _parseContentLength(headerStr);
    if (contentLength == null) {
      // Content-Length 없으면 다음 boundary 기준으로 잘라내기 (fallback)
      final nextBoundaryIdx = _indexOf(
        buffer.sublist(dataStart),
        boundaryBytes,
      );
      if (nextBoundaryIdx < 0) return null;
      final frameBytes =
          Uint8List.fromList(buffer.sublist(dataStart, dataStart + nextBoundaryIdx));
      final remaining = buffer.sublist(dataStart + nextBoundaryIdx);
      return (frameBytes, remaining);
    }

    // Content-Length만큼 JPEG 바이트가 쌓였는지 확인
    if (dataStart + contentLength > buffer.length) return null;

    final frameBytes =
        Uint8List.fromList(buffer.sublist(dataStart, dataStart + contentLength));
    final remaining = buffer.sublist(dataStart + contentLength);
    return (frameBytes, remaining);
  }

  /// Content-Type 헤더에서 boundary 값 추출.
  /// 대소문자 무관, 따옴표/공백 허용.
  String? _parseBoundary(String contentType) {
    final lower = contentType.toLowerCase();
    final idx = lower.indexOf('boundary=');
    if (idx < 0) return null;
    var boundary = contentType.substring(idx + 9).trim();
    // 따옴표 제거
    if (boundary.startsWith('"') && boundary.endsWith('"')) {
      boundary = boundary.substring(1, boundary.length - 1);
    }
    // 세미콜론 이후 제거
    final semiIdx = boundary.indexOf(';');
    if (semiIdx >= 0) {
      boundary = boundary.substring(0, semiIdx).trim();
    }
    return boundary.isEmpty ? null : boundary;
  }

  /// part 헤더 문자열에서 Content-Length 값 파싱.
  int? _parseContentLength(String headers) {
    final lower = headers.toLowerCase();
    final idx = lower.indexOf('content-length:');
    if (idx < 0) return null;
    final rest = headers.substring(idx + 15).trim();
    final lineEnd = rest.indexOf('\r\n');
    final valueStr = lineEnd >= 0 ? rest.substring(0, lineEnd).trim() : rest.trim();
    return int.tryParse(valueStr);
  }

  /// List of int에서 패턴 첫 번째 위치 반환. 없으면 -1.
  int _indexOf(List<int> source, List<int> pattern) {
    if (pattern.isEmpty || source.length < pattern.length) return -1;
    outer:
    for (var i = 0; i <= source.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  /// 연결을 닫는다. dispose에서 반드시 호출.
  Future<void> close() async {
    _client?.close();
    _client = null;
  }
}
