local _,K=...
K.Library={}
local L=K.Library
L.limits={customActions=256,actionOverrides=512,itemBindings=512}
local function entries(map) local n=0; for _ in pairs(map or {}) do n=n+1 end; return n end
function L:CheckLimits(settings)
    for field,limit in pairs(self.limits) do if entries(settings[field])>limit then return false,"This preset exceeds the supported "..limit.." "..field.." entries." end end
    return true
end
function L:CanOverride(id)
    local map=K:GetSettings().actionOverrides
    return map[id]~=nil or entries(map)<self.limits.actionOverrides
end
local function busy() return K.Engine and K.Engine.busy end
local modes={default=true,mouseover=true,target=true,focus=true,self=true,cursor=true}
local function text(value,max) return type(value)=="string" and #value>0 and #value<=(max or 100) and not value:find("[%c|]") end
local function integer(value) return type(value)=="number" and value>0 and value<2147483647 and value%1==0 end
local function chat(command) return command:find("CHAT") or command:find("REPLY") or command:find("WHISPER") or command:find("SAY") or command:find("YELL") end
function L:Commands()
    local commands,readable=K.API:GetBindingCommands()
    if not readable then return {} end
    local locale=GetLocale and GetLocale() or "enUS"
    if self.commandCache and self.commandSource==commands and self.commandLocale==locale then return self.commandCache end
    local result={}
    for command,info in pairs(commands) do
        local category=info.category
        if command and command~="" and not command:match("^HEADER") and not command:match("^MACRO ") and not command:match("^CLICK ") then
            result[command]={label=K.API:BindingLabel(command),category=category and (_G[category] or category) or "Game controls",tab=chat(command) and "chat" or "game"}
        end
    end
    self.commandCache,self.commandSource,self.commandLocale=result,commands,locale
    return result
end
function L:Emotes()
    if self.emoteCache then return self.emoteCache end
    local result={}
    for key,value in pairs(_G) do
        local serial=type(key)=="string" and key:match("^EMOTE(%d+)_TOKEN$")
        local command=serial and _G["EMOTE"..serial.."_CMD1"]
        if serial and type(value)=="string" and value:match("^[A-Z_]+$") and type(command)=="string" and command:match("^/[^%s%c|]+$") then result[value]=command end
    end
    -- These standard actions remain available on clients that keep the emote
    -- token table private; no arbitrary chat or Lua text is accepted here.
    for _,token in ipairs({"WAVE","DANCE","CHEER","BOW","SALUTE","THANK","LAUGH","SIT","STAND","KNEEL","POINT","FOLLOWME","WAIT","HELLO","GOODBYE","YES","NO","CLAP","CHARGE","FLEE","HELP_ME"}) do
        if not result[token] and (not GetLocale or GetLocale()=="enUS" or GetLocale()=="enGB") then
            if token=="HELP_ME" then result[token]="/helpme" else result[token]="/"..token:lower() end
        end
    end
    self.emoteCache=result; return result
