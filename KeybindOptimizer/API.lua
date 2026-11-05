local _, K = ...
K.API={}
local A=K.API
function A:GetFlavor(settings)
    local selected=(settings or K:GetSettings()).flavor
    if selected and selected~="auto" then return selected end
    local version=GetBuildInfo and GetBuildInfo() or ""
    if version:match("^1%.60%.") then return "forever" end
    if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID==WOW_PROJECT_MAINLINE then return "retail" end
    return "era"
end
function A:GetNativeMouseoverState()
    local state={supported=false,enabled=false,autoSelfCast=false}
    local getter=C_CVar and C_CVar.GetCVar or GetCVar
    local setter=C_CVar and C_CVar.SetCVar or SetCVar
    local available,supported=false,false
    if type(IsMouseoverCastSupported)=="function" then available,supported=pcall(IsMouseoverCastSupported) end
    if not available or not supported or type(getter)~="function" or type(setter)~="function"
        or type(GetModifiedClick)~="function" or type(SetModifiedClick)~="function" then
        state.reason="This client does not expose supported built-in mouseover casting."; return state
    end
    local ok,enabled,modifier,selfCast=pcall(function()
        return getter("enableMouseoverCast"),GetModifiedClick("MOUSEOVERCAST"),getter("autoSelfCast")
    end)
    if not ok or (enabled~="0" and enabled~="1") or type(modifier)~="string" or modifier==""
        or (selfCast~="0" and selfCast~="1") then
        state.reason="The client's mouseover casting settings are not readable yet."; return state
    end
    state.supported=true; state.enableMouseoverCast=enabled; state.modifier=modifier; state.autoSelfCastValue=selfCast
    state.enabled=enabled=="1" and modifier=="NONE"; state.autoSelfCast=selfCast=="1"
    return state
end
function A:SpellInfo(id)
    if id==nil then return end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok,info=pcall(C_Spell.GetSpellInfo,id)
        if ok and info then return info.name,info.iconID,info.spellID or id end
    end
    if GetSpellInfo then
        local ok,name,rank,icon,castTime,minRange,maxRange,spellID=pcall(GetSpellInfo,id)
        if ok then return name,icon,spellID or id end
    end
end
function A:SpellRank(id)
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok,rank=pcall(C_Spell.GetSpellSubtext,id)
        if ok and type(rank)=="string" and rank~="" then return rank end
    end
    if GetSpellInfo then
        local ok,_,rank=pcall(GetSpellInfo,id)
        if ok and type(rank)=="string" and rank~="" then return rank end
    end
