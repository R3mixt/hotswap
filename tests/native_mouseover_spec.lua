local function nativeMouseover()
 local k=TestAddon; k:Init()
 Mock.cvars.enableMouseoverCast='0'; Mock.cvars.autoSelfCast='0'; Mock.modified.MOUSEOVERCAST='SHIFT'
 Mock:ResetWrites(); return k
end
local function applyNative(k)
 assert(k.Engine:ApplyCurrentEdits()=='pending'); local ok,why=Mock:Drain(); assert(ok,why)
end
function Tests.native_mouseover_checkbox_stages_persists_and_discards_without_game_writes()
 local k=nativeMouseover(); local preset=k:Export()
 assert(k.CurrentBindings:SetNativeMouseover(true))
 assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:GetNativeMouseoverState().enabled and k.CurrentBindings:GetNativeMouseoverState().pending)
 assert(not k.API:GetNativeMouseoverState().enabled and Mock.modified.MOUSEOVERCAST=='SHIFT' and Mock.cvars.autoSelfCast=='0')
 k:Init(); assert(k.CurrentBindings:HasEdits() and k.CurrentBindings:GetNativeMouseoverState().pending)
 k.CurrentBindings:Discard()
 assert(not k.CurrentBindings:HasEdits() and not k.CurrentBindings:GetNativeMouseoverState().enabled)
 assert(#Mock.writes==0 and k:Export()==preset)
end
function Tests.native_mouseover_unchecking_pending_enable_cancels_without_enforcement()
 local k=nativeMouseover()
 assert(k.CurrentBindings:SetNativeMouseover(true)); assert(k.CurrentBindings:SetNativeMouseover(false))
 assert(not k.CurrentBindings:HasEdits() and not k.CurrentBindings:GetNativeMouseoverState().pending and #Mock.writes==0)
 Mock.cvars.enableMouseoverCast='1'; Mock.modified.MOUSEOVERCAST='NONE'; k:Init()
 assert(k.CurrentBindings:GetNativeMouseoverState().enabled and #Mock.writes==0)
 Mock.cvars.enableMouseoverCast='0'
 assert(not k.CurrentBindings:GetNativeMouseoverState().enabled and not k.CurrentBindings:HasEdits())
end
function Tests.native_mouseover_disabling_only_changes_mouseover_cvar()
 local k=nativeMouseover(); Mock.cvars.enableMouseoverCast='1'; Mock.modified.MOUSEOVERCAST='NONE'; Mock.cvars.autoSelfCast='1'
 assert(k.CurrentBindings:SetNativeMouseover(false))
 -- Changes unrelated to disabling mouseover must be retained, even after staging.
 Mock.modified.MOUSEOVERCAST='CTRL'; Mock.cvars.autoSelfCast='0'; applyNative(k)
 assert(Mock.cvars.enableMouseoverCast=='0' and Mock.modified.MOUSEOVERCAST=='CTRL' and Mock.cvars.autoSelfCast=='0')
end
function Tests.native_mouseover_setting_only_apply_keeps_active_binding_scope()
 local k=nativeMouseover(); Mock.bindingSet=1; Mock.bindingSets[1]=k.Copy(Mock.bindings)
 assert(k.CurrentBindings:SetNativeMouseover(true)); applyNative(k)
 assert(Mock.bindingSet==1 and Mock.cvars.enableMouseoverCast=='1' and Mock.modified.MOUSEOVERCAST=='NONE' and Mock.cvars.autoSelfCast=='1')
 local saved=false
 for _,write in ipairs(Mock.writes) do
  assert(write[1]~='binding' and write[1]~='createmacro' and write[1]~='action','Native setting changed an action or key')
  if write[1]=='savebindings' then assert(write[2]==1,'Setting switched to character bindings'); saved=true end
 end
 assert(saved,'Modified-click preference was not persisted')
end
function Tests.native_mouseover_capability_requires_readable_native_settings_and_supported_api()
 local k=nativeMouseover(); IsMouseoverCastSupported=nil
 assert(not k.API:GetNativeMouseoverState().supported and not k.CurrentBindings:SetNativeMouseover(true))
 IsMouseoverCastSupported=function() return true end; Mock.cvars.enableMouseoverCast=nil
 assert(not k.API:GetNativeMouseoverState().supported and not k.CurrentBindings:SetNativeMouseover(true))
 assert(not k.CurrentBindings:HasEdits() and #Mock.writes==0)
end
function Tests.native_mouseover_preset_apply_preserves_native_automatic_self_cast()
 local k=nativeMouseover(); Mock:AllowFullCatalogMacros()
 Mock.cvars.enableMouseoverCast='1'; Mock.cvars.autoSelfCast='1'; Mock.modified.MOUSEOVERCAST='NONE'
 assert(k:Apply())
 assert(Mock.cvars.enableMouseoverCast=='1' and Mock.cvars.autoSelfCast=='1' and Mock.modified.MOUSEOVERCAST=='NONE')
end
