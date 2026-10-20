/// 서버가 기기 ACK로 확정한 LCD 문구 (`devices.lcd_text`·`lcd_text_updated_at`,
/// terra-server 회신 `BACKEND_HANDOFF_REPLY_LCD_TEXT_2026-10-07.md`).
///
/// - [updatedAt]이 있으면 서버가 확인한 값이다. 이때 [text]가 null이면 기기가
///   기본 문구를 띄우고 있다는 뜻(지우기 ACK).
/// - [updatedAt]이 null이면 서버가 모른다 — 기능 배포 전에 바꿨거나 아직 한 번도
///   안 바꿨다.
class DeviceLcdText {
  const DeviceLcdText({required this.text, required this.updatedAt});

  static const unknown = DeviceLcdText(text: null, updatedAt: null);

  final String? text;
  final DateTime? updatedAt;

  bool get confirmed => updatedAt != null;

  factory DeviceLcdText.fromJson(Map<String, dynamic> j) {
    final raw = j['lcd_text'];
    final at = j['lcd_text_updated_at'];
    return DeviceLcdText(
      text: raw is String && raw.isNotEmpty ? raw : null,
      updatedAt: at == null ? null : DateTime.tryParse(at.toString()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceLcdText &&
      other.text == text &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(text, updatedAt);
}

/// 이 폰이 방금 보낸 문구 — 기기 ACK(보통 1~2초)가 서버 값으로 돌아오기 전까지
/// 화면에 먼저 보인다.
///
/// [baseline]은 보낼 때 알던 서버 확정 시각이다. 서버 값이 그 뒤로 바뀌면
/// (ACK) 서버 값을 쓴다 — 서버 시각과 폰 시각을 비교하지 않는다(폰 시계가
/// 어긋날 수 있다). [sentAt]은 폰 시계끼리만 비교한다.
class PendingLcdText {
  const PendingLcdText(this.text,
      {required this.sentAt, required this.baseline});

  final String text;
  final DateTime sentAt;
  final DateTime? baseline;
}

/// 서버 명령 TTL(30초). 이 안에 ACK가 안 오면 기기에 안 간 것으로 보고
/// 서버 값으로 돌아간다 — 안 그러면 "LCD와 앱 문구가 다르다"가 다시 생긴다.
const kLcdPendingWindow = Duration(seconds: 30);

/// 홈 "LCD 표시" 줄·LCD 입력칸에 보일 문구. null이면 아는 문구가 없다(호출측이
/// 기기 ID로 채운다).
///
/// 우선순위(2026-10-07): ① 방금 보낸 문구(서버 값이 아직 그대로이고 30초 안)
/// ② 서버 확정값(확정된 기본 문구=null이면 휴대폰 저장값을 쓰지 않는다)
/// ③ 휴대폰 저장값(서버 기능 배포 전 이력).
String? resolveLcdText({
  required DeviceLcdText server,
  required PendingLcdText? pending,
  required String? phone,
  required DateTime now,
}) {
  if (pending != null &&
      now.difference(pending.sentAt) < kLcdPendingWindow &&
      server.updatedAt == pending.baseline) {
    return pending.text;
  }
  if (server.confirmed) return server.text;
  return phone;
}
