-- Cross-feature release checks use ordinary native actions, real character
-- macro limits and repeated operations, independent of curated fixture size.
local function ready()
 local k=TestAddon
 Mock.class='MAGE'; Mock.build='1.15.9'; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 Mock:Learn(133,'Fireball'); Mock:Learn(116,'Frostbolt')
 Mock.bindings={['1']='ACTIONBUTTON1',F12='SCREENSHOT',BUTTON1='CAMERAORSELECTORMOVE',BUTTON2='TURNORACTION'}
 Mock.actions={[1]={'spell',133}}; Mock.bindingInventory=nil
 k:Init(); Mock:ResetWrites(); return k
end
local function finish(k)
 local status,why=k.Engine:ApplyCurrentEdits(); assert(status=='pending',why)
 local ok,message=Mock:Drain(); assert(ok,message)
end
function Tests.release_current_repeated_apply_import_reopen_restore_preserves_native_controls()
 local k=ready(); local before=k.Copy(Mock.bindings); local account=k.Copy(Mock.bindingSets[1])
 local selected=k.db.activePreset; local settings=k.db.settings
 local preferences=k.db.preferences; preferences.confirmReplacements=false; preferences.confirmSwaps=false
 local code=k:Export(selected)
 for iteration=1,12 do
  local id=iteration%2==0 and 133 or 116
  assert(k.CurrentBindings:StageEntry({spellID=id,label=id==133 and 'Fireball' or 'Frostbolt'},'1'))
  finish(k)
  assert(Mock.actions[1][2]==id and Mock.bindings.F12=='SCREENSHOT')
  local ok,why=k:Import(code); assert(ok,why)
  assert(k.db.activePreset==selected and k.db.settings==settings)
  assert(k.db.preferences==preferences and preferences.confirmReplacements==false and preferences.confirmSwaps==false)
  k.UI:Open(); assert(k.UI.bindingSource=='current')
  k.UI:ShowPage('Presets'); k.UI.frame:Hide(); k.UI:Open()
  assert(k.UI.bindingSource=='current' and k.UI.activePage=='Bindings')
  k.UI.frame:Hide()
 end
 local a,c=GetNumMacros(); assert(a==1 and c==0,'Simple current edits generated macros')
 for key,value in pairs(account) do assert(Mock.bindingSets[1][key]==value) end
 local backups=k.Engine:ListBackups(); assert(#backups==12)
 local oldest=backups[#backups]
 local ok,why=k.Engine:RestoreBackup(oldest.id); assert(ok,why)
 assert(Mock.actions[1][2]==133)
 for key,value in pairs(before) do assert(Mock.bindings[key]==value) end
end
function Tests.release_combat_never_applies_staged_current_edit_or_imported_preset()
 local k=ready(); assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'1'))
 local source=k.db.settings; local selected=k.db.activePreset; local code=k:Export(selected)
 Mock.combat=true; Mock:ResetWrites()
 local ok=k.Engine:ApplyCurrentEdits(); assert(not ok)
 assert(k:Import(code)); assert(k.db.settings==source and k.db.activePreset==selected)
 assert(#Mock.writes==0 and Mock.actions[1][2]==133)
 Mock.combat=false; Mock:Fire('PLAYER_REGEN_ENABLED'); Mock:Advance(1,10)
 assert(Mock.actions[1][2]==133 and k.CurrentBindings:HasEdits(),'Combat end installed a draft')
 finish(k); assert(Mock.actions[1][2]==116)
end
function Tests.release_malformed_transfer_corpus_never_executes_or_mutates_state()
 local k=ready(); local original=k:Export(); local settings=k.db.settings
 local selected=k.db.activePreset; local counter=k.db.nextPresetID
 local inputs={'', '\239\187\191', 'KBO2\n/run _G.RELEASE_INJECTED=true',
  'KBO1\ns\tmount\tnumber\t1e999', 'KBO1\ns\tmount\tnumber\t-1',
  'KBO1\nb\tdruid.wrath\tCTRL-CTRL-Q', 'KBO1\ns\twheel\tboolean\tTRUE'}
 for n=0,127 do
  inputs[#inputs+1]='KBO2\nunknown'..string.char(n)..'\t'..string.rep('x',n)
  inputs[#inputs+1]='KBO1\nb\tbad/id'..string.char(n)..'\tF9'
 end
 Mock:ResetWrites()
 for index,payload in ipairs(inputs) do
  local called,ok=pcall(k.Import,k,payload)
  assert(called and not ok,'Malformed corpus entry escaped validation: '..index)
  assert(k.db.settings==settings and k.db.activePreset==selected and k.db.nextPresetID==counter)
 end
 assert(k:Export()==original and #Mock.writes==0 and _G.RELEASE_INJECTED==nil)
end