end
function L:ValidateDescriptor(d)
    if type(d)~="table" then return false,"Invalid library action." end
    local allowed={kind=true,name=true,spellID=true,rank=true,rankMode=true,targeting=true,form=true,command=true,emote=true,macroName=true,macroFingerprint=true,sourceID=true,itemID=true}
    for key in pairs(d) do if not allowed[key] then return false,"Unknown library action field: "..tostring(key) end end
    if d.form and not ({all=true,caster=true,cat=true,bear=true,moonkin=true})[d.form] then return false,"Invalid action page." end
    if d.targeting and not ({harm=true,help=true,dead=true,self=true,none=true,ground=true,form=true,focus=true})[d.targeting] then return false,"Invalid action target." end
    if d.targeting=="focus" and not K.API:SupportsFocus() then return false,"Focus targeting is unavailable on this client. Choose another target mode." end
    if d.name and (not text(d.name,120) or (d.kind=="spell" and d.name:find("[;%[%]/]"))) then return false,"Invalid action name." end
    if d.rankMode and d.rankMode~="highest" then return false,"Invalid rank mode." end
    if d.kind=="spell" then
        if d.sourceID then
            if not text(d.sourceID,100) or not d.sourceID:match("^[%w%._%-]+$") or d.sourceID:match("^custom%.") then return false,"Invalid source spell family." end
        elseif not integer(d.spellID) then return false,"Invalid spell ID." end
        if (d.spellID and not integer(d.spellID)) or (d.rank and (not text(d.rank,60) or d.rank:find("[;%[%]/]"))) then return false,"Invalid spell or rank." end
    elseif d.kind=="item" then
        if not integer(d.itemID) then return false,"Invalid item ID." end
    elseif d.kind=="system" then
        if not text(d.command,200) or not self:Commands()[d.command] then return false,"This game command is unavailable: "..tostring(d.command) end
    elseif d.kind=="emote" then
        if not self:Emotes()[d.emote] then return false,"Unknown emote." end
    elseif d.kind=="macroref" then
        if not text(d.macroName,120) or type(d.macroFingerprint)~="string" or not d.macroFingerprint:match("^KBO_%x%x%x%x%x%x%x%x$") then return false,"Invalid macro reference." end
    else return false,"Unknown library action type." end
    return true
end
function L:ValidateOverride(override)
    if type(override)~="table" then return false end
    for key,value in pairs(override) do
        if key=="spellID" then if not integer(value) then return false end
        elseif key=="targetMode" then if not modes[value] then return false end
        elseif key=="replacement" then if not self:ValidateDescriptor(value) or value.kind=="system" then return false end
        else return false end
    end
    return true
end
function L:ResolveDescriptor(id,d,book)
    local ok,why=self:ValidateDescriptor(d); if not ok then return nil,why end
    local a={id=id,name=d.name,label=d.name,form=d.form or "all",targeting=d.targeting or "none",source="Spellbook library",category="Custom actions"}
    if d.kind=="spell" then
        if d.sourceID then
            local _,class=UnitClass("player")
            for _,def in ipairs(K.Profiles:Get(class,K.API:GetFlavor())) do if def.id==d.sourceID then a=K.Copy(def); a.librarySourceID=def.id; a.id=id; break end end
            if not a.spellIDs then return nil,"The source spell family is unavailable: "..d.sourceID end
            if not d.spellID then return a end
        end
        local exact=K.API:ResolveExact(d.spellID,book)
        if not exact then return nil,"This spell ID is unavailable in the client's spell data: "..tostring(d.spellID) end
        if d.rankMode=="highest" then a.spellIDs={d.spellID}; a.name=exact.name; a.label=a.name; return a end
        a.spellIDs={d.spellID}; a.selectedSpellID=d.spellID; a.explicitRank=true
        a.selectedRank=exact.rank; a.name=exact.name
        a.label=a.name; a.exactSpell=exact
    elseif d.kind=="item" then
        a.kind="item"
        if not K.Items.ApplyToAction then return nil,"Item binding metadata is not ready." end
        K.Items:ApplyToAction(a,d.itemID)
    elseif d.kind=="system" then a.kind="system"; a.command=d.command; a.label=K.API:BindingLabel(d.command); a.known=true
    elseif d.kind=="emote" then a.kind="emote"; a.emote=d.emote; a.label=self:Emotes()[d.emote]; a.known=true; a.icon="Interface\\Icons\\INV_Misc_Note_01"
    else
        a.kind="macroref"; a.macroName=d.macroName; a.macroFingerprint=d.macroFingerprint
        a.macroIndex=GetMacroIndexByName(d.macroName)
        local name,icon,body=GetMacroInfo(a.macroIndex or 0)
        a.known=name==d.macroName and body and K.Macros:Name(body)==d.macroFingerprint or false
        a.label=d.macroName; a.icon=icon
    end
    return a