end
function A:MacroForAction(slot,id,subtype)
    -- Modern clients report the macro's spell/item identity in GetActionInfo,
    -- not its macro-bank index. Read the native action text (never button text,
    -- which addons can relabel), then require an unambiguous bank entry.
    local text=C_ActionBar and C_ActionBar.GetActionText or GetActionText
    local name
    if text then
        local ok,value=pcall(text,slot)
        if not ok then return nil,"Cannot read the macro in action slot "..slot.."." end
        name=value
    end
    if type(name)=="string" and name~="" then
        local account,character=GetNumMacros()
        local constants=Constants and Constants.MacroConsts
        local maxAccount=(constants and constants.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
        local found,icon,body
        for bank=1,2 do
            local count=bank==1 and account or character
            local offset=bank==1 and 0 or maxAccount
            for index=offset+1,offset+count do
                local candidate,texture,content=GetMacroInfo(index)
                if candidate==name then
                    if found then return nil,"More than one macro is named '"..name.."'. Give them unique names before applying changes." end
                    found,icon,body=index,texture,content
                end
            end
        end
        if found and type(body)=="string" then return found,name,icon,body end
    elseif subtype==nil or subtype=="" then
        -- Older clients return the actual macro index and may lack action text.
        local legacy,icon,body=GetMacroInfo(id)
        if legacy and type(body)=="string" then return id,legacy,icon,body end
    end
    return nil,"Cannot identify the macro in action slot "..slot.."."
end
function A:IsKnown(id,pet)
    if IsPlayerSpell and not pet then local ok,v=pcall(IsPlayerSpell,id); if ok and v then return true end end
    if IsSpellKnown then local ok,v=pcall(IsSpellKnown,id,pet or false); if ok and v then return true end end
    return false
end
local function flag(method,id)
    if not method then return false end
    local ok,v=pcall(method,id); return ok and v==true
end
function A:ScanSpellbook()
    local book={list={},byID={},byName={},byExactID={},ranks={},passives={},flyouts={}}
    local function add(id,name,icon,rank,index,bank,passive,category)
        if not id or not name then return end
        passive=passive or flag(C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell,id)
        rank=rank or A:SpellRank(id)
        local entry={id=id,name=name,icon=icon,rank=rank,index=index,bank=bank,passive=passive,category=category}
        -- Keep immutable rank records alongside the family's highest-rank entry.
        -- Updating byName below must never promote an explicitly selected rank.
        if not book.byExactID[id] then
            local exact={id=id,name=name,icon=icon,rank=rank,index=index,bank=bank,passive=passive,category=category,known=true}
            book.byExactID[id]=exact
            if not passive then book.ranks[#book.ranks+1]=exact end
        end
        book.byID[id]=entry
        if passive then book.passives[#book.passives+1]=entry; return end
        local previous=book.byName[name]
        if previous then
            -- Spellbook order is rank order in Classic; name cast selects highest rank.
            previous.id,previous.icon,previous.rank,previous.index=id,icon,rank,index
            book.byID[id]=previous
        else book.list[#book.list+1]=entry; book.byName[name]=entry end
    end
    local function flyout(id)
        if not GetFlyoutInfo or not GetFlyoutSlotInfo then return end
        local _,_,n=GetFlyoutInfo(id)
        for i=1,n or 0 do
            local spellID,overrideID,known,name=GetFlyoutSlotInfo(id,i)
            if known then
                spellID=overrideID and overrideID~=0 and overrideID or spellID
                local resolved,icon=A:SpellInfo(spellID)
                add(spellID,resolved or name,icon,nil,i,"flyout",false)
            end
        end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for tab=1,C_SpellBook.GetNumSpellBookSkillLines() do
            local line=C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if line and not line.isOffSpec and (not line.offSpecID or line.offSpecID==0) then
                for index=(line.itemIndexOffset or 0)+1,(line.itemIndexOffset or 0)+(line.numSpellBookItems or 0) do
                    local info=C_SpellBook.GetSpellBookItemInfo(index,bank)
                    if info and not info.isOffSpec and not info.isUnlearned and not info.isFutureSpell then
                        local id=info.spellID
                        local flyType=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
                        local futureType=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
                        if (flyType and info.itemType==flyType) or info.itemType=="FLYOUT" then flyout(info.actionID)
                        elseif id and (not futureType or info.itemType~=futureType) then
                            local name,icon=A:SpellInfo(id)
                            local passive=C_SpellBook.IsSpellBookItemPassive and C_SpellBook.IsSpellBookItemPassive(index,bank)
                            add(id,info.name or name,info.iconID or icon,info.subName,index,bank,passive,line.name)
                        end
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for tab=1,GetNumSpellTabs() do
            local category,_,offset,num,_,offSpecID=GetSpellTabInfo(tab)
            if not offSpecID or offSpecID==0 then
                for index=(offset or 0)+1,(offset or 0)+(num or 0) do
                    local typ,id=GetSpellBookItemInfo(index,BOOKTYPE_SPELL or "spell")
                    if typ=="FLYOUT" then flyout(id)
                    elseif typ=="SPELL" and id then
                        local name,rank=GetSpellBookItemName(index,BOOKTYPE_SPELL or "spell")
                        local _,icon=A:SpellInfo(id)
                        add(id,name,icon,rank,index,"spell",IsPassiveSpell and IsPassiveSpell(index,BOOKTYPE_SPELL or "spell"),category)
                    end
                end
            end
        end
    end
    -- Pet spellbooks have their own bank and are not included in player skill lines.
    local petFn=C_SpellBook and C_SpellBook.HasPetSpells or HasPetSpells
    local petCount=petFn and petFn()
    if type(petCount)=="number" then
        for index=1,petCount do
            if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
                local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
                local info=C_SpellBook.GetSpellBookItemInfo(index,bank)
                if info and info.spellID then local name,icon=A:SpellInfo(info.spellID); add(info.spellID,info.name or name,icon,nil,index,bank,info.isPassive) end
            elseif GetSpellBookItemInfo then
                local typ,id=GetSpellBookItemInfo(index,BOOKTYPE_PET or "pet")
                if typ=="SPELL" then local name,rank=GetSpellBookItemName(index,BOOKTYPE_PET or "pet"); local _,icon=A:SpellInfo(id); add(id,name,icon,rank,index,"pet",IsPassiveSpell and IsPassiveSpell(index,"pet")) end
            end
        end
    end
    table.sort(book.list,function(a,b) return a.name<b.name end)
    self.spellbook=book
    return book
end
function A:InvalidateSpellbook() self.spellbook=nil end
function A:GetCachedSpellbook() return self.spellbook or self:ScanSpellbook() end
local function matchesDefinition(def,name)
    if not name then return false end
    local locale=GetLocale and GetLocale() or "enUS"
    if locale~="enUS" and locale~="enGB" then return true end
    if not def.name or def.combo or name==def.name then return true end
    for _,alias in ipairs(def.spellNames or {}) do if name==alias then return true end end
    return false
end
-- Display metadata is deliberately separate from Resolve. The spell database
-- knows icons and tooltips for unlearned spells; that is not permission to cast.
function A:ResolveDisplay(def)
    local function lookup(identifier)
        local name,icon,id=A:SpellInfo(identifier)
        if not matchesDefinition(def,name) then return end
        id=tonumber(id)
        return {id=id and id>0 and id or nil,name=name,icon=icon}
    end
    for _,id in ipairs(def.spellIDs or {}) do
        local display=lookup(id)
        if display then return display end
    end
    -- Forever-only definitions may have no verified ID yet. Ask this client for
    -- exact names instead of borrowing IDs from another expansion.
    for _,name in ipairs(def.spellNames or {}) do
        local display=lookup(name)
        if display then return display end
    end
    if def.name then return lookup(def.name) end
end
function A:Resolve(def,book)
    for _,id in ipairs(def.spellIDs or {}) do
        local entry=book.byID[id]
        local name,icon=self:SpellInfo(id)
        if entry and matchesDefinition(def,entry.name) then return book.byName[entry.name] or entry end
        if matchesDefinition(def,name) and book.byName[name] then return book.byName[name] end
        if matchesDefinition(def,name) and self:IsKnown(id,def.pet or def.petSpell) then return {id=id,name=name,icon=icon} end
    end
    for _,name in ipairs(def.spellNames or {}) do if book.byName[name] then return book.byName[name] end end
    return book.byName[def.name]
end
function A:ResolveExact(id,book)
    id=tonumber(id)
    if not id or id<=0 or id%1~=0 then return end
    book=book or self:GetCachedSpellbook()
    local exact=book.byExactID and book.byExactID[id]
    if exact then return K.Copy(exact) end
    local name,icon,resolved=self:SpellInfo(id)
    if not name or tonumber(resolved)~=id then return end
    return {id=id,name=name,icon=icon,rank=self:SpellRank(id),known=self:IsKnown(id)}
end
function A:GetLearnedRanks(book)
    return K.Copy((book or self:GetCachedSpellbook()).ranks or {})
end
function A:GetExactSpell(id,book)
    local exact=self:ResolveExact(id,book)
    if exact and exact.known and not exact.passive then return exact end
end
function A:GetSpellRanks(def,book)
    book=book or self:GetCachedSpellbook()
    local names,seen,result={},{},{}
    if def.name then names[def.name]=true end
    for _,name in ipairs(def.spellNames or {}) do names[name]=true end
    local function add(entry)
        if entry and not entry.passive and not seen[entry.id] then
            seen[entry.id]=true; result[#result+1]=K.Copy(entry)
        end
    end
    -- Catalog ranks are shown only when this client's data resolves the same
    -- spell identity. Database availability alone does not imply it is learned.
    for _,id in ipairs(def.spellIDs or {}) do
        local exact=self:ResolveExact(id,book)
        if exact and matchesDefinition(def,exact.name) then names[exact.name]=true; add(exact) end
    end
    for _,entry in ipairs(book.ranks or {}) do if names[entry.name] then add(entry) end end
    table.sort(result,function(a,b)
        local ar,br=tonumber((a.rank or ""):match("%d+")),tonumber((b.rank or ""):match("%d+"))
        if ar and br and ar~=br then return ar<br end
        if a.name~=b.name then return a.name<b.name end
        return a.id<b.id
    end)
    return result
end
function A:GetForms()
    local forms={}
    local ids={ [5487]="bear",[9634]="bear",[768]="cat",[783]="travel",[1066]="aquatic",[24858]="moonkin",[33891]="tree",[33943]="flight",[40120]="flight" }
    local names={}
    for id,kind in pairs(ids) do local name=self:SpellInfo(id); if name then names[name]=kind end end
    for index=1,(GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) do
        local icon,active,castable,spellID=GetShapeshiftFormInfo(index)
        local name=self:SpellInfo(spellID)
        local kind=ids[spellID] or names[name]
        if kind then forms[kind]={index=index,spellID=spellID,name=name,icon=icon} end
    end
    return forms
end
-- Native Druid combat banks are Base, Cat, Bear and Moonkin. Travel,
-- Aquatic and flight are movement forms, not separate combat pages. Prowl
-- remains on the native Cat page; its distinct page was a custom-dock feature.
function A:ActionPageForForm(kind)
    if kind=="cat" or kind=="prowl" then return "cat" end
    if kind=="bear" or kind=="moonkin" then return kind end
    return "caster"
end
function A:GetActiveActionPage(settings,forms)
    local active=GetShapeshiftForm and GetShapeshiftForm() or 0
    for kind,form in pairs(forms or self:GetForms()) do
        if form.index==active then return self:ActionPageForForm(kind) end
    end
    return "caster"
end
function A:FormSignature()
    local forms=self:GetForms(); local parts={}
    for _,kind in ipairs({"cat","bear","moonkin","travel","aquatic","tree","flight"}) do
        if forms[kind] then parts[#parts+1]=kind..":"..forms[kind].index..":"..forms[kind].spellID end
    end
    return table.concat(parts,";")
end
function A:Helpful(id) return flag(C_Spell and C_Spell.IsSpellHelpful or IsHelpfulSpell,id) end
function A:ItemInfo(id)
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not fn then return end
    return fn(id)
end
function A:ItemSpell(id)
    local fn=C_Item and C_Item.GetItemSpell or GetItemSpell
    if fn then return fn(id) end
end
function A:BindingAction(key) return GetBindingAction and GetBindingAction(key) or "" end
-- These active native commands are explicitly hidden in both supported XMLs:
-- classic_era/Blizzard_FrameXML/Bindings_Vanilla.xml lines 1449/1456 and
-- forever/Blizzard_FrameXML/Bindings_Camelot.xml lines 1517/1524.
-- Visible command enumeration alone cannot establish their availability.
A.HiddenMouseCommands={CAMERAORSELECTORMOVE=true,TURNORACTION=true}
function A:IsBindingCommandSupported(command,visibleCommands)
    if type(command)~="string" then return false end
    local visible=visibleCommands or self:GetBindingCommands()
    return self.HiddenMouseCommands[command]==true or visible[command]~=nil
end
local function packBindings(...) return {n=select("#",...),...} end
function A:ReadHiddenMouseBindings(result)
    if type(result)~="table" or type(GetBindingKey)~="function" or type(GetBindingAction)~="function" then
        return false,"The game's mouse-binding APIs are not ready. No binding snapshot was guessed."
    end
    local aliases,buttons={},{}
    for _,command in ipairs({"CAMERAORSELECTORMOVE","TURNORACTION"}) do
        local ok,keys=pcall(function() return packBindings(GetBindingKey(command)) end)
        if not ok or keys.n>10000 then return false,"Could not read the mouse bindings for "..command.."." end
        for index=1,keys.n do
            local key=keys[index]
            if key~=nil then
                if type(key)~="string" or key=="" then return false,"The game returned an unreadable mouse-binding key." end
                aliases[key]=command
            end
        end
    end
    for _,key in ipairs({"BUTTON1","BUTTON2"}) do
        local ok,command=pcall(GetBindingAction,key)
        if not ok or type(command)~="string" then return false,"Could not read "..key..". No mouse binding was guessed." end
        buttons[key]=command
    end
    -- Commit only after every read succeeds. Direct button reads preserve a
    -- custom action or an intentionally unbound button instead of assuming
    -- that the native camera command still owns its usual mouse button.
    for key,command in pairs(result) do if self.HiddenMouseCommands[command] then result[key]=nil end end
    for key,command in pairs(aliases) do result[key]=command end
    for key,command in pairs(buttons) do result[key]=command~="" and command or nil end
    return true
end
function A:InvalidateBindingCommands()
    self.bindingCommands=nil; self.bindingCommandCount=nil; self.bindingCommandLocale=nil
end
function A:GetBindingCommands(forceRefresh)
    -- This is the client's visible registry, including commands with no key.
    -- A flavor preference or a localized binding label does not prove support.
    if forceRefresh then self:InvalidateBindingCommands() end
    if type(GetNumBindings)~="function" or type(GetBinding)~="function" then self:InvalidateBindingCommands(); return {},false end
    local ok,count=pcall(GetNumBindings)
    if not ok or type(count)~="number" or count<1 or count>10000 or count%1~=0 then self:InvalidateBindingCommands(); return {},false end
    local locale=GetLocale and GetLocale() or "enUS"
    if not forceRefresh and self.bindingCommands and self.bindingCommandCount==count and self.bindingCommandLocale==locale then return self.bindingCommands,true end
    local commands={}
    for index=1,count do
        local readable,command,category=pcall(GetBinding,index)
        if not readable or type(command)~="string" or command=="" then self:InvalidateBindingCommands(); return {},false end
        commands[command]={category=category,index=index}
    end
    self.bindingCommands,self.bindingCommandCount,self.bindingCommandLocale=commands,count,locale
    return commands,true
end
function A:SupportsFocus()
    local commands,readable=self:GetBindingCommands()
    return readable and (commands.TARGETFOCUS~=nil or commands.FOCUSTARGET~=nil) or false
end
function A:ActionUsesFocus(action)
    return action.builtin=="focus" or action.builtin=="clearfocus" or action.targetMode=="focus"
        or (action.targeting=="focus" and (not action.targetMode or action.targetMode=="default"))
end
function A:BindingLabel(command)
    if not command or command=="" then return "Unbound" end
    local index=command:match("^ACTIONBUTTON(%d+)$")
    if index then return "Action bar 1, button "..index end
    local bar,slot=command:match("^MULTIACTIONBAR(%d+)BUTTON(%d+)$")
    if bar then return "Action bar "..tostring(tonumber(bar)+1)..", button "..slot end
    slot=command:match("^SHAPESHIFTBUTTON(%d+)$")
    if slot then return "Form bar, button "..slot end
    slot=command:match("^BONUSACTIONBUTTON(%d+)$")
    if slot then return "Pet bar, button "..slot end
    if command:match("^CLICK KBO_Mode_") then return "Hot Swap preset shortcut" end
    if command:match("^CLICK KBO_") then return "Hot Swap spell binding" end
    local localized=_G["BINDING_NAME_"..command]
    if type(localized)=="string" and localized~="" then return localized end
    local labels={MOVEFORWARD="Move forward",MOVEBACKWARD="Move backward",STRAFELEFT="Strafe left",STRAFERIGHT="Strafe right",JUMP="Jump",TOGGLEAUTORUN="Auto-run",OPENCHAT="Open chat",OPENCHATSLASH="Open command chat",REPLY="Reply to whisper",ASSISTTARGET="Assist target",ATTACKTARGET="Attack target",TARGETNEARESTENEMY="Target next enemy",TARGETPREVIOUSENEMY="Target previous enemy",CAMERAORSELECTORMOVE="Select / camera",TURNORACTION="Turn / interact",CAMERAZOOMIN="Zoom in",CAMERAZOOMOUT="Zoom out",TOGGLEGAMEMENU="Game menu",TOGGLECHARACTER0="Character",TOGGLEACHIEVEMENT="Achievements",OPENALLBAGS="Open all bags"}
    if labels[command] then return labels[command] end
    local frame=command:match("^CLICK ([^:]+)")
    if frame then return "Addon button: "..frame end
    return command:gsub("_"," "):lower():gsub("^%l",string.upper)
end
function A:NormalizeKey(key)
    if type(key)~="string" then return nil end
    if key:find("[%s%c]") then return nil end
    key=key:upper()
    if key=="`" or key=="~" or key=="GRAVE" then return "`" end
    local mods={}; local base=key
    while true do
        local mod,rest=base:match("^(ALT)%-([^%s]+)$")
        if not mod then mod,rest=base:match("^(CTRL)%-([^%s]+)$") end
        if not mod then mod,rest=base:match("^(SHIFT)%-([^%s]+)$") end
        if not mod then break end
        if mods[mod] then return nil end
        mods[mod]=true; base=rest
    end
    if base=="GRAVE" or base=="~" then base="`" end
    local named={SPACE=true,TAB=true,ENTER=true,ESCAPE=true,BACKSPACE=true,INSERT=true,DELETE=true,HOME=true,END=true,PAGEUP=true,PAGEDOWN=true,UP=true,DOWN=true,LEFT=true,RIGHT=true,CAPSLOCK=true,NUMLOCK=true,SCROLLLOCK=true,PAUSE=true,PRINTSCREEN=true,MOUSEWHEELUP=true,MOUSEWHEELDOWN=true,NUMPADPLUS=true,NUMPADMINUS=true,NUMPADMULTIPLY=true,NUMPADDIVIDE=true,NUMPADDECIMAL=true,NUMPADENTER=true}
    local valid=(#base==1 and base:match("^[A-Z0-9`%-%[%];',./=\\]$")) or named[base]
    local f=tonumber(base:match("^F(%d+)$")); if f and f>=1 and f<=24 then valid=true end
    local button=tonumber(base:match("^BUTTON(%d+)$")); if button and button>=1 and button<=31 then valid=true end
    if base:match("^NUMPAD%d$") then valid=true end
    if not valid then return nil end
    local result=""
    for _,m in ipairs({"ALT","CTRL","SHIFT"}) do if mods[m] then result=result..m.."-" end end
    return result..base
end
