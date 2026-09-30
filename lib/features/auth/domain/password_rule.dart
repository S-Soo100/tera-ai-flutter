/// 새 비밀번호 규칙 — 영문·숫자·특수문자를 모두 포함한 6~12자.
///
/// 가입·비밀번호 재설정·비밀번호 변경이 같은 규칙을 쓴다(UX-07, 2026-10-01).
/// **로그인에는 쓰지 않는다** — 이 규칙 이전에 가입한 계정의 비밀번호가
/// 규칙을 만족한다는 보장이 없어 로그인에서 강제하면 잠긴다.
bool meetsPasswordRule(String v) =>
    v.length >= 6 &&
    v.length <= 12 &&
    RegExp(r'[A-Za-z]').hasMatch(v) &&
    RegExp(r'[0-9]').hasMatch(v) &&
    RegExp(r'[^A-Za-z0-9]').hasMatch(v);
