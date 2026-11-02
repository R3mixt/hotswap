local _, K = ...
K.Planner={}
local P=K.Planner
local pageOrder={all=0,caster=1,moonkin=2,cat=3,prowl=4,bear=5,travel=6,aquatic=7}
local function overlaps(a,b) return a==b or a=="all" or b=="all" end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function altKey(key) return K.API:NormalizeKey("ALT-"..key) end
local reservedBase={W=true,A=true,S=true,D=true,SPACE=true,TAB=true,ESCAPE=true,ENTER=true,BUTTON1=true,BUTTON2=true}
local function bases(key) return key:gsub("ALT%-",""):gsub("CTRL%-",""):gsub("SHIFT%-","") end
local systemMap={
    {"W","MOVEFORWARD","Move forward"},{"S","MOVEBACKWARD","Move backward"},{"A","STRAFELEFT","Strafe left"},{"D","STRAFERIGHT","Strafe right"},{"SPACE","JUMP","Jump"},
    {"BUTTON1","CAMERAORSELECTORMOVE","Select / camera"},{"BUTTON2","TURNORACTION","Turn / interact"},{"PRINTSCREEN","SCREENSHOT","Screenshot"},
    {"ALT-`","TOGGLEAUTORUN","Auto-run"},{"ALT-MOUSEWHEELUP","CAMERAZOOMIN","Zoom in"},{"ALT-MOUSEWHEELDOWN","CAMERAZOOMOUT","Zoom out"},
    {"I","OPENALLBAGS","Bags"},{"J","TOGGLECHARACTER0","Character"},{"K","TOGGLESPELLBOOK","Spellbook"},{"P","TOGGLETALENTS","Talents"},
    {"M","TOGGLEWORLDMAP","Map"},{"L","TOGGLEQUESTLOG","Quest log"},{"O","TOGGLESOCIAL","Social"},{"ESCAPE","TOGGLEGAMEMENU","Game menu"},
    {"TAB","TARGETNEARESTENEMY","Next enemy"},{"SHIFT-TAB","TARGETPREVIOUSENEMY","Previous enemy"},
    {"ENTER","OPENCHAT","Open chat"},{"SHIFT-ENTER","OPENCHATSLASH","Open command chat"},
    {"F1","TARGETSELF","Target self"},{"F2","TARGETPARTYMEMBER1","Target party 1"},{"F3","TARGETPARTYMEMBER2","Target party 2"},{"F4","TARGETPARTYMEMBER3","Target party 3"},{"F5","TARGETPARTYMEMBER4","Target party 4"},{"F6","TARGETFOCUS","Target focus"},
}
local racialDefs={
    {20549,"War Stomp","self"},{20580,"Shadowmeld","none"},{20594,"Stoneform","self"},{7744,"Will of the Forsaken","self"},{26297,"Berserking","self"},{20572,"Blood Fury","self"},{20589,"Escape Artist","self"},{20577,"Cannibalize","none"},{58984,"Shadowmeld","none"},{28730,"Arcane Torrent","self"},{28880,"Gift of the Naaru","help"},{59752,"Will to Survive","self"},
}
function P:Build(useCachedData)
    local settings=K:GetSettings()
    local _,class=UnitClass("player"); K.playerClass=class
    local flavor=K.API:GetFlavor()
    local bindingCommands,bindingCommandsReadable=K.API:GetBindingCommands()
    local supportsFocus=K.API:SupportsFocus()
    local version,build=GetBuildInfo()
    local selected=K.db.presets[K.db.activePreset]
    local plan={actions={},system={},conflicts={},errors={},warnings={},changes={},coverage={total=0,bound=0,missing={},catalogTotal=0,catalogKnown=0,catalogReserved=0},class=class,flavor=flavor,build=tostring(version).."."..tostring(build),formSignature=K.API:FormSignature(),settings=K.Copy(settings),fallbackBindings=K.Copy(settings.fallbackBindings or {}),presetName=K.db.activePreset,presetID=selected and selected.id}
    local protected,preserved,protectionError=K.Protection:Build(settings)
    plan.protectedKeys,plan.preservedActions=protected or {},preserved or {}
    if protectionError then plan.errors[#plan.errors+1]=protectionError end
    local validChoices,choiceError=K.TalentBindings:ValidateSettings(settings)
    if not validChoices then plan.errors[#plan.errors+1]=choiceError end
    local book=useCachedData and K.API:GetCachedSpellbook() or K.API:ScanSpellbook()
    local definitions=K.Profiles and K.Profiles:Get(class,flavor) or {}
    if #definitions==0 then plan.warnings[#plan.warnings+1]="This class uses spellbook coverage rather than a curated class profile." end
    if flavor=="retail" then plan.warnings[#plan.warnings+1]="Retail is a compatibility profile. Its additional spells receive explicit coverage bindings." end
    local coverage={}
    local used={}
    local ids={}
    local function add(def)
        local action=K.TalentBindings and K.TalentBindings:Resolve(def,settings,book) or K.Copy(def)
        local override=(settings.actionOverrides or {})[action.id]
        if override and override.replacement and K.Library then
            local replacement,why=K.Library:ResolveDescriptor(def.id,override.replacement,book)
            if replacement then
                replacement.id,replacement.form,replacement.key=def.id,def.form,def.key
                action=replacement
            else plan.errors[#plan.errors+1]=why end
        end
        local slots={ ["1"]=1,["2"]=2,["3"]=3,["4"]=4,["5"]=5,["SHIFT-1"]=6,["SHIFT-2"]=7,["SHIFT-3"]=8,["SHIFT-4"]=9,["SHIFT-5"]=10,["R"]=11,["SHIFT-R"]=12 }
        action.barSlot=(not def.kind or (override and override.replacement)) and slots[def.key] or nil
        action.form=action.form or "all"
        if action.kind=="item" and settings.itemBindings and settings.itemBindings[action.id] and K.Items.ApplyToAction then K.Items:ApplyToAction(action,action.itemID,settings.itemBindings[action.id]) end
        action.category=action.category or "Utility"
        action.label=action.label or action.name or action.id
        if override then
            if not K.Library or not K.Library:ValidateOverride(override) then plan.errors[#plan.errors+1]="Invalid spell override for "..action.label
            else
                if action.kind~="item" then action.targetMode=override.targetMode end
                if override.spellID then
                    local matching=false
                    for _,rank in ipairs(K.API:GetSpellRanks(action,book)) do if rank.id==override.spellID then matching=true end end
                    if not matching then plan.errors[#plan.errors+1]="Selected rank does not belong to "..action.label
                    else action.selectedSpellID=override.spellID; action.explicitRank=true end
                end
            end
        end
        if ids[action.id] then plan.errors[#plan.errors+1]="Duplicate action ID: "..action.id end
        ids[action.id]=true
        local exact=action.selectedSpellID and K.API:ResolveExact(action.selectedSpellID,book)
        if exact then action.selectedRank=exact.rank or action.selectedRank end
        local spell=not action.kind and not action.builtin and (action.selectedSpellID and (exact and exact.known and exact or nil) or K.API:Resolve(action,book))
        if action.selectedSpellID and (not exact or not exact.known) then spell=nil end
        if spell and spell.passive then spell=nil end
        if spell then
            action.known=true; action.spellID=spell.id; action.spellName=spell.name; action.icon=spell.icon; action.label=spell.name..(action.targeting=="focus" and " · focus" or "")
        elseif action.known==nil then action.known=false end
        if not action.kind and not action.builtin then
            local display=exact or spell or K.API:ResolveDisplay(action)
            action.displayName=display and display.name or action.name or action.label
            if display then
                action.displaySpellID=display.id
                action.displayIcon=display.icon
                action.icon=action.icon or display.icon
                if not action.known and not action.combo and not def.label then
                    action.label=display.name..(action.targeting=="focus" and " · focus" or "")
                end
            end
        end
        if action.explicitRank and action.selectedRank then action.label=action.label.." · "..action.selectedRank end
        if K.API:ActionUsesFocus(action) and not supportsFocus then
            plan.errors[#plan.errors+1]="Focus targeting is unavailable on this client: "..action.label..". Choose another target mode."
        end
        if action.targetMode and K.Library then
            local valid=false; for _,mode in ipairs(K.Library:TargetModes(action)) do if mode==action.targetMode then valid=true end end
            if not valid then plan.errors[#plan.errors+1]="Unsupported target mode for "..action.label end
        end
        if action.combo and action.known then
            local names={}
            for _,id in ipairs(action.combo) do
                local component=K.API:Resolve({spellIDs=type(id)=="number" and {id} or {},name=type(id)=="string" and id or nil},book)
                if component and not component.passive then names[#names+1]=component.name else action.known=false end
            end
            action.label=table.concat(names," + ")
            if not action.known then action.label=def.label or (def.name.." + heal · unavailable") end
        end
        if spell and action.known then
            coverage[spell.name]=true
            if action.rankFamily then
                for _,id in ipairs(action.spellIDs or {}) do
                    local member=book.byID[id]; local name=member and member.name or K.API:SpellInfo(id)
                    if name and book.byName[name] then coverage[name]=true end
                end
                for _,name in ipairs(action.spellNames or {}) do if book.byName[name] then coverage[name]=true end end
            end
        end
        action.key=K.API:NormalizeKey((not action.id:match("^mode%.") and settings.bindingOverrides[action.id]) or action.key)
        if K.Availability then K.Availability:Annotate(action,class,flavor) end
        if class=="MAGE" and settings.primarySchool=="fire" and not settings.bindingOverrides[action.id] then
            if action.name=="Fireball" then action.key="1" elseif action.name=="Frostbolt" then action.key="SHIFT-1" end
        end
        plan.actions[#plan.actions+1]=action
        return action
    end
    for _,def in ipairs(definitions) do
        local override=settings.actionOverrides and settings.actionOverrides[def.id]
        local replaced=override and (override.replacement or (override.targetMode and override.targetMode~="default" and override.targetMode~="focus"))
        if supportsFocus or not K.API:ActionUsesFocus(def) or replaced then add(def)
        elseif (settings.bindingOverrides or {})[def.id] or override then
            -- A stock focus variant can be omitted on Era. An edited/imported
            -- focus intent needs an explicit error, never a different target.
            plan.errors[#plan.errors+1]="Saved focus action is unavailable on this client: "..tostring(def.label or def.name or def.id)..". Remove its override or choose another target mode."
        end
    end
    local catalogFamilies={}
    for _,action in ipairs(plan.actions) do
        if not action.combo and not action.focusOf and action.targeting~="focus" then
            local family=action.rankFamily and action.id or tostring(action.spellIDs and action.spellIDs[1] or action.name)
            local entry=catalogFamilies[family] or {known=false}
            entry.known=entry.known or action.known; catalogFamilies[family]=entry
        end
    end
    for _,entry in pairs(catalogFamilies) do
        plan.coverage.catalogTotal=plan.coverage.catalogTotal+1
        if entry.known then plan.coverage.catalogKnown=plan.coverage.catalogKnown+1 else plan.coverage.catalogReserved=plan.coverage.catalogReserved+1 end
    end
    if K.Library then
        local actions,errors=K.Library:Actions(book)
        for _,why in ipairs(errors) do plan.errors[#plan.errors+1]=why end
        for _,def in ipairs(actions) do
            if def.kind=="system" and K.Protection:Preserves(def.command,settings,bindingCommands) then
                plan.warnings[#plan.warnings+1]="Protected game control left unchanged: "..tostring(def.label or def.command)
            else add(def) end
        end
    end
    local function addSystem(id,key,command,label)
        if K.Protection:Preserves(command,settings,bindingCommands) then return end
        local supported=K.API:IsBindingCommandSupported(command,bindingCommands) or (not bindingCommandsReadable and command~="TARGETFOCUS")
        if supported then
            local a=add({id=id,key=key,label=label,kind="system",command=command,known=true,category="System"})
            plan.system[#plan.system+1]=a
        elseif (settings.bindingOverrides or {})[id] or (settings.actionOverrides or {})[id] then
            plan.errors[#plan.errors+1]="Saved game command is unavailable on this client: "..label.." ("..command.."). Remove its override before using this preset."
        else plan.warnings[#plan.warnings+1]=label.." is unavailable on this client; its default key is not assigned." end
    end
    for _,mapping in ipairs(systemMap) do
        addSystem("system."..mapping[2],mapping[1],mapping[2],mapping[3])
    end
    if K.Presets and K.Presets.Actions then
        for _,definition in ipairs(K.Presets:Actions()) do
            local a=add(definition); plan.system[#plan.system+1]=a
        end
    end
    if not settings.wheel then
        for _,m in ipairs({{"MOUSEWHEELUP","CAMERAZOOMIN","Zoom in"},{"MOUSEWHEELDOWN","CAMERAZOOMOUT","Zoom out"}}) do
            addSystem("system.normal."..m[2],m[1],m[2],m[3])
        end
    end
    add({id="item.trinket13",key="T",label="Trinket · upper slot",kind="item",itemSlot=13,known=true,category="Items"})
    add({id="item.trinket14",key="SHIFT-T",label="Trinket · lower slot",kind="item",itemSlot=14,known=true,category="Items"})
    local itemKeys={utility="CTRL-T",potion="CTRL-SPACE",healthstone="SHIFT-SPACE",mount="`"}
    if useCachedData then K.Items:GetCached() else K.Items:Scan() end
    for _,slotName in ipairs({"utility","potion","healthstone","mount"}) do
        local id=K.Items:GetSelected(slotName) or (slotName=="mount" and settings.mount)
        local item=K.Items:Resolve(id)
        local a=add({id="item."..slotName,key=itemKeys[slotName],label=slotName=="mount" and "Mount · choose an item" or slotName=="utility" and "Selected on-use item" or slotName=="potion" and "Healing potion" or "Healthstone",kind="item",known=item~=nil and not item.missing and not item.requiresEquip,category="Items"})
        if item and not ((settings.actionOverrides[a.id] or {}).replacement or settings.itemBindings[a.id]) then
            a.label=item.name; a.icon=item.icon
            if item.kind=="mountspell" then a.mountSpell=item.spellID; a.spellName=item.name; a.spellID=item.spellID
            elseif item.slot then a.itemSlot=item.slot else a.itemID=id end
            a.isMount=slotName=="mount"
            if item.requiresEquip then plan.warnings[#plan.warnings+1]=item.name.." must be equipped first; its item key is inactive." end
            if item.missing then plan.warnings[#plan.warnings+1]=item.name.." is missing from your bags and equipment." end
        end
    end
    for _,v in ipairs({{"cancel","BUTTON3","Leave form"},{"focus","SHIFT-BUTTON3","Set focus"},{"clearfocus","CTRL-BUTTON3","Clear focus"}}) do
        local id="utility."..v[1]
        if settings.preserveTargeting and v[1]~="cancel" then
            -- Focus management is a targeting control, not a class spell.
        elseif v[1]=="cancel" or supportsFocus then
            add({id=id,key=v[2],label=v[3],builtin=v[1],known=true,category="Utility"})
        elseif (settings.bindingOverrides or {})[id] or (settings.actionOverrides or {})[id] then
            plan.errors[#plan.errors+1]="Saved focus utility is unavailable on this client: "..v[3]..". Remove its override before using this preset."
        end
    end
    local racialCount=0; local raceNames={}
    for _,def in ipairs(racialDefs) do
        local spell=K.API:Resolve({spellIDs={def[1]},name=def[2]},book)
        if spell and not raceNames[spell.name] then
            raceNames[spell.name]=true; racialCount=racialCount+1
            add({id="racial."..def[1],spellIDs={def[1]},name=def[2],key=racialCount==1 and "CTRL-F" or racialCount==2 and "CTRL-Z" or "SHIFT-H",category="Racial",targeting=def[3]})
        end
    end
    if class=="HUNTER" or class=="WARLOCK" then
        for _,v in ipairs({{"petattack","CTRL-F7","Pet attack"},{"petfollow","CTRL-F8","Pet follow"},{"petpassive","CTRL-F9","Pet passive"}}) do add({id="pet."..v[1],key=v[2],label=v[3],builtin=v[1],known=true,category="Pet"}) end
    end
    -- Hardware availability is based on observed input events, never guessed hardware counts.
    local function available(key,action)
        if not key then return false end
        if plan.protectedKeys[key] then return false end
        if action and (action.talentHasHelpful or ((action.targeting=="help" or action.itemTargeting=="help") and not action.noSelf)) and plan.protectedKeys[altKey(key)] then return false end
        if action.kind=="system" then return true end
        if not settings.ctrl and key:find("CTRL%-") then return false end
        local base=bases(key)
        if base=="MOUSEWHEELUP" or base=="MOUSEWHEELDOWN" then return settings.wheel end
        if base=="BUTTON3" then return settings.middle end
        if base:match("^BUTTON%d+$") then return settings.mouseButtons[base]==true end
        return true
    end
    local function reserve(a)
        if not a.key then return end
        used[a.key]=used[a.key] or {}
        used[a.key][#used[a.key]+1]=a
    end
    local function free(key,form)
        if plan.protectedKeys[key] then return false end
        for _,a in ipairs(used[key] or {}) do if overlaps(a.form,form) then return false end end
        return true
    end
    local fallbacks={}
    -- Extra observed side buttons are useful capacity; no phantom hardware slots.
    for _,modifier in ipairs({"","SHIFT-","CTRL-"}) do
        if modifier~="CTRL-" or settings.ctrl then
            for n=6,31 do if settings.mouseButtons["BUTTON"..n] then fallbacks[#fallbacks+1]=modifier.."BUTTON"..n end end
        end
    end
    for _,key in ipairs({"H","Y","U","N","SHIFT-H","SHIFT-Y","SHIFT-U","SHIFT-N","6","SHIFT-6","7","SHIFT-7","8","SHIFT-8","9","SHIFT-9","0","SHIFT-0","-","=","[","]",";","'",",",".","/","\\"}) do fallbacks[#fallbacks+1]=key end
    for _,m in ipairs({"CTRL-","SHIFT-",""}) do
        if m~="CTRL-" or settings.ctrl then
            for i=7,12 do fallbacks[#fallbacks+1]=m.."F"..i end
            for i=0,9 do fallbacks[#fallbacks+1]=m.."NUMPAD"..i end
        end
    end
    if settings.ctrl then for _,key in ipairs({"H","Y","U","N","6","7","8","9","0","-","=","[","]",";","'",",",".","/","\\"}) do fallbacks[#fallbacks+1]="CTRL-"..key end end
    -- A native main-bar position has one binding across every form bank.
    -- Protection can block only one page's Alt-self alias, but allocation must
    -- still move the whole position rather than splitting its form keys.
    local linked,groupOf={},{}
    local nativeDruidPages={caster=true,cat=true,bear=true,moonkin=true}
    for _,action in ipairs(plan.actions) do
        if action.barSlot and ((class=="DRUID" and nativeDruidPages[action.form]) or class~="DRUID") then
            local group=linked[action.barSlot] or {actions={}}
            linked[action.barSlot]=group; groupOf[action]=group
            group.actions[#group.actions+1]=action
            group.blocked=group.blocked or not available(action.key,action)
        end
    end
    for _,action in ipairs(plan.actions) do
        local group=groupOf[action]
        if not (group and group.blocked) and available(action.key,action) then reserve(action)
        else action.requestedKey=action.key; action.key=nil end
    end
    local function allocate(action)
        local preferred=K.API:NormalizeKey(plan.fallbackBindings[action.id])
        if preferred and available(preferred,action) and free(preferred,action.form) then action.key=preferred
        else
            for _,key in ipairs(fallbacks) do if available(key,action) and free(key,action.form) then action.key=key; break end end
        end
        if action.key then plan.fallbackBindings[action.id]=action.key; reserve(action)
        else plan.errors[#plan.errors+1]="No available key for "..action.label end
    end
    local function allocateGroup(group)
        if group.attempted then return end
        group.attempted=true
        for _,action in ipairs(group.actions) do
            if settings.bindingOverrides[action.id] then
                plan.errors[#plan.errors+1]="Custom key "..tostring(settings.bindingOverrides[action.id]).." is protected or unavailable for linked position "..action.barSlot
                return
            end
        end
        local function usable(key)
            if not key then return false end
            for _,action in ipairs(group.actions) do if not available(key,action) or not free(key,action.form) then return false end end
            return true
        end
        local selected
        for _,action in ipairs(group.actions) do
            local preferred=K.API:NormalizeKey(plan.fallbackBindings[action.id])
            if usable(preferred) then selected=preferred; break end
        end
        if not selected then for _,key in ipairs(fallbacks) do if usable(key) then selected=key; break end end end
        if not selected then plan.errors[#plan.errors+1]="No available key for linked main-bar position "..group.actions[1].barSlot; return end
        for _,action in ipairs(group.actions) do
            action.key=selected; plan.fallbackBindings[action.id]=selected; reserve(action)
        end
    end
    for _,action in ipairs(plan.actions) do
        if not action.key then
            if action.id:match("^mode%.") then plan.errors[#plan.errors+1]="Preset hotkey "..tostring(action.requestedKey).." is protected or unavailable. Choose another preset hotkey."
            elseif groupOf[action] then allocateGroup(groupOf[action])
            elseif settings.bindingOverrides[action.id] then plan.errors[#plan.errors+1]="Custom key "..tostring(settings.bindingOverrides[action.id]).." is protected or unavailable for "..action.label
            else allocate(action) end
        end
    end
    -- Every distinct active spell in the actual spellbook receives an explicit bind.
    for _,spell in ipairs(book.list) do
        plan.coverage.total=plan.coverage.total+1
        if not coverage[spell.name] then
            local a=add({id="spell."..K.Macros:Name(spell.name):sub(5),name=spell.name,spellIDs={spell.id},category="Additional spells",targeting=K.API:Helpful(spell.id) and "help" or "harm",source="Spellbook coverage",known=true})
            if a.key and not available(a.key,a) then
                plan.errors[#plan.errors+1]="Custom key "..a.key.." is protected or unavailable for "..a.label
                a.requestedKey=a.key; a.key=nil
            elseif a.key then reserve(a) else allocate(a) end
            coverage[spell.name]=a.key~=nil
        end
        if coverage[spell.name] then plan.coverage.bound=plan.coverage.bound+1 else plan.coverage.missing[#plan.coverage.missing+1]=spell.name end
    end
    for key,actions in pairs(used) do
        for i=1,#actions do for j=i+1,#actions do
            if overlaps(actions[i].form,actions[j].form) then plan.errors[#plan.errors+1]=key.." is assigned to both "..actions[i].label.." and "..actions[j].label.." ("..actions[i].form.." / "..actions[j].form..")." end
        end end
    end
    local conflictKeys={}
    for _,a in ipairs(plan.actions) do
        if a.key then
            local base=bases(a.key)
            if a.kind~="system" and (a.key:find("ALT%-") or a.key=="W" or a.key=="A" or a.key=="S" or a.key=="D" or a.key=="SPACE" or a.key=="TAB" or a.key=="ESCAPE" or a.key=="ENTER" or base=="BUTTON1" or base=="BUTTON2") then
                plan.errors[#plan.errors+1]="Reserved movement, targeting, or self-cast key: "..a.key
            end
            if a.kind=="system" and a.key:find("ALT%-") and a.key~="ALT-`" and a.key~="ALT-MOUSEWHEELUP" and a.key~="ALT-MOUSEWHEELDOWN" then plan.errors[#plan.errors+1]="Alt is reserved for self-cast, camera zoom, and auto-run." end
            local body,err=K.Macros:Build(a,settings); a.body=body
            if err then plan.errors[#plan.errors+1]=err end
            a.previousBinding=K.API:BindingAction(a.key)
            a.previousBindingLabel=K.API:BindingLabel(a.previousBinding)
            if a.previousBinding~="" and not a.previousBinding:find("^CLICK KBO_") and a.previousBinding~=a.command and not conflictKeys[a.key] then
                conflictKeys[a.key]=true
                plan.conflicts[#plan.conflicts+1]={key=a.key,label=a.label,previous=a.previousBinding,previousLabel=a.previousBindingLabel,message=a.key..": "..a.previousBindingLabel.." -> "..a.label}
            end
            if a.talentHasHelpful or ((a.targeting=="help" or a.itemTargeting=="help") and not a.noSelf) then
                a.selfKey=altKey(a.key)
                if a.selfKey and used[a.selfKey] then plan.errors[#plan.errors+1]="Self-cast conflict: "..a.selfKey end
                local previous=a.selfKey and K.API:BindingAction(a.selfKey) or ""
                if previous~="" and not previous:find("^CLICK KBO_") and not conflictKeys[a.selfKey] then
                    conflictKeys[a.selfKey]=true
                    plan.conflicts[#plan.conflicts+1]={key=a.selfKey,label="Self-cast "..a.label,previous=previous,previousLabel=K.API:BindingLabel(previous),message=a.selfKey..": "..K.API:BindingLabel(previous).." -> self-cast "..a.label}
                end
            end
        end
    end
    if K.NativeBars and K.NativeBars.Prepare then
        local layout,why=K.NativeBars:Prepare(plan)
        if not layout then plan.errors[#plan.errors+1]=why or "Native action bars could not be prepared." end
    end
    plan.macrosNeeded,plan.macrosAvailable=K.Macros:Budget(plan)
    if plan.macrosNeeded>plan.macrosAvailable then plan.errors[#plan.errors+1]="Need "..plan.macrosNeeded.." free macro slots; only "..plan.macrosAvailable.." are available. No macros will be overwritten." end
    if plan.coverage.total==0 then plan.warnings[#plan.warnings+1]="No active spells found. Open your spellbook and refresh before applying." end
    if settings.hideUnavailableSpells or settings.adaptTalents or next(settings.talentAlternatives or {}) then
        plan.changes[#plan.changes+1]="Learned spells and talent choices update owned slots outside combat. Keys stay in place; personal bar edits are preserved."
    else plan.warnings[#plan.warnings+1]="Review new spells and talents here. Established keys are not moved automatically." end
    plan.changes[#plan.changes+1]=settings.preserveGameSettings and "Existing casting modifiers and game settings are preserved." or ("Alt self-cast; focus-cast modifier cleared; automatic self fallback "..(settings.selfFallback and "enabled in helpful macros" or "disabled")..".")
    plan.changes[#plan.changes+1]=settings.preserveCamera and "Existing camera and mouse controls are protected." or ("Mouse wheel abilities "..(settings.wheel and "on; Alt-wheel zoom" or "off; normal wheel zoom restored")..".")
    plan.changes[#plan.changes+1]="A named backup is saved first. Applying updates planned keys and preserves unrelated bindings."
    table.sort(plan.actions,function(a,b)
        local x,y=pageOrder[a.form] or 9,pageOrder[b.form] or 9
        if x~=y then return x<y end
        if a.category~=b.category then return a.category<b.category end
        if (a.key or "")~=(b.key or "") then return (a.key or "")<(b.key or "") end
        return a.id<b.id
    end)
    return plan
end
