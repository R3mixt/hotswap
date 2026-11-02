-- These fixtures exercise full catalogs/visible reservations with account overflow explicitly enabled.
local function libraryInit()
    TestAddon:Init(); TestAddon:GetSettings().allowAccountMacros=true; TestAddon.db.settings.flavor='era'; return TestAddon
end
local function actionFor(k,id)
    for _,action in ipairs(k:Preview().actions) do if action.id==id then return action end end
    error('Missing action '..id)
end
local function spellEntry(k,id)
    for _,entry in ipairs(k.Library:List({tab='spells'})) do if entry.actionID==id then return entry end end
    error('Missing library entry '..id)
end
function Tests.library_uses_real_rank_metadata_and_explicit_ranks_keep_separate_keys()
    local k=libraryInit(); local rank
    for _,entry in ipairs(k.Library:List({tab='spells',showRanks=true})) do if entry.spellID==5176 and entry.rank=='Rank 1' then rank=entry end end
    assert(rank,'Rank 1 Wrath was not available in the mini spellbook')
    local ok,id,why=k.Library:Stage(rank); assert(ok,why)
    local custom=actionFor(k,id)
    assert(custom.known and custom.spellID==5176 and custom.explicitRank)
    assert(custom.body:find('/cast Wrath(Rank 1)',1,true),'Exact rank macro upgraded to highest')
    assert(custom.form=='all' and custom.key~=actionFor(k,'druid.wrath.caster').key)
    assert(actionFor(k,'druid.wrath.caster').spellID==5177,'Adding rank1 changed the default highest rank')
    assert(k:Apply())
    assert(k.Library:SetRank(id,nil)); custom=actionFor(k,id)
    assert(not custom.explicitRank and custom.spellID==5177,'Highest rank option did not reset an explicit duplicate')
end
function Tests.library_rank_override_and_main_page_replacement_preserve_other_form_positions()
    local k=libraryInit()
    assert(k.Library:SetRank('druid.wrath.caster',5176))
    local caster=actionFor(k,'druid.wrath.caster'); assert(caster.spellID==5176 and caster.barSlot==1)
    assert(k.Library:Place(spellEntry(k,'druid.rejuvenation'),'druid.wrath.caster','focus'))
    caster=actionFor(k,'druid.wrath.caster')
    assert(caster.spellName=='Rejuvenation' and caster.key=='1' and caster.barSlot==1 and caster.form=='caster')
    assert(caster.body:find('[mod:alt,@player][@focus,help,nodead]',1,true))
    assert(actionFor(k,'druid.claw.cat').key=='1' and actionFor(k,'druid.claw.cat').name=='Claw')
    assert(actionFor(k,'druid.rejuvenation').key=='Q','Dragging a spell to a page removed its normal binding')
    assert(k:Apply())
end
function Tests.library_unknown_rank_stays_unlearned_and_missing_rank_text_blocks_macro()
    local k=libraryInit(); Mock.catalog[991234]={id=991234,name='Wrath',rank='Rank 9',icon=123}
    local ok,id=k.Library:Stage({descriptor={kind='spell',spellID=991234,name='Wrath',rank='Rank 9',targeting='harm'}}); assert(ok)
    local action=actionFor(k,id)
    assert(not action.known and action.nativeMacro and action.body:find('Wrath(Rank 9)',1,true))
    local body,why=k.Macros:Build({known=true,explicitRank=true,name='Wrath'},k:GetSettings())
    assert(not body and why:find('rank',1,true),'Missing subtext silently cast highest rank')
end
function Tests.library_target_modes_keep_alt_self_first_and_reject_incompatible_targets()
    local k=libraryInit()
    assert(k.Library:SetTargetMode('druid.rejuvenation','focus'))
    local a=actionFor(k,'druid.rejuvenation')
    assert(a.body:find('/cast [mod:alt,@player][@focus,help,nodead] Rejuvenation',1,true))
    assert(a.body:find('/cancelform [mod:alt,@player][@focus,help,nodead]',1,true))
    assert(not k.Library:SetTargetMode('druid.wrath.caster','self'))
    assert(not k.Library:SetTargetMode('druid.wrath.caster','cursor'))
    assert(k.Library:SetTargetMode('druid.hurricane.caster','cursor'))
    assert(actionFor(k,'druid.hurricane.caster').body:find('[@cursor]',1,true))
