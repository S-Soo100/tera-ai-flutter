/// 발행 후 이 시간 안에 ACK가 안 오면 "기기에 닿지 않은 명령"으로 본다.
///
/// mist 블랙아웃(2026-09-07 핸드오프)으로 유실된 명령은 서버에 **영영
/// `sent`로 남는다** — `pending`→`expired` TTL은 있어도 `sent`에는 만료가
/// 없다(실DB 3건 실증). 정상 ACK는 1~3초에 온다. 서버가 `sent` 만료를
/// 구현하면(핸드오프 §2) 이 휴리스틱은 서버 상태 기반으로 교체한다.
const kCommandAckGrace = Duration(seconds: 15);

/// PRD §4.2.1 진행 중 타이머 칩의 데이터 모델.
///
/// 서버에 타이머 상태 테이블은 **없다**(A안 확정, 2026-08-14 핸드오프 §1.3).
/// `fan_on` + `duration_ms`를 보내면 펌웨어가 스스로 끄고, 진행 중 여부는
/// `commands` 이력에서 `issued_at + duration_ms`로 계산한다 — 그래서
/// 다기기에서도 같은 값이 나온다. 배선은 [fanTimerFrom].
class RunningTimer {
  final String id;
  final String deviceId;

  /// 액추에이터 i18n 키. 기존 `module_actuator_*` 키를 그대로 쓴다.
  final String actuatorLabelKey;

  /// 사용자가 건 타이머 길이(분). 칩 문구 `팬 30분 타이머 가동 중`의 30.
  final int durationMinutes;

  final DateTime endsAt;

  const RunningTimer({
    required this.id,
    required this.deviceId,
    required this.actuatorLabelKey,
    required this.durationMinutes,
    required this.endsAt,
  });

  /// 남은 시간. 만료됐으면 [Duration.zero] — 음수 카운트다운을 막는다.
  Duration remaining(DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool isActive(DateTime now) => remaining(now) > Duration.zero;

  /// `commands` 이력 → 진행 중 팬 타이머 (A안: `issued_at + duration_ms`).
  ///
  /// [rows]는 fan 계열(`fan_on`/`fan_off`/`fan_toggle`) 명령을 **`issued_at`
  /// 내림차순**으로 담는다. 최신 유효 명령이 duration 붙은 `fan_on`이고 아직 안
  /// 끝났을 때만 타이머다 — 그 뒤에 off/toggle이 왔으면 취소된 것이고,
  /// `rejected`/`expired`는 기기에 닿지 않았으니 없는 셈 친다.
  ///
  /// `pending`/`sent`는 [kCommandAckGrace] **안에서만** 타이머로 본다 —
  /// 발행 직후 칩이 바로 떠야 사용자가 "걸렸다"를 확인하지만, 유예를 넘긴
  /// 미ACK는 mist 블랙아웃으로 유실돼 영영 `sent`로 남은 명령이다(2026-09-07).
  /// 그걸 계속 타이머로 치면 **실제로는 안 도는 팬**을 카운트다운한다.
  /// 유예 초과 미ACK는 fan_off여도 없는 셈 친다(대칭) — 유실된 off가 이전의
  /// 정상 타이머를 가짜로 취소하는 것도 막는다.
  static RunningTimer? fanTimerFrom(
    List<Map<String, dynamic>> rows,
    DateTime now,
  ) {
    for (final r in rows) {
      final status = r['status'] as String?;
      if (status == 'rejected' || status == 'expired') continue;
      final issuedAtRaw = DateTime.tryParse('${r['issued_at']}')?.toLocal();
      if (status != 'acked' &&
          issuedAtRaw != null &&
          now.difference(issuedAtRaw) > kCommandAckGrace) {
        continue; // 미ACK 유예 초과 — 기기에 닿지 못한 명령.
      }
      if (r['action'] != 'fan_on') return null;
      final payload = r['payload'];
      final ms = payload is Map ? (payload['duration_ms'] as num?) : null;
      if (ms == null) return null;
      final issuedAt = issuedAtRaw;
      if (issuedAt == null) return null;
      final t = RunningTimer(
        id: '${r['id']}',
        deviceId: '${r['device_id']}',
        actuatorLabelKey: 'module_actuator_fan',
        durationMinutes: ms.toInt() ~/ 60000,
        endsAt: issuedAt.add(Duration(milliseconds: ms.toInt())),
      );
      return t.isActive(now) ? t : null;
    }
    return null;
  }
}

/// `18분 20초` / `7초` / `1시간 5분 3초` 형식. PRD 목업 문구를 따른다.
String formatRemaining(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h시간 $m분 $s초';
  if (m > 0) return '$m분 $s초';
  return '$s초';
}
