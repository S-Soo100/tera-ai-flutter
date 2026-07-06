# 크레캠 세부캠 — 비디오 기록 / 온습도 수정 기획서

> 작성일: 2026-07-06 · 대상 화면: `/crecam/cameras/:cameraId` (CameraDetailScreen)
> 조사 방법: 코드 정적 분석 + Supabase 실 DB 조회(leegawnhun 앱 계정 기준) + terra-server `APP_INTEGRATION.md` 계약 대조
> 상태: **진단 완료 / 구현 전** — 아래 "결정 필요사항"에 대한 사용자 승인 후 착수

---

## 0. 세 줄 요약

1. **비디오 기록이 "없음"으로 뜨는 건 실제로 영상이 없어서가 아니다.** 앱은 `camera_clips`(옛 petcam-lab PoC 테이블, 앱 계정 **0건**)를 보는데, 실제 카메라 영상은 terra-server의 `motion_clips` 테이블에 **2,557건**(지금도 실시간 축적, 최신 2026-07-06 00:49)이 쌓여 있다. **테이블을 잘못 보고 있는 문제**다. 분류/라벨 필터 문제가 아니다(앱엔 분류 필터가 아예 없음).
2. **온습도는 placeholder가 아니라 실데이터**(telemetry 실측값, realtime 구독)다. 다만 **이 카메라가 속한 사육장과 매칭되어 있지 않다.** 카메라와 무관하게 "첫 번째/전역 선택 디바이스"의 값을 보여준다.
3. 두 문제의 **공통 뿌리는 `enclosure`(사육장) 미배선**이다. 앱 계정의 카메라 2개·디바이스 2개가 전부 `enclosure_id = null`이라 "이 카메라 = 이 사육장 = 이 온습도 = 이 영상"으로 묶을 키가 없다.

## 결정 (2026-07-06 사용자 승인)

- **비디오 기록 → 방안 B(정공법)**: enclosure 배선 후 `GET /enclosures/{id}/clips`로 전환.
- **온습도 → 그대로 둠**: 임시 조치(숨김/라벨) 없이, 정공법 단계에서 enclosure 매칭으로 **한 번에** 해결.
- ⇒ 두 문제 모두 **enclosure 배선 = "사육장 개념의 앱 신규 도입"이 선결 1단계**. CAOF **Critical** 트랙.
- 근거 보강: 페어링(`/devices/pair`·`/cameras/pair`)은 `owner_id`만 세팅하고 `enclosure_id`는 **안 채운다**(현 데이터 4개 전부 null이 증거). RLS가 "본인 것 수정 가능"이라 **앱에서 배정 가능**.

---

## 1. 조사로 확정한 사실 (leegawnhun@gmail.com = `e2d0a451…` 앱 계정)

### 1.1 계정 리소스 현황 (실 DB)

| 리소스 | 개수 | 상세 | `enclosure_id` |
|--------|------|------|----------------|
| cameras | 2 | `5b3ea7aa…` P4 Cam(dev) `p4cam-79b5d844` · `f6599924…` P4 Cam 2 `p4cam-27b1f486` | **둘 다 null** |
| devices | 2 | `68eb9410…` test_device `terra-7856e64e` · `c61b2066…` test_device_02 `terra-cb52aabf` | **둘 다 null** |
| enclosures | 1 | `c78e805d…` "테스트" | (아무 카메라/디바이스도 이 사육장을 참조 안 함) |
| **camera_clips** (앱이 조회) | **0** | 앱 계정 소유 클립 0건. (215건 전부 bss.rol20 계정 소유 — PoC 라벨링 데이터) | — |
| **motion_clips** (실제 영상) | **2,557** | `5b3ea7aa`=1,817건 · `f6599924`=740건. 최신 2026-07-06 00:49. R2 저장(`terra-clips/clips/…mp4`) | — |
| telemetry | 80,785 | test_device=**0건** · test_device_02=최신 2026-07-05 23:35 **27.7℃ / 63.5%** (a_ok=true) | — |

