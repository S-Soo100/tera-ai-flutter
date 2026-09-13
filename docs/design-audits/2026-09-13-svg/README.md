# Final Design SVG 원본 — 2026-09-13

승인된 설계의 아이콘 30개를 Talk to Figma MCP에서 직접 추출했다. 모두 SVG XML 및 path를 포함하며 래스터 image 태그는 없다. 원본 경로·색상·마스크·viewBox를 보존했다. 앱 에셋 적용 전 원본 보관본이다.

## 추출 방법

배포 플러그인의 `exportNodeAsImage`는 요청 format을 무시하고 PNG로 고정되어 있었다. 설치되어 있던 Talk to Figma 소스의 임시 개발용 복사본에서 format을 존중하도록 고쳤다. SVG에는 래스터 SCALE 제약을 전달하지 않는다. 원본 소스·배포 플러그인은 변경하지 않았다. 수정본의 SVG/PNG 호환 단위 검증과 실제 Figma SVG 출력을 확인했다.

개발용 플러그인은 `/tmp/vivnanaut-figma-svg-plugin/manifest.json`에서 등록했으며 현재 채널은 `ks50dfit`이다. `/tmp`가 정리되면 아래 patch를 기존 소스의 별도 복사본에 적용하고 개발용으로 다시 등록하면 된다. Figma 원본 도형은 수정하지 않았다.

[재현용 수정 patch](talk-to-figma-svg-export.patch) · [원본 노드·viewBox·SHA-256](manifest.json)

## 적용 시 주의

- 글리프와 전체 버튼/원형 배경을 구별한다. `fan_on` 등 Asset_v2 원본은 배경까지 포함할 수 있으므로 기존 원형 배경 위에 중복 렌더하지 않는다.
- Flutter에 연결할 때 tint 가능한 단색 아이콘과 원본 색을 유지할 다색 아이콘을 분리한다.
- 16/24/36/44 viewBox 등 크기 차이가 있다. 전체 SVG 너비와 화면에서 보이는 글리프 크기를 동일시하지 않는다.
- 원본에 마스크가 있으므로 앱의 flutter_svg 렌더링 검증 후 불필요한 마스크만 별도 파생 에셋에서 정리한다. 원본은 변경하지 않는다.

## 아이콘 목록

| 파일 | Figma node | viewBox |
|---|---|---|
| [close.svg](close.svg) | 941:2120 | 0 0 24 24 |
| [arrow_previous.svg](arrow_previous.svg) | 941:1849 | 0 0 24 24 |
| [arrow_next.svg](arrow_next.svg) | 941:1861 | 0 0 24 24 |
| [download.svg](download.svg) | 941:1853 | 0 0 36 36 |
| [share.svg](share.svg) | 941:1855 | 0 0 36 36 |
| [bookmark.svg](bookmark.svg) | 941:1857 | 0 0 36 36 |
| [delete.svg](delete.svg) | 941:1864 | 0 0 44 44 |
| [play.svg](play.svg) | 941:1868 | 0 0 36 36 |
| [speed_2x.svg](speed_2x.svg) | 941:1910 | 0 0 36 36 |
| [expand.svg](expand.svg) | 941:1876 | 0 0 36 36 |
| [cards_star.svg](cards_star.svg) | 945:4173 | 0 0 24 24 |
| [bookmark_check.svg](bookmark_check.svg) | 945:4181 | 0 0 24 24 |
| [calendar.svg](calendar.svg) | 945:4189 | 0 0 16 16 |
| [bookmark_badge.svg](bookmark_badge.svg) | 945:4203 | 0 0 32 32 |
| [nav_home.svg](nav_home.svg) | 945:4259 | 0 0 24 24 |
| [nav_camera.svg](nav_camera.svg) | 945:4262 | 0 0 24 24 |
| [nav_mycre.svg](nav_mycre.svg) | 945:4265 | 0 0 24 24 |
| [nav_community.svg](nav_community.svg) | 945:4268 | 0 0 24 24 |
| [dropdown.svg](dropdown.svg) | 945:4152 | 0 0 24 24 |
| [add.svg](add.svg) | 945:4157 | 0 0 24 24 |
| [person.svg](person.svg) | 945:4161 | 0 0 24 24 |
| [live_expand.svg](live_expand.svg) | 945:4167 | 0 0 18 18 |
| [fan_on.svg](fan_on.svg) | 934:1058 | 0 0 40 40 |
| [fan_off.svg](fan_off.svg) | 934:1066 | 0 0 40 40 |
| [mist_on.svg](mist_on.svg) | 934:1062 | 0 0 40 40 |
| [mist_off.svg](mist_off.svg) | 934:1072 | 0 0 40 40 |
| [cool_on.svg](cool_on.svg) | 934:1060 | 0 0 40 40 |
| [cool_off.svg](cool_off.svg) | 934:1068 | 0 0 40 40 |
| [led_on.svg](led_on.svg) | 934:1064 | 0 0 40 40 |
| [led_off.svg](led_off.svg) | 934:1070 | 0 0 40 40 |
