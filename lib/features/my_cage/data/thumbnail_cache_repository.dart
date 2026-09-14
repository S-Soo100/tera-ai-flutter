import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

typedef ThumbnailCacheKey = ({
  String ownerId,
  String cameraId,
  String clipId,
  String version
});

/// A cache hit never requires a new presigned URL. Metadata and file mutations
/// are serialized so simultaneous downloads cannot exceed the byte budget.
class ThumbnailCacheRepository {
  ThumbnailCacheRepository(
      {required this.directory,
      required this.metadata,
      required this.client,
      this.maxBytes = 200 * 1024 * 1024});
  final Directory directory;
  final Box<dynamic> metadata;
  final http.Client client;
  final int maxBytes;
  final _inFlight = <String, Future<File?>>{};
  final _epochs = <String, int>{};
  Future<void> _mutations = Future.value();
  bool _initialized = false;

  String _id(ThumbnailCacheKey key) => sha256
      .convert(utf8.encode(
          jsonEncode([key.ownerId, key.cameraId, key.clipId, key.version])))
      .toString();

  Future<T> _locked<T>(Future<T> Function() action) async {
    final before = _mutations;
    final done = Completer<void>();
    _mutations = done.future;
    await before;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  Future<File?> getFile(ThumbnailCacheKey key,
      {required Future<Uri?> Function() resolveUrl}) {
    final epoch = _epochs[key.ownerId] ?? 0;
    final flightKey = '${_id(key)}:$epoch';
    return _inFlight.putIfAbsent(
        flightKey,
        () => _getFile(key, epoch, resolveUrl).whenComplete(() {
              _inFlight.remove(flightKey);
            }));
  }

  Future<File?> _getFile(ThumbnailCacheKey key, int epoch,
      Future<Uri?> Function() resolveUrl) async {
    final id = _id(key);
    bool current() => (_epochs[key.ownerId] ?? 0) == epoch;
    final hit = await _locked(() async {
      if (!_initialized) {
        await directory.create(recursive: true);
        await for (final entry in directory.list()) {
          final name = entry.uri.pathSegments.last;
          final orphan = RegExp(r'^[a-f0-9]{64}\.img$').hasMatch(name) &&
              !metadata.containsKey(name.split('.').first);
          final partial =
              RegExp(r'^[a-f0-9]{64}\.[0-9]+\.part$').hasMatch(name);
          if (entry is File && (orphan || partial)) await entry.delete();
        }
        _initialized = true;
      }
      if (!current()) return null;
      final raw = metadata.get(id);
      if (raw is! Map || raw['owner'] != key.ownerId) return null;
      final file = File('${directory.path}/$id.img');
      if (!await file.exists() ||
          await file.length() != raw['bytes'] ||
          !await _validImage(file)) {
        if (await file.exists()) await file.delete();
        await metadata.delete(id);
        return null;
      }
      await metadata
          .put(id, {...raw, 'access': DateTime.now().microsecondsSinceEpoch});
      return file;
    });
    if (!current()) return null;
    if (hit != null) return hit;
    final uri = await resolveUrl();
    if (uri == null || !current()) return null;
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw HttpException('Thumbnail HTTP ${response.statusCode}');
    }
    await directory.create(recursive: true);
    final temp = File('${directory.path}/$id.$epoch.part');
    final sink = temp.openWrite();
    var bytes = 0;
    try {
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 15))) {
        if (!current()) return null;
        bytes += chunk.length;
        if (bytes > math.min(maxBytes, 8 * 1024 * 1024)) {
          throw const FileSystemException('Thumbnail exceeds cache budget');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      if (!current() || !await _validImage(temp)) return null;
      return await _locked(() async {
        if (!current()) return null;
        await _evict(bytes);
        final file = await temp.rename('${directory.path}/$id.img');
        try {
          await metadata.put(id, {
            'owner': key.ownerId,
            'bytes': bytes,
            'access': DateTime.now().microsecondsSinceEpoch
          });
        } catch (_) {
          await file.delete();
          rethrow;
        }
        return file;
      });
    } finally {
      await sink.close();
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<bool> _validImage(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(12);
      if (bytes.length < 12) return false;
      final png =
          bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71;
      final jpeg = bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
      final webp = ascii.decode(bytes.take(4).toList(), allowInvalid: true) ==
              'RIFF' &&
          ascii.decode(bytes.skip(8).toList(), allowInvalid: true) == 'WEBP';
      return png || jpeg || webp;
    } finally {
      await handle.close();
    }
  }

  Future<void> _evict(int incoming) async {
    final entries = metadata
        .toMap()
        .entries
        .where((e) => e.value is Map)
        .toList()
      ..sort((a, b) => ((a.value as Map)['access'] as int? ?? 0)
          .compareTo((b.value as Map)['access'] as int? ?? 0));
    var total = entries.fold<int>(
        incoming, (n, e) => n + ((e.value as Map)['bytes'] as int? ?? 0));
    for (final entry in entries) {
      if (total <= maxBytes) break;
      final file = File('${directory.path}/${entry.key}.img');
      if (await file.exists()) await file.delete();
      await metadata.delete(entry.key);
      total -= (entry.value as Map)['bytes'] as int? ?? 0;
    }
  }

  Future<void> clearOwner(String ownerId) async {
    _epochs[ownerId] = (_epochs[ownerId] ?? 0) + 1;
    await _locked(() async {
      final keys = metadata
          .toMap()
          .entries
          .where((entry) =>
              entry.value is Map && (entry.value as Map)['owner'] == ownerId)
          .map((e) => e.key)
          .toList();
      for (final key in keys) {
        final file = File('${directory.path}/$key.img');
        if (await file.exists()) await file.delete();
        await metadata.delete(key);
      }
    });
  }
}
