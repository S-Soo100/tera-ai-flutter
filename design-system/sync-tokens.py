#!/usr/bin/env python3
"""_tokens.css를 모든 카드의 <style> 첫 블록에 주입한다.

카드는 개별 렌더되므로 토큰을 링크할 수 없고 인라인으로 복사해야 한다.
그래서 토큰을 고치면 전 카드를 다시 써야 하는데, 손으로 하면 반드시 빠뜨린다.
"""
import pathlib, re, sys

root = pathlib.Path(__file__).parent
tokens = (root / '_tokens.css').read_text(encoding='utf-8').strip()
changed = []
for f in sorted(root.rglob('*.html')):
    if f.name == 'index.html':
        continue
    s = f.read_text(encoding='utf-8')
    new, n = re.subn(r'<style>\n.*?\n</style>', f'<style>\n{tokens}\n</style>',
                     s, count=1, flags=re.S)
    if n == 0:
        print(f'  ! {f.relative_to(root)} — <style> 블록을 못 찾음', file=sys.stderr)
        continue
    if new != s:
        f.write_text(new, encoding='utf-8')
        changed.append(str(f.relative_to(root)))
print(f'{len(changed)}장 갱신' + (': ' + ', '.join(changed) if changed else ''))
