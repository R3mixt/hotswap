local function focusInit(supported)
    local k=TestAddon; k:Init(); k:GetSettings().flavor="era"
    Mock:SetBindingCommandAvailable("TARGETFOCUS",supported)
    Mock:SetBindingCommandAvailable("FOCUSTARGET",supported)
    k.API:InvalidateBindingCommands()
    return k
end
local function hasMode(values,wanted)
    for _,value in ipairs(values) do if value==wanted then return true end end
    return false
end
local function findFocusAction(plan,id)
    for _,action in ipairs(plan.actions) do if action.id==id then return action end end
end
local function focusError(plan)
    for _,why in ipairs(plan.errors) do if why:lower():find("focus",1,true) then return true end end
    return false
end

function Tests.focus_capability_omits_unsupported_defaults_even_in_forever_profile()
    local k=focusInit(false); k:GetSettings().flavor="forever"
    assert(not k.API:SupportsFocus())
    local plan=k:Preview()
    assert(#plan.errors==0,table.concat(plan.errors,"; "))
    assert(not findFocusAction(plan,"system.TARGETFOCUS"),"Unsupported F6 command survived")
    assert(not findFocusAction(plan,"utility.focus") and not findFocusAction(plan,"utility.clearfocus"))
    for _,action in ipairs(plan.actions) do
        assert(not k.API:ActionUsesFocus(action),"Unsupported curated focus action survived: "..action.id)
        assert(not action.body or not action.body:find("@focus",1,true),"Unsupported focus macro was generated")
    end
    assert(findFocusAction(plan,"druid.roots"),"Removing focus duplicate removed the primary spell")
end

function Tests.focus_capability_retains_registered_unbound_commands_in_era_profile()
    local k=focusInit(true)
    local map,readable=k.API:GetBindingCommands()
    assert(readable and map.TARGETFOCUS and map.FOCUSTARGET)
    assert(not GetBindingKey("TARGETFOCUS"),"Fixture focus command should be unbound")
    assert(k.API:SupportsFocus(),"Selected Era flavor hid actual client capability")
    local plan=k:Preview()
    assert(findFocusAction(plan,"system.TARGETFOCUS").key=="F6")
    assert(findFocusAction(plan,"utility.focus") and findFocusAction(plan,"utility.clearfocus"))
    local found=false; for _,action in ipairs(plan.actions) do if action.targeting=="focus" then found=true end end
    assert(found,"Supported focus spell variants were lost")
end

function Tests.focus_capability_filters_spell_and_item_target_options_and_rejects_edits()
    local k=focusInit(false)
    for _,targeting in ipairs({"help","harm","dead"}) do
        assert(not hasMode(k.Library:TargetModes({targeting=targeting}),"focus"))
    end
    assert(not hasMode(k.Items:GetTargetModes({itemID=1251}),"focus"))
    assert(not hasMode(k.Items:GetTargetModes({itemID=10720}),"focus"))
    assert(not hasMode(k.Library:TargetModes({kind="item",itemID=1251}),"focus"))
    local ok,why=k.Library:SetTargetMode("druid.rejuvenation","focus")
    assert(not ok and why:find("Focus",1,true))
    assert(not k:GetSettings().actionOverrides["druid.rejuvenation"])
    ok,why=k.Items:ValidateBinding({selected=1251,targetMode="focus"})
    assert(not ok and why:find("Focus",1,true))
end

function Tests.focus_capability_preserves_saved_explicit_intent_as_preflight_error()
    local k=focusInit(false)
    k:GetSettings().actionOverrides["druid.rejuvenation"]={targetMode="focus"}
    local plan=k:Preview()
    assert(focusError(plan),"Explicit focus intent silently fell back to current target")
    local action=findFocusAction(plan,"druid.rejuvenation")
    assert(action.targetMode=="focus" and not action.body,"Unsupported focus was replaced with a castable target macro")
    Mock:ResetWrites(); local ok=k:Apply()
    assert(not ok and #Mock.writes==0,"Incompatible focus preset changed live controls")
    k:GetSettings().actionOverrides={}; k:GetSettings().bindingOverrides["system.TARGETFOCUS"]="F9"
    assert(focusError(k:Preview()),"Edited unsupported system command was silently discarded")
end

function Tests.focus_capability_rejects_unsupported_future_and_item_macro_intents()
    local k=focusInit(false)
    for _,action in ipairs({
        {known=true,builtin="focus",label="Set focus"},
        {known=true,builtin="clearfocus",label="Clear focus"},
        {known=false,nativePending=true,spellName="Bash",targeting="focus"},
        {known=false,kind="item",itemID=1251,itemTargeting="help",targetMode="focus"},
    }) do
        local body,why=k.Macros:Build(action,k:GetSettings())
        assert(not body and why:find("Focus targeting",1,true),"Unsupported focus intent compiled")
    end
    local ok,why=k.Library:ValidateDescriptor({kind="spell",spellID=5211,targeting="focus"})
    assert(not ok and why:find("Focus targeting",1,true))
end

function Tests.focus_capability_missing_or_failed_registry_never_implies_support()
    local k=focusInit(true)
    GetNumBindings=nil; k.API:InvalidateBindingCommands()
    local _,readable=k.API:GetBindingCommands()
    assert(not readable and not k.API:SupportsFocus())
    GetNumBindings=function() return 2 end
    GetBinding=function(index) if index==1 then return "TARGETFOCUS","TARGETING" end; error("Not ready") end
    _,readable=k.API:GetBindingCommands(true)
    assert(not readable and not k.API:SupportsFocus(),"A partially readable registry implied support")
end

function Tests.focus_capability_failed_forced_refresh_discards_stale_positive_cache()
    local k=focusInit(true)
    assert(k.API:SupportsFocus())
    GetBinding=function() error("Registry unavailable") end
    local _,readable=k.API:GetBindingCommands(true)
    assert(not readable and not k.API:SupportsFocus(),"A failed authoritative read reused stale focus support")
end

function Tests.focus_capability_registry_count_is_bounded_before_enumeration()
    local k=focusInit(true); local calls=0
    GetNumBindings=function() return 10001 end
    GetBinding=function() calls=calls+1; error("Must not enumerate an invalid count") end
    local _,readable=k.API:GetBindingCommands(true)
    assert(not readable and calls==0,"A malformed registry count caused unbounded scanning")
end
