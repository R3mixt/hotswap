local function initUI(allowFixtureOverflow)
  TestAddon:Init()
  -- These activation scenarios need all spells in the cross-spec Druid fixture.
  if allowFixtureOverflow then TestAddon:GetSettings().allowAccountMacros=true end
  TestAddon.UI:Open(); TestAddon.UI:SetBindingSource("draft")
  return TestAddon
end
local function eq(a,b,why) assert(a==b,(why or "value")..": expected "..tostring(b)..", got "..tostring(a)) end

function Tests.full_presets_keep_independent_binding_settings_and_item_choices()
  local k=initUI()
  k:UpdateSetting("bindingOverrides",{["druid.rejuvenation"]="NUMPAD9"})
  k.db.presets.Leveling.items.potion=1710
  assert(k.Presets:Create("Raid night",true))
  k:UpdateSetting("bindingOverrides",{["druid.rejuvenation"]="NUMPAD8"})
  k:UpdateSetting("selfFallback",true)
  k.db.presets["Raid night"].items.potion=118
  assert(k.Presets:Select("Leveling"))
  eq(k:GetSettings().bindingOverrides["druid.rejuvenation"],"NUMPAD9","Original bindings changed with a duplicate")
  eq(k:GetSettings().selfFallback,false,"Original settings changed with a duplicate")
  eq(k.Items:GetSelected("potion"),1710,"Original item selection changed")
  assert(k.Presets:Select("Raid night"))
  eq(k:GetSettings().bindingOverrides["druid.rejuvenation"],"NUMPAD8","Custom bindings were not saved")
  eq(k:GetSettings().selfFallback,true,"Custom self-cast setting was not saved")
  eq(k.Items:GetSelected("potion"),118,"Custom item selection was not saved")
end

