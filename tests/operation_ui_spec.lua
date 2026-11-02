local function operationUI(allowFixtureOverflow)
    local k=TestAddon; k:Init()
    -- Apply/rollback scenarios use the artificial all-talents Druid fixture.
    if allowFixtureOverflow then k:GetSettings().allowAccountMacros=true end
    k.UI:Open(); k.UI:SetBindingSource("draft"); Mock.async=true
    return k
end
function Tests.operation_failure_details_preserve_full_binding_error_after_review_and_reopen()
    local k=operationUI(true); local original=SetBinding; local rejected=false; local placed=false
    SetBinding=function(key,command)
        if key=="F6" and command and not rejected then
            rejected=true; placed=next(Mock.actions)~=nil; return false
        end
        return original(key,command)
    end
    k.UI.apply:Click()
    local ok,why=Mock:Drain(); assert(not ok and rejected,why)
    assert(placed,"Failure fixture did not occur after native bar placement")
    local error=k.UI.operationError; local dialog=k.UI.operationErrorDialog
    assert(error and error.outcome=="restored","Successful rollback is not explained")
    assert(error.message:find("F6",1,true) and dialog.text:GetText():find(error.message,1,true),"Full key failure is missing from selectable details")
    assert(error.explanation:find("Bars can appear briefly",1,true),"Transient bar placement is unexplained")
    assert(dialog:IsShown() and dialog.text:HasFocus(),"Open-window failure did not expose copyable details")
    assert(k.UI.status:GetText()==error.summary and #error.summary<80,"Footer still contains a clipped technical error")
    assert(k.UI.reviewButton:GetText()=="Details","Failure details are not reachable")
    Mock:KeyDown("ESCAPE"); Mock:Advance(0.05)
    assert(not dialog:IsShown() and k.UI.frame:IsShown(),"Escape closed the parent window")
    k.UI.reviewButton:Click()
    assert(k.UI.operationError==error and dialog:IsShown(),"Review cleared the last operation failure")
    dialog.close:Click(); Mock:Advance(0.05); k.UI.frame:Hide(); k.UI:Open(); k.UI:SetBindingSource("draft")
    assert(k.UI.operationError==error and k.UI.reviewButton:GetText()=="Details","Closing the window lost the failure")
    k.UI.reviewButton:Click(); dialog.dismiss:Click(); Mock:Advance(0.05)
    assert(not k.UI.operationError and k.UI.reviewButton:GetText()=="Review","Explicit dismissal did not clear details")
    assert(not k.db.appliedPreset,"Failed apply was marked active")
end

function Tests.operation_preflight_failure_ignores_old_rollback_and_success_clears_details()
    local k=operationUI(true)
    k.Engine.lastJob={finished=true,ok=false,kind="apply",rollingBack=true,message="Old setup was rolled back",entry={id="old",name="Old backup",complete=true}}
    local original=k.Presets.Activate
    k.Presets.Activate=function() return false,"This client does not support F6 (Target focus; TARGETFOCUS)." end
    Mock:ResetWrites(); k.UI.apply:Click()
    local error=k.UI.operationError
    assert(error.outcome=="not-started" and not error.backupID,"Preflight borrowed an old rollback or backup")
    assert(error.details:find("No game changes were made",1,true) and error.details:find("No new recovery backup",1,true),"Preflight outcome is misleading")
    assert(#Mock.writes==0,"Failure details changed game state")
    k.UI.operationErrorDialog.close:Click(); Mock:Advance(0.05)
    k.Presets.Activate=original; k.UI.apply:Click()
    assert(not k.UI.operationErrorDialog:IsShown(),"Retry retained its modal over progress")
    local ok,why=Mock:Drain(); assert(ok,why); Mock:Advance(0.2)
    assert(not k.UI.operationError and k.UI.reviewButton:GetText()=="Review","Successful retry kept stale failure details")
end

function Tests.operation_rollback_failure_never_claims_the_previous_setup_was_restored()
    local k=operationUI()
    local message="Setup failed; rollback could not finish. Use the saved backup. Rejected F6."
    k.Engine.lastJob={kind="apply",finished=true,ok=false,changed=true,rollingBack=true,message=message,failure="The client rejected F6 (Target focus; TARGETFOCUS).",failureStage="Installing bindings",failureKey="F6",failureAction="Target focus",failureCommand="TARGETFOCUS",entry={id="b9",name="Recovery setup",complete=true}}
    k.UI:OnOperationComplete(false,message,"apply")
    local error=k.UI.operationError
    assert(error.outcome=="incomplete" and error.summary:find("recovery needs attention",1,true),"Failed rollback was mislabeled successful")
    assert(error.details:find("Recovery setup [b9]",1,true) and error.details:find("Installing bindings",1,true),"Recovery instructions lost backup or original stage")
    assert(error.details:find("Binding: F6 - Target focus (TARGETFOCUS)",1,true),"Copy details lost readable binding context")
    assert(not error.summary:find("restored",1,true),"Footer promises unverified restoration")
end

function Tests.operation_error_details_are_opaque_without_changing_window_preferences()
    local k=operationUI(); k.UI:SetAppearance("windowOpacity",0.4)
    local create=CreateFrame
    CreateFrame=function(kind,name,...)
        local frame=create(kind,name,...)
        if name=="KeybindOptimizerOperationError" then
            function frame:SetIgnoreParentAlpha(value) self.ignoresParentAlpha=value end
        end
        return frame
    end
    k.UI:RecordOperationFailure("Not enough character-specific macro slots.","apply")
    local dialog=k.UI.operationErrorDialog
    assert(dialog.ignoresParentAlpha and dialog:GetAlpha()==1,"Failure text inherited the translucent main window")
    assert(dialog.opaqueBackground and dialog.opaqueBackground.colorTexture[4]==1,"Native translucent backdrop has no opaque backing")
    assert(dialog.opaqueBackground.allPoints==dialog and dialog.backdrop,"Opaque backing lost full coverage or native styling")
    assert(k.db.preferences.windowOpacity==0.4 and k.UI.frame:GetAlpha()==0.4,"Opening details overwrote the user's window appearance")
    dialog.close:Click(); Mock:Advance(0.05)
    assert(k.UI.frame:IsShown() and k.UI.frame:GetAlpha()==0.4,"Closing error details changed or closed the main window")
end

function Tests.operation_review_capacity_reservations_are_informational_and_keep_draft_status()
    local k=operationUI(); local plan=k.UI.plan
    plan.capacityDeferredCount=12; plan.errors={}
    k.Preview=function() return plan end; k.PreviewCached=function() return plan end
    k.UI.notice=nil; k.UI:Refresh(); k.UI:OpenReview()
    assert(k.UI.status:GetText():find("12 future spells reserved; see Review.",1,true),"Footer omitted macro-capacity reservations")
    assert(k.UI.status:GetText():find("Draft",1,true),"Capacity note replaced the draft/active state")
    local found
    for _,row in ipairs(k.UI.review.list.rows) do
        if row:GetText():find("12 future spells reserved to save macro slots.",1,true) then
            assert(row.textColor[1]~=1 or row.textColor[2]~=.43,"Capacity reservation was styled as an error")
            found=true
        end
    end
    assert(found and k.UI.apply:IsEnabled() and not k.UI.operationError,"Future reservations incorrectly blocked applying")
    plan.capacityDeferredCount=0; k.UI:Refresh()
    assert(not k.UI.status:GetText():find("future spells reserved",1,true),"Cleared reservations left a stale capacity note")
end
