-- Assertions exercise real modules. Added as public module APIs stabilize.
Tests={}
local function init()
  TestAddon:Init()
  return TestAddon
end
local function contains(s,needle) return type(s)=="string" and s:find(needle,1,true)~=nil end
local function equal(actual,expected,label)
  assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
function Tests.modules_load_in_lua51()
  assert(TestAddon,"Addon namespace missing")
  assert(type(TestAddon.Preview)=="function","Preview unavailable")
  assert(type(TestAddon.Apply)=="function","Apply unavailable")
  assert(type(TestAddon.Restore)=="function","Restore unavailable")
end

function Tests.reused_spell_id_never_binds_a_different_named_ability()
  local k=init()
  Mock:Learn(900800,"Expected Spell")
  Mock:Learn(900801,"Different Spell")
  local book=k.API:ScanSpellbook()
  local result=k.API:Resolve({name="Expected Spell",spellIDs={900801}},book)
  equal(result.name,"Expected Spell","English name must win over reused ID")
  equal(k.API:Resolve({name="Missing Spell",spellIDs={900801}},book),nil,"Wrong named spell must not become a known action")
end

function Tests.applied_form_macro_flavor_ignores_staged_profile_changes()
  local k=init()
  k:GetSettings().flavor="era"
  local body=k.Macros:Build({known=true,spellName="Cat Form",label="Cat Form",targeting="form",formType="cat"},{flavor="forever",cancelForUtility=true})
  assert(not contains(body,"/cancelform"),"Staged Era setting leaked into applied Forever macro")
end

function Tests.rebinding_a_system_control_releases_its_previous_key()
  local k=init()
  local original=GetBindingAction("J")
  assert(k:Apply())
  k:GetSettings().bindingOverrides["system.TOGGLECHARACTER0"]="CTRL-NUMPAD9"
  local ok,why=k:Apply(); assert(ok,why)
  equal(GetBindingAction("J"),original,"Previous system control restored")
  equal(GetBindingAction("CTRL-NUMPAD9"),"TOGGLECHARACTER0","New character control applied")
end

function Tests.spellbook_collapses_ranks_and_resolves_highest_learned()
  local k=init()
  local book=k.API:ScanSpellbook()
  local count=0
  for _,s in ipairs(book.list) do if s.name=="Wrath" then count=count+1 end end
  equal(count,1,"Wrath actions")
  assert(book.byID[5176] and book.byID[5177],"All rank IDs must remain resolvable")
  local resolved=k.API:Resolve({name="Wrath",spellIDs={5176}},book)
  equal(resolved.id,5177,"highest learned Wrath")
end

