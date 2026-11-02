local function currentMage()
 local k=TestAddon; Mock.class='MAGE'; Mock.spells={}; Mock.catalog={}; Mock.forms={}
 UnitClass=function() return 'Mage','MAGE',8 end
 Mock:Learn(133,'Fireball'); Mock:Learn(116,'Frostbolt')
 Mock.bindings={['1']='ACTIONBUTTON1',['2']='ACTIONBUTTON2',F='OPENCHAT',G='TARGETSELF',BUTTON1='CAMERAORSELECTORMOVE',BUTTON2='TURNORACTION'}
 Mock.bindingInventory=nil; Mock.actions={[1]={'spell',133},[2]={'spell',133},[40]={'spell',133}}
 k:Init(); Mock:ResetWrites(); return k
end
function Tests.current_edit_sparse_rebind_preserves_preset_and_unrelated_controls()
 local k=currentMage(); local saved=k:Export(); local account=k.Copy(Mock.bindingSets[1])
 k.UI:Open(); assert(k.UI.library:IsShown())
 assert(k.UI:AssignBinding(k.UI.bindingPlan.byKey.F,'F9'))
 assert(#Mock.writes==0 and k:Export()==saved and k.UI.apply:IsEnabled())
 assert(k.UI.bindingPlan.byKey.F9.command=='OPENCHAT' and not k.UI.bindingPlan.byKey.F)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.bindings.F9=='OPENCHAT' and not Mock.bindings.F and Mock.bindings.G=='TARGETSELF')
 assert(Mock.actions[40][2]==133 and k:Export()==saved and not k.db.enabled)
 for key,value in pairs(account) do assert(Mock.bindingSets[1][key]==value) end
 assert(not k.CurrentBindings:HasEdits() and #k.Engine:ListBackups()==1)
end
function Tests.current_edit_live_slot_and_aliases_preview_then_apply()
 local k=currentMage(); Mock.bindings['ALT-1']='ACTIONBUTTON1'
 assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'1'))
 local view=k.CurrentBindings:EditingView()
 assert(view.byKey['1'].spellID==116 and view.byKey['ALT-1'].spellID==116)
 assert(Mock.actions[1][2]==133 and #Mock.writes==0)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.actions[1][2]==116 and Mock.actions[2][2]==133 and Mock.bindings['1']=='ACTIONBUTTON1')
end
function Tests.current_edit_external_change_rejected_before_backup()
 local k=currentMage(); assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey.F,'F9'))
 Mock.bindings.F='TARGETSELF'; Mock:ResetWrites()
 local ok,why=k.Engine:ApplyCurrentEdits(); assert(ok==false and why:find('changed'))
 assert(#Mock.writes==0 and #k.Engine:ListBackups()==0 and k.CurrentBindings:HasEdits())
end
function Tests.current_edit_write_failure_restores_controls_and_retains_draft()
 local k=currentMage(); assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'1'))
 assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey.F,'F9'))
 local set=SetBinding; SetBinding=function(key,command,...) if key=='F9' and command then return false end return set(key,command,...) end
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok=Mock:Drain(); assert(not ok)
 assert(Mock.actions[1][2]==133 and Mock.bindings.F=='OPENCHAT' and not Mock.bindings.F9)
 assert(k.CurrentBindings:HasEdits())
end
function Tests.current_edit_rebind_then_place_uses_staged_destination()
 local k=currentMage(); assert(k.CurrentBindings:Rebind(k.CurrentBindings:Get().byKey['1'],'F9'))
 assert(k.CurrentBindings:StageEntry({spellID=116,label='Frostbolt'},'F9'))
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
 assert(Mock.actions[1][2]==116 and Mock.bindings.F9=='ACTIONBUTTON1' and not Mock.bindings['1'])
end
function Tests.current_edit_future_spell_stays_in_prefilled_workflow()
 local k=currentMage(); Mock.catalog[999]={id=999,name='Future',icon=999}
 local ok,why=k.CurrentBindings:StageEntry({spellID=999,label='Future'},'F9')
 assert(not ok and why:find('not learned') and not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.character_login_replaces_foreign_selected_draft_without_deleting_it()
 local k=currentMage(); local foreign={id='p99',sourceClass='WARLOCK',settings=k.Copy(k.defaults),items={},equipment={}}
 k.db.presets={Warlock=foreign}; k.db.activePreset='Warlock'; k.db.schema=2
 k:Init(); assert(k.db.activePreset~='Warlock' and k.db.presets.Warlock==foreign)
 assert(#k.Presets:List()==1 and k.db.presets[k.db.activePreset].sourceClass=='MAGE')
 assert(not k.Presets:Select('Warlock')); assert(#Mock.writes==0)
 k:GetSettings().allowAccountMacros=true
 local ok,why=k.Presets:Activate(k.db.activePreset); assert(ok,why)
 assert(k.db.appliedPlan.class=='MAGE')
end
function Tests.character_login_disables_foreign_installed_plan_without_writes()
 local k=currentMage(); k.db.enabled=true; k.db.appliedPlan={class='WARLOCK',actions={}}
 Mock:ResetWrites(); Mock:Fire('PLAYER_LOGIN'); Mock:Advance(0.2)
 assert(not k.db.enabled and k.db.appliedPlan.class=='WARLOCK' and not k.Engine.busy)
 for _,write in ipairs(Mock.writes) do assert(write[1]~='binding' and write[1]~='action') end
end
