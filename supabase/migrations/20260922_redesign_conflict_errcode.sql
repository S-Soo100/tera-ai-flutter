-- 2026-09-22: redesign_* RPC의 '구성 변경' 오류 코드 40001 → PT409.
--
-- 40001(serialization_failure)은 PostgREST가 일시적 충돌로 보고 트랜잭션을
-- 자동 재시도한다. 이 함수들은 앱이 보낸 예상 구성이 실제와 다를 때 40001을
-- 냈는데, 조건이 바뀌지 않으니 재시도가 끝없이 반복돼 요청이 응답을 못 받았다
-- (운영: 24시간 group changed 약 520만 건, 멈춘 연결 4개).
-- PT409는 PostgREST가 재시도하지 않고 HTTP 409로 바로 돌려주는 사용자 코드다.
-- 앱(RedesignGroupRepository·RedesignPetRepository)은 PT409와 구 40001을
-- 같은 '구성 변경' 실패로 읽는다.
--
-- 함수 본문은 그대로 두고 오류 코드만 바꾼다(정의를 읽어 치환 후 재생성).
DO $$
DECLARE
  fn regprocedure;
  def text;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'public'
      AND p.proname IN ('redesign_save_group_v1', 'redesign_remove_group_member_v1',
                        'redesign_save_pet_v1', 'redesign_delete_pet_v1')
  LOOP
    def := pg_get_functiondef(fn);
    IF def ~ 'ERRCODE\s*=\s*''40001''' THEN
      EXECUTE regexp_replace(def, 'ERRCODE\s*=\s*''40001''', 'ERRCODE=''PT409''', 'g');
    END IF;
  END LOOP;
END $$;