### 1.2 두 클립 테이블은 다른 파이프라인

| | `camera_clips` (앱 현재 조회) | `motion_clips` (실제 카메라 영상) |
|---|---|---|
| 출처 | petcam-lab VLM 행동분석 **PoC** | terra-server ESP32-P4 카메라 **운영** |
| 소유 컬럼 | `user_id` | `owner_id` |
| 파일 참조 | `file_path` (TEXT) | `r2_key` / `thumbnail_key` (R2 object key) |
| 모션 | `has_motion`(bool) + `behavior_logs` 분류 | `motion_score`(float), 전부 모션 이벤트 |
| 앱 계정 데이터 | **0건** | **2,557건** |
| 재생 API | `GET {petcamBackend}/clips/{id}/file/url` | `GET {terraApi}/clips/{id}/url` |

> 메모리 `project_crecam_realdata_wiring`의 "leegawnhun 카메라 실데이터 0건→백엔드 대기"는 **camera_clips 기준으로는 맞지만 낡았다.** 그 사이 실제 영상은 `motion_clips`로 들어오고 있었고, 앱만 옛 테이블을 계속 보고 있었다.

---

## 2. 질문 1 — "비디오 기록에 녹화 영상이 없다"

### 2.1 사용자 질문에 대한 직접 답
- **실제로 없는가?** → 아니다. **2,557건 존재**(실시간 축적 중). 단, `motion_clips` 테이블에.
- **분류를 안 한 영상이 안 나오는가?** → 아니다. 앱 조회 쿼리에 **분류/라벨/behavior 필터가 전혀 없다**. `camera_id` 하나로만 조회하고 시간 역순 전체를 나열한다.
- **진짜 원인** → 앱이 **잘못된 테이블**을 조회한다. `camera_clips`(앱 계정 0건)를 보므로 항상 empty.

### 2.2 코드 경로 (근거)
```
_VideoLogSection (camera_detail_screen.dart:537-648)
  └ ref.watch(_cameraClipsProvider(cameraId))       // :545
      └ _cameraClipsProvider (camera_detail_screen.dart:35-40)
          └ ClipRepository.listPage(cameraId, limit:50)
              └ _supabase.from('camera_clips')...    // clip_repository.dart:45  ← 잘못된 테이블
  clips.isEmpty → _buildEmptyAction()                // :568 → "camera_detail_clips_empty".tr()
```
재생 경로(참고):
```
ClipCard.onTap → /crecam/clips/{id} → ClipPlayerScreen
  └ ClipRepository.getFileUrl(id)                     // clip_repository.dart:232
      └ GET {backendUrl}/clips/{id}/file/url (presigned)   ← petcam-lab 계약
  └ video_cache_repository.downloadAndCache → VideoPlayerController.file  // clip_player_screen.dart:57-70
```

### 2.3 terra-server가 제공하는 대체 계약 (`APP_INTEGRATION.md`)
- `GET /enclosures/{id}/clips` (JWT) — 사육장의 모션 클립 목록 (line 81)
- `GET /clips/{id}/url` (JWT) — 재생용 R2 presigned URL, TTL 1h (line 80, 494)
- Realtime: `motion_clips` INSERT를 WebSocket push (line 20, 377-392)
- RLS: `motion_clips`는 "본인 cameras의 클립만 SELECT" (line 552) → **camera_id 직결 조회도 RLS로 안전**

### 2.4 수정 방안 (택1 — 결정 필요)

