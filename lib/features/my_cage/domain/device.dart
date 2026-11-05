import '../../../shared/domain/num_format.dart';
import '../../home/domain/auto_env.dart';
import 'lcd_screen_state.dart';
import 'lcd_text.dart';

/// Supabase `devices` row 매핑.
class Device {
  final String id;
  final String? ownerId;
  final String? enclosureId;
  final String? name;
  final String? hardwareId;
  final bool isOnline;
  final DateTime? lastSeenAt;

  /// 보드 능력 (`devices.capabilities` JSONB, 2026-08-18 백엔드 회신 §2).
  /// 예: `{"board":"mosfet","led_dimmable":true}`. 구 행은 서버가
  /// `{"board":"relay","led_dimmable":false}`로 백필했고, null이면 아직 아무도
  /// 안 채운 것 — 모르는 능력은 **없는 것으로** 본다.
  final Map<String, dynamic>? capabilities;

  /// 기기가 ACK로 확정한 LCD 문구(`devices.lcd_text`·`lcd_text_updated_at`,
  /// 2026-10-07 서버 회신).
  final DeviceLcdText lcd;

  /// 모듈 화면 설정(전원·꺼짐 예약·보호기·사진, `devices.lcd_*`, 2026-11-03).
  final DeviceLcdScreen lcdScreen;

  /// 기기가 **지금 적용 중인** 온도 보정값(`devices.temp_offset_c`, ℃).
  /// 기기가 보내는 `t_a`는 이미 보정된 값이고 원래 측정값 = `t_a − 이 값`
  /// (서버 `handlers.py`, `docs/MQTT.md`). 펌웨어 빌드 기본은 −1.5℃.
  ///
  /// null = 모름(구 펌웨어·미보고). 숫자가 아니거나 기기 명령 허용 범위
  /// ±10.0(서버 `TEMP_OFFSET_LIMIT_C`) 밖이면 믿을 수 없는 값이라 null로 둔다.
  /// 이 값은 `deviceListProvider` 1회 조회에서 온다 — 저장 후 갱신은 보정
  /// 화면이 맡는다.
  final double? tempOffsetC;

  /// 서버 자동 환경 제어의 지금 상태(`devices.auto_env_state`, 계약 C3).
  /// 목록 스냅샷 값이고, 실시간 값은 [DeviceLinkStatus.autoEnv]로 온다.
  final AutoEnvState autoEnv;

  /// 기기 명령 `set_temp_offset` 허용 범위(서버 `TEMP_OFFSET_LIMIT_C`).
  static const double tempOffsetLimitC = 10.0;

  const Device({
    required this.id,
    required this.ownerId,
    required this.enclosureId,
    required this.name,
    required this.isOnline,
    required this.lastSeenAt,
    this.hardwareId,
    this.capabilities,
    this.lcd = DeviceLcdText.unknown,
    this.lcdScreen = DeviceLcdScreen.unknown,
    this.tempOffsetC,
    this.autoEnv = AutoEnvState.none,
  });

  /// 모듈 화면 설정 지원 단계(기획 §12-4).
  LcdSupport get lcdSupport => LcdSupport.fromCapabilities(capabilities);

  /// 신 nano 펌웨어 — 수동 전원 조작이 다음 예약 경계까지만(기획 §12-1).
  bool get lcdOverride => lcdOverrideFromCapabilities(capabilities);

  /// LED 밝기(PWM) 조절이 되는 보드인가. 릴레이 보드는 `brightness`를 무시하고
  /// 켜기만 하므로 이 값이 true일 때만 밝기 UI를 보여준다.
  ///
  /// ⚠️ 펌웨어가 아직 capabilities를 보고하지 않아(회신 §2) 실제 MOSFET 보드도
  /// 당분간 false로 온다 — 운영자가 DB에서 갱신하거나 펌웨어 보고가 붙으면
  /// 자동으로 맞는다. 앱은 이 분기만 갖고 기다린다.
  bool get ledDimmable => capabilities?['led_dimmable'] == true;

  /// `relay` / `mosfet` / null(미보고).
  String? get boardType => capabilities?['board'] as String?;

  /// `temp_offset_c` 원문 → ℃. 숫자 아님·±10 밖은 null(구 펌웨어와 같게 본다).
  static double? parseTempOffset(Object? raw) {
    final v = parseDouble(raw);
    if (v == null || !v.isFinite) return null;
    return v.abs() > tempOffsetLimitC ? null : v;
  }

