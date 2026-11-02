local primary="priest.power_infusion"
local alternate="priest.mind_flay"
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function action(plan,id)
 for _,a in ipairs(plan.actions) do if a.id==id then return a end end
 error("Missing action "..id)
end
local function ready()
 Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class="PRIEST"
 Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
 Mock:Learn(585,"Smite")
 Mock.catalog[10060]={id=10060,name="Power Infusion",icon=135939}
 Mock.catalog[15407]={id=15407,name="Mind Flay",icon=136208}
 TestAddon:Init(); return TestAddon
end
local function preview(k)
 local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; ")); return plan
end
local function choose(k,choices)
 local ok,why=k.TalentBindings:SetChoices(primary,choices); assert(ok,why)
end
local function removeSpell(id)
 for i=#Mock.spells,1,-1 do if Mock.spells[i].id==id then table.remove(Mock.spells,i) end end
end
local function finish(k)
 if k.Engine.busy then local ok,why=Mock:Drain(); assert(ok,why) end
end
local function changed(k)
 Mock:Fire("PLAYER_TALENT_UPDATE"); finish(k)
end
local function macroBody(a)
 local kind,index=GetActionInfo(a.nativeSlot); equal(kind,"macro")
 local name,_,body=GetMacroInfo(index); equal(name,a.macroName)
 return body
end

function Tests.talent_bindings_selects_first_learned_choice_and_keeps_primary_identity()
 local k=ready(); Mock:Learn(15407,"Mind Flay"); choose(k,{primary,alternate})
 local a=action(preview(k),primary)
 equal(a.talentSelectionID,alternate); equal(a.librarySourceID,alternate)
 equal(a.id,primary); equal(a.key,"X"); equal(a.spellID,15407)
 assert(a.known and a.talentHasHelpful and a.nativeBlockAlt)
 equal(a.selfKey,"ALT-X","Helpful future choice lost its reserved self-cast key")
end

function Tests.talent_bindings_both_learned_respects_explicit_order_not_tree_guessing()
 local k=ready(); Mock:Learn(10060,"Power Infusion"); Mock:Learn(15407,"Mind Flay")
 choose(k,{primary,alternate}); equal(action(preview(k),primary).talentSelectionID,primary)
 choose(k,{alternate,primary}); equal(action(preview(k),primary).talentSelectionID,alternate)
 local choices=k.TalentBindings:GetChoices(primary); choices[1]="changed outside"
 equal(k.TalentBindings:GetChoices(primary)[1],alternate,"GetChoices leaked mutable saved data")
end

function Tests.talent_bindings_no_learned_choice_stays_inert_or_hidden_with_reservation()
 local k=ready(); choose(k,{primary,alternate})
 Mock:AllowFullCatalogMacros() -- Exercise visible placeholders when there is room for them.
 local a=action(preview(k),primary)
 assert(not a.known and not a.talentSelectionID and a.nativeSlot and a.key)
 assert(a.nativeHidden and not a.body,"Unlearned shared choice should reserve an empty slot")
 local slot,key=a.nativeSlot,a.key
 k:GetSettings().adaptTalents=true
 local hidden=action(preview(k),primary)
 assert(hidden.nativeHidden and not hidden.body)
 equal(hidden.nativeSlot,slot); equal(hidden.key,key)
end

