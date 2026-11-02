function Tests.followup_select_unchanged_preset_is_noop()
 local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros()
 assert(k.Presets:Activate('Leveling'))
 local count=#k.Engine:ListBackups()
 assert(k.Presets:Select('Leveling')); assert(not k.dirty)
 Mock:ResetWrites(); assert(k.Presets:Activate('Leveling'))
 assert(#Mock.writes==0 and #k.Engine:ListBackups()==count)
end
function Tests.followup_current_unreadable_slot_is_not_empty()
 local k=TestAddon; Mock.bindings={['1']='ACTIONBUTTON1'}; Mock.bindingInventory=nil
 GetActionInfo=function() error('Unreadable slot') end
 Mock:ResetWrites(); local p=k.CurrentBindings:Build()
 assert(p.byKey['1'].readError and not p.byKey['1'].liveEmpty and #p.errors>0)
 assert(#Mock.writes==0)
end
function Tests.followup_list_all_pages_is_available_and_keyboard_returns_to_single_page()
 local k=TestAddon; k:Init(); k.UI:Open(); k.UI:SetBindingSource('draft')
 local page=k.UI.pages.Bindings; page.modeButtons.List:Click()
 local options; local original=k.UI.Menu
 k.UI.Menu=function(_,_,values) options=values end
 page.form:Click(); k.UI.Menu=original
 assert(options[1].value=='all')
 k.UI:SetActionPage('all'); assert(k.UI.formFilter=='all')
 page.modeButtons.Keyboard:Click(); assert(k.UI.formFilter~='all')
end
for _,class in ipairs({'DRUID','HUNTER','MAGE','PALADIN','PRIEST','ROGUE','SHAMAN','WARLOCK','WARRIOR'}) do
 local selectedClass=class
 Tests['followup_hover_complete_catalog_'..class]=function()
  local k=TestAddon; Mock.class=selectedClass; Mock.spells={}; Mock.petSpells={}; Mock.catalog={}; Mock.forms={}
  for _,a in ipairs(k.Profiles:Get(selectedClass,'era')) do
   for _,id in ipairs(a.spellIDs or {}) do Mock.catalog[id]={id=id,name=a.name,icon=id} end
  end
  k:Init(); k:GetSettings().flavor='era'; k.db.preferences.showUnavailableBindings=false
  k.UI:Open(); k.UI:SetBindingSource('draft'); k.UI:OpenHoverBindings()
  local grid=k.UI.hoverBindings; assert(grid and grid.active)
  local count=0
  for _,a in ipairs(k.UI.plan.actions) do if not a.kind and not a.builtin then
   count=count+1; assert(grid.rows[a.id] and grid.rows[a.id]:IsShown(),'Missing '..selectedClass..' '..a.id)
  end end
  assert(count>0)
 end
end
function Tests.followup_hover_preserves_configured_rank()
 local k=TestAddon; k:Init(); assert(k.Library:SetRank('druid.wrath.caster',5176))
 k.UI:Open(); k.UI:SetBindingSource('draft'); k.UI:OpenHoverBindings()
 local a=k.UI.hoverBindings.rows['druid.wrath.caster'].action
 assert(a.spellID==5176 and a.explicitRank)
end

function Tests.followup_named_restore_waits_for_explicit_confirmation()
 local k=TestAddon; k:Init(); Mock:AllowFullCatalogMacros(); assert(k:Apply())
 k.UI:Open(); k.UI:ShowPage('Safety'); Mock:ResetWrites()
 k.UI.pages.Safety.restoreSelected:Click()
 assert(k.UI.confirm:IsShown() and not k.Engine.busy and #Mock.writes==0)
 k.UI.confirm:Hide(); assert(#Mock.writes==0)
end
