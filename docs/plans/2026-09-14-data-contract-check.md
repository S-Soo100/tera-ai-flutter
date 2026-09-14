# Final Design 데이터 계약 확인

2026-09-14. 외부 전송·서버 배포 없음. 앱 변경은 `codex/final-design-implementation`에 있다.

## 온습도 일평균

확인한 출처: `~/Downloads/APP_INTEGRATION.md`, 앱 `TelemetryBucket`, `SupabaseModuleControlRepository.telemetryHistory`. 문서는 raw telemetry 7일/1분 집계 보관을 설명하지만 앱은 `telemetry_30m`을 읽는다. 로컬 프로젝트 및 `home-mac`의 확인 가능한 경로에서 해당 집계 SQL은 찾지 못했다. 따라서 `sample_count`가 `avg`와 동일한 필터의 유효 개수라는 근거가 없다.

앱 어댑터는 아래 **제안 필드**를 선택적으로 파싱한다. 현재 서버에서 제공된다고 확인한 필드가 아니다. 기존 서버에 없는 컬럼을 명시 select하여 전체 차트를 실패시키지 않도록 기존 행을 읽고 optional 필드만 소비한다.

```json
{
  "bucket": "2026-09-13T15:00:00Z",
  "sample_count": 3,
  "t_a_avg": 25.0,
  "t_a_valid_count": 2,
  "h_a_avg": 60.0,
  "h_a_valid_count": 1
}
```

서버 수락 조건:

1. 온도/습도 각각 `avg`, `min`, `max`, `valid_count`는 같은 필터(`a_ok`, null/0 센티넬, 비정상 값 제외)를 사용한다. 위 fixture의 온도 유효값 20/30, 습도 유효값 60을 raw→집계 SQL로 재현한다.
2. 기존 장기 버킷의 valid count 복원이 불가능하면 null로 두고 그 사실을 유지한다. 총 raw 개수를 임의 복제하지 않는다.
3. `[현지 날짜 00:00, 다음 날짜 00:00)`의 UTC 변환을 쿼리 경계로 사용한다. 30분 버킷이 현지 경계와 정렬되지 않는 시간대는 서버 일간 집계가 필요하다. 현재 KST 30분 정렬 범위에 한정한다.
4. `(20×1 + 30×3)/4=27.5`를 검증한다. 온습도 유효 개수가 다를 때 각각 계산한다. 빈 집합=null, 수집 공백 보간 없음.

앱 현황: 오늘 stale/미수신은 마지막 차트값으로 대체하지 않는다. 과거는 유효 개수로 가중 평균하며 유효 평균이 있는 버킷 중 count 하나라도 미상인 지표는 `--`이다. 이 상태를 실제 과거 평균 연동 완료로 보고하지 않는다.

## 하이라이트 공개 배치

확인 출처: 로컬 `~/petcam-lab/backend/routers/highlights.py`, 앱 `HighlightRepository.listFeatured`, `NightlyHighlight`. 현행 GET `/highlights/featured`는 요청 시 `fn_highlight_featured` 결과를 반환한다. `day_key`, 촬영시각, rank, `play_from_sec`는 있지만 불변 공개 배치 ID/공개 완료시각은 없다.

기존 항목에 아래 **제안 optional 객체**가 있으면 앱이 도착/읽음 UX를 사용할 수 있다. 서버 구현 또는 배포 사실은 확인되지 않았다.

```json
{
  "clip_id": "clip-id",
  "camera_id": "camera-id",
  "publication": {
    "batch_id": "immutable-batch-id",
    "capture_start": "2026-09-12T13:00:00Z",
    "capture_end": "2026-09-12T21:00:00Z",
    "published_at": "2026-09-12T23:00:00Z",
    "status": "ready"
  }
}
```

- 같은 카메라·batch_id의 구성원과 publication 메타는 일관돼야 한다. ready 전에 완료로 반환하지 않는다. 재선정 시 동일 배치 유지/새 revision 발급 중 하나를 서버가 명시해야 한다.
- 촬영 시작/종료와 공개 시각은 UTC offset을 포함한다. `capture_start < capture_end <= published_at <= now`여야 도착 배너 후보가 된다.
- 앱의 밤 활동 창 22~06시, 활동일 경계 07시, 기존 featured day_key 20시 경계는 서로 다르다. 새 공개 배치의 실제 촬영 구간을 명시하여 20시 day_key를 전날 밤 구간으로 추정하지 않는다.
- 읽음은 `(ownerId, cameraId, batchId)`별 로컬 저장이다. 실제 재생 위치가 진행되어야 저장하며 진입/initialize/초기 seek/버퍼링은 저장하지 않는다. X 닫기는 별도 dismiss, 읽음이 아니다.
- 현재 서버 응답처럼 publication이 없으면 기존 하이라이트 목록/재생은 유지하되 도착 카드와 ‘업데이트’ 공개시각은 만들어 내지 않는다. 촬영시각을 published_at으로 대체하지 않는다.
- 다른 기기에서도 읽음을 동기화하려면 owner별 읽음 endpoint/테이블 및 RLS 계약이 추가로 필요하다. 이번 로컬 저장이 다중 기기 동기화라는 뜻은 아니다.

추가 실서버 확인: 앱 Supabase anon 키로 행을 반환하지 않는 select/limit=0 검사에서 `telemetry_30m.t_a_valid_count`는 42703(컬럼 없음). 실제 계정 fixture 조회는 자동 승인 검토가 명시적 계정 접근 승인 부족으로 거부하여 수행하지 않았다. schema probe가 정확한 일평균 지원을 입증한 것은 아니다.