function Tests.mode_hotkeys_survive_switches_and_renaming_and_never_apply_in_combat()
  local k=initUI(true)
  assert(k.Presets:Create("Raid night",true))
  assert(k.Presets:SetHotkey("Leveling","CTRL-F11"))
  assert(k.Presets:SetHotkey("Raid night","CTRL-F12"))
  assert(k.Presets:Activate("Leveling"))
  local id=k.db.presets["Raid night"].id
  eq(GetBindingAction("CTRL-F12"),"CLICK KBO_Mode_"..id..":LeftButton","Mode hotkey missing")
  assert(k.Presets:Rename("Raid night","Dungeon healer"))
  Mock:Advance(1)
  k.Presets.buttons[id]:Click()
  eq(k.db.appliedPreset,"Dungeon healer","Stable hotkey did not follow rename")
  eq(GetBindingAction("CTRL-F11"),"CLICK KBO_Mode_"..k.db.presets.Leveling.id..":LeftButton","Switch dropped return hotkey")
  local before=#k.Engine:ListBackups()
  Mock.combat=true; Mock:ResetWrites()
  local ok=k.Presets:Activate("Leveling")
  assert(not ok,"Mode activated in combat")
  eq(#Mock.writes,0,"Combat shortcut mutated protected state")
  eq(#k.Engine:ListBackups(),before,"Rejected combat shortcut created backup")
  Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED")
  eq(k.db.appliedPreset,"Dungeon healer","Combat shortcut silently activated later")
end

function Tests.sharing_selected_preset_merges_without_replacing_current_active_layout()
  local k=initUI(true)
  assert(k.Presets:Activate("Leveling"))
  assert(k.Presets:Create("Shared healer",true))
  k:UpdateSetting("bindingOverrides",{["druid.rejuvenation"]="NUMPAD9"})
  local encoded=k:Export("Shared healer")
  assert(encoded:match("^KBO2"),"Export does not use the data-only collection format")
  local before=#k.Engine:ListBackups()
  local installed=GetBindingAction("Q")
  Mock:ResetWrites()
  local ok,why=k:Import(encoded); assert(ok,why)
  eq(k.db.activePreset,"Shared healer (2)","Import overwrote the existing mode")
  eq(k.db.appliedPreset,"Leveling","Import activated unreviewed bindings")
  eq(GetBindingAction("Q"),installed,"Import changed live bindings")
  eq(#k.Engine:ListBackups(),before,"Import unnecessarily created a live backup")
  eq(#Mock.writes,0,"Sharing performs protected writes")
  eq(k:GetSettings().bindingOverrides["druid.rejuvenation"],"NUMPAD9","Shared bindings lost")
  assert(k.db.presets["Shared healer"],"Import deleted the original mode")
end

function Tests.presets_support_many_custom_names_without_fixed_mode_slots()
  local k=initUI()
  for index=1,40 do assert(k.Presets:Create("Custom mode "..index,false)) end
  eq(#k.Presets:List(),43,"Preset manager imposes a three-mode limit")
  assert(k.Presets:Select("Custom mode 40"))
  local id=k.db.presets["Custom mode 40"].id
  assert(k.Presets:Rename("Custom mode 40","Travel and gathering"))
  eq(k.db.presets["Travel and gathering"].id,id,"Rename changed mode identity")
  assert(k.Presets:Delete("Custom mode 1"))
  assert(k.db.presets["Travel and gathering"],"Deleting another preset lost the selected mode")
end

function Tests.preset_tab_creates_names_and_activates_complete_layout_with_named_backup()
  local k=initUI(); k.UI:ShowPage("Presets")
  local page=k.UI.pages.Presets
  page.new:Click()
  k.UI.nameDialog.input:SetText("Healing dungeon")
  k.UI.nameDialog.save:Click(); Mock:Advance(0.02)
  eq(k.db.activePreset,"Healing dungeon","New preset UI did not select the mode")
  assert(not k.db.enabled,"Naming a preset applied it")
  page.hotkey:Click()
  Mock.ctrl=true; Mock:KeyDown("F11"); Mock.ctrl=false; Mock:Advance(0.03)
  eq(k.db.presets["Healing dungeon"].hotkey,"CTRL-F11","Preset shortcut was not captured")
  assert(not k.db.enabled,"Binding a shortcut applied the preset")
  -- A new preset starts with safe defaults; explicitly permit this oversized fixture.
  k:UpdateSetting("allowAccountMacros",true)
  page.usePreset:Click(); Mock:Advance(0.2)
  eq(k.db.appliedPreset,"Healing dungeon","Use preset did not activate the selected mode")
  assert(k.db.enabled,"Preset was not enabled")
  local backups=k.Engine:ListBackups(); assert(#backups>0,"Use preset skipped backup")
  assert(backups[1].name:find("Tester",1,true),"Backup label omits character")
  k.UI:ShowPage("Safety")
  assert(k.UI.pages.Safety.restoreSelected:IsEnabled(),"Named backup cannot be selected for restore")
  k.UI.pages.Safety.restoreSelected:Click(); Mock:Advance(0.2)
  assert(not k.db.enabled,"Restoring initial backup did not restore pre-addon state")
  assert(k.db.presets["Healing dungeon"],"Restoring bindings deleted the custom preset")
end

function Tests.import_export_has_own_page_and_import_never_activates_bindings()
  local k=initUI(true); assert(k.Presets:Activate("Leveling"))
  k.UI.nav.Share:Click()
  local page=k.UI.pages.Share
  eq(k.UI.activePage,"Share","Import/export tab did not open")
  page.exportSelected:Click()
  assert(page.transfer:GetText():match("^KBO2"),"Export selected did not populate transferable text")
  Mock:ResetWrites()
  page.import:Click(); Mock:Advance(0.2)
  eq(k.db.activePreset,"Leveling (2)","Import did not preserve colliding local preset")
  eq(k.db.appliedPreset,"Leveling","Import switched the active game layout")
  eq(#Mock.writes,0,"Import/export UI changed protected bindings")
  assert(page.help:GetText():find(".hotswap",1,true),"Export lacks external-file instructions")
end

function Tests.expected_replacements_are_not_presented_as_errors()
  local k=initUI()
  k.UI.reviewButton:Click()
  assert(k.UI.review and k.UI.review:IsShown(),"Planned changes view missing")
  assert(not k.UI.reviewExpanded,"Expected replacements should start collapsed")
  local function allText()
    local parts={}
    for _,frame in ipairs(Mock.frames) do
      if frame:IsVisible() and frame.GetText then parts[#parts+1]=frame:GetText() or "" end
    end
    return table.concat(parts,"\n")
  end
  assert(not allText():find("CONFLICT",1,true),"Normal replacement was still called a conflict")
  k.UI.review.expected:Click()
  local text=allText()
  assert(not text:find("ACTIONBUTTON",1,true),"Raw action-bar identifiers leak into normal replacement descriptions")
  assert(not text:find("→",1,true),"Unsupported arrow glyph remains in the review")
end
