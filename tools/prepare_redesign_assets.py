#!/usr/bin/env python3
"""Build Flutter copies without changing the user's Figma exports."""
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/figma/2026-09-15'
SVG = '{http://www.w3.org/2000/svg}'
PLACEMENTS = {
    'icons/discover_tune.svg': {
        'role': 'Three-tab management action including original inner padding',
        'figmaNode': '765:4239', 'displaySize': [44, 44], 'parentSize': [44, 44],
    },
    'icons/cards_star.svg': {
        'role': 'Camera highlight entry glyph', 'figmaNode': '765:4499',
        'displaySize': [24, 24], 'parentSize': [40, 40],
    },
    'icons/bookmark_check.svg': {
        'role': 'Camera bookmark entry glyph', 'figmaNode': '765:4507',
        'displaySize': [24, 24], 'parentSize': [40, 40],
    },
}


def prepare():
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    entries = []
    for entry in manifest['files']:
        raw = (SOURCE / entry['path']).read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != entry['sha256']:
            raise ValueError(f"Source hash mismatch: {entry['path']}")
        record = {
            'source': str((SOURCE / entry['path']).relative_to(ROOT)),
            'sourceSha256': digest,
        }
        if entry['format'] == 'svg':
            source = raw.decode('utf-8')
            root = ET.fromstring(source)
            masks = list(root.iter(SVG + 'mask'))
            # All current masks are solid, fully opaque alpha rectangles.
            # White has the same alpha and survives flutter_svg luminance masks.
            for mask in masks:
                children = list(mask)
                if (mask.get('style') != 'mask-type:alpha'
                        or len(children) != 1
                        or children[0].tag != SVG + 'rect'
                        or children[0].get('opacity', '1') != '1'
                        or children[0].get('fill-opacity', '1') != '1'
                        or not re.fullmatch(r'#[0-9a-fA-F]{6}', children[0].get('fill', ''))):
                    raise ValueError(f"Unreviewed mask: {entry['path']}")
            result = re.sub(
                r'<mask\b.*?</mask>',
                lambda m: re.sub(r'fill="#[0-9a-fA-F]{6}"', 'fill="#FFFFFF"', m[0]),
                source,
                flags=re.S,
            ).encode('utf-8')
            relative = Path('assets/icons/redesign_v2') / Path(entry['path']).relative_to('icons')
            target = ROOT / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(result)
            record.update(runtime=str(relative), runtimeSha256=hashlib.sha256(result).hexdigest(),
                          viewBox=entry['viewBox'],
                          transform='opaque-alpha-mask-white' if masks else 'byte-copy',
                          placementStatus='Source retained; usage inventory below (unused variants are not forced into UI)')
        else:
            record.update(runtime=record['source'], transform='ExactAssetImage(scale: 3)', scale=3)
        if entry['path'] in PLACEMENTS:
            record.update(PLACEMENTS[entry['path']], placementStatus='Compared with current Figma PNG export')
        runtime_name = str(record['runtime']).removeprefix('assets/icons/').removesuffix('.svg')
        consumers = []
        constants = (ROOT / 'lib/shared/widgets/figma_icon.dart').read_text()
        aliases = re.findall(r"static const (\w+) = '" + re.escape(runtime_name) + r"';", constants)
        for dart in (ROOT / 'lib').rglob('*.dart'):
            text = dart.read_text()
            if runtime_name in text or any('FigmaIcons.' + alias in text for alias in aliases):
                consumers.append(str(dart.relative_to(ROOT)))
        if '/2828/' in str(record['runtime']) or '/3636/' in str(record['runtime']):
            record['role'] = 'Compact chart marker (28) or control record badge (36); original colored circle preserved'
            consumers.extend(['lib/features/home/presentation/widgets/control_log_list.dart', 'lib/shared/domain/control_log.dart'])
        record['consumers'] = sorted(set(consumers))
        entries.append(record)
    output = ROOT / 'docs/design-audits/2026-09-15-redesign-asset-map.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'sourceManifest': 'assets/figma/2026-09-15/manifest.json',
                                  'files': entries}, ensure_ascii=False, indent=2) + '\n')
    print(f"Verified {len(entries)} source hashes; generated {manifest['svgCount']} SVG runtime copies.")


if __name__ == '__main__':
    prepare()
