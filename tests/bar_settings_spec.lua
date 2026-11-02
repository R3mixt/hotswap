local function equal(actual,expected,label)
 assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function init()
 TestAddon:Init(); return TestAddon
end
function Tests.native_bar_settings_distinguish_hidden_from_unsupported()
 local k=init(); local plan=k:Preview()
 MultiBar7:Hide(); _G.MultiBar6=nil
 local options=k.NativeBars:GetBarOptions(plan,k:GetSettings())
 equal(#options,7,"Settings list covers all native extra bars")
 equal(options[7].available,true,"Hidden bar was mistaken for an unsupported bar")
 equal(options[7].shown,false,"Hidden bar visibility")
 equal(options[6].available,false,"Unsupported bar capability")
 equal(options[1].required,plan.nativeLayout.usedBars[1] and true or false,"Required bar status")
end
function Tests.native_apply_turns_on_actual_hidden_frames_for_every_used_extra_bar()
 local k=init()
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do _G[bar.frame]:Hide(); Mock.actionToggles[bar.toggle]=false end
 local ok,why=k:Apply(); assert(ok,why)
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do
  if k.db.appliedPlan.nativeLayout.usedBars[bar.toggle] then
   equal(Mock.actionToggles[bar.toggle],true,"Native setting for used bar "..bar.toggle)
   assert(_G[bar.frame]:IsShown(),"Used bar remained hidden: "..bar.frame)
  end
 end
end
function Tests.native_bar_settings_apply_required_and_optional_choices_and_restore()
 local k=init(); local original=k.Copy(Mock.actionToggles)
 local options={[7]=true,[1]=false}
 k:UpdateSetting("nativeBars",options)
 equal(Mock.actionToggles[7],false,"Staged visibility changed the game")
 local ok,why=k:Apply(); assert(ok,why)
 equal(Mock.actionToggles[7],true,"Requested optional bar stayed hidden")
 equal(Mock.actionToggles[1],true,"A required bar was disabled by an override")
 ok,why=k:Restore(); assert(ok,why)
 for i=1,7 do equal(Mock.actionToggles[i],original[i],"Restore native visibility "..i) end
end
function Tests.native_bar_settings_can_hide_unused_bars_and_preserve_unspecified_ones()
 local k=init(); Mock.actionToggles[6]=true; Mock.actionToggles[7]=true
 k:UpdateSetting("nativeBars",{[7]=false})
 local plan=k:Preview()
 assert(not plan.nativeLayout.usedBars[6] and not plan.nativeLayout.usedBars[7],"Fixture needs two unused extra bars")
 local ok,why=k:Apply(); assert(ok,why)
 equal(Mock.actionToggles[6],true,"An unspecified unused bar was hidden")
 equal(Mock.actionToggles[7],false,"An explicitly disabled unused bar stayed visible")
end
function Tests.native_bar_settings_keep_nil_toggle_positions_and_legacy_numeric_flags()
 local k=init(); local real=GetActionBarToggles
 GetActionBarToggles=function() return nil,1,nil,1,nil,nil,1 end
 local options=k.NativeBars:GetBarOptions({nativeLayout={usedBars={}}},{nativeBars={}})
 for index,wanted in ipairs({false,true,false,true,false,false,true}) do
  equal(options[index].shown,wanted,"Legacy toggle at "..index)
 end
 local snapshot=k.NativeBars:Snapshot()
 GetActionBarToggles=real
 k.NativeBars:Restore(snapshot)
 for index,wanted in ipairs({false,true,false,true,false,false,true}) do
  equal(Mock.actionToggles[index],wanted,"Restored toggle at "..index)
 end
end
function Tests.native_bar_visibility_syncs_proxy_cache_and_refreshes_lagged_mirror()
 local k=init(); local cached={true,true,true,true,true,true,true}; local pending
 local proxies={}; local calls=0; local refreshMasks={}
 SetActionBarToggles=function(...) pending={...} end
 for index=1,7 do
  local at=index
  proxies[index]={SetValueDerived=function(_,value)
   calls=calls+1; cached[at]=value; SetActionBarToggles(unpack(cached))
  end}
 end
 Settings.GetSetting=function(variable) return proxies[tonumber(variable:match("(%d+)$"))-1] end
 MultiActionBar_Update=function() refreshMasks[#refreshMasks+1]=k.Copy(Mock.actionToggles) end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={[1]=true}}}
 assert(k.NativeBars:Apply(plan))
 equal(calls,7,"Every cached proxy bit must be synchronized, including unchanged false bits")
 for i=1,7 do equal(cached[i],i==1 or i==7,"Private mask cache "..i) end
 equal(Mock.actionToggles[7],false,"Fixture must still have a stale server mirror")
 Mock:Advance(0.3)
 Mock.actionToggles=pending; Mock:Advance(0.3)
 equal(refreshMasks[#refreshMasks][7],true,"Native bars were not refreshed after the mirror arrived")
 for i=1,40 do Mock:Advance(0.3) end
 assert(not k.NativeBars.visibilityObserver:GetScript("OnUpdate"),"Visibility polling was not bounded")
end
function Tests.native_bar_refresh_pauses_in_combat_and_restore_supersedes_old_requests()
 local k=init(); local old=k.NativeBars:Snapshot(); local pending
 SetActionBarToggles=function(...) pending={...} end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={}}}
 k.NativeBars:Apply(plan)
 Mock.combat=true; local before=Mock.barUpdates
 Mock.actionToggles=pending; Mock:Advance(0.5)
 equal(Mock.barUpdates,before,"Deferred visibility mutated frames during combat")
 Mock.combat=false; k.NativeBars:Restore(old)
 Mock.actionToggles=pending; Mock:Advance(0.5)
 equal(Mock.actionToggles[7],false,"A stale apply refresh overwrote Restore")
 assert(Mock.barUpdates>before,"Visibility did not refresh after combat")
end