**방안 A — Supabase 직결(camera_id)로 motion_clips 조회 + terra-api 재생** ✅ 권장
- 조회: `ClipRepository`(또는 신규 `MotionClipRepository`)가 `motion_clips`를 `camera_id`로 직결 조회(RLS가 본인 것만 허용). enclosure 배선 불필요.
- 재생: presigned는 R2 credential이 앱에 없으므로 **terra-api `GET /clips/{id}/url` 필요**. 앱의 현재 `_backendUrl`이 terra-api인지 petcam-lab인지 확인 후, terra-api 클라이언트 배선.
- 모델: `motion_clips` 스키마용 매핑(`r2_key`/`thumbnail_key`/`motion_score`) 추가. `Clip.fromJson`의 `file_path` 의존(clip.dart:48) 분기 처리.
- 장점: enclosure 배선 없이 **오늘 바로 실영상 표출 가능**. 단점: camera_clips 기반 부가기능(활동량·behavior 라벨)과 스키마가 갈림 → §4 참조.

**방안 B — enclosure 배선 후 `GET /enclosures/{id}/clips`로 정공법 전환**
- terra-server 설계(enclosure 중심)에 가장 충실. 단 §1처럼 카메라·디바이스 enclosure_id가 전부 null이라 **선결 배선(§4)이 필수** → 착수까지 리드타임.

**방안 C(임시) — 아무것도 안 고치고 empty 문구만 정직화**
- "아직 녹화 영상이 연동되지 않았습니다" 류로 문구만 교체. 근본 해결 아님. 비권장.

---

## 3. 질문 2 — "오른쪽 위 온습도가 실데이터인가 / 사육장과 매칭되나"

### 3.1 사용자 질문에 대한 직접 답
- **placeholder인가?** → 아니다. **실데이터**다. Supabase `telemetry`를 realtime 구독하고 실측값(`t_a`/`h_a`)을 표시한다.
- **사육장과 매칭되어 있나?** → **아니다.** 이 카메라가 속한 사육장이 아니라 **"첫 번째/전역 선택 디바이스"의 온습도**를 보여준다.
- **부수 위험**: 첫 번째 디바이스(test_device)는 telemetry가 **0건**이라, 그게 선택되면 뱃지가 `—° / —%`로 뜬다. test_device_02가 선택돼야 27.7℃/63.5%가 표시된다. 즉 값이 뜨든 안 뜨든 **카메라와의 인과관계가 없다.**

### 3.2 코드 경로 (근거)
```
_LiveEnvBadge (camera_detail_screen.dart:223-247)  // 라이브 영상 위 top:12,right:12 (:195-199)
  └ ref.watch(currentDeviceProvider)               // :228  ← 카메라 정보 안 씀
      └ currentDeviceProvider (supabase_module_providers.dart:35-45)
          └ deviceList.first (selectedDeviceId 없으면)  ← 카메라와 무관한 전역 디바이스
  └ ref.watch(telemetryStreamProvider(deviceId))   // :235
      └ latestTelemetry + realtime insert 구독 (supabase_module_control_repository.dart:73-83)
```
- `_LiveEnvBadge`는 `cameraId`를 **인자로 받지도 않는다**. camera→device 연결 로직 전무.
- 도메인엔 `TerraCamera.enclosureId` / `Device.enclosureId` 필드가 **이미 있다**(terra_camera.dart, device.dart) — 즉 매칭 설계 여지는 있으나 **DB 값이 null**이고 **연결 코드도 없다**.

### 3.3 수정 방안 (택1 — 결정 필요)

**방안 A — enclosure 기반 정합 매칭** ✅ 최종 지향
- `_LiveEnvBadge(cameraId)`로 카메라를 받아 → `camera.enclosureId` → 같은 enclosure의 device → 그 device의 telemetry.
- **선결**: §4 enclosure 배선. 배선 전엔 매칭 대상이 없어 동작 불가.

**방안 B — 배선 완료 전까지 뱃지 정직화**
- enclosure 매칭이 불가한 현재, 잘못된 값을 "이 사육장 온습도"처럼 보여주는 게 가장 나쁨. 배선 전까지는:
  - (b-1) 뱃지 숨김, 또는
  - (b-2) telemetry 있는 device가 유일하면 그 값 + "대표 사육장" 라벨 명시(카메라 소속이 아님을 표기).
