-- Full-catalog transaction fixtures explicitly use synthetic character capacity; capacity tests retain 30.
local function equal(actual,expected,label)
 assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function init()
 TestAddon:Init(); Mock:AllowFullCatalogMacros(); return TestAddon
end
local function nativeVisibilityEvent()
 -- Simulate Blizzard's controller receiving a native page/form/settings-load
 -- event. Native toggle setters alone do not guarantee this visual refresh.
 local previous=Mock.inNativeVisibilityEvent; Mock.inNativeVisibilityEvent=true
 MultiActionBar_Update(); Mock.inNativeVisibilityEvent=previous
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
function Tests.native_apply_enables_used_extra_bars_for_a_later_native_visibility_event()
 local k=init()
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do _G[bar.frame]:Hide(); Mock.actionToggles[bar.toggle]=false end
 local ok,why=k:Apply(); assert(ok,why)
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do assert(not _G[bar.frame]:IsShown(),"Apply forced a protected frame refresh") end
 nativeVisibilityEvent()
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
function Tests.native_bar_visibility_syncs_proxy_cache_without_refreshing_a_lagged_mirror()
 local k=init(); local cached={true,true,true,true,true,true,true}; local pending
 local proxies={}; local calls=0; local refreshMasks={}
 SetActionBarToggles=function(...) pending={...} end
 for index=1,7 do
  local at=index
  proxies[index]={GetValueDerived=function() return select(at,GetActionBarToggles()) end,SetValueDerived=function(_,value)
   calls=calls+1; cached[at]=value; SetActionBarToggles(unpack(cached))
  end}
 end
 Settings.GetSetting=function(variable) return proxies[tonumber(variable:match("(%d+)$"))-1] end
 Settings.NotifyUpdate=function() error("Addon notified protected bar settings") end
 MultiActionBar_Update=function()
  assert(Mock.inNativeVisibilityEvent,"Addon forced a protected bar refresh")
  refreshMasks[#refreshMasks+1]=k.Copy(Mock.actionToggles)
 end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={[1]=true}}}
 assert(k.NativeBars:Apply(plan))
 equal(calls,7,"Every cached proxy bit must be synchronized, including unchanged false bits")
 for i=1,7 do equal(cached[i],i==1 or i==7,"Private mask cache "..i) end
 equal(Mock.actionToggles[7],false,"Fixture must still have a stale server mirror")
 Mock:Advance(0.3)
 Mock.actionToggles=pending; Mock:Advance(0.3)
 equal(#refreshMasks,0,"Addon refreshed frames when the mirror arrived")
 nativeVisibilityEvent()
 equal(refreshMasks[#refreshMasks][7],true,"Native event did not read the mirrored toggle")
 for i=1,40 do Mock:Advance(0.3) end
 equal(#refreshMasks,1,"Addon kept polling protected frames")
 assert(not k.NativeBars.visibilityObserver,"Addon created a visibility polling frame")
end
function Tests.native_bar_mask_restore_supersedes_apply_without_combat_frame_refreshes()
 local k=init(); local old=k.NativeBars:Snapshot(); local pending
 SetActionBarToggles=function(...) pending={...} end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={}}}
 k.NativeBars:Apply(plan)
 Mock.combat=true; local before=Mock.barUpdates
 Mock.actionToggles=pending; Mock:Advance(0.5)
 equal(Mock.barUpdates,before,"Deferred visibility mutated frames during combat")
 Mock.combat=false; k.NativeBars:Restore(old)
 Mock.actionToggles=pending; Mock:Advance(0.5)
 equal(Mock.actionToggles[7],false,"A stale apply request overwrote Restore")
 equal(Mock.barUpdates,before,"Addon refreshed protected frames after combat")
 assert(not k.NativeBars.visibilityObserver,"Addon kept a deferred visibility observer")
 nativeVisibilityEvent(); equal(MultiBar7:IsShown(),false,"Native event did not apply restored visibility")
end
function Tests.native_bar_apply_reapply_and_restore_never_invoke_native_layout_callbacks()
 local k=init(); local native=MultiActionBar_Update; local updates=0
 Settings.NotifyUpdate=function() error("Addon notified protected bar settings") end
 MultiActionBar_Update=function()
  assert(Mock.inNativeVisibilityEvent,"Addon invoked a native bar layout callback")
  updates=updates+1; return native()
 end
 local original=k.Copy(Mock.actionToggles)
 local ok,why=k:Apply(); assert(ok,why)
 equal(updates,0,"Apply invoked a native bar layout callback")
 nativeVisibilityEvent()
 local afterApply=updates
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do
  if k.db.appliedPlan.nativeLayout.usedBars[bar.toggle] then assert(_G[bar.frame]:IsShown(),"Apply left a required bar hidden") end
 end
 Mock.actionToggles={false,false,false,false,false,false,false}
 ok,why=k.Engine:ReapplyCurrentProfile(); if ok=="pending" then ok,why=Mock:Drain() end; assert(ok,why)
 equal(updates,afterApply,"Reapply invoked a native bar layout callback")
 nativeVisibilityEvent()
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do
  if k.db.appliedPlan.nativeLayout.usedBars[bar.toggle] then assert(_G[bar.frame]:IsShown(),"Reapply left a required bar hidden") end
 end
 local afterReapply=updates
 Mock:ResetWrites()
 ok,why=k.Engine:ReapplyCurrentProfile(); if ok=="pending" then ok,why=Mock:Drain() end; assert(ok,why)
 for _,write in ipairs(Mock.writes) do assert(write[1]~="actiontoggles","Unchanged Reapply wrote native toggles") end
 equal(updates,afterReapply,"Unchanged Reapply invoked a native bar layout callback")
 ok,why=k:Restore(); assert(ok,why)
 equal(updates,afterReapply,"Restore invoked a native bar layout callback")
 nativeVisibilityEvent()
 for _,bar in ipairs(k.NativeBars:AvailableBars()) do
  equal(Mock.actionToggles[bar.toggle],original[bar.toggle],"Restore changed the original native toggle")
  equal(_G[bar.frame]:IsShown(),original[bar.toggle],"Restore did not refresh the original native visibility")
 end
end
function Tests.native_bar_refresh_without_settings_dispatch_leaves_frames_to_native_events()
 local k=init(); Settings.GetSetting=nil; Settings.NotifyUpdate=nil
 MultiActionBar_Update=function() error("Addon used an insecure legacy refresh fallback") end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={}}}
 assert(k.NativeBars:Apply(plan)); equal(Mock.actionToggles[7],true,"Missing Settings dispatch lost the native toggle write")
 for i=1,40 do Mock:Advance(0.3) end
 assert(not k.NativeBars.visibilityObserver,"Missing Settings dispatch left a polling observer")
