"""Read installed QuestieDB baked metadata for an offline, comparison-only audit.

Static corrections are already baked in; character-dependent corrections are not.
No database rows or comparison results are used by the runtime builders.
Run with uv run --with cbor2 python tools/compare_questiedb.py <toc> --checked YYYY-MM-DD --output <json>.
"""
import argparse
import base64
import hashlib
import json
import re
from pathlib import Path
import cbor2

ROOT = Path(__file__).resolve().parents[1]

def read_metadata(path):
    return dict(re.findall(r'^## ([^:]+): (.*)$', path.read_text(encoding='utf-8'), re.M))

def field(meta, entity, ident, slot):
    key = f'X-{entity}-{ident}-{slot}'
    value = meta.get(key)
    if value is None:
        return None
    if re.fullmatch(r'~\d+~', value):
        value = ''.join(meta[f'{key}-{i}'] for i in range(1, int(value[1:-1]) + 1))
    return cbor2.loads(base64.b64decode(value))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('toc', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--checked', required=True, help='Date this installed snapshot was reviewed')
    args = parser.parse_args()
    meta = read_metadata(args.toc)
    if meta.get('X-Flavor') != 'Forever' or meta.get('X-Mode') != 'baked':
        raise ValueError('Expected a Forever baked QuestieDB TOC')
    catalogue = json.loads((ROOT/'data/catalogue.json').read_text(encoding='utf-8'))
    nodes = json.loads((ROOT/'data/walkthroughs.json').read_text(encoding='utf-8'))
    missing, differences, matched = [], [], []
    for q in catalogue:
        row = field(meta, 'Quest', q['id'], 'S')
        if row is None:
            missing.append(q['id'])
            continue
        changes = {}
        for key, slot in [('minLevel', 4), ('level', 5)]:
            if q.get(key) is not None and q[key] != row.get(slot, 0):
                changes[key] = {'catalogue': q[key], 'questieDB': row.get(slot, 0)}
        node = nodes.get(str(q['id']), {})
        ours = (sorted(node.get('all', [])), sorted(node.get('any', [])))
        theirs = (sorted(field(meta, 'Quest', q['id'], 12) or []),
                  sorted(field(meta, 'Quest', q['id'], 13) or []))
        # A single OR prerequisite has the same meaning as a single AND prerequisite.
        def normalized(edges):
            both, either = edges
            return (sorted(set(both + either)), []) if len(either) <= 1 else edges
        if normalized(ours) != normalized(theirs):
            changes['prerequisites'] = {'catalogue': {'all': ours[0], 'any': ours[1]},
                                        'questieDB': {'all': theirs[0], 'any': theirs[1]}}
        if changes:
            differences.append({'id': q['id'], 'name': q['name'], 'fields': changes})
        else:
            matched.append(q['id'])
    report = {'checked': args.checked, 'version': meta.get('Version'),
              'commit': meta.get('X-BUILD-COMMIT'), 'sha256': hashlib.sha256(args.toc.read_bytes()).hexdigest(),
              'scope': 'Catalogue levels and walkthrough AND/OR prerequisite edges; baked static data only. Agreement is not live-client verification.',
              'catalogueCount': len(catalogue), 'matched': matched, 'missing': missing,
              'differences': differences, 'buildInputsChanged': False}
    args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(f'{len(catalogue)} checked: {len(matched)} agree, {len(differences)} differ, {len(missing)} absent')

if __name__ == '__main__':
    main()