end
function L:Actions(book)
    local actions,errors={},{}
    for id,d in pairs(K:GetSettings().customActions or {}) do
        local action,why=self:ResolveDescriptor(id,d,book)
        if action then actions[#actions+1]=action else errors[#errors+1]=why end
    end
    table.sort(actions,function(a,b) return a.id<b.id end)
    return actions,errors
end
local function categoryFor(class,def,spell)
    local category,talent
    if def.librarySourceID then def=K.Copy(def); def.id=def.librarySourceID end
    if K.LibraryData then category,talent=K.LibraryData:Classify(class,def,K.API:GetFlavor()) end
    return (spell and spell.category) or category or "General",talent
end
function L:List(options)
    options=options or {}; local tab=options.tab or "spells"; local entries={}
    if tab=="spells" then
        local plan=K:PreviewCached(); local book=K.API:GetCachedSpellbook(); local seen={}
        if self.spellListPlan~=plan then self.spellListPlan=plan; self.spellLists={} end
        local cacheKey=options.showRanks and "ranks" or "families"
        if self.spellLists[cacheKey] then entries=self.spellLists[cacheKey]
        else
        for _,a in ipairs(plan.actions) do
            if not a.kind and not a.builtin and not a.combo and not a.focusOf and a.targeting~="focus" then
                local family=a.name or a.displayName or a.label
                if not seen[family] then
                    seen[family]=true
                    local learned=K.API:Resolve(a,book)
                    local category,talent=categoryFor(plan.class,a,learned)
                    local label=a.displayName or a.label
                    if a.explicitRank and a.selectedRank then label=label.." · "..a.selectedRank end
                    entries[#entries+1]={id=a.id,actionID=a.id,label=label,name=a.name,icon=a.icon,spellID=a.displaySpellID or a.spellID,known=a.known,category=category,talent=talent,form=a.form,targeting=a.targeting}
                    if options.showRanks then
                        for _,rank in ipairs(K.API:GetSpellRanks(a,book)) do
                            if rank.rank and rank.rank~="" then
                                entries[#entries+1]={id="rank."..rank.id,label=rank.name.." · "..rank.rank,name=rank.name,icon=rank.icon,spellID=rank.id,rank=rank.rank,known=rank.known,category=rank.category or category,talent=talent,form=a.form,targeting=a.targeting,descriptor={kind="spell",name=rank.name,spellID=rank.id,rank=rank.rank,form=a.form,targeting=a.targeting}}
                            end
                        end
                    end
                end
            end
        end
        self.spellLists[cacheKey]=entries
        end
    elseif tab=="items" then entries=K.Items.LibraryEntries and K.Items:LibraryEntries() or {}
    elseif tab=="game" or tab=="chat" then
        for command,info in pairs(self:Commands()) do if info.tab==tab then entries[#entries+1]={id="command."..command,label=info.label,category=info.category,known=true,descriptor={kind="system",command=command,name=info.label}} end end
    elseif tab=="emotes" then
        for token,command in pairs(self:Emotes()) do entries[#entries+1]={id="emote."..token,label=command,category="Emotes",known=true,icon="Interface\\Icons\\INV_Misc_Note_01",descriptor={kind="emote",emote=token}} end
    elseif tab=="macros" then
        local account,character=GetNumMacros(); local constants=Constants and Constants.MacroConsts
        local maxAccount=(constants and constants.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
        for bank,count in ipairs({account,character}) do for n=1,count do
            local index=bank==1 and n or maxAccount+n; local name,icon,body=GetMacroInfo(index)
            if name and body then
                local generated=K.db.ownedMacros[name]==body
                entries[#entries+1]={id="macro."..index,label=name,icon=icon,known=true,generated=generated,category=generated and "Hot Swap" or "Your macros",descriptor={kind="macroref",macroName=name,macroFingerprint=K.Macros:Name(body)}}
            end
        end end
    end
    local filtered={}; local query=tostring(options.query or ""):lower()
    for _,entry in ipairs(entries) do
        if (not options.category or options.category=="All" or options.category==entry.category) and (query=="" or entry.label:lower():find(query,1,true)) then filtered[#filtered+1]=entry end
    end
    table.sort(filtered,function(a,b) if a.category~=b.category then return a.category<b.category end; if a.label~=b.label then return a.label<b.label end; return a.id<b.id end)
    return filtered
end
function L:Categories(tab)
    local categories={}; for _,entry in ipairs(self:List({tab=tab})) do categories[entry.category]=true end
    local result={}; for name in pairs(categories) do result[#result+1]=name end; table.sort(result); return result
end
function L:CurrentTargetMode(action) return action.targetMode or "default" end
function L:TargetModes(action)
    if action.kind=="item" then return K.Items.GetTargetModes and K.Items:GetTargetModes(action) or {"default"} end
    if action.kind or action.builtin or action.combo or action.targeting=="form" then return {"default"} end
    if action.targeting=="ground" then return {"default","cursor"} end
    if action.targeting=="help" then
        local values={"default","mouseover","target"}
        if K.API:SupportsFocus() then values[#values+1]="focus" end
        if not action.noSelf then values[#values+1]="self" end; return values
    end
    if action.targeting=="harm" or action.targeting=="focus" or action.targeting=="dead" then
        local values={"default","mouseover","target"}; if K.API:SupportsFocus() then values[#values+1]="focus" end; return values
    end
    return {"default"}
end
local function findAction(id)
    for _,action in ipairs(K:PreviewCached().actions) do if action.id==id then return action end end
end
function L:SetTargetMode(id,mode)
    if busy() then return false,"Wait for the current operation to finish." end
    if mode=="focus" and not K.API:SupportsFocus() then return false,"Focus targeting is unavailable on this client. Choose another target mode." end
    local action=findAction(id); if not action then return false,"That action is unavailable." end
    if action.kind=="item" and K.Items.SetBindingTargetMode then return K.Items:SetBindingTargetMode(id,mode) end
    if not self:CanOverride(id) then return false,"This preset has reached its action-edit limit." end
    local allowed=false; for _,entry in ipairs(self:TargetModes(action)) do if entry==mode then allowed=true end end
    if not allowed then return false,"That target mode is not supported by this action." end
    local overrides=K:GetSettings().actionOverrides; overrides[id]=overrides[id] or {}; overrides[id].targetMode=mode~="default" and mode or nil
    K.Presets:Changed(); return true,"Target behavior saved to this preset."
end
function L:SetRank(id,spellID)
    if busy() then return false,"Wait for the current operation to finish." end
    if not self:CanOverride(id) then return false,"This preset has reached its action-edit limit." end
    local action=findAction(id); if not action or action.kind or action.combo then return false,"Choose a spell action." end
    if spellID then
        local found=false
        for _,rank in ipairs(K.API:GetSpellRanks(action)) do if rank.id==spellID and rank.rank and rank.rank~="" then found=true end end
        if not found then return false,"This exact rank is not available in the client's spell data." end
    end
    local overrides=K:GetSettings().actionOverrides; overrides[id]=overrides[id] or {}; overrides[id].spellID=spellID
    if not spellID then
        local descriptor=overrides[id].replacement or K:GetSettings().customActions[id]
        if descriptor and descriptor.kind=="spell" and descriptor.spellID then descriptor.rankMode="highest" end
    end
    K.Presets:Changed(); return true,spellID and "Fixed rank saved to this preset." or "Highest learned rank restored."
end
function L:Place(entry,id,mode)
    if busy() then return false,"Wait for the current operation to finish." end
    if not self:CanOverride(id) then return false,"This preset has reached its action-edit limit." end
    local destination=findAction(id)
    if not destination or destination.kind=="system" then return false,"Choose a spell or action position." end
    local descriptor=entry and entry.descriptor and K.Copy(entry.descriptor)
    if not descriptor and entry and entry.actionID then
        local source=findAction(entry.actionID)
        if source and not source.kind and not source.builtin then
            descriptor={kind="spell",sourceID=source.id,name=source.name,targeting=source.targeting}
            if source.id:match("^custom%.") then descriptor=K.Copy(K:GetSettings().customActions[source.id]) end
            if source.id:match("^spell%.") then descriptor={kind="spell",spellID=source.spellID,name=source.spellName,targeting=source.targeting,rankMode="highest"} end
        end
    end
    local valid,why=self:ValidateDescriptor(descriptor); if not valid then return false,why end
    if descriptor.kind=="system" then return false,"Game commands need a global key outside the form-changing main bar." end
    local settings=K:GetSettings(); local nextItems
    if descriptor.kind=="item" then
        if not settings.itemBindings[id] and entries(settings.itemBindings)>=self.limits.itemBindings then return false,"This preset has reached its item-binding limit." end
        nextItems={selected=descriptor.itemID,alternatives={},targetMode=mode or "default"}
        local seen={}; local old=settings.itemBindings[id]
        local function keep(value) if value and not seen[value] then seen[value]=true; nextItems.alternatives[#nextItems.alternatives+1]=value end end
        for _,value in ipairs(old and old.alternatives or {}) do keep(value) end
        keep(old and old.selected); keep(descriptor.itemID)
        local ok,message=K.Items:ValidateBinding(nextItems); if not ok then return false,message end
    end
    local replacement,err
    if nextItems then replacement=K.Items:ApplyToAction({id=id},descriptor.itemID,nextItems)
    else replacement,err=self:ResolveDescriptor(id,descriptor) end
    if not replacement then return false,err end
    if mode and mode~="default" then
        local allowed=false; for _,candidate in ipairs(self:TargetModes(replacement)) do if candidate==mode then allowed=true end end
        if not allowed then return false,"That target mode is unavailable for this action." end
    end
    settings.actionOverrides[id]={replacement=descriptor,targetMode=not nextItems and mode~="default" and mode or nil}
    settings.itemBindings[id]=nextItems
    K.Presets:Changed(); return true,"Action replaced on this page. Its key and the other form pages are preserved."
end
function L:Stage(entry,targetMode)
    if busy() then return false,"Wait for the current operation to finish." end
    if type(entry)~="table" then return false,"Choose a library action." end
    local settings=K:GetSettings(); local id=entry.actionID; local created=false
    if not id then
        if entries(settings.customActions)>=self.limits.customActions then return false,"This preset has reached its 256 custom-action limit." end
        if entry.descriptor and entry.descriptor.kind=="item" and entries(settings.itemBindings)>=self.limits.itemBindings then return false,"This preset has reached its item-binding limit." end
        local ok,why=self:ValidateDescriptor(entry.descriptor); if not ok then return false,why end
        local resolved,err=self:ResolveDescriptor("preview",entry.descriptor); if not resolved then return false,err end
        repeat K.db.nextCustomActionID=(K.db.nextCustomActionID or 0)+1; id="custom."..K.db.nextCustomActionID until not settings.customActions[id]
        settings.customActions[id]=K.Copy(entry.descriptor); settings.customActions[id].form="all"; created=true
    elseif not findAction(id) then return false,"That spell action is no longer available." end
    local token={presetID=K.db.presets[K.db.activePreset].id,id=id,created=created,previousOverride=K.Copy(settings.actionOverrides[id]),previousItems=K.Copy(settings.itemBindings[id])}
    if created and entry.descriptor.kind=="item" then settings.itemBindings[id]={selected=entry.descriptor.itemID,alternatives={entry.descriptor.itemID},targetMode="default"} end
    K.Presets:Changed()
    if targetMode and targetMode~="default" then local ok,why=self:SetTargetMode(id,targetMode); if not ok then self:Unstage(token); return false,why end end
    return true,id,"Action ready to bind.",token
end
function L:Unstage(token)
    if not token or busy() or K.db.presets[K.db.activePreset].id~=token.presetID then return false end
    local settings=K:GetSettings()
    if token.created then settings.customActions[token.id]=nil; settings.bindingOverrides[token.id]=nil; settings.fallbackBindings[token.id]=nil end
    settings.actionOverrides[token.id]=K.Copy(token.previousOverride); settings.itemBindings[token.id]=K.Copy(token.previousItems); K.Presets:Changed(); return true
end
