local _, K = ...
K.Engine={buttons={}}
local E=K.Engine
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function captureBindings()
    local result={}
    for index=1,(GetNumBindings and GetNumBindings() or 0) do
        local values={GetBinding(index)}
        local command=values[1]
        -- Current supported clients return command, category, key1, key2, ... .
        for i=3,#values do if values[i] and values[i]~="" then result[values[i]]=command end end
    end
    return result
end
local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name)
end
local function setCVar(name,value)
    if value==nil then return end
    local fn=C_CVar and C_CVar.SetCVar or SetCVar
    if fn then fn(name,value) end
end
local function loadBindings(set)
    if LoadBindings and LoadBindings(set)==false then error("Could not load binding set "..tostring(set)) end
end
local function saveBindings(set)
    if SaveBindings(set)==false then error("Could not save binding set "..tostring(set)) end
end
local function runtimeState()
    return {enabled=K.db.enabled and true or false,dirty=K.dirty,appliedPlan=K.Copy(K.db.appliedPlan),ownedMacros=K.Copy(K.db.ownedMacros or {}),baseline=K.Copy(K.db.backup),settings=K.Copy(K.db.settings),activePreset=K.db.activePreset,appliedPreset=K.db.appliedPreset,presetState=K.Presets and K.Presets.SnapshotState and K.Presets:SnapshotState() or nil}
end
local function restoreRuntime(state,mergePresets)
    if state.presetState then
        if mergePresets and K.Presets and K.Presets.RestoreState then K.Presets:RestoreState(K.Copy(state.presetState))
        else
            local p=state.presetState
            K.db.presets=K.Copy(p.presets); K.db.activePreset=p.activePreset; K.db.appliedPreset=p.appliedPreset; K.db.appliedPresetSignature=p.appliedPresetSignature; K.db.nextPresetID=p.nextPresetID
            K.db.settings=K.Copy(p.settings or state.settings)
            if K.db.presets and K.db.presets[K.db.activePreset] then K.db.presets[K.db.activePreset].settings=K.db.settings end
        end
    else K.db.settings=K.Copy(state.settings); K.db.activePreset=state.activePreset; K.db.appliedPreset=state.appliedPreset end
    K.db.enabled=state.enabled; K.db.appliedPlan=K.Copy(state.appliedPlan)
    K.dirty=state.dirty
    K.db.ownedMacros=K.Copy(state.ownedMacros or {}); K.db.backup=K.Copy(state.baseline)
