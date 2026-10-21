# 레포 안 패키지 사본

## flutter_webrtc 1.4.1 (2026-10-20)

pub.dev 1.4.1 원본을 그대로 복사하고(`example/` 제외) **녹화 비트레이트만** 고쳤다. `pubspec.yaml`의 `dependency_overrides`로 쓴다.

| 파일 | 원본 | 수정 |
|---|---|---|
| `android/.../record/VideoFileRenderer.java` `getSupportedConfigurations` | 후보 `{6000000, 4000000, 2000000, 1000000}` | `{1500000, 1000000}` (2026-10-21, 전엔 `{2500000, 2000000, 1000000}`) |
| 같은 파일 `tryConfigureEncoder` | VBR(기본) | 지원하면 **CBR** (2026-10-21 — Android 12+ VQApply가 VBR에서 요청 1.5Mbps를 화질 하한 3.98Mbps로 올려 2분 54MB가 나왔다. CBR엔 하한이 없다) |
| 같은 파일 `FRAME_RATE` | `30` | `10` (카메라 영상이 약 6fps — CBR 프레임당 예산을 실제에 가깝게) |
| `common/darwin/Classes/FlutterRTCMediaRecorder.m`, `ios/Classes/FlutterRTCMediaRecorder.m` | `AVVideoAverageBitRateKey: 6*1024*1024` | `1500000` (2026-10-21, 전엔 `2500000`) |

- 이유: 라이브 직접 녹화(`MediaRecorder`)가 6fps 영상을 6Mbps로 다시 인코딩해 1분 33MB가 나왔다. 목표 1분 20MB 이하(사용자 결정 2026-10-20) → 녹화 최대 2분 확정으로 1.5Mbps(2분 약 23MB, 서버 크기 한도 30MB 안, 2026-10-21). Android는 후보를 높은 값부터 시도하므로 목표보다 큰 후보를 남기지 말 것.
- 수정 위치는 `vivanaut patch` 주석으로 찾는다.
- **flutter_webrtc를 올릴 때:** 새 버전을 다시 복사하고 위 두 곳을 다시 고친다. 녹화를 안 쓰게 되면 override와 이 폴더를 지우면 된다.

### 2026-10-21 실측 — 삼성(Exynos)에서는 비트레이트가 먹지 않는다

SM-G996N(Android, `c2.exynos.h264.encoder`)에서 1.5Mbps를 요청해도 Android VQApply("minquality")가 VBR 모드에서 1280×960 하한 3.32Mbps + 0.66Mbps를 강제해 **3.98Mbps**로 녹화된다(2분 = 54MB). 이 인코더는 CBR 지원을 보고하지 않고, 하한을 끄는 `android._encoding-quality-level` 키는 앱이 설정해도 무시된다. 즉 2026-10-20의 2.5Mbps 패치도 삼성에서는 효과가 없었다(그 전 33MB/분도 같은 3.98Mbps 상한 근처). CBR을 지원하는 인코더에서는 이 패치가 1.5Mbps로 동작한다.

**해결(같은 날):** 하드웨어 인코더가 CBR을 지원하지 않으면 Android 기본 소프트웨어 인코더 `c2.android.avc.encoder`로 바꾼다(`VideoFileRenderer.tryConfigureEncoder`, `supportsCbr`). G996 실측: CBR 1.5Mbps 설정 → 실제 0.97Mbps(영상 6.3fps), 40.9초 4.9MB → **2분 약 15MB**. 같은 장면 비교에서 화질 차이는 작다(약간 부드러움). VQApply는 CBR에 적용되지 않는다.

### 2026-10-21 iOS

`FlutterRTCMediaRecorder.m`(두 벌)에 `AVVideoMaxKeyFrameIntervalDurationKey: 5`를 더했다. `AVVideoExpectedSourceFrameRateKey`·`AVVideoAllowFrameReorderingKey`는 iPhone 13 mini 시뮬레이터에서 녹화 도중 `-11800`(내부 `-12419`)로 매번 실패해 넣지 않는다. 시뮬레이터의 소프트웨어 인코더는 평균 비트레이트를 따르지 않아 1.5Mbps를 줘도 **2.7~2.9Mbps**가 나온다(67초 24MB). 실제 iPhone(하드웨어 VideoToolbox)에서 다시 재야 한다 — 실기기도 높으면 VTCompressionSession으로 직접 인코딩해 DataRateLimits를 거는 방법을 검토한다. 앱은 업로드 전 30MB 초과를 막는다.

**iOS 간헐 실패 원인(같은 날):** WebRTC가 프레임을 서로 다른 두 스레드에서 넘겨 `appendSampleBuffer`·`initialize`가 동시에 돌았다(실패 로그의 스레드가 둘). `renderFrame`을 `@synchronized(self)`로 감싸고, 멈춘 뒤·실패 뒤 프레임은 버린다(`assetWriter.status != Writing`). 수정 뒤 시뮬레이터 10·20초 녹화 연속 성공, 녹화 중 오류 0건. 10월 1일의 "2.5초 뒤 -11800/-12419" 실패도 같은 원인으로 본다.
