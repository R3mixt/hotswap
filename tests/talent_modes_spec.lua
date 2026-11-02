local primary="priest.power_infusion"
local alternate="priest.mind_flay"
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function ready()
 Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class="PRIEST"
 Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
 Mock:Learn(585,"Smite"); Mock:Learn(10060,"Power Infusion"); Mock:Learn(15407,"Mind Flay")
 TestAddon:Init(); return TestAddon
end
local function action(plan,id)
 for _,a in ipairs(plan.actions) do if a.id==id then return a end end
 error("Missing action "..id)
end
local function preview(k)
 local plan=k:Preview(); equal(#plan.errors,0,table.concat(plan.errors,"; ")); return plan
end
local function mode(k,id,value)
 local ok,why=k.TalentBindings:SetMode(id,value); assert(ok,why)
end

function Tests.talent_modes_defaults_to_separate_and_shared_starts_with_only_that_primary()
 local k=ready(); local t=k.TalentBindings
 equal(t:GetMode(primary),"separate"); equal(t:GetMode(alternate),"separate")
 Mock:ResetWrites(); mode(k,primary,"shared")
 equal(t:GetMode(primary),"shared"); equal(t:GetMode(alternate),"separate")
 local choices=t:GetChoices(primary); equal(#choices,1); equal(choices[1],primary)
 equal(t:GetMode(primary,k.db.presets.Dungeon.settings),"separate","Mode leaked to another preset")
 assert(k.dirty); equal(#Mock.writes,0,"Choosing shared mode changed live bindings")
end

function Tests.talent_modes_reselecting_shared_preserves_existing_choice_order()
 local k=ready(); local t=k.TalentBindings
 assert(t:SetChoices(primary,{alternate,primary})); mode(k,primary,"shared")
 local choices=t:GetChoices(primary)
 equal(choices[1],alternate); equal(choices[2],primary)
 equal(action(preview(k),primary).talentSelectionID,alternate)
 mode(k,primary,"separate"); equal(t:GetMode(primary),"separate")
 assert(not k:GetSettings().talentAlternatives[primary])
 mode(k,primary,"shared")
 choices=t:GetChoices(primary); equal(#choices,1); equal(choices[1],primary,"New shared group reused removed alternatives")
end

function Tests.talent_modes_independent_pins_survive_shared_then_separate_and_restore_primary_spells()
 local k=ready(); local settings=k:GetSettings(); local t=k.TalentBindings
 settings.bindingOverrides[primary]="CTRL-F21"; settings.bindingOverrides[alternate]="CTRL-F22"
 local separate=preview(k)
 equal(action(separate,primary).spellName,"Power Infusion"); equal(action(separate,alternate).spellName,"Mind Flay")
 assert(t:SetChoices(primary,{alternate,primary}))
 local shared=preview(k)
 equal(action(shared,primary).spellName,"Mind Flay"); equal(action(shared,primary).key,"CTRL-F21")
 equal(action(shared,alternate).key,"CTRL-F22","Shared group replaced the other talent's independent pin")
 local ok,why=k:Apply(); assert(ok,why)
 local live=k.Copy(Mock.bindings)
 Mock:ResetWrites(); mode(k,primary,"separate")
 equal(#Mock.writes,0,"Switching the editing mode immediately changed gameplay")
 for key,command in pairs(live) do equal(Mock.bindings[key],command) end
 local restored=preview(k); local own=action(restored,primary); local other=action(restored,alternate)
 equal(own.spellName,"Power Infusion"); equal(own.label,"Power Infusion")
 equal(other.spellName,"Mind Flay"); equal(other.label,"Mind Flay")
 equal(own.key,"CTRL-F21"); equal(other.key,"CTRL-F22")
 assert(not own.talentChoices and not own.talentSelectionID and not own.talentHasHelpful,"Separate action retained shared-choice metadata")
 equal(settings.bindingOverrides[primary],"CTRL-F21"); equal(settings.bindingOverrides[alternate],"CTRL-F22")
 ok,why=k:Apply(); assert(ok,why)
 equal(action(k.db.appliedPlan,primary).spellName,"Power Infusion")
 equal(action(k.db.appliedPlan,alternate).spellName,"Mind Flay")
end

function Tests.talent_modes_shared_and_separate_round_trip_without_losing_independent_keys()
 local k=ready(); local t=k.TalentBindings
 k:GetSettings().bindingOverrides[primary]="CTRL-F21"; k:GetSettings().bindingOverrides[alternate]="CTRL-F22"
 assert(t:SetChoices(primary,{alternate,primary}))
 local payload,why=k:Export("Leveling"); assert(payload,why)
 Mock:ResetWrites(); local ok,message=k:Import(payload); assert(ok,message)
 equal(t:GetMode(primary),"shared"); equal(t:GetMode(alternate),"separate")
 equal(t:GetChoices(primary)[1],alternate); equal(t:GetChoices(primary)[2],primary)
 equal(k:GetSettings().bindingOverrides[primary],"CTRL-F21"); equal(k:GetSettings().bindingOverrides[alternate],"CTRL-F22")
 mode(k,primary,"separate")
 payload,why=k:Export(k.db.activePreset); assert(payload,why)
 ok,message=k:Import(payload); assert(ok,message)
 equal(t:GetMode(primary),"separate"); equal(t:GetMode(alternate),"separate")
 assert(not k:GetSettings().talentAlternatives[primary])
 equal(k:GetSettings().bindingOverrides[primary],"CTRL-F21"); equal(k:GetSettings().bindingOverrides[alternate],"CTRL-F22")
 equal(#Mock.writes,0,"Import or mode selection applied live changes")
end

function Tests.talent_modes_invalid_or_busy_request_leaves_saved_choices_and_pins_unchanged()
 local k=ready(); local t=k.TalentBindings
 k:GetSettings().bindingOverrides[primary]="CTRL-F21"
 assert(t:SetChoices(primary,{alternate,primary}))
 local signature=k.Presets:Signature(k.db.activePreset); local dirty=k.dirty
 Mock:ResetWrites()
 for _,value in ipairs({"automatic","individual","",false,42}) do
  local ok=t:SetMode(primary,value); assert(not ok,"Invalid talent mode was accepted")
  equal(k.Presets:Signature(k.db.activePreset),signature); equal(k.dirty,dirty)
 end
 k.Engine.busy=true
 for _,value in ipairs({"separate","shared"}) do
  local ok,why=t:SetMode(primary,value); assert(not ok and why:find("Wait",1,true),tostring(why))
  equal(k.Presets:Signature(k.db.activePreset),signature)
 end
 k.Engine.busy=false; equal(#Mock.writes,0)
 equal(t:GetMode(primary),"shared"); equal(t:GetChoices(primary)[1],alternate)
end
