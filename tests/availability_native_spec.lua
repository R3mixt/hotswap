local function eq(actual,expected,message) assert(actual==expected,(message or "value")..": expected "..tostring(expected)..", got "..tostring(actual)) end
local function action(plan,id) for _,a in ipairs(plan.actions) do if a.id==id then return a end end end

function Tests.availability_distinguishes_talents_without_granting_spell_knowledge()
 local k=TestAddon; k:Init(); local a={id="druid.faerie_fire_feral.cat",known=false}
 k.Availability:Annotate(a,"DRUID","era")
 eq(a.talent,true); eq(a.availabilityState,"talent"); eq(a.availabilityLabel,"Talent not learned"); eq(a.known,false)
 eq(k.Availability:IsHidden(a,{adaptTalents=true}),true)
 local b={id="custom.copy",librarySourceID="druid.swiftmend",known=false}
 k.Availability:Annotate(b,"DRUID","era"); eq(b.talent,true,"Copied talent lost source metadata")
 b.known=true; k.Availability:Annotate(b,"DRUID","era")
 eq(b.availabilityState,"ready"); eq(k.Availability:IsHidden(b,{hideUnavailableSpells=true,adaptTalents=true}),false)
 local ordinary={id="druid.wrath.caster",known=false}
 k.Availability:Annotate(ordinary,"DRUID","era"); eq(ordinary.availabilityState,"unlearned")
 eq(k.Availability:IsHidden(ordinary,{adaptTalents=true}),false)
 eq(k.Availability:IsHidden(ordinary,{hideUnavailableSpells=true}),true)
end

function Tests.availability_never_hides_missing_items_or_nonspell_commands()
 local k=TestAddon; k:Init()
 for _,kind in ipairs({"item","system","macroref","emote"}) do
  local a={id="druid.swiftmend",kind=kind,known=false,talent=true,availabilityState="talent"}
  k.Availability:Annotate(a,"DRUID","era")
  eq(a.availabilityState,nil); eq(k.Availability:IsHidden(a,{hideUnavailableSpells=true,adaptTalents=true}),false)
 end
 local a={id="builtin.cancel",builtin="cancel",known=false}
 k.Availability:Annotate(a,"DRUID","era"); eq(k.Availability:Status(a),nil)
end

function Tests.native_hidden_spells_reserve_identical_keys_and_slots_without_macro_cost()
 local k=TestAddon; k:Init(); Mock.build="1.15.9"; k.API:InvalidateBindingCommands()
 local original=k:Preview(); local plan=k.Copy(original)
 plan.settings.hideUnavailableSpells=true
 local layout,why=k.NativeBars:Prepare(plan); assert(layout,why)
 local byID={}; for _,a in ipairs(original.actions) do byID[a.id]=a end
 local hidden=0
 for _,a in ipairs(plan.actions) do
  local before=byID[a.id]
  eq(a.key,before.key,"Availability changed a key"); eq(a.nativeSlot,before.nativeSlot,"Availability moved a native slot")
  if a.nativeHidden then
   hidden=hidden+1; eq(k.NativeBars:ContentFor(a),false)
   if a.nativeSlot then eq(a.body,nil,"Hidden native action still costs a macro"); eq(a.nativeMacro,nil) end
  end
 end
 assert(hidden>0,"Fixture did not contain an unlearned spell")
 local a=action(plan,"druid.natures_swiftness.caster")
 assert(a and a.nativeHidden,"Talent spell on a native page was not hidden")
 eq(layout.keys[a.key].command,byID[a.id].nativeCommand,"Reserved key no longer targets its original button")
end

function Tests.native_hidden_overflow_reserves_key_with_inert_macro()
 local k=TestAddon; k:Init(); MultiBar5=nil; MultiBar6=nil; MultiBar7=nil
 local plan={class="MAGE",flavor="era",settings={hideUnavailableSpells=true},actions={}}
 for index=1,49 do plan.actions[index]={id="future."..index,name="Future "..index,label="Future",key="CTRL-F"..index,form="all",known=false} end
 local layout,why=k.NativeBars:Prepare(plan); assert(layout,why)
 eq(layout.overflow,1)
 local count=0
 for _,a in ipairs(plan.actions) do
  assert(a.nativeHidden)
  if a.nativeOverflow then
   count=count+1; eq(a.body,"#showtooltip"); eq(a.nativeMacro,true)
   eq(layout.keys[a.key].macroAction,a.id,"Overflow left a prior action exposed")
  else eq(a.body,nil); eq(a.nativeMacro,nil) end
 end
 eq(count,1)
