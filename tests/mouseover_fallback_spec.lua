local function buildTargeting(target,mode,noSelf,selfFallback)
 local k=TestAddon; k:Init()
 return assert(k.Macros:Build({known=true,spellName='Test Spell',label='Test Spell',targeting=target,targetMode=mode,noSelf=noSelf},
  {flavor='era',cancelForUtility=false,selfFallback=selfFallback}))
end
function Tests.mouseover_heal_prioritizes_alt_then_mouseover_then_target_then_self()
 local body=buildTargeting('help','mouseover',false,false)
 assert(body=='#showtooltip Test Spell\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead][@player] Test Spell',body)
end
function Tests.mouseover_self_fallback_never_changes_other_explicit_target_modes_or_default_setting()
 local target=buildTargeting('help','target',false,true)
 assert(target=='#showtooltip Test Spell\n/cast [mod:alt,@player][help,nodead] Test Spell',target)
 local self=buildTargeting('help','self',false,true)
 assert(self=='#showtooltip Test Spell\n/cast [mod:alt,@player][@player] Test Spell',self)
 Mock:SetBindingCommandAvailable('TARGETFOCUS',true); Mock:SetBindingCommandAvailable('FOCUSTARGET',true); TestAddon.API:InvalidateBindingCommands()
 local focus=buildTargeting('help','focus',false,true)
 assert(focus=='#showtooltip Test Spell\n/cast [mod:alt,@player][@focus,help,nodead] Test Spell',focus)
 local strict=buildTargeting('help','default',false,false)
 local fallback=buildTargeting('help','default',false,true)
 assert(strict=='#showtooltip Test Spell\n/cast [mod:alt,@player][@mouseover,help,nodead][help,nodead] Test Spell',strict)
 assert(fallback:find('[help,nodead][@player] Test Spell',1,true),fallback)
end
function Tests.mouseover_harm_resurrection_and_no_self_spells_never_gain_self_fallback()
 for _,case in ipairs({
  {'harm',false,'[@mouseover,harm,nodead][harm,nodead]'},
  {'dead',false,'[@mouseover,help,dead][help,dead]'},
  {'help',true,'[nomod:alt,@mouseover,help,nodead][nomod:alt,help,nodead]'},
 }) do
  local body=buildTargeting(case[1],'mouseover',case[2],true)
  assert(body=='#showtooltip Test Spell\n/cast '..case[3]..' Test Spell',body)
  assert(not body:find('@player',1,true),body)
 end
end
