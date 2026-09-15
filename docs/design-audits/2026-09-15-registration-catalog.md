# 등록 카탈로그 대조 — 2026-09-15

공개 `morph_genetics` GET과 번들 JSON을 대조했다. DB에 새 데이터를 쓰거나 생물학적 정의를 추정·병합하지 않았다. 등록 화면은 기존 `CareInfoRepository`의 로컬 카탈로그를 사용하며, 이전 등록 화면이 제공하던 모프와 라인브리드 항목을 모두 유지한다.

|구분|로컬|DB|로컬에만 있는 ID|
|---|---:|---:|---|
|genes|6|6||
|morphs|23|17|phantom-sable, axanthic-cappuccino, axanthic-sable, super-highway, lilly-highway, phantom-luwak|
|line_bred_traits|26|22|super-dalmatian, buckskin, charcoal, creamsicle|

등록 선택 키는 `morph:<id>` / `trait:<id>`로 출처를 구분한다. 기존 `pets.morph`는 표시 문자열 계약이라 저장 형식을 강제 변경하지 않는다. 기존 다른 종·사용자 모프 문자열도 보존한다. 신규 종은 `crested-gecko`만 선택할 수 있다.

DB와 겹치는 ID의 표시 이름은 동일하다. DB 17/22와 로컬 23/26 차이는 원격 카탈로그의 별도 반영 대상이며, 이 앱 변경에서 공개 유전자 계산 정의를 수정하지 않았다.

로컬 카탈로그 SHA-256: `7ff731b44035016462534e5d0ae3c011195c5ac516d9ae6e7c6df83d6158b1d7`.