function Tests.talent_bindings_rejects_invalid_duplicate_sparse_and_non_talent_alternatives()
 local k=ready(); choose(k,{primary,alternate}); local settings=k:GetSettings()
 local before=k.Presets:Signature(k.db.activePreset)
 local invalid={{primary,primary},{primary,"missing.spell"},{primary,"priest.smite"},{[1]=primary,[3]=alternate},{primary,alternate,unexpected="field"}}
 Mock:ResetWrites()
 for _,choices in ipairs(invalid) do
  local ok=k.TalentBindings:SetChoices(primary,choices); assert(not ok,"Accepted invalid shared choices")
  equal(k.Presets:Signature(k.db.activePreset),before,"Rejected choices changed the preset")
 end
 assert(not k.TalentBindings:SetChoices("priest.silence.focus",{alternate}),"A focus variant accepted automatic talent swapping")
 equal(#Mock.writes,0); equal(settings.talentAlternatives[primary][2],alternate)
 choose(k,{}); assert(not settings.talentAlternatives[primary],"Resetting choices did not remove the override")
end

function Tests.talent_bindings_rejects_fixed_rank_or_replacement_on_shared_primary()
 local k=ready(); local settings=k:GetSettings()
 for _,override in ipairs({{spellID=10060},{replacement={kind="spell",spellID=10060}}}) do
  settings.actionOverrides[primary]=override
  local ok,why=k.TalentBindings:SetChoices(primary,{primary,alternate})
  assert(not ok and why:find("replacement or fixed rank",1,true),tostring(why))
  assert(not settings.talentAlternatives[primary])
 end
 settings.actionOverrides[primary]=nil; choose(k,{primary,alternate})
 settings.actionOverrides[primary]={spellID=10060}
 local plan=k:Preview(); assert(#plan.errors>0,"Fixed rank added after choices escaped plan preflight")
end

function Tests.talent_bindings_import_export_preserves_order_without_live_writes()
 local k=ready(); choose(k,{alternate,primary}); k:GetSettings().adaptTalents=true
 local payload,why=k:Export("Leveling"); assert(payload,why)
 assert(payload:find("t\tLeveling\t"..primary.."\t"..alternate,1,true))
 Mock:ResetWrites(); local ok,message=k:Import(payload); assert(ok,message); assert(k.Presets:Select("Leveling (2)"))
 local choices=k.TalentBindings:GetChoices(primary)
 equal(choices[1],alternate); equal(choices[2],primary); equal(k:GetSettings().adaptTalents,true)
 equal(#Mock.writes,0,"Importing talent choices changed live native actions")
 equal(k.db.presets.Dungeon.settings.talentAlternatives[primary],nil)
end

function Tests.talent_bindings_invalid_import_is_atomic_and_data_only()
 local k=ready(); local count=#k.Presets:List(); local selected=k.db.activePreset
 local prefix="KBO2\nc\tPRIEST\nn\tInvalid\n"
 local invalid={
  "t\tInvalid\t"..primary.."\t"..primary.."\nt\tInvalid\t"..primary.."\t"..primary,
  "t\tInvalid\t"..primary.."\tmissing.spell",
  "t\tInvalid\t"..primary.."\tpriest.smite",
  "t\tInvalid\t"..primary.."\t"..alternate.."\no\tInvalid\t"..primary.."\tspellID\t10060",
  "t\tInvalid\t"..primary.."\t"..alternate.."\nr\tInvalid\t"..primary.."\tkind\tspell\nr\tInvalid\t"..primary.."\tspellID\t10060",
  "t\tInvalid\t"..primary.."\t%0A%2Frun%20Injected=true",
 }
 Mock:ResetWrites()
 for _,body in ipairs(invalid) do
  local ok,why=k:Import(prefix..body.."\na\tInvalid"); assert(not ok,tostring(why))
  equal(#k.Presets:List(),count); equal(k.db.activePreset,selected)
 end
 equal(#Mock.writes,0); assert(not _G.Injected)
end

function Tests.talent_bindings_selected_alternative_keeps_all_other_keys_stable()
 local k=ready(); Mock:Learn(10060,"Power Infusion"); Mock:Learn(15407,"Mind Flay")
 local baseline=preview(k); local positions={}
 for _,a in ipairs(baseline.actions) do positions[a.id]=a.key end
 choose(k,{alternate,primary}); local swapped=preview(k)
 for _,a in ipairs(swapped.actions) do
  local prior=positions[a.id]
  if prior then equal(a.key,prior,"Key moved for "..a.id); positions[a.id]=nil end
 end
 assert(not next(positions),"Sharing a talent removed an existing action")
 equal(swapped.coverage.bound,swapped.coverage.total,"Displaced known primary lost spellbook coverage")
end

function Tests.talent_bindings_engine_switches_only_installed_choice_with_safe_alt_and_no_draft_apply()
 local k=ready(); Mock:Learn(10060,"Power Infusion"); choose(k,{primary,alternate})
 Mock.async=true; equal(k:Apply(),"pending"); finish(k)
 local first=action(k.db.appliedPlan,primary); local key,slot,selfKey=first.key,first.nativeSlot,first.selfKey
 assert(macroBody(first):find("mod:alt,@player",1,true),"Helpful choice lacks self-cast condition")
 local bindings=k.Copy(Mock.bindings)
 -- Staged choices/keys are independent from the installed choice group.
 choose(k,{primary}); k:GetSettings().bindingOverrides[primary]="CTRL-F24"
 removeSpell(10060); Mock:Learn(15407,"Mind Flay"); Mock:ResetWrites(); changed(k)
 local swapped=action(k.db.appliedPlan,primary)
 equal(swapped.talentSelectionID,alternate); equal(swapped.key,key); equal(swapped.nativeSlot,slot); equal(swapped.selfKey,selfKey)
 assert(swapped.nativeBlockAlt and macroBody(swapped):find("/cast [nomod:alt] Mind Flay",1,true),"Alt self-cast can execute the harmful talent choice")
 for binding,command in pairs(bindings) do equal(Mock.bindings[binding],command,"Talent swap changed "..binding) end
 for _,write in ipairs(Mock.writes) do assert(write[1]~="binding","Native talent swap rebound gameplay keys") end
 equal(k:GetSettings().bindingOverrides[primary],"CTRL-F24"); equal(#k.TalentBindings:GetChoices(primary),1)
 Mock:Learn(10060,"Power Infusion"); changed(k)
 local restored=action(k.db.appliedPlan,primary); equal(restored.talentSelectionID,primary)
 assert(not restored.nativeBlockAlt and macroBody(restored):find("mod:alt,@player",1,true))
end

function Tests.talent_bindings_engine_preserves_manually_replaced_slot_when_selection_changes()
 local k=ready(); Mock:Learn(10060,"Power Infusion"); choose(k,{primary,alternate})
 Mock.async=true; equal(k:Apply(),"pending"); finish(k)
 local original=action(k.db.appliedPlan,primary); local slot=original.nativeSlot
 Mock.actions[slot]={"item",900003}
 removeSpell(10060); Mock:Learn(15407,"Mind Flay"); changed(k)
 equal(GetActionInfo(slot),"item"); equal(select(2,GetActionInfo(slot)),900003,"Talent swap overwrote a personal native action")
 Mock:Learn(10060,"Power Infusion"); changed(k)
 equal(select(2,GetActionInfo(slot)),900003,"A later talent swap reclaimed a personal native action")
end

function Tests.talent_bindings_named_backup_restores_pre_swap_macro_after_idle_cleanup()
 local k=ready(); Mock:Learn(10060,"Power Infusion"); choose(k,{primary,alternate})
 Mock.async=true; equal(k:Apply(),"pending"); finish(k)
 local original=action(k.db.appliedPlan,primary); local name,body,slot=original.macroName,original.body,original.nativeSlot
 -- A second activation backs up the installed helpful choice, including its
 -- native slot contents and owned macro identity, before the later talent event.
 equal(k:Apply(),"pending"); finish(k); local backup=k.db.lastBindingBackupID
 assert(k.db.bindingBackups[backup].complete)
 removeSpell(10060); Mock:Learn(15407,"Mind Flay"); changed(k)
 for _=1,200 do
  if not next(k.AvailabilityEngine.pendingCleanup or {}) then break end
  Mock:Advance(0.016)
 end
 equal(GetMacroIndexByName(name),0,"Obsolete helpful macro was not collected")
 assert(not k.db.ownedMacros[name])
 equal(k.Engine:RestoreBackup(backup),"pending"); finish(k)
 local restored=action(k.db.appliedPlan,primary)
 equal(restored.nativeSlot,slot); equal(restored.talentSelectionID,primary)
 equal(macroBody(restored),body,"Named backup did not recreate its collected generated macro")
 assert(k.Macros:FindOwned(name,body),"Restored macro did not regain exact owned identity")
end