  factory Device.fromJson(Map<String, dynamic> j) {
    final caps = j['capabilities'];
    return Device(
      id: j['id'] as String? ?? '',
      ownerId: j['owner_id'] as String?,
      enclosureId: j['enclosure_id'] as String?,
      name: j['name'] as String?,
      hardwareId: j['device_id'] as String?,
      isOnline: j['is_online'] as bool? ?? false,
      lastSeenAt: j['last_seen_at'] != null
          ? DateTime.tryParse(j['last_seen_at'].toString())
          : null,
      capabilities: caps is Map ? caps.cast<String, dynamic>() : null,
      lcd: DeviceLcdText.fromJson(j),
      lcdScreen: DeviceLcdScreen.fromJson(j),
      tempOffsetC: parseTempOffset(j['temp_offset_c']),
      autoEnv: AutoEnvState.fromJson(j['auto_env_state']),
    );
  }
}

/// 기기 연결 상태만 — `devices` 실시간 UPDATE와 목록 스냅샷 공용(2026-09-25).
///
/// 같은 행 UPDATE에 실려 오는 LCD 문구([lcd])도 함께 나른다(2026-10-07) —
/// 기기마다 채널을 하나 더 열지 않으려고. 연결 판정 소비처는 `isOnline`만
/// select하므로 LCD 변화로 다시 그려지지 않는다.
///
/// 모듈 화면 설정([lcdScreen])과 LCD 능력([lcdSupport]·[lcdOverride])도 같은
/// 길로 온다(2026-11-03) — OTA 뒤 `capabilities.lcd_saver`가 켜지면 열린 화면도
/// 바로 활성화된다(기획 §11-1). capabilities는 LCD 판정에 쓰는 값만 담는다 —
/// 전체 맵을 담으면 무관한 능력 변화까지 `==`가 달라진다.
///
/// 서버 자동 환경 제어 상태([autoEnv], `devices.auto_env_state`)도 같은 길로
/// 온다(2026-11-05) — 서버는 바뀔 때만 갱신하지만 이 객체는 생존 신호 행에도
/// 다시 만들어지므로 [AutoEnvState]는 값으로 비교한다.
class DeviceLinkStatus {
  const DeviceLinkStatus({
    required this.isOnline,
    required this.lastSeenAt,
    this.lcd = DeviceLcdText.unknown,
    this.lcdScreen = DeviceLcdScreen.unknown,
    this.lcdSupport = LcdSupport.needsUpdate,
    this.lcdOverride = false,
    this.autoEnv = AutoEnvState.none,
  });

  final bool isOnline;
  final DateTime? lastSeenAt;
  final DeviceLcdText lcd;
  final DeviceLcdScreen lcdScreen;
  final LcdSupport lcdSupport;
  final bool lcdOverride;
  final AutoEnvState autoEnv;

  factory DeviceLinkStatus.of(Device d) => DeviceLinkStatus(
      isOnline: d.isOnline,
      lastSeenAt: d.lastSeenAt,
      lcd: d.lcd,
      lcdScreen: d.lcdScreen,
      lcdSupport: d.lcdSupport,
      lcdOverride: d.lcdOverride,
      autoEnv: d.autoEnv);

  factory DeviceLinkStatus.fromJson(Map<String, dynamic> j) {
    final caps = _capabilitiesOf(j['capabilities']);
    return DeviceLinkStatus(
      isOnline: j['is_online'] as bool? ?? false,
      lastSeenAt: j['last_seen_at'] != null
          ? DateTime.tryParse(j['last_seen_at'].toString())
          : null,
      lcd: DeviceLcdText.fromJson(j),
      lcdScreen: DeviceLcdScreen.fromJson(j),
      lcdSupport: LcdSupport.fromCapabilities(caps),
      lcdOverride: lcdOverrideFromCapabilities(caps),
      autoEnv: AutoEnvState.fromJson(j['auto_env_state']),
    );
  }

  static Map<String, dynamic>? _capabilitiesOf(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : null;

  @override
  bool operator ==(Object other) =>
      other is DeviceLinkStatus &&
      other.isOnline == isOnline &&
      other.lastSeenAt == lastSeenAt &&
      other.lcd == lcd &&
      other.lcdScreen == lcdScreen &&
      other.lcdSupport == lcdSupport &&
      other.lcdOverride == lcdOverride &&
      other.autoEnv == autoEnv;

  @override
  int get hashCode => Object.hash(
      isOnline, lastSeenAt, lcd, lcdScreen, lcdSupport, lcdOverride, autoEnv);
}