end

function Tests.native_macro_names_toggle_only_fontstrings_and_survive_page_updates()
 local k=TestAddon; k:Init()
 local b=CreateFrame("CheckButton","ActionButton1",UIParent)
 b.Name=b:CreateFontString(nil,"OVERLAY"); b.Name:SetText("Personal Macro")
 b.HotKey=b:CreateFontString(nil,"OVERLAY"); b.HotKey:SetText("1")
 b.Name:SetAlpha(0.8); b:SetAttribute("action",1)
 function b:Update() self.Name:SetText("Updated Macro") end
 Mock.actions[1]={"macro",1}; local name,_,body=GetMacroInfo(1)
 k.db.preferences.showMacroNames=false; k.NativeBars:ApplyMacroTextPreference()
 eq(b.Name:GetAlpha(),0); eq(b.HotKey:GetAlpha(),1); assert(b:IsShown())
 b:Update(); eq(b.Name:GetAlpha(),0); eq(b.Name:GetText(),"Updated Macro")
 eq(b:GetAttribute("action"),1); eq(GetMacroInfo(1),name); local _,_,after=GetMacroInfo(1); eq(after,body)
 k.db.preferences.showMacroNames=true; k.NativeBars:ApplyMacroTextPreference()
 eq(b.Name:GetAlpha(),0.8,"Showing names did not restore original alpha")
end

function Tests.native_macro_name_preference_defers_combat_without_hiding_buttons()
 local k=TestAddon; k:Init()
 local b=CreateFrame("CheckButton","ActionButton1",UIParent); b.Name=b:CreateFontString(nil,"OVERLAY")
 Mock.combat=true; k.db.preferences.showMacroNames=false
 eq(k.NativeBars:ApplyMacroTextPreference(),false); eq(b.Name:GetAlpha(),1); assert(b:IsShown())
 Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
 eq(b.Name:GetAlpha(),0); assert(b:IsShown())
end

function Tests.availability_review_flag_ignores_reserved_families_but_finds_new_unbound_spells()
 local k=TestAddon; Mock.class="MAGE"; Mock.spells={}; Mock.forms={}
 Mock:Learn(116,"Frostbolt"); k:Init(); local plan=k:Preview()
 eq(k.AvailabilityEngine:HasUnboundLearnedSpells(plan),false)
 Mock:Learn(133,"Fireball"); k.API:InvalidateSpellbook()
 eq(k.AvailabilityEngine:HasUnboundLearnedSpells(plan),false,"Learning a reserved family falsely requires reapplying")
 Mock:Learn(999999,"Uncatalogued Research Spell"); k.API:InvalidateSpellbook()
 local missing,names=k.AvailabilityEngine:HasUnboundLearnedSpells(plan)
 eq(missing,true); eq(names[1],"Uncatalogued Research Spell")
 plan.actions[#plan.actions+1]={id="additional.999999",name="Uncatalogued Research Spell",spellIDs={999999},key="CTRL-F24"}
 eq(k.AvailabilityEngine:HasUnboundLearnedSpells(plan),false)
 plan.actions[#plan.actions].key=nil
 eq(k.AvailabilityEngine:HasUnboundLearnedSpells(plan),true,"A keyless action was reported covered")
end

function Tests.availability_review_flag_respects_explicit_shared_talent_priority()
 local k=TestAddon; Mock.class="PRIEST"; Mock.spells={}; Mock.forms={}
 Mock:Learn(10060,"Power Infusion"); Mock:Learn(15407,"Mind Flay"); k:Init()
 local plan={settings=k.Copy(k:GetSettings()),actions={{id="priest.power_infusion",name="Power Infusion",spellIDs={10060},key="F",talentChoices={"priest.power_infusion","priest.mind_flay"}}}}
 eq(k.AvailabilityEngine:HasUnboundLearnedSpells(plan),false,"Explicit lower-priority talent was reported as an accidental unbound spell")
end
