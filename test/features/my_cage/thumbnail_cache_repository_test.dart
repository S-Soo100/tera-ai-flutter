import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivanaut/features/my_cage/data/thumbnail_cache_repository.dart';

void main() {
  late Directory root;
  late Box<dynamic> metadata;
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZQAAAABJRU5ErkJggg==');
  ThumbnailCacheKey key(String clip, {String owner = 'a'}) =>
      (ownerId: owner, cameraId: 'cam', clipId: clip, version: 'v1');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('thumb-test');
    Hive.init(root.path);
    metadata = await Hive.openBox<dynamic>('thumb-meta');
  });
  tearDown(() async {
    await metadata.close();
    await root.delete(recursive: true);
  });
  test('캐시 hit은 URL 발급과 다운로드가 없고 재시작 후에도 유지된다', () async {
    var urls = 0;
    var downloads = 0;
    final client = MockClient((r) async {
      downloads++;
      return http.Response.bytes(png, 200, request: r);
    });
    final repo = ThumbnailCacheRepository(
        directory: root, metadata: metadata, client: client);
    Future<Uri?> url() async {
      urls++;
      return Uri.parse('https://example.test/thumb');
    }

    final first = await repo.getFile(key('1'), resolveUrl: url);
    final restarted = ThumbnailCacheRepository(
        directory: root, metadata: metadata, client: client);
    final cached = await restarted.getFile(key('1'), resolveUrl: url);
    expect(cached!.path, first!.path);
    expect(urls, 1);
    expect(downloads, 1);
  });
  test('동시 요청은 합치고 용량 상한은 바이트로 오래된 파일부터 정리한다', () async {
    var downloads = 0;
    final repo = ThumbnailCacheRepository(
        directory: root,
        metadata: metadata,
        maxBytes: png.length + 1,
        client: MockClient((r) async {
          downloads++;
          return http.Response.bytes(png, 200, request: r);
        }));
    Future<Uri?> url() async => Uri.parse('https://example.test/thumb');
    final files = await Future.wait(
        List.generate(3, (_) => repo.getFile(key('1'), resolveUrl: url)));
    expect(downloads, 1);
    final second = await repo.getFile(key('2'), resolveUrl: url);
    expect(await files.first!.exists(), false);
    expect(await second!.exists(), true);
  });
  test('계정 정리 중 완료된 다운로드는 파일이나 metadata를 되살리지 않는다', () async {
    final response = Completer<http.Response>();
    final repo = ThumbnailCacheRepository(
        directory: root,
        metadata: metadata,
        client: MockClient((r) => response.future));
    final pending = repo.getFile(key('1'),
        resolveUrl: () async => Uri.parse('https://example.test/thumb'));
    await Future<void>.delayed(Duration.zero);
    await repo.clearOwner('a');
    response.complete(http.Response.bytes(png, 200));
    expect(await pending, isNull);
    expect(metadata.values, isEmpty);
  });
  test('없는 파일은 다시 받고 다른 계정 파일을 공유하지 않는다', () async {
    var downloads = 0;
    final repo = ThumbnailCacheRepository(
        directory: root,
        metadata: metadata,
        client: MockClient((r) async {
          downloads++;
          return http.Response.bytes(png, 200, request: r);
        }));
    Future<Uri?> url() async => Uri.parse('https://example.test/thumb');
    final first = await repo.getFile(key('1'), resolveUrl: url);
    await first!.delete();
    final restored = await repo.getFile(key('1'), resolveUrl: url);
    final other = await repo.getFile(key('1', owner: 'b'), resolveUrl: url);
    expect(restored!.path, isNot(other!.path));
    expect(downloads, 3);
  });
}
