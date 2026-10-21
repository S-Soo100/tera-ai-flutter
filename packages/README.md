# 레포 안 패키지 사본

## flutter_webrtc 1.4.1 (2026-10-20)

pub.dev 1.4.1 원본을 그대로 복사하고(`example/` 제외) **녹화 비트레이트만** 고쳤다. `pubspec.yaml`의 `dependency_overrides`로 쓴다.

| 파일 | 원본 | 수정 |
|---|---|---|
| `android/.../record/VideoFileRenderer.java` `getSupportedConfigurations` | 후보 `{6000000, 4000000, 2000000, 1000000}` | `{1500000, 1000000}` (2026-10-21, 전엔 `{2500000, 2000000, 1000000}`) |
| `common/darwin/Classes/FlutterRTCMediaRecorder.m`, `ios/Classes/FlutterRTCMediaRecorder.m` | `AVVideoAverageBitRateKey: 6*1024*1024` | `1500000` (2026-10-21, 전엔 `2500000`) |

- 이유: 라이브 직접 녹화(`MediaRecorder`)가 6fps 영상을 6Mbps로 다시 인코딩해 1분 33MB가 나왔다. 목표 1분 20MB 이하(사용자 결정 2026-10-20) → 녹화 최대 2분 확정으로 1.5Mbps(2분 약 23MB, 서버 크기 한도 30MB 안, 2026-10-21). Android는 후보를 높은 값부터 시도하므로 목표보다 큰 후보를 남기지 말 것.
- 수정 위치는 `vivanaut patch` 주석으로 찾는다.
- **flutter_webrtc를 올릴 때:** 새 버전을 다시 복사하고 위 두 곳을 다시 고친다. 녹화를 안 쓰게 되면 override와 이 폴더를 지우면 된다.
