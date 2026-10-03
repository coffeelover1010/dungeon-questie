"""Read a pinned CMaNGOS SQL snapshot as data (never execute SQL).

Export only named factual columns needed by the checklist. Quest descriptions,
dialogue and SQL implementation are deliberately excluded. No Questie input.
"""
import argparse, gzip, hashlib, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r"'((?:\\.|[^'\\])*)'|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(NULL)|([(),;])", re.S)

def rows(sql, table):
    schema = re.search(r'CREATE TABLE `' + table + r'` \((.*?)\) ENGINE=', sql, re.S)
    columns = re.findall(r'^  `([^`]+)`', schema[1], re.M)
    for line in sql.splitlines():
        prefix = 'INSERT INTO `' + table + '` VALUES '
        if not line.startswith(prefix):
            continue
        values = []; end = 0
        body = line[len(prefix):]
        for m in TOKEN.finditer(body):
            assert not body[end:m.start()].strip(), (table, body[end:m.start()][:80])
            end = m.end()
            string, number, null, punctuation = m.groups()
            if string is not None:
                escapes = {'n':'\n','r':'\r','t':'\t','0':'\0','Z':'\x1a'}
                values.append(re.sub(r'\\(.)', lambda x: escapes.get(x[1], x[1]), string))
            elif number is not None:
                values.append(float(number) if any(c in number for c in '.eE') else int(number))
            elif null:
                values.append(None)
            elif punctuation == ')':
                assert len(values) == len(columns), (table, len(values), len(columns))
                yield dict(zip(columns, values)); values = []
        assert not body[end:].strip()

def main():
    p=argparse.ArgumentParser(); p.add_argument('snapshot'); p.add_argument('--revision', required=True)
    args=p.parse_args(); path=Path(args.snapshot)
    sql=gzip.open(path,'rt',encoding='utf-8').read()
    quest_fields=['entry','Title','MinLevel','RequiredClasses','RequiredRaces','RequiredSkill','RequiredCondition','RequiredMinRepFaction','RequiredMaxRepFaction','PrevQuestId','NextQuestId','ExclusiveGroup','BreadcrumbForQuestId','SrcSpell']
    quest_fields += [f'{key}{i}' for key in ('ReqItemId','ReqItemCount','ReqCreatureOrGOId','ReqCreatureOrGOCount','ReqSpellCast') for i in range(1,5)]
    tables={'quest_template':quest_fields,
            'creature_template':['Entry','Name'], 'gameobject_template':['entry','name'],
            'item_template':['entry','name','startquest'],
            'creature_questrelation':['id','quest'], 'creature_involvedrelation':['id','quest'],
            'gameobject_questrelation':['id','quest'], 'gameobject_involvedrelation':['id','quest'],
            'creature':['id','map','position_x','position_y'], 'gameobject':['id','map','position_x','position_y']}
    result={name:[{k:r[k] for k in fields} for r in rows(sql,name)] for name,fields in tables.items()}
    for table in ('creature','gameobject'):
        givers={r['id'] for suffix in ('questrelation','involvedrelation') for r in result[table+'_'+suffix]}
        result[table]=[r for r in result[table] if r['id'] in givers and r['map'] in (0,1)]
    seeds={q['id'] for q in json.loads((ROOT/'data/catalogue.json').read_text(encoding='utf-8'))}
    overrides=json.loads((ROOT/'data/walkthrough-overrides.json').read_text(encoding='utf-8'))
    seeds.update(int(i) for i in overrides)
    for r in overrides.values():seeds.update(r.get('all',[])+r.get('any',[]))
    selected=set(seeds)
    while True:
        old=set(selected)
        group_ids={r['ExclusiveGroup'] for r in result['quest_template'] if r['entry'] in selected and r['ExclusiveGroup']}
        for r in result['quest_template']:
            if r['entry'] in selected:
                if r['PrevQuestId']:selected.add(abs(r['PrevQuestId']))
            if abs(r['NextQuestId']) in selected or r['BreadcrumbForQuestId'] in selected or r['ExclusiveGroup'] in group_ids:selected.add(r['entry'])
        if old==selected:break
    result['quest_template']=[r for r in result['quest_template'] if r['entry'] in selected]
    entity_ids={'creature':set(),'gameobject':set(),'item':set()}
    for table in ('creature','gameobject'):
        for suffix in ('questrelation','involvedrelation'):
            key=table+'_'+suffix;result[key]=[r for r in result[key] if r['quest'] in selected]
            entity_ids[table].update(r['id'] for r in result[key])
    entity_ids['item'].update(r['entry'] for r in result['item_template'] if r['startquest'] in selected)
    for r in result['quest_template']:
        for slot in range(1,5):
            entity_ids['item'].add(r[f'ReqItemId{slot}'])
            target=r[f'ReqCreatureOrGOId{slot}'];entity_ids['creature' if target>0 else 'gameobject'].add(abs(target))
    for table in ('creature','gameobject','item'):
        id_key='Entry' if table=='creature' else 'entry'
        result[table+'_template']=[r for r in result[table+'_template'] if r[id_key] in entity_ids[table]]
        if table!='item':result[table]=[r for r in result[table] if r['id'] in entity_ids[table]]
    # Keep source facts separate from the runtime schema. The full factual subset
    # permits deterministic chain closure without depending on a comparison file.
    out=ROOT/'data/classic-source.json'
    out.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
    metadata={'project':'CMaNGOS Classic-DB','revision':args.revision,'snapshot':'Full_DB/ClassicDB_1_12_1_z2815.sql.gz','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'license':'GPL-3.0','scope':'Pinned base snapshot; subsequent SQL updates are not applied. Classic reference, not Forever verification.','source':'https://github.com/cmangos/classic-db/tree/'+args.revision}
    (ROOT/'data/classic-source-provenance.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print({k:len(v) for k,v in result.items()})

if __name__=='__main__': main()