end
function Tests.library_user_macro_reference_is_not_copied_and_modified_reference_fails_safely()
    local k=libraryInit(); local entry
    for _,v in ipairs(k.Library:List({tab='macros'})) do if v.label=='UserMacro' then entry=v end end
    assert(entry and not entry.generated)
    local ok,id=k.Library:Stage(entry); assert(ok)
    local a=actionFor(k,id); assert(a.kind=='macroref' and a.known and not a.body)
    assert(k:Apply()); assert(GetMacroInfo(GetMacroIndexByName("UserMacro"))=='UserMacro')
    EditMacro(GetMacroIndexByName("UserMacro"),nil,nil,'/say I changed my macro')
    local plan=k:Preview(); assert(#plan.errors>0,'Changed user macro reference was silently accepted')
    assert(not k:Apply()); assert(GetMacroInfo(GetMacroIndexByName("UserMacro"))=='UserMacro')
end
function Tests.library_stage_undo_and_import_are_data_only_and_preserve_rank_replacements()
    local k=libraryInit(); local rank={descriptor={kind='spell',spellID=5176,name='Wrath',rank='Rank 1',targeting='harm'}}
    local ok,id,_,token=k.Library:Stage(rank); assert(ok and k.db.settings.customActions[id])
    assert(k.Library:Unstage(token)); assert(not k.db.settings.customActions[id])
    assert(k.Library:Place(rank,'druid.wrath.caster','target'))
    ok,id=k.Library:Stage(rank); assert(ok)
    k.db.settings.bindingOverrides[id]='SHIFT-F24'
    local payload=k:Export('Leveling'); assert(k:Import(payload))
    assert(k.db.settings.actionOverrides['druid.wrath.caster'].replacement.spellID==5176)
    assert(k.db.settings.customActions[id].rank=='Rank 1')
    assert(not k:Import(payload..'\nu\tLeveling\tcustom.999\tbody\t/run CastSpellByName("Wrath")'))
end
function Tests.library_localizes_emotes_and_excludes_unfingerprinted_macro_commands()
    local k=libraryInit(); local locale=GetLocale
    GetLocale=function() return 'deDE' end
    EMOTE999_TOKEN='WAVE'; EMOTE999_CMD1='/winken'; k.Library.emoteCache=nil
    local ok,id=k.Library:Stage({descriptor={kind='emote',emote='WAVE'}}); assert(ok)
    assert(actionFor(k,id).body=='/winken')
    assert(not k.Library:ValidateDescriptor({kind='emote',emote='/run Evil()'}))
    local bindings=GetBinding; local number=GetNumBindings
    GetNumBindings=function() return 2 end
    GetBinding=function(i) return i==1 and 'MACRO UserMacro' or 'CLICK Evil:LeftButton','GENERAL' end
    k.Library.commandCache=nil; assert(not next(k.Library:Commands()))
    GetBinding,GetNumBindings,GetLocale=bindings,number,locale
end

function Tests.library_item_replacements_keep_target_mode_and_clear_old_item_selection()
    local k=libraryInit()
    Mock.bagItems[0]={{id=1251},{id=10720}}
    Mock.itemInfo[1251]={name='Linen Bandage',effect='First Aid'}
    Mock.itemInfo[10720]={name='Gnomish Net-o-Matic Projector',effect='Net-o-Matic'}
    k.Items:Invalidate()
    assert(k.Library:Place({descriptor={kind='item',itemID=1251}},'druid.wrath.caster'))
    assert(k.Library:SetTargetMode('druid.wrath.caster','self'))
    local a=actionFor(k,'druid.wrath.caster')
    assert(a.targetMode=='self' and a.body:find('/use [@player] item:1251',1,true))
    assert(a.selfKey=='ALT-1' and a.barSlot==1)
    assert(k.Library:Place({descriptor={kind='item',itemID=10720}},'druid.wrath.caster','focus'))
    a=actionFor(k,'druid.wrath.caster')
    assert(a.itemSelectedID==10720 and a.targetMode=='focus' and a.body:find('/use [@focus,harm,nodead] item:10720',1,true))
    assert(not a.selfKey and not k.Library:SetTargetMode(a.id,'self'))
    assert(k.Library:Place(spellEntry(k,'druid.rejuvenation'),'druid.wrath.caster'))
    assert(not k.db.settings.itemBindings['druid.wrath.caster'])
    assert(actionFor(k,'druid.wrath.caster').spellName=='Rejuvenation')
end

function Tests.library_item_choices_and_explicit_empty_roundtrip_without_code()
    local k=libraryInit()
    assert(k.Library:Place({descriptor={kind='item',itemID=1251}},'druid.wrath.caster'))
    assert(k.Items:AddAlternative('druid.wrath.caster',2581))
    assert(k.Items:SetBindingItem('druid.wrath.caster',nil))
    local payload=k:Export('Leveling'); assert(k:Import(payload))
    local record=k.db.settings.itemBindings['druid.wrath.caster']
    assert(record.empty and not record.selected and #record.alternatives==2)
    local a=actionFor(k,'druid.wrath.caster'); assert(not a.known and not a.itemSelectedID,'Cleared selection revived the original item descriptor')
    assert(not k:Import(payload..'\ni\tLeveling\tdruid.wrath.caster\tcode\t/run Evil()'))
end

function Tests.many_saved_presets_do_not_rebuild_inactive_layouts_during_apply()
    local k=libraryInit(); assert(k.Presets:SetHotkey('Leveling','SHIFT-F24'))
    for i=1,45 do assert(k.Presets:Create('Saved mode '..i,true)) end
    local build=k.Planner.Build; local calls=0
    k.Planner.Build=function(self,...) calls=calls+1; return build(self,...) end
    assert(k:Apply()); assert(calls==1,'Apply rebuilt inactive preset plans: '..calls)
end

function Tests.library_category_and_search_refreshes_reuse_cached_spell_metadata()
    local k=libraryInit(); k.Library:List({tab='spells',showRanks=true})
    local ranks=k.API.GetSpellRanks; local calls=0
    k.API.GetSpellRanks=function(self,...) calls=calls+1; return ranks(self,...) end
    k.Library:List({tab='spells',showRanks=true,query='Wrath'})
    k.Library:List({tab='spells',showRanks=true,category='Balance'})
    assert(calls==0,'Filtering the same spellbook rescanned rank metadata')
end

function Tests.retired_custom_bar_options_are_imported_as_ignored_migration_fields()
    local k=libraryInit()
    assert(not k.defaults.showBars and not k.defaults.prowlPage and not k.defaults.barScale)
    assert(k:Import('KBO1\ns\tshowBars\tboolean\tfalse\ns\tprowlPage\tboolean\ttrue\ns\tbarScale\tnumber\t1.1\na\tLeveling'))
    assert(k.db.settings.showBars==nil and k.db.settings.prowlPage==nil and k.db.settings.barScale==nil)
    local payload=k:Export(k.db.activePreset)
    assert(not payload:find('showBars',1,true) and not payload:find('prowlPage',1,true) and not payload:find('barScale',1,true))
end