- 방안 A의 안전한 징검다리.

**방안 C — camera↔device를 1:1 수동 지정**
- enclosure 없이 카메라별 device를 사용자가/설정으로 직접 지정. enclosure 설계와 중복되므로 비권장(A로 수렴).

---

## 4. 공통 선결과제 — `enclosure`(사육장) 배선

두 문제(정공법 기준) 모두 여기서 막힌다. terra-server는 **enclosure를 허브로** cameras·devices·motion_clips·telemetry를 묶는 설계인데(`APP_INTEGRATION.md` line 74-81, 515-518, 549-552), 앱 계정 실데이터는 전부 `enclosure_id = null`.

- **누가 enclosure_id를 채우나?** 현재 BLE 페어링은 (a)방식(앱은 WiFi만, 토큰/DB는 사전 세팅 — 메모리 `project_ble_provisioning_scheme`). enclosure 소속도 이 "사전 세팅" 범위인지, 앱에서 사육장을 만들고 카메라/디바이스를 배정하는 UI를 줄지 **미정**.
- terra-api엔 `POST /enclosures`(생성), `GET /enclosures`(목록)가 이미 있음(line 74-75). 앱에 "사육장 만들고 기기 배정" 플로우를 붙일 근거는 있음.

> 이 배선은 **별도 트랙(사육장 관리 UX)**으로 다룰 규모라, 본 기획서는 "질문 1·2를 지금 풀 수 있는 최소 경로"와 "정공법(enclosure)"을 분리해 제시한다.

---

## 5. 정공법 실행 로드맵 (방안 B 확정)

**전제**: 페어링은 enclosure를 안 채우므로 배정은 별도 단계. terra-api `POST /enclosures`(생성)·`GET /enclosures`(목록)가 있고, RLS가 본인 리소스 UPDATE를 허용하므로 **앱에서 사육장 생성 + 카메라/디바이스 배정 가능**. 앱은 현재 enclosure를 UI·Repository·Provider 어디서도 쓰지 않으므로(도메인 모델만 필드 파싱), 이 단계는 사실상 **신규 feature**.

| 단계 | 작업 | 트랙 | 핵심 산출물 |
|------|------|------|------------|
| **S1** | Enclosure 데이터 레이어 | Critical | `Enclosure` 도메인, `EnclosureRepository`(`GET/POST /enclosures` 또는 Supabase 직결 `from('enclosures')`), `enclosuresProvider` |
| **S2** | 사육장 관리 UX + 배정 | Critical | 사육장 생성 화면 + 카메라/디바이스를 사육장에 배정(`enclosure_id` UPDATE). 기존 카메라2·디바이스2를 사육장에 편입 |
| **S3** | 비디오 기록 전환 | Critical | `MotionClip` 모델/Repository(`GET /enclosures/{id}/clips`), `_VideoLogSection` 재배선, `ClipPlayerScreen` 재생을 terra-api `GET /clips/{id}/url`로 |
| **S4** | 온습도 정합 | Standard | `_LiveEnvBadge(cameraId)`로 카메라 수신 → `camera.enclosureId` → 같은 enclosure device → 그 device telemetry |
| **S5** | 검증 | — | leegawnhun 계정에서 세부캠 진입 시 **실영상 + 이 사육장 실온습도** 표출 확인 |

> S1·S2가 구조의 뼈대(사육장 개념 도입). S3·S4는 그 위에 카메라 상세를 정합. **S2의 "배정 방식"이 전체 UX를 좌우** → §8 하위 결정 1 참조.

### 5.1 데이터 레이어 변경 요약

