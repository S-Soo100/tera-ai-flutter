#!/usr/bin/env python3
"""탈퇴자 커뮤니티 숨김 초안을 격리 컨테이너에서 검증한다(운영 URL·자격 증명 받지 않음).

준비: docker run --rm -d --network none --name vivanaut-community-sql-check \
  -e POSTGRES_HOST_AUTH_METHOD=trust public.ecr.aws/supabase/postgres:17.6.1.104 postgres
순서: 기반 → 운영 마이그레이션 §3.1~3.3(테이블·RLS, 운영 pg_policies와 동일 확인)
      → 초안 → 검증. 전부 한 트랜잭션에서 ROLLBACK한다.
"""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
migration = (root / 'supabase/migrations/2026-08-31_community_clip_feed.sql').read_text()
tables_and_rls = migration.split('-- ── §3.4')[0]
draft = (root / 'supabase/drafts/20261117_community_hide_deleted_authors.sql').read_text()
draft = re.sub(r'(?mi)^(BEGIN|COMMIT|ROLLBACK);.*$', '', draft)
parts = ['BEGIN;', (root / 'test/sql/community_base_schema.sql').read_text(),
         tables_and_rls, draft,
         (root / 'test/sql/community_hide_deleted_assertions.sql').read_text(),
         'ROLLBACK;']
result = subprocess.run(['docker', 'exec', '-i', 'vivanaut-community-sql-check',
                         'psql', '-U', 'supabase_admin', '-d', 'postgres',
                         '-v', 'ON_ERROR_STOP=1', '-q'], input='\n'.join(parts), text=True)
raise SystemExit(result.returncode)