end
function Tests.native_bar_unchanged_normalized_mask_skips_proxy_and_native_writes()
 local k=init(); Mock.actionToggles={false,true,false,true,false,false,true}
 Settings.GetSetting=function() error("Unchanged mask accessed private proxy setters") end
 SetActionBarToggles=function() error("Unchanged mask wrote native toggles") end
 k.NativeBars:Restore({actions={},toggles={0,1,false,"1",false,false,true}})
 assert(not k.NativeBars.pendingToggleMask,"Unchanged mask created an outstanding write")
end
function Tests.native_bar_restore_before_mirror_cancels_the_outstanding_apply_mask()
 local k=init(); local old=k.NativeBars:Snapshot(); local pending; local writes=0
 SetActionBarToggles=function(...) writes=writes+1; pending={...} end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={[1]=true}}}
 k.NativeBars:Apply(plan); local afterApply=writes
 assert(pending[1] and pending[7] and k.NativeBars.pendingToggleMask,"Fixture needs an outstanding native mask")
 for index=1,7 do equal(Mock.actionToggles[index],old.toggles[index],"Fixture mirror advanced before Restore") end
 k.NativeBars:Restore(old)
 assert(writes>afterApply,"Restore skipped because the old mask was still in the server mirror")
 for index=1,7 do equal(pending[index],old.toggles[index],"Final pending Restore mask "..index) end
 Mock.actionToggles=pending; nativeVisibilityEvent()
 equal(MultiBar7:IsShown(),false,"Pending Apply won after Restore")
end
function Tests.native_bar_observed_mirror_clears_pending_intent_before_later_manual_changes()
 local k=init(); local pending; local writes=0
 SetActionBarToggles=function(...) writes=writes+1; pending={...} end
 local plan={settings={nativeBars={[7]=true}},actions={},nativeLayout={placements={},usedBars={}}}
 k.NativeBars:Apply(plan); Mock.actionToggles=pending; local afterApply=writes
 k.NativeBars:Apply(plan)
 equal(writes,afterApply,"Matching observed mirror caused another write")
 assert(not k.NativeBars.pendingToggleMask,"Observed native mirror did not settle the outstanding intent")
 Mock.actionToggles[7]=false; plan.settings.nativeBars[7]=false
 k.NativeBars:Apply(plan)
 equal(writes,afterApply,"Settled intent forced a write over later matching manual state")
end