| 대상 | 현재 | 정공법 후 |
|------|------|-----------|
| 비디오 목록 | `camera_clips` (camera_id) — 앱 계정 0건 | `motion_clips` via `GET /enclosures/{id}/clips` |
| 비디오 재생 | `GET {petcam}/clips/{id}/file/url` | `GET {terra-api}/clips/{id}/url` |
| Clip 모델 | `file_path` 의존 | `r2_key`/`thumbnail_key`/`motion_score` 매핑 |
| 온습도 device | `currentDeviceProvider`(첫/전역) | `camera.enclosureId` 매칭 device |
| 사육장 개념 | 없음 (평면 목록) | Enclosure 도메인/Repo/UI 신규 |

---

## 6. 영향 범위 / 리스크

- **활동량 카드(`getActivity`)와의 스키마 분기**: 활동량은 `camera_clips.has_motion` + `behavior_logs`(clip_id FK가 camera_clips 참조)에 의존(clip_repository.dart:157-227). motion_clips로 옮기면 `has_motion`/behavior가 없어 **활동량 집계가 깨진다.** → motion_clips 전환 시 활동량은 `motion_score`/개수 기반으로 재정의하거나, 당분간 분리 유지할지 결정 필요. (메모리 `project_crecam_realdata_wiring`와 충돌 지점)
- **`kShowVerifyClip=false`(camera_detail_screen.dart:17-20)**: 검증용 클립 섹션은 이번 전환과 별개(RLS labeler 이슈). 그대로 둠.
- **재생 백엔드 이원화**: 현재 `getFileUrl`은 `/clips/{id}/file/url`(petcam-lab), terra는 `/clips/{id}/url`. 경로·호스트가 달라 **terra-api 전용 클라이언트가 필요할 수 있음**.
- **behavior_logs RLS off (보안 이슈, 별건)**: `list_tables` advisory가 `public.behavior_logs`의 RLS 비활성(anon 전체 노출)을 경고. 본 기획과 무관하나 별도 조치 권장.

---

## 7. 검증 방법

- **질문1 수정 후**: leegawnhun 로그인 → 크레캠 세부캠(P4 Cam) → 비디오 기록에 2,557건 중 최신순 노출 확인, 썸네일/재생 동작 확인.
- **질문2 수정 후(단계 2)**: 뱃지가 카메라와 무관한 값을 "이 사육장"처럼 오인시키지 않는지 확인.
- **정공법(단계 4)**: 카메라↔device가 같은 enclosure일 때만 그 device 온습도가 뜨는지.

---

## 8. 결정 현황

**확정(2026-07-06)**: 비디오 기록=방안 B(정공법) · 온습도=그대로 둠(정공법에서 해결) · enclosure 배선 포함(Critical) · **배정 주체=앱 사육장 관리 UI 전면**(사육장 생성·기기 배정 모두 앱에서).

**남은 하위 결정:**

1. ~~배정 주체~~ → **확정: 앱 사육장 관리 UI 전면.** 기존 카메라2·디바이스2도 이 UI로 사용자가 직접 배정(별도 DB 마이그레이션 불필요). ⇒ S2에 **사육장 CRUD + 기기 배정/해제 UI** 포함, terra-api `POST /enclosures` + `cameras`/`devices` `enclosure_id` UPDATE 사용.
2. **검증용 최소 구성**: S5 검증엔 사육장 1개에 카메라1 + 디바이스1(telemetry 실측 있는 **test_device_02** 권장) 배정이 필요. 실제 물리 구성은 사용자가 UI에서 결정.
3. **활동량 카드**: `motion_clips`엔 `has_motion`/`behavior_logs`가 없음(§6). `motion_score`/개수 재정의 / camera_clips 분리 유지 / 보류 중 택1. (S3 착수 시 결정)
4. **재생 백엔드**: 앱 `_backendUrl`을 terra-api로 전환 or terra 전용 클라이언트 추가(현 `/clips/{id}/file/url` ≠ terra `/clips/{id}/url`). (S3 구현 세부)
