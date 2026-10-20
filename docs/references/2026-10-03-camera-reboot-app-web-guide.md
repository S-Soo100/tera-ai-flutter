# 카메라 원격 재부팅 — 앱 · 웹 사용 가이드

> **대상**: 앱(Flutter, vivanaut) 개발 · 웹 콘솔 운영
> **작성**: terra-server 백엔드, 2026-10-03
> **기준 코드**: terra-server `main` (`236e5eb`) — 서버 변경 없이 현재 API 그대로 사용
> **정본**: `docs/API.md` §4.8 · `docs/APP_CAMERA_REBOOT_HEALTH_2026-09-28.md`

---

## 0. 한눈에

| 항목 | 내용 |
|---|---|
| API | `POST https://api.terra-server.uk/cameras/{camera_uuid}/reboot` |
| 인증 | `Authorization: Bearer <Supabase access_token>` |
| 본문 | 없음 |
| 동작 | 서버가 MQTT `esp32/{camera_id}/command` 로 `reboot` 명령 **1회** 발행 (TTL 60초) |
| 카메라 | 신 펌웨어(≥ 0.2.0): ack → **1.5초 뒤 재부팅** → 약 12초 후 MQTT 복귀 → 첫 하트비트까지 최대 약 27초 |
| 완료 판정 | `cameras` 행의 `clip_stats.sys.reset == "SW:mqtt_reboot"` 이고 `uptime_s` 가 작아짐 |
| 쓰는 상황 | 하트비트는 살아 있는데(온라인) 녹화·업로드·라이브가 멈춘 카메라 |

> `camera_uuid` 는 `cameras.id`(UUID) 입니다. `camera_id`(`p4cam-xxxxxxxx` 같은 문자열)가 아닙니다.

---

## 1. API 계약

```
POST /cameras/{camera_uuid}/reboot
Authorization: Bearer <JWT>

200 { "published": true,  "msg_id": "8f1c…" }   → 명령 발행됨
200 { "published": false, "msg_id": null }      → 브로커 순간 장애. 잠시 후 재시도
401                                             → 토큰 없음/만료
404 { "detail": "camera not found" }            → 타인 카메라 · 등록 해제된 카메라 · 없는 UUID
```

### 꼭 알아둘 점 (서버가 해주지 않는 것)

| 서버가 하지 않는 것 | 그래서 클라이언트가 할 일 |
|---|---|
| **온라인 여부를 확인하지 않음** — 오프라인 카메라에도 발행하고 `published: true` 를 돌려줌. 명령은 60초 뒤 그냥 사라짐 | `is_online == true` 일 때만 버튼 활성화 |
| **펌웨어 버전을 확인하지 않음** — 구 펌웨어(0.1.0)는 명령을 거부하고 아무 일도 안 일어남 | 신 펌웨어(§3)일 때만 버튼 노출 |
| **연타 방지 없음** — 누를 때마다 발행됨 | 발행 성공 후 **60초 비활성**(+ 재부팅 완료 감지 시 즉시 해제) |
| **ack 결과를 DB 에 남기지 않음** — 카메라 명령은 `commands` 테이블을 거치지 않음 | 앱은 ack 를 받을 수 없음. 완료는 하트비트(§4)로 판정 |

`published: true` 는 **"브로커에 올라갔다"** 는 뜻이지 **"카메라가 받았다"** 는 뜻이 아닙니다.

---

## 2. 사용자 체험 흐름 (권장 UX)

```
[화면]  카메라 상세 — 온라인, "카메라 재시작" 버튼
[조작]  버튼 탭
[반응]  확인 다이얼로그
        "카메라가 약 30초 동안 꺼졌다 켜집니다. 라이브 보기와 녹화가 잠시 중단됩니다."
        [취소] [재시작]
[조작]  [재시작]
[반응]  버튼 → "재시작 중…" (비활성, 스피너)
        · 라이브 시청 중이었다면 WebRTC 끊김 → 라이브 화면 닫거나 "재연결" 안내
[대기]  약 12~27초
[반응]  Realtime 으로 reset=SW:mqtt_reboot 하트비트 도착 → 토스트 "카메라가 다시 켜졌어요"
        버튼 원상복귀
[예외]  60초 지나도 완료 신호 없음 → "재시작 확인이 늦어지고 있어요. 잠시 후 상태를 확인해 주세요."
        (버튼은 다시 활성화)
[예외]  published=false → "잠시 후 다시 시도해 주세요" (버튼 즉시 활성화)
```

### 버튼 상태 규칙

| 조건 | 버튼 |
|---|---|
| `is_online == false` | 숨김 또는 비활성 ("카메라가 오프라인이에요") |
| 구 펌웨어 (`firmware_ver` null 또는 < 0.2.0) | 숨김 |
| 발행 성공 후 ~ 완료 감지 또는 60초 | 비활성 "재시작 중…" |
| 그 외 | 활성 |

