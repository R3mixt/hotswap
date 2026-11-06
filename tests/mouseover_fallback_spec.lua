local function buildTargeting(target,mode,noSelf,selfFallback)
 local k=TestAddon; k:Init()
 return assert(k.Macros:Build({known=true,spellName='Test Spell',label='Test Spell',targeting=target,targetMode=mode,noSelf=noSelf},
  {flavor='era',cancelForUtility=false,selfFallback=selfFallback}))
end
function Tests.mouseover_heal_prioritizes_alt_then_mouseover_then_target_then_self()
 local body=buildTargeting('help','mouseover',false,false)
 assert(body=='#showtooltip Test Spell\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] Test Spell',body)
end
function Tests.mouseover_self_fallback_never_changes_other_explicit_target_modes()
 local target=buildTargeting('help','target',false,true)
 assert(target=='#showtooltip Test Spell\n/cast [mod:alt,@player][help,nodead] Test Spell',target)
 local self=buildTargeting('help','self',false,true)
 assert(self=='#showtooltip Test Spell\n/cast [mod:alt,@player][@player] Test Spell',self)
 Mock:SetBindingCommandAvailable('TARGETFOCUS',true); Mock:SetBindingCommandAvailable('FOCUSTARGET',true); TestAddon.API:InvalidateBindingCommands()
 local focus=buildTargeting('help','focus',false,true)
 assert(focus=='#showtooltip Test Spell\n/cast [mod:alt,@player][@focus,help,nodead] Test Spell',focus)
end
function Tests.mouseover_default_and_implicit_heals_always_fall_back_to_self_with_legacy_settings()
 local expected='#showtooltip Test Spell\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] Test Spell'
 for _,legacy in ipairs({false,true}) do
  assert(buildTargeting('help','default',false,legacy)==expected)
  assert(buildTargeting('help',nil,false,legacy)==expected)
 end
 assert(buildTargeting('help','default',false,nil)==expected)
 assert(buildTargeting('help',nil,false,nil)==expected)
end
function Tests.mouseover_harm_resurrection_and_no_self_spells_never_gain_self_fallback()
 for _,case in ipairs({
  {'harm',false,'[@mouseover,harm,nodead][harm,nodead]'},
  {'dead',false,'[@mouseover,help,dead][help,dead]'},
  {'help',true,'[nomod:alt,@mouseover,help,nodead][nomod:alt,help,nodead]'},
 }) do
  for _,mode in ipairs({'mouseover','default'}) do
   -- Ordinary harmful Default spells need no macro; the other guarded
   -- families retain their conditions in both targeting paths.
   if mode=='mouseover' or case[1]~='harm' then
    local body=buildTargeting(case[1],mode,case[2],true)
    assert(body=='#showtooltip Test Spell\n/cast '..case[3]..' Test Spell',body)
    assert(not body:find('@player',1,true),body)
   end
  end
 end
end
