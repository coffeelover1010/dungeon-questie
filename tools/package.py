"""Allowlisted addon ZIP, including editable data and build tools for source access."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
version=next(x.split(':',1)[1].strip() for x in (ROOT/'DungeonGuideForever.toc').read_text().splitlines() if x.startswith('## Version:'))
files={ROOT/'DungeonGuideForever.toc',ROOT/'LICENSE'}
files.update(ROOT/x.strip().replace('\\','/') for x in (ROOT/'DungeonGuideForever.toc').read_text().splitlines() if x.strip() and not x.startswith('#'))
files.update(ROOT/x for x in ('README.md','WALKTHROUGHS.md','AI-RESEARCH-README.md','SOURCE-REBUILD.md','THIRD-PARTY-NOTICES.md','RELEASE-NOTES.md','Libs/NOTICE.txt','Libs/Ace3-LICENSE.txt'))
for directory in ('data','tools','licenses'):
    files.update(p for p in (ROOT/directory).iterdir() if p.is_file() and p.suffix in ('.json','.csv','.txt','.py','.ps1','.md'))
files.add(ROOT/'licenses/ClassicDB-AUTHORS')
out=ROOT/'dist';out.mkdir(exist_ok=True)
archive=out/f'DungeonQuestie-{version}.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):z.write(p,'DungeonGuideForever/'+p.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert not z.testzip()
    assert all(name.startswith('DungeonGuideForever/') and '/research/' not in name and '__pycache__' not in name for name in z.namelist())
print(json.dumps({'archive':str(archive),'files':len(files),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}))