---

## 3. 신 펌웨어 판별

`cameras.firmware_ver` 형식: `"fb2-p4 <major>.<minor>.<patch>[-<build>]"`

| 값 | 판정 |
|---|---|
| `null` / `"fb2-p4 0.1.0"` | 구 펌웨어 → 재부팅 미지원 |
| `"fb2-p4 0.2.0-20260928"` 이후 | 신 펌웨어 → 지원 |

문자열 비교 말고 **버전 파싱**으로 `>= 0.2.0` 판정:

```dart
bool supportsReboot(String? fw) {
  if (fw == null) return false;
  final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(fw);
  if (m == null) return false;
  final v = [1, 2, 3].map((i) => int.parse(m.group(i)!)).toList();
  if (v[0] != 0) return v[0] > 0;
  return v[1] >= 2; // 0.2.0+
}
```

```js
function supportsReboot(fw) {
  const m = /(\d+)\.(\d+)\.(\d+)/.exec(fw || '');
  if (!m) return false;
  const [maj, min] = [+m[1], +m[2]];
  return maj > 0 || min >= 2;
}
```

---

## 4. 재부팅 완료 판정

카메라는 15초마다 하트비트를 보내고 서버가 `cameras.clip_stats` 를 UPDATE 합니다. 재부팅 후 첫 하트비트에서:

- `clip_stats.sys.reset == "SW:mqtt_reboot"`
- `clip_stats.sys.uptime_s` 가 버튼 누르기 전 값보다 작음 (보통 수십 초)

둘 다 만족하면 완료. **`reset` 만 보면 안 됩니다** — 이전에 재부팅한 적이 있으면 이미 `SW:mqtt_reboot` 일 수 있으니 반드시 `uptime_s` 감소와 같이 봅니다.

정상 재부팅은 3분 안에 하트비트가 돌아오므로 `is_online` 은 보통 `false` 로 뒤집히지 않습니다(오프라인 임계 180초).

---

## 5. 앱 (Flutter) 구현 예시

### 5.1 API 호출

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum RebootResult { published, brokerFailed, notFound, unauthorized, error }

Future<RebootResult> rebootCamera(String cameraUuid) async {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null) return RebootResult.unauthorized;

  final res = await http.post(
    Uri.parse('https://api.terra-server.uk/cameras/$cameraUuid/reboot'),
    headers: {'Authorization': 'Bearer $token'},
  );

  switch (res.statusCode) {
    case 200:
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['published'] == true
          ? RebootResult.published
          : RebootResult.brokerFailed;
    case 401:
      return RebootResult.unauthorized;
    case 404:
      return RebootResult.notFound;
    default:
      return RebootResult.error;
  }
}
```

### 5.2 완료 감지 (Realtime)

```dart
// 버튼 누르기 직전 uptime 을 기억해 둔다.
final int? uptimeBefore = (camera['clip_stats']?['sys']?['uptime_s'] as num?)?.toInt();

final channel = Supabase.instance.client
    .channel('camera-reboot-$cameraUuid')
    .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'cameras',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: cameraUuid,
      ),
      callback: (payload) {
        final sys = payload.newRecord['clip_stats']?['sys'];
        final reset = sys?['reset'];
        final uptime = (sys?['uptime_s'] as num?)?.toInt();
        final restarted = reset == 'SW:mqtt_reboot' &&
            uptime != null &&
            (uptimeBefore == null || uptime < uptimeBefore);
        if (restarted) {
          // 토스트 "카메라가 다시 켜졌어요" + 버튼 복귀 + 채널 해제
        }
      },
    )
    .subscribe();

// 60초 타임아웃: 완료 신호가 없으면 안내 후 버튼 복귀 + channel 해제.
```

> 이미 카메라 목록/상세용 `cameras` Realtime 구독이 있으면 채널을 새로 열지 말고 그 콜백에서 같은 판정만 추가하면 됩니다.

### 5.3 결과별 문구

| 결과 | 문구 | 버튼 |
|---|---|---|
| `published` | "카메라를 재시작하고 있어요" | 60초 비활성 / 완료 감지 시 복귀 |
| `brokerFailed` | "잠시 후 다시 시도해 주세요" | 즉시 활성 |
| `notFound` | "카메라를 찾을 수 없어요" → 목록 새로고침 | — |
| `unauthorized` | 재로그인 흐름 | — |
| `error` / 네트워크 예외 | "일시적인 오류예요. 잠시 후 다시 시도해 주세요" | 즉시 활성 |

---

## 6. 웹 콘솔 사용법

이미 구현돼 있습니다. **`https://api.terra-server.uk/`** → 로그인 → **카메라** 목록.

