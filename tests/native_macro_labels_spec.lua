local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function tooltipContains(text)
 text=text:lower()
 if tostring(GameTooltip:GetText()):lower():find(text,1,true) then return true end
 for _,line in ipairs(GameTooltip.lines or {}) do if tostring(line):lower():find(text,1,true) then return true end end
 return false
end
local function ready()
 local k=TestAddon; k:Init(); Mock.equipment={}
 k.db.enabled=true
 k.db.appliedPlan={class="DRUID",settings=k.Copy(k:GetSettings()),actions={},nativeLayout={placements={},keys={}}}
 -- Model only the native tooltip surface needed by these tests. Ownership,
 -- slot lookup and macro indices remain live, including bank reindexing.
 function GameTooltip:GetOwner() return self.owner end
 function GameTooltip:IsOwned(owner) return self.owner==owner end
 function GameTooltip:ClearLines() self.lines={}; self:SetText("") end
 function GameTooltip:SetInventoryItem(unit,slot)
  local id=GetInventoryItemID(unit,slot); local name=id and GetItemInfo(id)
  if not name then return false end
  self:SetText(name); self:AddLine("Native item attributes"); return true
 end
 function GameTooltip:SetAction(slot)
  local kind,index=GetActionInfo(slot)
  if kind~="macro" then self:SetText(kind=="spell" and "Native spell tooltip" or ""); return kind~=nil end
  local name,_,body=GetMacroInfo(index)
  local equipped=body and tonumber(body:match("^#showtooltip (%d+)"))
  if equipped and self:SetInventoryItem("player",equipped) then return true end
  self:SetText(name or ""); self:AddLine("Native action description"); return name~=nil
 end
 return k
