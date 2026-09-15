#!/usr/bin/env python3
"""Execute redesign draft assertions in an existing isolated test container.

Create with docker run --rm -d --network none --name vivanaut-redesign-sql-check
-e POSTGRES_HOST_AUTH_METHOD=trust public.ecr.aws/supabase/postgres:17.6.1.104 postgres
No remote URL/credential is accepted. All schema and fixture changes roll back.
"""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
parts = ['BEGIN;', (root / 'test/sql/redesign_base_schema.sql').read_text()]
for name in ['20260915_assignment_history.sql', '20260915_redesign_groups.sql',
             '20260915_clip_visibility.sql', '20260915_redesign_pets.sql']:
    path = root / 'supabase/drafts' / name
    if path.exists():
        parts.append(re.sub(r'(?mi)^(BEGIN|COMMIT|ROLLBACK);.*$', '', path.read_text()))
parts += [(root / 'test/sql/redesign_contract_assertions.sql').read_text(), 'ROLLBACK;']
result = subprocess.run(['docker', 'exec', '-i', 'vivanaut-redesign-sql-check',
                         'psql', '-U', 'supabase_admin', '-d', 'postgres',
                         '-v', 'ON_ERROR_STOP=1'], input='\n'.join(parts), text=True)
raise SystemExit(result.returncode)