### 6.1 버튼 쓰기

1. 카메라 행 오른쪽 **재부팅** 버튼 클릭
2. 확인창 "`<camera_id>` 재부팅? 약 30초간 꺼졌다 켜짐…" → 확인
3. 토스트
   - 초록 `reboot 발행 · msg_id <uuid>` → 발행됨
   - 빨강 `reboot 발행 실패(브로커) — 잠시 후 재시도`
4. 약 30초 뒤 목록 새로고침 → 온라인 칸 상태줄이 `up 0m · reset SW:mqtt_reboot · …` 처럼 바뀌면 완료

> 콘솔 버튼은 온라인/펌웨어 여부와 상관없이 항상 보입니다(운영용). 누르기 전에 행의 **온라인** 상태와 펌웨어를 직접 확인하세요.

### 6.2 상태줄 읽는 법

온라인 칸 아래 `up <가동시간> · reset <사유> · heap <K> · int <K>/<K> · rssi`:

| reset 값 | 뜻 | 표시 |
|---|---|---|
| `SW:mqtt_reboot` | 앱/콘솔 원격 재부팅 | 회색(정상) |
| `POWERON` | 전원 투입 | 회색 |
| `SW:rotate` / `SW:ble_reprov` / `SW:http_restart` | 회전 적용 / BLE 재설정 / HTTP 재시작 | 회색 |
| `SW:net_wd` / `SW:boot_net_wd` | WiFi 단절 자가 재부팅 | 빨강 |
| `SW:upload_stuck` | 업로드 15분 정체 자가 재부팅 | 빨강 |
| `SW:rtc_loop_stall` | 라이브(WebRTC) 루프 정지 워치독 | 빨강 |
| `BROWNOUT` | 전원 부족 (어댑터/케이블 의심) | 빨강 |
| `PANIC` / `*WDT` | 크래시 | 빨강 |

재부팅 직전 에러는 카메라 상세의 **에러 로그**(`camera_logs`)에서 `[이전 부팅]` 표시 줄로 볼 수 있습니다.

### 6.3 서버 로그로 도착 확인 (운영자)

발행은 `terra-api`, ack 는 `terra-bridge` 에 남으므로 두 유닛을 같이 봅니다. 토스트의 `msg_id` 로 grep:

```bash
journalctl -u terra-api -u terra-bridge --since "10 min ago" | grep <msg_id>
```

| 로그 | 의미 |
|---|---|
| `reboot 발행 camera=… msg_id=…` 만 있음 | 카메라가 못 받음 (오프라인 · TTL 만료) |
| `camera ack … result=ok` | 신 펌웨어 수신 → 1.5초 뒤 재부팅 |
| `camera ack … result=rejected_unknown_action` | 구 펌웨어 → 재부팅 안 됨, 리플래시 필요 |
| `reboot 발행 실패 camera=…` | 브로커 장애 (`published: false`) |

---

## 7. 테스트 체크리스트

| # | 시나리오 | 기대 결과 |
|:---:|---|---|
| 1 | 온라인 + 신 펌웨어 카메라에서 재시작 | 200 published → 30초 안에 완료 토스트 |
| 2 | 구 펌웨어 카메라 | 앱: 버튼 숨김 / 콘솔: 발행되지만 ack `rejected_unknown_action`, 재부팅 없음 |
| 3 | 오프라인 카메라 | 앱: 버튼 비활성 / 콘솔: `published: true` 지만 아무 일 없음 |
| 4 | 다른 계정 카메라 UUID 로 호출 | 404 |
| 5 | 연타 | 앱: 첫 탭 후 비활성. (서버는 막지 않음) |
| 6 | 라이브 시청 중 재시작 | WebRTC 끊김 → 재부팅 후 라이브 다시 열면 정상 |
| 7 | 60초 내 완료 신호 없음 | 지연 안내 후 버튼 복귀 |

테스트용 신 펌웨어 카메라: **p4cam-0d1b47b4** (9/28 실기 검증 완료).

---

## 8. 참고 — IoT 기기(사육장 컨트롤러) 재부팅과 차이

| | 카메라 | IoT 기기 |
|---|---|---|
| API | `POST /cameras/{id}/reboot` | `POST /devices/{id}/reboot` |
| 응답 | 200 `{published, msg_id}` | 201 `{id, action:"reboot", status:"pending"}` |
| 경로 | 즉시 MQTT 발행 | `commands` 테이블 큐잉 → dispatcher |
| ack 확인 | 불가 (하트비트로 판정) | `commands` Realtime 으로 `acked` / `no_ack` 확인 가능 |
| 재부팅 후 | — | 서버가 예약 상태(조명 등) 자동 복원 |

두 버튼을 같은 화면에 둘 경우 완료 판정 방식이 다르니 섞지 마세요.