end
local function owned(k,id,slot,label,body,itemSlot)
 local name=k.Macros:Name(body); local index=CreateMacro(name,1,body,true)
 k.db.ownedMacros[name]=body
 local a={id=id,key=itemSlot==13 and "T" or itemSlot==14 and "SHIFT-T" or "Q",label=label,name=label,
  body=body,macroName=name,macroIndex=index,nativeSlot=slot,known=true,form="all",nativeMacro=true,itemSlot=itemSlot,kind=itemSlot and "item" or nil}
 k.db.appliedPlan.actions[#k.db.appliedPlan.actions+1]=a
 k.db.appliedPlan.nativeLayout.placements[#k.db.appliedPlan.nativeLayout.placements+1]={slot=slot,actionID=id}
 Mock.actions[slot]={"macro",index}
 return a
end
local function button(name,slot,globalFont)
 local b=CreateFrame("CheckButton",name,UIParent,"SecureActionButtonTemplate")
 local font=b:CreateFontString(nil,"OVERLAY"); font:SetAlpha(0.8)
 if globalFont then _G[name.."Name"]=font else b.Name=font end
 b.HotKey=b:CreateFontString(nil,"OVERLAY"); b.HotKey:SetText("T")
 b.Count=b:CreateFontString(nil,"OVERLAY"); b.Count:SetText("7")
 b.action=slot; b:SetAttribute("action",slot)
 function b:Update(...)
  self.updateArgs={...}
  local kind,index=GetActionInfo(self.action or self:GetAttribute("action"))
  local text=kind=="macro" and GetMacroInfo(index) or ""
  font:SetText(text or "")
  return "native update",42
 end
 function b:SetTooltip(...)
  self.tooltipArgs={...}
  GameTooltip:SetOwner(self.tooltipOwnerOverride or self,"ANCHOR_RIGHT")
  GameTooltip:SetAction(self.action or self:GetAttribute("action")); GameTooltip:Show()
  return "native tooltip",43
 end
 b:Update(); return b,font
end
local function trinkets(k)
 return owned(k,"item.trinket13",61,"Trinket · upper slot","#showtooltip 13\n/use 13",13),
  owned(k,"item.trinket14",62,"Trinket · lower slot","#showtooltip 14\n/use 14",14)
end

function Tests.native_macro_labels_friendly_trinket_names_change_only_cosmetic_text()
 local k=ready(); local upper=trinkets(k); local b,font=button("MultiBarBottomLeftButton1",upper.nativeSlot)
 equal(font:GetText(),upper.macroName)
 k.plan={actions={{id=upper.id,label="Unapplied draft label",nativeSlot=upper.nativeSlot}}}
 Mock:ResetWrites(); k.NativeBars:ApplyMacroTextPreference()
 equal(font:GetText(),"Trinket 1"); equal(font:GetAlpha(),0.8)
 equal(b.HotKey:GetText(),"T"); equal(b.Count:GetText(),"7"); assert(b:IsShown())
 equal(b:GetAttribute("action"),upper.nativeSlot)
 local first,second=b:Update("preserved",99); equal(first,"native update"); equal(second,42)
 equal(b.updateArgs[1],"preserved"); equal(b.updateArgs[2],99); equal(font:GetText(),"Trinket 1")
 local name,_,body=GetMacroInfo(GetMacroIndexByName(upper.macroName)); equal(name,upper.macroName); equal(body,upper.body)
 equal(#Mock.writes,0,"Friendly labels changed protected state or a macro")
end

function Tests.native_macro_labels_follow_effective_action_page_without_stale_personal_or_spell_labels()
 local k=ready(); local upper,lower=trinkets(k)
 local spell=owned(k,"druid.rejuvenation",73,"Rejuvenation","#showtooltip Rejuvenation\n/cast [@player] Rejuvenation")
 local personal=CreateMacro("My personal button",1,"/say Personal",true); Mock.actions[74]={"macro",personal}
 Mock.actions[75]={"spell",774}
 local b,font=button("ActionButton1",upper.nativeSlot)
 k.NativeBars:ApplyMacroTextPreference(); equal(font:GetText(),"Trinket 1")
 -- .action changes with the native page; the base attribute intentionally stays61.
 for _,entry in ipairs({{lower.nativeSlot,"Trinket 2"},{spell.nativeSlot,"Rejuvenation"},{74,"My personal button"},{75,""},{76,""}}) do
  b.action=entry[1]; b:Update(); equal(font:GetText(),entry[2])
 end
 equal(b:GetAttribute("action"),upper.nativeSlot)
end

function Tests.native_macro_labels_refuse_edited_or_unowned_generated_names()
 local k=ready(); local upper=trinkets(k); local b,font=button("ActionButton1",upper.nativeSlot)
 k.NativeBars:ApplyMacroTextPreference(); equal(font:GetText(),"Trinket 1")
 EditMacro(GetMacroIndexByName(upper.macroName),nil,nil,"/say My replacement")
 b:Update(); equal(font:GetText(),upper.macroName,"Edited macro retained a misleading generated label")
 local _,_,body=GetMacroInfo(GetMacroIndexByName(upper.macroName)); equal(body,"/say My replacement")
 local foreign=CreateMacro("KBO_foreign_name",1,"#showtooltip 13\n/use 13",true)
 Mock.actions[63]={"macro",foreign}; b.action=63; b:Update()
 equal(font:GetText(),"KBO_foreign_name","An unowned KBO-looking macro was relabeled")
 b:SetTooltip(); assert(not tooltipContains("No trinket equipped"),"Unowned macro received owned-slot tooltip instructions")
end

function Tests.native_macro_labels_hide_option_restores_alpha_and_latest_friendly_text_after_updates()
 local k=ready(); local upper,lower=trinkets(k); local b,font=button("ActionButton1",upper.nativeSlot)
 k.db.preferences.showMacroNames=false; k.NativeBars:ApplyMacroTextPreference()
 equal(font:GetAlpha(),0); equal(b.HotKey:GetAlpha(),1)
 b.action=lower.nativeSlot; b:Update(); equal(font:GetAlpha(),0)
 k.db.preferences.showMacroNames=true; k.NativeBars:ApplyMacroTextPreference()
 equal(font:GetAlpha(),0.8); equal(font:GetText(),"Trinket 2")
 equal(b.HotKey:GetText(),"T"); equal(b.Count:GetText(),"7"); assert(b:IsShown())
end

function Tests.native_macro_labels_defer_combat_and_resolve_current_page_after_regen()
 local k=ready(); local upper,lower=trinkets(k); local b,font=button("ActionButton1",upper.nativeSlot)
 k.NativeBars:ApplyMacroTextPreference(); equal(font:GetText(),"Trinket 1")
 Mock.combat=true; b.action=lower.nativeSlot; Mock:ResetWrites()
 equal(k.NativeBars:ApplyMacroTextPreference(),false); equal(font:GetText(),"Trinket 1"); equal(#Mock.writes,0)
 Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
 equal(font:GetText(),"Trinket 2","Deferred update replayed an old action page")
 equal(#Mock.writes,0); equal(b:GetAttribute("action"),upper.nativeSlot)
end

function Tests.native_macro_labels_support_late_buttons_global_fontstrings_and_attribute_fallback()
 local k=ready(); local upper=trinkets(k); k.NativeBars:ApplyMacroTextPreference()
 local b,font=button("MultiBar7Button12",upper.nativeSlot,true); b.action=nil
 Mock:Fire("ADDON_LOADED","Blizzard_ActionBar")
 equal(font:GetText(),"Trinket 1")
 k.NativeBars:ApplyMacroTextPreference(); k.NativeBars:ApplyMacroTextPreference()
 b:Update("still native"); equal(font:GetText(),"Trinket 1"); equal(b.updateArgs[1],"still native")
end

function Tests.native_macro_labels_empty_trinket_tooltips_explain_both_slots_without_duplicate_lines()
 local k=ready(); local upper,lower=trinkets(k); local b=button("ActionButton1",upper.nativeSlot)
 k.NativeBars:ApplyMacroTextPreference()
 local first,second=b:SetTooltip("optional",17); equal(first,"native tooltip"); equal(second,43)
 equal(b.tooltipArgs[1],"optional"); equal(b.tooltipArgs[2],17)
 equal(GameTooltip:GetText(),"Upper trinket"); assert(tooltipContains("No trinket equipped")); assert(GameTooltip:IsOwned(b))
 local count=#GameTooltip.lines
 for _=1,3 do k.NativeBars:ApplyMacroTextPreference(); b:SetTooltip() end
 equal(#GameTooltip.lines,count,"Repeated tooltip updates duplicated slot instructions")
 b.action=lower.nativeSlot; b:Update(); b:SetTooltip()
 equal(GameTooltip:GetText(),"Lower trinket"); assert(tooltipContains("No trinket equipped"))
end

function Tests.native_macro_labels_trinket_tooltips_preserve_live_native_item_details_and_unknown_state()
 local k=ready(); local upper=trinkets(k); local b=button("ActionButton1",upper.nativeSlot)
 k.NativeBars:ApplyMacroTextPreference()
 Mock.equipment[13]=900011; Mock.itemInfo[900011]={name="Passive Badge",kind="Armor",equipLoc="INVTYPE_TRINKET"}
 b:SetTooltip(); equal(GameTooltip:GetText(),"Passive Badge"); assert(tooltipContains("Native item attributes"))
 assert(tooltipContains("No usable item effect reported"))
 Mock.equipment[13]=900012; Mock.itemInfo[900012]=nil
 b:SetTooltip(); assert(tooltipContains("Loading item details"))
 assert(not tooltipContains("No usable item effect reported"),"Uncached trinket was labeled as having no effect")
 Mock.itemInfo[900012]={name="Active Badge",kind="Armor",equipLoc="INVTYPE_TRINKET",effect="Badge activation"}
 b:SetTooltip(); equal(GameTooltip:GetText(),"Active Badge"); assert(tooltipContains("Native item attributes"))
 assert(not tooltipContains("No usable item effect reported") and not tooltipContains("Loading item details"))
 assert(tooltipContains("Upper trinket") or tooltipContains("slot 13"),"Usable trinket tooltip lost its slot purpose")
 local name,_,body=GetMacroInfo(GetMacroIndexByName(upper.macroName)); equal(name,upper.macroName); equal(body,upper.body)
end

function Tests.native_macro_labels_tooltip_hook_never_takes_another_tooltip_owner()
 local k=ready(); local upper=trinkets(k); local b=button("ActionButton1",upper.nativeSlot)
 local other=CreateFrame("Frame",nil,UIParent); b.tooltipOwnerOverride=other
 k.NativeBars:ApplyMacroTextPreference(); b:SetTooltip()
 assert(GameTooltip:IsOwned(other)); equal(GameTooltip:GetText(),upper.macroName)
 assert(not tooltipContains("No trinket equipped"),"Post-hook modified another owner's tooltip")
end

function Tests.native_macro_labels_legacy_global_update_and_tooltip_hooks_preserve_native_calls()
 local k=ready(); local upper=trinkets(k); local b,font=button("ActionButton1",upper.nativeSlot,true)
 local update,tooltip=b.Update,b.SetTooltip
 b.Update=nil; b.SetTooltip=nil
 ActionButton_Update=function(frame,...) return update(frame,...) end
 ActionButton_SetTooltip=function(frame,...) return tooltip(frame,...) end
 k.NativeBars:ApplyMacroTextPreference()
 local first,second=ActionButton_Update(b,"legacy update")
 equal(first,"native update"); equal(second,42); equal(b.updateArgs[1],"legacy update")
 equal(font:GetText(),"Trinket 1")
 first,second=ActionButton_SetTooltip(b,"legacy tooltip")
 equal(first,"native tooltip"); equal(second,43); equal(b.tooltipArgs[1],"legacy tooltip")
 equal(GameTooltip:GetText(),"Upper trinket"); assert(tooltipContains("No trinket equipped"))
end
