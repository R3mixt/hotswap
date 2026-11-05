function Tests.slash_registration_never_reassigns_blizzards_shared_registry()
    local source=debug.getinfo(TestAddon.Init,"S").source
    assert(source:sub(1,1)=="@","Core module must expose its source path for the isolated load")
    local chunk,why=loadfile(source:sub(2)); assert(chunk,why)
    local calls=0
    local existing=function() calls=calls+1 end
    local registry={RESTEDXP=existing}
    local writes={}
    local environment={}
    rawset(environment,"_G",environment)
    rawset(environment,"CreateFrame",function()
        return {RegisterEvent=function() end,SetScript=function() end}
    end)
    setmetatable(environment,{
        __index=function(_,key)
            if key=="SlashCmdList" then return registry end
            return _G[key]
        end,
        __newindex=function(owner,key,value)
            -- A same-table global assignment still causes WoW taint. Keep the
            -- registry inherited so __newindex observes even that assignment.
            assert(key~="SlashCmdList","Core reassigned Blizzard's shared SlashCmdList global")
            writes[key]=true; rawset(owner,key,value)
        end,
    })
    local addon={}; setfenv(chunk,environment); chunk("KeybindOptimizer",addon)
    assert(environment.SlashCmdList==registry and rawget(environment,"SlashCmdList")==nil)
    assert(registry.RESTEDXP==existing,"Registration replaced another addon's slash handler")
    local count=0; for _ in pairs(registry) do count=count+1 end
    assert(count==2 and type(registry.KEYBINDOPTIMIZER)=="function","Only Hot Swap's handler should be registered")
    assert(environment.SLASH_KEYBINDOPTIMIZER1=="/hotswap" and environment.SLASH_KEYBINDOPTIMIZER2=="/kbo"
        and environment.SLASH_KEYBINDOPTIMIZER3=="/keybindoptimizer")
    for key in pairs(writes) do
        assert(key=="KeybindOptimizer" or key:match("^SLASH_KEYBINDOPTIMIZER[123]$"),"Unexpected global write: "..key)
    end
    addon.UI={Toggle=function() calls=calls+10 end}
    registry.RESTEDXP(); registry.KEYBINDOPTIMIZER("")
    assert(calls==11,"Existing and Hot Swap slash handlers must both remain callable")
end
