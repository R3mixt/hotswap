local _, K = ...
K.Macros={}
function K.Macros:Build(action,settings)
    if not action.known and not action.nativePending then return nil end
    if action.kind=="system" then return nil end
    if action.kind=="macroref" then return nil end
    local name=action.spellName or action.displayName or action.name or action.label
    if action.explicitRank then
        if not action.selectedRank or action.selectedRank=="" then return nil,"Exact rank text is unavailable for "..tostring(name)..". Refresh the spellbook before using this rank." end
        name=name.."("..action.selectedRank..")"
    end
    -- A reserved combination must not run only its learned components. A
    -- future ordinary spell may become castable, but a partial emergency heal
    -- must stay inert until a fresh plan verifies the complete combination.
    if action.nativePending and not action.known and action.combo then return "#showtooltip "..name end
    if action.nativePending and not action.known and action.powerShift then return "#showtooltip "..name.."\n/cast [noform] !"..name end
    local lines={}
    local function push(text) lines[#lines+1]=text end
    if action.kind=="emote" then
        if not K.Library or not K.Library:Emotes()[action.emote] then return nil,"Unknown emote." end
        push(K.Library:Emotes()[action.emote])
    elseif action.builtin then
        if action.builtin=="cancel" then push("/cancelform")
        elseif action.builtin=="focus" then push("/focus [@mouseover,exists,nodead][]")
        elseif action.builtin=="clearfocus" then push("/clearfocus")
        elseif action.builtin=="stopcast" then push("/stopcasting")
        elseif action.builtin=="petattack" then push("/petattack")
        elseif action.builtin=="petfollow" then push("/petfollow")
        elseif action.builtin=="petpassive" then push("/petpassive")
        end
    elseif action.mountSpell then
        push("#showtooltip "..name)
        if K.playerClass=="DRUID" then push("/cancelform") end
        push("/cast [nomounted] "..name)
    elseif action.itemSlot or action.itemID then
        local item=action.itemSlot and tostring(action.itemSlot) or "item:"..action.itemID
        push("#showtooltip "..item)
        -- Do not /use unequipped armor by ID: that command can equip instead of use.
        if action.isMount and K.playerClass=="DRUID" then push("/cancelform") end
        local condition=action.isMount and "[nomounted] " or ""
        if action.itemTargeting=="help" then
            local mode=action.targetMode or "default"
            if mode=="self" then condition="[@player] "
            elseif mode=="target" then condition="[mod:alt,@player][help,nodead] "
            elseif mode=="focus" then condition="[mod:alt,@player][@focus,help,nodead] "
            else condition="[mod:alt,@player][@mouseover,help,nodead][help,nodead] " end
        elseif action.itemTargeting=="harm" then
            local mode=action.targetMode or "default"
            if mode=="focus" then condition="[@focus,harm,nodead] "
            elseif mode=="mouseover" then condition="[@mouseover,harm,nodead][harm,nodead] "
            else condition="[harm,nodead] " end
        end
        push("/use "..condition..item)
    elseif action.powerShift then
        push("#showtooltip "..name)
        push("/cancelform")
        push("/cast "..name)
    elseif action.targeting=="form" then
        push("#showtooltip "..name)
        local form=K.API:GetForms()[action.formType or ""]
        if not form then
            if action.nativePending then return "#showtooltip "..name.."\n/cast [noform] !"..name end
            return nil,"Form information is not ready for "..name..". Refresh after entering the world."
        end
        if K.API:GetFlavor(settings)=="era" and form then push("/cancelform [noform:"..form.index.."]") end
        -- ! alone can intentionally re-shift on some Classic clients. Gate the cast.
        push("/cast [noform:"..form.index.."] !"..name)
    elseif action.combo then
        push("#showtooltip "..name)
        if action.cancelForm and settings.cancelForUtility and K.API:GetFlavor(settings)=="era" then push("/cancelform") end
        for _,spell in ipairs(action.combo) do
            local resolved=type(spell)=="number" and K.API:SpellInfo(spell) or spell
            if resolved then push("/cast [@player] "..resolved) end
        end
    elseif action.targeting=="help" or action.targeting=="dead" or action.targeting=="focus" or action.targeting=="self" or action.targeting=="ground" or action.nonToggle or action.cancelForm or action.targetMode then
        push("#showtooltip "..name)
        local target=action.targeting
        local isDruid=K.playerClass=="DRUID"
        local cancel=action.cancelForm or (isDruid and (target=="help" or target=="dead"))
        local cond=""
        if target=="help" then
            if action.noSelf then cond="[nomod:alt,@mouseover,help,nodead][nomod:alt,help,nodead]"
            else cond="[mod:alt,@player][@mouseover,help,nodead][help,nodead]"..(settings.selfFallback and "[@player]" or "") end
        elseif target=="dead" then cond="[@mouseover,help,dead][help,dead]"
        elseif target=="focus" then cond="[@focus,harm,nodead]"
        elseif target=="self" then cond="[@player]"
        elseif target=="ground" and settings.groundAtCursor then cond="[@cursor]" end
        local mode=action.targetMode
        if mode and mode~="default" then
            local validity=target=="dead" and "help,dead" or target=="help" and "help,nodead" or "harm,nodead"
            local guard=action.noSelf and "nomod:alt," or ""
            if target=="ground" then cond=mode=="cursor" and "[@cursor]" or ""
            else
                if mode=="mouseover" then cond="["..guard.."@mouseover,"..validity.."]["..guard..validity.."]"
                elseif mode=="focus" then cond="["..guard.."@focus,"..validity.."]"
                elseif mode=="self" then cond="[@player]"
                elseif mode=="target" then cond="["..guard..validity.."]" end
                if target=="help" and not action.noSelf then cond="[mod:alt,@player]"..cond end
            end
        end
        if cancel and settings.cancelForUtility and not action.requiresForm and K.API:GetFlavor(settings)=="era" then
            if target=="help" or target=="dead" then push("/cancelform "..cond)
            else push("/cancelform") end
        end
        push("/cast "..cond..(#cond>0 and " " or "")..(action.nonToggle and "!" or "")..name)
    end
    if #lines==0 and action.explicitRank then push("#showtooltip "..name); push("/cast "..name) end
    if #lines==0 then return nil end
    local body=table.concat(lines,"\n")
    if #body>255 then return nil,"Macro exceeds the client's 255-byte limit: "..action.label end
    return body
end
function K.Macros:Name(body)
    local hash=5381
    for i=1,#body do hash=(hash*33+body:byte(i))%2147483647 end
    return "KBO_"..string.format("%08x",hash)
end
function K.Macros:FindOwned(name,body)
    local index=GetMacroIndexByName and GetMacroIndexByName(name) or 0
    if index and index>0 then
        local found,_,current=GetMacroInfo(index)
        if found==name and current==body and K.db.ownedMacros[name]==body then return index,name end
    end
    -- A user-owned macro can occupy the hash name. Reuse our prior suffixed name.
    for owned,expected in pairs(K.db.ownedMacros or {}) do
        if expected==body then
            local i=GetMacroIndexByName(owned)
            if i and i>0 then local found,_,current=GetMacroInfo(i); if found==owned and current==body then return i,owned end end
        end
    end
end
function K.Macros:Budget(plan)
    local requested={}
    for _,action in ipairs(plan.actions) do
        if (action.known or action.nativeMacro) and action.body then requested[action.body]=true end
    end
    local count=0
    for body in pairs(requested) do
        local name=self:Name(body)
        if not self:FindOwned(name,body) then count=count+1 end
    end
    local account,character=0,0
    if GetNumMacros then account,character=GetNumMacros() end
    local constants=Constants and Constants.MacroConsts
    local maxAccount=(constants and constants.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
    local maxCharacter=(constants and constants.MAX_CHARACTER_MACROS) or MAX_CHARACTER_MACROS or 18
    return count,math.max(0,maxAccount-account)+math.max(0,maxCharacter-character),maxAccount,maxCharacter
end