end
function E:CaptureBackup(reason,supplied)
    if type(supplied)~="table" or type(supplied.bindings)~="table" then error("A completed binding-read stage is required before saving a backup.") end
    local entry
    local runtime=runtimeState()
    -- A staged preset may differ from the layout currently installed.
    if runtime.enabled and runtime.appliedPlan then
        runtime.dirty=false
        runtime.settings=K.Copy(runtime.appliedPlan.settings)
        runtime.settings.fallbackBindings=K.Copy(runtime.appliedPlan.fallbackBindings or runtime.settings.fallbackBindings or {})
        if runtime.presetState then
            runtime.presetState.activePreset=runtime.presetState.appliedPreset or runtime.presetState.activePreset
            -- Execution is restored from appliedPlan. Keep the editing draft
            -- belonging to that mode, including unapplied binding/hardware edits.
            local selected=runtime.presetState.presets[runtime.presetState.activePreset]
            if selected and selected.settings then runtime.settings=K.Copy(selected.settings) end
            runtime.presetState.settings=K.Copy(runtime.settings)
        end
    end
    local function persist(active)
        K.db.bindingBackups=K.db.bindingBackups or {}; K.db.bindingBackupOrder=K.db.bindingBackupOrder or {}
        K.db.nextBindingBackupID=(K.db.nextBindingBackupID or 0)+1
        local id="backup-"..tostring(active.createdAt).."-"..tostring(K.db.nextBindingBackupID)
        local character=UnitName and UnitName("player") or "Character"
        local class=UnitClass and UnitClass("player") or "Class"
        local stamp=date and date("%Y-%m-%d %H:%M:%S",active.createdAt) or tostring(active.createdAt)
        local baseName=tostring(character).."-"..tostring(class).."-"..stamp
        local name,suffix=baseName,1
        local duplicate=true
        while duplicate do
            duplicate=false
            for _,saved in pairs(K.db.bindingBackups) do if saved.name==name then duplicate=true; suffix=suffix+1; name=baseName.." ("..suffix..")"; break end end
        end
        entry={id=id,name=name,createdAt=active.createdAt,preset=K.db.appliedPreset or K.db.activePreset,enabled=runtime.enabled,status="saved",complete=false,reason=reason or "apply",snapshot=active,runtime=runtime}
        K.db.bindingBackups[id]=entry; K.db.bindingBackupOrder[#K.db.bindingBackupOrder+1]=id
    end
    persist(supplied)
    return supplied,entry
end
function E:ListBackups()
    local result={}
    for index=#(K.db and K.db.bindingBackupOrder or {}),1,-1 do
        local entry=K.db.bindingBackups[K.db.bindingBackupOrder[index]]
        if entry then result[#result+1]={id=entry.id,name=entry.name,createdAt=entry.createdAt,preset=entry.preset,enabled=entry.enabled,status=entry.status} end
    end
    return result
end
function E:CreateMacros(plan,created)
    local bodies={}
    local _,_,maxAccount,maxCharacter=K.Macros:Budget(plan)
    for _,a in ipairs(plan.actions) do
        if (a.known or a.nativeMacro) and a.body then
            if not bodies[a.body] then
                local name=K.Macros:Name(a.body)
                local index,ownedName=K.Macros:FindOwned(name,a.body)
                if ownedName then name=ownedName end
                if not index then
                    local suffix=0
                    while GetMacroIndexByName(name)>0 do
                        suffix=suffix+1; name=K.Macros:Name(a.body).."_"..suffix
                    end
                    local account,character=GetNumMacros()
                    local perCharacter=character<maxCharacter
                    if not perCharacter and account>=maxAccount then error("No free macro slots remain.") end
                    index=CreateMacro(name,a.icon or "INV_MISC_QUESTIONMARK",a.body,perCharacter)
                    if not index or index==0 then error("Could not create "..a.label.." macro.") end
                    K.db.ownedMacros[name]=a.body; created[name]=a.body
                end
                bodies[a.body]={name=name}
            end
            a.macroName=bodies[a.body].name
            -- Indices are only a current lookup result. Later macro creation,
            -- renaming or deletion may move this macro within its bank.
            a.macroIndex=K.Macros:FindExact(a.macroName,a.body)
            if not a.macroIndex then error("Could not verify "..tostring(a.label).." macro.") end
        end
    end
end
function E:DeleteOwned(owned)
    for name,body in pairs(owned) do
        local index=K.Macros:FindExact(name,body)
        if index then DeleteMacro(index) end
        K.db.ownedMacros[name]=nil
    end
end
-- Native action bars and bounded setup jobs. Each mutation is a small step;
-- errors switch to a separate bounded rollback job rather than retrying an
-- exhausted Apply/Restore callback in the same frame.
local function clockMS()
    if GetTimePreciseSec then return GetTimePreciseSec()*1000 end
    if debugprofilestop then return debugprofilestop() end
    return (GetTime and GetTime() or 0)*1000
end
local function addStep(steps,fn,message,barrier,mutates)
    steps[#steps+1]={run=fn,message=message,barrier=barrier,mutates=mutates}
end
local function appendNative(steps,nativeSteps,message,mutates)
    for _,fn in ipairs(nativeSteps or {}) do
        local run=fn
        addStep(steps,function() local ok,why=run(); if ok==false then error(why or message) end end,message,false,mutates)
    end
end
local function insertSteps(job,steps)
    for index=#steps,1,-1 do table.insert(job.steps,job.index+1,steps[index]) end
    job.total=#job.steps
end
local function bindingCount()
    local count=GetNumBindings and GetNumBindings() or 0
    if type(count)~="number" or count<0 or count>10000 then error("The client returned an invalid binding count.") end
    return count
end
local function readBinding(index,result)
    local values={GetBinding(index)}
    for n=3,#values do if values[n] and values[n]~="" then result[values[n]]=values[1] end end
end
local function readSteps(result)
    local steps={}; local count=bindingCount()
    for first=1,count,24 do
        local start,last=first,math.min(first+23,count)
        addStep(steps,function() for index=start,last do readBinding(index,result) end end,"Reading bindings",true,false)
    end
    return steps
end
local bindingSteps
local function snapshotSteps(job)
    local snapshot={bindings={},bindingSet=GetCurrentBindingSet and GetCurrentBindingSet() or 2,modified={},cvars={},createdAt=time and time() or 0,native={}}
    job.before=snapshot
    for _,key in ipairs({"SELFCAST","FOCUSCAST"}) do snapshot.modified[key]=GetModifiedClick and GetModifiedClick(key) or "NONE" end
    snapshot.cvars.autoSelfCast=getCVar("autoSelfCast")
    local steps=readSteps(snapshot.bindings)
    addStep(steps,function()
        job.currentBindings=K.Copy(snapshot.bindings)
        local _,entry=E:CaptureBackup(job.kind,snapshot); job.entry=entry
    end,"Saving named backup",true,false)
    if K.NativeBars and K.NativeBars.SnapshotSteps then appendNative(steps,K.NativeBars:SnapshotSteps(snapshot.native),"Backing up action bars",false) end
    addStep(steps,function()
        snapshot[snapshot.bindingSet==1 and "accountBindings" or "characterBindings"]=K.Copy(snapshot.bindings)
        if LoadBindings then
            -- This read stays atomic: no frame can begin with the inactive set
            -- loaded. There are no mass SetBinding writes in this callback.
            local inactive=snapshot.bindingSet==1 and 2 or 1
            local ok,why=pcall(function()
                loadBindings(inactive)
                snapshot[inactive==1 and "accountBindings" or "characterBindings"]=captureBindings()
            end)
            local loaded
            local restored,restoreError=pcall(function()
                loadBindings(snapshot.bindingSet)
                loaded=captureBindings()
            end)
            if not restored then
                -- Loading the inactive set was itself a state change. If the
                -- reload fails, do not cancel while leaving those controls
                -- selected: the captured maps can drive bounded recovery.
                local readable,current=pcall(captureBindings)
                if readable then job.currentBindings=current end
                job.changed=true; job.backupReady=true
                job.entry.complete=snapshot.accountBindings~=nil and snapshot.characterBindings~=nil
                error("Could not restore the active binding set after backup: "..tostring(restoreError))
            end
            job.currentBindings=loaded
            if not ok then
                -- Only the saved active context was loaded; restore unsaved
                -- edits through the same bounded rollback path before ending.
                job.changed=true; job.backupReady=true; error(why)
            end
        end
        job.entry.complete=true; job.backupReady=true
        insertSteps(job,bindingSteps(job,snapshot.bindings))
    end,"Backing up account and character bindings",true,false)
    return steps
end
local critical={W=1,A=2,S=3,D=4,SPACE=5,ESCAPE=6,ENTER=7,["SHIFT-ENTER"]=8,BUTTON1=9,BUTTON2=10,TAB=11}
bindingSteps=function(job,target)
    local steps,keys={},{}
    for key in pairs(target) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)
        local x,y=critical[a] or 100,critical[b] or 100
        return x==y and a<b or x<y
    end)
    for _,key in ipairs(keys) do
        local binding,command=key,target[key]
        if job.currentBindings[binding]~=command then
            addStep(steps,function()
                if not SetBinding(binding,command) then error("The client rejected key "..binding) end
                job.currentBindings[binding]=command
            end,"Installing bindings",false,true)
        end
    end
    -- Obsolete keys are removed only after all replacement controls exist.
    for key in pairs(job.currentBindings) do
        local binding=key
        if target[binding]==nil then addStep(steps,function()
            if not SetBinding(binding) then error("The client could not clear old key "..binding) end
            job.currentBindings[binding]=nil
        end,"Removing obsolete bindings",false,true) end
    end
    return steps
end
local function settingsSteps(snapshot)
    local steps={}
    for key,value in pairs(snapshot.modified or {}) do
        local name,setting=key,value
        addStep(steps,function()
            if SetModifiedClick then SetModifiedClick(name,setting) end
            if GetModifiedClick and GetModifiedClick(name)~=setting then error("Could not restore modifier "..name) end
        end,"Restoring modifier settings",false,true)
    end
    for key,value in pairs(snapshot.cvars or {}) do
        local name,setting=key,value
        addStep(steps,function()
            setCVar(name,setting)
            if tostring(getCVar(name))~=tostring(setting) then error("Could not restore setting "..name) end
        end,"Restoring game settings",false,true)
    end
    return steps
end
local function restoreSteps(job,snapshot)
    local steps={}
    if snapshot.native and K.NativeBars and K.NativeBars.RestoreSteps then appendNative(steps,K.NativeBars:RestoreSteps(snapshot.native),"Restoring native action bars",true) end
    local other=snapshot.bindingSet==1 and 2 or 1
    for _,set in ipairs({other,snapshot.bindingSet}) do
        local bindingSet=set
        local target=set==snapshot.bindingSet and snapshot.bindings or snapshot[set==1 and "accountBindings" or "characterBindings"]
        if target then
            addStep(steps,function() insertSteps(job,bindingSteps(job,target)) end,"Preparing saved bindings",true,false)
            addStep(steps,function() saveBindings(bindingSet) end,"Saving restored bindings",true,true)
        end
    end
    addStep(steps,function() loadBindings(snapshot.bindingSet) end,"Selecting restored binding set",true,true)
    for _,step in ipairs(settingsSteps(snapshot)) do steps[#steps+1]=step end
    addStep(steps,function()
        local read={}; local verify=readSteps(read)
        addStep(verify,function()
            for key,command in pairs(snapshot.bindings) do if read[key]~=command then error("Restore verification failed for "..key) end end
            for key in pairs(read) do if not snapshot.bindings[key] then error("Unexpected restored key "..key) end end
        end,"Verifying restored bindings",true,false)
        insertSteps(job,verify)
    end,"Verifying restored bindings",true,false)
    return steps
end
local function macroSteps(plan,created)
    local steps={}
    for _,action in ipairs(plan and plan.actions or {}) do
        if (action.known or action.nativeMacro) and action.body then
            local current=action
            addStep(steps,function() E:CreateMacros({actions={current}},created) end,"Preparing spell macros",true,true)
        end
    end
    return steps
end
local function deleteSteps(owned)
    local steps={}
    for name,body in pairs(owned or {}) do
        local macro,expected=name,body
        addStep(steps,function() E:DeleteOwned({[macro]=expected}) end,"Removing unedited generated macros",true,true)
    end
    return steps
end
function E:Deactivate()
    if inCombat() then return false end
    local dock=self.dock or _G.KBO_ActionDock
    if dock then dock:Hide() end
    if self.override then UnregisterStateDriver(self.override,"override"); self.override:Execute("self:ClearBindings()") end
    for _,button in pairs(self.buttons or {}) do
        UnregisterStateDriver(button,"kboform"); button:SetAttribute("type",nil); button:Hide()
    end
    return true
end
function E:FinishJob(job,ok,message)
    if self.runner then self.runner:SetScript("OnUpdate",nil) end
    job.progress=1; job.message=message; job.finished=true; job.ok=ok
    self.lastJob=job; self.job=nil; self.busy=false
    if K.OnApplyComplete then K:OnApplyComplete(ok,message,job.plan,job.kind)
    elseif message then K:Print(message) end
    if K.QueueRefresh then K:QueueRefresh() end
end
function E:StartJob(job)
    if self.busy then return false,"Wait for the current operation to finish." end
    self.busy=true; self.job=job
    job.index=1; job.total=#job.steps; job.progress=0; job.message="Preparing "..job.kind
    if not self.runner then self.runner=CreateFrame("Frame") end
    self.runner:SetScript("OnUpdate",function()
        if E.job~=job then return end
        if inCombat() then
            job.paused=true; job.message="Paused in combat. Setup is partly complete and will resume afterward."; return
        end
        job.paused=false
        local started=clockMS(); local count=0
        while job.index<=#job.steps and count<6 do
            local step=job.steps[job.index]
            job.message=step.message or job.message
            if step.mutates then job.changed=true end
            local ok,why=pcall(step.run)
            if not ok then
                if job.entry then job.entry.status="failed"; job.entry.error=tostring(why) end
                if job.rollingBack then
                    E:FinishJob(job,false,"Setup failed; rollback could not finish. Use the saved backup. "..tostring(why)); return
                end
                job.failure=tostring(why)
                if not job.changed or not job.backupReady then E:FinishJob(job,false,"Setup cancelled: "..tostring(why)); return end
                local built,rollback=pcall(job.rollback,job)
                if not built then E:FinishJob(job,false,"Setup failed; could not prepare rollback. Backup retained. "..tostring(rollback)); return end
                job.steps=rollback; job.index=1; job.total=#rollback; job.rollingBack=true; job.message="Rolling back failed setup"; return
            end
            job.index=job.index+1; job.total=#job.steps; job.progress=math.min(0.99,(job.index-1)/math.max(1,job.total))
            count=count+1
            if step.barrier or clockMS()-started>=4 then break end
        end
        if job.index>#job.steps then
            if job.rollingBack then E:FinishJob(job,false,"Setup failed and was rolled back: "..tostring(job.failure))
            else
                local ok,message=pcall(job.commit,job)
                if not ok then
                    job.failure=tostring(message)
                    local built,rollback=pcall(job.rollback,job)
                    if built then job.steps=rollback; job.index=1; job.total=#rollback; job.rollingBack=true
                    else E:FinishJob(job,false,"Setup failed; backup retained. "..tostring(rollback)) end
                else E:FinishJob(job,true,message) end
            end
        end
    end)
    if K.QueueRefresh then K:QueueRefresh() end
    return "pending","Setup started. Progress is shown in Hot Swap."
end
local function rollbackJob(job)
    local steps={}
    addStep(steps,function() E:Deactivate(); restoreRuntime(job.previous,false) end,"Restoring previous preset state",true,false)
    for _,step in ipairs(macroSteps(job.previous.enabled and job.previous.appliedPlan,{})) do steps[#steps+1]=step end
    for _,step in ipairs(restoreSteps(job,job.before)) do steps[#steps+1]=step end
    -- Restore the slots before removing newly-created macros they may still
    -- reference. Their indexes are valid throughout native slot inspection.
    for _,step in ipairs(deleteSteps(job.created)) do steps[#steps+1]=step end
    return steps
end
local function validSnapshot(snapshot)
    if type(snapshot)~="table" or type(snapshot.bindings)~="table" or (snapshot.bindingSet~=1 and snapshot.bindingSet~=2) then return false end
    for _,name in ipairs({"bindings","accountBindings","characterBindings"}) do
        if snapshot[name] then
            if type(snapshot[name])~="table" then return false end
            for key,command in pairs(snapshot[name]) do if type(key)~="string" or type(command)~="string" then return false end end
        end
    end
    return true
end
local function nativePrepare(plan)
    if not K.NativeBars or not K.NativeBars.Prepare then return nil,"Native action bar support is unavailable." end
    local layout,why=K.NativeBars:Prepare(plan)
    if not layout then return nil,why or "Could not prepare native action bars." end
    plan.nativeLayout=layout
    return layout
end
function E:Apply(plan)
    if self.busy then return false,"Wait for the current operation to finish." end
    if inCombat() then return false,"Leave combat before applying a preset." end
    if not plan or #(plan.errors or {})>0 then return false,plan and plan.errors[1] or "Create a preview first." end
    local layout,why=nativePrepare(plan); if not layout then return false,why end
    local needed,available=K.Macros:Budget(plan)
    if needed>available then return false,"Not enough free macro slots. No changes were made." end
    local job={kind="apply",plan=plan,previous=runtimeState(),created={}}
    job.steps=snapshotSteps(job); job.rollback=rollbackJob
    for _,step in ipairs(macroSteps(plan,job.created)) do job.steps[#job.steps+1]=step end
    addStep(job.steps,function()
        E:Deactivate()
        if K.Presets and K.Presets.EnsureButtons then K.Presets:EnsureButtons() end
        insertSteps(job,(function()
            local steps={}; appendNative(steps,K.NativeBars:ApplySteps(plan,layout),"Placing spells on native action bars",true); return steps
        end)())
    end,"Preparing native action bars",true,true)
    addStep(job.steps,function()
        local bindings,err=K.NativeBars:BindingMap(plan)
        if not bindings then error(err or "Could not prepare native bindings.") end
        job.expected=bindings; insertSteps(job,bindingSteps(job,bindings))
    end,"Preparing replacement bindings",true,false)
    addStep(job.steps,function()
        if SetModifiedClick then SetModifiedClick("SELFCAST","ALT"); SetModifiedClick("FOCUSCAST","NONE") end
        if job.before.cvars.autoSelfCast~=nil then setCVar("autoSelfCast","0") end
        if GetModifiedClick and (GetModifiedClick("SELFCAST")~="ALT" or GetModifiedClick("FOCUSCAST")~="NONE") then error("The client rejected self-cast settings.") end
        if job.before.cvars.autoSelfCast~=nil and tostring(getCVar("autoSelfCast"))~="0" then error("The client rejected automatic self-cast settings.") end
    end,"Setting Alt self-cast",true,true)
    addStep(job.steps,function() saveBindings(2); loadBindings(2) end,"Saving character bindings",true,true)
    addStep(job.steps,function()
        local read={}; local checks=readSteps(read)
        addStep(checks,function()
            for key,command in pairs(job.expected) do if read[key]~=command then error("Verification failed for "..key) end end
            for key in pairs(read) do if not job.expected[key] then error("Unexpected binding remains on "..key) end end
        end,"Verifying installed bindings",true,false)
        insertSteps(job,checks)
    end,"Verifying installed bindings",true,false)
    job.commit=function()
        local baseline=K.Copy(K.db.backup or job.before)
        if not baseline.native then baseline.native=K.Copy(job.before.native) end
        K.db.backup=baseline; K.db.enabled=true; K.db.appliedPlan=K.Copy(plan); K.db.appliedPreset=K.db.activePreset
        K.db.settings.fallbackBindings=K.Copy(plan.fallbackBindings)
        K.db.history[#K.db.history+1]={at=time and time() or 0,build=plan.build,spells=plan.coverage.bound,preset=K.db.activePreset}
        if #K.db.history>10 then table.remove(K.db.history,1) end
        job.entry.status="applied"; K.db.lastBindingBackupID=job.entry.id
        return "Preset applied to the original action bars. Backup saved: "..job.entry.name
    end
    return self:StartJob(job)
end
function E:RestoreBackup(id)
    if self.busy then return false,"Wait for the current operation to finish." end
    if inCombat() then return false,"Leave combat before restoring a backup." end
    local entry=K.db and K.db.bindingBackups and K.db.bindingBackups[id]
    if not entry or entry.complete==false or not validSnapshot(entry.snapshot) or type(entry.runtime)~="table" then return false,"That backup is unavailable or incomplete." end
    local target=K.Copy(entry.runtime)
    if target.enabled and (not target.appliedPlan or not target.appliedPlan.nativeLayout) then return false,"This backup used the retired custom bars. Restore your original setup, then apply a native-bar preset." end
    local owned=K.Copy(K.db.ownedMacros or {})
    for name,body in pairs(target.ownedMacros or {}) do if owned[name]==nil then owned[name]=body end end
    if target.enabled then
        local current=K.db.ownedMacros; K.db.ownedMacros=owned
        local needed,available=K.Macros:Budget(target.appliedPlan); K.db.ownedMacros=current
        if needed>available then return false,"Not enough free macro slots to restore this backup. No changes were made." end
    end
    local job={kind="restore",plan=target.appliedPlan,previous=runtimeState(),created={}}
    job.steps=snapshotSteps(job); job.rollback=rollbackJob
    addStep(job.steps,function() E:Deactivate(); restoreRuntime(target,true); K.db.ownedMacros=owned end,"Restoring saved preset state",true,false)
    for _,step in ipairs(macroSteps(target.enabled and target.appliedPlan,job.created)) do job.steps[#job.steps+1]=step end
    for _,step in ipairs(restoreSteps(job,entry.snapshot)) do job.steps[#job.steps+1]=step end
    job.commit=function()
        if K.Presets and K.Presets.EnsureButtons then K.Presets:EnsureButtons() end
        K.db.appliedPlan=K.Copy(target.appliedPlan)
        job.entry.status="restored"; K.db.lastBindingBackupID=job.entry.id
        if K.Presets and K.Presets.HasUnappliedChanges then K.dirty=K.Presets:HasUnappliedChanges() end
        return "Restored "..entry.name.."."..(K.db.enabled and K.dirty and " Saved draft edits remain unapplied." or "")
    end
    return self:StartJob(job)
end
function E:Restore()
    if self.busy then return false,"Wait for the current operation to finish." end
    if inCombat() then return false,"Leave combat before restoring bindings." end
    local target=K.db and K.db.backup
    if not target then return false,"No installed layout to restore." end
    if not validSnapshot(target) then return false,"The original backup is incomplete. Choose a named backup." end
    local job={kind="restore-original",previous=runtimeState(),created={}}
    job.steps=snapshotSteps(job); job.rollback=rollbackJob
    addStep(job.steps,function() E:Deactivate() end,"Restoring original setup",true,true)
    for _,step in ipairs(restoreSteps(job,target)) do job.steps[#job.steps+1]=step end
    for _,step in ipairs(deleteSteps(K.Copy(K.db.ownedMacros))) do job.steps[#job.steps+1]=step end
    job.commit=function()
        K.db.enabled=false; K.db.appliedPlan=nil; K.db.backup=nil; K.db.appliedPreset=nil; K.db.appliedPresetSignature=nil
        job.entry.status="restored"; K.db.lastBindingBackupID=job.entry.id
        if K.Presets and K.Presets.HasUnappliedChanges then K.dirty=K.Presets:HasUnappliedChanges() end
        return "Original bindings, action bars and settings restored. Unedited generated macros removed."
    end
    return self:StartJob(job)
end
function E:Activate(plan)
    if self.busy then return "pending","An operation is already running." end
    if inCombat() then return false,"Leave combat before activating the layout." end
    if not plan or not plan.nativeLayout then return false,"This saved layout used custom bars. Restore the original setup, then apply a preset for native action bars." end
    self:Deactivate()
    K.playerClass=plan.class or K.playerClass
    if K.Presets and K.Presets.EnsureButtons then K.Presets:EnsureButtons() end
    return self:RepairLearnedActions(plan)
end
function E:RepairLearnedActions(plan,itemsOnly)
    if self.busy then return "pending","Form maintenance is already queued." end
    if inCombat() then return false,"Form maintenance waits until combat ends." end
    local forms=itemsOnly and {} or K.API:GetForms(); local changes={}; local book
    for _,action in ipairs(plan.actions or {}) do
        local form=action.formType and forms[action.formType]
        local updated
        if action.kind=="item" and action.itemBinding and action.macroName then
            updated=K.Copy(action)
            K.Items:ApplyToAction(updated,action.itemSelectedID,action.itemBinding)
        elseif not itemsOnly and action.targeting=="form" and not form and action.known then
            -- A removed talent must not retain an old /cancelform guard: it
            -- could drop Bear and then fail to cast the unlearned form.
            updated=K.Copy(action); updated.known=false; updated.nativePending=true; updated.spellID=nil
        elseif not itemsOnly and form and action.targeting=="form" then
            updated=K.Copy(action)
            updated.spellID,updated.spellName,updated.label,updated.icon=form.spellID,form.name,form.name,form.icon
            updated.known=true; updated.nativePending=nil
        elseif not itemsOnly and action.combo and action.macroName then
            book=book or K.API:GetCachedSpellbook()
            local learned=true
            for _,id in ipairs(action.combo) do
                local component=K.API:Resolve({spellIDs=type(id)=="number" and {id} or {},name=type(id)=="string" and id or nil},book)
                if not component or component.passive then learned=false; break end
            end
            if learned~=action.known then
                updated=K.Copy(action); updated.known=learned; updated.nativePending=not learned or nil
            end
        end
        if updated then
            local body,why=K.Macros:Build(updated,plan.settings)
            if updated.kind=="item" then
                updated.body=body
                local prepared,prepareError=K.NativeBars:MakeMacro(updated,plan.settings,true)
                if not prepared then return false,prepareError end
                body=updated.body
            end
            if why then return false,why end
            if body~=action.body or (updated.kind=="item" and (updated.icon~=action.icon or updated.label~=action.label or updated.known~=action.known)) then
                local index,name=K.Macros:FindExact(action.macroName,action.body)
                if not index or K.db.ownedMacros[name]~=action.body then return false,"A managed macro was edited or removed. Review and apply your preset." end
                changes[#changes+1]={action=action,updated=updated,name=name,oldBody=action.body,newBody=body}
            end
        end
    end
    if #changes==0 then if not itemsOnly then plan.formSignature=K.API:FormSignature() end; return true end
    -- Reused macros can appear on several keys/pages. Edit each shared body
    -- once, while committing metadata to every referring action afterward.
    local operations,byName={},{}
    for _,change in ipairs(changes) do
        local previous=byName[change.name]
        if previous then
            if previous.oldBody~=change.oldBody or previous.newBody~=change.newBody then return false,"A shared ability now needs different macros. Use your preset to update these bindings safely." end
        else byName[change.name]=change; operations[#operations+1]=change end
    end
    local job={kind=itemsOnly and "item-maintenance" or "maintenance",plan=plan,steps={},backupReady=true,created={},previous=runtimeState()}
    for _,change in ipairs(operations) do local c=change
        addStep(job.steps,function()
            local index=K.Macros:FindExact(c.name,c.oldBody)
            if not index or K.db.ownedMacros[c.name]~=c.oldBody then error("A managed macro changed before maintenance. Review and apply your preset.") end
            c.touched=true
            EditMacro(index,nil,c.updated.icon,c.newBody)
            if not K.Macros:FindExact(c.name,c.newBody) then error("The client rejected an ability macro update.") end
        end,"Updating learned ability macros",true,true)
    end
    job.rollback=function()
        local steps={}
        for _,change in ipairs(operations) do local c=change
            addStep(steps,function()
                if not c.touched then return end
                if K.Macros:FindExact(c.name,c.oldBody) then return end
                local index=K.Macros:FindExact(c.name,c.newBody)
                if not index then error("A macro was edited while maintenance was running; its personal edits were preserved.") end
                EditMacro(index,nil,c.action.icon,c.oldBody)
                if not K.Macros:FindExact(c.name,c.oldBody) then error("The client rejected restoration of an ability macro.") end
            end,"Restoring ability macros",true,true)
        end
        return steps
    end
    job.commit=function()
        -- Verify every update before changing any saved action/ownership state.
        for _,c in ipairs(changes) do
            c.currentIndex=K.Macros:FindExact(c.name,c.newBody)
            if not c.currentIndex then error("An updated macro changed before maintenance finished; personal edits were preserved.") end
        end
        for _,c in ipairs(changes) do
            local a,u=c.action,c.updated
            for key in pairs(a) do a[key]=nil end
            for key,value in pairs(u) do a[key]=K.Copy(value) end
            a.body=c.newBody; a.macroName=c.name; a.macroIndex=c.currentIndex
            K.db.ownedMacros[c.name]=c.newBody
        end
        if not itemsOnly then plan.formSignature=K.API:FormSignature() end
        return itemsOnly and "Item bindings updated on the original action bars." or "Learned ability macros updated on the original action bars."
    end
    return self:StartJob(job)
end
function E:RepairItemActions(plan) return self:RepairLearnedActions(plan,true) end