function Tests.spellbook_omits_passives_and_future_spells()
  local k=init()
  Mock:Learn(999001,"Test Passive")
  Mock.spells[#Mock.spells].passive=true
  local book=k.API:ScanSpellbook()
  assert(not book.byName["Test Passive"],"Passive must not become a combat bind")
  equal(#book.passives,1,"passive count")
  local original=C_SpellBook.GetSpellBookItemInfo
  C_SpellBook.GetSpellBookItemInfo=function(i,bank)
    local row=original(i,bank)
    if row and row.spellID==2912 then row.itemType=Enum.SpellBookItemType.FutureSpell end
    return row
  end
  book=k.API:ScanSpellbook()
  assert(not book.byName.Starfire,"Future spell must not be considered learned")
end

function Tests.classic_spellbook_fallback_collapses_ranks()
  local k=init()
  C_SpellBook=nil
  Mock.build="1.15.9"
  WOW_PROJECT_ID=WOW_PROJECT_CLASSIC
  equal(k.API:GetFlavor(),"era","classic flavor")
  local book=k.API:ScanSpellbook()
  assert(#book.list>30,"Classic spellbook was not read")
  equal(k.API:Resolve({name="Wrath",spellIDs={5176}},book).id,5177,"classic rank resolution")
end

function Tests.native_form_description_uses_runtime_indices_and_movement_base_page()
  local k=init()
  Mock.forms={ {id=768,name="Cat Form"},{id=5487,name="Bear Form"},{id=783,name="Travel Form"} }
  local forms=k.API:GetForms()
  equal(forms.cat.index,1,"Runtime Cat index")
  equal(forms.bear.index,2,"Runtime Bear index")
  equal(k.API:ActionPageForForm("prowl"),"cat","Prowl keeps native Cat page")
  equal(k.API:ActionPageForForm("travel"),"caster","Travel keeps native Base page")
  equal(k.API:ActionPageForForm("aquatic"),"caster","Aquatic keeps native Base page")
  Mock.formIndex=1; equal(k.API:GetActiveActionPage(k:GetSettings(),forms),"cat","Current Cat page")
  Mock.formIndex=2; equal(k.API:GetActiveActionPage(k:GetSettings(),forms),"bear","Current Bear page")
end

function Tests.key_normalization_handles_grave_and_modifiers()
  local k=init()
  equal(k.API:NormalizeKey("shift-ctrl-q"),"CTRL-SHIFT-Q","modifier order")
  equal(k.API:NormalizeKey("alt-grave"),"ALT-`","grave normalization")
  equal(k.API:NormalizeKey("shift-shift-q"),nil,"duplicate modifier")
  equal(k.API:NormalizeKey("q\n/run dangerous"),nil,"malformed input")
end

function Tests.import_is_data_only_and_rejects_malformed_profiles()
  local k=init()
  local original=k:Export()
  Mock:ResetWrites()
  for _,payload in ipairs({"_G.KBO_PWNED=true", "KBO1\n/run _G.KBO_PWNED=true", "KBO1\ns\twheel\tboolean\tmaybe", "KBO1\nm\tBUTTON2", "KBO1\na\tMissing", string.rep("x",100001)}) do
    local ok=k:Import(payload)
    assert(not ok,"Accepted malformed profile")
  end
  equal(_G.KBO_PWNED,nil,"import side effects")
  equal(k:Export(),original,"failed import preserves settings")
  equal(#Mock.writes,0,"import protected writes")
end

function Tests.help_macro_prioritizes_alt_and_has_no_implicit_self_fallback()
  local k=init()
  local body=k.Macros:Build({known=true,spellName="Rejuvenation",label="Rejuvenation",targeting="help"},k:GetSettings())
  local alt=assert(body:find("[mod:alt,@player]",1,true),"Alt self clause missing")
  local mouse=assert(body:find("[@mouseover,help,nodead]",1,true),"Mouseover clause missing")
  local target=assert(body:find("[help,nodead]",1,true),"Friendly target clause missing")
  assert(alt<mouse and mouse<target,"Target precedence changed")
  assert(not contains(body,"[]"),"Unexpected unconditional target fallback")
  assert(not contains(body,"][@player]"),"Unexpected implicit self fallback")
  k:GetSettings().selfFallback=true
  body=k.Macros:Build({known=true,spellName="Rejuvenation",label="Rejuvenation",targeting="help"},k:GetSettings())
  assert(contains(body,"[help,nodead][@player]"),"Explicit self fallback ignored")
end

local function formMacroEffects(body,currentForm,destinationForm)
  -- A deliberately small interpreter for the generated form macro subset.
  -- Count eligible casts even when ! would allow a client-specific powershift.
  local effects={form=currentForm,casts=0,cancels=0}
  for line in body:gmatch("[^\n]+") do
    local command,args=line:match("^(/%a+)%s*(.*)$")
    if command=="/cast" or command=="/cancelform" then
      local clause=args:match("^%[([^%]]+)%]")
      local permitted=true
      if clause then
        local n=clause:match("^noform:(%d+)$")
        assert(n,"Unexpected form-test condition: "..clause)
        permitted=effects.form~=tonumber(n)
      end
      if permitted then
        if command=="/cast" then effects.casts=effects.casts+1; effects.form=destinationForm
        else effects.cancels=effects.cancels+1; effects.form=0 end
      end
    end
  end
  return effects
end

function Tests.form_selection_never_recasts_active_form_across_clients()
  local k=init()
  local action={known=true,spellName="Cat Form",label="Cat Form",targeting="form",formType="cat"}
  for _,flavor in ipairs({"forever","era","retail"}) do
    k:GetSettings().flavor=flavor
    for _,catIndex in ipairs({1,3}) do
      Mock.forms={{id=5487,name="Bear Form"},{id=1066,name="Aquatic Form"},{id=768,name="Cat Form"}}
      if catIndex==1 then Mock.forms[1],Mock.forms[3]=Mock.forms[3],Mock.forms[1] end
      local body,err=k.Macros:Build(action,k:GetSettings()); assert(body,err)
      local same=formMacroEffects(body,catIndex,catIndex)
      equal(same.casts,0,flavor.." repeat form cast")
      equal(same.cancels,0,flavor.." repeat form cancellation")
      equal(same.form,catIndex,flavor.." repeat final form")
      for _,startingForm in ipairs({0,2}) do
        local changed=formMacroEffects(body,startingForm,catIndex)
        equal(changed.casts,1,flavor.." selects requested form")
        equal(changed.form,catIndex,flavor.." selected final form")
      end
    end
  end
  Mock.forms={}
  local body,err=k.Macros:Build(action,k:GetSettings())
  assert(not body and err,"Unresolved form index must block an unsafe unguarded cast")
end

function Tests.explicit_powershift_remains_separate_from_form_selection()
  local k=init()
  k:GetSettings().flavor="era"
  local body=k.Macros:Build({known=true,spellName="Cat Form",label="Powershift",targeting="form",formType="cat",powerShift=true},k:GetSettings())
  local effects=formMacroEffects(body,3,3)
  equal(effects.cancels,1,"intentional powershift cancellation")
  equal(effects.casts,1,"intentional powershift recast")
  body=k.Macros:Build({known=true,spellName="Prowl",label="Prowl",targeting="none",nonToggle=true},k:GetSettings())
  assert(contains(body,"/cast !Prowl"),body)
end

function Tests.resurrection_and_focus_macros_require_explicit_valid_units()
  local k=init()
  local body=k.Macros:Build({known=true,spellName="Rebirth",label="Rebirth",targeting="dead"},k:GetSettings())
  assert(contains(body,"[@mouseover,help,dead][help,dead]"),body)
  assert(not contains(body,"@player"),"Resurrection must not self-cast")
  body=k.Macros:Build({known=true,spellName="Bash",label="Bash focus",targeting="focus"},k:GetSettings())
  assert(contains(body,"[@focus,harm,nodead]"),body)
  assert(not contains(body,"[]"),"Missing focus must not hit current target")
end

function Tests.trinket_macros_follow_slots_and_bag_macros_follow_item_ids()
  local k=init()
  for _,slot in ipairs({13,14}) do
    local body=k.Macros:Build({known=true,itemSlot=slot,label="Trinket"},k:GetSettings())
    equal(body,"#showtooltip "..slot.."\n/use "..slot,"trinket slot macro")
  end
  local body=k.Macros:Build({known=true,itemID=5512,label="Healthstone"},k:GetSettings())
  assert(contains(body,"/use item:5512"),body)
end

function Tests.macro_budget_deduplicates_and_counts_both_banks()
  local k=init()
  local plan={actions={{known=true,body="/use 13"},{known=true,body="/use 13"},{known=true,body="/use 14"},{known=false,body="/use 15"}}}
  local needed,available=k.Macros:Budget(plan)
  equal(needed,2,"distinct macros")
  equal(available,149,"free macro slots")
  local name=k.Macros:Name("/use 13")
  CreateMacro(name,1,"/use 13",true)
  k.db.ownedMacros[name]="/use 13"
  needed=k.Macros:Budget(plan)
  equal(needed,1,"owned matching macro reuse")
  EditMacro(GetMacroIndexByName(name),nil,nil,"/say user edited")
  needed=k.Macros:Budget(plan)
  equal(needed,2,"edited macro not reused")
end

function Tests.macro_body_length_is_checked()
  local k=init()
  local body,err=k.Macros:Build({known=true,spellName=string.rep("S",240),label="Too long",targeting="help"},k:GetSettings())
  equal(body,nil,"oversized macro")
  assert(err and contains(err,"255"),"Missing macro length explanation")
end

function Tests.on_use_items_distinguish_equipped_and_bag_equipment()
  local k=init()
  Mock.itemInfo[1001]={name="Use Trinket",effect="Power",equipLoc="INVTYPE_TRINKET"}
  Mock.itemInfo[1002]={name="Bag Trinket",effect="Other Power",equipLoc="INVTYPE_TRINKET"}
  Mock.itemInfo[1003]={name="Healing Potion",effect="Heal"}
  Mock.itemInfo[1004]={name="Passive Ring",equipLoc="INVTYPE_FINGER"}
  Mock.equipment[13]=1001
  Mock.bagItems[0]={{id=1002},{id=1003,count=3},{id=1003,count=4},{id=1004}}
  local list=k.Items:Scan()
  equal(#list,3,"on-use candidates")
  local equipped=k.Items:Resolve(1001)
  equal(equipped.slot,13,"equipped slot")
  assert(not equipped.requiresEquip,"Equipped item incorrectly requires equip")
  assert(k.Items:Resolve(1002).requiresEquip,"Bag gear must require equip")
  equal(k.Items:Resolve(1003).count,7,"bag stack aggregation")
end

function Tests.item_preset_changes_stage_only_and_equipping_is_blocked_in_combat()
  local k=init()
  Mock:ResetWrites()
  assert(k.Items:Select("utility",1002))
  assert(k.Items:SetPreset("PvP"))
  equal(#Mock.writes,0,"item selection writes")
  k.db.presets.PvP.equipment={[13]=1002}
  Mock.combat=true
  local ok=k.Items:EquipPreset("PvP")
  assert(not ok,"Combat equipment change accepted")
  equal(#Mock.writes,0,"combat equipment writes")
end

function Tests.missing_gear_preflight_does_not_partially_equip()
  local k=init()
  k.db.presets.Leveling.equipment={[13]=1002,[14]=1003}
  Mock.itemInfo[1002]={name="Owned",effect="Power",equipLoc="INVTYPE_TRINKET"}
  Mock.bagItems[0]={{id=1002}}
  Mock:ResetWrites()
  assert(not k.Items:EquipPreset("Leveling"),"Missing gear set accepted")
  equal(#Mock.writes,0,"partial equip writes")
end

function Tests.class_catalogs_have_unique_ids_and_no_overlapping_default_keys()
  local k=init()
  for _,class in ipairs({"DRUID","MAGE","WARRIOR","ROGUE","HUNTER","PRIEST","PALADIN","SHAMAN","WARLOCK"}) do
    for _,flavor in ipairs({"forever","era"}) do
      local list=k.Profiles:Get(class,flavor)
      assert(#list>20,"Missing class catalog: "..class)
      local ids={}
      for i,a in ipairs(list) do
        assert(not ids[a.id],"Duplicate action ID "..a.id)
        ids[a.id]=true
        assert(not contains(a.key,"ALT-"),"Class action occupies Alt: "..a.id)
        for j=i+1,#list do
          local b=list[j]
          local af,bf=a.form or "all",b.form or "all"
          assert(a.key~=b.key or (af~=bf and af~="all" and bf~="all"),"Overlapping defaults: "..a.id.." and "..b.id)
        end
      end
    end
  end
end

function Tests.preview_binds_every_distinct_active_spell_without_writes()
  local k=init()
  Mock:Learn(999002,"Unknown Future Active Spell")
  Mock:ResetWrites()
  local plan=k:Preview()
  equal(#plan.errors,0,table.concat(plan.errors,"; "))
  equal(plan.coverage.bound,plan.coverage.total,"coverage")
  equal(#plan.coverage.missing,0,"missing coverage")
  local found=false
  for _,a in ipairs(plan.actions) do if a.spellID==999002 then found=a.key and a.known end end
  assert(found,"Newly learned spell lacks explicit fallback binding")
  equal(#Mock.writes,0,"preview writes")
end

function Tests.wheel_disabled_restores_zoom_and_rehomes_abilities()
  local k=init()
  k:GetSettings().wheel=false
  local plan=k:Preview()
  equal(#plan.errors,0,table.concat(plan.errors,"; "))
  local zoomUp,zoomDown=false,false
  for _,a in ipairs(plan.actions) do
    if a.kind~="system" then assert(not contains(a.key,"MOUSEWHEEL"),"Wheel ability remains: "..a.id) end
    if a.key=="MOUSEWHEELUP" and a.command=="CAMERAZOOMIN" then zoomUp=true end
    if a.key=="MOUSEWHEELDOWN" and a.command=="CAMERAZOOMOUT" then zoomDown=true end
  end
  assert(zoomUp and zoomDown,"Normal camera zoom not restored")
  equal(plan.coverage.bound,plan.coverage.total,"coverage without wheel")
end

function Tests.no_mouse_or_ctrl_profile_retains_complete_keyboard_coverage()
  local k=init()
  local s=k:GetSettings()
  s.mouseButtons={}; s.middle=false; s.wheel=false; s.ctrl=false
  local plan=k:Preview()
  equal(#plan.errors,0,table.concat(plan.errors,"; "))
  for _,a in ipairs(plan.actions) do
    if a.kind~="system" then
      assert(not contains(a.key,"BUTTON"),"Mouse bind remains: "..a.id)
      assert(not contains(a.key,"MOUSEWHEEL"),"Wheel bind remains: "..a.id)
      assert(not contains(a.key,"CTRL-"),"Ctrl bind remains: "..a.id)
    end
  end
  equal(plan.coverage.bound,plan.coverage.total,"keyboard-only coverage")
end

function Tests.custom_collisions_and_combat_alt_bindings_are_rejected()
  local k=init()
  k:GetSettings().bindingOverrides["druid.wrath.caster"]="F"
  local plan=k:Preview()
  assert(#plan.errors>0,"Overlapping custom bind accepted")
  k:GetSettings().bindingOverrides["druid.wrath.caster"]="ALT-Q"
  plan=k:Preview()
  assert(#plan.errors>0,"Alt combat bind accepted")
end

function Tests.full_macro_banks_fail_preflight_without_mutation()
  local k=init()
  for i=1,150 do Mock.macros[i]={name="Existing"..i,icon=1,body="/say "..i} end
  Mock:ResetWrites()
  local plan=k:Preview()
  equal(plan.macrosAvailable,0,"full banks capacity")
  assert(#plan.errors>0,"Full banks accepted")
  equal(#Mock.writes,0,"capacity preview mutations")
end

function Tests.successful_import_roundtrip_stages_only()
  local k=init()
  local s=k:GetSettings()
  s.wheel=false; s.mouseButtons={BUTTON4=true,BUTTON8=true}
  s.bindingOverrides["druid.wrath.caster"]="SHIFT-H"
  k.db.presets.PvP.items.utility=5512
  k.db.activePreset="PvP"
  local exported=k:Export()
  s.wheel=true; s.mouseButtons={}
  Mock:ResetWrites()
  local ok,err=k:Import(exported)
  assert(ok,err)
  equal(k:GetSettings().wheel,false,"import wheel")
  assert(k:GetSettings().mouseButtons.BUTTON8,"import observed mouse buttons")
  equal(k:GetSettings().bindingOverrides["druid.wrath.caster"],"SHIFT-H","import binding")
  equal(k.db.presets.PvP.items.utility,5512,"import item")
  equal(k.db.activePreset,"PvP (2)","import selects a safely renamed copy")
  equal(#Mock.writes,0,"import writes")
end

local function sameMap(a,b,label)
  for key,value in pairs(a) do equal(b[key],value,(label or "map").."["..tostring(key).."]") end
  for key,value in pairs(b) do equal(a[key],value,(label or "map").." extra ["..tostring(key).."]") end
end

function Tests.apply_and_restore_preserve_original_bindings_settings_and_personal_macros()
  local k=init()
  local originalBindings=k.Copy(Mock.bindings)
  local originalCharacter=k.Copy(Mock.bindingSets[2])
  local originalModified=k.Copy(Mock.modified)
  local originalCVars=k.Copy(Mock.cvars)
  local ok,err=k:Apply()
  assert(ok,err)
  assert(k.db.enabled and k.db.backup,"Applied state not persisted")
  equal(Mock.modified.SELFCAST,"ALT","installed self-cast")
  equal(Mock.modified.FOCUSCAST,"NONE","installed focus modifier")
  equal(Mock.cvars.autoSelfCast,"0","installed auto self-cast")
  assert(contains(Mock.bindings.T,"MULTIACTIONBAR"),"Trinket key not installed on an original bar")
  local userName,_,body=GetMacroInfo(GetMacroIndexByName("UserMacro"))
  equal(userName,"UserMacro","personal macro name")
  equal(body,"/say preserved","personal macro body")
  ok,err=k:Restore()
  assert(ok,err)
  sameMap(Mock.bindings,originalBindings,"restored active bindings")
  sameMap(Mock.bindingSets[2],originalCharacter,"restored inactive character bindings")
  sameMap(Mock.modified,originalModified,"restored modifiers")
  sameMap(Mock.cvars,originalCVars,"restored CVars")
  equal(GetMacroInfo(GetMacroIndexByName("UserMacro")),"UserMacro","personal macro survives Restore")
  local account,character=GetNumMacros()
  equal(account+character,1,"generated macros removed")
end

function Tests.repeated_apply_preserves_first_backup_and_does_not_duplicate_macros()
  local k=init()
  local original=k.Copy(Mock.bindings)
  assert(k:Apply())
  local a,c=GetNumMacros(); local count=a+c
  local ok,err=k:Apply()
  assert(ok,err)
  a,c=GetNumMacros()
  equal(a+c,count,"repeat apply macro count")
  assert(k:Restore())
  sameMap(Mock.bindings,original,"original first baseline")
end

function Tests.apply_restore_and_activate_make_no_protected_writes_in_combat()
  local k=init()
  assert(k:Apply())
  Mock:ResetWrites(); Mock.combat=true
  local ok=k:Apply(); assert(not ok,"Apply allowed in combat")
  ok=k:Restore(); assert(not ok,"Restore allowed in combat")
  ok=k.Engine:Activate(k.db.appliedPlan); assert(not ok,"Activate allowed in combat")
  k:UpdateSetting("wheel",false)
  equal(#Mock.writes,0,"combat protected writes")
  assert(k.db.enabled,"Combat failed operation disabled previous setup")
end

function Tests.invalid_plan_apply_is_a_no_op()
  local k=init()
  k:GetSettings().bindingOverrides["druid.wrath.caster"]="F"
  Mock:ResetWrites()
  local ok=k:Apply()
  assert(not ok,"Invalid plan applied")
  equal(#Mock.writes,0,"invalid-plan mutations")
end

function Tests.full_macro_capacity_apply_is_a_no_op()
  local k=init()
  for i=1,150 do Mock.macros[i]={name="Existing"..i,icon=1,body="/say "..i} end
  Mock:ResetWrites()
  assert(not k:Apply(),"Full macro banks applied")
  equal(#Mock.writes,0,"full-bank apply mutations")
end

function Tests.apply_failure_rolls_back_partial_writes()
  local k=init()
  local original=k.Copy(Mock.bindings)
  local character=k.Copy(Mock.bindingSets[2])
  local modified=k.Copy(Mock.modified)
  local cvars=k.Copy(Mock.cvars)
  local realSet=SetBinding
  local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and key=="T" and command and command:find("^MULTIACTIONBAR") then rejected=true; return false end
    return realSet(key,command,...)
  end
  local ok,err=k:Apply()
  assert(not ok and contains(err,"rolled back"),err)
  assert(rejected,"Failure injection did not run")
  sameMap(Mock.bindings,original,"error rollback bindings")
  sameMap(Mock.bindingSets[2],character,"error rollback inactive bindings")
  sameMap(Mock.modified,modified,"error rollback modifiers")
  sameMap(Mock.cvars,cvars,"error rollback settings")
  local a,c=GetNumMacros(); equal(a+c,1,"error rollback macros")
  assert(not k.db.enabled,"Failed first apply marked enabled")
end

function Tests.restore_preserves_user_edited_generated_macro()
  local k=init()
  assert(k:Apply())
  local ownedName=next(k.db.ownedMacros)
  local idx=GetMacroIndexByName(ownedName)
  EditMacro(idx,nil,nil,"/say now my own content")
  assert(k:Restore())
  idx=GetMacroIndexByName(ownedName)
  assert(idx>0,"Restore deleted user-edited generated macro")
  local _,_,body=GetMacroInfo(idx)
  equal(body,"/say now my own content","edited macro text")
  equal(GetMacroInfo(GetMacroIndexByName("UserMacro")),"UserMacro","original personal macro")
end

function Tests.native_actions_follow_macro_indices_after_unrelated_macro_deletion()
  local k=init()
  CreateMacro("000 Unrelated",1,"/say unrelated",false)
  assert(k:Apply())
  -- Delete unrelated first account macro; generated account indices may move.
  DeleteMacro(GetMacroIndexByName("000 Unrelated"))
  local ok,err=k.Engine:Activate(k.db.appliedPlan)
  assert(ok,err)
  for _,a in ipairs(k.db.appliedPlan.actions) do
    if a.body and a.nativeSlot then
      local kind,index=GetActionInfo(a.nativeSlot)
      equal(kind,"macro","Native action kept its macro")
      equal(index,GetMacroIndexByName(a.macroName),"Native macro index follows game remapping")
    end
  end
end

function Tests.original_bar_paging_changes_combat_actions_and_keeps_support_accessible()
  local k=init()
  assert(k:Apply())
  assert(not k.Engine.dock and not next(k.Engine.buttons),"Custom action buttons were created")
  local heal=Mock:NativeActionFor("Q")
  Mock.combat=true
  Mock:ResetWrites()
  for _,state in ipairs({{0,1},{1,9},{2,1},{3,7},{4,1},{5,10}}) do
    Mock.formIndex=state[1]
    equal(Mock:NativePage(),state[2],"Native page for form "..state[1])
    equal(Mock:NativeActionFor("1"),Mock.actions[(state[2]-1)*12+1],"Game owns primary page")
    equal(Mock:NativeActionFor("Q"),heal,"Support binding moved with form")
  end
  Mock.vehiclePage=11; Mock.actions[121]={"spell",990999}
  equal(Mock:NativeActionFor("1"),Mock.actions[121],"Native override page dispatch")
  equal(#Mock.writes,0,"Form changes triggered addon protected writes")
end

function Tests.fully_learned_class_catalogs_pass_planner_validation()
  local k=init()
  for _,class in ipairs({"DRUID","MAGE","WARRIOR","ROGUE","HUNTER","PRIEST","PALADIN","SHAMAN","WARLOCK"}) do
    for _,flavor in ipairs({"forever","era"}) do
      k:GetSettings().flavor=flavor; Mock.class=class; Mock.spells={}
      local seen={}; local synthetic=900000
      for _,d in ipairs(k.Profiles:Get(class,flavor)) do
        if not seen[d.name] then
          synthetic=synthetic+1
          Mock:Learn((d.spellIDs and d.spellIDs[1]) or synthetic,d.name)
          seen[d.name]=true
        end
      end
      local plan=k:Preview()
      equal(#plan.errors,0,class.." "..flavor..": "..table.concat(plan.errors,"; "))
      equal(plan.coverage.bound,plan.coverage.total,class.." coverage")
    end
  end
end

function Tests.ui_opens_and_closes_without_installing_anything()
  local k=init()
  Mock:ResetWrites()
  k.UI:Toggle()
  assert(k.UI.frame and k.UI.frame:IsShown(),"Options window did not open")
  k.UI:Toggle()
  assert(not k.UI.frame:IsShown(),"Options window did not close")
  equal(#Mock.writes,0,"opening UI changed game settings")
end

function Tests.personal_macro_name_collision_is_preserved_and_generated_suffix_reused()
  local k=init()
  local body="#showtooltip 13\n/use 13"
  local generatedName=k.Macros:Name(body)
  CreateMacro(generatedName,1,"/say personal collision",false)
  local ok,err=k:Apply(); assert(ok,err)
  local a,c=GetNumMacros(); local count=a+c
  ok,err=k:Apply(); assert(ok,err)
  a,c=GetNumMacros()
  equal(a+c,count,"suffix-owned macro reused on repeated apply")
  local _,_,current=GetMacroInfo(GetMacroIndexByName(generatedName))
  equal(current,"/say personal collision","personal name collision preserved")
end

function Tests.all_mouse_option_combinations_remain_collision_free()
  local k=init()
  local s=k:GetSettings()
  for _,wheel in ipairs({true,false}) do
    for _,middle in ipairs({true,false}) do
      for _,ctrl in ipairs({true,false}) do
        for _,sideCount in ipairs({0,1,2}) do
          s.wheel,s.middle,s.ctrl=wheel,middle,ctrl
          s.mouseButtons={}; if sideCount>0 then s.mouseButtons.BUTTON4=true end; if sideCount>1 then s.mouseButtons.BUTTON5=true end
          local plan=k:Preview()
          equal(#plan.errors,0,"hardware option combination: "..table.concat(plan.errors,"; "))
          equal(plan.coverage.bound,plan.coverage.total,"option combination coverage")
        end
      end
    end
  end
end

function Tests.reapply_failure_preserves_prior_applied_layout()
  local k=init()
  assert(k:Apply())
  local original=k.Copy(Mock.bindings)
  local originalPlan=k.Copy(k.db.appliedPlan)
  local beforeAccount,beforeCharacter=GetNumMacros()
  k:GetSettings().wheel=false
  local real=SetBinding
  local rejected=false
  SetBinding=function(key,command,...)
    if not rejected and key=="T" and command and command:find("^MULTIACTIONBAR") then rejected=true; return false end
    return real(key,command,...)
  end
  local ok,err=k:Apply()
  assert(not ok and contains(err,"rolled back"),err)
  assert(k.db.enabled,"Prior enabled layout lost")
  sameMap(Mock.bindings,original,"previous applied bindings after failure")
  equal(k.db.appliedPlan.settings.wheel,originalPlan.settings.wheel,"saved prior plan")
  local a,c=GetNumMacros(); equal(a+c,beforeAccount+beforeCharacter,"failed reapply macros")
end

function Tests.cvar_write_rejection_is_not_silently_reported_as_success()
  local k=init()
  C_CVar.SetCVar=function(name,value) if name=="autoSelfCast" then return nil end; return SetCVar(name,value) end
  local ok,err=k:Apply()
  assert(not ok,"Apply reported success even though autoSelfCast remained enabled")
  equal(Mock.cvars.autoSelfCast,"1","rejected CVar remains baseline")
end

function Tests.era_emergency_heal_combo_respects_form_cancellation_setting()
  local k=init()
  k.playerClass="DRUID"; k:GetSettings().flavor="era"
  Mock:Learn(17116,"Nature's Swiftness")
  local action={known=true,spellName="Nature's Swiftness",label="Emergency heal",combo={17116,5185},cancelForm=true,targeting="self"}
  local body=k.Macros:Build(action,k:GetSettings())
  assert(contains(body,"/cancelform"),"Classic emergency heal combo cannot cast from Cat/Bear without leaving form")
  assert(contains(body,"/cast [@player] Healing Touch"),body)
  k:GetSettings().cancelForUtility=false
  body=k.Macros:Build(action,k:GetSettings())
  assert(not contains(body,"/cancelform"),"Disabled form cancellation ignored")
end

function Tests.help_spells_that_cannot_target_self_do_not_consume_alt()
  local k=init()
  k:GetSettings().selfFallback=true
  local body=k.Macros:Build({known=true,spellName="Divine Grace",label="Divine Grace",targeting="help",noSelf=true},k:GetSettings())
  assert(not contains(body,"@player"),"Non-self spell contains a self-cast route")
  assert(contains(body,"[nomod:alt,@mouseover,help,nodead][nomod:alt,help,nodead]"),body)
  Mock.class="PRIEST"; Mock:Learn(990046,"Divine Grace")
  local found=false
  for _,a in ipairs(k:Preview().actions) do
    if a.spellName=="Divine Grace" then
      found=true
      assert(a.noSelf,"Divine Grace metadata allows invalid self-target")
      equal(a.selfKey,nil,"No-self spell consumes Alt binding")
    end
  end
  assert(found,"Divine Grace test fixture not resolved")
end

function Tests.unknown_spell_binding_identity_survives_learning_a_higher_rank()
  local k=init()
  Mock:Learn(900001,"Uncatalogued Spell","Rank 1")
  local first
  for _,a in ipairs(k:Preview().actions) do if a.spellName=="Uncatalogued Spell" then first=a end end
  assert(first and first.key,"Unknown spell was not assigned")
  k:GetSettings().bindingOverrides[first.id]="SHIFT-H"
  Mock:Learn(900002,"Uncatalogued Spell","Rank 2")
  local second
  for _,a in ipairs(k:Preview().actions) do if a.spellName=="Uncatalogued Spell" then second=a end end
  equal(second.id,first.id,"spell-family stable action identity")
  equal(second.key,"SHIFT-H","rank upgrade custom binding")
  equal(second.spellID,900002,"rank upgrade spell ID")
end

function Tests.extra_observed_mouse_buttons_are_used_without_phantom_inputs()
  local k=init()
  k:GetSettings().mouseButtons.BUTTON8=true
  Mock:Learn(900001,"Uncatalogued Mouse Spell")
  local plan=k:Preview()
  local found=false
  for _,a in ipairs(plan.actions) do
    if a.spellName=="Uncatalogued Mouse Spell" then found=true; assert(a.key:match("BUTTON8$"),"Observed extra button was not used for overflow: "..a.key) end
    assert(not contains(a.key,"BUTTON6") and not contains(a.key,"BUTTON7"),"Allocated unobserved side button")
  end
  assert(found,"Fixture spell missing")
end

local function swapCatAndBear()
  Mock.forms[1],Mock.forms[3]=Mock.forms[3],Mock.forms[1]
end

function Tests.form_index_maintenance_updates_guards_in_place_without_rebinding()
  local k=init()
  assert(k:Apply())
  local bindings=k.Copy(Mock.bindings)
  local account,character=GetNumMacros()
  local oldSignature=k.db.appliedPlan.formSignature
  swapCatAndBear()
  Mock:ResetWrites()
  Mock:Fire("UPDATE_SHAPESHIFT_FORMS")
  assert(k.db.enabled,"Form maintenance disabled valid layout")
  assert(k.db.appliedPlan.formSignature~=oldSignature,"Form signature not updated")
  for _,a in ipairs(k.db.appliedPlan.actions) do
    if a.id=="druid.form_cat" then
      local _,_,body=GetMacroInfo(GetMacroIndexByName(a.macroName))
      equal(formMacroEffects(body,1,1).casts,0,"maintained current Cat guard")
      equal(formMacroEffects(body,0,1).casts,1,"maintained Cat selection")
    end
  end
  sameMap(Mock.bindings,bindings,"form maintenance key stability")
  local a,c=GetNumMacros(); equal(a+c,account+character,"in-place form macro count")
  for _,write in ipairs(Mock.writes) do assert(write[1]~="binding" and write[1]~="savebindings","Maintenance reassigned keys") end
end

function Tests.form_maintenance_failure_restores_original_setup()
  local k=init()
  local original=k.Copy(Mock.bindings)
  assert(k:Apply())
  swapCatAndBear()
  local real=EditMacro; local edits=0
  EditMacro=function(...)
    edits=edits+1
    if edits==2 then error("Injected form macro edit failure") end
    return real(...)
  end
  Mock:Fire("UPDATE_SHAPESHIFT_FORMS")
  assert(not k.db.enabled,"Failed form maintenance left stale layout active")
  sameMap(Mock.bindings,original,"form failure restore bindings")
  local a,c=GetNumMacros(); equal(a+c,1,"form failure generated macros cleaned up")
  equal(GetMacroInfo(GetMacroIndexByName("UserMacro")),"UserMacro","form failure personal macro")
end

function Tests.form_maintenance_defers_protected_writes_until_combat_ends()
  local k=init()
  assert(k:Apply())
  local signature=k.db.appliedPlan.formSignature
  swapCatAndBear(); Mock.combat=true; Mock:ResetWrites()
  Mock:Fire("UPDATE_SHAPESHIFT_FORMS")
  equal(#Mock.writes,0,"combat form maintenance writes")
  equal(k.db.appliedPlan.formSignature,signature,"combat signature changed before repair")
  Mock.combat=false
  Mock:Fire("PLAYER_REGEN_ENABLED")
  assert(k.db.appliedPlan.formSignature~=signature,"Queued form maintenance not completed")
end

function Tests.legacy_visual_toggle_does_not_create_or_hide_original_bars()
  local k=init()
  k:GetSettings().showBars=false
  assert(k:Apply())
  assert(not k.Engine.dock,"Legacy visual toggle created a custom dock")
  assert(MainActionBar:IsShown(),"Main original bar hidden")
  assert(Mock.actionToggles[1],"Required original extra bar was not enabled")
  assert(GetActionInfo(1),"Original main bar was not populated")
end

function Tests.mount_collection_and_bag_mounts_roundtrip_and_cast_from_druid_forms()
  local k=init()
  Mock:Learn(458,"Brown Horse")
  C_MountJournal={GetMountIDs=function() return {1,2} end,GetMountInfoByID=function(id)
    return id==1 and "Brown Horse" or "Uncollected Horse",id==1 and 458 or 459,123,false,true,1,false,false,nil,false,id==1
  end}
  local candidates=k.Items:Scan(); local found=false
  for _,item in ipairs(candidates) do
    if item.id=="spell:458" then found=true end
    assert(item.id~="spell:459","Uncollected mount offered")
  end
  assert(found,"Collected mount missing")
  assert(k.Items:Select("mount","spell:458"))
  local exported=k:Export()
  assert(k:Import(exported))
  equal(k.Items:GetSelected("mount"),"spell:458","spell mount import")
  local function mountAction()
    for _,a in ipairs(k:Preview().actions) do if a.id=="item.mount" then return a end end
  end
  local action=mountAction()
  assert(action.known and action.mountSpell,"Mount spell not planned")
  assert(contains(action.body,"/cancelform") and contains(action.body,"/cast [nomounted] Brown Horse"),action.body)
  Mock.itemInfo[5656]={name="Brown Horse Bridle",effect="Brown Horse"}
  Mock.bagItems[0]={{id=5656}}
  assert(k.Items:Select("mount",5656))
  action=mountAction()
  assert(contains(action.body,"/cancelform") and contains(action.body,"/use [nomounted] item:5656"),action.body)
end

function Tests.modern_pet_spellbank_is_included_without_global_haspetspells()
  local k=init()
  Mock.class="WARLOCK"; HasPetSpells=nil
  Mock.petSpells={{id=19647,name="Spell Lock",passive=false},{id=990090,name="Pet Passive",passive=true}}
  local book=k.API:ScanSpellbook()
  assert(book.byName["Spell Lock"],"Modern pet spell missing")
  assert(not book.byName["Pet Passive"],"Pet passive allocated")
  local plan=k:Preview(); local found=false
  for _,a in ipairs(plan.actions) do if a.spellName=="Spell Lock" and a.known and a.key then found=true end end
  assert(found,"Pet ability has no key")
  equal(plan.coverage.total,plan.coverage.bound,"pet spell coverage")
end

function Tests.emergency_combo_is_not_offered_until_all_components_are_learned()
  local k=init()
  Mock:Learn(17116,"Nature's Swiftness")
  for i=#Mock.spells,1,-1 do if Mock.spells[i].name=="Healing Touch" then table.remove(Mock.spells,i) end end
  local found=false
  for _,a in ipairs(k:Preview().actions) do if a.id=="druid.natures_swiftness_heal" then found=true; assert(not a.known,"Incomplete emergency combo offered as ready") end end
  assert(found,"Emergency combo reservation missing")
end

function Tests.native_override_keeps_linked_main_position_binding()
  local k=init()
  local plan=k:Preview()
  for _,action in ipairs(plan.actions) do
    if action.barSlot==1 then k:GetSettings().bindingOverrides[action.id]="U" end
  end
  assert(k:Apply())
  Mock.vehiclePage=11; Mock.actions[121]={"spell",990999}
  equal(GetBindingAction("U"),"ACTIONBUTTON1","Linked main position binding")
  equal(Mock:NativeActionFor("U"),Mock.actions[121],"Native vehicle page respects linked position binding")
  assert(not k.Engine.override,"Custom vehicle router was reinstated")
end

function Tests.ui_mouse_calibration_and_wheel_checkbox_stage_only()
  local k=init()
  k.UI:Toggle(); Mock:ResetWrites()
  local found=false
  for _,row in ipairs(k.UI.pages.Setup.checks) do if row.settingKey=="wheel" then found=true; row:Click() end end
  assert(found,"Wheel checkbox missing")
  equal(k:GetSettings().wheel,false,"wheel checkbox setting")
  k.UI:BeginCapture("mouse")
  k.UI:CaptureInput("BUTTON8")
  k.UI:CaptureInput("BUTTON8")
  assert(k:GetSettings().mouseButtons.BUTTON8,"Observed mouse button not recorded")
  k.UI:CaptureInput("ESCAPE")
  assert(not k.UI.capture:IsShown() and not k.UI.capture.keyboard,"Capture did not release keyboard")
  equal(#Mock.writes,0,"UI staging made protected writes")
end

function Tests.ui_navigation_keeps_every_configuration_page_reachable()
  local k=init()
  k.UI:Toggle(); Mock:ResetWrites()
  for _,name in ipairs({"Setup","Presets","Bindings","Items","Safety","Share","Setup"}) do
    local navigation=assert(k.UI.nav[name],"Missing navigation for "..name)
    navigation:Click()
    equal(k.UI.activePage,name,"selected options page")
    for other,page in pairs(k.UI.pages) do
      equal(page:IsShown(),other==name,"page visibility "..other)
    end
  end
  assert(k.UI.pages.Setup.checks and #k.UI.pages.Setup.checks>0,"Setup controls missing")
  assert(k.UI.pages.Bindings.search,"Binding search missing")
  assert(k.UI.pages.Items.idInput,"Item selection missing")
  assert(k.UI.pages.Share.transfer,"Dedicated import/export page missing")
  assert(k.UI.pages.Presets.usePreset,"Full preset controls missing")
  assert(k.UI.pages.Safety.restoreSelected,"Named backup recovery missing")
  equal(#Mock.writes,0,"options navigation installed changes")
end

function Tests.ui_key_capture_still_stages_modifier_bindings_and_cancels_cleanly()
  local k=init()
  k.UI:Toggle()
  local action
  for _,a in ipairs(k.UI.plan.actions) do if a.id=="druid.rejuvenation" then action=a end end
  assert(action,"Fixture action not present in binding editor")
  Mock:ResetWrites()
  k.UI:BeginCapture("binding",action)
  IsShiftKeyDown=function() return true end
  k.UI:CaptureInput("H")
  IsShiftKeyDown=function() return false end
  equal(k:GetSettings().bindingOverrides[action.id],"SHIFT-H","captured modifier binding")
  assert(not k.UI.capture.keyboard and not k.UI.capture:IsShown(),"Completed capture retained input focus")
  k.UI:BeginCapture("binding",action)
  k.UI:CaptureInput("ESCAPE")
  equal(k:GetSettings().bindingOverrides[action.id],"SHIFT-H","Escape changed existing binding")
  assert(not k.UI.capture.keyboard and not k.UI.capture:IsShown(),"Cancelled capture retained input focus")
  equal(#Mock.writes,0,"key capture installed game bindings")
end

function Tests.original_bars_receive_real_spells_and_macros_without_custom_dispatch_frames()
  local k=init()
  assert(k:Apply())
  local sawSpell,sawMacro=false,false
  for _,action in pairs(Mock.actions) do
    if action[1]=="spell" then sawSpell=true end
    if action[1]=="macro" then sawMacro=true end
  end
  assert(sawSpell and sawMacro,"Original bars lost a spell or macro action type")
  assert(not k.Engine.dock and not next(k.Engine.buttons),"Custom action buttons still exist")
end

function Tests.native_options_templates_keep_controls_and_close_behavior()
  local k=init()
  k.UI:Toggle()
  equal(k.UI.frame.template,"BasicFrameTemplateWithInset","native options window")
  equal(k.UI.frame.TitleText:GetText(),"Hot Swap","native title region")
  equal(k.UI.apply.template,"UIPanelButtonTemplate","native apply button")
  equal(k.UI.pages.Bindings.search.template,"InputBoxTemplate","native binding search field")
  for name,tab in pairs(k.UI.nav) do
    equal(tab.template,"PanelTabButtonTemplate","native Forever tab "..name)
    equal(tab.selected,name=="Setup","initial selected tab "..name)
  end
  local wheel
  for _,row in ipairs(k.UI.pages.Setup.checks) do if row.settingKey=="wheel" then wheel=row.checkbox end end
  assert(wheel,"Native wheel checkbox missing")
  equal(wheel.template,"UICheckButtonTemplate","native checkbox")
  assert(wheel:GetChecked(),"Native checkbox did not reflect initial setting")
  Mock:ResetWrites()
  wheel:Click()
  assert(not k:GetSettings().wheel and not wheel:GetChecked(),"Native checkbox click did not stage and render")
  k.UI:BeginCapture("mouse")
  k.UI.closeButton:Click()
  assert(not k.UI.frame:IsShown(),"Native close button did not hide options")
  assert(not k.UI.capture.keyboard and not k.UI.capture:IsShown(),"Closing options retained capture input")
  equal(#Mock.writes,0,"Native options controls installed changes")
end

function Tests.native_options_select_classic_tab_template()
  local k=init()
  WOW_PROJECT_ID=WOW_PROJECT_CLASSIC
  k.UI:Toggle()
  for name,tab in pairs(k.UI.nav) do
    equal(tab.template,"CharacterFrameTabButtonTemplate","native Classic tab "..name)
    tab:Click()
    equal(k.UI.activePage,name,"Classic tab navigation")
    assert(tab.selected and k.UI.pages[name]:IsShown(),"Classic selection did not show its page")
  end
end

local function observeCalls(owner,method)
  local original=assert(owner[method],"Cannot observe missing method "..method)
  local observation={count=0}
  owner[method]=function(self,...)
    observation.count=observation.count+1
    return original(self,...)
  end
  return observation
end

function Tests.escape_finishes_mouse_calibration_without_closing_parent_window()
  local k=init(); k.UI:Toggle(); k.UI:BeginCapture("mouse")
  k.UI:CaptureInput("BUTTON8")
  Mock:ResetWrites()
  -- Unlike calling CaptureInput directly, dispatch also runs the default
  -- Escape binding if the handler re-enables keyboard propagation.
  Mock:KeyDown("ESCAPE")
  assert(k.UI.frame:IsShown(),"Same Escape closed calibration AND the options window")
  -- Ending capture may intentionally wait one frame so the same key event
  -- cannot propagate after the keyboard listener is released.
  Mock:Advance(0.032,2)
  assert(k.UI.frame:IsShown(),"Deferred calibration close also closed options")
  assert(not k.UI.capture:IsShown() and not k.UI.capture.keyboard,"Calibration still owns keyboard input")
  assert(k:GetSettings().mouseButtons.BUTTON8,"Escape discarded recorded mouse buttons")
  Mock:KeyDown("ESCAPE")
  assert(not k.UI.frame:IsShown(),"The next Escape must close the ordinary options window")
  equal(#Mock.writes,0,"Escape calibration path changed protected game state")
end

function Tests.escape_special_window_dispatch_closes_only_current_modal()
  local k=init(); k.UI:Toggle(); k.UI:BeginCapture("mouse")
  -- Exercise Blizzard's real live UISpecialFrames loop without first routing
  -- through the frame OnKeyDown callback. OnHide must also end capture safely.
  assert(CloseSpecialWindows(),"Calibration is missing from Escape handling")
  assert(k.UI.frame:IsShown(),"Special-window Escape closed the calibration parent")
  assert(not k.UI.capture:IsShown() and not k.UI.capture.keyboard,"Special-window Escape left capture active")
  Mock:Advance(0.016)
  assert(CloseSpecialWindows(),"Main window was not restored to Escape handling")
  assert(not k.UI.frame:IsShown(),"Main window did not close on the next Escape")
end

function Tests.visible_event_burst_coalesces_into_one_preview_scan()
  local k=init(); k.UI:Toggle()
  local builds=observeCalls(k.Planner,"Build")
  local spells=observeCalls(k.API,"ScanSpellbook")
  local items=observeCalls(k.Items,"Scan")
  Mock:ResetWrites()
  for i=1,100 do
    Mock:Fire("SPELLS_CHANGED")
    Mock:Fire("BAG_UPDATE_DELAYED")
    Mock:Fire("GET_ITEM_INFO_RECEIVED",900000+i,true)
  end
  equal(builds.count,0,"Event handlers rebuilt the plan synchronously")
  Mock:Advance(0.2)
  equal(builds.count,1,"One visible event burst should build one preview")
  equal(spells.count,1,"One visible event burst should scan the spellbook once")
  equal(items.count,1,"One visible event burst should scan inventory once")
  Mock:Advance(0.2)
  equal(builds.count,1,"Settled event burst scheduled another build")
  equal(#Mock.writes,0,"Read-only event refresh wrote protected state")
end

function Tests.hidden_options_do_not_build_plans_for_inventory_or_spell_events()
  local k=init(); k.UI:Toggle(); k.UI:Toggle()
  local builds=observeCalls(k.Planner,"Build")
  local spells=observeCalls(k.API,"ScanSpellbook")
  local items=observeCalls(k.Items,"Scan")
  for i=1,30 do Mock:Fire("SPELLS_CHANGED"); Mock:Fire("BAG_UPDATE_DELAYED") end
  Mock:Advance(0.2)
  equal(builds.count,0,"Hidden options rebuilt a plan")
  equal(spells.count,0,"Hidden options scanned the spellbook")
  equal(items.count,0,"Hidden options scanned inventory")
  k.UI:Toggle()
  equal(builds.count,1,"Opening options did not consume the invalidated state exactly once")
end

function Tests.failed_item_info_notification_does_not_create_a_query_refresh_loop()
  local k=init()
  Mock.bagItems[0]={{id=990099}}
  Mock.onItemRequest=function(id) Mock:Fire("GET_ITEM_INFO_RECEIVED",id,false) end
  local builds=observeCalls(k.Planner,"Build")
  k.UI:Toggle()
  for i=1,8 do Mock:Advance(0.2); k.UI:Refresh() end
  equal(Mock.itemRequests[990099],1,"Uncached failed item was repeatedly requested by its own result event")
  assert(builds.count<=2,"Item result produced an unbounded preview loop: "..builds.count)
  for i=1,100 do Mock:Fire("GET_ITEM_INFO_RECEIVED",990200+i,true) end
  local before=builds.count
  Mock:Advance(0.2)
  equal(builds.count,before,"Unrelated item notifications rebuilt the preview")
end

function Tests.repeated_visible_refresh_reuses_reviewed_plan_without_rescanning()
  local k=init(); k.UI:Toggle()
  local builds=observeCalls(k.Planner,"Build")
  local spells=observeCalls(k.API,"ScanSpellbook")
  local items=observeCalls(k.Items,"Scan")
  for i=1,10 do k.UI:Refresh() end
  equal(builds.count,0,"Rendering the same preview rebuilt the plan")
  equal(spells.count,0,"Rendering the same preview rescanned spells")
  equal(items.count,0,"Rendering the same preview rescanned inventory")
end

function Tests.apply_button_does_not_repeat_heavy_preview_work_in_same_callback()
  local k=init(); k.UI:Toggle()
  local builds=observeCalls(k.Planner,"Build")
  local bindingRows=observeCalls(k.UI,"RenderBindings")
  local inventoryRows=observeCalls(k.UI,"RenderItems")
  local recoveryRows=observeCalls(k.UI,"RenderSafety")
  k.UI.apply:Click()
  assert(k.db.enabled,"Apply click did not install its reviewed plan")
  equal(builds.count,1,"Apply callback immediately built a second complete preview")
  equal(bindingRows.count,0,"Apply on Setup rendered hidden binding rows")
  equal(inventoryRows.count,0,"Apply on Setup rendered hidden inventory rows")
  equal(recoveryRows.count,0,"Apply on Setup rendered hidden recovery rows")
  Mock:Advance(0.2)
  assert(builds.count<=2,"Apply refresh repeatedly rebuilt the plan")
end

function Tests.apply_uses_fresh_spellbook_even_after_ui_preview_was_cached()
  local k=init(); k.UI:Toggle()
  Mock:Learn(990123,"Learned After Preview")
  local ok,why=k:Apply(); assert(ok,why)
  local found=false
  for _,action in ipairs(k.db.appliedPlan.actions) do
    if action.spellName=="Learned After Preview" and action.known and action.key then found=true end
  end
  assert(found,"Apply reused stale cached coverage instead of fresh preflight")
end

function Tests.item_completion_during_preview_is_not_lost_when_build_returns()
  local k=init()
  Mock.bagItems[0]={{id=990110}}
  -- A saved selection can first request its data during the next preview.
  k.db.presets.Leveling.items.utility=990110; k:InvalidatePreview()
  Mock.onItemRequest=function(id)
    Mock.itemInfo[id]={name="Loaded During Scan",effect="Useful effect"}
    Mock:Fire("GET_ITEM_INFO_RECEIVED",id,true)
  end
  k.UI:Toggle()
  Mock:Advance(0.2)
  local selected
  for _,action in ipairs(k.UI.plan.actions) do if action.id=="item.utility" then selected=action end end
  assert(selected and selected.known,"Item completion was overwritten by the preview that requested it")
  equal(Mock.itemRequests[990110],1,"Successful item completion triggered another data request")
end

local function actionByID(plan,id)
  for _,action in ipairs(plan.actions) do if action.id==id then return action end end
  error("Missing action fixture "..id)
end

function Tests.unlearned_spell_metadata_keeps_real_icon_and_localized_tooltip_id_without_casting()
  Mock.class="HUNTER"; Mock.locale="deDE"; Mock.spells={}; Mock.forms={}
  Mock.catalog[19434]={id=19434,name="Gezielter Schuss",icon=135130}
  local k=init(); k:GetSettings().flavor="era"
  local plan=k:Preview()
  local aimed=actionByID(plan,"hunter.aimed_shot")
  equal(aimed.known,false,"Catalog metadata must not imply learned")
  equal(aimed.spellID,nil,"Display lookup supplied executable spell ID")
  equal(aimed.displaySpellID,19434,"Unlearned native tooltip ID")
  equal(aimed.displayName,"Gezielter Schuss","Unlearned localized spell name")
  equal(aimed.label,"Gezielter Schuss","Unlearned visible spell label")
  equal(aimed.icon,135130,"Unlearned visible spell icon")
  equal(aimed.displayIcon,135130,"Unlearned metadata icon")
  k.UI:Open(); k.UI:ShowPage("Bindings")
  assert(k.UI:AssignBinding(aimed,"U"))
  assert(k:Apply())
  local applied=actionByID(k.db.appliedPlan,aimed.id)
  equal(applied.key,"U","An unlearned spell cannot be bound in advance")
  equal(applied.known,false,"Applying an advance binding learned the spell")
  local kind,index=GetActionInfo(applied.nativeSlot)
  equal(kind,"macro","Advance binding did not reserve an original action slot")
  local _,_,body=GetMacroInfo(index)
  assert(contains(body,"Gezielter Schuss"),"Future spell placeholder is not localized")
  assert(not k.API:IsKnown(19434),"Creating a future-spell macro must not imply learned")
  local key=k.UI.pages.Bindings.keyboard.keys.U
  key:GetScript("OnEnter")(key)
  equal(GameTooltip.spellID,19434,"Reserved action dock lacks the native spell tooltip")
  assert(contains(table.concat(GameTooltip.lines or {}," "),"Talent not learned") and key.lockBadge:GetText()=="T","Reserved talent tooltip or badge omits its availability")
end

function Tests.display_metadata_resolves_name_only_catalog_and_rejects_reused_spell_ids()
  Mock.catalog[990301]={id=990301,name="Future Utility",icon=900301}
  Mock.catalog[990302]={id=990302,name="Wrong Spell",icon=900302}
  local k=init()
  local byName=k.API:ResolveDisplay({name="Future Utility",spellIDs={}})
  assert(byName,"Name-only future spell lacks metadata")
  equal(byName.id,990301,"Name-only catalog resolution")
  equal(k.API:IsKnown(990301),false,"Catalog is wrongly counted as learned")
  equal(k.API:ResolveDisplay({name="Missing Utility",spellIDs={990302}}),nil,"Reused ID displayed the wrong spell")
end

function Tests.learned_highest_rank_metadata_wins_over_catalog_preview()
  local k=init()
  Mock.catalog[5176]={id=5176,name="Wrath",icon=9005176}
  for _,spell in ipairs(Mock.spells) do if spell.id==5177 then spell.icon=9005177 end end
  local wrath=actionByID(k:Preview(),"druid.wrath.caster")
  equal(wrath.spellID,5177,"Highest learned rank execution")
  equal(wrath.displaySpellID,5177,"Highest learned rank tooltip")
  equal(wrath.displayIcon,9005177,"Highest learned rank icon")
end

local function hunterKeyboard()
  Mock.class="HUNTER"; Mock.spells={}; Mock.forms={}
  Mock:Learn(75,"Auto Shot"); Mock:Learn(2973,"Raptor Strike")
  Mock.catalog[19434]={id=19434,name="Aimed Shot",icon=135130}
  local k=init(); k:GetSettings().flavor="era"
  k.UI:Open(); k.UI:ShowPage("Bindings")
  return k,k.UI.pages.Bindings.keyboard
end

function Tests.keyboard_live_testing_lights_pressed_combo_and_never_propagates_cast_keys()
  local k,board=hunterKeyboard()
  assert(k.UI.tester and k.UI.tester:IsVisible(),"Bindings keyboard did not activate preview testing")
  equal(k.UI.tester.propagate,false,"Preview testing allows action keys to reach the game")
  local builds=observeCalls(k.Planner,"Build")
  local spells=observeCalls(k.API,"ScanSpellbook")
  local items=observeCalls(k.Items,"Scan")
  Mock:ResetWrites(); Mock.propagatedKeys={}
  Mock:KeyDown("1")
  equal(k.UI.testKeys["1"],"1","Pressed physical key combination")
  assert(board.keys["1"].pressed and board.keys["1"].pressGlow:IsShown(),"Pressed 1 did not visibly light up")
  equal(k.UI.selectedAction.id,"hunter.auto_shot","Pressed 1 did not identify Auto Shot")
  assert(contains(board.note:GetText(),"Auto Shot"),"Pressed action name is not visible")
  assert(not k.UI.capture or not k.UI.capture:IsShown(),"Testing a key unexpectedly began rebinding")
  Mock:KeyUp("1")
  assert(not board.keys["1"].pressed and not board.keys["1"].pressGlow:IsShown(),"Released 1 stayed highlighted")
  Mock:SetModifiers(true,false,false); Mock:KeyDown("1")
  equal(k.UI.testKeys["1"],"SHIFT-1","Held modifier was omitted from test combination")
  assert(board.keys.LSHIFT.pressed or board.keys.RSHIFT.pressed,"Held Shift did not light up")
  equal(k.UI.selectedAction.id,"hunter.raptor_strike","Shift+1 did not identify modified action")
  Mock:KeyUp("1"); Mock:SetModifiers(false,false,false)
  for index=1,40 do Mock:KeyDown("1"); Mock:KeyUp("1") end
  equal(#Mock.propagatedKeys,0,"Testing leaked a key to gameplay")
  equal(builds.count,0,"Live key testing rebuilt the plan")
  equal(spells.count,0,"Live key testing scanned the spellbook")
  equal(items.count,0,"Live key testing scanned inventory")
  equal(#Mock.writes,0,"Live key testing changed secure state")
end

function Tests.keyboard_testing_clears_lost_keyup_and_pauses_for_focus_modal_and_hidden_pages()
  local k,board=hunterKeyboard()
  Mock:KeyDown("1"); Mock.downKeys["1"]=nil; Mock:Advance(0.2)
  assert(not board.keys["1"].pressed,"Missed key-up leaves a permanently pressed key")
  local search=k.UI.pages.Bindings.search
  search:SetFocus(); k.UI:UpdateBindingTester()
  assert(not k.UI.tester:IsVisible(),"Tester steals input from search")
  search:ClearFocus(); k.UI:UpdateBindingTester()
  assert(k.UI.tester:IsVisible(),"Tester did not resume after search focus")
  k.UI:BeginCapture("key",board.keys["1"].action)
  assert(not k.UI.tester:IsVisible(),"Preview tester remains active underneath rebind capture")
  k.UI:EndCapture(); Mock:Advance(0.02); k.UI:UpdateBindingTester()
  assert(k.UI.tester:IsVisible(),"Tester did not resume after rebind capture")
  k.UI:ShowPage("Items")
  assert(not k.UI.tester:IsVisible(),"Tester captures keys outside Bindings")
  k.UI:ShowPage("Bindings"); k.UI.frame:Hide()
  assert(not k.UI.tester:IsVisible(),"Tester remains active with the addon hidden")
end

function Tests.keyboard_preview_releases_input_on_combat_and_recovers_afterward()
  local k,board=hunterKeyboard()
  Mock.strictInputRestrictions=true
  Mock:KeyDown("1")
  Mock.combat=true; Mock:Fire("PLAYER_REGEN_DISABLED")
  assert(not k.UI.tester:IsVisible(),"Combat did not release no-cast preview input")
  assert(not board.keys["1"].pressed,"Combat retained a stale key highlight")
  Mock.propagatedKeys={}; Mock:KeyDown("1")
  equal(Mock.propagatedKeys[1],"1","Combat key input remains blocked by the preview")
  Mock:KeyUp("1"); Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
  k.UI:UpdateBindingTester()
  assert(k.UI.tester:IsVisible(),"Preview did not recover after combat")
end

function Tests.first_open_bindings_in_combat_does_not_capture_or_reconfigure_keyboard_input()
  local k=init()
  Mock.strictInputRestrictions=true; Mock.combat=true
  k.UI:Open(); k.UI:ShowPage("Bindings")
  assert(not k.UI.tester or not k.UI.tester:IsVisible(),"Opening in combat activated a key consumer")
  Mock:KeyDown("1")
  equal(Mock.propagatedKeys[#Mock.propagatedKeys],"1","Opening bindings in combat blocked gameplay input")
end

function Tests.combat_start_ends_active_rebind_capture_without_protected_input_mutation()
  local k,board=hunterKeyboard()
  board.keys["1"]:Click()
  assert(k.UI.capture:IsVisible(),"Rebind fixture did not start capture")
  Mock.strictInputRestrictions=true; Mock.combat=true
  Mock:Fire("PLAYER_REGEN_DISABLED")
  assert(not k.UI.capture:IsVisible(),"Combat retained active rebind capture")
  Mock:KeyDown("1")
  equal(Mock.propagatedKeys[#Mock.propagatedKeys],"1","Combat rebind capture swallowed gameplay input")
end

function Tests.keyboard_click_immediately_captures_rebind_and_locked_spell_has_native_tooltip()
  local k,board=hunterKeyboard()
  local aimed=board.keys["2"]
  equal(aimed.icon:GetTexture(),135130,"Locked action still uses a question mark")
  assert(aimed.locked and aimed.lockBadge:IsShown(),"Locked spell has no distinct lock marking")
  assert(aimed.icon.desaturated,"Locked spell icon is visually indistinguishable from learned")
  aimed:GetScript("OnEnter")(aimed)
  equal(GameTooltip.spellID,19434,"Locked spell does not use the native spell tooltip")
  local status=table.concat(GameTooltip.lines or {}," ")
  assert(contains(status,"learn") or contains(status,"unlock"),"Tooltip omits locked availability")
  aimed:Click()
  assert(k.UI.capture and k.UI.capture:IsShown(),"One icon click did not enter rebind mode")
  equal(k.UI.captureAction.id,"hunter.aimed_shot","Rebind capture selected the wrong spell")
  Mock:KeyDown("ESCAPE"); Mock:Advance(0.02)
  assert(k.UI.frame:IsShown(),"Escape from direct-icon rebinding closed the addon")
  assert(not k.UI.capture:IsShown(),"Escape did not end direct-icon rebinding")
  equal(k:GetSettings().bindingOverrides["hunter.aimed_shot"],nil,"Cancelled rebinding changed an unlearned action")
end

function Tests.keyboard_keycap_icons_and_captions_use_separate_aligned_regions()
  local k,board=hunterKeyboard()
  for _,base in ipairs({"1","2","Q","F","Z","F7"}) do
    local cap=board.keys[base]
    assert(cap.backdrop and cap.backdrop.edgeFile,"Key "..base.." has no full-size native outline")
    assert(not cap.normalTexture,"Key "..base.." retains the padded quickslot frame responsible for misalignment")
    equal(cap.icon.point[1],"BOTTOM",base.." icon vertical anchor")
    equal(cap.icon.point[2],0,base.." icon horizontal centering")
    equal(cap.caption.point[1],"TOP",base.." caption vertical anchor")
    equal(cap.caption.point[2],0,base.." caption horizontal centering")
    local iconTop=cap:GetHeight()-cap.icon.point[3]-cap.icon:GetHeight()
    local captionBottom=-cap.caption.point[3]+cap.caption.font[2]
    assert(iconTop>=captionBottom+1,"Key "..base.." icon overlaps its key label")
    assert(cap.icon:GetWidth()<=cap:GetWidth()-8,"Key "..base.." icon crowds the full-size frame")
  end
  local mouse=board.keys.BUTTON4
  equal(mouse.icon.point[1],"LEFT","Mouse icon alignment")
  assert(mouse.icon.point[2]+mouse.icon:GetWidth()<mouse.caption.point[2],"Mouse icon overlaps its label")
end

function Tests.keyboard_mouse_test_shield_previews_side_buttons_and_wheel_without_rebinding()
  local k,board=hunterKeyboard()
  local shield=k.UI.testMouseShield
  assert(shield and shield:IsVisible() and shield.mouse,"No mouse input shield during no-cast testing")
  equal(shield.allPoints,UIParent,"Mouse preview shield does not cover gameplay surfaces")
  Mock.downKeys.BUTTON4=true
  shield:GetScript("OnMouseDown")(shield,"Button4")
  assert(board.keys.BUTTON4.pressed,"Side-button preview did not light up")
  equal(k.UI.selectedAction.id,"hunter.intimidation","Side-button preview selected wrong action")
  assert(not k.UI.capture or not k.UI.capture:IsShown(),"Testing a side button accidentally started rebinding")
  Mock.downKeys.BUTTON4=nil
  shield:GetScript("OnMouseUp")(shield,"Button4")
  assert(not board.keys.BUTTON4.pressed,"Side-button release did not clear highlighting")
  shield:GetScript("OnMouseWheel")(shield,1)
  assert(board.keys.MOUSEWHEELUP.pressed,"Wheel preview did not light up")
  equal(k.UI.selectedAction.id,"hunter.aspect_hawk","Wheel preview selected wrong action")
  Mock:Advance(0.2)
  assert(not board.keys.MOUSEWHEELUP.pressed,"Momentary wheel highlight never cleared")
  k.UI.pages.Bindings.search:SetFocus()
  assert(not k.UI.tester:IsVisible(),"Search did not release the keyboard tester")
  assert(shield:IsVisible(),"Search focus lets mouse input reach gameplay during preview")
  k.UI.pages.Bindings.search:ClearFocus()
  k.UI.pages.Bindings.modeButtons.List:Click()
  assert(not shield:IsVisible(),"Mouse shield remains active outside keyboard view")
end

function Tests.finishing_direct_rebind_consumes_the_same_key_event_instead_of_casting()
  local k,board=hunterKeyboard()
  board.keys["2"]:Click()
  Mock.propagatedKeys={}
  Mock:KeyDown("NUMPAD9")
  equal(k:GetSettings().bindingOverrides["hunter.aimed_shot"],"NUMPAD9","Captured key was not staged")
  equal(#Mock.propagatedKeys,0,"Completing a rebind leaked that same key event into gameplay")
  Mock:Advance(0.02)
  assert(not k.UI.capture:IsVisible(),"Completed rebind retained capture overlay")
  assert(k.UI.frame:IsShown(),"Completing a rebind closed the main window")
end

function Tests.rebind_confirmation_keeps_keyboard_input_consumed_until_overlay_is_dismissed()
  local k,board=hunterKeyboard()
  board.keys["2"]:Click()
  Mock.propagatedKeys={}
  Mock:KeyDown("3")
  assert(k.UI.confirm and k.UI.confirm:IsVisible(),"Swapping two planned actions skipped review")
  equal(#Mock.propagatedKeys,0,"Opening rebind review leaked the captured key")
  Mock:Advance(0.02)
  Mock:KeyDown("1")
  equal(#Mock.propagatedKeys,0,"Rebind confirmation allows unrelated keys to cast")
  equal(k:GetSettings().bindingOverrides["hunter.aimed_shot"],nil,"Typing during confirmation committed a binding")
  Mock:KeyDown("ESCAPE"); Mock:Advance(0.02)
  assert(not k.UI.confirm:IsVisible(),"Escape did not dismiss rebind confirmation")
  assert(k.UI.frame:IsShown(),"Escape from confirmation closed the main window")
end

function Tests.keyboard_displays_qwerty_form_specific_icons_and_persistent_heals()
  local k=init()
  for _,spell in ipairs(Mock.spells) do spell.icon=1000000+spell.id end
  k.UI:Open(); k.UI:ShowPage("Bindings")
  local board=k.UI.pages.Bindings.keyboard
  assert(board and board:IsShown(),"Visual keyboard is not the initial bindings view")
  for base in ("QWERTYUIOPASDFGHJKLZXCVBNM"):gmatch(".") do assert(board.keys[base],"Missing QWERTY key "..base) end
  for _,base in ipairs({"`","1","5","F1","F12","LSHIFT","RSHIFT","LCTRL","RCTRL","LALT","RALT","SPACE","MOUSEWHEELUP","BUTTON4","BUTTON5"}) do
    assert(board.keys[base],"Keyboard/mouse surface missing "..base)
  end
  assert(not board.keys.BUTTON6,"Visual mouse invented an unconfigured side button")
  for form,id in pairs({caster="druid.wrath.caster",cat="druid.claw.cat",bear="druid.maul.bear",moonkin="druid.wrath.moonkin"}) do
    k.UI:SetActionPage(form)
    local expected=actionByID(k.UI.plan,id)
    equal(board.keys["1"].action.id,id,form.." primary key")
    equal(board.keys["1"].icon:GetTexture(),expected.icon,form.." primary icon")
    equal(board.keys.Q.action.id,"druid.rejuvenation",form.." persistent heal")
  end
  k.UI:SetActionPage("cat"); Mock:SetModifiers(true,false,false)
  equal(board.keys["1"].action.id,"druid.ravage.cat","Native Cat page retains separate stealth opener binding")
end

function Tests.keyboard_modifier_events_change_layers_without_scans_or_protected_writes()
  local k=init(); k.UI:Open(); k.UI:ShowPage("Bindings")
  local board=k.UI.pages.Bindings.keyboard
  local builds=observeCalls(k.Planner,"Build")
  local spells=observeCalls(k.API,"ScanSpellbook")
  local items=observeCalls(k.Items,"Scan")
  local rows=observeCalls(k.UI,"RenderBindings")
  Mock:ResetWrites(); Mock.combat=true
  Mock:SetModifiers(true,false,false)
  equal(k.UI.modifierPrefix,"SHIFT-","held Shift prefix")
  equal(board.keys.Q.action.id,"druid.swiftmend","Shift healing icon mapping")
  Mock:SetModifiers(false,true,false)
  equal(k.UI.modifierPrefix,"CTRL-","held Ctrl prefix")
  equal(board.keys.Q.action.id,"druid.mark","Ctrl buff icon mapping")
  Mock:SetModifiers(true,true,false)
  equal(k.UI.modifierPrefix,"CTRL-SHIFT-","combined modifiers")
  equal(board.keys.Q.fullKey,"CTRL-SHIFT-Q","combined key identity")
  Mock:SetModifiers(false,false,true)
  equal(board.keys.Q.action.id,"druid.rejuvenation","Alt self-cast icon")
  assert(board.keys.Q.alias,"Alt helpful key is not marked as a self alias")
  equal(board.keys.MOUSEWHEELUP.action.command,"CAMERAZOOMIN","Alt wheel preserves zoom")
  for i=1,20 do Mock:SetModifiers(true,false,false); Mock:SetModifiers(false,true,false) end
  Mock:SetModifiers(false,false,false)
  equal(k.UI.modifierPrefix,"","releasing modifiers restores base layer")
  equal(builds.count,0,"Live modifier preview rebuilt the plan")
  equal(spells.count,0,"Live modifier preview scanned spells")
  equal(items.count,0,"Live modifier preview scanned inventory")
  equal(rows.count,0,"Live modifier preview rerendered complete binding rows")
  equal(#Mock.writes,0,"Live modifier preview made protected writes")
end

function Tests.keyboard_click_and_picker_reassign_only_selected_action_and_self_alias()
  local k=init(); k.UI:Open(); k.UI:ShowPage("Bindings")
  local page=k.UI.pages.Bindings
  page.keyboard.keys.Q:Click()
  equal(k.UI.selectedAction.id,"druid.rejuvenation","clicking occupied key selects its action")
  assert(page.detail.rebind:IsEnabled(),"Selected key cannot be rebound")
  assert(k.UI.capture:IsShown(),"Clicking an occupied key did not immediately begin rebinding")
  k.UI:EndCapture(); Mock:Advance(0.02)
  assert(not page.keyboard.keys.U.action,"U fixture must be unassigned")
  Mock:ResetWrites()
  page.keyboard.keys.U:Click()
  assert(k.UI.picker and k.UI.picker:IsShown(),"Clicking an empty key did not open the action picker")
  equal(k.UI.picker.key,"U","picker destination key")
  k.UI.picker.search:SetText("Rejuvenation")
  k.UI.picker.search:GetScript("OnTextChanged")(k.UI.picker.search,true)
  local chosen
  for _,row in ipairs(k.UI.picker.list.rows) do
    if row:IsShown() and row.action.id=="druid.rejuvenation" then chosen=row end
  end
  assert(chosen,"Search did not expose matching persistent heal")
  chosen:Click()
  equal(k:GetSettings().bindingOverrides["druid.rejuvenation"],"U","picker staged destination")
  local moved=actionByID(k.UI.plan,"druid.rejuvenation")
  equal(moved.key,"U","updated primary binding")
  equal(moved.selfKey,"ALT-U","self-cast follows reassignment")
  equal(actionByID(k.UI.plan,"druid.regrowth").key,"E","unrelated action moved")
  equal(GetBindingAction("U"),"","Staging changed live U binding")
  equal(#Mock.writes,0,"Picker reassignment installed protected state")
end

function Tests.keyboard_same_form_swap_requires_confirmation_and_cross_form_collision_stays_blocked()
  local k=init(); k.UI:Open(); k.UI:ShowPage("Bindings")
  local heal=actionByID(k.UI.plan,"druid.rejuvenation")
  Mock:ResetWrites()
  assert(not k.UI:AssignBinding(heal,"E"),"Colliding keys swapped before confirmation")
  equal(k:GetSettings().bindingOverrides[heal.id],nil,"Review changed override before confirmation")
  assert(k.UI.confirm and k.UI.confirm:IsShown(),"Same-form swap did not show a review")
  local confirmed=k.UI.confirm.callback; k.UI.confirm:Hide(); confirmed()
  equal(actionByID(k.UI.plan,"druid.rejuvenation").key,"E","Confirmed swap did not move selected action")
  equal(actionByID(k.UI.plan,"druid.regrowth").key,"Q","Confirmed swap lost the displaced action")
  equal(actionByID(k.UI.plan,"druid.rejuvenation").selfKey,"ALT-E","Selected self-cast alias did not follow swap")
  equal(actionByID(k.UI.plan,"druid.regrowth").selfKey,"ALT-Q","Displaced self-cast alias did not follow swap")
  assert(k.UI:AssignBinding(actionByID(k.UI.plan,"druid.claw.cat"),"U"),"Free cat reassignment rejected")
  assert(k.UI:AssignBinding(actionByID(k.UI.plan,"druid.wrath.caster"),"U"),"Distinct form banks cannot share the same physical key")
  equal(#k.UI.plan.errors,0,"Distinct form reassignment produced planner collisions")
  assert(not k.UI:AssignBinding(actionByID(k.UI.plan,"druid.rejuvenation"),"U"),"Persistent utility was allowed to overwrite form-specific keys")
  assert(k.UI.notice and contains(k.UI.notice,"U"),"Blocked cross-form collision did not identify its key")
  assert(not k.UI:AssignBinding(heal,"ALT-Y"),"Combat action consumed Alt outside self-cast")
  assert(not k.UI:AssignBinding(heal,"W"),"Combat action overwrote movement")
  equal(#Mock.writes,0,"Collision validation wrote game state")
end

function Tests.keyboard_existing_game_binding_replacement_stages_without_false_conflict()
  local k=init(); k.UI:Open(); k.UI:ShowPage("Bindings")
  Mock:RegisterBindingCommand("TOGGLEACHIEVEMENT","BINDING_HEADER_INTERFACE")
  Mock.bindings.U="TOGGLEACHIEVEMENT"
  local heal=actionByID(k.UI.plan,"druid.rejuvenation")
  Mock:ResetWrites()
  assert(k.UI:AssignBinding(heal,"U"),"A normal existing game binding was treated as an error")
  assert(not k.UI.confirm or not k.UI.confirm:IsShown(),"A normal replacement interrupted editing")
  equal(k:GetSettings().bindingOverrides[heal.id],"U","Replacement key was not staged")
  equal(Mock.bindings.U,"TOGGLEACHIEVEMENT","Staging directly replaced the game binding")
  equal(#Mock.writes,0,"Binding editing bypassed Use preset")
end

function Tests.occupied_keyboard_key_can_change_action_using_mouse_controls_only()
  local k=init(); k.UI:Open(); k.UI:ShowPage("Bindings")
  local page=k.UI.pages.Bindings
  Mock:ResetWrites()
  page.keyboard.keys.Q:Click()
  assert(page.detail.change and page.detail.change:IsEnabled(),"Occupied key has no Change action control")
  assert(k.UI.capture:IsShown(),"Occupied key did not enter direct rebind mode")
  k.UI:EndCapture(); Mock:Advance(0.02)
  page.detail.change:Click()
  assert(k.UI.picker:IsShown(),"Change action did not open the picker")
  equal(k.UI.picker.key,"Q","Change action picker targets the wrong physical key")
  local candidate
  for _,row in ipairs(k.UI.picker.list.rows) do
    if row:IsShown() and row.action.id=="druid.regrowth" then candidate=row end
  end
  assert(candidate,"Mouse picker omitted the action to swap")
  candidate:Click()
  equal(k:GetSettings().bindingOverrides["druid.regrowth"],nil,"Picking a collision committed before confirmation")
  local confirmButton
  for _,frame in ipairs(Mock.frames) do
    if frame:GetParent()==k.UI.confirm and frame.kind=="Button" and frame:GetText()=="Continue" then confirmButton=frame end
  end
  assert(confirmButton,"Swap review has no usable confirmation button")
  confirmButton:Click()
  equal(actionByID(k.UI.plan,"druid.regrowth").key,"Q","Mouse-only swap did not assign the chosen spell")
  equal(actionByID(k.UI.plan,"druid.rejuvenation").key,"E","Mouse-only swap discarded the previous spell")
  equal(#k.UI.plan.errors,0,"Mouse-only swap produced invalid bindings")
  equal(#Mock.writes,0,"Mouse-only swap applied live bindings without Apply")
end

function Tests.settings_launcher_registers_once_and_open_is_idempotent()
  local k=init(); Mock:ResetWrites()
  Mock:Fire("ADDON_LOADED",k.name)
  Mock:Fire("ADDON_LOADED","Blizzard_Settings")
  k.Launcher:RegisterSettings()
  equal(#Mock.settingsCategories,1,"Modern settings category registration duplicated")
  equal(#Mock.addonCategories,1,"Addon category registration duplicated")
  equal(Mock.settingsCategories[1].name,"Hot Swap","Settings display name")
  equal(Mock.settingsCategories[1].frame,k.Launcher.panel,"Registered settings panel")
  SettingsPanel=CreateFrame("Frame","SettingsPanel",UIParent)
  InterfaceOptionsFrame=CreateFrame("Frame","InterfaceOptionsFrame",UIParent)
  k.Launcher.panel.openButton:Click()
  assert(k.UI.frame:IsShown(),"Settings entry did not open the addon")
  assert(not SettingsPanel:IsShown() and not InterfaceOptionsFrame:IsShown(),"Settings containers remained over the addon")
  k.Launcher.panel.openButton:Click()
  assert(k.UI.frame:IsShown(),"Opening an already visible addon toggled it closed")
  equal(#Mock.writes,0,"Settings launcher applied bindings")
end

function Tests.modern_escape_menu_rebuilds_exactly_one_native_hot_swap_button()
  local k=init(); local menu=Mock:CreateGameMenu(true)
  Mock:Fire("ADDON_LOADED","Blizzard_GameMenu")
  k.Launcher:RegisterMenu()
  Mock:ResetWrites()
  for i=1,4 do
    menu:Show()
    local count,button=0
    for _,candidate in ipairs(menu.activeButtons) do
      if candidate:GetText()=="Hot Swap" then count=count+1; button=candidate end
    end
    equal(count,1,"Duplicate or missing menu entry on rebuild "..i)
    equal(button.layoutIndex,2.5,"Menu entry is not positioned after AddOns")
    button:Click()
    assert(not menu:IsShown() and k.UI.frame:IsShown(),"Menu entry failed to open the addon and dismiss menu")
  end
  equal(#Mock.writes,0,"Escape-menu launcher applied bindings")
end

function Tests.legacy_settings_and_escape_menu_launchers_register_once()
  local k=init(); Settings=nil
  local menu=Mock:CreateGameMenu(false)
  k.Launcher:Register(); k.Launcher:Register()
  equal(#Mock.legacyCategories,1,"Legacy settings category registration duplicated")
  equal(Mock.legacyCategories[1].name,"Hot Swap","Legacy settings category name")
  local first=k.Launcher.menuButton
  equal(first:GetParent(),menu,"Legacy menu button is not a menu child")
  k.Launcher:RegisterMenu()
  equal(k.Launcher.menuButton,first,"Repeated legacy registration created another button")
  Mock:ResetWrites(); menu:Show(); first:Click()
  assert(k.UI.frame:IsShown() and not menu:IsShown(),"Legacy menu entry did not open the addon")
  equal(#Mock.writes,0,"Legacy launcher applied bindings")
end
