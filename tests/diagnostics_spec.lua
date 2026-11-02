-- These fixtures exercise full catalogs/visible reservations with account overflow explicitly enabled.
local function equal(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function ready()
    TestAddon:Init(); TestAddon:GetSettings().allowAccountMacros=true; TestAddon.Diagnostics:Init(); return TestAddon,TestAddon.Diagnostics
end
local function handlers()
    local calls={}
    local previous=function(message,extra) calls[#calls+1]={message,extra}; return "handled",extra end
    local current=previous
    geterrorhandler=function() return current end
    seterrorhandler=function(handler) assert(type(handler)=="function"); current=handler end
    return previous,calls
end

function Tests.diagnostics_default_off_records_nothing_and_does_not_wrap_the_error_handler()
    local previous,calls=handlers(); local k,d=ready()
    assert(not d:IsEnabled()); equal(d:Count(),0); equal(geterrorhandler(),previous)
    assert(not d:Record("error","test","Do not retain this",{key="F6"}))
    equal(d:Count(),0); equal(#k.db.diagnostics,0)
    geterrorhandler()("Interface/AddOns/KeybindOptimizer/UI.lua:1: sample","detail")
    equal(#calls,1); equal(d:Count(),0)
end

function Tests.diagnostics_caps_messages_context_and_total_saved_records()
    local k,d=ready(); assert(d:SetEnabled(true))
    for index=1,225 do d:Record("info","step",string.rep("x",4000),{key="F6",operation=index,macroBody="SECRET",preset={secret=true},stage=string.rep("s",300)}) end
    equal(d:Count(),200); equal(k.db.diagnostics[1].context.operation,"26")
    local entry=k.db.diagnostics[200]
    equal(#entry.message,3000); equal(#entry.context.stage,128)
    assert(entry.context.class and entry.context.flavor and entry.context.version)
    assert(not entry.context.macroBody and not entry.context.preset)
    local exported=d:Export()
    assert(exported:find("Hot Swap diagnostics",1,true) and exported:find("key=F6",1,true))
    assert(not exported:find("SECRET",1,true),"Export included non-whitelisted private context")
end

function Tests.diagnostics_disable_preserves_entries_and_clear_removes_them_without_a_new_event()
    local previous=handlers(); local k,d=ready(); assert(d:SetEnabled(true))
    assert(geterrorhandler()~=previous)
    d:Record("error","failure","Saved problem")
    assert(d:SetEnabled(false)); equal(geterrorhandler(),previous)
    assert(not d:Record("info","later","Should not be stored")); equal(d:Count(),1)
    assert(d:Export():find("Saved problem",1,true) and d:Export():find("Logging: disabled",1,true))
    assert(d:Clear()); equal(d:Count(),0); equal(#k.db.diagnostics,0)
    assert(d:Export():find("No diagnostic entries",1,true))
end

function Tests.diagnostics_uncaught_addon_errors_are_logged_and_always_forwarded()
    local previous,calls=handlers(); local k,d=ready(); assert(d:SetEnabled(true))
    local result,extra=geterrorhandler()("Interface/AddOns/KeybindOptimizer/Engine.lua:316: sample","original detail")
    equal(result,"handled"); equal(extra,"original detail"); equal(#calls,1); equal(d:Count(),1)
    equal(k.db.diagnostics[1].event,"lua_error")
    geterrorhandler()("Interface/AddOns/OtherAddon/Test.lua:1: unrelated")
    equal(#calls,2); equal(d:Count(),1,"Unrelated addon error was captured")
    -- A diagnostics fault must not prevent the existing game's handler.
    d.Record=function() error("diagnostic write failure") end
    equal(geterrorhandler()("KeybindOptimizer/UI.lua:1: another"),"handled")
    equal(#calls,3)
end

function Tests.diagnostics_disable_keeps_another_addons_handler_chain_and_reenable_does_not_duplicate()
    local previous,calls=handlers(); local _,d=ready(); assert(d:SetEnabled(true))
    local ours=geterrorhandler(); local outerCalls=0
    local outer=function(...) outerCalls=outerCalls+1; return ours(...) end
    seterrorhandler(outer)
    assert(d:SetEnabled(false)); equal(geterrorhandler(),outer,"Disabling replaced another addon's handler")
    geterrorhandler()("KeybindOptimizer/UI.lua:1: disabled")
    equal(d:Count(),0); equal(outerCalls,1); equal(#calls,1)
    assert(d:SetEnabled(true)); geterrorhandler()("KeybindOptimizer/UI.lua:2: enabled")
    equal(d:Count(),1,"Reenable duplicated a chained error")
    equal(outerCalls,2); equal(#calls,2)
    assert(d:SetEnabled(false)); equal(geterrorhandler(),outer)
end

function Tests.diagnostics_reload_preserves_preference_and_normalizes_bounded_saved_entries()
    local previous=handlers(); local k,d=ready(); assert(d:SetEnabled(true))
    d:Record("error","saved","Retained across reload",{operation="apply",macroBody="PRIVATE"})
    local stored=k.Copy(k.db)
    assert(d:SetEnabled(false)); KeybindOptimizerDB=stored
    k:Init(); d:Init()
    assert(d:IsEnabled()); equal(d:Count(),1); assert(geterrorhandler()~=previous)
    assert(d:Export():find("Retained across reload",1,true))
    k.db.preferences.diagnostics=false
    for index=1,250 do k.db.diagnostics[index]={message=string.rep("m",4000),context={key="F6",macroBody="PRIVATE"}} end
    d:Init(); assert(not d:IsEnabled()); equal(geterrorhandler(),previous)
    equal(d:Count(),200); equal(#k.db.diagnostics[1].message,3000)
    assert(not d:Export():find("PRIVATE",1,true))
end

function Tests.diagnostics_trace_is_bounded_opt_in_and_does_not_collect_locals()
    local _,d=ready(); local calls=0
    debugstack=function(start,top,bottom)
        calls=calls+1; equal(start,2); equal(top,16); equal(bottom,0)
        return "Engine.lua:247: binding step\n"..string.rep("s",4000)
    end
    equal(d:Trace("disabled error"),"disabled error"); equal(calls,0)
    assert(d:SetEnabled(true)); local trace=d:Trace("binding rejected")
    assert(trace:find("binding rejected",1,true) and trace:find("Stack:\nEngine.lua:247",1,true))
    equal(#trace,3000); equal(calls,1)
    debugstack=function() error("stack unavailable") end
    equal(d:Trace("base error"),"base error")
end

local function event(k,name)
    for _,entry in ipairs(k.db.diagnostics) do if entry.event==name then return entry end end
end

function Tests.diagnostics_actual_apply_is_silent_when_off_and_records_success_when_enabled()
    local k,d=ready(); assert(k:Apply()); equal(d:Count(),0,"Default Apply wrote diagnostic events")
    assert(d:SetEnabled(true)); assert(k:Apply())
    assert(event(k,"operation-start") and event(k,"phase"),"Enabled Apply did not record its progress")
    local finished=event(k,"operation-finished")
    assert(finished and finished.context.outcome=="success" and finished.context.operation=="apply")
    assert(finished.context.backup,"Successful operation omitted its recovery snapshot")
end

function Tests.diagnostics_binding_failure_records_f6_command_stage_backup_and_completed_rollback()
    local k,d=ready(); assert(d:SetEnabled(true))
    local original=k.Copy(Mock.bindings); local set=SetBinding; local rejected=false
    SetBinding=function(key,command,...)
        if not rejected and key=="F6" and command=="TARGETFOCUS" then rejected=true; return false end
        return set(key,command,...)
    end
    debugstack=function() return "Engine.lua:247: binding step\nEngine.lua:381: worker" end
    local ok,why=k:Apply()
    assert(not ok and rejected and why:find("F6",1,true) and why:find("TARGETFOCUS",1,true),tostring(why))
    local failure=event(k,"step-error")
    assert(failure,"Runtime command failure was not logged")
    equal(failure.context.key,"F6"); equal(failure.context.command,"TARGETFOCUS")
    equal(failure.context.stage,"Installing bindings"); assert(failure.context.backup)
    assert(failure.message:find("Stack:",1,true),"Worker logged the error after its stack was lost")
    assert(event(k,"rollback-start") and event(k,"rollback-complete"),"Rollback outcome was omitted")
    local finished=event(k,"operation-finished")
    equal(finished.context.outcome,"rolled-back")
    for key,command in pairs(original) do equal(Mock.bindings[key],command,"Recovered binding "..key) end
    for key in pairs(Mock.bindings) do assert(original[key],"Failed setup retained an extra binding") end
end

function Tests.diagnostics_preflight_failure_is_logged_without_game_writes_or_a_backup()
    Mock.build="1.15.9"; Mock.buildNumber="70576"
    local k,d=ready(); assert(d:SetEnabled(true)); local plan=k:Preview()
    local a={id="test.unavailable",kind="system",key="F6",command="TARGETFOCUS",known=true,label="Unavailable target focus"}
    plan.actions[#plan.actions+1]=a; plan.system[#plan.system+1]=a
    Mock:ResetWrites(); local before=#k.Engine:ListBackups()
    local ok,why=k.Engine:Apply(plan)
    assert(not ok and why:find("TARGETFOCUS",1,true),tostring(why))
    equal(#Mock.writes,0); equal(#k.Engine:ListBackups(),before)
    local failure=event(k,"preflight")
    assert(failure and failure.message:find("F6",1,true)); equal(failure.context.outcome,"not-started")
    assert(not failure.context.backup and not event(k,"operation-start"))
end

function Tests.diagnostics_logger_failure_cannot_interrupt_apply_or_leave_the_worker_busy()
    local k,d=ready(); assert(d:SetEnabled(true))
    d.Record=function() error("injected diagnostics failure") end
    local ok,why=k:Apply(); assert(ok,why)
    assert(k.db.enabled and not k.Engine.busy,"Diagnostic failure interrupted the setup transaction")
end
