local function equal(actual,expected,label)
 assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function sameMap(actual,expected,label)
 for key,value in pairs(expected) do equal(actual[key],value,(label or "binding map").." "..key) end
 for key,value in pairs(actual) do equal(value,expected[key],(label or "binding map").." unexpected "..key) end
end
local function fresh(inherited)
 local k=TestAddon
 KeybindOptimizerDB=nil; k.db=nil
 Mock.build="1.15.9"; Mock.buildNumber="70576"; Mock.class="WARRIOR"
 Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
 Mock:Learn(78,"Heroic Strike"); Mock:Learn(2457,"Battle Stance")
 Mock.bindings=k.Copy(inherited); Mock.bindingSet=1; Mock.bindingInventory=nil
 Mock.bindingSets={[1]=k.Copy(inherited),[2]={C="TOGGLECHARACTER0"}}
 Mock:ResetWrites()
 return k
end
local function loginWithoutCapture(k)
 k:Init()
 Mock:Fire("ADDON_LOADED","KeybindOptimizer")
 Mock:Fire("PLAYER_LOGIN")
 Mock:Fire("UPDATE_BINDINGS")
 Mock:Advance(1,10)
 equal(#Mock.writes,0,"A fresh closed addon changed game state before Apply")
 assert(not k.db.enabled and not k.db.appliedPlan,"Fresh login activated a preset")
 assert(not k.Engine.busy,"Fresh login started an engine transaction")
 assert(not k.UI.frame,"Fresh login constructed the configuration window")
 assert(not k.UI.capture and not k.UI.tester and not k.UI.testMouseShield,"Fresh login constructed an input capture overlay")
 for _,frame in ipairs(Mock.frames) do
  assert(not (frame:IsVisible() and frame.keyboard and frame.propagate==false),"Fresh login left a visible keyboard sink")
 end
end

function Tests.fresh_character_native_account_controls_survive_login_and_binding_events_without_writes()
 local inherited={W="MOVEFORWARD",S="MOVEBACKWARD",TAB="TARGETNEARESTENEMY",F="ASSISTTARGET",
  BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION",MOUSEWHEELUP="CAMERAZOOMIN"}
 local k=fresh(inherited)
 loginWithoutCapture(k)
 equal(GetCurrentBindingSet(),1)
 sameMap(Mock.bindings,inherited,"Active controls")
 sameMap(Mock.bindingSets[1],inherited,"Saved account controls")
end

function Tests.fresh_character_broken_inherited_controls_remain_unchanged_until_explicit_apply()
 -- Model the effective unbound keys caused by the account cache's NONE
 -- overrides, without inventing a client API return value for that file token.
 local inherited={W="MOVEFORWARD",S="MOVEBACKWARD",F="ASSISTTARGET",F12="SCREENSHOT"}
 local k=fresh(inherited)
 loginWithoutCapture(k)
 equal(GetBindingAction("BUTTON1"),""); equal(GetBindingAction("BUTTON2"),"")
 equal(GetBindingAction("TAB"),"")
 sameMap(Mock.bindings,inherited,"Inherited missing controls")
 local accountBefore=k.Copy(Mock.bindingSets[1])
 local ok,why,name=k.Presets:CreateRecommended(); assert(ok,why)
 assert(k.Presets:Activate(name))
 assert(k.db.enabled and k.db.appliedPlan,"Optimize did not install the character layout")
 equal(GetCurrentBindingSet(),2,"Optimize used account-wide bindings")
 equal(GetBindingAction("BUTTON1"),"CAMERAORSELECTORMOVE")
 equal(GetBindingAction("BUTTON2"),"TURNORACTION")
 equal(GetBindingAction("TAB"),"TARGETNEARESTENEMY")
 equal(GetBindingAction("W"),"MOVEFORWARD")
 equal(GetBindingAction("F12"),"SCREENSHOT","Unassigned personal key changed")
 sameMap(Mock.bindingSets[1],accountBefore,"Optimize changed inherited account controls")
 equal(Mock.bindingSets[2].BUTTON1,"CAMERAORSELECTORMOVE")
 equal(Mock.bindingSets[2].BUTTON2,"TURNORACTION")
 assert(not k.UI.frame and not k.UI.testMouseShield,"Headless Optimize captured gameplay input")
end

function Tests.fresh_character_camera_protection_keeps_personal_mouse_commands_during_apply()
 local inherited={W="MOVEFORWARD",TAB="TARGETNEARESTENEMY",BUTTON1="TARGETSELF",BUTTON2="OPENCHAT",
  ["CTRL-BUTTON4"]="TURNORACTION",MOUSEWHEELUP="CAMERAZOOMIN"}
 local k=fresh(inherited)
 loginWithoutCapture(k)
 k:GetSettings().preserveCamera=true
 local ok,why,name=k.Presets:CreateRecommended(); assert(ok,why)
 assert(k.Presets:Activate(name))
 equal(GetCurrentBindingSet(),2)
 equal(GetBindingAction("BUTTON1"),"TARGETSELF")
 equal(GetBindingAction("BUTTON2"),"OPENCHAT")
 equal(GetBindingAction("CTRL-BUTTON4"),"TURNORACTION")
 equal(GetBindingAction("MOUSEWHEELUP"),"CAMERAZOOMIN")
 sameMap(Mock.bindingSets[1],inherited,"Protected setup changed saved account controls")
end
