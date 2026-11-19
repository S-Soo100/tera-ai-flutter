import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/device_add_flow.dart';
import '../domain/network_manage.dart';
import '../domain/pair_target_kind.dart';
import '../domain/sys_health.dart';

/// Read-only confirmation of the firmware's PAIR_OK identifier. The app never
/// calls /pair, inserts a device, guesses an ID, or infers kind from its prefix.
class DeviceAddRegistrationRepository {
  DeviceAddRegistrationRepository(this.client,
      {String? Function()? accountIdProvider})
      : _accountId = accountIdProvider ?? (() => client.auth.currentUser?.id);
  final SupabaseClient client;
  final String? Function() _accountId;
  void _guard(String account) {
    if (_accountId() != account) {
      throw StateError('Account changed');
    }
  }

  Future<List<String>> names(String account) async {
    _guard(account);
    final devices = await client
        .from('devices')
        .select('name,unlinked_at')
        .eq('owner_id', account);
    _guard(account);
    final cameras = await client
        .from('cameras')
        .select('name,unlinked_at')
        .eq('owner_id', account);
    _guard(account);
    // 해제된 행의 이름은 세지 않는다 — 지웠다 다시 붙일 때마다 번호만 커졌다
    // (2026-09-25 점검). 서버 이름 중복 검사도 unlinked_at IS NULL만 본다.
    return [
      for (final row in [...devices, ...cameras])
        if (row['unlinked_at'] == null)
          if (row['name'] case final String name) name
    ];
  }

  Future<String?> confirm(
      String account, PairTargetKind kind, String hardwareId) async {
    _guard(account);
    final isCamera = kind == PairTargetKind.camera;
    final rows = await client
        .from(isCamera ? 'cameras' : 'devices')
        .select('id')
        .eq('owner_id', account)
        .eq(isCamera ? 'camera_id' : 'device_id', hardwareId)
        .limit(2);
    _guard(account);
    if (rows.length != 1) return null;
    final id = rows.single['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// 이 계정의 기기 행이 아직 있으면 마지막 접속 시각·`hw_id`와 함께 돌려준다.
  /// 삭제·해제(`unlinked_at`)됐거나 다른 계정으로 넘어갔으면 null — 새로
  /// 등록해야 한다(해제된 행으로 Wi-Fi만 붙이면 목록에 안 보인다).
  ///
  /// 카메라는 다른 계정이 같은 보드를 등록해 서버가 `superseded_at`을 찍은
  /// 행도 null이다(2026-11-10) — 새로 등록하면 서버가 같은 행을 되돌려 준다.
  /// **그 컬럼은 cameras에만 있다** — devices 조회에 넣으면 PostgREST 400.
  Future<OwnedDeviceRow?> owned(
      String account, PairTargetKind kind, String id) async {
    _guard(account);
    final isCamera = kind == PairTargetKind.camera;
    final rows = await client
        .from(isCamera ? 'cameras' : 'devices')
        .select(isCamera
            ? 'id,last_seen_at,hw_id,is_online,unlinked_at,superseded_at'
            : 'id,last_seen_at,hw_id,is_online,unlinked_at')
        .eq('owner_id', account)
        .eq('id', id)
        .limit(1);
    _guard(account);
    if (rows.isEmpty ||
        rows.single['unlinked_at'] != null ||
        rows.single['superseded_at'] != null) {
      return null;
    }
    final raw = rows.single['last_seen_at'];
    final hw = rows.single['hw_id'];
    final online = rows.single['is_online'];
    return (
      lastSeen: raw == null ? null : DateTime.tryParse(raw.toString()),
      hardwareId: hw is String && hw.isNotEmpty ? hw : null,
      isOnline: online is bool ? online : null
    );
  }

  /// 네트워크 관리 목록용 이 계정 기기 행 전부(2026-11-19). 화면을 열 때·
  /// [다시 스캔] 때만 읽는다 — `clip_stats`는 heartbeat마다 바뀌어
  /// `camerasProvider`에 넣지 않는다(CLAUDE.md).
  ///
  /// 전체 열을 고른다: 서버에 `wifi_ssid`가 생기면 앱 수정 없이 읽고, 없는 열을
  /// 이름으로 고르면 PostgREST가 400을 낸다. 해제(`unlinked_at`)·대체
  /// (`superseded_at`, cameras에만 있다) 행은 [owned]와 같은 규칙으로 앱에서 거른다.
  Future<List<OwnedNetworkDevice>> networkDevices(String account) async {
    _guard(account);
    final devices =
        await client.from('devices').select().eq('owner_id', account);
    _guard(account);
    final cameras =
        await client.from('cameras').select().eq('owner_id', account);
    _guard(account);
    return [
      for (final row in devices)
        if (_networkRow(row, PairTargetKind.device) case final d?) d,
      for (final row in cameras)
        if (_networkRow(row, PairTargetKind.camera) case final d?) d,
    ];
  }

  /// [networkDevices]의 행 하나 — 보내기 직전 재확인·확인 중 폴링용(목록 전체를
  /// 5초마다 기기 수만큼 읽지 않게, 2026-11-19 리뷰). 해제·대체됐으면 null.
  Future<OwnedNetworkDevice?> networkDevice(
      String account, PairTargetKind kind, String id) async {
    _guard(account);
    final rows = await client
        .from(kind == PairTargetKind.camera ? 'cameras' : 'devices')
        .select()
        .eq('owner_id', account)
        .eq('id', id)
        .limit(1);
    _guard(account);
    return rows.isEmpty ? null : _networkRow(rows.first, kind);
  }

  static OwnedNetworkDevice? _networkRow(
      Map<String, dynamic> row, PairTargetKind kind) {
    if (row['unlinked_at'] != null || row['superseded_at'] != null) {
      return null;
    }
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    final health = kind == PairTargetKind.camera
        ? SysHealth.fromCameraRow(row)
        : SysHealth.fromDeviceRow(row);
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    final seen = row['last_seen_at'];
    final online = row['is_online'];
    return OwnedNetworkDevice(
        kind: kind,
        id: id,
        name: text(row['name']) ?? '',
        hardwareId: text(row['hw_id']),
        isOnline: online is bool ? online : null,
        lastSeen: seen == null ? null : DateTime.tryParse(seen.toString()),
        wifiRssi: health.rssi,
        wifiSsid: text(row['wifi_ssid']),
        uptimeSeconds: health.uptimeSeconds);
  }
}
