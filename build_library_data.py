"""Build catalog-only spellbook groups from reviewed client-data exports.

Inputs were fetched through the GitHub connector on 2026-11-01. No spell
descriptions, executable code, or new castable spells are imported.
"""
from pathlib import Path
import json
from collections import defaultdict

ROOT=Path(__file__).resolve().parent
exports=json.loads((ROOT/'classification-source.json').read_text())
talents=json.loads((ROOT/'talent-classification-source.json').read_text())+json.loads((ROOT/'forever-talent-classification-source.json').read_text())
catalog=json.loads((ROOT/'catalog-classification-input.json').read_text())
by_id=defaultdict(dict); by_name=defaultdict(lambda:defaultdict(set))
for source in exports:
    cls=source['class'].upper()
    for row in source['rows']:
        if row['spec']!='Other':
            by_id[cls][row['id']]=row['spec']
            by_name[cls][row['name']].add(row['spec'])
talent_ids=defaultdict(dict); talent_names=defaultdict(dict)
for source in talents:
    key=('era' if source['flavor']=='classic' else 'forever',source['class'].upper())
    for tree in source['trees']:
        for talent in tree['talents']:
            for spell_id in talent.get('spellIds',[talent.get('spellId')]):
                # The Classic source's two Warrior field labels are correct,
                # but their numeric IDs were transposed. Keep the Vanilla tree.
                if key==('era','WARRIOR') and talent['fieldName']=='sweepingStrikes': spell_id=12328
                if key==('era','WARRIOR') and talent['fieldName']=='deathWish': spell_id=12292
                if spell_id: talent_ids[key][spell_id]=tree['name']
            if talent.get('fancyName'): talent_names[key][talent['fancyName']]=tree['name']
def array(value):
    return list(value.values()) if isinstance(value,dict) else value or []

groups=defaultdict(lambda:defaultdict(list)); unmapped=defaultdict(list)
for row in catalog:
    flavor,cls,definition=row['flavor'],row['class'],row['def']
    ids=array(definition.get('spellIDs'))
    names=[definition['name']]+array(definition.get('spellNames'))
    tree=next((talent_ids[(flavor,cls)][sid] for sid in ids if sid in talent_ids[(flavor,cls)]),None)
    tree=tree or next((talent_names[(flavor,cls)][name] for name in names if name in talent_names[(flavor,cls)]),None)
    is_talent=bool(tree)
    if definition.get('petSpell') or definition.get('pet'):
        group='Pets'
    elif tree:
        group=tree
    else:
        group=next((by_id[cls][sid] for sid in ids if sid in by_id[cls]),None)
        if not group:
            choices=set()
            for name in names: choices.update(by_name[cls][name])
            group=next(iter(choices)) if len(choices)==1 else None
        if not group and cls=='DRUID' and (definition.get('requiresForm') in ('cat','bear') or definition.get('form') in ('cat','bear')):
            group='Feral Combat'
        if not group: group='General'; unmapped[(flavor,cls)].append(definition['name'])
    # The party version is trained from a book but requires the same talent.
    if flavor=='era' and cls=='PRIEST' and definition['id']=='priest.prayer_spirit': is_talent=True
    if flavor=='era' and cls=='PALADIN' and definition['id'] in ('paladin.greater_kings','paladin.greater_sanctuary'):
        group='Protection'; is_talent=True
    groups[(flavor,cls)][group].append(('!' if is_talent else '')+definition['id'])

lines=['local _, K = ...','-- Catalog display groups only; the live spellbook category takes precedence.',
       '-- Reviewed 2026-11-01. Talent flags are separate for Era and Forever.',
       '-- Sources: https://github.com/wowsims/gamedata/tree/main/spells',
       '-- https://github.com/wowsims/classic/tree/master/ui/core/talents/trees',
       '-- https://github.com/wowsims/forever/tree/master/ui/sim/talents/trees',
       '-- Unknown additions use General; none of this data grants spell knowledge.',
       'K.LibraryData={}; local D=K.LibraryData','local data={era={},forever={}}',
       'local function group(flavor,class,category,ids)',
       ' local map=data[flavor][class] or {}; data[flavor][class]=map',
       ' for token in ids:gmatch("%S+") do',
       '  local talent=token:sub(1,1)=="!"; local id=talent and token:sub(2) or token',
       '  map[id]={category,talent}',
       ' end','end']
for (flavor,cls),specs in sorted(groups.items()):
    for spec,ids in sorted(specs.items()):
        lines.append('group(%s,%s,%s,%s)'%(json.dumps(flavor),json.dumps(cls),json.dumps(spec),json.dumps(' '.join(sorted(set(ids))))))
lines += ['function D:Classify(class,definition,flavor)',
          ' flavor=flavor or (K.API and K.API:GetFlavor()) or "era"',
          ' local map=(data[flavor] or data.era)[class] or {}',
          ' local entry=definition and map[definition.id]',
          ' if entry then return entry[1],entry[2] end',
          ' if definition and (definition.petSpell or definition.pet) then return "Pets",false end',
          ' return "General",false','end','']
(ROOT/'KeybindOptimizer'/'LibraryData.lua').write_text('\n'.join(lines),encoding='utf-8')
for key,names in sorted(unmapped.items()): print(*key,':',', '.join(sorted(set(names))))
print('Wrote catalog groups:',sum(len(ids) for specs in groups.values() for ids in specs.values()))
